"""Focused final checks only; never invokes the repository-wide suite or cloud."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent
SCRATCH = Path("/tmp/cloud-T004-01a14d9e-7a63-71c2-a07c-aa71d275b9de")
PYTHON = "/tmp/cloud-quality-python/bin/python"


def main():
    sources = sorted((ROOT/"plugins/sdd-azure-cloud/scripts").glob("*.py"))
    sources += [ROOT/"tests/cloud-orchestration-routing.tests.py"] + sorted(OUT.glob("*.py"))
    source_paths = [str(p.relative_to(ROOT)) for p in sources]
    checks = [
        ("green", [sys.executable, "-B", "tests/cloud-orchestration-routing.tests.py"]),
        ("contracts-regression", [sys.executable, "-B", "tests/cloud-orchestration-contracts.tests.py"]),
        ("ruff", [PYTHON, "-m", "ruff", "check", "--config", "tests/shared-launch-python/pyproject.toml", *source_paths]),
        ("mypy", [PYTHON, "-m", "mypy", "--config-file", "tests/shared-launch-python/pyproject.toml", *source_paths]),
        ("manifest-validation-final", ["bash", "plugins/sdd-implementation/scripts/validate-task-input-manifest.sh",
            "--manifest", str(OUT.parent.relative_to(ROOT)/"task-input-manifest.json"),
            "--snapshot-root", str(SCRATCH/"inputs"), "--expected-task", "T-004"]),
    ]
    records = []
    for label, command in checks:
        started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        before = time.monotonic()
        proc = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180)
        (OUT/(label+".log")).write_bytes(proc.stdout+proc.stderr)
        records.append(dict(label=label, command=command, start_utc=started, elapsed_seconds=round(time.monotonic()-before, 3),
                            exit_code=proc.returncode, log=str((OUT/(label+".log")).relative_to(ROOT))))
    manifest = json.loads((OUT.parent/"task-input-manifest.json").read_bytes())
    drift = [r["path"] for r in manifest["allowed_inputs"] if hashlib.sha256((ROOT/r["path"]).read_bytes()).hexdigest()!=r["sha256"]]
    sources += [ROOT/"plugins/sdd-quality-loop/scripts/cloud_contracts.py",
                ROOT/"tests/cloud-orchestration-contracts.tests.py", ROOT/"tests/shared-launch-python/pyproject.toml"]
    (OUT/"execution.json").write_text(json.dumps(dict(
        run_id="01a14d9e-7a63-71c2-a07c-aa71d275b9de", task_id="T-004", task_attempt_count=2,
        spec_revision=hashlib.sha256((ROOT/"specs/cloud-orchestration/requirements.md").read_bytes()).hexdigest(),
        input_drift=drift, commands=records,
        source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        full_repository_suite="Not run; root-owned", cloud_calls=0,
        coverage="Not measured; actual task subprocess/native compiler checks, not a coverage claim"), indent=2)+"\n")
    assert not drift, drift
    assert all(r["exit_code"] == 0 for r in records), records


if __name__ == "__main__":
    main()
