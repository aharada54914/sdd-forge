#!/usr/bin/env python3
"""External ordinary Claude fixture: public JSON result, owned source read, no backend or model intelligence."""
import json
import os
from pathlib import Path
import sys
from typing import Any


def main():
    spec = json.loads(Path(os.environ['SDD_INVESTIGATOR_FIXTURE']).read_text())
    argv = sys.argv[1:]
    event = {'argv': argv}
    log = Path(spec['log'])

    def note(kind, **data):
        with log.open('a') as output:
            output.write(json.dumps({'event': kind, **event, **data}, sort_keys=True) + '\n')

    if argv in (['--help'], ['--version']):
        with Path(spec['calls']).open('a') as calls:
            calls.write(argv[0] + '\n')
    if argv == ['--help']:
        note('help')
        for edit in spec.get('edit_on_help', []):
            Path(edit['path']).write_text(edit['text'])
        print(spec['help'], end='')
        return 0
    if argv == ['--version']:
        note('version')
        print(spec['version'])
        return 0
    payload = sys.stdin.read(16 * 1024 * 1024 + 1)
    options: dict[str, Any] = {}
    flags = {'--print', '--verbose'}
    pairs = {'--output-format', '--model', '--effort', '--session-id', '--agent', '--agents',
             '--tools', '--disallowedTools'}
    index = 0
    try:
        while index < len(argv):
            key = argv[index]
            assert key not in options, 'duplicate native option'
            if key in flags:
                options[key] = True
                index += 1
            else:
                assert key in pairs and index + 1 < len(argv), 'unexpected native option'
                options[key] = argv[index + 1]
                index += 2
        assert options['--print'] is True and options['--output-format'] == 'json'
        assert options['--model'] == spec['model'] and options['--effort'] == spec['effort']
        assert options['--session-id'] == spec['session_id']
        assert options['--agent'] == 'sdd-investigator'
        assert options['--tools'].split(',') == ['Read', 'Grep', 'Glob', 'Bash']
        assert options['--disallowedTools'].split(',') == ['Write', 'Edit', 'NotebookEdit']
        agents = json.loads(options['--agents'])
        assert set(agents) == {'sdd-investigator'}
        agent = agents['sdd-investigator']
        assert set(agent) == {'description', 'prompt', 'tools', 'disallowedTools', 'model', 'effort'}
        assert isinstance(agent['description'], str) and agent['description']
        assert agent['prompt'] == spec['role_body']
        assert agent['tools'] == ['Read', 'Grep', 'Glob', 'Bash']
        assert agent['disallowedTools'] == ['Write', 'Edit', 'NotebookEdit']
        assert (agent['model'], agent['effort']) == (spec['model'], spec['effort'])
        assert len(payload.encode()) <= 16 * 1024 * 1024
        for path, content in spec['sources'].items():
            assert path in payload and payload.count(content) == 1, 'missing or abbreviated skill/reference'
        assert payload.count(spec['instructions']) == 1
        assert 'already the fresh investigator context' in payload
        assert 'do not invoke Skill or Agent' in payload
        assert os.environ.get(spec['canary_name']) == spec['canary_value']
        sessions = Path(spec['sessions'])
        previous = sessions.read_text().splitlines() if sessions.exists() else []
        assert options['--session-id'] not in previous, 'native session already exists; resume is forbidden'
        text = Path(spec['target']).read_text()  # the fixture performs a real owned codebase read
        assert text == spec['target_content']
    except (AssertionError, KeyError, ValueError) as failure:
        note('rejected', message=str(failure), stdin=payload)
        print(json.dumps({'type': 'result', 'is_error': True, 'result': 'fixture carrier rejection'}))
        return 71
    with Path(spec['sessions']).open('a') as session_log:
        session_log.write(options['--session-id'] + '\n')
    note('work', stdin=payload, agent=agent)
    if spec.get('reject_work'):
        print(json.dumps({'type': 'result', 'is_error': True, 'result': 'fixture ordinary work rejected'}))
        return 72
    mode = spec.get('reply_mode', 'success')
    if mode == 'malformed':
        print('not one public JSON result')
        return 0
    if mode == 'overflow':
        print('x' * (16 * 1024 * 1024 + 1))
        return 0
    result = {'type': 'result', 'is_error': False,
              'result': 'INV-001 sample.py:1 defines total(value); BL-001 sample.py:2 returns value + 1.',
              'session_id': spec['session_id'],
              'modelUsage': {'fixture-aggregate-must-not-become-actual-id': {'inputTokens': 1}}}
    if mode == 'error-with-zero-exit':
        result['is_error'] = True
    elif mode == 'empty-result':
        result['result'] = '  '
    elif mode == 'wrong-session':
        result['session_id'] = spec['other_session_id']
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
