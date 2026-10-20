#!/usr/bin/env python3
"""External native stream recorder; fixture only, never provider/identity/adoption evidence."""
import json
import os
from pathlib import Path
import sys

if sys.argv[1:] == ['--help']:
    print(os.environ['SDD_ACTION_FIXTURE_HELP'])
elif sys.argv[1:] == ['--version']:
    print(os.environ['SDD_ACTION_FIXTURE_VERSION'])
else:
    payload = sys.stdin.buffer.read()
    Path(os.environ['SDD_ACTION_FIXTURE_RECORD']).write_text(json.dumps({
        'argv': sys.argv[1:], 'stdin_hex': payload.hex(),
        'settings': json.loads((Path.home() / '.claude/settings.json').read_text()),
        'canary': os.environ.get('SDD_ACTION_FIXTURE_CANARY'), 'evidence': 'fixture-only'}))
    sys.stdout.buffer.write(payload)
    sys.stderr.buffer.write(b'fixture-native-stderr\n')
    raise SystemExit(int(os.environ.get('SDD_ACTION_FIXTURE_EXIT', '0')))
