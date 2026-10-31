"""Prepare fresh evaluator inputs without changing frozen evidence or reserving."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

root = Path(__file__).resolve().parents[4]
base = Path(__file__).resolve().parent


def digest(path):
    assert path.is_file() and not path.is_symlink(), path
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entry(path):
    return {"path": path.relative_to(root).as_posix(), "sha256": digest(path)}


def save(path, value):
    with path.open("x") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


source = base / "evaluation-input-d91b0393-7e35-4f0b-8916-7ea488f272b4.json"
assert digest(source) == "574ef8c9494e25cf9ab776dcf946ae04470977a51a60ff81dd975499b603ab5f"
document = json.loads(source.read_bytes())
entries = {item["path"]: item for item in document["allowed_input_manifest"]}
assert len(entries) == len(document["allowed_input_manifest"]) == 184
test = "tests/review-hash-normalization.tests.ps1"
changes = []
for item in entries.values():
    actual = digest(root / item["path"])
    if actual != item["sha256"]:
        assert item["path"] == test, item["path"]
        changes.append({"path": test, "before": item["sha256"], "after": actual})
assert len(changes) == 1
identity = str(uuid.uuid4())
evidence = base / f"equivalence-followup-{identity}"
evidence.mkdir()
run = subprocess.run(["rtk", "proxy", "pwsh", "-NoLogo", "-NoProfile", "-File", test],
                     cwd=root, capture_output=True, text=True, timeout=120)
log = evidence / "powershell.log"
with log.open("x") as stream:
    stream.write(run.stdout + run.stderr)
save(evidence / "test-result.json", {"command": run.args, "exit_code": run.returncode,
     "changes": changes, "claim": "local regression, not native Windows or formal verdict"})
assert run.returncode == 0, run.stderr
paths = ["AGENTS.md", "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh",
         "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1", test]
diff = subprocess.run(["rtk", "proxy", "git", "diff", "HEAD", "--", *paths],
                      cwd=root, check=True, capture_output=True).stdout
diff_path = evidence / "scoped-current.diff"
with diff_path.open("xb") as stream:
    stream.write(diff)
binding = base.parent / "T-005/current-full-binding-20261010"
summary = json.loads((binding / "binding-summary.json").read_bytes())
comparison = json.loads((binding / "comparison-after.json").read_bytes())
for path in paths[:3]:
    rows = [row for row in comparison["rows"] if row["path"] == path]
    assert len(rows) == 1 and rows[0]["current_sha256"] == digest(root / path), path
added = [Path(__file__), root / test, base / "permanent-equivalence-followup-20261010.md",
         log, evidence / "test-result.json", diff_path, binding / "binding-summary.json"]
for name in ["README.md", "comparison-after.json", "diff-attribution.json", "results.json",
             "review-context-boundary.json", "review-context-boundary.log"]:
    assert digest(binding / name) == summary["evidence_sha256"][name], name
    added.append(binding / name)
pointer = document["supplemental_delivery_declaration"]
declaration = json.loads((root / pointer["path"]).read_bytes())
artifacts = {item["path"]: item for item in declaration["artifacts"]}
for path in added:
    item = entry(path)
    assert item["path"] not in artifacts
    artifacts[item["path"]] = item
    entries[item["path"]] = item
declaration["artifacts"] = list(artifacts.values())
target = base / f"supplemental-equivalence-{identity}.json"
save(target, declaration)
del entries[pointer["path"]]
entries[entry(target)["path"]] = entry(target)
document["supplemental_delivery_declaration"] = entry(target)
scratch = Path(tempfile.mkdtemp(prefix="sdd-t002-equivalence-evaluator-")).resolve()
for item in entries.values():
    relative = Path(item["path"])
    assert not relative.is_absolute() and ".." not in relative.parts
    assert digest(root / relative) == item["sha256"]
    destination = scratch / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / relative, destination)
    assert digest(destination) == item["sha256"]
ledger = (root / document["identity_ledger_path"]).read_bytes()
tip = json.loads(ledger)["records"][-1]
document.update(run_id=identity, host_session_id=identity, scratch_root=str(scratch),
                allowed_input_manifest=list(entries.values()),
                identity_ledger_sha256=hashlib.sha256(ledger).hexdigest(),
                sequence=tip["sequence"] + 1, previous_record_sha256=tip["record_sha256"])
invocation = base / f"evaluation-input-{identity}.json"
save(invocation, document)
print(json.dumps({"invocation": str(invocation), "sha256": digest(invocation),
                  "scratch_root": str(scratch),
                  "output": str(root / f"reports/quality-gate/launch-{identity}"),
                  "reservation": "NOT PERFORMED"}))
