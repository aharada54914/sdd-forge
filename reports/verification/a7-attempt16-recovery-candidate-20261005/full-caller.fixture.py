#!/usr/bin/env python3
"""Run the candidate Bash/PowerShell prechecks only inside isolated copies."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
OWNER = HERE.parents[2]
FEATURE = 'epic-195-a7-compatibility'
OLD = OWNER / 'reports/verification/a7-spec-fresh-review-contract-attempt15-20261005.json'
BASE = f'reports/spec-review/{FEATURE}/attempt-15'
CONTRACT = 'reports/verification/fixture-attempt16-contract.json'
TRANSCRIPT = 'reports/verification/fixture-private-a15r3-host.jsonl'
AUTHORITY = 'reports/verification/fixture-attempt16-approval.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False))


def build(root, baseline, raw_transcript):
    shutil.copytree(baseline, root)
    old = json.loads(OLD.read_text())
    for item in old['evidence']:
        rel = item['path']
        if rel in (old['transcript']['path'], old['authority']['path']):
            continue
        destination = root / rel
        if destination.exists():
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(OWNER / rel, destination)
    target = root / TRANSCRIPT
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(raw_transcript, target)
    old['next_attempt'] = 16
    specs = root / 'specs' / FEATURE
    hashes = {
        'requirements_sha256': digest(specs / 'requirements.md'),
        'acceptance_sha256': digest(specs / 'acceptance-tests.md'),
        'investigation_sha256': digest(specs / 'investigation.md')
        if (specs / 'investigation.md').exists() else None,
        'calibration_sha256': digest(root / 'plugins/sdd-review-loop/references/spec-review-calibration.md'),
    }
    values = [hashes['requirements_sha256'], hashes['acceptance_sha256']]
    if hashes['investigation_sha256']:
        values.append(hashes['investigation_sha256'])
    hashes['input_sha256'] = hashlib.sha256(':'.join(values).encode()).hexdigest()
    old['input_hashes'] = hashes
    old['partial_attempts'] = list(range(8, 16))
    old['transcript'] = {'path': TRANSCRIPT}
    old['authority'] = {'path': AUTHORITY}
    old['failed_final_round'] = 3
    receipt = json.loads((root / BASE / 'round-3/reviewer-a-host-allocation.json').read_text())
    old['failed_turn'] = {
        'transcript_path': TRANSCRIPT,
        'transcript_sha256': digest(root / TRANSCRIPT),
        'blocker_sha256': digest(root / BASE / 'round-3/reviewer-a-launch-blocker.md'),
        'host_session_id': receipt['host_session_id'],
        'failure_mode': 'prompt-truncated-before-role-manifest',
    }
    evidence_paths = {item['path'] for item in old['evidence']
                      if item['path'] not in
                      ('reports/verification/a7-spec-attempt14-diagnostic-transcript-attempt15-20261005.json',
                       'reports/verification/a7-spec-fresh-review-approval-attempt15-20261005.json')}
    for round_no in (1, 2, 3):
        round_rel = f'{BASE}/round-{round_no}'
        evidence_paths.update(round_rel + '/' + p.name for p in (root / round_rel).iterdir())
        for role in (('a', 'b') if round_no < 3 else ('a',)):
            evidence_paths.add(f'reports/review-context/{FEATURE}-spec-a15r{round_no}-{role}-invocation.json')
    evidence_paths.update((TRANSCRIPT, AUTHORITY))
    save(root / AUTHORITY, {
        'schema': 'spec-fresh-review-approval-audit/v1', 'feature': FEATURE,
        'next_attempt': 16, 'origin': 'current-user-conversation',
        'recorded_by_role': 'orchestrator', 'user_statement': 'SYNTHETIC fixture approval',
        'scope': 'quarantine-history-and-start-fresh-review-only',
        'input_hashes': old['input_hashes'],
    })
    old['evidence'] = [{'path': rel, 'sha256': digest(root / rel)}
                       for rel in sorted(evidence_paths)]
    save(root / CONTRACT, old)


def run(root, runtime, changed=False):
    contract = root / CONTRACT
    if changed:
        data = json.loads(contract.read_text())
        data['failed_turn']['blocker_sha256'] = '0' * 64
        save(contract, data)
    script = root / 'plugins/sdd-review-loop/scripts/spec-review-precheck'
    command = (['bash', str(script) + '.sh', FEATURE, '16', '1', '--reset',
                '--fresh-review-contract=' + str(contract)] if runtime == 'bash' else
               ['pwsh', '-NoProfile', '-File', str(script) + '.ps1', FEATURE, '16', '1',
                '-Reset', '-FreshReviewContract', str(contract)])
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    expected = 1 if changed else 0
    if result.returncode != expected:
        raise AssertionError(f'{runtime} changed={changed}: exit {result.returncode}: '
                             + result.stderr[-1200:] + result.stdout[-1200:])
    if changed and 'failed-turn diagnostic binding mismatch' not in result.stderr:
        raise AssertionError(f'{runtime} did not reject changed blocker pin: ' + result.stderr[-800:])
    if not changed and not (root / f'reports/spec-review/{FEATURE}/attempt-16/round-1/precheck-result.json').exists():
        raise AssertionError(f'{runtime} did not create isolated precheck')
    print(f'PASS {runtime} ' + ('reject changed blocker pin' if changed else 'admit fresh attempt'))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: full-caller.fixture.py <candidate-baseline-root> <local-transcript>')
    baseline, raw = (pathlib.Path(arg).resolve() for arg in sys.argv[1:])
    with tempfile.TemporaryDirectory(prefix='a7-failed-caller-') as folder:
        for runtime in ('bash', 'pwsh'):
            for changed in (False, True):
                root = (pathlib.Path(folder) /
                        (runtime + ('-reject' if changed else '-valid'))).resolve()
                build(root, baseline, raw)
                run(root, runtime, changed)
