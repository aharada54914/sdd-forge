"""Prepare or human-apply the fixed RT002 shared-launch recovery, in order.

Run with ``rtk proxy python3 ...`` from the named owner checkout. The default
is read-only. ``--apply`` is solely for the maintainer's permitted human path;
an actual protection refusal is a stop, never a reason to retry elsewhere.
This does not run the original-path suites or reserve a reviewer identity.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile


OWNER = Path("/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge")
HEAD = "1e86fb272643e798db4e1ca0c89f0402317a2fc8"
CANDIDATE = Path("specs/epic-189-a1-rt002-repair/verification/T-001/provenance-recovery-candidate-20261004")
MANIFESTS = (
    ("candidate-hashes.json", "66d27303ae49a89794d19869fafc6220917e7d2413f629a5cfc0f0f51d6cfea2",
     "shared-launch-auth-preserving.patch", "df4578aba6b540b6e6d8156877a7311d2e090080837cc10ff68b58ff9e004404"),
    ("binding-followup-hashes.json", "f9d865cd1bfaafa3289292ae08ecb6cda0cee74e14e3833a90e8887c684f6ed3",
     "binding-followup-integrated.patch", "2b0fff67fbc907cf62a947fc887f7b776c26655e77a35535b093047b41997087"),
)
EMPTY_HASH = hashlib.sha256(b"").hexdigest()


def stop(message):
    raise SystemExit("STOP: " + message)


def digest(path):
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as source:
        return hashlib.sha256(source.read()).hexdigest()


def read_regular(path):
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as source:
        if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
            stop("opened target is not regular: " + str(path))
        return source.read()


def no_follow_regular(root, rel, *, absent=False):
    """Reject symlink components and non-regular targets; never follow a link."""
    current = root
    parts = Path(rel).parts
    if not parts or Path(rel).is_absolute() or any(part in (".", "..", "") for part in parts):
        stop("noncanonical target: " + rel)
    for part in parts[:-1]:
        current /= part
        try:
            mode = current.lstat().st_mode
        except FileNotFoundError:
            if absent:
                return None
            stop("missing parent: " + str(current))
        if not stat.S_ISDIR(mode):
            stop("parent is not a real directory: " + str(current))
    target = current / parts[-1]
    try:
        mode = target.lstat().st_mode
    except FileNotFoundError:
        if absent:
            return None
        stop("missing target: " + str(target))
    if not stat.S_ISREG(mode):
        stop("target is not a no-follow regular file: " + str(target))
    return target


def no_follow_directory(root, rel):
    current = root
    for part in Path(rel).parts:
        current /= part
        if not stat.S_ISDIR(current.lstat().st_mode):
            stop("backup parent is not a real directory: " + str(current))
    return current


def check_bytes(root, expected, absent):
    for rel, sha in sorted(expected.items()):
        path = no_follow_regular(root, rel, absent=rel in absent)
        if path is None:
            if sha != EMPTY_HASH:
                stop("absent target has nonempty expected digest: " + rel)
            continue
        if rel in absent or digest(path) != sha:
            stop("unexpected target bytes/presence: " + rel)


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="maintainer-only permitted application")
    args = parser.parse_args()
    root = OWNER.resolve(strict=True)
    if root != OWNER or Path.cwd().resolve() != root:
        stop("run from the exact RT002 owner checkout")
    if git(root, "rev-parse", "HEAD") != HEAD:
        stop("owner HEAD changed; re-review the candidate")

    loaded = []
    for manifest_name, manifest_sha, patch_name, patch_sha in MANIFESTS:
        manifest_path = no_follow_regular(root, str(CANDIDATE / manifest_name))
        patch_path = no_follow_regular(root, str(CANDIDATE / patch_name))
        if digest(manifest_path) != manifest_sha or digest(patch_path) != patch_sha:
            stop("fixed manifest or patch digest changed: " + manifest_name)
        manifest = json.loads(read_regular(manifest_path).decode("utf-8"))
        if manifest["patch"] != patch_name or manifest["patch_sha256"] != patch_sha or manifest["status"] != "candidate-not-applied":
            stop("candidate metadata changed: " + manifest_name)
        files = {row["path"]: row for row in manifest["files"]}
        if len(files) != len(manifest["files"]):
            stop("duplicate target in " + manifest_name)
        patch_paths = {line.split("\t", 2)[2] for line in git(root, "apply", "--numstat", str(patch_path)).splitlines()}
        if patch_paths != set(files):
            stop("patch target set differs from pinned manifest: " + patch_name)
        loaded.append((manifest, patch_path, files))

    first, first_patch, first_files = loaded[0]
    second, second_patch, second_files = loaded[1]
    shared = set(first_files) & set(second_files)
    if len(first_files) != 8 or len(second_files) != 10 or len(shared) != 7 or len(set(first_files) | set(second_files)) != 11:
        stop("unexpected two-stage target topology")
    for rel in shared:
        if first_files[rel]["proposed_sha256"] != second_files[rel]["before_sha256"]:
            stop("intermediate hash chain mismatch: " + rel)

    before = {rel: row["before_sha256"] for rel, row in first_files.items()}
    before.update({rel: row["before_sha256"] for rel, row in second_files.items() if rel not in first_files})
    middle = dict(before)
    middle.update({rel: row["proposed_sha256"] for rel, row in first_files.items()})
    after = dict(middle)
    after.update({rel: row["proposed_sha256"] for rel, row in second_files.items()})
    new_files = {rel for rel, sha in before.items() if sha == EMPTY_HASH}
    if new_files != {"tests/review-implementation-binding.tests.py"}:
        stop("unexpected created-file set")
    check_bytes(root, before, new_files)
    git(root, "apply", "--check", str(first_patch))
    print("PRECHECK OK: fixed patches, 11 before hashes, seven intermediate links, stage-1 applicability")
    if not args.apply:
        print("READ-ONLY: stage 2 applicability and final hashes require the permitted human application")
        return

    backup_parent = no_follow_directory(root, "reports/verification")
    backup_root = Path(tempfile.mkdtemp(prefix="rt002-shared-launch-backup-", dir=backup_parent))
    for rel in sorted(before):
        source = no_follow_regular(root, rel, absent=rel in new_files)
        if source is None:
            continue
        destination = backup_root / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("xb") as output:
            output.write(read_regular(source))
            output.flush()
            os.fsync(output.fileno())
        if digest(destination) != before[rel]:
            stop("backup readback mismatch: " + rel)
    check_bytes(root, before, new_files)
    print("BACKUP OK:", backup_root, flush=True)
    try:
        git(root, "apply", str(first_patch))
        check_bytes(root, middle, new_files)
        git(root, "apply", "--check", str(second_patch))
        git(root, "apply", str(second_patch))
        check_bytes(root, after, set())
    except (subprocess.CalledProcessError, SystemExit) as error:
        detail = error.stderr if isinstance(error, subprocess.CalledProcessError) else str(error)
        stop(f"application stopped ({detail}); preserve {backup_root}; inspect exact target bytes and protection response before human recovery; do not retry elsewhere")
    print("APPLIED AND READBACK OK: all 11 final hashes; backup:", backup_root)
    print("Original-path regressions, installed state, CI, evaluator reservation and Done are NOT verified.")


if __name__ == "__main__":
    main()
