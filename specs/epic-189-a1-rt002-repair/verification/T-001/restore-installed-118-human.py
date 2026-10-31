#!/usr/bin/env python3
"""Human-only, hash-pinned RT002 1.18.0 restoration adapter.

The agent may run --self-test only. --restore changes the installed verifier
and is reserved for the maintainer after an activation failure. A refusal is
final: never retry through another executor. No automatic rollback occurs.

The backup is the retained maintainer-owned root-source-application original,
not a claim that it was created by the installed application. Its exact bytes
and ownership are checked before either mode. No private backup path is stored
in this script; the maintainer supplies it explicitly.
"""

import argparse
import hashlib
import os
from pathlib import Path
import stat
import tempfile


HELPER = Path(__file__).resolve().parents[4] / "reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py"
HELPER_SHA256 = "3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1"
BACKUP_SHA256 = "bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5"
CURRENT_SHA256 = "1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d"
INSTALLED_TARGET = Path.home() / ".codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/check-hook-activation-handshake.py"


def checked_bytes(path, expected, *, owner_only=False):
    before = path.lstat()
    if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
        raise ValueError("artifact must be a single-link regular file")
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as stream:
        opened = os.fstat(stream.fileno())
        if not stat.S_ISREG(opened.st_mode) or (before.st_dev, before.st_ino) != (opened.st_dev, opened.st_ino):
            raise ValueError("artifact changed during read")
        data = stream.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError("artifact SHA-256 mismatch")
    if owner_only and (opened.st_uid != os.getuid() or stat.S_IMODE(opened.st_mode) != 0o600):
        raise ValueError("backup must be owner-owned and mode 0600")
    return data


def reviewed_restore():
    code = checked_bytes(HELPER, HELPER_SHA256)
    namespace = {"__name__": "rt002_restore_library", "__file__": str(HELPER)}
    exec(compile(code, str(HELPER), "exec"), namespace)
    return namespace["restore"]


def self_test(backup):
    prior = checked_bytes(backup, BACKUP_SHA256, owner_only=True)
    current = checked_bytes(INSTALLED_TARGET, CURRENT_SHA256)
    restore = reviewed_restore()
    with tempfile.TemporaryDirectory(prefix="rt002-118-restore-isolation-") as directory:
        root = Path(directory)
        target = root / "target.py"
        target.write_bytes(current)
        restore(backup, target)
        assert target.read_bytes() == prior

        target.write_bytes(b"wrong current")
        try:
            restore(backup, target)
        except ValueError:
            pass
        else:
            raise AssertionError("wrong current hash admitted")
        assert target.read_bytes() == b"wrong current"

        wrong_backup = root / "wrong-backup.py"
        wrong_backup.write_bytes(b"wrong backup")
        target.write_bytes(current)
        try:
            restore(wrong_backup, target)
        except ValueError:
            pass
        else:
            raise AssertionError("wrong backup hash admitted")
        assert target.read_bytes() == current

        linked_backup = root / "linked-backup.py"
        linked_backup.symlink_to(backup)
        try:
            restore(linked_backup, target)
        except (OSError, ValueError):
            pass
        else:
            raise AssertionError("symlink backup admitted")
        assert target.read_bytes() == current

        target.unlink()
        target.symlink_to(INSTALLED_TARGET)
        try:
            restore(backup, target)
        except (OSError, ValueError):
            pass
        else:
            raise AssertionError("symlink target admitted")
        assert target.is_symlink()

    print("RT002 1.18.0 restoration isolation: PASS (real backup, restore, two hash refusals, two symlink refusals)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--self-test", action="store_true")
    modes.add_argument("--restore", action="store_true")
    parser.add_argument("--backup", required=True, type=Path)
    args = parser.parse_args()
    backup = args.backup
    if args.self_test:
        self_test(backup)
        return
    checked_bytes(backup, BACKUP_SHA256, owner_only=True)
    checked_bytes(INSTALLED_TARGET, CURRENT_SHA256)
    reviewed_restore()(backup, INSTALLED_TARGET)


if __name__ == "__main__":
    main()
