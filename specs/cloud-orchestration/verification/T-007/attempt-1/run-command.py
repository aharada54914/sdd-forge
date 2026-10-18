"""Scoped local command evidence; never serializes inherited environment."""
from pathlib import Path
import datetime
import json
import subprocess
import sys
import time

root = Path(__file__).resolve().parent
label, *command = sys.argv[1:]
started = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
tick = time.monotonic()
with (root / (label + ".log")).open("wb") as stream:
    result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
record = dict(command=command, cwd=str(Path.cwd()), started_at=started, exit_code=result.returncode, elapsed_seconds=round(time.monotonic()-tick, 3), classification="offline local command; no live cloud")
(root / (label + ".json")).write_text(json.dumps(record, indent=2) + "\n")
print(label, result.returncode, record["elapsed_seconds"], flush=True)
raise SystemExit(result.returncode)
