"""Disposable task-owned rollback; never restore shared working-tree state."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[4]
evidence = root / "specs/cloud-orchestration/verification/T-003"
scratch = Path("/tmp/cloud-T-003-01a14d65")
checkout = scratch / "rollback-checkout"
base = json.loads((evidence / "before.json").read_bytes())["base_revision"]
owned = [
    "plugins/sdd-quality-loop/scripts/cloud_authorization.py",
    "tests/cloud-orchestration-execution.tests.py",
]
owned += [str(p.relative_to(root)) for p in (root / "templates/cloud").rglob("*") if p.is_file()]


def command(argv, cwd, log):
    result = subprocess.run(argv, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    (evidence / log).write_bytes(
        ("COMMAND: " + " ".join(argv) + "\n").encode()
        + result.stdout
        + f"\nEXIT: {result.returncode}\n".encode()
    )
    assert result.returncode == 0, log


def hashes():
    return {
        path: hashlib.sha256((checkout / path).read_bytes()).hexdigest()
        if (checkout / path).is_file()
        else None
        for path in owned
    }


command(["git", "worktree", "add", "--detach", str(checkout), base], root, "rollback-checkout.log")
try:
    # Overlay exact initial candidate contract dependencies, not today's mutable tree.
    manifest = json.loads((evidence / "task-input-manifest.json").read_bytes())
    dependencies = [
        entry["path"]
        for entry in manifest["allowed_inputs"]
        if entry["path"].startswith("contracts/cloud-")
        or entry["path"]
        in (
            "plugins/sdd-quality-loop/scripts/cloud_contracts.py",
            "tests/cloud-orchestration-contracts.tests.py",
            "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py",
        )
    ]
    for path in dependencies:
        destination = checkout / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(scratch / "inputs" / path, destination)
    before = hashes()
    assert all(value is None for value in before.values())
    command(
        ["python3", "-B", "tests/cloud-orchestration-contracts.tests.py"],
        checkout,
        "rollback-baseline-before.log",
    )
    for path in owned:
        (checkout / path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / path, checkout / path)
    candidate = hashes()
    command(
        ["python3", "-B", "tests/cloud-orchestration-execution.tests.py"], checkout, "rollback-candidate.log"
    )
    for path in owned:
        (checkout / path).unlink()
    after = hashes()
    assert after == before
    command(
        ["python3", "-B", "tests/cloud-orchestration-contracts.tests.py"],
        checkout,
        "rollback-baseline-after.log",
    )
    (evidence / "rollback.json").write_text(
        json.dumps(
            dict(
                base_revision=base,
                checkout=str(checkout),
                before=before,
                candidate=candidate,
                restored=after,
                classification="local disposable checkout; no cloud rollback or historical evidence restoration",
                baseline_tests=23,
                admission_tests=22,
            ),
            indent=2,
        )
        + "\n"
    )
finally:
    command(["git", "worktree", "remove", "--force", str(checkout)], root, "rollback-cleanup.log")
