"""Bind current coverage without rewriting prior evaluations or reserving."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

base = Path(__file__).resolve().parent
root = base.parents[3]


def digest(path):
    assert path.is_file() and not path.is_symlink(), path
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entry(path):
    return {"path": path.relative_to(root).as_posix(), "sha256": digest(path)}


def save(path, value):
    with path.open("x") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


source = base / "evaluation-input-48f0bfc1-d566-49a1-9e00-bc36c36812ed.json"
assert digest(source) == "fbb1ffcbfd9f973a6ed8891662f7ed77a1e6b0e8e2b97cd4ff7fca12e7e94566"
document = json.loads(source.read_bytes())
entries = {item["path"]: item for item in document["allowed_input_manifest"]}
assert len(entries) == len(document["allowed_input_manifest"]) == 196
contract = "specs/shared-review-launch-repair/verification/T-002.contract.json"
changed = []
for relative, item in entries.items():
    if digest(root / relative) != item["sha256"]:
        assert relative == contract, relative
        assert digest(base / "contract-before-48f-remedy.json") == item["sha256"]
        changed.append(relative)
        entries[relative] = entry(root / relative)
assert changed == [contract], changed
identity = str(uuid.uuid4())
evidence = base / f"coverage-followup-{identity}"
evidence.mkdir()
test = "tests/review-hash-normalization.tests.ps1"
run = subprocess.run(["rtk", "proxy", "git", "diff", "--no-index", "--", "/dev/null", test],
                     cwd=root, capture_output=True)
assert run.returncode == 1 and b"new file mode" in run.stdout, run.stderr
diff = evidence / "permanent-test-added.diff"
with diff.open("xb") as stream:
    stream.write(run.stdout)
added = [Path(__file__), diff, base / "current-evidence-coverage.md",
         base / "permanent-equivalence-independent-review.md",
         base / "contract-before-48f-remedy.json"]
restoration = base / "current-restoration-380hac14"
results = json.loads((restoration / "results.json").read_bytes())
assert len(results) == 6 and all(row["exit_code"] == 0 for row in results)
added.extend(path for path in sorted(restoration.iterdir()) if path.is_file())
pointer = document["supplemental_delivery_declaration"]
declaration = json.loads((root / pointer["path"]).read_bytes())
artifacts = {item["path"]: item for item in declaration["artifacts"]}
assert len(artifacts) == len(declaration["artifacts"])
if contract in artifacts:
    artifacts[contract] = entry(root / contract)
for path in added:
    item = entry(path)
    assert item["path"] not in artifacts, item["path"]
    artifacts[item["path"]] = item
    entries[item["path"]] = item
declaration["artifacts"] = list(artifacts.values())
target = base / f"supplemental-coverage-{identity}.json"
save(target, declaration)
del entries[pointer["path"]]
entries[entry(target)["path"]] = entry(target)
document["supplemental_delivery_declaration"] = entry(target)
scratch = Path(tempfile.mkdtemp(prefix="sdd-t002-coverage-evaluator-")).resolve()
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
                  "output": str(root / f"reports/quality-gate/launch-{identity}"),
                  "reservation": "NOT PERFORMED"}))
