"""Run one bounded local check and preserve its actual command, exit and output."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time
label, *command = sys.argv[1:]
evidence = Path(__file__).resolve().parent
root = evidence.parents[4]
env = dict(os.environ, TMPDIR="/workspace/.task-scratch/ci-model-modernization", PYTHONDONTWRITEBYTECODE="1")
env["PATH"] = "/workspace/.tools/sdd-forge-dev/bin:" + env["PATH"]
start = time.monotonic()
result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True)
(evidence / (label + ".log")).write_text(result.stdout + result.stderr)
record = dict(label=label, command=command, cwd=str(root), timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(), exit_code=result.returncode, elapsed_seconds=time.monotonic()-start, environment={k:env[k] for k in ("TMPDIR","PYTHONDONTWRITEBYTECODE")})
(evidence / (label + ".json")).write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record))
print((result.stdout + result.stderr)[-1800:])
sys.exit(result.returncode)
