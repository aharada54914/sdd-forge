"""Human-only RT002 candidate. Agents may run --self-test only.

Default: read-only dry-run against the fixed worktree target.
--apply: apply the two reviewed line changes. --installed additionally includes
the fixed installed target; without it the cache is never opened or inspected.
--restore BACKUP --installed: restore the pinned prior installed bytes after
human review. This mode was prepared after the current application.
Stop on a real refusal; do not retry it through another executor.
Isolation checks are not installed restoration, native activation, formal
review, or quality-gate evidence.
"""

import argparse
import difflib
import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile


OLD_SHA256 = "bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5"
NEW_SHA256 = "1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d"
RELATIVE_TARGET = "plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py"
WORKTREE_TARGET = Path("/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge") / RELATIVE_TARGET
INSTALLED_TARGET = Path("/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.17.0/scripts/check-hook-activation-handshake.py")
REPLACEMENTS = (
    (
        b'    "Script error:\\nCommand blocked by PreToolUse hook: "\n',
        b'    "Command blocked by PreToolUse hook: "\n',
    ),
    (
        b'    pattern = re.escape(HOST_DENIAL_PREFIX + _codex_canary_patch(placeholder))\n',
        b'    pattern = r"(?:Script error:\\n)?" + re.escape(HOST_DENIAL_PREFIX + _codex_canary_patch(placeholder))\n',
    ),
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_regular(path):
    before = path.lstat()
    if not stat.S_ISREG(before.st_mode):
        raise ValueError("target must be a regular non-symlink file: " + str(path))
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as handle:
        opened = os.fstat(handle.fileno())
        if (before.st_dev, before.st_ino) != (opened.st_dev, opened.st_ino):
            raise ValueError("target changed during open: " + str(path))
        data = handle.read()
    return data, opened


def transform(original):
    if digest(original) != OLD_SHA256:
        raise ValueError("original SHA-256 mismatch")
    result = original
    for old, new in REPLACEMENTS:
        if result.count(old) != 1:
            raise ValueError("reviewed old span count is not exactly one")
        result = result.replace(old, new, 1)
    old_lines = original.splitlines(keepends=True)
    new_lines = result.splitlines(keepends=True)
    if len(old_lines) != len(new_lines):
        raise ValueError("line count changed outside the reviewed scope")
    changes = [(old, new) for old, new in zip(old_lines, new_lines) if old != new]
    if changes != list(REPLACEMENTS):
        raise ValueError("diff is not exactly the two reviewed line replacements")
    compile(result, RELATIVE_TARGET, "exec", dont_inherit=True)
    return result


def plan(path):
    current, metadata = read_regular(path)
    if digest(current) == OLD_SHA256:
        original = current
        candidate = transform(original)
        already_applied = False
    else:
        # Idempotence is accepted only if exact inverse spans reconstruct the
        # hash-pinned original and the forward transform reproduces every byte.
        original = current
        for old, new in REPLACEMENTS:
            if original.count(new) != 1:
                raise ValueError("target SHA-256 mismatch: " + str(path))
            original = original.replace(new, old, 1)
        if digest(original) != OLD_SHA256:
            raise ValueError("target SHA-256 mismatch: " + str(path))
        candidate = transform(original)
        if candidate != current:
            raise ValueError("target is not the exact reviewed candidate: " + str(path))
        already_applied = True
    return path, current, candidate, metadata, already_applied


def recheck(item):
    path, current, candidate, metadata, already_applied = item
    latest, latest_metadata = read_regular(path)
    if latest != current or (latest_metadata.st_dev, latest_metadata.st_ino) != (metadata.st_dev, metadata.st_ino):
        raise ValueError("target changed since preflight: " + str(path))


def backup_original(directory, index, item):
    path, current, candidate, metadata, already_applied = item
    backup = directory / (str(index) + "-" + path.name + ".original")
    fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as handle:
        os.fchmod(handle.fileno(), 0o600)
        handle.write(current)
        handle.flush()
        os.fsync(handle.fileno())
    if backup.read_bytes() != current or stat.S_IMODE(backup.stat().st_mode) != 0o600:
        raise ValueError("backup verification failed")
    print("BACKUP", str(backup), "sha256=" + digest(current), flush=True)


def atomic_apply(item, label="HUMAN_APPLIED"):
    path, current, candidate, metadata, already_applied = item
    fd, temporary_name = tempfile.mkstemp(prefix=".rt002-human-", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(candidate)
            handle.flush()
            os.fchmod(handle.fileno(), stat.S_IMODE(metadata.st_mode))
            os.fsync(handle.fileno())
        recheck(item)
        os.replace(temporary, path)
        actual, _ = read_regular(path)
        if digest(actual) != digest(candidate):
            raise ValueError("post-application SHA-256 mismatch: " + str(path))
        print(label, str(path), "sha256=" + digest(actual), flush=True)
    finally:
        if temporary.exists():
            temporary.unlink()


def restore(backup, target):
    prior, _ = read_regular(backup)
    if digest(prior) != OLD_SHA256:
        raise ValueError("backup SHA-256 mismatch")
    current, metadata = read_regular(target)
    if digest(current) != NEW_SHA256:
        raise ValueError("installed SHA-256 mismatch")
    atomic_apply((target, current, prior, metadata, False), "HUMAN_RESTORED")


def self_test():
    current, _ = read_regular(WORKTREE_TARGET)
    if digest(current) != NEW_SHA256:
        raise ValueError("source SHA-256 mismatch")
    prior = current
    for old, new in REPLACEMENTS:
        if prior.count(new) != 1:
            raise ValueError("reviewed new span count is not exactly one")
        prior = prior.replace(new, old, 1)
    if digest(prior) != OLD_SHA256:
        raise ValueError("reconstructed prior SHA-256 mismatch")
    with tempfile.TemporaryDirectory(prefix="rt002-restore-test-") as directory:
        root = Path(directory)
        backup, target, other = (root / name for name in ("backup", "target", "other"))
        backup.write_bytes(prior)
        target.write_bytes(current)
        restore(backup, target)
        if target.read_bytes() != prior:
            raise AssertionError("isolated restoration produced wrong bytes")

        target.write_bytes(current)
        backup.write_bytes(b"wrong backup")
        try:
            restore(backup, target)
        except ValueError:
            pass
        else:
            raise AssertionError("backup hash mismatch accepted")
        if target.read_bytes() != current:
            raise AssertionError("backup hash refusal mutated target")

        backup.write_bytes(prior)
        target.write_bytes(b"wrong installed target")
        try:
            restore(backup, target)
        except ValueError:
            pass
        else:
            raise AssertionError("installed hash mismatch accepted")
        if target.read_bytes() != b"wrong installed target":
            raise AssertionError("installed hash refusal mutated target")

        target.write_bytes(current)
        other.write_bytes(prior)
        backup.unlink()
        backup.symlink_to(other)
        try:
            restore(backup, target)
        except (OSError, ValueError):
            pass
        else:
            raise AssertionError("symlink backup accepted")
        if target.read_bytes() != current:
            raise AssertionError("backup symlink refusal mutated target")

        backup.unlink()
        backup.write_bytes(prior)
        target.unlink()
        target.symlink_to(other)
        try:
            restore(backup, target)
        except (OSError, ValueError):
            pass
        else:
            raise AssertionError("symlink target accepted")
        if other.read_bytes() != prior:
            raise AssertionError("target symlink refusal mutated destination")
    print("Restore isolation checks: PASS (restore, two hash refusals, two symlink refusals)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--apply", action="store_true", help="human-only application; omitted means dry-run")
    modes.add_argument("--restore", type=Path, metavar="BACKUP", help="human-only installed restoration")
    modes.add_argument("--self-test", action="store_true", help="temporary isolation only; no installed access")
    parser.add_argument("--installed", action="store_true", help="also include the fixed installed target")
    args = parser.parse_args()
    if args.self_test:
        if args.installed:
            parser.error("--self-test cannot use --installed")
        self_test()
        return
    if args.restore:
        if not args.installed:
            parser.error("--restore requires --installed")
        restore(args.restore, INSTALLED_TARGET)
        return
    targets = [WORKTREE_TARGET]
    if args.installed:
        targets.append(INSTALLED_TARGET)
    # Validate every selected target before any backup or source write.
    plans = [plan(path) for path in targets]
    for item in plans:
        path, current, candidate, metadata, already_applied = item
        print("TARGET", str(path))
        print("OLD_SHA256", OLD_SHA256)
        print("CANDIDATE_SHA256", digest(candidate))
        print("STATE", "already-applied" if already_applied else "original")
        if not already_applied:
            sys.stdout.write("".join(difflib.unified_diff(
                current.decode("utf-8").splitlines(keepends=True),
                candidate.decode("utf-8").splitlines(keepends=True),
                fromfile="a/" + RELATIVE_TARGET, tofile="b/" + RELATIVE_TARGET,
            )))
    if not args.apply:
        print("DRY_RUN: no files changed; no test/native/formal gate claim.")
        return
    pending = [item for item in plans if not item[4]]
    if not pending:
        print("ALREADY_APPLIED: no files changed; no test/native/formal gate claim.")
        return
    for item in plans:
        recheck(item)
    backup_directory = Path(tempfile.mkdtemp(prefix="rt002-human-originals-"))
    os.chmod(backup_directory, 0o700)
    print("BACKUP_DIRECTORY", str(backup_directory), flush=True)
    for index, item in enumerate(pending):
        backup_original(backup_directory, index, item)
    # Each replacement is atomic; a multi-target run is not a filesystem-wide
    # transaction. On any failure stop, retain backups and inspect stdout.
    for item in pending:
        atomic_apply(item)
    print("APPLICATION_ONLY: tests, native activation and formal review remain unverified.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("STOP:", str(error), file=sys.stderr)
        print("No automatic retry/rollback. Retain any printed backups and inspect partial-application output.", file=sys.stderr)
        raise SystemExit(1)
