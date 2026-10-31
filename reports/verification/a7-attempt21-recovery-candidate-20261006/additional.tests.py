"""Additional isolated checks; synthetic authority is fixture-only, never owner evidence."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
OWNER = HERE.parents[2]
FEATURE = 'epic-195-a7-compatibility'

def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def install(root):
    for name in ('failed-last-attempt', 'fresh-review-recovery', 'validate-nontty-spec-launch'):
        shutil.copy2(HERE / (name + '.candidate.py'), root / 'plugins/sdd-review-loop/scripts' / (name + '.py'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

old = module(OWNER / 'reports/verification/a7-attempt16-recovery-candidate-20261005/failed-last-attempt.fixture.py', 'old')
old.candidate = module(HERE / 'failed-last-attempt.candidate.py', 'candidate_failed')
source = OWNER / 'reports/verification/a7-private-attempt16/failed-host.jsonl'
old.check('legacy truncated positive', source, accepted=True)
for name in ('bad_verdict', 'unfinished', 'changed_input', 'reused_session', 'unexpected_output',
             'replay', 'empty_hashes', 'partial_hashes', 'changed_transcript_pin',
             'changed_blocker_pin', 'complete_user_prompt', 'precheck_only', 'missing_input',
             'extra_input', 'mismatched_input', 'duplicate_input', 'missing_b_summary'):
    old.check('legacy ' + name, source, mutate=getattr(old, name))

with contextlib.redirect_stdout(io.StringIO()):
    native = runpy.run_path(str(HERE / 'recovery.tests.py'))
with tempfile.TemporaryDirectory(prefix='a21-additional-native-') as folder:
    root = Path(folder).resolve()
    hashes, turn = native['fixture'](root)
    transport = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'))
    wrapper = root / native['BASE'] / 'round-2/reviewer-a-cli-wrapper.json'
    original = wrapper.read_bytes()
    value = json.loads(original)
    value['result'] = json.dumps({'stage': 'spec', 'role': 'spec-reviewer-a',
        'run_id': native['SESSION'], 'host_session_id': native['SESSION']})
    wrapper.write_text(json.dumps(value))
    args = (root, root / native['INV'], root / turn['transcript_path'],
        root / native['BASE'] / 'round-2/reviewer-a-first-turn.txt', wrapper,
        root / native['BASE'] / 'round-2/reviewer-a-reservation-receipt.txt')
    assert transport['postflight'](*args)['status'] == 'DELIVERY_OK'
    print('PASS ordinary raw JSON postflight DELIVERY_OK (transport only, not verdict schema)')
    wrapper.write_text(original.decode().rstrip()[:-1] + ',"session_id":"duplicate"}')
    try:
        transport['postflight'](*args)
    except ValueError as error:
        assert 'duplicate JSON key' in str(error)
        print('PASS duplicate wrapper rejected')
    else:
        raise AssertionError('duplicate wrapper accepted')
    wrapper.write_bytes(original)
    (root / native['BASE'] / 'round-1/reviewer-a-host-allocation.json').unlink()
    native['repin'](root, turn)
    inspector = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'))
    try:
        inspector['inspect'](root, FEATURE, 21, 2, hashes, turn)
    except ValueError as error:
        assert 'round-1 evidence inventory' in str(error)
        print('PASS completed-round allocation remains required; exception failed-round only')
    else:
        raise AssertionError('completed allocation absence accepted')

chain = module(OWNER / f'specs/{FEATURE}/verification/spec-review-fresh-chain.fixture.py', 'chain')
with tempfile.TemporaryDirectory(prefix='a21-chain-parity-') as folder:
    base = Path(folder).resolve() / 'base'
    chain.build(base)
    install(base)
    helper = runpy.run_path(str(base / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'))
    assert helper['validate'](base, FEATURE, 11, base / chain.CONTRACT)['terminal_attempt'] == 7
    print('PASS existing chain full validate authority/inventory/ledger')
    for runtime in ('bash', 'pwsh'):
        root = Path(folder).resolve() / runtime
        shutil.copytree(base, root)
        result = chain.run(root, runtime)
        assert result.returncode == 0, (runtime, result.stdout, result.stderr)
        print('PASS', runtime, 'existing chain canonical terminal contract and ordinary lock path')
        replay = chain.run(root, runtime)
        assert replay.returncode != 0
        print('PASS', runtime, 'replay rejected')

with tempfile.TemporaryDirectory(prefix='a21-completed23-parity-') as folder:
    for runtime in ('bash', 'pwsh'):
        root = Path(folder).resolve() / runtime
        for rel in ('plugins/sdd-review-loop', 'plugins/sdd-quality-loop', f'specs/{FEATURE}'):
            shutil.copytree(OWNER / rel, root / rel)
        round1 = f'reports/spec-review/{FEATURE}/attempt-20/round-1'
        shutil.copytree(OWNER / round1, root / round1)
        assert len(list((root / round1).iterdir())) == 23
        install(root)
        script = root / 'plugins/sdd-review-loop/scripts/spec-review-precheck'
        command = (['bash', str(script) + '.sh', FEATURE, '20', '2', '--edit-summary=fixture amended inputs']
            if runtime == 'bash' else ['pwsh', '-NoProfile', '-File', str(script) + '.ps1', FEATURE, '20', '2', '-EditSummary', 'fixture amended inputs'])
        result = subprocess.run(command, capture_output=True, text=True, timeout=120)
        assert result.returncode == 0, (runtime, result.stdout, result.stderr)
        print('PASS', runtime, 'real completed-round exact23 canonical contract; ordinary round2 precheck/lock')

with tempfile.TemporaryDirectory(prefix='a21-full-real-chain-') as folder:
    root = Path(folder).resolve()
    for rel in ('plugins/sdd-review-loop', 'plugins/sdd-quality-loop', f'specs/{FEATURE}',
                f'reports/spec-review/{FEATURE}', 'reports/review-context'):
        shutil.copytree(OWNER / rel, root / rel)
    install(root)
    # Preserve every retained historical byte/pin from the A20 contract.
    source_contract = OWNER / 'reports/verification/a7-attempt20-formal-20261006/fresh-review-contract-attempt20-transport.json'
    contract = json.loads(source_contract.read_bytes())
    old_authority = contract['authority']['path']
    for entry in contract['evidence']:
        if entry['path'] == old_authority or (root / entry['path']).exists():
            continue
        dest = root / entry['path']
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(OWNER / entry['path'], dest)
    # Reuse native fixture for original A20 paths; copy only missing artifacts.
    transcript_rel = 'reports/verification/native/' + native['SESSION'] + '.jsonl'
    for rel, source_path in ((transcript_rel, native['TRANSCRIPT']), (native['BLOCKER'], OWNER / native['BLOCKER'])):
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, target)
    pre = json.loads((root / native['BASE'] / 'round-2/precheck-result.json').read_bytes())
    hashes = {key: pre[key] for key in ('requirements_sha256', 'acceptance_sha256', 'investigation_sha256', 'calibration_sha256', 'input_sha256')}
    turn = {'failure_mode': 'native-nontty-malformed-result', 'host_session_id': native['SESSION'],
        'transcript_path': transcript_rel, 'transcript_sha256': sha(root / transcript_rel),
        'blocker_path': native['BLOCKER'], 'blocker_sha256': sha(root / native['BLOCKER']), 'files': []}
    native['repin'](root, turn)
    contract.update(next_attempt=21, partial_attempts=list(range(8, 21)), input_hashes=hashes,
        failed_final_round=2, failed_turn=turn, transcript={'path': transcript_rel})
    authority_rel = 'reports/verification/synthetic-a21-authority.json'
    contract['authority'] = {'path': authority_rel}
    audit = {'schema': 'spec-fresh-review-approval-audit/v1', 'feature': FEATURE,
        'next_attempt': 21, 'origin': 'current-user-conversation', 'recorded_by_role': 'orchestrator',
        'user_statement': 'SYNTHETIC FIXTURE ONLY; NO HUMAN AUTHORITY ASSERTED',
        'scope': 'quarantine-history-and-start-fresh-review-only', 'input_hashes': hashes}
    for name, value in (('failed_turn', turn), ('transport_inventories', contract['interrupted_transport_inventories'])):
        audit[name + '_sha256'] = hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()).hexdigest()
    (root / authority_rel).write_text(json.dumps(audit))
    evidence = {entry['path']: entry for entry in contract['evidence'] if entry['path'] != old_authority}
    new_paths = [p.relative_to(root).as_posix() for p in (root / native['BASE']).glob('round-*/*')]
    new_paths += [f'reports/review-context/{FEATURE}-spec-a20r{r}-{role}-invocation.json' for r, role in ((1, 'a'), (1, 'b'), (2, 'a'))]
    new_paths += [authority_rel, transcript_rel, native['BLOCKER']]
    for rel in new_paths:
        evidence[rel] = {'path': rel, 'sha256': sha(root / rel)}
    contract['evidence'] = list(evidence.values())
    contract_path = root / 'reports/verification/synthetic-a21-contract.json'
    contract_path.write_text(json.dumps(contract))
    helper = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'))
    result = helper['validate'](root, FEATURE, 21, contract_path)
    assert len(result['completed_rounds']) == 3
    print('PASS full A21 real-history admission; synthetic authority only; historical bytes unchanged')
    for label, rel, field in (
        ('historical precheck pin', f'reports/spec-review/{FEATURE}/attempt-15/round-3/precheck-result.json', 'investigation_sha256'),
        ('historical manifest pin', f'reports/review-context/{FEATURE}-spec-a15r3-a-invocation.json', 'allowed_input_manifest'),
        ('current failed-round mismatch', f'reports/spec-review/{FEATURE}/attempt-20/round-2/precheck-result.json', 'investigation_sha256')):
        target = root / rel
        original = target.read_bytes()
        value = json.loads(original)
        if field == 'allowed_input_manifest':
            value[field][0]['sha256'] = '0' * 64
        else:
            value[field] = '0' * 64
        target.write_text(json.dumps(value))
        try:
            helper['validate'](root, FEATURE, 21, contract_path)
        except ValueError as error:
            assert 'evidence hash mismatch' in str(error), str(error)
            print('PASS reject', label, 'without repinning history')
        else:
            raise AssertionError(label + ' accepted')
        target.write_bytes(original)
    for runtime in ('bash', 'pwsh'):
        isolated = Path(folder).resolve() / ('runtime-' + runtime)
        shutil.copytree(root, isolated)
        script = isolated / 'plugins/sdd-review-loop/scripts/spec-review-precheck'
        command = (['bash', str(script) + '.sh', FEATURE, '21', '1', '--reset', '--fresh-review-contract=' + str(isolated / contract_path.relative_to(root))]
            if runtime == 'bash' else ['pwsh', '-NoProfile', '-File', str(script) + '.ps1', FEATURE, '21', '1', '-Reset', '-FreshReviewContract', str(isolated / contract_path.relative_to(root))])
        run = subprocess.run(command, capture_output=True, text=True, timeout=120)
        assert run.returncode == 0, (runtime, run.stdout, run.stderr)
        print('PASS', runtime, 'full A21 canonical completed-round contracts and lock revalidation')

print('No owner files, ledger, reservations, approval or verdict modified; final correction 3/3.')
