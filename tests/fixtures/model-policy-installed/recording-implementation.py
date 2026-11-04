#!/usr/bin/env python3
"""Public CLI single-task implementation fixture: actual owned code change, passing test and report, no model intelligence or backend proof."""
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    spec = json.loads(Path(os.environ['SDD_IMPLEMENTER_FIXTURE']).read_text())
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
        assert 'already the fresh implementer context' in payload and 'do not reallocate this implementation context' in payload
        assert payload.count(spec['instructions']) == 1
        for name, text in spec['sources'].items():
            assert name in payload and payload.count(text) == 1, 'full original implementation source missing'
        assert os.environ.get(spec['canary_name']) == spec['canary_value']
        sessions = Path(spec['sessions'])
        assert not sessions.exists() or options['--session-id'] not in sessions.read_text().splitlines()
        assert Path(spec['target']).read_text() == spec['target_content']
        assert str(Path.cwd()) == spec['project_root']
        assert spec['task_ref'] in payload
        assert Path(spec['task_file']).read_text() == spec['tasks_before']
        assert 'Approval: Approved' in spec['tasks_before'].split('## T-999', 1)[1]
    except (AssertionError, KeyError, ValueError) as failure:
        note('rejected', detail=str(failure), stdin=payload)
        print(json.dumps({'type': 'result', 'is_error': True, 'result': 'implementation fixture carrier rejected'}))
        return 71
    with Path(spec['sessions']).open('a') as stream:
        stream.write(options['--session-id'] + '\n')
    precheck = subprocess.run(['/usr/bin/bash', spec['precheck']], cwd=spec['project_root'],
                              capture_output=True, text=True, timeout=10)
    if precheck.returncode:
        note('rejected', detail='owned project structural precheck failed')
        return 72
    Path(spec['target']).write_text('def total(value):\n    return value + 1\n')
    loop = subprocess.run([sys.executable, '-B', spec['public_test']], cwd=spec['project_root'],
                          capture_output=True, text=True, timeout=10)
    if loop.returncode:
        note('rejected', detail='owned implementation regression did not pass')
        return 72
    Path(spec['task_file']).write_text(spec['tasks_before'].replace(
        'Status: In Progress', 'Status: Implementation Complete', 1))
    Path(spec['report']).write_text('# Implementation Report: T-999\n\nRun ID: ' + spec['run_id']
        + '\nTask Attempt Count: 1\n- Model: ' + options['--model'] + '\n- Effort: '
        + options['--effort'] + '\n\nChanged only work/sample.py; actual regression command passed.\n'
        + 'Status: Implementation Complete; independent quality gate remains separate.\n')
    note('work', stdin=payload, loop_exit_code=loop.returncode, model=options['--model'],
         effort=options['--effort'], task_ref=spec['task_ref'])
    if spec.get('reject_work'):
        return 72
    mode = spec.get('reply_mode')
    if mode == 'malformed':
        print('not JSON')
        return 0
    result = {'type': 'result', 'is_error': mode == 'error-with-zero-exit',
              'result': 'Selected single-task implementation completed; regression passed; independent gate still required.',
              'session_id': spec['other_session_id'] if mode == 'wrong-session' else spec['session_id'],
              'modelUsage': {'fixture-aggregate-not-actual-identity': {'inputTokens': 1}}}
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
