"""Scoped rollback of supplemental tests; admitted candidate bytes are the baseline."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path.cwd()
BASE = Path("specs/cloud-orchestration/verification/T-013/preflight-repair")
SCRATCH = Path("/tmp/cloud-t013-preflight-01a14e44")
TREE = SCRATCH / "rollback-checkout"
records: list[dict] = []


def run(name: str, command: list[str], cwd: Path) -> None:
    started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)
    log = BASE / "evidence" / ("rollback-" + name + ".log")
    (ROOT / log).write_text(result.stdout + result.stderr)
    records.append(dict(name=name, command=command, cwd=str(cwd), started_at=started,
                        exit_code=result.returncode, log=str(log)))
    assert result.returncode == 0, name


def main() -> None:
    entry = json.loads((BASE / "evidence/entry.json").read_text())
    manifest = json.loads((BASE / "evidence/supplemental-task-input-manifest.json").read_text())
    run("create", ["git", "worktree", "add", "--detach", str(TREE), entry["base_revision"]], ROOT)
    try:
        for ref in manifest["allowed_inputs"]:
            dest = TREE / ref["path"]
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SCRATCH / "snapshot" / ref["path"], dest)
        for suite in ("execution", "contracts"):
            run("entry-" + suite, [sys.executable, "-B", "tests/cloud-orchestration-" + suite + ".tests.py"], TREE)
        outputs = [BASE / "probes.py", BASE / "run-mutations.py"]
        for relative in outputs:
            dest = TREE / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, dest)
        run("candidate-probes", [sys.executable, "-B", str(BASE / "probes.py"),
                                 "--output", str(ROOT / BASE / "evidence/rollback-candidate-probes.json")], TREE)
        for relative in outputs:
            (TREE / relative).unlink()
        for suite in ("execution", "contracts"):
            run("restored-" + suite, [sys.executable, "-B", "tests/cloud-orchestration-" + suite + ".tests.py"], TREE)
        equality = []
        for ref in manifest["allowed_inputs"]:
            actual = hashlib.sha256((TREE / ref["path"]).read_bytes()).hexdigest()
            equality.append(dict(path=ref["path"], expected_sha256=ref["sha256"], restored_sha256=actual))
            assert actual == ref["sha256"]
        for relative in outputs:
            shutil.copyfile(ROOT / relative, TREE / relative)
        run("reapplied-observation", [sys.executable, "-B", str(BASE / "probes.py"), "--case", "R9.observed-bindings",
                                      "--output", str(ROOT / BASE / "evidence/rollback-reapplied.json")], TREE)
        (BASE / "evidence/rollback.json").write_text(json.dumps(dict(base_revision=entry["base_revision"],
            baseline="Initial candidate bytes, not Git HEAD alone", commands=records, input_equality=equality,
            rollback_scope=[str(p) for p in outputs], production_changes=False), indent=2) + "\n")
    finally:
        run("remove", ["git", "worktree", "remove", "--force", str(TREE)], ROOT)
        (BASE / "evidence/rollback-commands.json").write_text(json.dumps(records, indent=2) + "\n")


if __name__ == "__main__":
    main()
