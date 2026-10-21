#!/usr/bin/env python3
"""Task-local proposal. Root admits the complete payload and owns execution/subreaping."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import time


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def load_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=pairs)


def relative(value):
    if (not isinstance(value, str) or not value or value.startswith("/")
            or "\\" in value or any(part in ("", ".", "..") for part in value.split("/"))
            or any(ord(character) < 32 for character in value)):
        raise ValueError("invalid relative path")
    return Path(value)


def regular_beneath(root, name):
    target = root
    parts = relative(name).parts
    for index, part in enumerate(parts):
        target = target / part
        mode = target.lstat().st_mode
        if stat.S_ISLNK(mode) or (index < len(parts) - 1 and not stat.S_ISDIR(mode)):
            raise ValueError("aliased input path: " + name)
    if not stat.S_ISREG(target.lstat().st_mode):
        raise ValueError("nonregular input: " + name)
    return target


KNOWN_LINK = "tests/fixtures/capability-registry/identity-bidirectional-repo/plugins/sdd-quality-loop/scripts/check-registered-symlink.py"
KNOWN_TARGET = "check-registered.py"


def inventory(root, exclude_git=False, allow_known_link=False):
    result = {}
    for directory, directories, files in os.walk(root, followlinks=False):
        here = Path(directory)
        if exclude_git and here == root and ".git" in directories:
            directories.remove(".git")
        for name in directories:
            if (here / name).is_symlink():
                raise ValueError("unexpected directory alias")
        for name in files:
            path = here / name
            info = path.lstat()
            name = path.relative_to(root).as_posix()
            if stat.S_ISLNK(info.st_mode):
                target = os.readlink(path)
                if not allow_known_link or name != KNOWN_LINK or target != KNOWN_TARGET:
                    raise ValueError("unexpected symlink")
                sibling = path.parent / target
                if not stat.S_ISREG(sibling.lstat().st_mode):
                    raise ValueError("known link target is not a regular sibling")
                result[name] = {"sha256": hashlib.sha256(os.fsencode(target)).hexdigest(),
                                "mode": stat.S_IMODE(info.st_mode), "kind": "symlink", "target": target}
            elif stat.S_ISREG(info.st_mode):
                result[name] = {"sha256": digest(path), "mode": stat.S_IMODE(info.st_mode)}
            else:
                raise ValueError("unexpected nonregular file")
    return dict(sorted(result.items()))


def save(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parent-manifest", required=True, type=Path)
    parser.add_argument("--parent-manifest-sha256", required=True)
    parser.add_argument("--snapshot-root", required=True, type=Path)
    parser.add_argument("--payload-prefix", default="inputs/legacy-runtime/payload")
    parser.add_argument("--modes-input", default="inputs/legacy-runtime/payload-modes.json")
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--python", required=True, type=Path)
    parser.add_argument("--bash", required=True, type=Path)
    parser.add_argument("--git", required=True, type=Path)
    parser.add_argument("--pwsh", required=True, type=Path)
    parser.add_argument("--test-timeout-seconds", type=int, default=900)
    args = parser.parse_args()
    if sys.version_info[:2] != (3, 12) or Path(sys.executable).resolve() != args.python.resolve():
        raise ValueError("launch this controller with the admitted canonical Python 3.12")
    if str(args.pwsh) != "/workspace/.tools/sdd-forge-dev/bin/pwsh":
        raise ValueError("the official PowerShell launcher is required")
    if args.test_timeout_seconds <= 0:
        raise ValueError("positive bounded timeout required")
    for executable in (args.python, args.bash, args.git, args.pwsh):
        if not executable.is_absolute() or not os.access(executable, os.X_OK):
            raise ValueError("explicit executable is unavailable")
    raw = args.parent_manifest.read_bytes()
    if hashlib.sha256(raw).hexdigest() != args.parent_manifest_sha256:
        raise ValueError("parent manifest raw pin mismatch")
    manifest = load_json(raw)
    rows = manifest["allowed_inputs"]
    pins = {}
    admitted_before = {}
    for row in rows:
        name = row["path"]
        if name in pins:
            raise ValueError("duplicate admitted path")
        path = regular_beneath(args.snapshot_root, name)
        if digest(path) != row["sha256"]:
            raise ValueError("admitted input hash mismatch: " + name)
        pins[name] = row["sha256"]
        admitted_before[name] = {"sha256": row["sha256"], "mode": stat.S_IMODE(path.stat().st_mode)}
    # The original permission bits are data pinned by the parent manifest. The
    # immutable snapshot may itself have read-only storage permissions.
    modes_path = regular_beneath(args.snapshot_root, args.modes_input)
    if args.modes_input not in pins:
        raise ValueError("modes document is not admitted")
    modes = load_json(modes_path.read_bytes())
    if set(modes) != {"schema", "files", "links"} or modes["schema"] != "legacy-runtime-payload/v2":
        raise ValueError("unexpected payload modes schema")
    prefix = relative(args.payload_prefix).as_posix()
    payload = args.snapshot_root / prefix
    expected = {}
    for row in modes["files"]:
        if set(row) != {"path", "sha256", "mode"}:
            raise ValueError("payload row must have exactly path/sha256/mode")
        name = relative(row["path"]).as_posix()
        if name == ".git" or name.startswith(".git/") or name in expected:
            raise ValueError("duplicate or Git metadata payload")
        mode = row["mode"]
        if type(mode) is not int or mode < 0 or mode > 0o777:
            raise ValueError("permission bits must be an integer without special bits")
        logical = prefix + "/" + name
        if pins.get(logical) != row["sha256"]:
            raise ValueError("payload file lacks an exact parent pin: " + name)
        regular_beneath(args.snapshot_root, logical)
        expected[name] = {"sha256": row["sha256"], "mode": mode}
    if not expected or set(inventory(payload)) != set(expected):
        raise ValueError("payload has missing or unlisted files")
    admitted_payload = {name[len(prefix) + 1:] for name in pins if name.startswith(prefix + "/")}
    if admitted_payload != set(expected):
        raise ValueError("payload inventory differs from parent manifest")
    links = modes["links"]
    if not isinstance(links, list) or len(links) != 1:
        raise ValueError("exactly the single tracked fixture symlink is required")
    link = links[0]
    if (not isinstance(link, dict) or set(link) != {"path", "target", "target_input"}
            or link["path"] != KNOWN_LINK or link["target"] != KNOWN_TARGET):
        raise ValueError("symlink is outside the fixed fixture allowlist")
    target_input = relative(link["target_input"]).as_posix()
    if target_input not in pins or target_input.startswith(prefix + "/"):
        raise ValueError("link target bytes must be a separately admitted non-payload input")
    target_blob = regular_beneath(args.snapshot_root, target_input).read_bytes()
    if target_blob != KNOWN_TARGET.encode("utf-8") or hashlib.sha256(target_blob).hexdigest() != pins[target_input]:
        raise ValueError("raw pinned symlink target bytes differ")
    if KNOWN_LINK in expected:
        raise ValueError("the link must not be replaced by a regular payload file")
    target_relative = (Path(KNOWN_LINK).parent / KNOWN_TARGET).as_posix()
    if target_relative not in expected:
        raise ValueError("known contained sibling target is absent from regular payload")
    regular_beneath(args.snapshot_root, prefix + "/" + target_relative)
    regular_expected = dict(expected)
    expected[KNOWN_LINK] = {"sha256": hashlib.sha256(target_blob).hexdigest(), "mode": 0o777,
                            "kind": "symlink", "target": KNOWN_TARGET}
    required = {"tests/install.tests.sh", "tests/install.tests.ps1"}
    if not required <= set(expected):
        raise ValueError("both actual legacy installer suites are required")
    # No payload copying or Git/test operation precedes the complete pin checks.
    if not args.output_dir.is_absolute():
        raise ValueError("output directory must be absolute")
    args.output_dir.mkdir(parents=False, exist_ok=False)
    output = args.output_dir
    save(output / "admitted-before.json", admitted_before)
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
                       GIT_TERMINAL_PROMPT="0", PYTHONDONTWRITEBYTECODE="1")
    environment["PATH"] = os.pathsep.join(dict.fromkeys([
        str(args.python.parent), str(args.pwsh.parent), str(args.bash.parent),
        str(args.git.parent), *environment.get("PATH", "").split(os.pathsep)]))
    results = []
    record = {"schema": "t008-legacy-controller/v1", "parent_manifest_sha256": args.parent_manifest_sha256,
              "payload_count": len(expected), "regular_payload_count": len(regular_expected),
              "symlink_count": 1, "commands": results, "started_at_epoch": time.time(),
              "controller_sha256": digest(Path(__file__)), "outer_subreaper_owned_by_root": True}

    def run(label, argv, cwd, timeout=120):
        number = len(results) + 1
        stdout, stderr = output / f"{number:02d}-{label}.stdout", output / f"{number:02d}-{label}.stderr"
        row = {"label": label, "argv": [str(arg) for arg in argv], "cwd": str(cwd),
               "timeout_seconds": timeout, "started_at_epoch": time.time()}
        with stdout.open("wb") as out, stderr.open("wb") as err:
            try:
                result = subprocess.run(row["argv"], cwd=cwd, env=environment,
                                        stdout=out, stderr=err, timeout=timeout, check=False)
                row.update(exit_code=result.returncode, timed_out=False)
            except subprocess.TimeoutExpired:
                row.update(exit_code=None, timed_out=True)
        row.update(finished_at_epoch=time.time(), stdout=stdout.name, stderr=stderr.name,
                   stdout_sha256=digest(stdout), stderr_sha256=digest(stderr))
        results.append(row)
        save(output / "results.json", record)
        return row

    def git(label, arguments, cwd):
        row = run(label, [args.git, *arguments], cwd)
        if row["timed_out"] or row["exit_code"] != 0:
            raise RuntimeError("fixture Git setup failed: " + label)
        return (output / row["stdout"]).read_bytes()

    workspace = None
    try:
        # Retained beneath output for Root inspection; never reads the live repo.
        workspace = Path(tempfile.mkdtemp(prefix="workspace-", dir=output))
        record["workspace"] = str(workspace)
        for name, row in regular_expected.items():
            source = regular_beneath(args.snapshot_root, prefix + "/" + name)
            target = workspace / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            target.chmod(row["mode"])
        link_path = workspace / KNOWN_LINK
        link_path.symlink_to(KNOWN_TARGET)
        before = inventory(workspace, allow_known_link=True)
        if before != dict(sorted(expected.items())):
            raise ValueError("copied payload bytes/modes differ")
        save(output / "source-before.json", before)
        git("git-init", ["init", "--template=", "-q", "."], workspace)
        for key, value in (("gc.auto", "0"), ("maintenance.auto", "false"),
                           ("core.autocrlf", "false"),
                           ("core.fsmonitor", "false"), ("commit.gpgSign", "false")):
            git("git-config-" + key, ["config", "--local", key, value], workspace)
        git("git-add", ["add", "--all", "--force", "--", "."], workspace)
        git("git-commit", ["-c", "user.name=T008 Fixture", "-c",
                          "user.email=t008-fixture@example.invalid", "commit",
                          "-qm", "Exact admitted legacy runtime"], workspace)
        record["head"] = git("git-head", ["rev-parse", "HEAD"], workspace).decode().strip()
        record["tree"] = git("git-tree", ["rev-parse", "HEAD^{tree}"], workspace).decode().strip()
        archive = run("git-archive", [args.git, "archive", "--format=tar", "HEAD"], workspace)
        if archive["timed_out"] or archive["exit_code"] != 0:
            raise RuntimeError("fixture archive failed")
        record["archive_sha256"] = archive["stdout_sha256"]
        for label, command in (
                ("legacy-bash", [args.bash, "tests/install.tests.sh"]),
                ("legacy-powershell", [args.pwsh, "-NoProfile", "-File", "tests/install.tests.ps1"])):
            row = run(label, command, workspace, args.test_timeout_seconds)
            if row["timed_out"]:
                # Do not start another heavy job while outer-owned descendants may remain.
                break
        tests = [row for row in results if row["label"].startswith("legacy-")]
        record["test_commands_passed"] = (len(tests) == 2 and all(
            row["exit_code"] == 0 and not row["timed_out"] for row in tests))
    except Exception as error:
        record["controller_error"] = {"type": type(error).__name__, "message": str(error)}
    finally:
        if workspace is not None:
            try:
                after = inventory(workspace, exclude_git=True, allow_known_link=True)
                save(output / "source-after.json", after)
                record["workspace_sources_unchanged"] = after == dict(sorted(expected.items()))
            except Exception as error:
                record["workspace_sources_unchanged"] = False
                record["source_after_error"] = type(error).__name__
        changed = []
        admitted_after = {}
        for name in pins:
            try:
                path = regular_beneath(args.snapshot_root, name)
                actual = {"sha256": digest(path), "mode": stat.S_IMODE(path.stat().st_mode)}
                admitted_after[name] = actual
                unchanged = actual == admitted_before[name]
            except (OSError, ValueError):
                unchanged = False
                admitted_after[name] = {"error": "missing, aliased or unreadable input"}
            if not unchanged:
                changed.append(name)
        save(output / "admitted-after.json", admitted_after)
        record["admitted_inputs_unchanged"] = not changed
        record["changed_admitted_inputs"] = changed
        try:
            record["parent_manifest_unchanged"] = digest(args.parent_manifest) == args.parent_manifest_sha256
        except OSError:
            record["parent_manifest_unchanged"] = False
        record["finished_at_epoch"] = time.time()
        record["passed"] = bool(record.get("test_commands_passed")
                                and record.get("workspace_sources_unchanged")
                                and record["admitted_inputs_unchanged"]
                                and record["parent_manifest_unchanged"]
                                and "controller_error" not in record)
        save(output / "results.json", record)
    print(json.dumps({"results": str(output / "results.json"), "passed": record["passed"]}))
    return 0 if record["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
