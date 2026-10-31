#!/usr/bin/env python3
"""Isolated candidate-only fixtures; never opens an attempt or edits owner evidence."""
import importlib.machinery
import hashlib
import json
import pathlib
import shutil
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
OWNER = HERE.parents[2]
FEATURE = 'epic-195-a7-compatibility'
LAST = f'reports/spec-review/{FEATURE}/attempt-15'
loader = importlib.machinery.SourceFileLoader('failed_last_candidate', str(HERE / 'failed-last-attempt.py.candidate'))
candidate = loader.load_module()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False))


def make_tree(root, transcript_source):
    for round_no in (1, 2, 3):
        source = OWNER / LAST / f'round-{round_no}'
        dest = root / LAST / f'round-{round_no}'
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, dest)
        for short_role in (('a', 'b') if round_no < 3 else ('a',)):
            name = f'{FEATURE}-spec-a15r{round_no}-{short_role}-invocation.json'
            original = OWNER / 'reports/review-context' / name
            target = root / 'reports/review-context' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, target)
    transcript_rel = 'reports/verification/local-private/a15r3-host.jsonl'
    target = root / transcript_rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(transcript_source, target)
    return transcript_rel


def check(label, transcript_source, mutate=None, accepted=False, expected_error=None):
    with tempfile.TemporaryDirectory(prefix='a7-failed-last-fixture-') as folder:
        root = pathlib.Path(folder)
        transcript_rel = make_tree(root, transcript_source)
        hashes = {key: value for key, value in
                  json.loads((root / LAST / 'round-3/precheck-result.json').read_text()).items()
                  if key in ('requirements_sha256', 'acceptance_sha256',
                             'investigation_sha256', 'calibration_sha256', 'input_sha256')}
        def digest(rel):
            return hashlib.sha256((root / rel).read_bytes()).hexdigest()
        blocker_rel = LAST + '/round-3/reviewer-a-launch-blocker.md'
        failed_turn = {
            'transcript_path': transcript_rel,
            'transcript_sha256': digest(transcript_rel),
            'blocker_sha256': digest(blocker_rel),
            'host_session_id': json.loads((root / 'reports/review-context' /
                f'{FEATURE}-spec-a15r3-a-invocation.json').read_text())['host_session_id'],
            'failure_mode': 'prompt-truncated-before-role-manifest',
        }
        if mutate:
            mutate(root, transcript_rel, hashes, failed_turn)
        try:
            result = candidate.inspect(root, FEATURE, 16, 3, hashes, failed_turn)
        except (ValueError, OSError, KeyError, TypeError) as error:
            if accepted:
                raise AssertionError(label + ' rejected: ' + str(error)) from error
            if expected_error and expected_error not in str(error):
                raise AssertionError(label + ' wrong rejection: ' + str(error)) from error
            print('PASS reject ' + label + ': ' + str(error))
            return
        if not accepted:
            raise AssertionError(label + ' unexpectedly accepted')
        assert [entry['verdict'] for entry in result['completed_rounds']] == ['NEEDS_WORK', 'NEEDS_WORK']
        assert len(result['invocations']) == 5
        print('PASS accept ' + label)


def bad_verdict(root, transcript_rel, hashes, failed_turn):
    target = root / LAST / 'round-2/spec-review-contract.json'
    data = json.loads(target.read_text())
    data['verdict'] = 'PASS'
    write_json(target, data)


def unfinished(root, transcript_rel, hashes, failed_turn):
    target = root / transcript_rel
    events = [json.loads(line) for line in target.read_text().splitlines() if line.strip()]
    events = [event for event in events if not
              (event.get('type') == 'assistant' and
               event.get('message', {}).get('stop_reason') == 'end_turn')]
    target.write_text('\n'.join(json.dumps(event) for event in events) + '\n')
    failed_turn['transcript_sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()


def changed_input(root, transcript_rel, hashes, failed_turn):
    hashes['requirements_sha256'] = '0' * 64


def reused_session(root, transcript_rel, hashes, failed_turn):
    source = json.loads((root / 'reports/review-context' /
                         f'{FEATURE}-spec-a15r1-a-invocation.json').read_text())
    target = root / 'reports/review-context' / f'{FEATURE}-spec-a15r1-b-invocation.json'
    data = json.loads(target.read_text())
    data['host_session_id'] = source['host_session_id']
    receipt = root / LAST / 'round-1/reviewer-b-host-allocation.json'
    rec = json.loads(receipt.read_text())
    rec['host_session_id'] = source['host_session_id']
    write_json(target, data)
    write_json(receipt, rec)


def unexpected_output(root, transcript_rel, hashes, failed_turn):
    (root / LAST / 'round-3/reviewer-a.json').write_text('{}')


def replay(root, transcript_rel, hashes, failed_turn):
    (root / LAST / 'round-4').mkdir()


def empty_hashes(root, transcript_rel, hashes, failed_turn):
    hashes.clear()


def partial_hashes(root, transcript_rel, hashes, failed_turn):
    hashes.pop('calibration_sha256')


def changed_transcript_pin(root, transcript_rel, hashes, failed_turn):
    failed_turn['transcript_sha256'] = '0' * 64


def changed_blocker_pin(root, transcript_rel, hashes, failed_turn):
    failed_turn['blocker_sha256'] = '0' * 64


def complete_user_prompt(root, transcript_rel, hashes, failed_turn):
    target = root / transcript_rel
    events = [json.loads(line) for line in target.read_text().splitlines() if line.strip()]
    for event in events:
        if event.get('type') == 'user':
            event['message']['content'] = 'REVIEW_CONTEXT_OK spec-reviewer-a full prompt'
    target.write_text('\n'.join(json.dumps(event) for event in events) + '\n')
    failed_turn['transcript_sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()


def change_manifest(root, round_no, role, transform):
    target = root / 'reports/review-context' / f'{FEATURE}-spec-a15r{round_no}-{role}-invocation.json'
    data = json.loads(target.read_text())
    data['allowed_input_manifest'] = transform(data['allowed_input_manifest'])
    write_json(target, data)


def precheck_only(root, transcript_rel, hashes, failed_turn):
    change_manifest(root, 1, 'a', lambda manifest: [item for item in manifest
                    if item['path'].endswith('/precheck-result.json')])


def missing_input(root, transcript_rel, hashes, failed_turn):
    change_manifest(root, 1, 'a', lambda manifest: [item for item in manifest
                    if not item['path'].endswith('/requirements.md')])


def extra_input(root, transcript_rel, hashes, failed_turn):
    change_manifest(root, 1, 'a', lambda manifest: manifest +
                    [{'path': 'specs/extra.md', 'sha256': '0' * 64}])


def mismatched_input(root, transcript_rel, hashes, failed_turn):
    def alter(manifest):
        for item in manifest:
            if item['path'].endswith('/acceptance-tests.md'):
                item['sha256'] = '0' * 64
        return manifest
    change_manifest(root, 2, 'a', alter)


def duplicate_input(root, transcript_rel, hashes, failed_turn):
    def alter(manifest):
        precheck = next(item for item in manifest if item['path'].endswith('/precheck-result.json'))
        summary_index = next(i for i, item in enumerate(manifest)
                             if item['path'].endswith('/integrated-summary.json'))
        manifest[summary_index] = dict(precheck)
        return manifest
    change_manifest(root, 1, 'b', alter)


def missing_b_summary(root, transcript_rel, hashes, failed_turn):
    change_manifest(root, 2, 'b', lambda manifest: [item for item in manifest
                    if not item['path'].endswith('/integrated-summary.json')])


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: failed-last-attempt.fixture.py <local-host-transcript.jsonl>')
    source = pathlib.Path(sys.argv[1]).resolve()
    check('real evidence copy', source, accepted=True)
    for name, change in [('changed verdict', bad_verdict),
                         ('unfinished first turn', unfinished),
                         ('changed current input', changed_input),
                         ('reused host session', reused_session),
                         ('unexpected reviewer output', unexpected_output),
                         ('replayed round', replay),
                         ('empty hashes', empty_hashes),
                         ('partial hashes', partial_hashes),
                         ('changed transcript pin', changed_transcript_pin),
                         ('changed blocker pin', changed_blocker_pin),
                         ('complete review prompt', complete_user_prompt),
                         ('precheck only manifest', precheck_only),
                         ('missing manifest input', missing_input),
                         ('extra manifest input', extra_input),
                         ('mismatched manifest hash', mismatched_input),
                         ('duplicate manifest input', duplicate_input),
                         ('missing reviewer B summary', missing_b_summary)]:
        expected_error = ('failed first turn has no completed host transcript'
                          if name == 'unfinished first turn' else
                          'last-attempt manifest differs from its precheck'
                          if 'manifest' in name or name == 'missing reviewer B summary'
                          else None)
        check(name, source, mutate=change, expected_error=expected_error)
