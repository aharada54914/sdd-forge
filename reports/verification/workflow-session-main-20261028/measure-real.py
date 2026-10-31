"""Compare one full check with a batch attempt and its required cold fallback."""
import hashlib
import json
import subprocess
import tempfile
import time
from pathlib import Path

root = Path.cwd()
gate = root / 'plugins/sdd-quality-loop/scripts/check-workflow-state.sh'
registry = root / 'specs/workflow-state-registry.json'
assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='sdd-real-batch-') as directory:
    request = Path(directory) / 'requests.json'
    request.write_text(json.dumps({'schema': 'workflow-state-batch/v1', 'requests': ['first', 'second']}))
    started = time.monotonic()
    normal = subprocess.run(['bash', str(gate), '--registry', str(registry)], capture_output=True)
    normal_seconds = time.monotonic() - started
    started = time.monotonic()
    candidate = subprocess.run(['bash', str(gate), '--registry', str(registry), '--batch', str(request)],
                               capture_output=True, text=True)
    batch_seconds = time.monotonic() - started
    try:
        result = json.loads(candidate.stdout)
    except json.JSONDecodeError:
        result = {}
    fallback = None
    if candidate.returncode == 2 and result.get('status') == 'cold-required':
        started = time.monotonic()
        recovered = subprocess.run(['bash', str(gate), '--registry', str(registry)], capture_output=True)
        fallback = {'exit_code': recovered.returncode, 'seconds': round(time.monotonic() - started, 3),
                    'stdout_sha256': hashlib.sha256(recovered.stdout).hexdigest(),
                    'stderr_sha256': hashlib.sha256(recovered.stderr).hexdigest()}
    assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()
    print(json.dumps({'scope': 'one ordered local comparison on the actual branch; no task approval or full-lifecycle claim',
                      'head': head, 'gate_sha256': hashlib.sha256(gate.read_bytes()).hexdigest(),
                      'ordinary': {'exit_code': normal.returncode, 'seconds': round(normal_seconds, 3),
                                   'stdout_sha256': hashlib.sha256(normal.stdout).hexdigest(),
                                   'stderr_sha256': hashlib.sha256(normal.stderr).hexdigest()},
                      'batch': {'exit_code': candidate.returncode, 'seconds': round(batch_seconds, 3),
                                'status': result.get('status'), 'reason': result.get('reason'),
                                'complete': result.get('complete')}, 'fallback': fallback}, indent=2))
