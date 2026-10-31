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


def task_transition(before, after):
    marker = b"## T-002 Freeze and PowerShell normalization\n"
    assert before.count(marker) == 1, "ambiguous T-002"
    prefix, task = before.split(marker, 1)
    section, separator, suffix = task.partition(b"\n## ")
    old = b"\nStatus: Planned\n"
    assert section.count(old) == 1, "unexpected historical status"
    expected = prefix + marker + section.replace(old, b"\nStatus: Implementation Complete\n", 1) + separator + suffix
    assert after == expected, "change outside approved T-002 status transition"


if sys.argv[1:] == ["--self-test"]:
    before = b"unchanged\n## T-002 Freeze and PowerShell normalization\n\nStatus: Planned\nbody\n## T-003\nStatus: Planned\n"
    after = before.replace(b"Status: Planned", b"Status: Implementation Complete", 1)
    task_transition(before, after)
    for bad in (after.replace(b"body", b"edited"), after.replace(b"unchanged", b"changed"),
                after.replace(b"Status: Planned", b"Status: Done"), before,
                after.replace(b"Implementation Complete", b"Done")):
        try:
            task_transition(before, bad)
        except AssertionError:
            continue
        raise AssertionError("invalid transition admitted")
    print("PASS: exact T-002 transition; five invalid changes rejected")
    sys.exit(0)


if sys.argv[1:] == ["--prepare-declaration"]:
    paths = [
        f"{base}/prepare-t002-evaluation-attempt-4-retry-2.py",
        "specs/shared-review-launch-repair/verification/T-002.contract.json",
        f"{base}/historical-red-recovery-20261010.md",
        f"{base}/independent-verification-20261010.md",
        f"{base}/independent-diff-review-20261010.md",
    ]
    # Top-level regular evidence only: never descend into caches or fixtures.
    for directory in ("deterministic-bundle-attempt-4", "native-revalidation-attempt-4"):
        for file in sorted((root / base / directory).iterdir()):
            if file.is_file() and not file.is_symlink():
                paths.append(file.relative_to(root).as_posix())
    declaration = {
        "schema": "supplemental-delivery-declaration/v1",
        "feature": "shared-review-launch-repair", "task_id": "T-002",
        "implementation_report": pin("reports/implementation/shared-review-launch-repair/T-002.md"),
        "artifacts": [pin(path) for path in paths],
    }
    target = root / base / "supplemental-delivery-attempt-4-retry-2.json"
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
    "required_validation": "243 output hashes; supplemental resolver; canonical evaluator delivery preflight without reserve",
    "head": subprocess.check_output(["rtk", "proxy", "git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "dirty": subprocess.check_output(["rtk", "proxy", "git", "status", "--porcelain", "--untracked-files=no"], cwd=root, text=True),
    "reused_helper": pin(source.relative_to(root).as_posix()),
}
# Exclusive creation preserves every prior preparation attempt.
scope_path = root / base / "evaluation-preparation-scope-attempt-4-retry-2.json"
with scope_path.open("x") as stream:
    json.dump(scope, stream, indent=2)
    stream.write("\n")
text = source.read_text()
replacements = {
    'root = Path(__file__).resolve().parents[3]': 'root = Path(__file__).resolve().parents[4]',
    'implementation = f"handoffs/{feature}-T-005-attempt-6/manifest.json"': 'implementation = f"handoffs/{feature}-T-002-attempt-4/manifest.json"',
    'len(pairs) == 32 and len(dict(pairs)) == 32': 'len(pairs) == 243 and len(dict(pairs)) == 243',
    'target = root / f"reports/review-context/shared-launch-T005-quality-{identity}.json"': 'target = root / f"specs/{feature}/verification/T-002/evaluation-input-{identity}.json"',
}
for before, after in replacements.items():
    assert text.count(before) == 1, before
    text = text.replace(before, after)
before = "    entries[path] = expected\ndeclaration = None"
after = """    if path == f"specs/{feature}/tasks.md":
        historical = root / "handoffs/shared-review-launch-repair-T-002-attempt-4/output/work" / path
        assert digest(historical) == expected, "historical task hash mismatch"
        task_transition(historical.read_bytes(), (root / path).read_bytes())
        entries[path] = digest(root / path)
    else:
        entries[path] = expected
declaration = None"""
assert text.count(before) == 1
text = text.replace(before, after)
text = text.replace("T-005", "T-002").replace("t005", "t002")
exec(compile(text, str(source), "exec"), {"__file__": __file__, "__name__": "__main__", "task_transition": task_transition})


