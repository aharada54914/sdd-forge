from pathlib import Path
import datetime
import hashlib
import json
import os
import subprocess
import time

root = Path('/workspace/sdd-forge')
b = root / 'specs/ci-model-modernization/verification/T-007/root-native-smoke'
driver = b / 'capture-v4-qa1-fix.py'
assert hashlib.sha256(driver.read_bytes()).hexdigest() == '6d8b357159ebbbdc16bdca9c75717dc6d05b8d9d40318e6a449547c0e3eba4a3'
assert not (b / 'actual-qa1-fix-final').exists()
command = ['/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3', '-B', str(driver)]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
t0 = time.monotonic()
with (b / 'native-qa1-fix-final.stdout.log').open('xb') as output, (b / 'native-qa1-fix-final.stderr.log').open('xb') as errors:
    try:
        process = subprocess.run(command, cwd=root, env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'),
                                 stdout=output, stderr=errors, timeout=180, check=False)
        code, timed_out = process.returncode, False
    except subprocess.TimeoutExpired:
        code, timed_out = 124, True
logs = [{'path': str((b / name).relative_to(root)), 'sha256': hashlib.sha256((b / name).read_bytes()).hexdigest()}
        for name in ['native-qa1-fix-final.stdout.log', 'native-qa1-fix-final.stderr.log']]
result = {'command': command, 'started_at': started,
          'finished_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'elapsed_seconds': time.monotonic() - t0, 'exit_code': code, 'timed_out': timed_out,
          'controller_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'driver_sha256': hashlib.sha256(driver.read_bytes()).hexdigest(), 'logs': logs}
with (b / 'command-qa1-fix-final.json').open('x') as stream:
    stream.write(json.dumps(result, indent=2) + '\n')
print(json.dumps({'exit_code': code, 'timed_out': timed_out, 'elapsed_seconds': result['elapsed_seconds']}))
raise SystemExit(code)
