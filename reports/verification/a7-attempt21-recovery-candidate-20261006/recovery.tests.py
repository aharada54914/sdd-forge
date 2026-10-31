"""Candidate-only copied-record regression; never reserves or launches."""
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import tempfile

HERE = Path(__file__).resolve().parent
OWNER = HERE.parents[2]
FEATURE = 'epic-195-a7-compatibility'
BASE = f'reports/spec-review/{FEATURE}/attempt-20'
INV = f'reports/review-context/{FEATURE}-spec-a20r2-a-invocation.json'
SESSION = '33bd78fd-c207-44c1-9ef3-d00c2e46b776'
TRANSCRIPT = Path('/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge') / (SESSION + '.jsonl')
BLOCKER = 'reports/verification/a7-attempt20-formal-20261006/round2-transport-failure.md'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture(root):
    paths = [BASE, BLOCKER, 'reports/review-context/identity-ledger.json',
             'plugins/sdd-review-loop/references/review-context-boundary.md']
    paths += [f'reports/review-context/{FEATURE}-spec-a20r{round_no}-{role}-invocation.json'
              for round_no, role in ((1, 'a'), (1, 'b'), (2, 'a'))]
    for rel in paths:
        dest = root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if (OWNER / rel).is_dir():
            shutil.copytree(OWNER / rel, dest)
        else:
            shutil.copy2(OWNER / rel, dest)
    for name in ('failed-last-attempt', 'validate-nontty-spec-launch', 'fresh-review-recovery'):
        dest = root / 'plugins/sdd-review-loop/scripts' / (name + '.py')
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(HERE / (name + '.candidate.py'), dest)
    transcript_rel = 'reports/verification/native/' + SESSION + '.jsonl'
    (root / transcript_rel).parent.mkdir(parents=True)
    shutil.copy2(TRANSCRIPT, root / transcript_rel)
    pre = json.loads((root / BASE / 'round-2/precheck-result.json').read_bytes())
    hashes = {key: pre[key] for key in ('requirements_sha256', 'acceptance_sha256',
              'investigation_sha256', 'calibration_sha256', 'input_sha256')}
    turn = {'failure_mode': 'native-nontty-malformed-result', 'host_session_id': SESSION,
            'transcript_path': transcript_rel, 'transcript_sha256': digest(root / transcript_rel),
            'blocker_path': BLOCKER, 'blocker_sha256': digest(root / BLOCKER), 'files': []}
    return hashes, turn


def repin(root, turn):
    turn['transcript_sha256'] = digest(root / turn['transcript_path'])
    turn['files'] = [{'path': p.relative_to(root).as_posix(), 'sha256': digest(p)}
                     for p in sorted((root / BASE / 'round-2').iterdir()) if p.is_file()]


def edit_json(root, rel, change):
    path = root / rel
    data = json.loads(path.read_bytes())
    change(data)
    path.write_text(json.dumps(data))


def check(label, mutate=None, accept=False, postflight=False):
    with tempfile.TemporaryDirectory(prefix='a21-recovery-') as folder:
        root = Path(folder).resolve()
        hashes, turn = fixture(root)
        repin(root, turn)
        if mutate:
            mutate(root, hashes, turn)
        inspector = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'))
        ledger = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'))
        try:
            result = inspector['inspect'](root, FEATURE, 21, 2, hashes, turn)
            ledger['validate_historical_reservations'](root, result['invocations'])
            if postflight:
                transport = runpy.run_path(str(root / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'))
                transport['postflight'](root, root / INV, root / turn['transcript_path'],
                    root / BASE / 'round-2/reviewer-a-first-turn.txt',
                    root / BASE / 'round-2/reviewer-a-cli-wrapper.json',
                    root / BASE / 'round-2/reviewer-a-reservation-receipt.txt')
        except (ValueError, OSError, KeyError, TypeError) as error:
            assert not accept, (label, str(error))
            print('PASS reject', label, str(error))
        else:
            assert accept, label + ' unexpectedly accepted'
            assert len(result['completed_rounds']) == 1 and len(result['invocations']) == 3
            assert 'verdict' not in result
            print('PASS accept', label)


def wrapper(root, hashes, turn, **changes):
    edit_json(root, BASE + '/round-2/reviewer-a-cli-wrapper.json', lambda data: data.update(changes))
    repin(root, turn)


def transcript(root, hashes, turn, mode):
    path = root / turn['transcript_path']
    events = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    if mode == 'extra':
        events.append({'type': 'user', 'sessionId': SESSION, 'message': {'content': 'extra'}})
    elif mode == 'trailing-tool-result':
        events.append({'type': 'user', 'sessionId': SESSION, 'message': {'content': [
            {'type': 'tool_result', 'tool_use_id': 'pending', 'content': 'unfinished followup'}]}})
    elif mode == 'unfinished':
        for event in events:
            if event.get('type') == 'assistant':
                event.get('message', {})['stop_reason'] = 'max_tokens'
    elif mode == 'wrong':
        events[0]['sessionId'] = 'different'
    path.write_text('\n'.join(json.dumps(event) for event in events) + '\n')
    repin(root, turn)


check('retained A20r2 diagnostic', accept=True)
check('ordinary postflight still rejects fenced result', postflight=True)
check('valid JSON not malformed mode', lambda r, h, t: wrapper(r, h, t, result='{}'))
check('wrong wrapper identity', lambda r, h, t: wrapper(r, h, t, session_id='different'))
check('API failure', lambda r, h, t: wrapper(r, h, t, is_error=True))
check('nonstring result', lambda r, h, t: wrapper(r, h, t, result={}))
check('extra text user', lambda r, h, t: transcript(r, h, t, 'extra'))
check('unfinished turn', lambda r, h, t: transcript(r, h, t, 'unfinished'))
check('wrong native identity', lambda r, h, t: transcript(r, h, t, 'wrong'))
check('current input mismatch', lambda r, h, t: h.update(requirements_sha256='0' * 64))
check('manifest mismatch', lambda r, h, t: edit_json(r, INV, lambda d: d['allowed_input_manifest'].pop()))
check('ledger chain mismatch', lambda r, h, t: edit_json(r, 'reports/review-context/identity-ledger.json',
      lambda d: d['records'][-1].update(previous_record_sha256='0' * 64)))
check('unexpected reviewer output', lambda r, h, t: (r / BASE / 'round-2/reviewer-a.json').write_text('{}'))
check('missing wrapper', lambda r, h, t: (r / BASE / 'round-2/reviewer-a-cli-wrapper.json').unlink())
check('extra inventory path', lambda r, h, t: t['files'].append(dict(t['files'][0])))
check('changed transcript pin', lambda r, h, t: t.update(transcript_sha256='0' * 64))
check('earlier PASS', lambda r, h, t: edit_json(r, BASE + '/round-1/spec-review-contract.json',
      lambda d: d.update(verdict='PASS')))
check('old mode rejects native evidence', lambda r, h, t: t.update(failure_mode='prompt-truncated-before-role-manifest'))
check('unanswered tool-result after end_turn', lambda r, h, t: transcript(r, h, t, 'trailing-tool-result'))
