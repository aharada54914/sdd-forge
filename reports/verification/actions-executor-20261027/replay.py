"""Replay native attempt fencing with the existing CI origin reconciler."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SNAPSHOT = HERE / 'reconciler/tests'
PINS = {
    'verification-ci.py': '76dacec22dfa24d636ddcb2521e43d7cd2ba08a03d6928e5c4035ddd1a667c2f',
    'verification-impact.py': '3cc48436b3c211398c037e1d0c9178286eb14e26485f3e22c9130fb4b904c502',
    'verification-workflow.py': 'de0b24319f0138bc3d7136e003634a94be837f39ee7cf3607a78ae5756b124cb',
    'verification.py': '968dd3e4ac08cc37efd78e669c97b63186a3deb995a21452e38828ff51b64a7e',
}
for name, expected in PINS.items():
    if hashlib.sha256((SNAPSHOT / name).read_bytes()).hexdigest() != expected:
        raise ValueError(f'reconciler snapshot digest mismatch: {name}')
spec = importlib.util.spec_from_file_location('native_ci_replay', SNAPSHOT / 'verification-ci.py')
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)
history = []
for attempt in range(1, 4):
    packet = json.loads((HERE / f'attempt-{attempt}-jobs.json').read_text())
    job, = [job for job in packet['jobs'] if job['name'] == 'lifecycle (1)']
    history.append(job)


def admissible(rows, record):
    latest, origin = ci.source_job(rows)
    return (latest['status'] == 'completed' and latest['conclusion'] == 'success'
            and record['run_id'] == str(origin['run_id'])
            and record['attempt'] == origin['run_attempt'] == latest['run_attempt']
            and record['head'] == origin['head_sha'] and record['slot'] == '1'
            and record['child_exit'] == 0)


cancelled = json.loads((HERE / 'cancelled-attempt2.json').read_text())
restarted = json.loads((HERE / 'restarted-attempt3.json').read_text())
assert cancelled['child_exit'] == 0, 'Preserve the actual zero-exit artifact from the cancelled attempt'
assert history[1]['conclusion'] == 'cancelled'
assert not admissible(history[:2], cancelled)
assert not admissible(history, cancelled)
assert admissible(history, restarted)
latest, origin = ci.source_job(history)
result = {'schema': 'native-actions-attempt-replay/v1',
          'source_job_helper_sha256': PINS['verification-ci.py'],
          'cancelled_artifact_rejected_at_attempt2': True,
          'cancelled_artifact_rejected_after_restart': True,
          'current_successful_attempt_admitted': True,
          'current_job_id': origin['id'], 'current_attempt': origin['run_attempt'],
          'scope': 'existing origin reconciliation over genuine native observations; no task, approval or gate authority'}
print(json.dumps(result))
