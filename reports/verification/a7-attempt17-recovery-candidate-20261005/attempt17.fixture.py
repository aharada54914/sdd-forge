#!/usr/bin/env python3
"""Exercise only isolated copies of the attempt-17 recovery candidates."""
import hashlib
import json
import pathlib
import runpy
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch

HERE = pathlib.Path(__file__).resolve().parent
OWNER = HERE.parents[2]
FEATURE = 'epic-195-a7-compatibility'
OLD_CONTRACT = 'reports/verification/a7-spec-fresh-review-contract-attempt16-20261005.json'
NEW_CONTRACT = 'reports/verification/fixture-attempt17-contract.json'
NEW_APPROVAL = 'reports/verification/fixture-attempt17-approval.json'
BASE = f'reports/spec-review/{FEATURE}'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False))


def build(root):
    shutil.copytree(OWNER, root, ignore=shutil.ignore_patterns('.git', 'node_modules'))
    for name in ('fresh-review-recovery.py', 'failed-last-attempt.py'):
        shutil.copy2(HERE / (name + '.candidate'),
                     root / 'plugins/sdd-review-loop/scripts' / name)
    data = json.loads((root / OLD_CONTRACT).read_text())
    data['next_attempt'] = 17
    data['partial_attempts'].append(16)
    old_failed = {'attempt': 15, 'failed_final_round': data.pop('failed_final_round'),
                  'failed_turn': data.pop('failed_turn')}
    data['historical_failed_rounds'] = [old_failed]
    data['authority'] = {'path': NEW_APPROVAL}
    approval = json.loads((root / 'reports/verification/a7-spec-fresh-review-approval-attempt16-20261005.json').read_text())
    approval['next_attempt'] = 17
    approval['user_statement'] = 'SYNTHETIC fixture authorization'
    save(root / NEW_APPROVAL, approval)
    paths = {item['path'] for item in data['evidence']}
    paths.remove('reports/verification/a7-spec-fresh-review-approval-attempt16-20261005.json')
    paths.add(NEW_APPROVAL)
    paths.update(f'{BASE}/attempt-16/round-1/{name}' for name in
                 ('precheck-result.json', 'reviewer-a-host-allocation.json',
                  'launch-blocker-note.md'))
    paths.add(f'reports/review-context/{FEATURE}-spec-a16r1-a-invocation.json')
    data['evidence'] = [{'path': path, 'sha256': sha(root / path)} for path in sorted(paths)]
    save(root / NEW_CONTRACT, data)
    return data


def helper(root, expected=0):
    result = subprocess.run([sys.executable,
        str(root / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'),
        str(root), FEATURE, '17', str(root / NEW_CONTRACT)],
        capture_output=True, text=True, timeout=60)
    if result.returncode != expected:
        raise AssertionError(f'helper exit {result.returncode}: {result.stderr[-1000:]}')
    return result


def reject(root, original, label, mutate):
    data = json.loads(json.dumps(original))
    mutate(data)
    save(root / NEW_CONTRACT, data)
    helper(root, 1)
    print('PASS reject ' + label)
    save(root / NEW_CONTRACT, original)


def reject_changed_file(root, original, label, relative, mutate):
    target = root / relative
    before = target.read_bytes()
    data = json.loads(json.dumps(original))
    changed = json.loads(before)
    mutate(changed)
    save(target, changed)
    for entry in data['evidence']:
        if entry['path'] == relative:
            entry['sha256'] = sha(target)
    save(root / NEW_CONTRACT, data)
    try:
        helper(root, 1)
        print('PASS reject ' + label)
    finally:
        target.write_bytes(before)
        save(root / NEW_CONTRACT, original)


def caller_command(root, runtime):
    script = root / 'plugins/sdd-review-loop/scripts/spec-review-precheck'
    return (['bash', str(script) + '.sh', FEATURE, '17', '1', '--reset',
                '--fresh-review-contract=' + str(root / NEW_CONTRACT)] if runtime == 'bash' else
               ['pwsh', '-NoProfile', '-File', str(script) + '.ps1', FEATURE, '17', '1',
                '-Reset', '-FreshReviewContract', str(root / NEW_CONTRACT)])


def reject_caller_contract(root, original, runtime):
    relative = f'{BASE}/attempt-15/round-1/spec-review-contract.json'
    target = root / relative
    before = target.read_bytes()
    contract = json.loads(before)
    contract['warningCount'] = 999
    save(target, contract)
    data = json.loads(json.dumps(original))
    next(item for item in data['evidence'] if item['path'] == relative)['sha256'] = sha(target)
    save(root / NEW_CONTRACT, data)
    try:
        if helper(root).returncode != 0:
            raise AssertionError('local helper unexpectedly rejected repinned contract')
        result = subprocess.run(caller_command(root, runtime), capture_output=True,
                                text=True, timeout=120)
        if result.returncode == 0 or 'completed NEEDS_WORK round is invalid' not in result.stderr:
            raise AssertionError(runtime + ' did not reject malformed completed contract: '
                                 + result.stderr[-1000:])
        print('PASS ' + runtime + ' rejects repinned malformed completed contract')
    finally:
        target.write_bytes(before)
        save(root / NEW_CONTRACT, original)


def caller(root, runtime):
    command = caller_command(root, runtime)
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        raise AssertionError(f'{runtime} exit {result.returncode}: {result.stderr[-1400:]}')
    precheck = root / BASE / 'attempt-17/round-1/precheck-result.json'
    output = json.loads(precheck.read_text())
    if output['fresh_review_contract_sha256'] != sha(root / NEW_CONTRACT):
        raise AssertionError('caller did not bind contract hash')
    print('PASS ' + runtime + ' full caller and contract hash')
    replay = subprocess.run(command, capture_output=True, text=True, timeout=120)
    if replay.returncode == 0:
        raise AssertionError(runtime + ' admitted replay')
    print('PASS ' + runtime + ' rejects replay')


def combined_rounds(root, original):
    """Exercise both optional history forms without manufacturing host receipts."""
    data = json.loads(json.dumps(original))
    data['failed_final_round'] = 2
    data['failed_turn'] = data['historical_failed_rounds'][0]['failed_turn']
    data['evidence'] = [item for item in data['evidence']
                        if '/attempt-16/' not in item['path'] and '-spec-a16r1-' not in item['path']]
    save(root / NEW_CONTRACT, data)
    module = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'))
    real_inspect = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'))['inspect']

    def inspect(*args, **kwargs):
        if 'old_attempt' in kwargs:
            return real_inspect(*args, **kwargs)
        return {'evidence_paths': [], 'completed_rounds': [{'attempt': 16, 'round': 1}],
                'invocation_paths': [], 'invocations': []}

    try:
        with patch('runpy.run_path', return_value={'inspect': inspect}):
            result = module['validate'](root, FEATURE, 17, root / NEW_CONTRACT)
            rounds = [(item['attempt'], item['round']) for item in result['completed_rounds']]
            if rounds != [(15, 1), (15, 2), (16, 1)]:
                raise AssertionError('combined history discarded earlier completed rounds: ' + str(rounds))
            print('PASS combined history preserves all completed rounds')
            relative = f'reports/review-context/{FEATURE}-spec-a15r1-a-invocation.json'
            target = root / relative
            before = target.read_bytes()
            try:
                for changed_hash in (None, '0' * 64):
                    changed = json.loads(before)
                    if changed_hash is not None:
                        changed['allowed_input_manifest'][0]['sha256'] = changed_hash
                    save(target, changed)
                    pinned = json.loads(json.dumps(data))
                    next(item for item in pinned['evidence']
                         if item['path'] == relative)['sha256'] = sha(target)
                    save(root / NEW_CONTRACT, pinned)
                    try:
                        module['validate'](root, FEATURE, 17, root / NEW_CONTRACT)
                    except ValueError as error:
                        if changed_hash is None or str(error) != 'last-attempt manifest differs from its precheck':
                            raise
                        print('PASS combined history rejects changed manifest at binding check')
                    else:
                        if changed_hash is not None:
                            raise AssertionError('combined history admitted changed manifest')
                        print('PASS combined history accepts repinned no-op control')
            finally:
                target.write_bytes(before)
    finally:
        save(root / NEW_CONTRACT, original)


def main():
    with tempfile.TemporaryDirectory(prefix='a7-attempt17-fixture-') as folder:
        root = pathlib.Path(folder).resolve() / 'bash-root'
        data = build(root)
        result = json.loads(helper(root).stdout)
        if [(item['attempt'], item['round']) for item in result['completed_rounds']] != [(15, 1), (15, 2)]:
            raise AssertionError('completed rounds not fully returned')
        print('PASS helper returns both completed NEEDS_WORK rounds')
        reject(root, data, 'missing special marker', lambda x: x.pop('historical_failed_rounds'))
        reject(root, data, 'duplicate special marker',
               lambda x: x['historical_failed_rounds'].append(x['historical_failed_rounds'][0]))
        reject(root, data, 'wrong special attempt',
               lambda x: x['historical_failed_rounds'][0].__setitem__('attempt', 14))
        reject(root, data, 'changed failed-turn hash',
               lambda x: x['historical_failed_rounds'][0]['failed_turn'].__setitem__('blocker_sha256', '0' * 64))
        reject(root, data, 'missing evidence pin', lambda x: x['evidence'].pop())
        reject(root, data, 'current input mismatch',
               lambda x: x['input_hashes'].__setitem__('input_sha256', '0' * 64))
        reject_changed_file(root, data, 'repinned completed contract verdict',
                            f'{BASE}/attempt-15/round-1/spec-review-contract.json',
                            lambda x: x.__setitem__('verdict', 'PASS'))
        reject_changed_file(root, data, 'repinned historical A manifest',
                            f'reports/review-context/{FEATURE}-spec-a15r1-a-invocation.json',
                            lambda x: x['allowed_input_manifest'][0].__setitem__('sha256', '0' * 64))
        reject_changed_file(root, data, 'repinned historical host receipt',
                            f'{BASE}/attempt-15/round-1/reviewer-a-host-allocation.json',
                            lambda x: x.__setitem__('host_session_id', 'wrong-session'))
        reject_changed_file(root, data, 'canonical ledger chain',
                            'reports/review-context/identity-ledger.json',
                            lambda x: x['records'][-1].__setitem__('record_sha256', '0' * 64))
        combined_rounds(root, data)
        reject_caller_contract(root, data, 'bash')
        caller(root, 'bash')
        ps_root = pathlib.Path(folder).resolve() / 'ps-root'
        ps_data = build(ps_root)
        reject_caller_contract(ps_root, ps_data, 'pwsh')
        caller(ps_root, 'pwsh')
        legacy_root = pathlib.Path(folder).resolve() / 'legacy-root'
        build(legacy_root)
        shutil.rmtree(legacy_root / BASE / 'attempt-16')
        legacy = subprocess.run([sys.executable,
            str(legacy_root / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'),
            str(legacy_root), FEATURE, '16', str(legacy_root / OLD_CONTRACT)],
            capture_output=True, text=True, timeout=60)
        if legacy.returncode != 0 or len(json.loads(legacy.stdout)['completed_rounds']) != 2:
            raise AssertionError('original v2 contract regressed: ' + legacy.stderr[-1000:])
        print('PASS original v2 contract compatibility')


if __name__ == '__main__':
    main()
