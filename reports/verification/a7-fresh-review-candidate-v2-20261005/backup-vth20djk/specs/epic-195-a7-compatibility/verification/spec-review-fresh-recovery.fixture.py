#!/usr/bin/env python3
"""Post-human-apply isolated regression; never writes the owner evidence."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
FEATURE = 'epic-195-a7-compatibility'
BASE = f'reports/spec-review/{FEATURE}'
SCRIPT = 'plugins/sdd-review-loop/scripts/spec-review-precheck'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(root):
    for rel in ('plugins/sdd-review-loop', 'plugins/sdd-quality-loop',
                f'specs/{FEATURE}', f'{BASE}/attempt-7', f'{BASE}/attempt-8',
                f'{BASE}/attempt-9', 'reports/review-context'):
        shutil.copytree(ROOT / rel, root / rel)
    output = json.loads((root / BASE / 'attempt-9/round-1/reviewer-a.json').read_text())
    session = output['host_session_id']
    transcript = root / 'fixture-transcript.jsonl'
    # Synthetic host events are fixture data, never real recovery evidence.
    events = [
        {'uuid': 'failed', 'sessionId': session, 'type': 'assistant',
         'message': {'stop_reason': 'end_turn', 'content': [{'type': 'text', 'text': 'BLOCKED'}]}},
        {'uuid': 'resume', 'sessionId': session, 'type': 'user',
         'message': {'content': 'Resume the consumed context'}},
        {'uuid': 'resumed', 'sessionId': session, 'type': 'assistant',
         'message': {'stop_reason': 'end_turn', 'content': [{'type': 'text', 'text': json.dumps(output)}]}}]
    transcript.write_text('\n'.join(json.dumps(x) for x in events) + '\n')
    evidence = [f'{BASE}/attempt-7/round-2/{name}' for name in
                ('spec-review-contract.json', 'precheck-result.json', 'reviewer-a.json',
                 'reviewer-b.json', 'integrated-summary.json', 'integrated-verdict.json')]
    for attempt, leaf in [(8, 'launch-blocker-note.md'), (9, 'reviewer-a.json')]:
        evidence += [f'{BASE}/attempt-{attempt}/round-1/{name}' for name in
                     ('precheck-result.json', 'reviewer-a-host-allocation.json', leaf)]
        evidence.append(f'reports/review-context/{FEATURE}-spec-a{attempt}r1-a-invocation.json')
    evidence.append(transcript.name)
    hashes = {field: digest(root / f'specs/{FEATURE}/{name}') for name, field in
              [('requirements.md', 'requirements_sha256'),
               ('acceptance-tests.md', 'acceptance_sha256'),
               ('investigation.md', 'investigation_sha256')]}
    hashes['calibration_sha256'] = digest(root / 'plugins/sdd-review-loop/references/spec-review-calibration.md')
    hashes['input_sha256'] = hashlib.sha256(':'.join(hashes[k] for k in
        ('requirements_sha256', 'acceptance_sha256', 'investigation_sha256')).encode()).hexdigest()
    contract = {'schema': 'spec-fresh-review-recovery/v1', 'feature': FEATURE,
                'next_attempt': 10, 'reason': 'failed-first-turn-resumed',
                'input_hashes': hashes,
                'evidence': [{'path': p, 'sha256': digest(root / p)} for p in evidence],
                'transcript': {'path': transcript.name, 'failed_end_turn_uuid': 'failed',
                               'resume_uuid': 'resume', 'resumed_end_turn_uuid': 'resumed'}}
    (root / 'fresh-review-contract.json').write_text(json.dumps(contract))


def run(root, runtime):
    contract = root / 'fresh-review-contract.json'
    cmd = (['bash', str(root / SCRIPT) + '.sh', FEATURE, '10', '1', '--reset',
            '--fresh-review-contract=' + str(contract)] if runtime == 'bash' else
           ['pwsh', '-NoProfile', '-File', str(root / SCRIPT) + '.ps1', FEATURE, '10', '1',
            '-Reset', '-FreshReviewContract', str(contract)])
    return subprocess.run(cmd, capture_output=True, text=True, timeout=120)


def main():
    cases = ('valid', 'current-input', 'wrong-attempt', 'evidence-hash', 'missing-reservation',
             'b-invocation', 'transcript-session', 'terminal-contract', 'post-lock-ledger')
    with tempfile.TemporaryDirectory(prefix='a7-fresh-review-') as tmp:
        base = pathlib.Path(tmp) / 'base'
        build(base)
        for runtime in ('bash', 'pwsh'):
            for case in cases:
                root = pathlib.Path(tmp) / (runtime + '-' + case)
                shutil.copytree(base, root)
                contract_path = root / 'fresh-review-contract.json'
                contract = json.loads(contract_path.read_text())
                if case == 'current-input':
                    path = root / f'specs/{FEATURE}/requirements.md'
                    path.write_text(path.read_text() + '\nfixture amendment\n')
                elif case == 'wrong-attempt':
                    contract['next_attempt'] = 11
                elif case == 'evidence-hash':
                    contract['evidence'][0]['sha256'] = '0' * 64
                elif case == 'missing-reservation':
                    (root / 'reports/review-context/identity-ledger.json').write_text('{}')
                elif case == 'b-invocation':
                    (root / f'reports/review-context/{FEATURE}-spec-a9r1-b-invocation.json').write_text('{}')
                elif case in ('transcript-session', 'terminal-contract'):
                    path = root / ('fixture-transcript.jsonl' if case == 'transcript-session' else
                                   f'{BASE}/attempt-7/round-2/spec-review-contract.json')
                    if case == 'transcript-session':
                        events = [json.loads(x) for x in path.read_text().splitlines()]
                        events[0]['sessionId'] = 'wrong-session'
                        path.write_text('\n'.join(json.dumps(x) for x in events))
                    else:
                        data = json.loads(path.read_text())
                        data['verdict'] = 'NEEDS_WORK'
                        path.write_text(json.dumps(data))
                    for entry in contract['evidence']:
                        if entry['path'] == str(path.relative_to(root)):
                            entry['sha256'] = digest(path)
                elif case == 'post-lock-ledger':
                    # Test-only injection in an isolated copy; not a production
                    # hook or a way to apply a candidate around protection.
                    script = root / (SCRIPT + ('.sh' if runtime == 'bash' else '.ps1'))
                    text = script.read_text()
                    marker = ('if [[ -n "$fresh_review_contract" ]]; then\n  fresh_recovery_current='
                              if runtime == 'bash' else '  if ($FreshReviewContract) {\n    $freshRecoveryCurrent =')
                    injection = ("printf '{}' > \"$repo_root/reports/review-context/identity-ledger.json\"\n"
                                 if runtime == 'bash' else
                                 "  [IO.File]::WriteAllText((Join-Path $root 'reports/review-context/identity-ledger.json'), '{}')\n")
                    assert text.count(marker) == 1
                    script.write_text(text.replace(marker, injection + marker))
                contract_path.write_text(json.dumps(contract))
                preserved = {str(p.relative_to(root)): digest(p)
                             for p in (root / BASE).rglob('*') if p.is_file()}
                ledger = root / 'reports/review-context/identity-ledger.json'
                before_ledger = digest(ledger)
                result = run(root, runtime)
                assert (result.returncode == 0) == (case == 'valid'), (runtime, case, result.stdout, result.stderr)
                destination = root / BASE / 'attempt-10/round-1'
                assert destination.exists() == (case == 'valid')
                assert all(digest(root / p) == sha for p, sha in preserved.items())
                if case != 'post-lock-ledger':
                    assert digest(ledger) == before_ledger
                if case == 'valid':
                    precheck = json.loads((destination / 'precheck-result.json').read_text())
                    assert precheck['fresh_review_contract_sha256'] == digest(contract_path)
                    assert sorted(p.name for p in destination.iterdir()) == ['precheck-result.json']
                    assert run(root, runtime).returncode != 0
                print('PASS', runtime, case)


if __name__ == '__main__':
    main()
