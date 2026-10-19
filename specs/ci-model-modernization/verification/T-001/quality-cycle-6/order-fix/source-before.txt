#!/usr/bin/env python3
"""Observe candidate impact selection; never execute, skip, or approve a check."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import re
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
# README is also a public contract. This is a hypothesis to measure, not safe selection.
README_SUITES = {
    'tests/workflow-documentation.tests.sh',
    'tests/design-system-contract.tests.sh',
    'tests/repository-release-validation.tests.sh',
    'tests/bump-version-gate.tests.sh',
    'tests/spec-review-loop.tests.sh',
}


def changed_paths(root, base, head):
    """No rename detection: both removed and added paths affect the decision."""
    if not base:
        return None, 'base-unavailable'
    try:
        revisions = []
        for ref in (base, head):
            revisions.append(subprocess.run(
                ['git', 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}'],
                cwd=root, check=True, capture_output=True, text=True,
            ).stdout.strip())
        result = subprocess.run(
            ['git', 'diff', '--no-renames', '--name-only', '-z', *revisions, '--'],
            cwd=root, check=True, capture_output=True,
        )
        return set(result.stdout.decode('utf-8').split('\0')) - {''}, 'diff-available'
    except (OSError, subprocess.CalledProcessError, UnicodeDecodeError):
        return None, 'diff-unavailable'


def propose(paths, full):
    if paths is None:
        return full.copy(), 'diff-unavailable'
    if not paths:
        return full.copy(), 'no-change-full-baseline'
    if paths != {'README.md'}:
        return full.copy(), 'unknown-or-shared-impact'
    if not README_SUITES.issubset(full):
        return full.copy(), 'candidate-suites-unavailable'
    return [suite for suite in full if suite in README_SUITES], 'readme-only-hypothesis'


def compare(receipts, full, selected, head, catalog_sha256, suite_hashes, workspace_state):
    """Only matching complete observations can finish comparison; skips are unknown."""
    statuses: dict[Any, Any] = {}
    rejected = 0
    for receipt in receipts:
        if (workspace_state != (head, True)
                or not isinstance(receipt, dict)
                or receipt.get('schema') != 'verification-receipt/v1'
                or not head or receipt.get('revision') != head
                or receipt.get('revision_after') != head
                or receipt.get('clean_before') is not True
                or receipt.get('clean_after') is not True
                or receipt.get('catalog_sha256') != catalog_sha256
                or not isinstance(receipt.get('results'), list)):
            rejected += 1
            continue
        for result in receipt['results']:
            if not isinstance(result, dict):
                continue
            suite, status = result.get('suite'), result.get('status')
            if (suite not in full or not suite_hashes.get(suite)
                    or result.get('source_sha256') != suite_hashes[suite]):
                continue
            valid = ((status == 'passed' and type(result.get('exit_code')) is int
                      and result['exit_code'] == 0)
                     or (status == 'failed' and type(result.get('exit_code')) is int
                         and result['exit_code'] != 0))
            if valid:
                # A later successful rerun must not erase an observed miss.
                if statuses.get(suite) != 'failed':
                    statuses[suite] = status
    missing = [suite for suite in full if suite not in statuses]
    missed = [suite for suite in full
              if statuses.get(suite) == 'failed' and suite not in selected]
    return {'status': 'incomplete' if missing or workspace_state != (head, True) else 'complete',
            'missed_failures': missed, 'unobserved': missing,
            'rejected_receipts': rejected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base')
    parser.add_argument('--head', default='HEAD')
    parser.add_argument('--profile', default='local-posix')
    parser.add_argument('--receipt', action='append', default=[])
    args = parser.parse_args()
    catalog_path = ROOT / 'tests/verification-catalog.json'
    from verification import load_catalog, repository_state
    try:
        catalog = load_catalog(catalog_path, ROOT)
    except (OSError, ValueError):
        parser.error('verification catalog unavailable or invalid')
    if args.profile not in catalog['profiles']:
        parser.error('unknown catalog profile')
    full = catalog['profiles'][args.profile]
    paths, diff_status = changed_paths(ROOT, args.base, args.head)
    selected, reason = propose(paths, full)
    try:
        head = subprocess.run(
            ['git', 'rev-parse', '--verify', '--end-of-options', args.head + '^{commit}'],
            cwd=ROOT, check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        head = None
    receipts = []
    for name in args.receipt:
        try:
            receipts.append(json.loads(Path(name).read_text(encoding='utf-8')))
        except (OSError, ValueError):
            receipts.append(None)
    digest = hashlib.sha256(catalog_path.read_bytes()).hexdigest()
    print(json.dumps({
        'schema': 'verification-impact/v1', 'mode': 'shadow',
        'required_checks': 'unchanged', 'profile': args.profile,
        'revision': head, 'diff_status': diff_status, 'reason': reason,
        'changed_path_count': len(paths) if paths is not None else None,
        'selected': selected, 'full_count': len(full),
        'comparison': compare(receipts, full, selected, head, digest, {
            suite: hashlib.sha256((ROOT / suite).read_bytes()).hexdigest()
            for suite in full
        }, repository_state(ROOT)),
    }, indent=2))
    return 0



# Explicit planning is separate from the historical observational interface.
PLAN_SCHEMA = 'verification-ci-plan/v1'
EVENTS = {'pull_request', 'push', 'merge_group', 'workflow_dispatch', 'release'}
REASONS = {'event-full', 'force-full', 'diff-unavailable', 'base-planner-unavailable',
           'binding-invalid', 'unknown-path', 'shared-change', 'unproven-category',
           'classified-change', 'input-invalid'}
PLANNER_FILES = ('tests/verification-impact.py', 'tests/verification-workflow.py',
                 'tests/verification.py', 'tests/verification-catalog.json')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'),
                      ensure_ascii=False, allow_nan=False).encode('utf-8')


def sha(value):
    return hashlib.sha256(value).hexdigest()


def strict_json(value):
    def unique(pairs):
        result = {}
        for key, item in pairs:
            if key in result:
                raise ValueError('duplicate JSON key')
            result[key] = item
        return result

    def invalid(_value):
        raise ValueError('nonfinite JSON number')

    if isinstance(value, bytes):
        value = value.decode('utf-8', errors='strict')
    result = json.loads(value, object_pairs_hook=unique, parse_constant=invalid)
    if not isinstance(result, dict):
        raise ValueError('JSON object required')
    canonical(result)  # Also reject overflow such as 1e999.
    return result


def exact_fields(value, fields):
    if not isinstance(value, dict) or set(value) != set(fields.split()):
        raise ValueError('invalid object fields')


def relative_path(value):
    return (isinstance(value, str) and bool(value) and not value.startswith('/')
            and not re.match(r'^[A-Za-z]:', value) and '\\' not in value
            and not any(ord(c) < 32 or ord(c) == 127 for c in value)
            and all(p not in ('', '.', '..') for p in value.split('/')))


def hash_value(value, size=64):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{' + str(size) + '}', value) is not None


def unique_strings(value, paths=False, nonempty=False):
    if (not isinstance(value, list) or (nonempty and not value)
            or any(not isinstance(x, str) or not x for x in value)
            or len(value) != len(set(value))
            or (paths and any(not relative_path(x) for x in value))):
        raise ValueError('invalid or duplicate string array')


def validate_plan(plan, expected=None):
    """Validate wire syntax, digest, and optionally a separately reconstructed plan.

    T-002 must supply its own reconstructed expected plan/inventory, not copy
    candidate fields into expected. A digest alone is not execution proof.
    """
    exact_fields(plan, 'schema mode reason event run_id planning_attempt api_head_sha '
                 'tested_revision base_revision pr_head_revision merge_base_revision '
                 'catalog_sha256 workflow_sha256 trusted_planner_sha256 plan_sha256 '
                 'changed_path_count groups obligations omissions activation_evidence')
    if (any(not isinstance(plan[k], str) for k in ('schema', 'mode', 'reason', 'event'))
            or plan['schema'] != PLAN_SCHEMA or plan['mode'] not in ('full', 'affected')
            or plan['reason'] not in REASONS or plan['event'] not in EVENTS
            or not isinstance(plan['run_id'], str) or not re.fullmatch(r'[1-9][0-9]*', plan['run_id'])
            or type(plan['planning_attempt']) is not int or plan['planning_attempt'] < 1):
        raise ValueError('invalid plan identity or enum')
    for key in ('api_head_sha', 'tested_revision'):
        if not hash_value(plan[key], 40):
            raise ValueError('invalid mandatory revision')
    for key in ('base_revision', 'pr_head_revision', 'merge_base_revision'):
        if plan[key] is not None and not hash_value(plan[key], 40):
            raise ValueError('invalid optional revision')
    for key in ('catalog_sha256', 'workflow_sha256', 'plan_sha256'):
        if not hash_value(plan[key]):
            raise ValueError('invalid digest')
    if plan['trusted_planner_sha256'] is None:
        if plan['mode'] != 'full' or plan['reason'] != 'base-planner-unavailable':
            raise ValueError('missing trusted source binding')
    elif not hash_value(plan['trusted_planner_sha256']):
        raise ValueError('invalid trusted source binding')
    count = plan['changed_path_count']
    if count is not None and (type(count) is not int or count < 0):
        raise ValueError('invalid changed path count')
    unique_strings(plan['groups'], nonempty=True)
    condition_outputs(plan, plan['groups'])
    if not isinstance(plan['obligations'], list) or not plan['obligations']:
        raise ValueError('missing obligations')
    ids = set()
    for row in plan['obligations']:
        exact_fields(row, 'id job matrix runner step command_sha256 suites receipt_required')
        if any(not isinstance(row[k], str) or not row[k].strip() for k in ('id', 'job', 'step')):
            raise ValueError('invalid obligation identity')
        if row['id'] in ids or row['job'] not in plan['groups']:
            raise ValueError('duplicate or unselected obligation')
        ids.add(row['id'])
        if (row['runner'] not in ('ubuntu-latest', 'macos-latest', 'windows-latest')
                or not hash_value(row['command_sha256']) or type(row['receipt_required']) is not bool
                or not isinstance(row['matrix'], dict)
                or any(not isinstance(k, str) or not k or type(v) not in (str, int, float, bool)
                       for k, v in row['matrix'].items())):
            raise ValueError('invalid command or matrix obligation')
        canonical(row['matrix'])
        unique_strings(row['suites'], paths=True)
    if not isinstance(plan['omissions'], list) or not isinstance(plan['activation_evidence'], list):
        raise ValueError('invalid omissions or activation')
    for row in plan['omissions']:
        exact_fields(row, 'id reason')
        if (not isinstance(row['id'], str) or not row['id'] or row['id'] in ids
                or not isinstance(row['reason'], str) or not re.fullmatch('[a-z]+(?:-[a-z]+)*', row['reason'])):
            raise ValueError('invalid omission or overlapping partition')
        ids.add(row['id'])
    categories = set()
    for row in plan['activation_evidence']:
        exact_fields(row, 'category path sha256 rule_sha256 baseline_revision')
        if (not isinstance(row['category'], str) or not re.fullmatch('[a-z0-9]+(?:-[a-z0-9]+)*', row['category'])
                or row['category'] in categories or not relative_path(row['path'])
                or not hash_value(row['sha256']) or not hash_value(row['rule_sha256'])
                or not hash_value(row['baseline_revision'], 40)):
            raise ValueError('invalid activation evidence')
        categories.add(row['category'])
    if plan['mode'] == 'full' and (plan['omissions'] or plan['activation_evidence']):
        raise ValueError('full plan cannot omit work')
    if plan['mode'] == 'affected' and (plan['reason'] != 'classified-change'
                                     or not categories or not count or plan['event'] != 'pull_request'
                                     or any(plan[k] is None for k in ('base_revision', 'pr_head_revision', 'merge_base_revision'))):
        raise ValueError('incomplete affected binding')
    if plan['plan_sha256'] != sha(canonical({k: v for k, v in plan.items() if k != 'plan_sha256'})):
        raise ValueError('plan digest mismatch')
    if expected is not None and canonical(plan) != canonical(expected):
        raise ValueError('plan disagrees with independently bound counterpart')


def condition_outputs(plan, groups):
    unique_strings(groups, nonempty=True)
    outputs = {}
    for group in groups:
        if not re.fullmatch('[a-z0-9]+(?:-[a-z0-9]+)*', group):
            raise ValueError('invalid condition group')
        key = 'run_' + group.replace('-', '_')
        if key in outputs:
            raise ValueError('condition key collision')
        outputs[key] = 'true' if group in plan['groups'] else 'false'
    if set(plan['groups']) - set(groups):
        raise ValueError('undeclared selected group')
    return outputs


def workflow_module():
    spec = importlib.util.spec_from_file_location('verification_workflow', Path(__file__).with_name('verification-workflow.py'))
    assert spec and spec.loader and spec.origin
    module = importlib.util.module_from_spec(spec)
    # Execute the verified source bytes, never a mutable bytecode cache.
    exec(compile(Path(spec.origin).read_bytes(), spec.origin, 'exec'), module.__dict__)
    return module


def read_workflow(path):
    # JSON is YAML, and is useful for hermetic fixture repositories.
    if path.read_bytes().lstrip().startswith(b'{'):
        return strict_json(path.read_bytes())
    return workflow_module().load_workflow(path, Path(__file__).resolve().parents[1])


def rules(catalog, workflow):
    data = catalog.get('impact', {'schema': 'verification-impact-rules/v1', 'categories': [], 'dependencies': {}})
    if set(data) - {'schema', 'categories', 'dependencies', 'non_suite_steps'}:
        raise ValueError('unknown impact rule property')
    exact_fields({k: v for k, v in data.items() if k != 'non_suite_steps'}, 'schema categories dependencies')
    if data['schema'] != 'verification-impact-rules/v1' or not isinstance(data['categories'], list) or not isinstance(data['dependencies'], dict):
        raise ValueError('invalid impact rules')
    suites = {s['path'] for s in catalog['suites']}
    groups = set(workflow['jobs']) - {'required-checks'}
    condition_outputs({'groups': []}, sorted(groups))
    for name, deps in data['dependencies'].items():
        unique_strings(deps, paths=True)
        if name not in suites or set(deps) - suites:
            raise ValueError('unknown dependency')
    declarations = data.get('non_suite_steps', [])
    if not isinstance(declarations, list):
        raise ValueError('invalid non-suite declarations')
    declared = set()
    for item in declarations:
        exact_fields(item, 'job step kind')
        if (item['job'] not in groups or item['kind'] not in ('build', 'audit')
                or not isinstance(item['step'], str) or (item['job'], item['step']) in declared):
            raise ValueError('invalid non-suite declaration')
        candidates = [s for s in workflow['jobs'][item['job']].get('steps', []) if s.get('name') == item['step']]
        if len(candidates) != 1 or candidates[0].get('run', '').strip() not in (
                'npm run build', 'npm test', 'npx tsc --noEmit', 'npm audit --omit=dev --audit-level=high'):
            raise ValueError('unrecognized non-suite command cannot authorize omission')
        declared.add((item['job'], item['step']))
    seen = set()
    for category in data['categories']:
        exact_fields(category, 'id paths prefixes suites groups active evidence')
        cid = category['id']
        if not isinstance(cid, str) or not re.fullmatch('[a-z0-9]+(?:-[a-z0-9]+)*', cid) or cid in seen:
            raise ValueError('duplicate or invalid category')
        seen.add(cid)
        for field in ('paths', 'suites', 'groups'):
            unique_strings(category[field], paths=field != 'groups')
        unique_strings(category['prefixes'])
        if (type(category['active']) is not bool or set(category['suites']) - suites
                or set(category['groups']) - groups
                or any(not p.endswith('/') or not relative_path(p[:-1])
                       or p in ('docs/', 'specs/', 'reports/', 'plugins/') for p in category['prefixes'])
                or not (category['paths'] or category['prefixes'])):
            raise ValueError('invalid category references')
        if category['evidence'] is not None:
            exact_fields(category['evidence'], 'path sha256 rule_sha256 baseline_revision')
            ev = category['evidence']
            if not relative_path(ev['path']) or not hash_value(ev['sha256']) or not hash_value(ev['rule_sha256']) or not hash_value(ev['baseline_revision'], 40):
                raise ValueError('invalid category evidence reference')
    return data


def rule_digest(catalog, workflow):
    data = rules(catalog, workflow)
    definition = {'categories': [{k: v for k, v in c.items() if k not in ('active', 'evidence')}
                                 for c in data['categories']], 'dependencies': data['dependencies'],
                  'suites': [{k: v for k, v in s.items() if k in ('path', 'runtime', 'args', 'host_args', 'requires', 'delegated_to', 'ci_jobs', 'optional_in', 'excluded')}
                             for s in catalog['suites']],
                  'profiles': catalog['profiles'], 'non_suite_steps': data.get('non_suite_steps', []), 'workflow': workflow}
    return sha(canonical(definition))


def dependency_closure(selected, groups, catalog, obligations):
    selected = set(selected)
    suites = {s['path'] for s in catalog['suites']}
    deps = catalog.get('impact', {}).get('dependencies', {})
    for key, values in deps.items():
        if key not in suites or set(values) - suites:
            raise ValueError('unknown suite dependency')
    if selected - suites:
        raise ValueError('unknown selected suite')
    while True:
        previous = selected.copy()
        for suite in previous:
            selected.update(deps.get(suite, []))
        for obligation in obligations:
            if obligation['job'] in groups or selected.intersection(obligation['suites']):
                selected.update(obligation['suites'])
        if previous == selected:
            return selected


def read_reference(root, revision, reference):
    exact_fields(reference, 'path sha256')
    if not relative_path(reference['path']) or not hash_value(reference['sha256']):
        raise ValueError('unsafe proof reference')
    try:
        payload = bound_file(root, revision, reference['path'])
    except (OSError, subprocess.CalledProcessError) as exc:
        raise ValueError('unavailable proof reference') from exc
    if sha(payload) != reference['sha256']:
        raise ValueError('proof reference digest mismatch')
    return strict_json(payload)


def validate_result_binding(result, plan, success):
    exact_fields(result, 'schema status reason run_id api_head_sha tested_revision plan_sha256 results')
    if (result['schema'] != 'verification-ci-result/v1'
            or result['status'] != ('PASS' if success else 'FAIL')
            or result['reason'] != ('verified' if success else 'execution-failed')
            or any(result[k] != plan[k] for k in ('run_id', 'api_head_sha', 'tested_revision', 'plan_sha256'))
            or not isinstance(result['results'], list)):
        raise ValueError('comparison result binding mismatch')
    expected = {o['id'] for o in plan['obligations']}
    seen, failed = set(), set()
    for row in result['results']:
        exact_fields(row, 'obligation_id status reason job_id source_attempt')
        oid = row['obligation_id']
        if (not isinstance(oid, str) or oid in seen or oid not in expected
                or row['status'] not in ('PASS', 'FAIL')
                or row['reason'] != ('verified' if row['status'] == 'PASS' else 'execution-failed')
                or type(row['job_id']) is not int or row['job_id'] < 1
                or type(row['source_attempt']) is not int or row['source_attempt'] < 1):
            raise ValueError('invalid comparison obligation result')
        seen.add(oid)
        if row['status'] == 'FAIL':
            failed.add(oid)
    if seen != expected or bool(failed) == success:
        raise ValueError('incomplete comparison or inconsistent verdict')
    return failed


def category_matches(category, path):
    return path in category['paths'] or any(path.startswith(p) for p in category['prefixes'])


def selected_obligations(categories, catalog, workflow, obligations):
    selected = {s for c in categories for s in c['suites']}
    groups = {g for c in categories for g in c['groups']}
    engine = workflow_module()
    declared = set()
    for declaration in catalog.get('impact', {}).get('non_suite_steps', []):
        job = workflow['jobs'][declaration['job']]
        step = next(s for s in job['steps'] if s.get('name') == declaration['step'])
        if job.get('if') is None and step.get('if') is None:
            declared.add((declaration['job'], declaration['step']))
    mandatory = set()
    runners = {'ubuntu-latest': 'Linux', 'macos-latest': 'macOS', 'windows-latest': 'Windows'}
    for obligation in obligations:
        job = workflow['jobs'][obligation['job']]
        steps = [s for s in job['steps'] if engine.expand_matrix(s.get('name', ''), obligation['matrix']) == obligation['step']]
        unknown = (len(steps) != 1 or engine.condition_value(job.get('if'), obligation['matrix'], runners[obligation['runner']]) is None
                   or engine.condition_value(steps[0].get('if'), obligation['matrix'], runners[obligation['runner']]) is None)
        if unknown or (not obligation['suites'] and (obligation['job'], obligation['step']) not in declared):
            mandatory.add(obligation['id'])
            selected.update(obligation['suites'])
    selected = dependency_closure(selected, groups, catalog, obligations)
    return [o for o in obligations if o['id'] in mandatory or o['job'] in groups
            or selected.intersection(o['suites'])]


def proof_blob(root, revision, path):
    if not hash_value(revision, 40) or not relative_path(path):
        raise ValueError('invalid baseline source reference')
    try:
        entry = git(root, 'ls-tree', '-z', revision, '--', path)
        if not entry.startswith((b'100644 blob ', b'100755 blob ')):
            raise ValueError('proof source must be a regular Git blob')
        return git(root, 'show', revision + ':' + path)
    except subprocess.CalledProcessError as exc:
        raise ValueError('proof source object unavailable') from exc

def execution_definition(path):
    name = path.rsplit('/', 1)[-1].lower()
    return (path.startswith(('tests/', 'contracts/', '.github/', 'scripts/', 'hooks/',
                             '.claude/', '.codex/', '.agents/', 'install', 'uninstall'))
            or any(part in path for part in ('/agents/', '/copilot-agents/', '/hooks/'))
            or name in ('agents.md', 'skill.md', 'package.json', 'package-lock.json',
                        'npm-shrinkwrap.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lock',
                        'bun.lockb', 'pyproject.toml', 'setup.py', 'setup.cfg', 'pipfile',
                        'pipfile.lock', 'poetry.lock', 'uv.lock', 'dockerfile', 'makefile')
            or bool(re.fullmatch(r'(?:requirements.*\.txt|tsconfig.*\.json)', name)))


def validate_proof_freshness(root, baseline, revision, catalog, baseline_catalog,
                             artifacts, consumer_sources):
    def without_activation(value):
        value = json.loads(canonical(value))
        for item in value.get('impact', {}).get('categories', []):
            item.pop('active', None)
            item.pop('evidence', None)
        return canonical(value)

    if without_activation(catalog) != without_activation(baseline_catalog):
        raise ValueError('catalog definitions changed since activation baseline')
    changed, status = changed_paths(root, baseline, revision)
    if status != 'diff-available':
        raise ValueError('activation baseline changes unavailable')
    categories = catalog['impact']['categories']
    for path in changed:
        if path == 'tests/verification-catalog.json':
            continue  # Only activation metadata differs; definitions were checked above.
        if execution_definition(path):
            raise ValueError('execution definition changed since activation baseline')
        ordinary_input = any(category_matches(item, path) for item in categories)
        if path in consumer_sources and not ordinary_input:
            raise ValueError('consumer source changed since activation baseline')
        if not ordinary_input and path not in artifacts:
            raise ValueError('unproven change since activation baseline')


def validate_activation(category, rule, root, revision, catalog, workflow, obligations):
    reference = category['evidence']
    if not category['active'] or not isinstance(reference, dict):
        raise ValueError('inactive or unproven category')
    exact_fields(reference, 'path sha256 rule_sha256 baseline_revision')
    if reference['rule_sha256'] != rule or not hash_value(reference['baseline_revision'], 40):
        raise ValueError('activation definition mismatch')
    proof = read_reference(root, revision, {k: reference[k] for k in ('path', 'sha256')})
    fields = 'schema category rule_sha256 baseline_revision full_plan full_result consumer_inventory mutation_evidence'
    exact_fields(proof, fields + (' supporting_evidence' if 'supporting_evidence' in proof else ''))
    artifacts = {reference['path']}
    artifacts.update(proof[key]['path'] for key in (
        'full_plan', 'full_result', 'consumer_inventory', 'mutation_evidence')
        if isinstance(proof[key], dict) and isinstance(proof[key].get('path'), str))
    baseline = reference['baseline_revision']
    if (proof['schema'] != 'verification-ci-activation/v1' or proof['category'] != category['id']
            or proof['rule_sha256'] != rule or proof['baseline_revision'] != baseline):
        raise ValueError('activation proof identity mismatch')
    full = read_reference(root, revision, proof['full_plan'])
    validate_plan(full)
    if full['mode'] != 'full' or full['tested_revision'] != baseline:
        raise ValueError('baseline is not a full plan')
    # Rebind historical definitions and all expanded obligations to actual Git
    # blobs, not just a saved plan's claims. Product files may change normally.
    baseline_catalog = strict_json(proof_blob(root, baseline, 'tests/verification-catalog.json'))
    baseline_workflow_bytes = proof_blob(root, baseline, '.github/workflows/test.yml')
    if (full['catalog_sha256'] != sha(proof_blob(root, baseline, 'tests/verification-catalog.json'))
            or full['workflow_sha256'] != sha(baseline_workflow_bytes)
            or full['obligations'] != obligations
            or rule_digest(baseline_catalog, workflow) != rule
            or sha(baseline_workflow_bytes) != sha((root / '.github/workflows/test.yml').read_bytes())):
        raise ValueError('baseline definition or inventory mismatch')
    validate_result_binding(read_reference(root, revision, proof['full_result']), full, True)
    consumers = read_reference(root, revision, proof['consumer_inventory'])
    exact_fields(consumers, 'schema baseline_revision rule_sha256 consumers')
    if (consumers['schema'] != 'verification-ci-consumers/v1'
            or consumers['baseline_revision'] != baseline or consumers['rule_sha256'] != rule
            or not isinstance(consumers['consumers'], list)):
        raise ValueError('consumer inventory identity mismatch')
    selectors = set(category['paths'] + category['prefixes'])
    seen = set()
    consumer_sources = set()
    for item in consumers['consumers']:
        exact_fields(item, 'input suites groups sources')
        if (not isinstance(item['input'], str) or item['input'] not in selectors or item['input'] in seen
                or item['suites'] != category['suites'] or item['groups'] != category['groups']
                or not isinstance(item['sources'], list) or not item['sources']):
            raise ValueError('consumer declaration mismatch')
        seen.add(item['input'])
        source_paths = set()
        for source in item['sources']:
            exact_fields(source, 'path sha256')
            if (not relative_path(source['path']) or source['path'] in source_paths
                    or not hash_value(source['sha256'])
                    or sha(proof_blob(root, baseline, source['path'])) != source['sha256']):
                raise ValueError('source consumer evidence mismatch')
            source_paths.add(source['path'])
            consumer_sources.add(source['path'])
    if seen != selectors:
        raise ValueError('incomplete source-consumer inventory')
    mutations = read_reference(root, revision, proof['mutation_evidence'])
    exact_fields(mutations, 'schema baseline_revision rule_sha256 cases')
    if (mutations['schema'] != 'verification-ci-mutations/v1'
            or mutations['baseline_revision'] != baseline or mutations['rule_sha256'] != rule
            or not isinstance(mutations['cases'], list) or not mutations['cases']):
        raise ValueError('mutation evidence identity mismatch')
    covered: set[str] = set()
    case_inputs: set[str] = set()
    selected = {o['id'] for o in selected_obligations([category], catalog, workflow, obligations)}
    for case in mutations['cases']:
        exact_fields(case, 'input plan result')
        if (not relative_path(case['input']) or not category_matches(category, case['input'])
                or case['input'] in case_inputs):
            raise ValueError('mutation input mismatch')
        case_inputs.add(case['input'])
        mutation_plan = read_reference(root, revision, case['plan'])
        validate_plan(mutation_plan)
        tested = mutation_plan['tested_revision']
        changed, _ = changed_paths(root, baseline, tested)
        if (mutation_plan['mode'] != 'full' or mutation_plan['obligations'] != obligations
                or not changed or case['input'] not in changed
                or mutation_plan['catalog_sha256'] != full['catalog_sha256']
                or mutation_plan['workflow_sha256'] != full['workflow_sha256']
                or sha(proof_blob(root, tested, 'tests/verification-catalog.json')) != full['catalog_sha256']
                or sha(proof_blob(root, tested, '.github/workflows/test.yml')) != full['workflow_sha256']):
            raise ValueError('mutation plan mismatch')
        failed = validate_result_binding(read_reference(root, revision, case['result']), mutation_plan, False)
        artifacts.update((case['plan']['path'], case['result']['path']))
        if not failed.issubset(selected):
            raise ValueError('selection misses a mutation failure')
        covered.update(s for s in selectors if case['input'] == s or (s.endswith('/') and case['input'].startswith(s)))
    if covered != selectors:
        raise ValueError('incomplete mutation coverage')
    supporting = proof.get('supporting_evidence', [])
    if not isinstance(supporting, list):
        raise ValueError('invalid supporting evidence')
    for item in supporting:
        exact_fields(item, 'path sha256')
        path = item['path']
        if (not relative_path(path) or not hash_value(item['sha256']) or path in artifacts
                or execution_definition(path)
                or not re.fullmatch(r'(?:reports/verification/|specs/[a-z0-9-]+/verification/).+\.(?:json|md|txt|log|patch|csv|yml|yaml)', path)
                or sha(bound_file(root, revision, path)) != item['sha256']):
            raise ValueError('invalid or unbound passive supporting evidence')
        artifacts.add(path)
    validate_proof_freshness(root, baseline, revision, catalog, baseline_catalog,
                             artifacts, consumer_sources)
    return {'category': category['id'], **reference}


def classify(paths, catalog, workflow, obligations, root, revision):
    data = rules(catalog, workflow)
    categories: dict[str, Any] = {}
    for path in paths:
        matches = [c for c in data['categories'] if category_matches(c, path)]
        if not matches:
            return obligations, [], 'unknown-path'
        categories.update((c['id'], c) for c in matches)
    try:
        rule = rule_digest(catalog, workflow)
        evidence = [validate_activation(c, rule, root, revision, catalog, workflow, obligations)
                    for c in categories.values()]
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError):
        return obligations, [], 'unproven-category'
    selected = selected_obligations(categories.values(), catalog, workflow, obligations)
    return selected, evidence, 'classified-change'


def git(root, *args):
    return subprocess.run(['git', '-C', str(root), *args], check=True, capture_output=True).stdout


def bound_file(root, revision, path):
    target = root / path
    if not relative_path(path) or target.is_symlink() or not target.resolve().is_relative_to(root.resolve()):
        raise ValueError('unsafe input path')
    blob = git(root, 'show', revision + ':' + path)
    if target.read_bytes() != blob:
        raise ValueError('input bytes differ from bound revision')
    return blob


def source_inventory(root, catalog_bytes=None):
    paths = set(PLANNER_FILES)
    for path in ('tests/verification-timings.json', 'tests/run-ci-unwired.sh',
                 'mcp/sdd-forge-mcp/package-lock.json'):
        if (root / path).is_file():
            paths.add(path)
    package = root / 'mcp/sdd-forge-mcp/node_modules/js-yaml'
    if package.exists():
        for path in package.rglob('*'):
            if path.is_file() and path.suffix in ('.json', '.js', '.cjs', '.mjs'):
                if path.is_symlink() or not path.resolve().is_relative_to(root):
                    raise ValueError('parser module escapes trusted checkout')
                paths.add(path.relative_to(root).as_posix())
    return [{'path': p, 'sha256': sha(catalog_bytes if p == 'tests/verification-catalog.json'
                                     and catalog_bytes is not None else (root / p).read_bytes())}
            for p in sorted(paths)]


def trusted_inventory(root, revision):
    if git(root, 'rev-parse', 'HEAD').decode().strip() != revision:
        raise ValueError('trusted root is not exact base')
    inventory = source_inventory(root)
    for item in inventory:
        if '/node_modules/' not in item['path']:
            bound_file(root, revision, item['path'])
    return inventory


def revision_inputs(root, event, api_head, tested, base, head):
    if git(root, 'rev-parse', 'HEAD').decode().strip() != tested:
        raise ValueError('tested revision is not actual checkout HEAD')
    result = {'base_revision': None, 'pr_head_revision': None, 'merge_base_revision': None}
    if event != 'pull_request':
        if api_head != tested:
            raise ValueError('non-PR API head differs from tested revision')
        return result, None, None
    for field, value in (('base_revision', base), ('pr_head_revision', head)):
        if hash_value(value, 40):
            try:
                if git(root, 'rev-parse', '--verify', value + '^{commit}').decode().strip() == value:
                    result[field] = value
            except subprocess.CalledProcessError:
                pass
    if not all(result[k] for k in ('base_revision', 'pr_head_revision')):
        return result, None, 'diff-unavailable'
    if api_head != head:
        return result, None, 'binding-invalid'
    try:
        merge_base = git(root, 'merge-base', base, head).decode().strip()
    except subprocess.CalledProcessError:
        return result, None, 'diff-unavailable'
    result['merge_base_revision'] = merge_base
    if tested != head:
        parents = git(root, 'show', '-s', '--format=%P', tested).decode().strip().split()
        if parents != [base, head]:
            return result, None, 'binding-invalid'
    paths, status = changed_paths(root, merge_base, head)
    if status != 'diff-available':
        return result, None, 'diff-unavailable'
    if tested != head:
        resolution, _ = changed_paths(root, head, tested)
        if resolution is None:
            return result, None, 'diff-unavailable'
        paths.update(resolution)
    return result, paths, None


def make_plan(root, trusted_root, event, run_id, run_attempt, api_head_sha,
              tested_revision, base=None, head=None, force_full=None):
    root, trusted_root = Path(root).resolve(), Path(trusted_root).resolve()
    if (event not in EVENTS or not isinstance(run_id, str) or not re.fullmatch('[1-9][0-9]*', run_id)
            or type(run_attempt) is not int or run_attempt < 1
            or not hash_value(api_head_sha, 40) or not hash_value(tested_revision, 40)):
        raise ValueError('missing or invalid mandatory execution identity')
    current = Path(__file__).resolve().parents[1]
    # Bootstrap does not import the PR implementation to decide omissions.
    # A compatible base is re-executed in an isolated Python process.
    if event == 'pull_request' and current != trusted_root and hash_value(base, 40):
        try:
            trusted_inventory(trusted_root, base)
            source = (trusted_root / 'tests/verification-impact.py').read_text(encoding='utf-8')
            supported = 'verification-ci-plan/v1' in source and 'def plan_main(' in source
        except (OSError, ValueError, subprocess.CalledProcessError):
            supported = False
        if supported:
            command = [sys.executable, '-I', '-B', str(trusted_root / 'tests/verification-impact.py'),
                       '--plan', '--root', str(root), '--trusted-root', str(trusted_root),
                       '--event', event, '--run-id', run_id, '--run-attempt', str(run_attempt),
                       '--api-head-sha', api_head_sha, '--tested-revision', tested_revision]
            for key, value in (('base', base), ('head', head), ('force-full', force_full)):
                if value is not None:
                    command.extend(['--' + key, value])
            completed = subprocess.run(command, capture_output=True, timeout=120)
            if completed.returncode:
                raise ValueError('trusted planner rejected input')
            result = strict_json(completed.stdout)
            validate_plan(result)
            return result
    identities, paths, invalid = revision_inputs(root, event, api_head_sha, tested_revision, base, head)
    catalog_bytes = bound_file(root, tested_revision, 'tests/verification-catalog.json')
    workflow_bytes = bound_file(root, tested_revision, '.github/workflows/test.yml')
    catalog = strict_json(catalog_bytes)
    workflow = read_workflow(root / '.github/workflows/test.yml')
    engine = workflow_module()
    runner = engine.runner_module()
    # Use the existing catalog validation without executing any subject suite.
    catalog = runner.load_catalog(root / 'tests/verification-catalog.json', root)
    catalog = {k: v for k, v in catalog.items() if not k.startswith('_')}
    rules(catalog, workflow)
    if engine.coverage_errors(workflow, catalog):
        raise ValueError('workflow does not prove required catalog coverage')
    weights = None
    if 'ci-posix-fallback' in catalog['profiles']:
        bound_file(root, tested_revision, 'tests/verification-timings.json')
        weights = runner.load_weights(root / 'tests/verification-timings.json')
    obligations = engine.plan_obligations(workflow, catalog, weights=weights)
    current = Path(__file__).resolve().parents[1]
    inventory = None
    if event == 'pull_request' and identities['base_revision']:
        try:
            inventory = trusted_inventory(trusted_root, base)
            # The executing implementation and imports must themselves be the base bytes.
            for item in inventory:
                if item['path'].endswith('.py') and sha((current / item['path']).read_bytes()) != item['sha256']:
                    raise ValueError('executing planner is not trusted base source')
        except (OSError, ValueError, subprocess.CalledProcessError):
            inventory = None
    elif event != 'pull_request':
        inventory = source_inventory(current, catalog_bytes)
    # Explicit branches avoid allowing lower-priority classification to override full.
    if event != 'pull_request':
        reason = 'event-full'
    elif inventory is None:
        reason = 'base-planner-unavailable'
    elif force_full != 'false':
        reason = 'force-full'
    elif invalid:
        reason = invalid
    elif git(root, 'status', '--porcelain', '--untracked-files=no'):
        reason = 'binding-invalid'
    elif not paths:
        reason = 'diff-unavailable'
    else:
        shared = ('tests/', 'contracts/', '.github/', 'scripts/', 'install', 'uninstall',
                  'reports/', 'specs/', 'human-copy/', 'sdd/', '.claude/', '.codex/', '.agents/', 'hooks/')
        reason = 'shared-change' if any(p.startswith(shared) or p.endswith(('AGENTS.md', 'SKILL.md'))
                     or any(part in p for part in ('/hooks/', '/agents/', '/copilot-agents/', 'guard', 'authorization'))
                     for p in paths) else 'unknown-path'
    selected, evidence = obligations, []
    if reason == 'unknown-path':
        trusted_catalog = strict_json(bound_file(trusted_root, base, 'tests/verification-catalog.json'))
        if catalog != trusted_catalog:
            reason = 'shared-change'
        else:
            selected, evidence, reason = classify(paths, trusted_catalog, workflow, obligations, trusted_root, base)
    mode = 'affected' if reason == 'classified-change' else 'full'
    selected_ids = {o['id'] for o in selected}
    omissions = [{'id': o['id'], 'reason': 'unrelated-category'} for o in obligations if o['id'] not in selected_ids]
    result = dict(schema=PLAN_SCHEMA, mode=mode, reason=reason, event=event,
                  run_id=run_id, planning_attempt=run_attempt, api_head_sha=api_head_sha,
                  tested_revision=tested_revision, **identities,
                  catalog_sha256=sha(catalog_bytes), workflow_sha256=sha(workflow_bytes),
                  trusted_planner_sha256=sha(canonical(inventory)) if inventory is not None else None,
                  changed_path_count=len(paths) if paths is not None else None,
                  groups=sorted({o['job'] for o in selected}), obligations=selected,
                  omissions=omissions, activation_evidence=evidence)
    result['plan_sha256'] = sha(canonical(result))
    validate_plan(result)
    return result


def plan_main(argv):
    class PlanParser(argparse.ArgumentParser):
        def error(self, message):
            raise ValueError(message)

    parser = PlanParser(description='Produce a revision-bound CI plan, never execution success.')
    parser.add_argument('--plan', action='store_true', required=True)
    for name in ('root', 'trusted-root', 'event', 'run-id', 'run-attempt', 'api-head-sha', 'tested-revision'):
        parser.add_argument('--' + name, required=True)
    for name in ('base', 'head', 'force-full', 'output', 'github-output'):
        parser.add_argument('--' + name)
    try:
        flags = [v.split('=', 1)[0] for v in argv if v.startswith('--')]
        if len(flags) != len(set(flags)):
            raise ValueError('duplicate planning argument')
        args = vars(parser.parse_args(argv))
        args.pop('plan')
        output, github_output = args.pop('output'), args.pop('github_output')
        if not re.fullmatch('[1-9][0-9]*', args['run_attempt']):
            raise ValueError('run-attempt must be a positive integer')
        args['run_attempt'] = int(args['run_attempt'])
        result = make_plan(**args)
        text = json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + '\n'
        if output:
            with Path(output).open('x', encoding='utf-8') as handle:
                handle.write(text)
        if github_output:
            workflow = read_workflow(Path(args['root']) / '.github/workflows/test.yml')
            values = condition_outputs(result, sorted(set(workflow['jobs']) - {'required-checks'}))
            with Path(github_output).open('a', encoding='utf-8') as handle:
                handle.write(''.join(key + '=' + value + '\n' for key, value in values.items()))
        print(text, end='')
        return 0
    except subprocess.TimeoutExpired:
        print(json.dumps({'schema': 'verification-ci-error/v1', 'reason': 'input-invalid',
                          'message': 'Planning subprocess timed out; verify local dependencies and retry.'}),
              file=sys.stderr)
        return 2
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print(json.dumps({'schema': 'verification-ci-error/v1', 'reason': 'input-invalid',
                          'message': 'Invalid planning input, revision binding, or output destination.'}), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(plan_main(sys.argv[1:]) if '--plan' in sys.argv[1:] else main())
