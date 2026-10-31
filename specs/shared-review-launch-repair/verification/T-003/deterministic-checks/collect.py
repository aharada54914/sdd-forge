"""Collect current T-003 checks without modifying product or review state."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent / "attempt-2"
OUT.mkdir(exist_ok=False)
REPORT = ROOT / "reports/implementation/shared-review-launch-repair/T-003.md"


def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


save("scope-before.json", {
    "task": "T-003", "owner": str(ROOT), "risk": "high",
    "scope": "Evidence collection only; no lifecycle, ledger or product writes",
    "contracts": ["verification-contract/v2", "implementation-report/v2"],
    "required_validation": "24 output bindings, regressions, deterministic checks, independent evaluation and evidence bundle",
    "head": subprocess.check_output(["rtk", "proxy", "git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "dirty": subprocess.check_output(["rtk", "proxy", "git", "status", "--short"], cwd=ROOT, text=True),
})
body = REPORT.read_text().split("## Outputs\n", 1)[1].split("\n## ", 1)[0]
rows = re.findall(r"^\| `([^`]+)` \| `([0-9a-f]{64})` \|$", body, re.M)
assert len(rows) == 24, len(rows)


def binding(name):
    result = [{"path": path, "expected": expected, "actual": sha(ROOT / path)} for path, expected in rows]
    save(name, result)
    assert all(row["expected"] == row["actual"] for row in result), "output drift"


binding("binding-before.json")
base = "specs/shared-review-launch-repair/verification/T-003/"
save("traceability.json", {"feature": "shared-review-launch-repair", "links": [{"req": "REQ-006", "acs": ["AC-006"],
    "tests": ["TEST-011a", "TEST-011b", "TEST-011c", "TEST-011d", "TEST-011e", "TEST-011f", "TEST-012a", "TEST-012b", "TEST-012c", "TEST-012d", "TEST-013"],
    "evidence": [base + "focused-host.json", base + "regression-mutations.json", base + "final-generator.json", base + "final-parity.json"]}]})
quality = "plugins/sdd-quality-loop/scripts/"
commands = {
    "host-regression": ["python3", "-B", "tests/host-review-preflight.tests.py", "-v"],
    "generator": ["python3", "-B", quality + "generate-guard-invariants.py", "--check"],
    "build": ["python3", "-B", "tests/shared-launch-build.tests.py", "-v"],
    "placeholder": ["bash", quality + "check-placeholders.sh", "tests/host-review-preflight.tests.py"],
    "risk": ["bash", quality + "check-risk.sh", "specs/shared-review-launch-repair/tasks.md"],
    "task-state": ["bash", quality + "check-task-state.sh", "specs/shared-review-launch-repair/tasks.md", "reports/quality-gate", "reports/implementation", "."],
    "component": ["python3", "-B", quality + "check-component-coverage.py", "--repo-root", "."],
    "traceability": ["bash", quality + "check-traceability.sh", str(OUT / "traceability.json"), ".", "require-evidence"],
    "report": ["bash", "plugins/sdd-implementation/scripts/validate-implementation-report.sh", str(REPORT)],
}
results = []
for name, command in commands.items():
    run = subprocess.run(["rtk", "proxy", *command], cwd=ROOT, env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    log = OUT / (name + ".log")
    log.write_text(run.stdout)
    results.append({"check": name, "command": command, "exit_code": run.returncode, "log_sha256": sha(log)})
    save("checks.json", results)
    print(name, run.returncode, flush=True)
binding("binding-after.json")
raise SystemExit(int(any(row["exit_code"] for row in results)))
