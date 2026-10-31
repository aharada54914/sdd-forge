#!/usr/bin/env python3
"""Capture T-004 gate commands without changing production, ledger or task state."""
import datetime, hashlib, json, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[5]
OUT = pathlib.Path(__file__).resolve().parent
RUN = "c3d9b63a-ad5e-4e90-bc50-5d0d387c7a4f"
def record(name, command):
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    p = subprocess.run(["rtk", "proxy", *command], cwd=ROOT, capture_output=True, text=True)
    (OUT / (name + ".log")).write_text(p.stdout + p.stderr)
    result = dict(command=["rtk", "proxy", *command], exit_code=p.returncode, started_at=started,
                  finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (OUT / (name + ".json")).write_text(json.dumps(result, indent=2) + "\n")
    print(name, p.returncode, flush=True)
    return p.returncode
modules = ["plugins/sdd-review-loop/scripts/" + n + ".py" for n in
           ["validate-nontty-spec-launch", "probe-nontty-review", "preflight-host-review", "launch-impl-review"]]
modules += ["plugins/sdd-quality-loop/scripts/" + n + ".py" for n in
            ["preflight-evaluator-delivery", "review-conditional-inputs"]]
commands = {
 "binding": ["python3", "-B", str(OUT / "verify-binding.py")],
 "risk": ["bash", "plugins/sdd-quality-loop/scripts/check-risk.sh", "specs/shared-review-launch-repair/tasks.md"],
 "placeholder": ["bash", "plugins/sdd-quality-loop/scripts/check-placeholders.sh", ".github/workflows/test.yml"],
 "workflow-state": ["bash", "plugins/sdd-quality-loop/scripts/check-workflow-state.sh"],
 "task-state": ["bash", "plugins/sdd-quality-loop/scripts/check-task-state.sh", "specs/shared-review-launch-repair/tasks.md", "reports/quality-gate", "reports/implementation", "."],
 "component": ["python3", "-B", "plugins/sdd-quality-loop/scripts/check-component-coverage.py", "--repo-root", "."],
 "ruff": ["/tmp/shared-launch-static-20261008/bin/ruff", "check", "--config", "tests/shared-launch-python/pyproject.toml", *modules],
 "mypy": ["/tmp/shared-launch-static-20261008/bin/mypy", "--config-file", "tests/shared-launch-python/pyproject.toml", *modules],
 "build": ["python3", "-B", "tests/shared-launch-build.tests.py", "-v"],
 "traceability": ["bash", "plugins/sdd-quality-loop/scripts/check-traceability.sh", str(OUT / "traceability.json"), ".", "require-evidence"],
 "pr": ["gh", "pr", "view", "558", "--repo", "aharada54914/sdd-forge", "--json", "state,mergedAt,mergeCommit,headRefOid,url"],
 "head-ci": ["gh", "run", "view", "38150318997", "--repo", "aharada54914/sdd-forge", "--json", "headSha,status,conclusion,jobs,url"],
 "post-merge-ci": ["gh", "run", "view", "38185550821", "--repo", "aharada54914/sdd-forge", "--json", "headSha,status,conclusion,jobs,url"],
 "merge-authority": ["gh", "api", "repos/aharada54914/sdd-forge/issues/comments/6115254249", "--jq", ".body"],
 "contract": ["bash", "plugins/sdd-quality-loop/scripts/check-contract.sh", "specs/shared-review-launch-repair/verification/T-004.contract.json", "."],
 "bundle": ["bash", "plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh", "specs/shared-review-launch-repair/verification/T-004.contract.json", "reports/quality-gate/20261015-shared-review-launch-repair-T-004.md", ".", "specs/shared-review-launch-repair/verification/T-004.evidence.json"],
 "bundle-check": ["bash", "plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh", "specs/shared-review-launch-repair/verification/T-004.evidence.json", "."]
}
for name in sys.argv[1:]:
    if record(name, commands[name]): raise SystemExit(1)

