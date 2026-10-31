"""Preserve rejected inputs and prepare a fresh, unreserved evaluator delivery."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
import uuid


def raw_review(name):
    return bool(re.search(r"^reports/(spec|impl|task)-review/.*/reviewer-[^/]*\.json$", name)
                or re.search(r"(^|/)reviewer-[ab]\.json$", name))


def fixture_review(name):
    return bool(re.match(r"^reports/(spec|impl|task)-review/workflow-state-integrity/", name))


def digest(file):
    assert file.is_file() and not file.is_symlink(), file
    return hashlib.sha256(file.read_bytes()).hexdigest()


if sys.argv[1:] == ["--self-test"]:
    for name in ("reports/impl-review/x/round-1/reviewer-a.json", "x/reviewer-b.json",
                 "reports/task-review/x/reviewer-extra.json"):
        assert raw_review(name), name
    for name in ("tests/reviewer-a.tests.py", "reports/implementation/x/T-002.md",
                 "reports/spec-review/x/summary.json", "plugins/reviewer-a.md"):
        assert not raw_review(name), name
    print("PASS: seven raw-review filtering cases")
    for stage in ("spec", "impl", "task"):
        assert fixture_review(f"reports/{stage}-review/workflow-state-integrity/attempt-1/round-1/precheck-result.json")
        assert not fixture_review(f"reports/{stage}-review/shared-review-launch-repair/attempt-1/round-1/precheck-result.json")
    assert not fixture_review("tests/workflow-state.tests.sh")
    print("PASS: seven fixture-review filtering cases")
    sys.exit(0)

assert sys.argv[1:] == ["--prepare"]
root = Path(__file__).resolve().parents[4]
base = root / "specs/shared-review-launch-repair/verification/T-002"
source = base / "evaluation-input-df659148-28de-442e-bc38-5059c13c9f52.json"
assert digest(source) == "253e87e970c61ac66e6d3d9d0a16c6a0ba66925b845d14a2969195a2b5dce467"
document = json.loads(source.read_bytes())
entries = document["allowed_input_manifest"]
assert len(entries) == len({e["path"] for e in entries}) == 265
for entry in entries:
    relative = Path(entry["path"])
    assert not relative.is_absolute() and ".." not in relative.parts
    assert digest(root / relative) == entry["sha256"], relative
removed = [e for e in entries if raw_review(e["path"])]
assert len(removed) == 28
fixture_removed = [e for e in entries if fixture_review(e["path"]) and not raw_review(e["path"])]
document["allowed_input_manifest"] = [e for e in entries
                                      if not raw_review(e["path"]) and not fixture_review(e["path"])]
scratch = Path(tempfile.mkdtemp(prefix="sdd-t002-filtered-evaluator-")).resolve(strict=True)
for entry in document["allowed_input_manifest"]:
    target = scratch / entry["path"]
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / entry["path"], target)
    assert digest(target) == entry["sha256"]
ledger = (root / document["identity_ledger_path"]).read_bytes()
tip = json.loads(ledger)["records"][-1]
identity = str(uuid.uuid4())
document.update(run_id=identity, host_session_id=identity, scratch_root=str(scratch),
                identity_ledger_sha256=hashlib.sha256(ledger).hexdigest(),
                sequence=tip["sequence"] + 1, previous_record_sha256=tip["record_sha256"])
target = base / f"evaluation-input-{identity}.json"
with target.open("x") as stream:
    json.dump(document, stream, indent=2)
    stream.write("\n")
print(json.dumps({"invocation": str(target), "sha256": digest(target),
                  "scratch": str(scratch), "inputs": len(document["allowed_input_manifest"]),
                  "excluded_raw_reports": len(removed), "reservation": "NOT PERFORMED",
                  "excluded_fixture_review_artifacts": len(fixture_removed),
                  "output": str(root / f"reports/quality-gate/launch-{identity}")}))
