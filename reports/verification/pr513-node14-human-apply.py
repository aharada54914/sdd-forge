"""Human-only application of the seven Node 14 ownership-check replacements."""
import hashlib
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
REL = "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js"
HEAD = "3a06933f6f9b5f51781dca4dc4c0f40b94f6382f"


def main():
    if sys.argv[1:] != ["--apply"]:
        raise SystemExit("Human only: run with --apply. No files changed.")
    target = ROOT / REL
    if target.is_symlink() or not target.is_file():
        raise SystemExit("Target is not a regular non-symlink file; no apply.")
    actual_head = subprocess.check_output(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True
    ).strip()
    if actual_head != HEAD:
        raise SystemExit("HEAD changed; no apply.")
    original = target.read_bytes()
    committed = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"{HEAD}:{REL}"]
    )
    if original != committed:
        raise SystemExit("Target differs from pinned commit; no apply.")
    expected = {
        b"Object.hasOwn(payload, 'toolCalls')": 1,
        b"Object.hasOwn(payload, 'toolName')": 1,
        b"Object.hasOwn(payload, 'toolArgs')": 1,
        b"Object.hasOwn(payload, k)": 2,
        b"Object.hasOwn(args, 'view_range')": 1,
        b"Object.hasOwn(args, 'file_text')": 1,
    }
    if original.count(b"Object.hasOwn(") != 7 or any(
        original.count(expr) != count for expr, count in expected.items()
    ):
        raise SystemExit("Expected seven expressions do not match; no apply.")
    candidate = original.replace(
        b"Object.hasOwn(", b"Object.prototype.hasOwnProperty.call("
    )
    subprocess.run(["node", "--check"], input=candidate, check=True)
    backup = pathlib.Path(tempfile.mkdtemp(prefix="sdd-pr513-node14-")) / target.name
    shutil.copy2(target, backup)
    if target.read_bytes() != original or backup.read_bytes() != original:
        raise SystemExit(f"Source or backup changed; no apply. Backup: {backup}")
    print(f"Backup: {backup}", flush=True)
    fd, temporary = tempfile.mkstemp(prefix=".node14-", dir=target.parent)
    staged = pathlib.Path(temporary)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(candidate)
            stream.flush()
            os.fsync(stream.fileno())
        shutil.copystat(target, staged)
        if staged.read_bytes() != candidate or target.read_bytes() != original:
            raise SystemExit("Staged bytes or source changed; no apply.")
        os.replace(staged, target)
    finally:
        staged.unlink(missing_ok=True)
    if target.read_bytes() != candidate:
        raise SystemExit(f"Readback mismatch; stop. Backup: {backup}")
    print(f"SHA256: {hashlib.sha256(candidate).hexdigest()}  {REL}")
    print("Applied seven replacements; Node syntax passed.")
    print("Node 14 runtime tests, regressions, CI and merge remain pending.")
    print("No commit/push/merge or review-status changes. Send output to Codex.")


if __name__ == "__main__":
    main()
