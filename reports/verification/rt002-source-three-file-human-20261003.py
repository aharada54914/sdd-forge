"""Human-only, hash-pinned RT002 source checkout application.

The default and --self-test modes do not write to the source checkout.
Only an explicit --apply-human may replace the three fixed source files.
Stop on a protected-operation refusal; do not reroute it through this helper.
No ledger, specification, task status, installed cache, or Git metadata is edited.
"""

import argparse
from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile


SOURCE_ROOT = Path("/Users/jrmag/sdd-forge")
CANDIDATE_ROOT = Path("/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge")


@dataclass(frozen=True)
class FileSpec:
    relative: str
    old_sha256: str
    new_sha256: str


FILES = (
    FileSpec(
        "plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py",
        "bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5",
        "1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d",
    ),
    FileSpec(
        "tests/check-hook-activation-handshake.tests.sh",
        "39463abc5464117cdc9e7ab6803652a061ec40b19af618fc30c0d78ffddc3403",
        "0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c",
    ),
    FileSpec(
        "tests/check-hook-activation-handshake.tests.ps1",
        "e0d2de1b1a9200d2634e5b377e32b4ddb4c22cf5648c3f4f5cd1f4457f963055",
        "49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd",
    ),
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_regular(path):
    if path.parent.resolve() != path.parent:
        raise ValueError("parent traverses a symbolic link: " + str(path))
    before = path.lstat()
    if not stat.S_ISREG(before.st_mode):
        raise ValueError("not a regular non-symlink file: " + str(path))
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as handle:
        opened = os.fstat(handle.fileno())
        if not stat.S_ISREG(opened.st_mode) or (before.st_dev, before.st_ino) != (opened.st_dev, opened.st_ino):
            raise ValueError("file changed during open: " + str(path))
        return handle.read(), opened


def plan(source_root, candidate_root, specs):
    plans = []
    for spec in specs:
        source = source_root / spec.relative
        candidate = candidate_root / spec.relative
        current, metadata = read_regular(source)
        wanted, _ = read_regular(candidate)
        if digest(wanted) != spec.new_sha256:
            raise ValueError("candidate SHA-256 mismatch: " + str(candidate))
        current_sha256 = digest(current)
        if current_sha256 not in (spec.old_sha256, spec.new_sha256):
            raise ValueError("source SHA-256 mismatch: " + str(source))
        plans.append((spec, source, current, wanted, metadata, current_sha256 == spec.new_sha256))
    return plans


def recheck(item):
    _, source, current, _, metadata, _ = item
    latest, latest_metadata = read_regular(source)
    if latest != current or (latest_metadata.st_dev, latest_metadata.st_ino) != (metadata.st_dev, metadata.st_ino):
        raise ValueError("source changed since preflight: " + str(source))


def backup_original(directory, index, item):
    spec, source, current, _, _, _ = item
    backup = directory / (str(index) + "-" + source.name + ".original")
    descriptor = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "wb") as handle:
        handle.write(current)
        handle.flush()
        os.fsync(handle.fileno())
    verified, metadata = read_regular(backup)
    if verified != current or digest(verified) != spec.old_sha256 or stat.S_IMODE(metadata.st_mode) != 0o600:
        raise ValueError("backup verification failed: " + str(backup))
    print("BACKUP", str(backup), "sha256=" + spec.old_sha256, flush=True)


def replace_one(item):
    spec, source, _, wanted, metadata, _ = item
    recheck(item)
    descriptor, temporary = tempfile.mkstemp(prefix=".rt002-source-three-", dir=source.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            os.fchmod(handle.fileno(), stat.S_IMODE(metadata.st_mode))
            handle.write(wanted)
            handle.flush()
            os.fsync(handle.fileno())
        temporary_path = Path(temporary)
        prepared, _ = read_regular(temporary_path)
        if digest(prepared) != spec.new_sha256:
            raise ValueError("temporary candidate SHA-256 mismatch: " + temporary)
        recheck(item)
        os.replace(temporary, source)
    finally:
        if os.path.lexists(temporary):
            os.unlink(temporary)
    actual, _ = read_regular(source)
    if digest(actual) != spec.new_sha256:
        raise ValueError("source readback SHA-256 mismatch: " + str(source))
    print("APPLIED", str(source), "sha256=" + spec.new_sha256, flush=True)


def run(source_root, candidate_root, specs, *, apply, backup_parent=None):
    # Complete three-file preflight before creating a backup or modifying a source.
    plans = plan(source_root, candidate_root, specs)
    for spec, source, _, _, _, already_applied in plans:
        print("TARGET", str(source), "state=" + ("already-applied" if already_applied else "original"))
        print("OLD_SHA256", spec.old_sha256)
        print("CANDIDATE_SHA256", spec.new_sha256)
    if not apply:
        print("DRY_RUN: no files changed")
        return
    pending = [(index, item) for index, item in enumerate(plans, start=1) if not item[5]]
    if not pending:
        print("ALREADY_APPLIED: no files changed")
        return
    for item in plans:
        recheck(item)
    backup_dir = Path(tempfile.mkdtemp(prefix="rt002-source-three-backups-", dir=backup_parent)).resolve()
    os.chmod(backup_dir, 0o700)
    print("BACKUP_DIRECTORY", str(backup_dir), flush=True)
    for index, item in pending:
        backup_original(backup_dir, index, item)
    # Per-file replacement is atomic, but the three-file batch is not transactional.
    # Never retry or roll back automatically after a refusal or partial failure.
    for _, item in pending:
        replace_one(item)
    for spec, source, _, _, _, _ in plans:
        actual, _ = read_regular(source)
        if digest(actual) != spec.new_sha256:
            raise ValueError("final three-file readback mismatch: " + str(source))
    print("ALL_THREE_READBACK_OK")


def self_test():
    with tempfile.TemporaryDirectory(prefix="rt002-source-three-selftest-") as directory:
        root = Path(directory).resolve()
        source = root / "source"
        candidate = root / "candidate"
        specs = []
        for index in range(1, 4):
            relative = "case-" + str(index) + "/file"
            old = ("original-" + str(index)).encode()
            new = ("candidate-" + str(index)).encode()
            for base, contents in ((source, old), (candidate, new)):
                path = base / relative
                path.parent.mkdir(parents=True)
                path.write_bytes(contents)
            specs.append(FileSpec(relative, digest(old), digest(new)))
        run(source, candidate, specs, apply=True, backup_parent=root)
        run(source, candidate, specs, apply=True, backup_parent=root)
        print("SELF_TEST success and idempotent rerun: PASS")

        source_bad = source / specs[2].relative
        source_bad.write_bytes(b"wrong hash")
        before = [(source / spec.relative).read_bytes() for spec in specs]
        try:
            run(source, candidate, specs, apply=True, backup_parent=root)
        except ValueError as error:
            if "source SHA-256 mismatch" not in str(error):
                raise
        else:
            raise AssertionError("hash mismatch was accepted")
        if before != [(source / spec.relative).read_bytes() for spec in specs]:
            raise AssertionError("hash refusal changed source")
        print("SELF_TEST hash mismatch no-change: PASS")

        source_bad.unlink()
        source_bad.symlink_to(candidate / specs[2].relative)
        before = [(source / spec.relative).lstat().st_mode for spec in specs]
        try:
            run(source, candidate, specs, apply=True, backup_parent=root)
        except ValueError as error:
            if "not a regular non-symlink file" not in str(error):
                raise
        else:
            raise AssertionError("symbolic link was accepted")
        if before != [(source / spec.relative).lstat().st_mode for spec in specs]:
            raise AssertionError("symlink refusal changed source")
        print("SELF_TEST symlink refusal: PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--apply-human", action="store_true", help="human-only three-file application")
    modes.add_argument("--self-test", action="store_true", help="isolated temporary-file tests only")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        run(SOURCE_ROOT, CANDIDATE_ROOT, FILES, apply=args.apply_human)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("STOP:", str(error), file=sys.stderr)
        print("No automatic retry or rollback. Preserve any printed backup directory and inspect partial state.", file=sys.stderr)
        raise SystemExit(1)
