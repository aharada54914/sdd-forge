#!/usr/bin/env python3
"""Collect read-only Actions metadata and verify revision-bound CI execution."""
import argparse
import datetime as dt
import importlib.util
import io
import lzma
import math
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
API_VERSION = '2026-03-10'
MAX_RESPONSE_BYTES = 32 * 1024 * 1024
MAX_EXPANDED_BYTES = 64 * 1024 * 1024
MAX_MEMBERS = 1024
MAX_PAGES = 1000
MAX_ATTEMPTS = 100
REASONS = {'input-invalid', 'binding-invalid', 'diff-unavailable', 'base-planner-unavailable',
           'force-full', 'event-full', 'unknown-path', 'shared-change', 'unproven-category',
           'evidence-missing', 'evidence-mismatch', 'execution-failed', 'verified',
           'unrelated-category', 'advisory-inactive'}


def planner_module():
    path = Path(__file__).with_name('verification-impact.py')
    spec = importlib.util.spec_from_file_location('ci_impact', path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    exec(compile(path.read_bytes(), str(path), 'exec'), module.__dict__)
    return module


P = planner_module()
W = P.workflow_module()
R = W.runner_module()


def positive(value):
    return type(value) is int and value > 0


def run_identity(value):
    return isinstance(value, str) and re.fullmatch('[1-9][0-9]*', value) is not None


def repository_identity(value):
    return isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', value) is not None


def utc(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z', value):
        raise ValueError('invalid UTC timestamp')
    return dt.datetime.fromisoformat(value.replace('Z', '+00:00'))


def reference(row, artifact=False):
    P.exact_fields(row, 'path sha256' + (' job_id source_attempt' if artifact else ''))
    if not P.relative_path(row['path']) or not P.hash_value(row['sha256']):
        raise ValueError('invalid file reference')
    if artifact and (not positive(row['job_id']) or not positive(row['source_attempt'])):
        raise ValueError('invalid artifact source execution')


def validate_collection(value):
    P.exact_fields(value, 'schema repository run_id api_head_sha collected_at api_version run jobs artifacts')
    if (value['schema'] != 'verification-ci-observations/v1' or not repository_identity(value['repository'])
            or not run_identity(value['run_id']) or not P.hash_value(value['api_head_sha'], 40)
            or value['api_version'] != API_VERSION):
        raise ValueError('invalid collection identity')
    utc(value['collected_at'])
    reference(value['run'])
    paths = {value['run']['path']}
    for name in ('jobs', 'artifacts'):
        if not isinstance(value[name], list) or (name == 'jobs' and not value[name]):
            raise ValueError('missing observation references')
        for row in value[name]:
            reference(row, name == 'artifacts')
            if row['path'] in paths:
                raise ValueError('duplicate observation reference')
            paths.add(row['path'])


def validate_error(value):
    P.exact_fields(value, 'schema reason message')
    if (value['schema'] != 'verification-ci-error/v1' or value['reason'] not in REASONS
            or not isinstance(value['message'], str) or not value['message'].strip()):
        raise ValueError('invalid error envelope')


def validate_result(value, expected=None):
    P.exact_fields(value, 'schema status reason run_id api_head_sha tested_revision plan_sha256 results')
    if (value['schema'] != 'verification-ci-result/v1' or value['status'] not in ('PASS', 'FAIL')
            or value['reason'] not in REASONS or not run_identity(value['run_id'])
            or not P.hash_value(value['api_head_sha'], 40) or not P.hash_value(value['tested_revision'], 40)
            or not P.hash_value(value['plan_sha256']) or not isinstance(value['results'], list) or not value['results']):
        raise ValueError('invalid result envelope')
    ids = set()
    for row in value['results']:
        P.exact_fields(row, 'obligation_id status reason job_id source_attempt')
        if (not isinstance(row['obligation_id'], str) or not row['obligation_id'] or row['obligation_id'] in ids
                or row['status'] not in ('PASS', 'FAIL', 'NOT_SELECTED', 'EXPECTED_SKIP') or row['reason'] not in REASONS):
            raise ValueError('invalid result row')
        ids.add(row['obligation_id'])
        if (row['job_id'] is None) != (row['source_attempt'] is None):
            raise ValueError('partial execution identity')
        if row['job_id'] is not None and (not positive(row['job_id']) or not positive(row['source_attempt'])):
            raise ValueError('invalid execution identity')
        if row['status'] == 'PASS' and row['job_id'] is None:
            raise ValueError('PASS requires execution identity')
        if row['status'] == 'NOT_SELECTED' and row['job_id'] is not None:
            raise ValueError('omission cannot claim execution')
        if row['status'] == 'EXPECTED_SKIP' and (row['reason'] != 'advisory-inactive'
                                                or row['job_id'] is not None):
            raise ValueError('expected skip cannot claim execution')
        if row['reason'] == 'advisory-inactive' and row['status'] != 'EXPECTED_SKIP':
            raise ValueError('inactive advisory requires expected skip')
    if (value['status'] == 'FAIL') != any(r['status'] == 'FAIL' for r in value['results']):
        raise ValueError('result status disagrees with rows')
    if expected is not None and P.canonical(value) != P.canonical(expected):
        raise ValueError('result counterpart mismatch')


def read_json(path):
    if path.stat().st_size > MAX_RESPONSE_BYTES:
        raise ValueError('JSON input exceeds bound')
    return P.strict_json(path.read_bytes())


def read_reference(root, row):
    path = root / row['path']
    if any(part.is_symlink() for part in [path, *path.parents] if part != root.parent):
        raise ValueError('symlink observation reference')
    if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError('missing or unsafe observation')
    if path.stat().st_size > MAX_RESPONSE_BYTES or P.sha(path.read_bytes()) != row['sha256']:
        raise ValueError('observation digest mismatch')
    return read_json(path)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = P.canonical(value) + b'\n'
    with path.open('xb') as output:
        output.write(raw)
    return {'path': path.name, 'sha256': P.sha(raw)}


def api_response(endpoint):
    # gh owns existing authentication. Its Go HTTP client strips Authorization
    # on cross-origin storage redirects; no token is obtained or manually sent.
    if not endpoint.startswith('/repos/') or any(c in endpoint for c in '\r\n#'):
        raise ValueError('invalid Actions endpoint')
    command = ['gh', 'api', '--hostname', 'github.com', '--method', 'GET', '--include',
               '--header', 'Accept: application/vnd.github+json',
               '--header', 'X-GitHub-Api-Version: ' + API_VERSION, endpoint]
    try:
        result = subprocess.run(command, capture_output=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ValueError('Actions read unavailable') from exc
    if result.returncode or len(result.stdout) > MAX_RESPONSE_BYTES:
        raise ValueError('Actions read failed or exceeded bound')
    raw = result.stdout
    # gh --include emits final response headers; do not persist redirect URLs.
    separator = b'\r\n\r\n' if b'\r\n\r\n' in raw else b'\n\n'
    header, marker, body = raw.partition(separator)
    if not marker or not re.match(rb'HTTP/\S+ 200(?:\s|$)', header):
        raise ValueError('Actions response is not a complete success')
    headers = {}
    for line in header.splitlines()[1:]:
        key, colon, value = line.partition(b':')
        if colon:
            name = key.decode('ascii').lower()
            if name in ('link', 'x-github-api-version-selected'):
                if name in headers:
                    raise ValueError('conflicting response headers')
                headers[name] = value.decode('ascii').strip()
    if headers.get('x-github-api-version-selected', API_VERSION) != API_VERSION:
        raise ValueError('Actions API version mismatch')
    return body, headers


def api_get(endpoint):
    raw, headers = api_response(endpoint)
    return P.strict_json(raw), headers


def pages(endpoint, field):
    original = urlsplit(endpoint)
    seen: set[str] = set()
    ids, output = set(), []
    total = None
    while endpoint:
        if endpoint in seen or len(seen) >= MAX_PAGES:
            raise ValueError('pagination cycle or bound exceeded')
        seen.add(endpoint)
        value, headers = api_get(endpoint)
        count = value.get('total_count')
        rows = value.get(field)
        if (type(count) is not int or count < 0 or not isinstance(rows, list)
                or (total is not None and total != count)):
            raise ValueError('invalid or conflicting page totals')
        total = count
        for row in rows:
            if not isinstance(row, dict) or not positive(row.get('id')) or row['id'] in ids:
                raise ValueError('duplicate or invalid API instance')
            ids.add(row['id'])
        output.append(value)
        endpoint = None
        links = headers.get('link', '')
        for item in links.split(',') if links else []:
            match = re.fullmatch(r'\s*<([^>]+)>;\s*rel="([a-z]+)"\s*', item)
            if not match:
                raise ValueError('malformed pagination link')
            if match[2] != 'next':
                continue
            url = urlsplit(match[1])
            if (endpoint is not None or url.scheme != 'https' or url.netloc != 'api.github.com'
                    or url.path != original.path or url.fragment or not url.query):
                raise ValueError('unsafe or ambiguous pagination link')
            endpoint = url.path + '?' + url.query
        if endpoint and (not rows or len(ids) >= total):
            raise ValueError('pagination contradicts total')
    if len(ids) != total:
        raise ValueError('incomplete pagination')
    return output


def extract_receipts(raw, target):
    if target.exists() or target.is_symlink() or len(raw) > MAX_RESPONSE_BYTES:
        raise ValueError('invalid archive destination or size')
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            members = archive.infolist()
            if not members or len(members) > MAX_MEMBERS or sum(m.file_size for m in members) > MAX_EXPANDED_BYTES:
                raise ValueError('archive bound exceeded')
            names, files = set(), {}
            for member in members:
                name = member.filename[:-1] if member.is_dir() else member.filename
                mode = member.external_attr >> 16
                if (not P.relative_path(name) or name in names or member.flag_bits & 1
                        or stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR))
                        or (not member.is_dir() and not name.endswith('.json'))):
                    raise ValueError('unsafe archive member')
                names.add(name)
                if not member.is_dir():
                    data = archive.read(member)
                    P.strict_json(data)
                    files[name] = data
            if not files or any(parent.as_posix() in files for name in names for parent in Path(name).parents if str(parent) != '.'):
                raise ValueError('empty archive or conflicting paths')
    except (zipfile.BadZipFile, zlib.error, lzma.LZMAError, EOFError, RuntimeError) as exc:
        raise ValueError('invalid receipt archive') from exc
    target.mkdir(parents=True)
    for name, data in files.items():
        path = target / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open('xb') as output:
            output.write(data)
    return [target / name for name in sorted(files)]


def name_key(name):
    return P.sha(P.canonical({'name': name}))


def artifact_identity(name, run_id):
    match = re.fullmatch(r'verification-receipts-([1-9][0-9]*)-([1-9][0-9]*)-([0-9a-f]{64})', name)
    if not match or match[1] != run_id:
        raise ValueError('invalid receipt artifact identity')
    return int(match[2]), match[3]


def collect(repository, run_id, output_dir):
    if not repository_identity(repository) or not run_identity(run_id) or output_dir.exists():
        raise ValueError('invalid collection arguments or existing destination')
    prefix = f'/repos/{repository}/actions'
    run, _ = api_get(prefix + '/runs/' + run_id)
    attempts = run.get('run_attempt')
    if (str(run.get('id')) != run_id or not positive(run.get('id'))
            or not positive(attempts) or attempts > MAX_ATTEMPTS
            or not P.hash_value(run.get('head_sha'), 40)
            or not isinstance(run.get('repository'), dict)
            or run['repository'].get('full_name') != repository):
        raise ValueError('run identity mismatch')
    output_dir.mkdir(parents=True)
    manifest = dict(schema='verification-ci-observations/v1', repository=repository, run_id=run_id,
                    api_head_sha=run['head_sha'], collected_at=dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                    api_version=API_VERSION, run=write_json(output_dir / 'run.json', run), jobs=[], artifacts=[])
    jobs = []
    for attempt in range(1, attempts + 1):
        records = pages(prefix + f'/runs/{run_id}/attempts/{attempt}/jobs?per_page=100', 'jobs')
        for page, record in enumerate(records, 1):
            for job in record['jobs']:
                if (job.get('run_id') != int(run_id) or job.get('run_attempt') != attempt
                        or job.get('head_sha') != run['head_sha']):
                    raise ValueError('job identity disagrees with requested attempt')
            jobs.extend(record['jobs'])
            path = f'jobs/{attempt}-{page}.json'
            manifest['jobs'].append({**write_json(output_dir / path, record), 'path': path})
    names = set()
    for record in pages(prefix + f'/runs/{run_id}/artifacts?per_page=100', 'artifacts'):
        for artifact in record['artifacts']:
            name = artifact.get('name')
            if not isinstance(name, str):
                raise ValueError('invalid artifact name')
            if not name.startswith('verification-receipts-'):
                continue
            attempt, key = artifact_identity(name, run_id)
            matches = [j for j in jobs if j['run_attempt'] == attempt and name_key(j.get('name')) == key]
            if (name in names or len(matches) != 1 or artifact.get('expired') is not False
                    or not isinstance(artifact.get('workflow_run'), dict)
                    or artifact['workflow_run'].get('id') != int(run_id)
                    or artifact['workflow_run'].get('head_sha') != run['head_sha']):
                raise ValueError('missing, duplicate, expired or wrong-run receipt artifact')
            names.add(name)
            raw, _ = api_response(prefix + f"/artifacts/{artifact['id']}/zip")
            target = output_dir / 'artifacts' / name
            for path in extract_receipts(raw, target):
                manifest['artifacts'].append(dict(path=path.relative_to(output_dir).as_posix(),
                                                 sha256=P.sha(path.read_bytes()), job_id=matches[0]['id'],
                                                 source_attempt=attempt))
    validate_collection(manifest)
    write_json(output_dir / 'collection.json', manifest)
    return manifest


def expanded_jobs(workflow):
    result = {}
    for job_id, job in workflow['jobs'].items():
        if job_id == 'required-checks':
            continue
        for matrix in W.matrix_rows(job):
            display = {key: str(value).lower() if type(value) is bool else str(value) for key, value in matrix.items()}
            name = W.expand_matrix(job['name'], display) if 'name' in job else job_id + (
                ' (' + ', '.join(str(v).lower() if type(v) is bool else str(v) for v in matrix.values()) + ')' if matrix else '')
            if '${{' in name or name in result:
                raise ValueError('ambiguous expanded job name')
            result[name] = {'job': job_id, 'matrix': matrix, 'runner': W.expand_matrix(job['runs-on'], matrix)}
    return result


def validate_jobs(manifest, observations, run):
    jobs, ids, names = [], set(), set()
    counts: dict[int, int] = {}
    page_totals: dict[int, int] = {}
    for reference_row in manifest['jobs']:
        page = read_reference(observations, reference_row)
        rows, total = page.get('jobs'), page.get('total_count')
        if not isinstance(rows, list) or type(total) is not int or total < 0:
            raise ValueError('malformed jobs page')
        attempts = set()
        for job in rows:
            if not isinstance(job, dict):
                raise ValueError('invalid job observation object')
            attempt = job['run_attempt']
            if (not positive(job.get('id')) or job['id'] in ids or not positive(attempt)
                    or attempt > run['run_attempt'] or job.get('run_id') != run['id']
                    or job.get('head_sha') != run['head_sha'] or not isinstance(job.get('name'), str)
                    or not job['name'] or (attempt, job['name']) in names):
                raise ValueError('duplicate or wrong-identity job')
            ids.add(job['id'])
            names.add((attempt, job['name']))
            attempts.add(attempt)
            jobs.append(job)
            counts[attempt] = counts.get(attempt, 0) + 1
        if len(attempts) != 1:
            raise ValueError('missing or mixed-attempt jobs page')
        attempt = attempts.pop()
        if attempt in page_totals and page_totals[attempt] != total:
            raise ValueError('conflicting jobs totals')
        page_totals[attempt] = total
    if set(counts) != set(range(1, run['run_attempt'] + 1)) or counts != page_totals:
        raise ValueError('incomplete attempt history')
    return jobs


def execution_signature(job):
    utc(job['started_at'])
    if utc(job['completed_at']) < utc(job['started_at']):
        raise ValueError('invalid execution interval')
    if not positive(job.get('runner_id')) or not isinstance(job.get('runner_name'), str) or not job['runner_name']:
        raise ValueError('missing native runner identity')
    steps, names, numbers = [], set(), set()
    if not isinstance(job.get('steps'), list) or not job['steps']:
        raise ValueError('missing steps')
    for step in job['steps']:
        if (not isinstance(step, dict) or not isinstance(step.get('name'), str) or not step['name'] or step['name'] in names
                or not positive(step.get('number')) or step['number'] in numbers):
            raise ValueError('ambiguous step identity')
        names.add(step['name'])
        numbers.add(step['number'])
        if step.get('started_at') is not None:
            utc(step['started_at'])
        if step.get('completed_at') is not None:
            utc(step['completed_at'])
        steps.append({k: step.get(k) for k in ('name', 'number', 'status', 'conclusion', 'started_at', 'completed_at')})
    return P.canonical({**{k: job.get(k) for k in ('name', 'labels', 'runner_id', 'runner_name',
                                                  'status', 'conclusion', 'started_at', 'completed_at')}, 'steps': steps})


def source_job(history):
    if min(job['run_attempt'] for job in history) != 1:
        raise ValueError('missing original logical job observation')
    latest = max(history, key=lambda j: j['run_attempt'])
    signature = execution_signature(latest)
    executed = [job for job in history if job.get('started_at') is not None
                and job.get('completed_at') is not None and positive(job.get('runner_id'))]
    same = [job for job in executed if execution_signature(job) == signature]
    origin = min(same, key=lambda j: j['run_attempt'])
    # A previous unstarted cancellation remains history, never execution proof.
    if any(j['started_at'] == latest['started_at'] and execution_signature(j) != signature for j in executed):
        raise ValueError('conflicting copied-execution lineage')
    return latest, origin


def rebuild_plan(root, run, plan):
    tested = P.git(root, 'rev-parse', 'HEAD').decode().strip()
    if P.git(root, 'status', '--porcelain', '--untracked-files=no'):
        raise ValueError('tracked checkout bytes differ from tested revision')
    if plan['planning_attempt'] > run['run_attempt']:
        raise ValueError('planning attempt is outside actual run history')
    if run.get('path') != '.github/workflows/test.yml' or run.get('event') not in P.EVENTS:
        raise ValueError('wrong workflow or event')
    arguments = dict(root=root, event=run['event'], run_id=str(run['id']), run_attempt=plan['planning_attempt'],
                     api_head_sha=run['head_sha'], tested_revision=tested)
    if run['event'] == 'pull_request':
        prs = run.get('pull_requests')
        if not isinstance(prs, list) or len(prs) != 1:
            raise ValueError('missing or ambiguous API PR revision identity')
        base, head = prs[0]['base']['sha'], prs[0]['head']['sha']
        if not P.hash_value(base, 40) or not P.hash_value(head, 40) or head != run['head_sha']:
            raise ValueError('invalid API PR revisions')
        with tempfile.TemporaryDirectory(prefix='ci-trusted-') as directory:
            trusted = Path(directory) / 'base'
            subprocess.run(['git', 'clone', '-q', '--no-hardlinks', '--no-checkout', str(root), str(trusted)],
                           capture_output=True, check=True, timeout=60)
            subprocess.run(['git', '-C', str(trusted), '-c', 'core.hooksPath=/dev/null',
                            'checkout', '-q', '--detach', base], capture_output=True, check=True, timeout=60)
            # Reuse the installed locked parser; never fetch or execute subject scripts.
            parser = ROOT / 'mcp/sdd-forge-mcp/node_modules/js-yaml'
            lock = 'mcp/sdd-forge-mcp/package-lock.json'
            if parser.exists() and (trusted / lock).is_file():
                if (ROOT / lock).read_bytes() != (trusted / lock).read_bytes():
                    raise ValueError('trusted parser lock differs from installed parser')
                shutil.copytree(parser, trusted / 'mcp/sdd-forge-mcp/node_modules/js-yaml')
            normal = P.make_plan(trusted_root=trusted, base=base, head=head, force_full='false', **arguments)
            forced = P.make_plan(trusted_root=trusted, base=base, head=head, force_full='true', **arguments)
            if P.canonical(plan) not in (P.canonical(normal), P.canonical(forced)):
                raise ValueError('plan disagrees with independent trusted reconstruction')
    else:
        expected = P.make_plan(trusted_root=root, **arguments)
        P.validate_plan(plan, expected=expected)
    workflow = P.read_workflow(root / '.github/workflows/test.yml')
    return workflow, R.load_catalog(root / 'tests/verification-catalog.json', root)


def receipt_profile(workflow, obligation):
    job = workflow['jobs'][obligation['job']]
    steps = [step for step in job['steps'] if 'run' in step
             and W.expand_matrix(step.get('name', ''), obligation['matrix']) == obligation['step']]
    if len(steps) != 1:
        raise ValueError('ambiguous receipt command')
    body = W.expand_matrix(steps[0]['run'], obligation['matrix'])
    profiles: list[str | None] = []
    for line in body.splitlines():
        args = shlex.split(line)
        scripts = {arg.removeprefix('./') for arg in args}
        if 'tests/run-ci-unwired.sh' in scripts:
            profiles.append('ci-posix-fallback')
        if 'tests/verification.py' in scripts and '--run' in args:
            profiles.append(args[args.index('--profile') + 1] if '--profile' in args else None)
    if len(profiles) != 1:
        raise ValueError('ambiguous runner invocation')
    return profiles[0]


def receipt_matches(receipt, obligation, catalog, root, plan, workflow):
    P.exact_fields(receipt, 'schema profile revision clean_before reusable catalog_sha256 selected results revision_after clean_after')
    suites = obligation['suites']
    if (receipt['schema'] != 'verification-receipt/v1' or receipt['revision'] != plan['tested_revision']
            or receipt['revision_after'] != plan['tested_revision'] or receipt['clean_before'] is not True
            or receipt['clean_after'] is not True or receipt['reusable'] is not False
            or receipt['catalog_sha256'] != plan['catalog_sha256']
            or not isinstance(receipt['selected'], list) or len(receipt['selected']) != len(set(receipt['selected']))
            or set(receipt['selected']) != set(suites) or not isinstance(receipt['results'], list)
            or len(receipt['results']) != len(suites)):
        raise ValueError('receipt execution binding mismatch')
    if receipt['profile'] != receipt_profile(workflow, obligation):
        raise ValueError('receipt profile differs from exact command')
    if receipt['profile'] is not None and (receipt['profile'] not in catalog['profiles']
                                         or not set(suites).issubset(catalog['profiles'][receipt['profile']])):
        raise ValueError('receipt profile mismatch')
    seen = set()
    for row in receipt['results']:
        P.exact_fields(row, 'suite source_sha256 status exit_code seconds')
        name = row['suite']
        if (not isinstance(name, str) or name in seen or name not in suites
                or row['status'] != 'passed' or type(row['exit_code']) is not int or row['exit_code'] != 0
                or type(row['seconds']) not in (int, float) or row['seconds'] < 0
                or (type(row['seconds']) is float and not math.isfinite(row['seconds']))
                or row['source_sha256'] != P.sha(P.bound_file(root, plan['tested_revision'], name))):
            raise ValueError('receipt suite result mismatch')
        seen.add(name)


def result_record(plan, reason, results):
    status = 'FAIL' if any(r['status'] == 'FAIL' for r in results) else 'PASS'
    result = dict(schema='verification-ci-result/v1', status=status, reason=reason,
                  run_id=plan['run_id'], api_head_sha=plan['api_head_sha'],
                  tested_revision=plan['tested_revision'], plan_sha256=plan['plan_sha256'], results=results)
    validate_result(result)
    return result


def inactive_a9(root, plan, workflow, histories, origins, run):
    active = W.a9_activation(root, plan, workflow)
    advisory = {o['id'] for o in plan['obligations'] if o['job'] == 'a9-advisory'}
    if active is None:
        if advisory:
            raise ValueError('missing A9 activation context')
        return set()
    detector_job = workflow['jobs']['a9-advisory-inputs']
    advisory_job = workflow['jobs']['a9-advisory']
    detector_history = histories[detector_job['name']]
    advisory_history = histories[advisory_job['name']]
    for history in (detector_history, advisory_history):
        if {j['run_attempt'] for j in history} != set(range(1, run['run_attempt'] + 1)):
            raise ValueError('incomplete A9 logical attempt history')
    latest, origin = origins[detector_job['name']]
    if (origin['run_attempt'] < plan['planning_attempt']
            or latest.get('status') != 'completed' or latest.get('conclusion') != 'success'
            or origin.get('status') != 'completed' or origin.get('conclusion') != 'success'
            or not isinstance(origin.get('labels'), list) or detector_job['runs-on'] not in origin['labels']):
        raise ValueError('A9 detector did not execute successfully')
    name = next(step['name'] for step in detector_job['steps'] if 'run' in step)
    matches = [step for step in origin['steps'] if step['name'] == name]
    if (len(matches) != 1 or matches[0].get('status') != 'completed'
            or matches[0].get('conclusion') != 'success'
            or not utc(origin['started_at']) <= utc(matches[0].get('started_at'))
            <= utc(matches[0].get('completed_at')) <= utc(origin['completed_at'])):
        raise ValueError('A9 detection step did not execute successfully')
    if active:
        return set()
    for job in advisory_history:
        # Skipped jobs can retain requested labels without assigning a runner.
        if (job.get('status') != 'completed' or job.get('conclusion') != 'skipped'
                or job.get('steps') != [] or job.get('labels') not in ([], [advisory_job['runs-on']])
                or not (job.get('runner_id') is None or type(job.get('runner_id')) is int and job['runner_id'] == 0)
                or job.get('runner_name') not in (None, '')):
            raise ValueError('inactive A9 requires actual nonexecuted skipped observations')
        # Skipped timestamps are API metadata, including reversed copied-rerun intervals.
        for field in ('started_at', 'completed_at'):
            if job.get(field) is not None:
                utc(job[field])
    return advisory


def aggregate(root, plan, observations, run_id, api_head_sha):
    P.validate_plan(plan)
    if not run_identity(run_id) or not P.hash_value(api_head_sha, 40):
        raise ValueError('invalid aggregate execution identity')
    manifest = read_json(observations / 'collection.json')
    validate_collection(manifest)
    results = [dict(obligation_id=o['id'], status='FAIL', reason='evidence-missing', job_id=None, source_attempt=None)
               for o in plan['obligations']]
    results += [dict(obligation_id=o['id'], status='NOT_SELECTED', reason=o['reason'], job_id=None, source_attempt=None)
                for o in plan['omissions']]
    try:
        run = read_reference(observations, manifest['run'])
        if (manifest['run_id'] != run_id or plan['run_id'] != run_id or str(run.get('id')) != run_id
                or not positive(run.get('id')) or not positive(run.get('run_attempt')) or run['run_attempt'] > MAX_ATTEMPTS
                or manifest['api_head_sha'] != api_head_sha or plan['api_head_sha'] != api_head_sha
                or run.get('head_sha') != api_head_sha
                or not isinstance(run.get('repository'), dict)
                or run['repository'].get('full_name') != manifest['repository']):
            raise ValueError('run observation binding mismatch')
        workflow, catalog = rebuild_plan(root, run, plan)
        jobs = validate_jobs(manifest, observations, run)
        identities = expanded_jobs(workflow)
        histories = {name: [j for j in jobs if j['name'] == name] for name in identities}
        origins, execution_origins = {}, {}
        for name, history in histories.items():
            ordered = sorted(history, key=lambda j: j['run_attempt'])
            for index, job in enumerate(ordered):
                if job.get('started_at') is not None and job.get('completed_at') is not None and positive(job.get('runner_id')):
                    latest, origin = source_job(ordered[:index + 1])
                    # Retain earlier executions, but never promote copied API IDs to origins.
                    execution_origins[origin['id']] = origin
                    if index == len(ordered) - 1:
                        origins[name] = latest, origin
        inactive = inactive_a9(root, plan, workflow, histories, origins, run)
        receipts = [(row, read_reference(observations, row)) for row in manifest['artifacts']]
        for row, _receipt in receipts:
            parts = row['path'].split('/')
            if len(parts) < 3 or parts[0] != 'artifacts':
                raise ValueError('receipt path lacks artifact identity')
            attempt, key = artifact_identity(parts[1], run_id)
            matching = [origin for origin in execution_origins.values() if origin['id'] == row['job_id']
                        and origin['run_attempt'] == row['source_attempt'] == attempt and name_key(origin['name']) == key]
            if len(matching) != 1:
                raise ValueError('receipt source is not original execution')
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError):
        for row in results:
            if row['status'] == 'FAIL':
                row['reason'] = 'evidence-mismatch'
        return result_record(plan, 'evidence-mismatch', results)
    for obligation, row in zip(plan['obligations'], results):
        if obligation['id'] in inactive:
            row.update(status='EXPECTED_SKIP', reason='advisory-inactive')
            continue
        names = [name for name, identity in identities.items()
                 if identity['job'] == obligation['job'] and identity['matrix'] == obligation['matrix']]
        if len(names) != 1 or names[0] not in origins:
            continue
        latest, origin = origins[names[0]]
        row.update(job_id=origin['id'], source_attempt=origin['run_attempt'])
        try:
            if (origin['run_attempt'] < plan['planning_attempt']
                    or latest.get('status') != 'completed' or latest.get('conclusion') != 'success'
                    or origin.get('status') != 'completed' or origin.get('conclusion') != 'success'
                    or not isinstance(origin.get('labels'), list) or obligation['runner'] not in origin['labels']):
                raise ValueError('selected native job did not succeed')
            matches = [s for s in origin['steps'] if s['name'] == obligation['step']]
            if len(matches) != 1 or matches[0].get('status') != 'completed' or matches[0].get('conclusion') != 'success':
                raise ValueError('selected step did not succeed')
            if obligation['receipt_required']:
                matched = []
                for reference_row, receipt in receipts:
                    if reference_row['job_id'] == origin['id'] and reference_row['source_attempt'] == origin['run_attempt']:
                        if set(receipt.get('selected', [])) == set(obligation['suites']):
                            receipt_matches(receipt, obligation, catalog, root, plan, workflow)
                            matched.append(receipt)
                if len(matched) != 1:
                    raise ValueError('missing or duplicate selected receipt')
            row.update(status='PASS', reason='verified')
        except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError):
            row['reason'] = 'execution-failed'
    return result_record(plan, 'execution-failed' if any(r['status'] == 'FAIL' for r in results) else 'verified', results)


def main(argv=None):
    class Parser(argparse.ArgumentParser):
        def error(self, message):
            raise ValueError('invalid command arguments')
    parser = Parser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    collect_parser = sub.add_parser('collect')
    collect_parser.add_argument('--repository', required=True)
    collect_parser.add_argument('--run-id', required=True)
    collect_parser.add_argument('--output-dir', type=Path, required=True)
    aggregate_parser = sub.add_parser('aggregate')
    for name in ('root', 'plan', 'observations'):
        aggregate_parser.add_argument('--' + name, type=Path, required=True)
    aggregate_parser.add_argument('--run-id', required=True)
    aggregate_parser.add_argument('--api-head-sha', required=True)
    aggregate_parser.add_argument('--output', type=Path)
    try:
        args = parser.parse_args(argv)
        if args.command == 'collect':
            collect(args.repository, args.run_id, args.output_dir)
            return 0
        if args.output and args.output.exists():
            raise ValueError('output must be create-only')
        try:
            root, observations = args.root.resolve(), args.observations.resolve()
        except RuntimeError as exc:
            raise ValueError('invalid input path resolution') from exc
        result = aggregate(root, read_json(args.plan), observations, args.run_id, args.api_head_sha)
        if args.output:
            write_json(args.output, result)
        print(P.canonical(result).decode('utf-8'))
        return 0 if result['status'] == 'PASS' else 1
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError):
        error = dict(schema='verification-ci-error/v1', reason='input-invalid',
                     message='Invalid or unavailable CI input; check the bound plan and complete observations.')
        validate_error(error)
        print(P.canonical(error).decode('utf-8'), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
