"""Released human-only snapshot v4 application batch; default is check-only.
Release covers the approved four-file RT-20260821-011 mode repair only.
The historical filename is retained. Agents must not apply or restore originals.
Stop on any guard refusal; do not reroute execution or alter pins to pass.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

OWNER = Path("/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge")
HEAD = "1e86fb272643e798db4e1ca0c89f0402317a2fc8"
HERE = OWNER / "reports/verification/rt002-snapshot-mode-repair-20261006"
HELPER = OWNER / "reports/verification/rt002-source-three-file-human-20261003.py"
HELPER_SHA = "5fd3353a3769d0879ca5fe06b6ad9758bcfa6cec750929a81e6f0752677e84e8"
PATCH_SHA = "a1129be245b1e4b52035d66163939ba98c661e5a369b178b0b2709ed6b9ece2d"
RELEASED = True  # 2026-10-06 scoped human release; not a CLI override or verdict.
MODES = (0o644, 0o644, 0o644, 0o644)  # Original modes, independently pinned.
ROWS = (
    ("plugins/sdd-implementation/scripts/prepare-task-snapshot.sh", "builder-candidate.sh",
     "b837c4409d3ea17e72c047bd2639e7cecb4a90f55c740170f313589f407f9267",
     "83302522785440208bc235ab6ad54ac679632c15a0f0e1edf8b4d59502e26b6b"),
    ("plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1", "builder-candidate.ps1",
     "35c4981f2b5eebb164223b4dd943c4ba90e9e5281b45c6e22d1bd1903f3428b2",
     "fbbde93b2d90d2cbdae5dac65121a361df30fef07eefb6e0ec8a5ac7a9cd7b75"),
    ("tests/task-context-isolation.tests.sh", "suite-proposed-v4.sh",
     "6b12e9ddd97327606d67d28a4e165ce3391afba28cfeaa04d68379f50f77fd9b",
     "3f4c0daa832c41db0c2b9899073508616f910a867dbf6673f43afc0cb15a04b5"),
    ("tests/task-context-isolation.tests.ps1", "suite-proposed-v4.ps1",
     "82641c89fc1b79a3077f18323fd3ac4a7f98aa7dd026e8173c26c9bffd566575",
     "ef3954581c1578914943e43cc3f73fd2bfd9e50ccd0d1f0355c632b25da8a1ae"),
)

def stop(message):
    raise ValueError(message)

def mode_metadata():
    return (json.dumps({"version": 1, "original_modes": [
        {"path": row[0], "mode": format(mode, "04o")}
        for row, mode in zip(ROWS, MODES, strict=True)
    ]}, sort_keys=True, separators=(",", ":")) + "\n").encode()

def backup_modes(helper, backup):
    expected = mode_metadata()
    path = backup / "original-modes.json"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as target:
        target.write(expected)
        target.flush()
        os.fsync(target.fileno())
    check_modes(helper, backup)

def check_modes(helper, backup):
    saved, metadata = helper.read_regular(backup / "original-modes.json")
    # Compare canonical bytes as well as SHA: exact keys, order, version and
    # values, derived only from pinned ROWS/MODES, never accepted from metadata.
    expected = mode_metadata()
    if saved != expected or helper.digest(saved) != helper.digest(expected) or stat.S_IMODE(metadata.st_mode) != 0o600:
        stop("restore mode metadata hash/schema/mode mismatch")

def recheck(helper, item):
    helper.recheck(item)
    _, metadata = helper.read_regular(item[1])
    if stat.S_IMODE(metadata.st_mode) != stat.S_IMODE(item[4].st_mode):
        stop("target mode changed during operation: " + str(item[1]))

def recovery_state(helper, backup):
    print("RECOVERY_REQUIRED: preserve backup; no automatic retry or rollback.", file=sys.stderr)
    print("BACKUP_DIRECTORY", backup, file=sys.stderr)
    for (rel, _, before, after), original_mode in zip(ROWS, MODES, strict=True):
        try:
            data, metadata = helper.read_regular(OWNER / rel)
            actual = helper.digest(data)
            state = "BEFORE" if actual == before else "AFTER" if actual == after else "UNKNOWN"
            if stat.S_IMODE(metadata.st_mode) != original_mode:
                state = "UNKNOWN_MODE"
        except Exception:
            state = "UNREADABLE"
        print("TARGET_STATE", rel, state, file=sys.stderr)
    print("Inspect all states. Only an authorized human may use --restore-human BACKUP_DIRECTORY; UNKNOWN/UNKNOWN_MODE/UNREADABLE must stop for investigation.", file=sys.stderr)

def restore(helper, backup):
    # Reuse the existing bare-envelope restore algorithm (old/new hash checks
    # plus atomic replacement), generalized to this batch's pinned helper/rows.
    if backup.parent != HERE or not backup.name.startswith("human-v4-backup-"):
        stop("restore backup outside the exact batch directory")
    if backup.resolve(strict=True) != backup or not stat.S_ISDIR(backup.lstat().st_mode):
        stop("restore backup must be a no-follow directory")
    if stat.S_IMODE(backup.stat().st_mode) != 0o700:
        stop("restore backup directory mode changed")
    check_modes(helper, backup)
    plans = []
    for index, (rel, _, before, after) in enumerate(ROWS, start=1):
        target = OWNER / rel
        prior, saved_metadata = helper.read_regular(backup / f"{index}-{target.name}.original")
        current, metadata = helper.read_regular(target)
        if stat.S_IMODE(metadata.st_mode) != MODES[index - 1]:
            stop("restore current mode mismatch: " + rel)
        if helper.digest(prior) != before or stat.S_IMODE(saved_metadata.st_mode) != 0o600:
            stop("restore backup hash or mode mismatch: " + rel)
        actual = helper.digest(current)
        if actual not in (before, after):
            stop("restore current hash mismatch: " + rel)
        plans.append((helper.FileSpec(rel, actual, before), target, current, prior, metadata, actual == before))
    # Validate every target and backup before writing any target. Already-before
    # rows allow explicit recovery of a partially applied/restored batch.
    for item in plans:
        recheck(helper, item)
    try:
        for item in plans:
            if not item[5]:
                recheck(helper, item)
                helper.replace_one(item)
        for item in plans:
            actual, metadata = helper.read_regular(item[1])
            if helper.digest(actual) != item[0].new_sha256 or stat.S_IMODE(metadata.st_mode) != stat.S_IMODE(item[4].st_mode):
                stop("restore final readback mismatch: " + str(item[1]))
    except Exception:
        recovery_state(helper, backup)
        raise
    print("RESTORED_ONCE_READBACK_OK; backups retained; no formal verdict")

def git(*args):
    return subprocess.run(["rtk", "proxy", "git", "-C", str(OWNER), *args],
                          check=True, capture_output=True, text=True).stdout.strip()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check-only", action="store_true")
    mode.add_argument("--apply-human", action="store_true")
    mode.add_argument("--restore-human", type=Path, metavar="BACKUP_DIRECTORY")
    args = parser.parse_args()
    if (args.apply_human or args.restore_human is not None) and not RELEASED:
        stop("UNRELEASED: shared snapshot high-risk scope/addendum and formal prerequisites are not established; no write attempted")
    if OWNER.resolve(strict=True) != OWNER or Path.cwd().resolve() != OWNER:
        stop("use the exact owner checkout")
    if git("rev-parse", "HEAD") != HEAD:
        stop("HEAD changed; pins require renewed review")
    if HELPER.parent.resolve() != HELPER.parent or not stat.S_ISREG(HELPER.lstat().st_mode):
        stop("helper is not a regular no-follow file")
    with os.fdopen(os.open(HELPER, os.O_RDONLY | os.O_NOFOLLOW), "rb") as source:
        helper_bytes = source.read()
    if hashlib.sha256(helper_bytes).hexdigest() != HELPER_SHA:
        stop("helper hash changed")
    # Execute only the pinned bytes just read, without a second path import.
    spec = importlib.util.spec_from_loader("rt002_pinned_apply_helper", loader=None)
    helper = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = helper
    exec(compile(helper_bytes, str(HELPER), "exec"), helper.__dict__)
    if args.restore_human is not None:
        restore(helper, args.restore_human)
        return
    patch = HERE / "candidate-v4.patch"
    if helper.digest(helper.read_regular(patch)[0]) != PATCH_SHA:
        stop("patch hash changed")
    plans = []
    for (rel, name, before, after), original_mode in zip(ROWS, MODES, strict=True):
        current, metadata = helper.read_regular(OWNER / rel)
        wanted, _ = helper.read_regular(HERE / name)
        if helper.digest(current) != before or helper.digest(wanted) != after:
            stop("target or candidate hash changed: " + rel)
        if stat.S_IMODE(metadata.st_mode) != original_mode:
            stop("target mode changed: " + rel)
        plans.append((helper.FileSpec(rel, before, after), OWNER / rel,
                      current, wanted, metadata, False))
        print("PIN_OK", rel, before, after)
    paths = {line.split("\t", 2)[2] for line in git("apply", "--numstat", str(patch)).splitlines()}
    if paths != {row[0] for row in ROWS}:
        stop("patch target set mismatch")
    git("apply", "--check", str(patch))
    for item in plans:
        recheck(helper, item)
    print("CHECK_ONLY_OK: HEAD, helper, patch, four before/after hashes, exact targets and applicability")
    if not args.apply_human:
        print("CHECK_ONLY: protected source unchanged; no backup created")
        return
    # Human-only application path: all originals backed up before first write.
    if HERE.resolve() != HERE:
        stop("backup parent traverses a symbolic link")
    backup = Path(tempfile.mkdtemp(prefix="human-v4-backup-", dir=HERE))
    os.chmod(backup, 0o700)
    print("BACKUP_DIRECTORY", backup, flush=True)
    try:
        backup_modes(helper, backup)
        for index, item in enumerate(plans, start=1):
            helper.backup_original(backup, index, item)
        for item in plans:
            recheck(helper, item)
        for item in plans:
            recheck(helper, item)
            helper.replace_one(item)
        for item in plans:
            actual, metadata = helper.read_regular(item[1])
            if helper.digest(actual) != item[0].new_sha256 or stat.S_IMODE(metadata.st_mode) != stat.S_IMODE(item[4].st_mode):
                stop("final readback mismatch: " + str(item[1]))
    except Exception:
        recovery_state(helper, backup)
        raise
    print("APPLIED_ONCE_READBACK_OK; formal verification, installed state and release are NOT VERIFIED")

if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("STOP:", error, file=sys.stderr)
        print("Preserve backup and inspect partial state; no automatic retry, rollback or alternate executor.", file=sys.stderr)
        raise SystemExit(1)
