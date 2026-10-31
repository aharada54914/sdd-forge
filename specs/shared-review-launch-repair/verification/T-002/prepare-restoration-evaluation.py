"""Prepare fresh delivery of existing evidence plus the restoration response."""
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import uuid

root = Path(__file__).resolve().parents[4]
base = Path(__file__).resolve().parent


def digest(file):
    assert file.is_file() and not file.is_symlink(), file
    return hashlib.sha256(file.read_bytes()).hexdigest()


def entry(file):
    return {"path": file.relative_to(root).as_posix(), "sha256": digest(file)}


source = base / "evaluation-input-66ee6525-d916-48d7-93a0-d0d893a92aca.json"
assert digest(source) == "c2434d6d362c09a025f60fcd8083504088c5be6730324575146efd32b927c92a"
document = json.loads(source.read_bytes())
entries = {item["path"]: item for item in document["allowed_input_manifest"]}
assert len(entries) == len(document["allowed_input_manifest"]) == 162
for item in entries.values():
    assert digest(root / item["path"]) == item["sha256"], item["path"]
pointer = document["supplemental_delivery_declaration"]
declaration = json.loads((root / pointer["path"]).read_bytes())
artifacts = {item["path"]: item for item in declaration["artifacts"]}
added = [Path(__file__), base / "evaluation-response-20261010.md",
         base / "restoration-retry-scope-20261010.md", base / "verify-disposable.py"]
results = base / "current-restoration-fjg8_bgi/results.json"
checks = json.loads(results.read_bytes())
assert len(checks) == 6 and all(item["exit_code"] == 0 for item in checks)
added.extend(sorted(file for file in results.parent.iterdir() if file.is_file()))
for file in added:
    item = entry(file)
    assert item["path"] not in artifacts or artifacts[item["path"]] == item
    artifacts[item["path"]] = item
    entries[item["path"]] = item
identity = str(uuid.uuid4())
declaration["artifacts"] = list(artifacts.values())
target = base / f"supplemental-restoration-{identity}.json"
with target.open("x") as stream:
    json.dump(declaration, stream, indent=2)
    stream.write("\n")
document["supplemental_delivery_declaration"] = entry(target)
assert pointer["path"] not in artifacts
del entries[pointer["path"]]
entries[target.relative_to(root).as_posix()] = entry(target)
scratch = Path(tempfile.mkdtemp(prefix="sdd-t002-restoration-evaluator-")).resolve()
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
with invocation.open("x") as stream:
    json.dump(document, stream, indent=2)
    stream.write("\n")
print(json.dumps({"invocation": str(invocation), "sha256": digest(invocation),
                  "output": str(root / f"reports/quality-gate/launch-{identity}"),
                  "reservation": "NOT PERFORMED"}))
