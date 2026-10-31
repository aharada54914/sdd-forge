#!/usr/bin/env python3
"""Collect local deterministic evidence without changing task or ledger state."""
import hashlib, json, pathlib, stat, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[5]
OUT = pathlib.Path(__file__).resolve().parent
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name, value): (OUT / name).write_text(json.dumps(value, indent=2) + "\n")
base = ROOT / "specs/shared-review-launch-repair/verification/T-005"
full = base / "current-full-binding-20261010"
rows = json.loads((full / "comparison-after.json").read_text())["rows"]
assert len(rows) == 620
for row in rows:
    p = ROOT / row["path"]
    assert digest(p) == row["current_sha256"], row["path"]
    assert oct(stat.S_IMODE(p.stat().st_mode)) == row["current_mode"], row["path"]
count = 0
for folder in [full, base / "parent-binding-20261010"]:
    summary = json.loads((folder / "binding-summary.json").read_text())
    for name, expected in summary["evidence_sha256"].items():
        assert digest(folder / name) == expected, str(folder / name)
        count += 1
save("fresh-binding.json", {"owner":str(ROOT),"current_paths_and_modes":620,"evidence_hashes":count,"verified":True})
modules = ["plugins/sdd-review-loop/scripts/" + n + ".py" for n in ["validate-nontty-spec-launch","probe-nontty-review","preflight-host-review","launch-impl-review"]]
modules += ["plugins/sdd-quality-loop/scripts/" + n + ".py" for n in ["preflight-evaluator-delivery","review-conditional-inputs"]]
commands = {
"ruff": ["/tmp/shared-launch-static-20261008/bin/ruff","check","--config","tests/shared-launch-python/pyproject.toml",*modules],
"mypy": ["/tmp/shared-launch-static-20261008/bin/mypy","--config-file","tests/shared-launch-python/pyproject.toml",*modules],
"build": ["python3","-B","tests/shared-launch-build.tests.py","-v"],
"placeholder":["bash","plugins/sdd-quality-loop/scripts/check-placeholders.sh",*modules],
"risk":["bash","plugins/sdd-quality-loop/scripts/check-risk.sh","specs/shared-review-launch-repair/tasks.md"],
"task-state":["bash","plugins/sdd-quality-loop/scripts/check-task-state.sh","specs/shared-review-launch-repair/tasks.md","reports/quality-gate","reports/implementation","."],
"component":["python3","-B","plugins/sdd-quality-loop/scripts/check-component-coverage.py","--repo-root","."],
"traceability":["bash","plugins/sdd-quality-loop/scripts/check-traceability.sh",str(OUT / "traceability.json"),".","require-evidence"]}
results = []
for name, command in commands.items():
    result = subprocess.run(["rtk","proxy",*command], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (OUT / (name + ".log")).write_text(result.stdout)
    results.append({"check":name,"command":command,"exit_code":result.returncode})
    print(name, result.returncode, flush=True)
    save("checks.json", results)
    if result.returncode: raise SystemExit(result.returncode)

