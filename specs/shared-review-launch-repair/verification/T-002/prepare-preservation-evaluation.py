"""Bind unchanged AC-004 implementation to a fixed Git baseline; do not reserve."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

root = Path(__file__).resolve().parents[4]
base = Path(__file__).resolve().parent


def digest(file):
    assert file.is_file() and not file.is_symlink(), file
    return hashlib.sha256(file.read_bytes()).hexdigest()


def entry(file):
    return {"path": file.relative_to(root).as_posix(), "sha256": digest(file)}


source = base / "evaluation-input-f9e74c8f-6720-4304-b098-1c3c6b1184c6.json"
assert digest(source) == "61a0807e3797bedfcd81ee2b0950849ccb3e82f3035306a84e58267c50ccf881"
document = json.loads(source.read_bytes())
entries = {item["path"]: item for item in document["allowed_input_manifest"]}
assert len(entries) == len(document["allowed_input_manifest"]) == 179
for item in entries.values():
    assert digest(root / item["path"]) == item["sha256"], item["path"]
pointer = document["supplemental_delivery_declaration"]
declaration = json.loads((root / pointer["path"]).read_bytes())
artifacts = {item["path"]: item for item in declaration["artifacts"]}
identity = str(uuid.uuid4())
evidence = base / f"preservation-{identity}"
evidence.mkdir()
commit = "9ce19abe90df0cb83e385f96855e4843318a8807"
records = []
added = [Path(__file__), base / "preservation-response-20261010.md"]
for suffix, expected in (
    ("sh", "001f6962590b7d9dc9a831d8d90d7171174cca6d890e94b376881ab0193bd85f"),
    ("ps1", "13351170ba1284d2fa1eb0d096d6e5faf506e3ce0a3a22a3cb81d09b10a028db"),
):
    path = f"plugins/sdd-quality-loop/scripts/check-workflow-state.{suffix}"
    prior = subprocess.run(["rtk", "proxy", "git", "show", f"{commit}:{path}"],
                           cwd=root, check=True, capture_output=True).stdout
    assert hashlib.sha256(prior).hexdigest() == expected
    assert (root / path).read_bytes() == prior, path
    copy = evidence / f"baseline-check-workflow-state.{suffix}"
    with copy.open("xb") as stream:
        stream.write(prior)
    assert digest(copy) == digest(root / path) == expected
    records.append({"path": path, "baseline_commit": commit,
                    "baseline_sha256": expected, "current_sha256": digest(root / path),
                    "byte_identical": True, "baseline_copy": entry(copy)})
    added.append(copy)
result = evidence / "results.json"
with result.open("x") as stream:
    json.dump({"claim": "AC-004 preservation, not retrospective RED or a review verdict",
               "records": records}, stream, indent=2)
    stream.write("\n")
added.append(result)
for file in added:
    item = entry(file)
    assert item["path"] not in artifacts
    artifacts[item["path"]] = item
    entries[item["path"]] = item
declaration["artifacts"] = list(artifacts.values())
target = base / f"supplemental-preservation-{identity}.json"
with target.open("x") as stream:
    json.dump(declaration, stream, indent=2)
    stream.write("\n")
document["supplemental_delivery_declaration"] = entry(target)
assert pointer["path"] not in artifacts
del entries[pointer["path"]]
entries[entry(target)["path"]] = entry(target)
scratch = Path(tempfile.mkdtemp(prefix="sdd-t002-preservation-evaluator-")).resolve()
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
                  "reservation": "NOT PERFORMED", "baseline_comparisons": len(records)}))
