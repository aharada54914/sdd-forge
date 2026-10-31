#!/usr/bin/env python3
"""Read-only owner verification; results and tool caches stay in this bundle."""
import hashlib
import difflib
import json
import os
import pathlib
import re
import stat
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[5]
OUT = pathlib.Path(__file__).resolve().parent
BASE = ROOT / "specs/shared-review-launch-repair/verification/T-002"
ADMISSION = ROOT / "handoffs/shared-review-launch-repair-T-002-attempt-4"
NATIVE = BASE / "native-revalidation-attempt-4"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + "\n")

scope = {"task":"T-002", "issue":423, "owner":str(ROOT), "risk":"high",
         "scope":"Deterministic evidence and contract preparation only; no product, report, lifecycle or ledger writes",
         "contracts":["verification-contract/v2", "implementation-report/v2"],
         "required_validation":"243 output hashes, canonical report, native evidence, deterministic checks, fail-closed verification contract"}
for key, command in [("head",["git","rev-parse","HEAD"]),("dirty",["git","status","--short"])]:
    scope[key] = subprocess.check_output(["rtk","proxy",*command], cwd=ROOT, text=True)
save("scope-before.json",scope)

report = ROOT / "reports/implementation/shared-review-launch-repair/T-002.md"
delivery = json.loads((ADMISSION / "output/delivery-index.json").read_text())
native_report = ADMISSION / "output" / delivery["report"]["path"]
assert digest(native_report) == delivery["report"]["sha256"]
(OUT / "report-adoption.diff").write_text("".join(difflib.unified_diff(native_report.read_text().splitlines(True),report.read_text().splitlines(True),fromfile="native-report",tofile="canonical-report")))
body = report.read_text().split("## Outputs\n",1)[1].split("\n## ",1)[0]
rows = re.findall(r"^\| `([^`]+)` \| `([0-9a-f]{64})` \|$",body,re.M)
assert len(rows) == 243, len(rows)
comparisons = []
for name, expected in rows:
    path = ROOT / name
    current = digest(path) if path.is_file() else None
    comparisons.append({"path":name,"expected_sha256":expected,"current_sha256":current,"matches":current == expected})
mode_rows = json.loads((NATIVE / "source-integrity.json").read_text())["files"]
mode_checks = []
for row in mode_rows:
    if row.get("expected_mode") is None:
        continue
    path = ROOT / row["path"]
    mode = stat.S_IMODE(path.stat().st_mode)
    mode_checks.append({"path":row["path"],"expected":row["expected_mode"],"current":mode,"matches":mode == row["expected_mode"]})
summary = json.loads((NATIVE / "execution-summary.json").read_text())
result = {"canonical_report_sha256":digest(report), "output_count":len(rows),"output_mismatches":[x for x in comparisons if not x["matches"]],"mode_count":len(mode_checks),"mode_mismatches":[x for x in mode_checks if not x["matches"]],"rows":comparisons,"modes":mode_checks,"native_run_id":summary["run_id"],"current_behavioral_suite_exit_codes":summary["behavioral_results"],"retained_initial_failure":{"traceability-freeze": summary["behavioral_results"]["traceability-freeze"]},"formal_acceptance":False}
save("fresh-binding.json",result)
print("binding",len(rows),"mismatches",len(result["output_mismatches"]),"mode mismatches",len(result["mode_mismatches"]),flush=True)

trace = {"feature":"shared-review-launch-repair","task":"T-002","scope":"Current evidence existence only, not formal acceptance or RED adequacy", "links":[
    {"req":"REQ-004","acs":["AC-004"],"tests":["TEST-007","TEST-008a","TEST-008b","TEST-008c","TEST-008d"],"evidence":[str((NATIVE / "traceability-freeze-retry-1.stdout.log").relative_to(ROOT)),str((NATIVE / "traceability-freeze-retry-1.stderr.log").relative_to(ROOT))]},
    {"req":"REQ-005","acs":["AC-005"],"tests":["TEST-009","TEST-010a","TEST-010b"],"evidence":[str((NATIVE / "hash-parity.stdout.log").relative_to(ROOT)),str((NATIVE / "unreadable-equivalence.stdout.log").relative_to(ROOT)),str((NATIVE / "downstream-parity.stdout.log").relative_to(ROOT))]}]}
save("traceability.json",trace)
modules = ["plugins/sdd-review-loop/scripts/" + n + ".py" for n in ["validate-nontty-spec-launch","probe-nontty-review","preflight-host-review","launch-impl-review"]]
modules += ["plugins/sdd-quality-loop/scripts/" + n + ".py" for n in ["preflight-evaluator-delivery","review-conditional-inputs"]]
commands = {
    "ruff":["/tmp/shared-launch-static-20261008/bin/ruff","check","--config","tests/shared-launch-python/pyproject.toml",*modules],
    "mypy":["/tmp/shared-launch-static-20261008/bin/mypy","--config-file","tests/shared-launch-python/pyproject.toml",*modules],
    "build":["python3","-B","tests/shared-launch-build.tests.py","-v"],
    "placeholder":["bash","plugins/sdd-quality-loop/scripts/check-placeholders.sh",*modules,"plugins/sdd-review-loop/scripts/review-hash-normalization.ps1","plugins/sdd-review-loop/scripts/impl-review-precheck.ps1","plugins/sdd-review-loop/scripts/task-review-precheck.ps1","plugins/sdd-quality-loop/scripts/validate-review-context-set.sh","plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"],
    "risk":["bash","plugins/sdd-quality-loop/scripts/check-risk.sh","specs/shared-review-launch-repair/tasks.md"],
    "task-state":["bash","plugins/sdd-quality-loop/scripts/check-task-state.sh","specs/shared-review-launch-repair/tasks.md","reports/quality-gate","reports/implementation","."],
    "component":["python3","-B","plugins/sdd-quality-loop/scripts/check-component-coverage.py","--repo-root","."],
    "traceability":["bash","plugins/sdd-quality-loop/scripts/check-traceability.sh",str(OUT / "traceability.json"),".","require-evidence"],
    "report":["bash","plugins/sdd-implementation/scripts/validate-implementation-report.sh",str(report)]}
(OUT / "tmp").mkdir(exist_ok=True)
env = dict(os.environ,TMPDIR=str(OUT / "tmp"),MYPY_CACHE_DIR=str(OUT / "mypy-cache"),RUFF_CACHE_DIR=str(OUT / "ruff-cache"),PYTHONDONTWRITEBYTECODE="1")
results=[]
for name,command in commands.items():
    run = subprocess.run(["rtk","proxy",*command],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    (OUT / (name + ".log")).write_text(run.stdout)
    results.append({"check":name,"command":["rtk","proxy",*command],"cwd":str(ROOT),"exit_code":run.returncode,"log_sha256":digest(OUT / (name+".log"))})
    save("checks.json",results)
    print(name,run.returncode,flush=True)
save("fresh-binding-after.json",{"rows":[{"path":name,"sha256":digest(ROOT/name),"matches":digest(ROOT/name)==expected} for name,expected in rows],"report_sha256":digest(report)})
