"""Restore only T-004 code/tests in a disposable checkout; never cloud rollback."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent
SCRATCH = Path("/tmp/cloud-T004-01a14d9e-7a63-71c2-a07c-aa71d275b9de")
WORKTREE = SCRATCH / "rollback"


def main():
    base = json.loads((OUT.parent/"before.json").read_bytes())["base_revision"]
    records = []

    def run(label, args, cwd=WORKTREE):
        started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        proc = subprocess.run(args, cwd=cwd, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1",
            "CLOUD_AZURE_UPSTREAM_ROOT": str(OUT/"native-workspace/bundle/upstream")},
            capture_output=True, timeout=180)
        (OUT/(label+"-final.log")).write_bytes(proc.stdout+proc.stderr)
        records.append(dict(label=label, command=args, cwd=str(cwd), start_utc=started, exit_code=proc.returncode))
        return proc.returncode

    assert run("rollback-create", ["git", "worktree", "add", "--detach", str(WORKTREE), base], ROOT) == 0
    try:
        # Seed exact initial uncommitted contract/runtime/test bytes, not task states/reviews.
        initial = SCRATCH/"inputs"
        paths = [str(p.relative_to(initial)) for p in (initial/"contracts").glob("cloud-*.schema.json")]
        paths += ["plugins/sdd-quality-loop/scripts/cloud_contracts.py",
                  "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py",
                  "tests/cloud-orchestration-contracts.tests.py", "tests/cloud-orchestration-routing.tests.py"]
        for path in paths:
            dest = WORKTREE/path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(initial/path, dest)
        baseline = [sys.executable, "-B", "tests/cloud-orchestration-contracts.tests.py"]
        routing = [sys.executable, "-B", "tests/cloud-orchestration-routing.tests.py"]
        before_hash = hashlib.sha256((WORKTREE/"tests/cloud-orchestration-routing.tests.py").read_bytes()).hexdigest()
        assert not (WORKTREE/"plugins/sdd-azure-cloud").exists()
        assert run("rollback-before-contracts", baseline) == 0
        assert run("rollback-before-routing", routing) == 1
        shutil.copytree(ROOT/"plugins/sdd-azure-cloud", WORKTREE/"plugins/sdd-azure-cloud")
        shutil.copyfile(ROOT/"tests/cloud-orchestration-routing.tests.py", WORKTREE/"tests/cloud-orchestration-routing.tests.py")
        assert run("rollback-candidate-routing", routing) == 0
        # Exact task-owned restoration: remove newly introduced provider tree and restore old test bytes.
        shutil.rmtree(WORKTREE/"plugins/sdd-azure-cloud")
        shutil.copyfile(initial/"tests/cloud-orchestration-routing.tests.py", WORKTREE/"tests/cloud-orchestration-routing.tests.py")
        after_hash = hashlib.sha256((WORKTREE/"tests/cloud-orchestration-routing.tests.py").read_bytes()).hexdigest()
        assert after_hash == before_hash
        assert run("rollback-restored-contracts", baseline) == 0
        assert run("rollback-restored-routing", routing) == 1
        result = dict(candidate_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in [*sorted((ROOT/"plugins/sdd-azure-cloud").rglob("*")),
                                  ROOT/"tests/cloud-orchestration-routing.tests.py"] if p.is_file()},
                      base_revision=base, task_owned_initial_provider_tree="absent",
                      routing_before_sha256=before_hash, routing_restored_sha256=after_hash,
                      exact_restoration=True, cloud_resources_created=False,
                      limits="Restores local task files only; initial routing Red remains Red. No state/review/identity ledger restored.")
    finally:
        assert run("rollback-remove", ["git", "worktree", "remove", "--force", str(WORKTREE)], ROOT) == 0
    (OUT/"rollback-final.json").write_text(json.dumps({**result, "commands": records}, indent=2)+"\n")


if __name__ == "__main__":
    main()
