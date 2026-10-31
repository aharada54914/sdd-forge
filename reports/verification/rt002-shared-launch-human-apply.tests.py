"""Isolated control-flow tests for the human batch; no real git or owner apply."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types


HERE = Path(__file__).resolve().parent
BATCH = HERE / "rt002-shared-launch-human-apply-20261004.py"
NEW = "tests/review-implementation-binding.tests.py"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(root, rel, data):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def read(root, rel):
    return (root / rel).read_bytes()


def load_batch():
    module = types.ModuleType("rt002_batch_under_test")
    module.__file__ = str(BATCH)
    exec(compile(BATCH.read_bytes(), str(BATCH), "exec"), module.__dict__)
    return module


def fixture(root, batch):
    first_paths = [f"safe/file{i}.txt" for i in range(8)]
    second_paths = first_paths[:7] + ["safe/file8.txt", "safe/file9.txt", NEW]
    originals = {}
    first = []
    second = []
    for i in range(10):
        rel = f"safe/file{i}.txt"
        originals[rel] = f"original-{i}\n".encode()
        write(root, rel, originals[rel])
    for rel in first_paths:
        first.append(dict(path=rel, before_sha256=sha(originals[rel]),
                          proposed_sha256=sha(("first-" + rel).encode())))
    for rel in second_paths:
        before = ("first-" + rel).encode() if rel in first_paths else originals.get(rel, b"")
        second.append(dict(path=rel, before_sha256=sha(before),
                           proposed_sha256=sha(("second-" + rel).encode())))
    patch_paths = {}
    descriptors = []
    for number, rows in ((1, first), (2, second)):
        patch_name = f"stage{number}.patch"
        manifest_name = f"stage{number}.json"
        patch = f"synthetic stage {number}\n".encode()
        manifest = dict(status="candidate-not-applied", patch=patch_name,
                        patch_sha256=sha(patch), files=rows)
        manifest_data = json.dumps(manifest, sort_keys=True).encode()
        write(root, f"candidate/{patch_name}", patch)
        write(root, f"candidate/{manifest_name}", manifest_data)
        patch_paths[patch_name] = [row["path"] for row in rows]
        descriptors.append((manifest_name, sha(manifest_data), patch_name, sha(patch)))
    batch.OWNER = root
    batch.HEAD = "fixture-head"
    batch.CANDIDATE = Path("candidate")
    batch.MANIFESTS = tuple(descriptors)
    return originals, first, second, patch_paths


def run(batch, root, apply):
    old_cwd = Path.cwd()
    old_argv = sys.argv
    try:
        os.chdir(root)
        sys.argv = [str(BATCH)] + (["--apply"] if apply else [])
        try:
            batch.main()
        except SystemExit as error:
            return str(error)
        return None
    finally:
        sys.argv = old_argv
        os.chdir(old_cwd)


def inspect_case(case):
    with tempfile.TemporaryDirectory(prefix="rt002-batch-fixture-", dir=HERE) as temporary:
        root = Path(temporary)
        (root / "reports/verification").mkdir(parents=True)
        batch = load_batch()
        originals, first, second, paths = fixture(root, batch)
        calls = []

        def fake_git(repo, *args):
            assert repo == root
            calls.append(args)
            if args == ("rev-parse", "HEAD"):
                return batch.HEAD
            assert args[0] == "apply"
            name = Path(args[-1]).name
            if "--numstat" in args:
                return "\n".join(f"1\t1\t{rel}" for rel in paths[name])
            if "--check" in args:
                return ""
            if name == "stage2.patch" and case == "stage2-failure":
                raise subprocess.CalledProcessError(1, args, stderr="synthetic stage-2 refusal")
            rows = first if name == "stage1.patch" else second
            for row in rows:
                write(root, row["path"], ("first-" if name == "stage1.patch" else "second-").encode() + row["path"].encode())
            if case == "stage1-readback-mismatch" and name == "stage1.patch":
                write(root, first[0]["path"], b"synthetic wrong stage-1 bytes")
            if case == "stage2-readback-mismatch" and name == "stage2.patch":
                write(root, second[0]["path"], b"synthetic wrong stage-2 bytes")
            return ""

        batch.git = fake_git
        if case == "before-mismatch":
            write(root, "safe/file0.txt", b"unexpected bytes")
        if case == "chain-mismatch":
            manifest_path = root / "candidate/stage2.json"
            data = json.loads(manifest_path.read_text())
            data["files"][0]["before_sha256"] = "0" * 64
            manifest_path.write_text(json.dumps(data, sort_keys=True))
            row = list(batch.MANIFESTS[1])
            row[1] = sha(manifest_path.read_bytes())
            batch.MANIFESTS = (batch.MANIFESTS[0], tuple(row))
        if case == "success":
            assert run(batch, root, False) is None
            assert all(read(root, rel) == data for rel, data in originals.items())
        error = run(batch, root, True)
        backup_dirs = list((root / "reports/verification").glob("rt002-shared-launch-backup-*"))
        applies = [args[-1] for args in calls if args[0] == "apply" and "--check" not in args and "--numstat" not in args]
        if case == "success":
            assert error is None and len(backup_dirs) == 1
            assert [Path(item).name for item in applies] == ["stage1.patch", "stage2.patch"]
            assert all(read(root, row["path"]) == ("second-" + row["path"]).encode() for row in second)
            assert read(root, "safe/file7.txt") == b"first-safe/file7.txt"
            assert all(read(backup_dirs[0], rel) == data for rel, data in originals.items())
            assert not (backup_dirs[0] / NEW).exists()
        elif case in ("before-mismatch", "chain-mismatch"):
            assert error and "STOP:" in error and not backup_dirs and not applies
            assert not (root / NEW).exists()
            assert all(read(root, rel) == (b"unexpected bytes" if case == "before-mismatch" and rel == "safe/file0.txt" else data)
                       for rel, data in originals.items())
        elif case == "stage1-readback-mismatch":
            assert "unexpected target bytes/presence" in error and len(backup_dirs) == 1
            assert [Path(item).name for item in applies] == ["stage1.patch"]
            assert not any(args[0] == "apply" and Path(args[-1]).name == "stage2.patch" and "--check" in args for args in calls)
            assert read(root, first[0]["path"]) == b"synthetic wrong stage-1 bytes"
            assert all(read(backup_dirs[0], rel) == data for rel, data in originals.items())
            assert not (root / NEW).exists()
        elif case == "stage2-readback-mismatch":
            assert "unexpected target bytes/presence" in error and len(backup_dirs) == 1
            assert [Path(item).name for item in applies] == ["stage1.patch", "stage2.patch"]
            assert read(root, second[0]["path"]) == b"synthetic wrong stage-2 bytes"
            assert all(read(backup_dirs[0], rel) == data for rel, data in originals.items())
            assert read(root, NEW) == ("second-" + NEW).encode()
        else:
            assert "synthetic stage-2 refusal" in error and len(backup_dirs) == 1
            assert [Path(item).name for item in applies] == ["stage1.patch", "stage2.patch"]
            assert all(read(root, row["path"]) == ("first-" + row["path"]).encode() for row in first)
            assert all(read(backup_dirs[0], rel) == data for rel, data in originals.items())
            assert not (root / NEW).exists()
        print("PASS", case)


def main():
    for case in ("success", "before-mismatch", "chain-mismatch", "stage2-failure",
                 "stage1-readback-mismatch", "stage2-readback-mismatch"):
        inspect_case(case)
    print("PASS: 6; FAIL: 0")


if __name__ == "__main__":
    main()
