#!/usr/bin/env python3
"""External native stream recorder; fixture only, never provider/identity/adoption evidence."""
import json
import os
from pathlib import Path
import sys
import time

if sys.argv[1:] == ['--help']:
    print(os.environ['SDD_ACTION_FIXTURE_HELP'])
elif sys.argv[1:] == ['--version']:
    print(os.environ['SDD_ACTION_FIXTURE_VERSION'])
else:
    payload = sys.stdin.buffer.read()
    record_path = Path(os.environ['SDD_ACTION_FIXTURE_RECORD'])
    prior_count = json.loads(record_path.read_text()).get('probe_calls', 0) if record_path.exists() else 0
    record_path.write_text(json.dumps({
        'probe_calls': prior_count + (1 if '--print' in sys.argv else 0),
        'argv': sys.argv[1:], 'stdin_hex': payload.hex(),
        'settings': json.loads((Path.home() / '.claude/settings.json').read_text()),
        'canary': os.environ.get('SDD_ACTION_FIXTURE_CANARY'), 'evidence': 'fixture-only'}))
    if '--print' in sys.argv:
        mode = os.environ.get('SDD_ACTION_FIXTURE_PROBE', 'success')
        nonce = payload.decode().rsplit(': ', 1)[-1]
        session = sys.argv[sys.argv.index('--session-id') + 1]
        label = 'claude-opus-5-5'
        if mode == 'label': label = 'unobserved-model'
        if mode == 'session': session = 'wrong-session'
        events = [dict(type='system', subtype='init', session_id=session, model=label,
                       claude_code_version='2.1.303', cwd=os.getcwd(), tools=['mcp__configured__read'])]
        if mode == 'hook':
            events.append(dict(type='system', subtype='hook_response', session_id=session, exit_code=0))
        block = dict(type='text', text=nonce)
        if mode == 'tool': block = dict(type='tool_use', name='Read', input={})
        if mode == 'server-tool': block = dict(type='server_tool_use', name='web_search', input={})
        events.append(dict(type='assistant', session_id=session, message=dict(model=label, content=[block])))
        result = dict(type='result', subtype='success', is_error=mode == 'is-error', session_id=session,
                      num_turns=1, result='wrong-nonce' if mode == 'nonce' else nonce)
        if mode != 'init-only': events.append(result)
        else: events = events[:1]
        if mode == 'duplicate': events.append(result)
        if mode == 'unknown': events.insert(1, dict(type='unexpected', session_id=session))
        if mode == 'reroute': events.insert(1, dict(type='system', subtype='model_rerouted', session_id=session))
        for event in events: print(json.dumps(event), flush=True)
        print('fixture-probe-stderr', file=sys.stderr, flush=True)
        if os.environ.get('SDD_ACTION_FIXTURE_SECRET'):
            print(os.environ['SDD_ACTION_FIXTURE_SECRET'], file=sys.stderr, flush=True)
        if mode == 'malformed': print('{', flush=True)
        if mode == 'overflow': print('x' * (1024 * 1024 + 1), flush=True)
        if mode == 'stderr-overflow': print('x' * (1024 * 1024 + 1), file=sys.stderr, flush=True)
        if mode == 'timeout': time.sleep(120)
        drift = os.environ.get('SDD_ACTION_FIXTURE_DRIFT')
        if drift:
            with open(drift, 'a') as stream: stream.write('\n ')
        raise SystemExit(23 if mode == 'nonzero' else 0)
    sys.stdout.buffer.write(payload)
    sys.stderr.buffer.write(b'fixture-native-stderr\n')
    raise SystemExit(int(os.environ.get('SDD_ACTION_FIXTURE_EXIT', '0')))
