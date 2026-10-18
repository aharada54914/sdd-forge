"""Scoped deterministic checks only; no full repository suite or cloud calls."""

from pathlib import Path
import json
import os
import shlex
import subprocess

ROOT = Path.cwd()
OUT = ROOT / "specs/cloud-orchestration/verification/T-006/attempt-3"
PYTHON = "/tmp/cloud-quality-python/bin/python"
CONFIG = "tests/shared-launch-python/pyproject.toml"
SHARED = [
    "plugins/sdd-quality-loop/scripts/cloud_verification.py",
    "tests/cloud-orchestration-verification.tests.py",
]
SHARED += [
    "specs/cloud-orchestration/verification/T-006/attempt-3/" + name + ".py"
    for name in ("verify-local", "rollback", "matrix-runner")
]
AWS = [str(p) for p in sorted(Path("plugins/sdd-aws-cloud/scripts").glob("*.py"))]
AZURE = [str(p) for p in sorted(Path("plugins/sdd-azure-cloud/scripts").glob("*.py"))]
commands = [
    (name, ["python3", "-B", "tests/cloud-orchestration-" + name + ".tests.py"])
    for name in ("verification", "execution", "routing", "contracts")
]
commands += [
    ("ruff", [PYTHON, "-m", "ruff", "check", "--config", CONFIG, *SHARED, *AWS, *AZURE])
]
commands += [
    ("mypy-" + name, [PYTHON, "-m", "mypy", "--config-file", CONFIG, *files])
    for name, files in (("shared", SHARED), ("aws", AWS), ("azure", AZURE))
]
results = []
env = dict(
    os.environ,
    MYPYPATH="plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts",
)
for name, command in commands:
    p = subprocess.run(
        command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    prefix = "MYPYPATH=" + env["MYPYPATH"] + " " if name.startswith("mypy") else ""
    (OUT / ("final-" + name + ".log")).write_bytes(
        ("$ " + prefix + shlex.join(command) + "\n").encode()
        + p.stdout
        + f"\nExit code: {p.returncode}\n".encode()
    )
    results.append(
        dict(name=name, command=prefix + shlex.join(command), exit_code=p.returncode)
    )
    print(name, p.returncode, flush=True)
(OUT / "final-checks.json").write_text(json.dumps(results, indent=2) + "\n")
raise SystemExit(any(row["exit_code"] != 0 for row in results))
