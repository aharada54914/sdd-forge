"""Exercise the exact v4 bounded-wait block against a genuinely SIGSTOPped child."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parent
source = (root / "suite-proposed-v4.sh").read_text()
start = source.index("# Reuse the suite's bounded 10ms polling pattern")
end = source.index('if wait "$copy_pid"; then', start)
block = source[start:end]
script = """set -eu
fail() { printf '%s\\n' "$1"; exit 1; }
bash -c 'kill -STOP "$$"' &
copy_pid=$!
printf 'child=%s\\n' "$copy_pid"
""" + block + "\nexit 99\n"
begin = time.monotonic()
result = subprocess.run(["bash", "-c", script], text=True, capture_output=True, timeout=45)
elapsed = time.monotonic() - begin
pid = int(result.stdout.splitlines()[0].split("=")[1])
try:
    os.kill(pid, 0)
    reaped = False
except ProcessLookupError:
    reaped = True
passed = (result.returncode == 1 and reaped and elapsed < 40
          and "mode-race builder did not exit before deadline" in result.stdout)
record = {"returncode": result.returncode, "stdout": result.stdout, "stderr": result.stderr,
          "elapsed_seconds": elapsed, "child_pid": pid, "child_absent_after_wait": reaped,
          "pass": passed, "scope": "direct stopped child, not arbitrary descendant process trees"}
(root / "stopped-child-v4.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
raise SystemExit(0 if passed else 1)
