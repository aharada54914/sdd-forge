#!/usr/bin/env python3
"""Authenticate A9 promotion evidence; optionally publish exactly its approved Context.

Existing HMAC Context approval and an operator-signed decision are both required.
This tool never signs, approves, edits trust, or starts a live evaluation.
"""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parents[1]

def load(relative, name):
    spec = importlib.util.spec_from_file_location(name, SOURCE / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

ROLLBACK = load('scripts/validate-a9-rollback-receipt.py', 'promotion_rollback')
PREFLIGHT = load('scripts/validate-a9-candidate.py', 'promotion_preflight')
HANDOFF = load('tests/lib/cross-runtime-consumer-evidence.py', 'promotion_handoff')
APPROVAL, PROOF = ROLLBACK.APPROVAL, ROLLBACK.PROOF
require, keys, utc = ROLLBACK.require, ROLLBACK.keys, ROLLBACK.utc
TARGETS = ROLLBACK.TARGETS
FIXED = {'context': TARGETS[0], 'approval': TARGETS[1], 'anchor': TARGETS[2],
         'approvers': 'sdd/approver-registry.yaml',
         'trusted_signers': 'plugins/sdd-review-loop/references/a8-trusted-signers.json',
         'registry': 'contracts/capability-registry.json'}
EVIDENCE = {'resolver', 'facet_manifest', 'release_cycle', 'findings', 'compatibility', 'cross_runtime'}
CANDIDATE = ('candidate_context', 'candidate_approval', 'candidate_snapshot')
CRITERIA = {'false_positive_triage': 'PASS', 'critical_major_resolution': 'PASS',
            'three_platforms': 'PASS', 'rollback_rehearsal': 'PASS'}
OLD = {'spec_profile': 'full', 'artifact_layout': 'legacy-seven-layer', 'capability_enforcement': 'advisory'}
NEW = {'spec_profile': 'full', 'artifact_layout': 'facet-hybrid', 'capability_enforcement': 'required'}


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.PIPE, timeout=30).decode().strip()


def document(check, binding):
    check.bound(binding)
    return PREFLIGHT.read_document(check.path(binding['path']))


def findings(check, record, cycle):
    keys(record, {'schema', 'base_sha', 'head_sha', 'observations', 'dispositions'}, 'findings inventory')
    require(record['schema'] == 'a9-advisory-findings/v1' and
            all(record[k] == cycle[k] for k in ('base_sha', 'head_sha')), 'findings release boundary differs')
    expected = {pr['number']: pr['head_sha'] for pr in cycle['pull_requests']}
    observed, reports = {}, set()
    for report in record['observations']:
        keys(report, {'pr', 'head_sha', 'source', 'findings'}, 'finding observation')
        number = report['pr']
        require(type(number) is int and number in expected and number not in reports and
                report['head_sha'] == expected[number], 'finding observations must cover each release PR once')
        reports.add(number)
        # The signed inventory cannot silently omit an item from its original export.
        source = document(check, report['source'])
        require(source == {k: report[k] for k in ('pr', 'head_sha', 'findings')}, 'findings differ from their raw export')
        for item in report['findings']:
            keys(item, {'id', 'kind', 'severity'}, 'observed finding')
            require(isinstance(item['id'], str) and bool(item['id']) and
                    item['kind'] in ('guard-false-positive', 'gate-false-positive', 'finding') and
                    item['severity'] in ('Critical', 'Major', 'Minor', 'Info'), 'invalid observed finding')
            identity = (number, item['id'])
            require(identity not in observed, 'duplicate observed finding')
            observed[identity] = item
    require(reports == set(expected), 'findings inventory omits a release PR')
    disposed = set()
    for item in record['dispositions']:
        keys(item, {'pr', 'id', 'status', 'wfi'}, 'finding disposition')
        require(type(item['pr']) is int and isinstance(item['id'], str) and bool(item['id']), 'invalid disposition identity')
        identity = (item['pr'], item['id'])
        require(identity in observed and identity not in disposed and
                item['status'] in ('resolved', 'open'), 'disposition must identify one observed finding')
        disposed.add(identity)
        finding = observed[identity]
        if finding['kind'] != 'finding':
            binding = item['wfi']
            raw = check.bound(binding)
            match = re.fullmatch(r'docs/workflow-improvements/(WFI-[0-9]{3,})\.md', binding['path'])
            require(match is not None, 'false positive must reference an existing WFI Markdown artifact')
            text = raw.decode('utf-8')
            def section(name):
                matches = re.findall(r'(?ms)^## ' + re.escape(name) + r'\s*\n(.*?)(?=^## |\Z)', text)
                require(len(matches) == 1, 'WFI section is absent or ambiguous')
                return re.sub(r'(?s)<!--.*?-->', '', matches[0]).strip()
            identifiers = re.findall(r'(?m)^\s*(WFI-[0-9]{3,})\s*$', section('WFI-ID'))
            statuses = re.findall(r'(?m)^Status: ([^\r\n]+)$', section('Status'))
            require(identifiers == [match.group(1)] and len(statuses) == 1 and
                    statuses[0] in ('Draft', 'Approved', 'Applied', 'Verified', 'Rejected', 'Regressed'),
                'WFI identity or status differs from its artifact')
            problem = section('Problem Evidence')
            require(re.search(r'(?<![\w-])' + re.escape(item['id']) + r'(?![\w-])', problem) and
                    re.search(r'\bPR #' + str(item['pr']) + r'(?![\w-])', problem) and '{{' not in problem,
                    'WFI does not identify the observed false positive')
            committed = subprocess.check_output(['git', 'show', cycle['head_sha'] + ':' + binding['path']],
                                                cwd=check.root, stderr=subprocess.PIPE, timeout=30)
            require(committed == raw, 'WFI was not saved in the approved release revision')
        else:
            require(item['wfi'] is None, 'ordinary finding has an unexpected WFI receipt')
        require(finding['severity'] not in ('Critical', 'Major') or item['status'] == 'resolved',
                'unresolved Critical/Major finding')
    require(disposed == set(observed), 'untriaged advisory finding')


def compatibility(check, record, head):
    keys(record, {'schema', 'head_sha', 'results'}, 'compatibility evidence')
    require(record['schema'] == 'a9-compatibility-observations/v1' and record['head_sha'] == head,
            'compatibility evidence is stale')
    expected = {(platform, suite) for platform in ('linux', 'macos', 'windows')
                for suite in ('compatibility-byte-identical', 'structural-compatibility')}
    seen = set()
    for row in record['results']:
        keys(row, {'platform', 'suite', 'source_sha256', 'exit_code', 'log'}, 'compatibility result')
        platform = row['platform']
        suffix = '.tests.ps1' if platform == 'windows' else '.tests.sh'
        suite = next((name for name in ('compatibility-byte-identical', 'structural-compatibility')
                      if row['suite'] == 'tests/' + name + suffix), None)
        identity = (platform, suite)
        require(identity in expected and identity not in seen and type(row['exit_code']) is int and row['exit_code'] == 0,
                'compatibility suite missing, duplicated or failed')
        seen.add(identity)
        source = subprocess.check_output(['git', 'show', head + ':' + row['suite']], cwd=check.root, stderr=subprocess.PIPE, timeout=30)
        require(ROLLBACK.digest(source) == row['source_sha256'], 'compatibility suite source is stale')
        log = check.bound(row['log']).decode('utf-8')
        require(re.search(r'(?m)^[1-9][0-9]* passed, 0 failed\s*\Z', log) and
                not re.search(r'(?m)^\s*(?:SKIP|FAIL)(?::|\s)', log), 'compatibility log failed or skipped required coverage')
    require(seen == expected, 'compatibility evidence must cover both existing suites on all three platforms')


def completed_host_proof(check, trace, record, decided):
    proof = trace['canary_case']['proof']
    keys(proof, {'schema', 'aggregate', 'records_dir', 'artifacts', 'stdout'}, 'signed host proof receipt')
    # Execute only this installed tool's reviewed code, never code supplied by an evidence pack.
    scripts = 'plugins/sdd-quality-loop/scripts/'
    for name in ('validate-live-host-proof.py', 'check-hook-activation-handshake.py', 'canonicalize-sdd-yaml.py'):
        require(check.read(scripts + name) == (SOURCE / scripts / name).read_bytes(), 'current proof verifier differs from this tool')
    relative = record['proof_records_dir']
    require(isinstance(relative, str) and (relative == 'tests/hook-activation-live-proof' or relative.endswith('/tests/hook-activation-live-proof')),
            'proof records must identify a captured proof root')
    records = check.path(relative + '/nonce-ledger.json').parent
    # Cache original raw bytes before revalidation so later publication detects concurrent changes.
    for path in records.rglob('*'):
        if not path.is_dir():
            check.read(path.relative_to(check.root).as_posix())
    for relative_source in PROOF.CONSUMERS.values():
        captured = records.parent.parent / relative_source
        check.read(captured.relative_to(check.root).as_posix())
    result = HANDOFF.read_only_proof(check.root, records)
    require({k: v for k, v in proof.items() if k not in ('records_dir', 'stdout')} ==
            {k: v for k, v in result.items() if k != 'records_dir'}, 'captured proof roster differs from current signed validation')
    # records_dir is a transport locator; artifact refs are canonical within their declared root.
    for artifact in result['artifacts']:
        base = records if artifact['kind'] in ('record', 'nonce_ledger') else check.root
        relative_artifact = (base / artifact['ref']).relative_to(check.root).as_posix()
        require('sha256:' + ROLLBACK.digest(check.read(relative_artifact)) == artifact['sha256'], 'proof input changed')
        if artifact['kind'] == 'record':
            signed = check.document(relative_artifact)
            require(PROOF.parse_utc(signed['session_end'], 'session_end') <= decided, 'host proof postdates the human decision')
    stdout = check.bound(record['proof_stdout'])
    require(proof['stdout'] == {'kind': 'validator_stdout', 'ref': 'live-host-proof.stdout.log',
            'sha256': 'sha256:' + ROLLBACK.digest(stdout)} and stdout in (b'discharged\n', b'discharged\r\n'),
            'proof completion output differs from the original receipt')


def cross_runtime(check, record, head, decided):
    keys(record, {'schema', 'head_sha', 'suite', 'source_sha256', 'exit_code', 'trace', 'logs', 'output', 'proof_records_dir', 'proof_stdout'}, 'cross-runtime evidence')
    require(record['schema'] == 'a9-cross-runtime-observation/v1' and record['head_sha'] == head and
            record['suite'] in ('tests/cross-runtime-handoff.tests.sh', 'tests/cross-runtime-handoff.tests.ps1') and
            type(record['exit_code']) is int and record['exit_code'] == 0, 'cross-runtime evidence is stale or failed')
    source = subprocess.check_output(['git', 'show', head + ':' + record['suite']], cwd=check.root, stderr=subprocess.PIPE, timeout=30)
    require(ROLLBACK.digest(source) == record['source_sha256'], 'cross-runtime suite source is stale')
    trace = document(check, record['trace'])
    require(trace['schema'] == 'cross-runtime-handoff-trace/v1' and trace['result'] == 'PASS' and
            trace['coverage_complete'] is True and
            {k: v for k, v in trace['canary_case'].items() if k != 'proof'} == {'present': True, 'result': 'PASS', 'skip_reason': None},
            'cross-runtime handoff lacks complete successful canary coverage')
    completed_host_proof(check, trace, record, decided)
    require(len(trace['steps']) == 2, 'cross-runtime handoff is incomplete')
    refs = set()
    for step, pair in zip(trace['steps'], (('claude', 'codex'), ('codex', 'copilot'))):
        require((step['producer_runtime'], step['consumer_runtime']) == pair and step['result'] == 'PASS' and
                step['invocation_mode'] == 'automated' and re.fullmatch(r'[0-9a-f]{32}', step['mutation_nonce']) and
                all(re.fullmatch(r'sha256:[0-9a-f]{64}', step[k]) for k in ('artifact_initial_sha256', 'artifact_final_sha256')) and
                step['artifact_initial_sha256'] != step['artifact_final_sha256'], 'cross-runtime step was not completed')
        require(len(step['evidence_refs']) == 2, 'cross-runtime native logs are missing')
        refs.update(step['evidence_refs'])
    require(isinstance(record['logs'], dict) and set(record['logs']) == refs, 'cross-runtime native log roster differs')
    logs = {ref: check.bound(binding) for ref, binding in record['logs'].items()}
    require(all(logs.values()), 'cross-runtime native log is empty')
    first, second = trace['steps']
    require(first['mutation_nonce'] != second['mutation_nonce'], 'handoff nonces were reused')
    marker = 'HANDOFF-01:' + first['mutation_nonce']
    require(first['consumer_observable'] == {'kind': 'stdout_substring', 'expected': marker} and
            marker.encode() in logs[first['evidence_refs'][1]], 'Codex consumer did not observe the producer mutation')
    require(check.bound(record['output']) == ('COPILOT-CONSUMED:' + second['mutation_nonce'] + '\n').encode(),
            'Copilot output does not contain exactly the producer nonce')
    require(second['consumer_observable'] == {'kind': 'generated_file_hash',
            'expected': 'sha256:' + ROLLBACK.digest(check.bound(record['output']))}, 'Copilot output differs from the handoff trace')


def rollback_rehearsal(check, record, candidate):
    keys(record, {'root', 'receipt', 'staging_dir', 'applied_attestation'}, 'rollback rehearsal')
    relative = record['root']
    require(isinstance(relative, str) and relative and '\\' not in relative and ':' not in relative and
            not relative.startswith('/') and all(p not in ('', '.', '..') for p in relative.split('/')),
            'rollback root must be a canonical relative directory')
    root = check.root / relative
    for name in ('receipt', 'applied_attestation'):
        binding = record[name]
        check.bound({'path': relative + '/' + binding['path'], 'sha256': binding['sha256']})
    for name in ('approvers', 'trusted_signers'):
        require(check.read(relative + '/' + FIXED[name]) == check.read(FIXED[name]), 'rehearsal trust differs from current trust')
    args = ROLLBACK.parser().parse_args(['--root', str(root), '--receipt', record['receipt']['path'],
        '--staging-dir', record['staging_dir'], '--applied-attestation', record['applied_attestation']['path']])
    result = ROLLBACK.run(args)
    require(result['result'] == 'APPLIED_VERIFIED', 'rollback was not applied and verified')
    nested = ROLLBACK.Check(root)
    authorization = nested.document(args.receipt)
    before = document(nested, authorization['bindings']['before_context'])
    require(before == candidate, 'rollback rehearsal did not exercise this proposed Context')
    return utc(nested.document(args.applied_attestation)['applied_at'])


def admit(args, check):
    APPROVAL._check_no_publish_in_progress(*TARGETS)
    decision = check.document(args.decision)
    keys(decision, {'schema', 'criteria_revision', 'head_sha', 'decided_at', 'decision', 'bindings', 'basis',
                    'old_tuple', 'new_tuple', 'criteria', 'rollback', 'signer', 'signer_key_id', 'signature'}, 'promotion decision')
    require(decision['schema'] == 'promotion-decision/v1' and decision['criteria_revision'] == 'OQ-003/2026-09-02' and
            decision['decision'] == 'promote' and decision['old_tuple'] == OLD and decision['new_tuple'] == NEW and
            decision['criteria'] == CRITERIA, 'promotion decision does not approve all current criteria')
    head = git(check.root, 'rev-parse', 'HEAD')
    require(decision['head_sha'] == head and not git(check.root, 'status', '--porcelain', '--untracked-files=no'),
            'promotion decision must bind the clean current commit')
    bindings = decision['bindings']
    keys(bindings, set(FIXED) | EVIDENCE | set(CANDIDATE) | {'manifest'}, 'promotion bindings')
    for name, path in FIXED.items():
        require(bindings[name]['path'] == path, 'promotion input is not the fixed live policy')
    stage = PurePosixPath(args.staging_dir)
    for name, target in zip(CANDIDATE, TARGETS):
        require(bindings[name]['path'] == str(stage / target), 'promotion candidate is outside the supplied stage')
    require(bindings['manifest']['path'] == str(stage / 'MANIFEST.sha256'), 'promotion manifest differs from stage')
    for binding in bindings.values():
        check.bound(binding)
    identities = [(check.path(b['path']).stat().st_dev, check.path(b['path']).stat().st_ino) for b in bindings.values()]
    require(len(set(identities)) == len(identities), 'promotion inputs must be distinct files')
    docs = {name: document(check, binding) for name, binding in bindings.items() if name != 'manifest'}
    before, after = docs['approval'], docs['candidate_approval']
    require(docs['context'] == docs['anchor'] and check.bound(bindings['candidate_context']) == check.bound(bindings['candidate_snapshot']),
            'live or candidate approved anchor differs')
    for content, approval in (('context', 'approval'), ('candidate_context', 'candidate_approval')):
        APPROVAL.run_standard_validation(check.path(bindings[content]['path']), check.path(bindings[approval]['path']),
                                         check.path(FIXED['approvers']))
    require(after['approval_epoch'] == before['approval_epoch'] + 1 and
            after['predecessor_context_sha256'] == before['context_sha256'], 'promotion is not the current approved successor')
    now = datetime.now(timezone.utc)
    decided = utc(decision['decided_at'])
    require(utc(before['primary_approval']['approved_at']) <= utc(after['primary_approval']['approved_at']) <= decided <= now,
            'approval or decision time is future or inconsistent')
    registry = docs['trusted_signers']
    PROOF.validate_registry(registry)
    ROLLBACK.verify_signature(decision, registry, b':a9-promotion-approved', after['primary_approval']['approver'])
    expected_manifest = ''.join(bindings[name]['sha256'] + '  ' + target + '\n' for name, target in zip(CANDIDATE, TARGETS))
    require(check.bound(bindings['manifest']) == expected_manifest.encode(), 'promotion manifest must contain exactly the approved three targets')
    cycle = docs['release_cycle']
    require(cycle['head_sha'] == head, 'promotion evidence predates the current release head')
    tracked = git(check.root, 'ls-files').splitlines()
    errors = PREFLIGHT.validate_promotion(docs['candidate_context'], docs['context'], tracked, docs['registry'],
        docs['resolver'], docs['facet_manifest'], cycle, PREFLIGHT.release_commits(cycle))
    require(not errors, 'existing release/Context/Pack/Resolver preflight rejected promotion')
    # Every observed Phase-1 publication needs authentic approval, not just a matching hash.
    with tempfile.TemporaryDirectory(prefix='a9-phase1-approval-') as directory:
        for pr in cycle['pull_requests']:
            artifacts = pr['advisory_observation']['artifacts']
            context, approval = Path(directory) / 'context.yaml', Path(directory) / 'approval.json'
            context.write_bytes(artifacts['context']['contents'].encode('utf-8'))
            approval.write_bytes(artifacts['approval']['contents'].encode('utf-8'))
            APPROVAL.run_standard_validation(context, approval, check.path(FIXED['approvers']))
    require(decision['basis'] == {'context_binding': docs['resolver']['context_binding'], 'resolver': docs['resolver']['resolver'],
                                 'affected_components': docs['facet_manifest']['affected_components']}, 'promotion basis differs from observed inputs')
    findings(check, docs['findings'], cycle)
    compatibility(check, docs['compatibility'], head)
    cross_runtime(check, docs['cross_runtime'], head, decided)
    require(rollback_rehearsal(check, decision['rollback'], docs['candidate_context']) <= decided,
            'rollback rehearsal postdates the human decision')
    check.unchanged()
    return decision


def run(args):
    root = Path(args.root).resolve()
    previous, previous_root = Path.cwd(), PREFLIGHT.ROOT
    try:
        os.chdir(root)
        PREFLIGHT.ROOT = root
        check = ROLLBACK.Check(root)
        decision = admit(args, check)
        if not args.apply:
            return {'schema': 'a9-promotion-validation/v1', 'result': 'ADMISSIBLE', 'applied': False,
                    'authorization_checked': True, 'head_sha': decision['head_sha'], 'criteria': CRITERIA}
        bindings = decision['bindings']
        with tempfile.TemporaryDirectory(prefix='a9-promotion-') as directory:
            staged = Path(directory)
            for name, target in zip(CANDIDATE, TARGETS):
                destination = staged / target
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(check.bound(bindings[name]))
            manifest = staged / 'MANIFEST.sha256'
            manifest.write_bytes(check.bound(bindings['manifest']))
            # Revalidate current trust, clock, live anchor and all nested evidence before publication.
            admit(args, ROLLBACK.Check(root))
            check.unchanged()
            publisher = SOURCE / 'plugins/sdd-quality-loop/scripts' / ('apply-human-copy.ps1' if args.publisher_runtime == 'ps1' else 'apply-human-copy.sh')
            command = (['pwsh', '-NoProfile', '-File', str(publisher), '-StagingDir', str(staged), '-Manifest', str(manifest)]
                       if args.publisher_runtime == 'ps1' else ['bash', str(publisher), '--staging-dir', str(staged), '--manifest', str(manifest)])
            completed = subprocess.run(command, cwd=root, text=True, capture_output=True, encoding="utf-8")
        require(completed.returncode == 0, 'transactional publisher refused; use its existing recovery procedure')
        published = PROOF.CANON.parse_json_bytes(completed.stdout.encode())
        require(published.get('status') == 'ok' and published.get('targets') == list(TARGETS), 'publisher receipt differs')
        hashes = {}
        for name, target in zip(CANDIDATE, TARGETS):
            raw = check.path(target).read_bytes()
            require(raw == check.bound(bindings[name]), 'published bytes differ from the approved promotion')
            hashes[target] = ROLLBACK.digest(raw)
        check.unchanged(exclude=TARGETS)
        return {'schema': 'a9-promotion-application/v1', 'result': 'APPLIED', 'authorization_checked': True,
                'decision_sha256': ROLLBACK.digest(check.read(args.decision)), 'post_hashes': hashes,
                'post_promotion_feature_verified': False}
    finally:
        PREFLIGHT.ROOT = previous_root
        os.chdir(previous)


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path.cwd())
    p.add_argument('--decision', required=True)
    p.add_argument('--staging-dir', required=True)
    p.add_argument('--apply', action='store_true')
    p.add_argument('--publisher-runtime', choices=('sh', 'ps1'), default='ps1' if os.name == 'nt' else 'sh')
    return p


def main(argv=None):
    try:
        print(json.dumps(run(parser().parse_args(argv)), sort_keys=True))
        return 0
    except (ROLLBACK.Refusal, OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.CalledProcessError, subprocess.TimeoutExpired,
            APPROVAL.ValidateApprovalSidecarError, PROOF.ValidationError, PROOF.CANON.CanonicalizeError) as error:
        print(json.dumps({'schema': 'a9-promotion-validation/v1', 'result': 'BLOCKED',
                          'category': getattr(error, 'category', getattr(error, 'code', 'PROMOTION_REFUSED'))}))
        return 1

if __name__ == '__main__':
    sys.exit(main())
