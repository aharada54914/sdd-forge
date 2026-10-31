"""Persist final static checks while retaining the evaluated output bindings."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent / "final-static"
OUT.mkdir(exist_ok=False)
bindings = json.loads((OUT.parent / "attempt-2/binding-after.json").read_text())


def verify():
    for row in bindings:
        actual = hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest()
        if actual != row["expected"]:
            raise RuntimeError("evaluated output changed: " + row["path"])


verify()
config = "tests/shared-launch-python/pyproject.toml"
commands = {
    "lint": ["/tmp/shared-launch-static-20261008/bin/ruff", "check", "--no-cache", "--config", config, "tests/host-review-preflight.tests.py"],
    "typecheck": ["/tmp/shared-launch-static-20261008/bin/mypy", "--cache-dir", "/tmp/shared-launch-t003-production-mypy", "--config-file", config],
    "workflow": ["bash", "plugins/sdd-quality-loop/scripts/check-workflow-state.sh"],
}
results = []
for name, command in commands.items():
    run = subprocess.run(["rtk", "proxy", *command], cwd=ROOT,
                         env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"),
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (OUT / (name + ".log")).write_bytes(run.stdout)
    results.append({"check": name, "command": command, "exit_code": run.returncode,
                    "log_sha256": hashlib.sha256(run.stdout).hexdigest()})
    (OUT / "checks.json").write_text(json.dumps(results, indent=2) + "\n")
    print(name, run.returncode, flush=True)
verify()
(OUT / "binding-after.json").write_text(json.dumps(bindings, indent=2) + "\n")
raise SystemExit(int(any(row["exit_code"] for row in results)))
