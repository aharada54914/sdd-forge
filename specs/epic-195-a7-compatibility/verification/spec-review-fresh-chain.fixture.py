#!/usr/bin/env python3
"""Isolated three-partial recovery regression; never edits owner evidence."""
import hashlib
import importlib.util
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
FEATURE = 'epic-195-a7-compatibility'
BASE = f'reports/spec-review/{FEATURE}'
CONTRACT = 'reports/verification/fresh-review-contract.json'
LEGACY_PATH = pathlib.Path(__file__).with_name('spec-review-fresh-recovery.fixture.py')
SPEC = importlib.util.spec_from_file_location('legacy_recovery_fixture', LEGACY_PATH)
LEGACY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LEGACY)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repin(contract, root, relative):
    for item in contract['evidence']:
        if item['path'] == relative:
            item['sha256'] = digest(root / relative)
            return
    raise AssertionError('missing evidence entry: ' + relative)


def build(root):
    LEGACY.build(root)
    shutil.copytree(ROOT / BASE / 'attempt-10', root / BASE / 'attempt-10')
    invocation = f'reports/review-context/{FEATURE}-spec-a10r1-a-invocation.json'
    shutil.copy2(ROOT / invocation, root / invocation)
    contract_path = root / CONTRACT
    contract = json.loads(contract_path.read_text())
    contract['next_attempt'] = 11
    contract['terminal_attempt'] = 7
    contract['partial_attempts'] = [8, 9, 10]
    for name in ('precheck-result.json', 'reviewer-a-host-allocation.json', 'reviewer-a.json'):
        rel = f'{BASE}/attempt-10/round-1/{name}'
        contract['evidence'].append({'path': rel, 'sha256': digest(root / rel)})
    contract['evidence'].append({'path': invocation, 'sha256': digest(root / invocation)})
    approval = root / contract['authority']['path']
    audit = json.loads(approval.read_text())
    audit['next_attempt'] = 11
    approval.write_text(json.dumps(audit))
    repin(contract, root, contract['authority']['path'])
    contract_path.write_text(json.dumps(contract))


def run(root, runtime):
    contract = root / CONTRACT
    script = root / 'plugins/sdd-review-loop/scripts/spec-review-precheck'
    cmd = (['bash', str(script) + '.sh', FEATURE, '11', '1', '--reset',
            '--fresh-review-contract=' + str(contract)] if runtime == 'bash' else
           ['pwsh', '-NoProfile', '-File', str(script) + '.ps1', FEATURE, '11', '1',
            '-Reset', '-FreshReviewContract', str(contract)])
    return subprocess.run(cmd, capture_output=True, text=True, timeout=120)


def helper_only():
    helper_path = ROOT / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'
    spec = importlib.util.spec_from_file_location('fresh_review_recovery', helper_path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    cases = ('valid', 'historical-manifest-sha', 'sequence-mismatch',
             'ledger-chain', 'ledger-duplicate', 'missing-last-reservation',
             'input-mode', 'fallback-mode', 'extra-envelope-key',
             'missing-envelope-key', 'ledger-digest-format', 'sequence-one',
             'previous-record-format')
    with tempfile.TemporaryDirectory(prefix='a7-fresh-chain-helper-') as tmp:
        base = (pathlib.Path(tmp) / 'base').resolve()
        build(base)
        historical = json.loads((base / f'reports/review-context/{FEATURE}-spec-a10r1-a-invocation.json').read_text())
        assert historical['allowed_input_manifest'][0]['sha256'] != digest(base / f'specs/{FEATURE}/requirements.md')
        for case in cases:
            root = (pathlib.Path(tmp) / case).resolve()
            shutil.copytree(base, root)
            contract_path = root / CONTRACT
            contract = json.loads(contract_path.read_text())
            invocation_rel = f'reports/review-context/{FEATURE}-spec-a10r1-a-invocation.json'
            invocation_path = root / invocation_rel
            ledger_path = root / 'reports/review-context/identity-ledger.json'
            if case in ('historical-manifest-sha', 'sequence-mismatch',
                        'input-mode', 'fallback-mode', 'extra-envelope-key',
                        'missing-envelope-key', 'ledger-digest-format',
                        'sequence-one', 'previous-record-format'):
                invocation = json.loads(invocation_path.read_text())
                if case == 'historical-manifest-sha':
                    invocation['allowed_input_manifest'][0]['sha256'] = '0' * 64
                elif case == 'sequence-mismatch':
                    invocation['sequence'] += 1
                elif case == 'input-mode':
                    invocation['input_mode'] = 'inline'
                elif case == 'fallback-mode':
                    invocation['fallback_mode'] = 'manual'
                elif case == 'extra-envelope-key':
                    invocation['unexpected'] = True
                elif case == 'missing-envelope-key':
                    del invocation['fallback_mode']
                elif case == 'ledger-digest-format':
                    invocation['identity_ledger_sha256'] = 'not-a-sha256'
                elif case == 'sequence-one':
                    invocation['sequence'] = 1
                else:
                    invocation['previous_record_sha256'] = 'not-a-sha256'
                invocation_path.write_text(json.dumps(invocation))
                repin(contract, root, invocation_rel)
            elif case in ('ledger-chain', 'ledger-duplicate', 'missing-last-reservation'):
                ledger = json.loads(ledger_path.read_text())
                if case == 'ledger-chain':
                    ledger['records'][-1]['record_sha256'] = '0' * 64
                elif case == 'ledger-duplicate':
                    ledger['records'].append(dict(ledger['records'][-1]))
                else:
                    ledger['records'] = [record for record in ledger['records']
                                         if record['run_id'] != historical['run_id']]
                ledger_path.write_text(json.dumps(ledger))
            contract_path.write_text(json.dumps(contract))
            try:
                helper.validate(root, FEATURE, 11, contract_path)
            except ValueError:
                assert case != 'valid', 'valid historical chain rejected'
            else:
                assert case == 'valid', 'corrupted historical chain accepted: ' + case
            print('PASS helper', case)


def main():
    if sys.argv[1:] == ['--helper-only']:
        helper_only()
        return
    if sys.argv[1:] == ['--expect-red']:
        old = ROOT / 'reports/verification/a7-fresh-review-candidate-v2-20261005/backup-vth20djk/plugins/sdd-review-loop/scripts/fresh-review-recovery.py'
        with tempfile.TemporaryDirectory(prefix='a7-fresh-chain-red-') as tmp:
            root = (pathlib.Path(tmp) / 'base').resolve()
            build(root)
            shutil.copy2(old, root / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py')
            for runtime in ('bash', 'pwsh'):
                result = run(root, runtime)
                assert result.returncode != 0 and not (root / BASE / 'attempt-11').exists(), (
                    runtime, result.stdout, result.stderr)
                assert 'unexpected fresh-review contract keys' in result.stderr
                print('RED', runtime, 'three-partial history rejected by original v2 helper')
        return
    assert not sys.argv[1:], 'usage: fixture.py [--expect-red]'
    cases = ('valid', 'missing-middle', 'reordered', 'duplicate-attempt', 'duplicate-session', 'bool-anchor',
             'missing-history-key', 'future-anchor', 'missing-last-reservation',
             'extra-b-invocation', 'output-identity', 'historical-manifest-sha',
             'ledger-chain', 'ledger-duplicate', 'sequence-mismatch', 'replay')
    with tempfile.TemporaryDirectory(prefix='a7-fresh-chain-') as tmp:
        base = (pathlib.Path(tmp) / 'base').resolve()
        build(base)
        historical = json.loads((base / f'reports/review-context/{FEATURE}-spec-a10r1-a-invocation.json').read_text())
        assert historical['allowed_input_manifest'][0]['sha256'] != digest(base / f'specs/{FEATURE}/requirements.md'), (
            'valid fixture must exercise amended current inputs against pinned historical inputs')
        for runtime in ('bash', 'pwsh'):
            for case in cases:
                root = (pathlib.Path(tmp) / (runtime + '-' + case)).resolve()
                shutil.copytree(base, root)
                contract_path = root / CONTRACT
                contract = json.loads(contract_path.read_text())
                if case == 'missing-middle':
                    contract['partial_attempts'] = [8, 10]
                elif case == 'reordered':
                    contract['partial_attempts'] = [10, 9, 8]
                elif case == 'duplicate-attempt':
                    contract['partial_attempts'] = [8, 9, 9, 10]
                elif case == 'duplicate-session':
                    source = json.loads((root / f'reports/review-context/{FEATURE}-spec-a9r1-a-invocation.json').read_text())
                    session = source['host_session_id']
                    paths = [f'reports/review-context/{FEATURE}-spec-a10r1-a-invocation.json',
                             f'{BASE}/attempt-10/round-1/reviewer-a-host-allocation.json',
                             f'{BASE}/attempt-10/round-1/reviewer-a.json']
                    for rel in paths:
                        path = root / rel
                        data = json.loads(path.read_text())
                        data['host_session_id'] = session
                        path.write_text(json.dumps(data))
                        repin(contract, root, rel)
                elif case == 'bool-anchor':
                    contract['terminal_attempt'] = True
                elif case == 'missing-history-key':
                    del contract['partial_attempts']
                elif case == 'future-anchor':
                    contract['terminal_attempt'] = 12
                elif case == 'missing-last-reservation':
                    ledger = root / 'reports/review-context/identity-ledger.json'
                    data = json.loads(ledger.read_text())
                    latest = json.loads((root / f'reports/review-context/{FEATURE}-spec-a10r1-a-invocation.json').read_text())
                    data['records'] = [record for record in data['records'] if record['run_id'] != latest['run_id']]
                    ledger.write_text(json.dumps(data))
                elif case == 'ledger-chain':
                    ledger = root / 'reports/review-context/identity-ledger.json'
                    data = json.loads(ledger.read_text())
                    data['records'][-1]['record_sha256'] = '0' * 64
                    ledger.write_text(json.dumps(data))
                elif case == 'ledger-duplicate':
                    ledger = root / 'reports/review-context/identity-ledger.json'
                    data = json.loads(ledger.read_text())
                    data['records'].append(dict(data['records'][-1]))
                    ledger.write_text(json.dumps(data))
                elif case in ('historical-manifest-sha', 'sequence-mismatch'):
                    rel = f'reports/review-context/{FEATURE}-spec-a10r1-a-invocation.json'
                    path = root / rel
                    data = json.loads(path.read_text())
                    if case == 'historical-manifest-sha':
                        data['allowed_input_manifest'][0]['sha256'] = '0' * 64
                    else:
                        data['sequence'] += 1
                    path.write_text(json.dumps(data))
                    repin(contract, root, rel)
                elif case == 'extra-b-invocation':
                    (root / f'reports/review-context/{FEATURE}-spec-a10r1-b-invocation.json').write_text('{}')
                elif case == 'output-identity':
                    rel = f'{BASE}/attempt-10/round-1/reviewer-a.json'
                    path = root / rel
                    output = json.loads(path.read_text())
                    output['host_session_id'] = 'wrong-session'
                    path.write_text(json.dumps(output))
                    repin(contract, root, rel)
                contract_path.write_text(json.dumps(contract))
                protected = {str(p.relative_to(root)): digest(p) for p in
                             (root / BASE).rglob('*') if p.is_file()}
                result = run(root, runtime)
                assert (result.returncode == 0) == (case in ('valid', 'replay')), (
                    runtime, case, result.stdout, result.stderr)
                assert all(digest(root / rel) == sha for rel, sha in protected.items())
                dest = root / BASE / 'attempt-11/round-1/precheck-result.json'
                assert dest.exists() == (case in ('valid', 'replay'))
                if case in ('valid', 'replay'):
                    precheck = json.loads(dest.read_text())
                    assert precheck['fresh_review_contract_sha256'] == digest(contract_path)
                    assert run(root, runtime).returncode != 0
                print('PASS', runtime, case)


if __name__ == '__main__':
    main()
