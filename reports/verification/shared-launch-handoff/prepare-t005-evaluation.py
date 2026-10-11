"""Prepare caller-owned, hash-checked inputs without reserving an identity."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import tempfile
import uuid
import sys

root = Path(__file__).resolve().parents[3]
feature = "shared-review-launch-repair"
report = f"reports/implementation/{feature}/T-005.md"
implementation = f"handoffs/{feature}-T-005-attempt-6/manifest.json"

def digest(path):
    assert path.is_file() and not path.is_symlink(), path
    return hashlib.sha256(path.read_bytes()).hexdigest()

entries = {}
for name in ("requirements", "acceptance-tests", "design", "tasks", "traceability",
             "ux-spec", "frontend-spec", "infra-spec", "security-spec", "baseline-behavior"):
    path = f"specs/{feature}/{name}.md"
    if (root / path).exists():
        entries[path] = digest(root / path)
for path in (report, implementation, "plugins/sdd-quality-loop/references/quality-gate-calibration.md"):
    entries[path] = digest(root / path)
outputs = (root / report).read_text().split("## Outputs\n", 1)[1].split("\n## ", 1)[0]
pairs = re.findall(r"\| `([^`]+)` \| `([0-9a-f]{64})` \|", outputs)
assert len(pairs) == 32 and len(dict(pairs)) == 32
for path, expected in pairs:
    assert not Path(path).is_absolute() and ".." not in Path(path).parts
    entries[path] = expected
declaration = None
supplement = None
if len(sys.argv) == 3 and sys.argv[1] == '--supplemental':
    name = sys.argv[2]
    assert name.startswith(f'specs/{feature}/verification/T-005/') and '..' not in Path(name).parts
    supplement = {'path': name, 'sha256': digest(root / name)}
    entries[name] = supplement['sha256']
    for entry in json.loads((root / name).read_bytes())['artifacts']:
        path, expected = entry['path'], entry['sha256']
        assert not Path(path).is_absolute() and '..' not in Path(path).parts
        assert digest(root / path) == expected, path
        entries[path] = expected
elif len(sys.argv) == 2:
    declaration_path = sys.argv[1]
    assert declaration_path.startswith("reports/quality-gate/")
    assert ".." not in Path(declaration_path).parts
    declaration = {"path": declaration_path, "sha256": digest(root / declaration_path)}
    section = (root / declaration_path).read_text().split("## Post-Fix Artifacts\n", 1)[1].split("\n## ", 1)[0]
    additions = re.findall(r"\| `([^`]+)` \| `([0-9a-f]{64})` \|", section)
    assert additions and len(dict(additions)) == len(additions)
    for path, expected in additions:
        assert not Path(path).is_absolute() and ".." not in Path(path).parts
        assert path.startswith(("reports/verification/", "plugins/", "tests/", "contracts/", f"specs/{feature}/verification/T-005/")) and digest(root / path) == expected
        entries[path] = expected
else:
    assert len(sys.argv) == 1
for path, expected in entries.items():
    assert digest(root / path) == expected, path
scratch = Path(tempfile.mkdtemp(prefix="sdd-t005-evaluator-")).resolve(strict=True)
assert str(scratch) == str(scratch.resolve(strict=True))
for path, expected in entries.items():
    target = scratch / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / path, target)
    assert digest(target) == expected, path
ledger_path = "reports/review-context/identity-ledger.json"
ledger_bytes = (root / ledger_path).read_bytes()
tip = json.loads(ledger_bytes)["records"][-1]
identity = str(uuid.uuid4())
invocation = {
    "schema": "review-context-invocation/v2", "input_mode": "file-manifest",
    "fallback_mode": "none", "read_only": True, "feature": feature,
    "stage": "quality", "role": "sdd-evaluator", "task_id": "T-005",
    "run_id": identity, "host_session_id": identity,
    "identity_ledger_path": ledger_path,
    "identity_ledger_sha256": hashlib.sha256(ledger_bytes).hexdigest(),
    "sequence": tip["sequence"] + 1, "previous_record_sha256": tip["record_sha256"],
    "implementation_manifest": {"path": implementation, "sha256": entries[implementation]},
    "scratch_root": str(scratch),
    "allowed_input_manifest": [{"path": p, "sha256": h} for p, h in entries.items()],
}
target = root / f"reports/review-context/shared-launch-T005-quality-{identity}.json"
if declaration:
    invocation["gate_report_declaration"] = declaration
if supplement:
    invocation['supplemental_delivery_declaration'] = supplement
    spec = importlib.util.spec_from_file_location('delivery', root / 'plugins/sdd-quality-loop/scripts/supplemental-delivery-inputs.py')
    delivery = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(delivery)
    with tempfile.TemporaryDirectory(prefix='sdd-t005-input-check-') as temporary:
        check = Path(temporary) / 'invocation.json'
        check.write_text(json.dumps(invocation))
        delivery.resolve(root, check)
with target.open("x") as stream:
    json.dump(invocation, stream, indent=2)
    stream.write("\n")
print(json.dumps({"invocation": str(target), "sha256": digest(target),
                  "scratch": str(scratch), "inputs": len(entries),
                  "output": str(root / f"reports/quality-gate/launch-{identity}")}))
