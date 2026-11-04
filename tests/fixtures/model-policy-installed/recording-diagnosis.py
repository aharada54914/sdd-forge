#!/usr/bin/env python3
"""Public CLI diagnosis fixture: actual owned failing regression and report, no model intelligence or backend proof."""
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    spec = json.loads(Path(os.environ['SDD_DIAGNOSIS_FIXTURE']).read_text())
    argv = sys.argv[1:]

    def note(event, **data):
        with Path(spec['log']).open('a') as stream:
            stream.write(json.dumps({'event': event, 'argv': argv, **data}) + '\n')

    if argv in (['--help'], ['--version']):
        note(argv[0][2:])
        if argv == ['--help']:
            for edit in spec.get('edit_on_help', []):
                Path(edit['path']).write_text(edit['text'])
        print(spec['help'] if argv == ['--help'] else spec['version'])
        return 0
    payload = sys.stdin.read(16 * 1024 * 1024 + 1)
    try:
        assert argv[0] == '--print'
        assert len(argv) == 9 and len(set(argv[1::2])) == 4
        options = dict(zip(argv[1::2], argv[2::2]))
        assert set(options) == {'--output-format', '--model', '--effort', '--session-id'}
        assert options['--output-format'] == 'json'
        assert (options['--model'], options['--effort']) == (spec['model'], spec['effort'])
        assert options['--session-id'] == spec['session_id']
        assert 'already the fresh diagnosis context' in payload and 'do not invoke Skill or Agent' in payload
        assert payload.count(spec['instructions']) == 1
        for name, text in spec['sources'].items():
            assert name in payload and payload.count(text) == 1, 'full original diagnosis source missing'
        assert os.environ.get(spec['canary_name']) == spec['canary_value']
        sessions = Path(spec['sessions'])
        assert not sessions.exists() or options['--session-id'] not in sessions.read_text().splitlines()
        assert Path(spec['target']).read_text() == spec['target_content']
    except (AssertionError, KeyError, ValueError) as failure:
        note('rejected', detail=str(failure), stdin=payload)
        print(json.dumps({'type': 'result', 'is_error': True, 'result': 'diagnosis fixture carrier rejected'}))
        return 71
    with Path(spec['sessions']).open('a') as stream:
        stream.write(options['--session-id'] + '\n')
    # Authorized diagnostic evidence, not a product fix. The genuine failing command must run before the report.
    harness = Path(spec['harness'])
    harness.write_text('from sample import total\nassert total(1) == 2, "reported regression: total(1) must equal 2"\n')
    loop = subprocess.run([sys.executable, '-B', str(harness)], cwd=harness.parent,
                          capture_output=True, text=True, timeout=10)
    if loop.returncode != 1 or 'reported regression' not in loop.stderr:
        note('rejected', detail='diagnostic loop did not reproduce the owned defect')
        return 72
    Path(spec['report']).write_text('# Diagnosis Report: fixture\n\n## Phase 1 — Feedback loop\n'
                                  'Command: python3 -B regression.py\nRed output: reported regression\n'
                                  '## Phase 5 — Root cause + fix\nProduct fix deferred to approved implement-task.\n'
                                  '## Handoff\nTrack: lite\nNext: /sdd-lite:lite-spec\n')
    note('work', stdin=payload, loop_exit_code=loop.returncode, model=options['--model'], effort=options['--effort'])
    if spec.get('reject_work'):
        return 72
    mode = spec.get('reply_mode')
    if mode == 'malformed':
        print('not JSON')
        return 0
    result = {'type': 'result', 'is_error': mode == 'error-with-zero-exit',
              'result': 'Diagnosis reproduction failed as expected; harness and report ready; product unchanged.',
              'session_id': spec['other_session_id'] if mode == 'wrong-session' else spec['session_id'],
              'modelUsage': {'fixture-aggregate-not-actual-identity': {'inputTokens': 1}}}
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
