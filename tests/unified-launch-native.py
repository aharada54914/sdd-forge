#!/usr/bin/env python3
"""Opt-in real Claude launch in a retained disposable root; never adopts a verdict."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def staged_native(source, stage, role):
    # Predecessor results are synthetic fixtures, never adopted review evidence.
    setup = subprocess.run(['rtk', 'proxy', 'bash', '-c', '''
set -e
source tests/lib/loop-driver.sh
loop_fixture_init greenfield native-launch-fixture
mv "$LOOP_FIXTURE_ROOT/domain" "$LOOP_FIXTURE_ROOT/domain-fixture-unused"
loop_prepare_STAGE_prereqs native-launch-fixture
printf 'FIXTURE_ROOT=%s\\n' "$LOOP_FIXTURE_ROOT"
'''.replace('STAGE', stage)], cwd=source, capture_output=True, text=True, timeout=240)
    if setup.returncode:
        raise SystemExit('TASK_FIXTURE_FAILED: ' + setup.stdout + setup.stderr)
    root = Path(next(line.split('=', 1)[1] for line in setup.stdout.splitlines()
                     if line.startswith('FIXTURE_ROOT=')))
    print('FIXTURE_ROOT=' + str(root), flush=True)
    # Move symlinked fixture scripts before copying; never write through to source.
    (root / 'plugins').rename(root / 'fixture-plugins')
    for plugin in ('sdd-review-loop', 'sdd-quality-loop'):
        shutil.copytree(source / 'plugins' / plugin, root / 'plugins' / plugin)
    scripts = root / 'plugins/sdd-review-loop/scripts'
    (root / 'reports/verification').mkdir(parents=True, exist_ok=True)
    (root / 'launch-source-hashes.json').write_text(json.dumps({
        name: sha(scripts / name) for name in
        ('launch-impl-review.py', 'validate-nontty-spec-launch.py', 'probe-nontty-review.py')
    }, indent=2) + '\n')
    result = subprocess.run(['rtk', 'proxy', 'bash', str(scripts / (stage + '-review-precheck.sh')),
                             'native-launch-fixture', '1', '1'], cwd=root,
                            capture_output=True, text=True, timeout=240)
    (root / 'precheck.stdout').write_text(result.stdout)
    (root / 'precheck.stderr').write_text(result.stderr)
    if result.returncode:
        raise SystemExit('TASK_PRECHECK_FAILED: ' + result.stderr)
    round_dir = root / ('reports/' + stage + '-review/native-launch-fixture/attempt-1/round-1')
    if role == 'b':
        ids = ['DEPENDENCY-GRAPH-VALID', 'TASK-AC-TRACE', 'RISK-WORKFLOW-MATCH',
               'SCOPE-DISJOINT', 'ROLLBACK-PLANNED', 'SIZE-APPROPRIATE']
        if stage == 'impl':
            ids = ['ARCH-COVERAGE', 'NO-CIRCULAR-DEPS', 'DATA-COVERAGE', 'API-COVERAGE',
                   'SECURITY-COVERAGE', 'FRONTEND-BACKEND-CONSISTENCY',
                   'TEST-STRATEGY-COVERAGE', 'NO-UNDEFINED-COMPONENT', 'ADR-PRESENT',
                   'DESIGN-SYSTEM-CONFORMANCE', 'DOMAIN-CONFORMANCE']
        (round_dir / 'integrated-summary.json').write_text(json.dumps({
            'schema': 'integrated-summary/v1', 'attempt': 1, 'round': 1,
            'reviewer_a_check_ids': ids, 'reviewer_a_fail_count': 0,
            'reviewer_a_pass_count': len(ids), 'reviewer_a_skip_count': 0,
            'generated_at': '2026-06-23T00:00:00Z'}))
    import importlib.util
    module_spec = importlib.util.spec_from_file_location('fixture_launcher', scripts / 'launch-impl-review.py')
    launcher = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(launcher)
    ledger = root / 'reports/review-context/identity-ledger.json'
    original = json.loads(ledger.read_text())['records']
    session = str(uuid.uuid4())
    data = {'schema': 'review-context-invocation/v2', 'input_mode': 'file-manifest',
            'fallback_mode': 'none', 'read_only': True, 'stage': stage,
            'role': stage + '-reviewer-' + role, 'feature': 'native-launch-fixture',
            'run_id': session, 'host_session_id': session,
            'sequence': original[-1]['sequence'] + 1,
            'identity_ledger_path': ledger.relative_to(root).as_posix(),
            'identity_ledger_sha256': sha(ledger),
            'previous_record_sha256': original[-1]['record_sha256'],
            'allowed_input_manifest': []}
    paths = launcher.required_input_paths(root, data, round_dir / 'precheck-result.json', 1, 1)
    precheck = json.loads((round_dir / 'precheck-result.json').read_text())
    data['allowed_input_manifest'] = [
        {'path': p, 'sha256': precheck['tasks_sha256'] if stage == 'task' and p.endswith('/tasks.md') else sha(root / p)}
        for p in sorted(paths)]
    invocation = root / ('reports/review-context/native-' + stage + '-invocation.json')
    invocation.write_text(json.dumps(data))
    output = round_dir / ('launch-' + session)
    result = subprocess.run(['rtk', 'proxy', 'python3', '-B',
                             str(scripts / 'launch-impl-review.py'), str(root), str(invocation),
                             str(output)], cwd=root, capture_output=True, text=True, timeout=1500)
    (root / 'launch.stdout').write_text(result.stdout)
    (root / 'launch.stderr').write_text(result.stderr)
    records = json.loads(ledger.read_text())['records']
    assert records[:len(original)] == original, 'fixture history changed'
    assert len(records) in (len(original), len(original) + 1)
    print(result.stdout, end='')
    print(result.stderr, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    assert len(records) == len(original) + 1 and (output / 'delivery.json').is_file()
    print(stage.upper() + '_NATIVE_DELIVERY_VERIFIED; predecessor fixtures synthetic; no verdict adoption')


def quality_native(source, prepare_only):
    """Diagnostic fixture with the unchanged canonical role; no production reservation."""
    source_ledger = source / 'reports/review-context/identity-ledger.json'
    original_ledger = source_ledger.read_bytes() if source_ledger.exists() else None
    source_role = source / 'plugins/sdd-quality-loop/agents/evaluator.md'
    original_role = source_role.read_bytes()
    root = Path(tempfile.mkdtemp(prefix='sdd-quality-native-')).resolve()
    print('FIXTURE_ROOT=' + str(root), flush=True)
    try:
        for plugin in ('sdd-review-loop', 'sdd-quality-loop'):
            shutil.copytree(source / 'plugins' / plugin, root / 'plugins' / plugin)
        role = root / 'plugins/sdd-quality-loop/agents/evaluator.md'
        if original_role.count(b'\nmodel: sonnet\n') != 1:
            raise SystemExit('QUALITY_FIXTURE_FAILED: expected canonical Sonnet model')
        assert role.read_bytes() == original_role, 'copied role differs from canonical role'
        scripts = root / 'plugins/sdd-review-loop/scripts'
        pins = {name: sha(scripts / name) for name in
                ('launch-impl-review.py', 'validate-nontty-spec-launch.py', 'probe-nontty-review.py')}
        pins.update({'canonical_role': hashlib.sha256(original_role).hexdigest(),
                     'fixture_role': sha(role)})
        (root / 'launch-source-hashes.json').write_text(json.dumps(pins, indent=2) + '\n')
        feature = 'native-launch-fixture'
        spec = root / 'specs' / feature
        spec.mkdir(parents=True)
        documents = {
            'requirements.md': '# Synthetic fixture\nREQ-001: Return hello unchanged.\n',
            'design.md': '# Design\nReturn the input string unchanged; no storage or network.\n',
            'acceptance-tests.md': '# Acceptance\nAC-001 / REQ-001: hello yields hello.\n',
            'tasks.md': '# Tasks\n## T-001\nApproval: Approved\nStatus: Implementation Complete\n'
                        'Synthetic diagnostic state only; no production approval.\n',
            'traceability.md': '# Traceability\nREQ-001 / AC-001 / T-001: synthetic fixture.\n'}
        for name, body in documents.items():
            (spec / name).write_text(body)
        implementation_scratch = root / 'implementation-scratch'
        evaluator_scratch = root / 'evaluator-scratch'
        implementation_scratch.mkdir()
        evaluator_scratch.mkdir()
        report = root / 'reports/implementation' / feature / 'T-001.md'
        report.parent.mkdir(parents=True)
        report.write_text('# Implementation Report: T-001\n- Task ID: T-001\n'
                          '- **Scratch Root**: ' + str(implementation_scratch) + '\n'
                          'Synthetic diagnostic, not implementation evidence.\n')
        context = root / 'reports/review-context'
        context.mkdir(parents=True)
        ledger = context / 'identity-ledger.json'
        previous = hashlib.sha256(b'1|spec|spec-reviewer-a|fixture-run|fixture-session|').hexdigest()
        history = [{'sequence': 1, 'stage': 'spec', 'role': 'spec-reviewer-a',
                    'run_id': 'fixture-run', 'host_session_id': 'fixture-session',
                    'previous_record_sha256': '', 'record_sha256': previous}]
        ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1', 'records': history}))
        ledger_before = ledger.read_bytes()
        session = str(uuid.uuid4())
        paths = [spec / name for name in documents] + [report,
                 root / 'plugins/sdd-quality-loop/references/quality-gate-calibration.md']
        invocation = context / 'native-quality-invocation.json'
        invocation.write_text(json.dumps({
            'schema': 'review-context-invocation/v2', 'input_mode': 'file-manifest',
            'fallback_mode': 'none', 'read_only': True, 'stage': 'quality',
            'role': 'sdd-evaluator', 'feature': feature, 'task_id': 'T-001',
            'scratch_root': str(evaluator_scratch), 'run_id': session,
            'host_session_id': session, 'sequence': 2,
            'identity_ledger_path': ledger.relative_to(root).as_posix(),
            'identity_ledger_sha256': sha(ledger), 'previous_record_sha256': previous,
            'allowed_input_manifest': [{'path': p.relative_to(root).as_posix(), 'sha256': sha(p)}
                                       for p in paths]}))
        output = root / 'reports/quality-gate' / ('launch-' + session)
        output.parent.mkdir(parents=True)
        preview = subprocess.run(['rtk', 'proxy', 'bash',
            str(root / 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh'),
            str(invocation), str(root)], cwd=root, capture_output=True, text=True, timeout=120)
        (root / 'preview.stdout').write_text(preview.stdout)
        (root / 'preview.stderr').write_text(preview.stderr)
        assert ledger.read_bytes() == ledger_before, 'preview changed fixture ledger'
        if preview.returncode:
            raise SystemExit('QUALITY_PREVIEW_FAILED: ' + preview.stdout + preview.stderr)
        print('SESSION=' + session, flush=True)
        if prepare_only:
            print('QUALITY_FIXTURE_PREPARED; native NOT RUN; no reservation or verdict adoption')
            return
        result = subprocess.run(['rtk', 'proxy', 'python3', '-B',
            str(scripts / 'launch-impl-review.py'), str(root), str(invocation), str(output)],
            cwd=root, capture_output=True, text=True, timeout=1500)
        (root / 'launch.stdout').write_text(result.stdout)
        (root / 'launch.stderr').write_text(result.stderr)
        records = json.loads(ledger.read_text())['records']
        assert records[:1] == history and len(records) in (1, 2), 'fixture history changed'
        print(result.stdout, end='')
        print(result.stderr, end='')
        if result.returncode:
            raise SystemExit(result.returncode)
        assert len(records) == 2 and (output / 'delivery.json').is_file()
        print('QUALITY_SYNTHETIC_DELIVERY_VERIFIED; canonical role unchanged; no production review or verdict adoption')
    finally:
        assert source_role.read_bytes() == original_role, 'canonical role changed during diagnostic'
        current = source_ledger.read_bytes() if source_ledger.exists() else None
        assert current == original_ledger, 'production ledger changed during diagnostic'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-native', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    stages = parser.add_mutually_exclusive_group()
    stages.add_argument('--task-role', choices=('a', 'b'))
    stages.add_argument('--impl-role', choices=('a', 'b'))
    stages.add_argument('--quality', action='store_true')
    args = parser.parse_args()
    if args.prepare_only and (not args.quality or args.run_native):
        parser.error('--prepare-only requires --quality and excludes --run-native')
    if not args.run_native and not (args.quality and args.prepare_only):
        parser.error('use --run-native or --quality --prepare-only')
    source = Path(__file__).resolve().parents[1]
    if args.quality:
        return quality_native(source, args.prepare_only)
    if args.task_role:
        return staged_native(source, 'task', args.task_role)
    if args.impl_role:
        return staged_native(source, 'impl', args.impl_role)
    root = Path(tempfile.mkdtemp(prefix='sdd-unified-native-')).resolve()
    print('FIXTURE_ROOT=' + str(root), flush=True)
    for plugin in ('sdd-review-loop', 'sdd-quality-loop'):
        shutil.copytree(source / 'plugins' / plugin, root / 'plugins' / plugin)
    spec = root / 'specs/native-launch-fixture'
    spec.mkdir(parents=True)
    (spec / 'requirements.md').write_text(
        '# Synthetic transport fixture\nSpec-Review-Status: Pending\n'
        'REQ-001: Return the supplied greeting unchanged. No storage or network.\n')
    (spec / 'acceptance-tests.md').write_text(
        '# Acceptance\nAC-001 / REQ-001: Input hello produces hello.\n')
    scripts = root / 'plugins/sdd-review-loop/scripts'
    (root / 'reports/verification').mkdir(parents=True)
    precheck = subprocess.run(['rtk', 'proxy', 'bash', str(scripts / 'spec-review-precheck.sh'),
                              'native-launch-fixture', '1', '1'], cwd=root,
                             capture_output=True, text=True, timeout=120)
    (root / 'precheck.stdout').write_text(precheck.stdout)
    (root / 'precheck.stderr').write_text(precheck.stderr)
    if precheck.returncode:
        raise SystemExit('PRECHECK_FAILED: ' + precheck.stderr)
    round_dir = root / 'reports/spec-review/native-launch-fixture/attempt-1/round-1'
    context = root / 'reports/review-context'
    context.mkdir(parents=True)
    previous = hashlib.sha256(b'1|spec|spec-reviewer-a|fixture-run|fixture-session|').hexdigest()
    ledger = context / 'identity-ledger.json'
    original = {'schema': 'review-identity-ledger/v1', 'records': [{
        'sequence': 1, 'stage': 'spec', 'role': 'spec-reviewer-a',
        'run_id': 'fixture-run', 'host_session_id': 'fixture-session',
        'previous_record_sha256': '', 'record_sha256': previous}]}
    ledger.write_text(json.dumps(original))
    session = str(uuid.uuid4())
    paths = [spec / 'requirements.md', spec / 'acceptance-tests.md',
             root / 'plugins/sdd-review-loop/references/spec-review-calibration.md',
             round_dir / 'precheck-result.json']
    invocation = context / 'native-invocation.json'
    invocation.write_text(json.dumps({
        'schema': 'review-context-invocation/v2', 'input_mode': 'file-manifest',
        'fallback_mode': 'none', 'read_only': True, 'stage': 'spec',
        'role': 'spec-reviewer-a', 'feature': 'native-launch-fixture',
        'run_id': session, 'host_session_id': session, 'sequence': 2,
        'identity_ledger_path': ledger.relative_to(root).as_posix(),
        'identity_ledger_sha256': sha(ledger), 'previous_record_sha256': previous,
        'allowed_input_manifest': [{'path': p.relative_to(root).as_posix(), 'sha256': sha(p)}
                                   for p in paths]}))
    output = round_dir / ('launch-' + session)
    result = subprocess.run(['rtk', 'proxy', 'python3', '-B',
                             str(scripts / 'launch-impl-review.py'), str(root),
                             str(invocation), str(output)], cwd=root,
                            capture_output=True, text=True, timeout=1500)
    (root / 'launch.stdout').write_text(result.stdout)
    (root / 'launch.stderr').write_text(result.stderr)
    records = json.loads(ledger.read_text())['records']
    assert records[:1] == original['records'], 'fixture history changed'
    assert len(records) in (1, 2), 'unexpected fixture reservations'
    print(result.stdout, end='')
    print(result.stderr, end='')
    print('FIXTURE_LEDGER_RECORDS=' + str(len(records)))
    if result.returncode:
        raise SystemExit(result.returncode)
    assert len(records) == 2 and (output / 'delivery.json').is_file()
    print('NATIVE_DELIVERY_VERIFIED; verdict adoption and production review NOT performed')


if __name__ == '__main__':
    main()
