import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
from unittest.mock import patch

output = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('order', output / 'work/tests/unified-launch-order.tests.py')
order = importlib.util.module_from_spec(spec)
spec.loader.exec_module(order)
actual_run = subprocess.run
observations = []

def observe(command, **kwargs):
    ledger = Path(kwargs['cwd']) / 'reports/review-context/identity-ledger.json'
    before = ledger.read_bytes()
    result = actual_run(command, **kwargs)
    after = ledger.read_bytes()
    observations.append(dict(command=command, returncode=result.returncode,
        stdout=result.stdout, stderr=result.stderr,
        before_sha256=hashlib.sha256(before).hexdigest(),
        after_sha256=hashlib.sha256(after).hexdigest(),
        before=json.loads(before), after=json.loads(after)))
    return result

cases = []
for runtime in ('bash', 'powershell'):
    for stage in ('spec', 'impl', 'task'):
        start = len(observations)
        with patch.object(subprocess, 'run', side_effect=observe):
            events = order.LaunchOrderTests().exercise('postappend-receipt', stage, runtime)
        cases.append(dict(runtime=runtime, stage=stage, failure='postappend-receipt',
                          events=events, validators=observations[start:]))
        print(json.dumps(dict(runtime=runtime, stage=stage, calls=len(observations)-start,
                              child_invocations=events.count('wrapper.json'),
                              launcher_reservations=events.count('reserved.txt'))))
evidence = output / 'work/specs/shared-review-launch-repair/verification/T-005/attempt-2'
(evidence / 'fixture-receipts.json').write_text(json.dumps(cases, indent=2) + '\n')
