"""Capture actual bounded task commands without ambient credentials in evidence."""
from pathlib import Path
import datetime
import json
import subprocess
import sys

name, cwd, *command = sys.argv[1:]
evidence = Path(__file__).resolve().parent
start = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with (evidence / (name + '.log')).open('w') as output:
    result = subprocess.run(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT, timeout=1800)
record = dict(command=command, cwd=cwd, started_at=start, exit_code=result.returncode)
(evidence / (name + '.json')).write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
sys.exit(result.returncode)
