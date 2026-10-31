"""Bounded T-002 adaptation of the existing T-005 input preparation helper.

Prepares unreserved identity inputs only. Does not launch or reserve a reviewer.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[4]
base = "specs/shared-review-launch-repair/verification/T-002"
source = root / "reports/verification/shared-launch-handoff/prepare-t005-evaluation.py"


def pin(path):
    file = root / path
    assert file.is_file() and not file.is_symlink(), path
    return {"path": path, "sha256": hashlib.sha256(file.read_bytes()).hexdigest()}


if sys.argv[1:] == ["--prepare-declaration"]:
    paths = [
        f"{base}/prepare-t002-evaluation.py",
        "specs/shared-review-launch-repair/verification/T-002.contract.json",
        f"{base}/historical-red-recovery-20261010.md",
        f"{base}/independent-verification-20261010.md",
        f"{base}/independent-diff-review-20261010.md",
    ]
    # Top-level regular evidence only: never descend into caches or fixtures.
    for directory in ("deterministic-bundle-20261010", "native-revalidation-attempt-3-20261010"):
        for file in sorted((root / base / directory).iterdir()):
            if file.is_file() and not file.is_symlink():
                paths.append(file.relative_to(root).as_posix())
    declaration = {
        "schema": "supplemental-delivery-declaration/v1",
        "feature": "shared-review-launch-repair", "task_id": "T-002",
        "implementation_report": pin("reports/implementation/shared-review-launch-repair/T-002.md"),
        "artifacts": [pin(path) for path in paths],
    }
    target = root / base / "supplemental-delivery-corrected-20261010.json"
    with target.open("x") as stream:
        json.dump(declaration, stream, indent=2)
        stream.write("\n")
    print(json.dumps(pin(target.relative_to(root).as_posix())))
    sys.exit(0)

assert len(sys.argv) == 3 and sys.argv[1] == "--supplemental"
scope = {
    "task": "T-002", "owner": str(root), "risk": "high",
    "scope": "Caller-owned evaluation input preparation only; no reservation, launch, ledger or lifecycle change",
    "contracts": ["review-context-invocation/v2", "supplemental-delivery-declaration/v1"],
    "required_validation": "242 output hashes; supplemental resolver; canonical evaluator delivery preflight without reserve",
    "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "dirty": subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=root, text=True),
    "reused_helper": pin(source.relative_to(root).as_posix()),
}
# Exclusive creation preserves every prior preparation attempt.
scope_path = root / base / "evaluation-preparation-scope-20261010.json"
with scope_path.open("x") as stream:
    json.dump(scope, stream, indent=2)
    stream.write("\n")
text = source.read_text()
replacements = {
    'root = Path(__file__).resolve().parents[3]': 'root = Path(__file__).resolve().parents[4]',
    'implementation = f"handoffs/{feature}-T-005-attempt-6/manifest.json"': 'implementation = f"specs/{feature}/verification/T-002/admission-attempt-3-20261010/manifest.json"',
    'len(pairs) == 32 and len(dict(pairs)) == 32': 'len(pairs) == 242 and len(dict(pairs)) == 242',
    'target = root / f"reports/review-context/shared-launch-T005-quality-{identity}.json"': 'target = root / f"specs/{feature}/verification/T-002/evaluation-input-{identity}.json"',
}
for before, after in replacements.items():
    assert text.count(before) == 1, before
    text = text.replace(before, after)
text = text.replace("T-005", "T-002").replace("t005", "t002")
exec(compile(text, str(source), "exec"), {"__file__": __file__, "__name__": "__main__"})
