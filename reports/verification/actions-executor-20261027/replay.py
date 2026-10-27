"""Replay native attempt fencing with the existing CI origin reconciler."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('native_ci_replay', ROOT / 'tests/verification-ci.py')
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
          'source_job_helper_sha256': hashlib.sha256((ROOT / 'tests/verification-ci.py').read_bytes()).hexdigest(),
          'cancelled_artifact_rejected_at_attempt2': True,
          'cancelled_artifact_rejected_after_restart': True,
          'current_successful_attempt_admitted': True,
          'current_job_id': origin['id'], 'current_attempt': origin['run_attempt'],
          'scope': 'existing origin reconciliation over genuine native observations; no task, approval or gate authority'}
(HERE / 'replay-result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
