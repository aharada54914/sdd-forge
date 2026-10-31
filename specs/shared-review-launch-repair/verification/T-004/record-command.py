"""Capture exact child streams and expected exits without treating RED as GREEN."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

name, expected, *command = sys.argv[1:]
evidence = Path(__file__).resolve().parent
root = evidence.parents[3]
output = root.parent
env = dict(os.environ, TMPDIR=str(output / 'tmp'), PYTHONDONTWRITEBYTECODE='1',
           npm_config_cache=str(output / 'npm-cache'))
env.pop('NODE_PATH', None)
env.pop('NODE_OPTIONS', None)
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
result = subprocess.run(['rtk', 'proxy', *command], cwd=root, env=env,
                        capture_output=True, text=True)
record = {'command': ['rtk', 'proxy', *command], 'cwd': str(root),
          'started_at': started, 'expected_exit': int(expected),
          'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr,
          'environment': {key: env[key] for key in ('TMPDIR', 'PYTHONDONTWRITEBYTECODE', 'npm_config_cache')},
          'source_sha256': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in
                            ('.github/workflows/test.yml', 'tests/run-all.sh', 'tests/run-all.ps1',
                             'tests/task-structured-output.tests.py', 'tests/host-review-preflight.tests.py',
                             'mcp/ci-mcp/package.json', 'mcp/ci-mcp/package-lock.json')}}
(evidence / (name + '.json')).write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
assert result.returncode == int(expected), 'unexpected exit; stop and retain evidence'
