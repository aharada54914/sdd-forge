#!/usr/bin/env bash
set -euo pipefail

manifest=""
repo_root=""
snapshot_root=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest="${2:-}"
      shift 2
      ;;
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    --snapshot-root)
      snapshot_root="${2:-}"
      shift 2
      ;;
    *)
      printf 'TASK_INPUT_JSON: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

python3 - "$manifest" "$repo_root" "$snapshot_root" <<'PY'
import hashlib
import json
import ctypes
import errno
import os
import re
import shutil
import stat
import sys
import tempfile
import time

manifest, repo_root, snapshot_root = sys.argv[1:]
SHA = re.compile(r"^[a-f0-9]{64}$")

def fail(code, message):
    print(f"TASK_INPUT_{code}: {message}", file=sys.stderr)
    sys.exit(1)

def path_ok(path):
    if not isinstance(path, str) or not path or path.startswith("/") or "\\" in path:
        return False
    parts = path.split("/")
    return (
        not any(part in ("", ".", "..") for part in parts)
        and re.match(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$", path) is not None
    )

def source_path(repo, rel):
    current = repo
    parts = rel.split("/")
    for part in parts:
        current = os.path.join(current, part)
        try:
            info = os.lstat(current)
        except FileNotFoundError:
            fail("PATH", f"input missing: {rel}")
        if stat.S_ISLNK(info.st_mode):
            fail("PATH", f"input contains symlink: {rel}")
    if not stat.S_ISREG(info.st_mode):
        fail("PATH", f"input is not a regular non-symlink file: {rel}")
    return current, info

def make_read_only(root):
    directories = []
    for current, dirnames, filenames in os.walk(root):
        directories.append(current)
        for name in filenames:
            path = os.path.join(current, name)
            info = os.lstat(path)
            if not stat.S_ISREG(info.st_mode):
                fail("PATH", "snapshot contains a non-regular file")
            os.chmod(path, 0o444, follow_symlinks=False)
        for name in dirnames:
            path = os.path.join(current, name)
            info = os.lstat(path)
            if not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode):
                fail("PATH", "snapshot contains an unsafe directory")
    for path in reversed(directories):
        directory_fd = os.open(path, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
        os.chmod(path, 0o555, follow_symlinks=False)
    for current, dirnames, filenames in os.walk(root):
        for name in filenames:
            mode = os.lstat(os.path.join(current, name)).st_mode
            if not stat.S_ISREG(mode) or mode & 0o222:
                fail("PATH", "snapshot file is not read-only")
        for name in dirnames:
            mode = os.lstat(os.path.join(current, name)).st_mode
            if not stat.S_ISDIR(mode) or stat.S_ISLNK(mode) or mode & 0o222:
                fail("PATH", "snapshot directory is not read-only")
    if os.lstat(root).st_mode & 0o222:
        fail("PATH", "snapshot root is not read-only")

def wait_at_test_publication_barrier():
    barrier = os.environ.get("SDD_TEST_SNAPSHOT_PUBLISH_BARRIER_DIR")
    if not barrier:
        return
    try:
        with open(os.path.join(barrier, "ready"), "xb"):
            pass
    except OSError as exc:
        fail("PATH", f"invalid test publication barrier: {exc}")
    deadline = time.monotonic() + 10
    while not os.path.exists(os.path.join(barrier, "continue")):
        if time.monotonic() >= deadline:
            fail("PATH", "test publication barrier timed out")
        time.sleep(0.01)

def atomic_publish_no_replace(source, destination):
    source_bytes = os.fsencode(source)
    destination_bytes = os.fsencode(destination)
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform.startswith("linux"):
        try:
            rename = libc.renameat2
        except AttributeError:
            fail("PATH", "atomic no-replace publication is unavailable")
        rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        rename.restype = ctypes.c_int
        result = rename(-100, source_bytes, -100, destination_bytes, 1)
    elif sys.platform == "darwin":
        rename = libc.renamex_np
        rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        rename.restype = ctypes.c_int
        result = rename(source_bytes, destination_bytes, 0x00000004)
    elif os.name == "nt":
        result = 1 if ctypes.windll.kernel32.MoveFileW(source, destination) else 0
    else:
        fail("PATH", "atomic no-replace publication is unavailable")
    if result != 0:
        error = ctypes.get_errno()
        if error in (errno.EEXIST, errno.ENOTEMPTY) or os.path.lexists(destination):
            fail("PATH", "snapshot root already exists")
        fail("PATH", f"atomic snapshot publication failed: errno {error}")

def remove_temporary_tree(path):
    if not os.path.exists(path):
        return
    for current, dirnames, filenames in os.walk(path):
        os.chmod(current, 0o700, follow_symlinks=False)
        for name in filenames:
            os.chmod(os.path.join(current, name), 0o600, follow_symlinks=False)
    shutil.rmtree(path)

try:
    with open(manifest, "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception as exc:
    fail("JSON", str(exc))

if not isinstance(data, dict):
    fail("JSON", "manifest must be an object")
inputs = data.get("allowed_inputs")
if not isinstance(inputs, list) or not inputs:
    fail("PATH", "allowed_inputs must be non-empty")
if not repo_root or not snapshot_root:
    fail("JSON", "missing repo or snapshot root")
repo_root = os.path.realpath(repo_root)
if not os.path.isdir(repo_root):
    fail("PATH", "repository root is not a directory")
if os.path.lexists(snapshot_root):
    fail("PATH", "snapshot root already exists")
parent = os.path.dirname(os.path.abspath(snapshot_root))
os.makedirs(parent, exist_ok=True)
tmp = tempfile.mkdtemp(prefix=".task-snapshot-", dir=parent)
try:
    seen = set()
    for entry in inputs:
        if not isinstance(entry, dict) or set(entry) != {"path", "sha256"}:
            fail("PATH", "invalid allowed_inputs entry")
        rel = entry["path"]
        expected = entry["sha256"]
        if not path_ok(rel):
            fail("PATH", f"invalid input path: {rel}")
        if rel in seen:
            fail("PATH", f"duplicate input path: {rel}")
        seen.add(rel)
        if not isinstance(expected, str) or not SHA.match(expected):
            fail("HASH", f"invalid sha256 for {rel}")
        source, stat_before = source_path(repo_root, rel)
        digest = hashlib.sha256()
        target = os.path.join(tmp, *rel.split("/"))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        try:
            source_fd = os.open(source, flags)
        except OSError:
            fail("PATH", f"input is not a regular non-symlink file: {rel}")
        with os.fdopen(source_fd, "rb") as src, open(target, "xb") as dst:
            opened = os.fstat(src.fileno())
            if (opened.st_dev, opened.st_ino) != (stat_before.st_dev, stat_before.st_ino):
                fail("HASH", f"source changed before copy: {rel}")
            for chunk in iter(lambda: src.read(1024 * 1024), b""):
                digest.update(chunk)
                dst.write(chunk)
            dst.flush()
            os.fsync(dst.fileno())
            stat_after = os.fstat(src.fileno())
        try:
            path_after = os.lstat(source)
        except FileNotFoundError:
            fail("HASH", f"source changed during copy: {rel}")
        if (stat_before.st_dev, stat_before.st_ino, stat_before.st_size, stat_before.st_mtime_ns) != (
            stat_after.st_dev, stat_after.st_ino, stat_after.st_size, stat_after.st_mtime_ns
        ):
            fail("HASH", f"source changed during copy: {rel}")
        if (path_after.st_dev, path_after.st_ino) != (stat_before.st_dev, stat_before.st_ino):
            fail("HASH", f"source changed during copy: {rel}")
        actual = digest.hexdigest()
        if actual != expected:
            fail("HASH", f"source hash mismatch: {rel}")
    make_read_only(tmp)
    wait_at_test_publication_barrier()
    atomic_publish_no_replace(tmp, snapshot_root)
    parent_fd = os.open(parent, os.O_RDONLY)
    try:
        os.fsync(parent_fd)
    finally:
        os.close(parent_fd)
except BaseException:
    remove_temporary_tree(tmp)
    raise

print("TASK_INPUT_OK")
PY
