#!/usr/bin/env python3
"""Passive identity/consistency checks; VALID is not execution or approval proof."""

import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import stat
import sys

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(
    "project_skill_schema", HERE / "validate-facet-manifest.py"
)
_schema = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_schema)
LOADED_SOURCES = {str(Path(path).resolve()): hashlib.sha256(Path(path).read_bytes()).hexdigest()
                  for path in (__file__, _schema.__file__)}
EVIDENCE = "reports/project-skill-observations/"
MAX_JSON_BYTES = 8 * 1024 * 1024
EXECUTION = ("command", "started_at", "finished_at", "exit_code", "passes", "evidence")


class Invalid(ValueError):
    pass


def fail(code):
    raise Invalid(code)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def execution_environment():
    # These are shell bookkeeping, not caller inputs; also remove them at execution.
    return {key: value for key, value in os.environ.items()
            if key not in ("_", "SHLVL", "PWD", "OLDPWD")}


def runtime_environment(manifest):
    """Fingerprint declared executables and inherited variables without executing tools."""
    tools = []
    declared = [(name, shutil.which(name)) for name in [manifest["runtime"], *manifest["requires"]]]
    bootstrap = HERE.parents[1] / "sdd-bootstrap/scripts"
    declared.extend((name, str(path)) for name, path in (
        ("@runner-python", sys.executable), ("@validator", Path(__file__)),
        ("@schema-validator", Path(_schema.__file__)),
        ("@runner", bootstrap / "project-skill.py"),
        ("@supervisor", bootstrap / "project-skill-process.py")))
    for name, path in declared:
        item = {"name": name, "path": path, "sha256": None, "identity_sha256": None}
        if path:
            try:
                with Path(path).open("rb") as stream:
                    before = os.fstat(stream.fileno())
                    if not stat.S_ISREG(before.st_mode):
                        fail("runtime-changed")
                    hasher = hashlib.sha256()
                    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                        hasher.update(chunk)
                    sha = hasher.hexdigest()
                    after = os.fstat(stream.fileno())
                def identity(info):
                    return (info.st_dev, info.st_ino, info.st_mode, info.st_size,
                            info.st_mtime_ns, info.st_ctime_ns)
                if identity(before) != identity(after) or identity(after) != identity(Path(path).stat()):
                    fail("runtime-changed")
                item.update(sha256=sha, identity_sha256=digest(json.dumps(identity(after)).encode()))
                loaded = LOADED_SOURCES.get(str(Path(path).resolve()))
                if loaded is not None and loaded != sha:
                    fail("runtime-changed")
            except OSError:
                fail("runtime-changed")
        tools.append(item)
    return {"runtime_path": tools[0]["path"], "toolchain": tools,
            "variables_sha256": digest(json.dumps(execution_environment(), sort_keys=True).encode())}


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate member")
        result[key] = value
    return result


def load(path, code):
    try:
        path = Path(path)
        if (
            path.is_symlink()
            or not path.is_file()
            or path.stat().st_size > MAX_JSON_BYTES
        ):
            fail(code)
        with path.open("rb") as stream:
            raw = stream.read(MAX_JSON_BYTES + 1)
        if len(raw) > MAX_JSON_BYTES:
            fail(code)
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=_pairs,
            parse_constant=lambda _: fail(code),
        )
        return value, raw
    except (OSError, ValueError):
        fail(code)


def schema(value, filename, code):
    source = HERE.parent / "contracts" / filename
    if not source.is_file():
        source = HERE.parents[2] / "contracts" / filename
    definition, _ = load(source, code)
    if _schema.validate_against_schema(value, definition):
        fail(code)
    # The shared helper predates allOf. Task-input-manifest uses it for fallback admission.
    for clause in definition.get("allOf", []):
        if _schema._schema_matches(value, clause.get("if", True), definition):
            diagnostics = []
            _schema._validate(
                value, clause.get("then", True), definition, "", diagnostics
            )
            if diagnostics:
                fail(code)


def relative(value, code="closure-escape"):
    if (
        not isinstance(value, str)
        or not value
        or "\\" in value
        or "\x00" in value
        or ":" in value
    ):
        fail(code)
    if any(part in ("", ".", "..") for part in value.split("/")):
        fail(code)
    return value


def safe(root, value, code="closure-escape", missing=True):
    relative(value, code)
    current = root
    for part in value.split("/"):
        current = current / part
        try:
            mode = current.lstat().st_mode
        except FileNotFoundError:
            if missing:
                continue
            fail(code)
        if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
            fail(code)
    return current


def files_under(root, prefix, code):
    path = safe(root, prefix.rstrip("/"), code)
    if not path.exists():
        return {}
    if path.is_file():
        if prefix.endswith("/"):
            fail(code)
        return {prefix: digest(path.read_bytes())}
    result = {}
    for directory, dirs, files in os.walk(path, followlinks=False):
        for name in dirs + files:
            child = Path(directory) / name
            mode = child.lstat().st_mode
            if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
                fail(code)
            if stat.S_ISREG(mode):
                result[child.relative_to(root).as_posix()] = digest(child.read_bytes())
    return result


def tree_digest(records):
    return digest(
        b"".join(
            path.encode("utf-8") + b"\0" + records[path].encode("ascii") + b"\n"
            for path in sorted(records, key=lambda x: x.encode("utf-8"))
        )
    )


def covers(output, path):
    return path == output or (output.endswith("/") and path.startswith(output))


def discover(root, skill, task=None):
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,62}", skill):
        fail("manifest-invalid")
    base = safe(root, "sdd/skills")
    if not base.is_dir():
        fail("manifest-missing")
    if task is None:
        names = [p.name for p in sorted(base.iterdir())]
    else:
        names = sorted(
            {
                p["path"].split("/")[2]
                for p in task.get("allowed_inputs", [])
                if re.fullmatch(
                    r"sdd/skills/[^/]+/skill-manifest.json", p.get("path", "")
                )
            }
        )
    if skill not in names:
        fail("manifest-missing")
    manifests = {}
    for name in names:
        path = safe(root, "sdd/skills/" + name + "/skill-manifest.json")
        if not path.is_file():
            fail("manifest-missing")
        value, raw = load(path, "manifest-invalid")
        schema(value, "project-skill-manifest.schema.json", "manifest-invalid")
        if any(".." in arg for arg in value["args"]):
            fail("manifest-invalid")
        manifests[name] = value, raw
    if any(value["name"] != name for name, (value, _) in manifests.items()):
        fail("name-mismatch")
    checks = [check for value, _ in manifests.values() for check in value["checks"]]
    if len(set(checks)) != len(checks):
        fail("check-collision")
    manifest, raw = manifests[skill]
    prefix = "sdd/skills/" + skill + "/"
    paths = [entry["path"] for entry in manifest["files"]]
    if paths != sorted(set(paths), key=lambda p: p.encode("utf-8")):
        fail("manifest-invalid")
    for path in paths:
        safe(root, prefix + relative(path))
    if manifest["entry"] not in paths or "skill-manifest.json" in paths:
        fail("closure-escape")
    actual = files_under(root, prefix.rstrip("/"), "closure-escape")
    actual.pop(prefix + "skill-manifest.json", None)
    listed = {prefix + entry["path"]: entry["sha256"] for entry in manifest["files"]}
    if listed.keys() - actual.keys():
        fail("closure-missing")
    if actual.keys() - listed.keys():
        fail("closure-incomplete")
    if actual != listed:
        fail("digest-mismatch")
    return manifest, raw, actual


def source_records(root, manifest, task, observation, closure):
    if task is None:
        return closure
    schema(task, "task-input-manifest.schema.json", "input-unbound")
    inputs = task["allowed_inputs"]
    outputs = task["allowed_outputs"]
    paths = [p["path"] for p in inputs]
    if len(set(paths)) != len(paths):
        fail("input-unbound")
    expected = observation_relative(observation)
    if not any(covers(output, expected) for output in outputs):
        fail("input-unbound")
    for output in outputs:
        relative(output.rstrip("/"), "input-unbound")
    required = set(closure) | {
        "sdd/skills/" + manifest["name"] + "/skill-manifest.json"
    }
    if not required.issubset(paths):
        fail("input-unbound")
    result = {}
    for item in inputs:
        path = item["path"]
        if path.startswith(EVIDENCE) or any(covers(o, path) for o in outputs):
            fail("input-unbound")
        file = safe(root, path, "input-unbound", missing=False)
        if not file.is_file() or digest(file.read_bytes()) != item["sha256"]:
            fail("input-unbound")
        result[path] = item["sha256"]
    excluded = EVIDENCE + observation["task_id"] + "/" + observation["run_id"] + "/"
    for output in outputs:
        for path, sha in files_under(root, output, "source-mismatch").items():
            if not path.startswith(excluded):
                result[path] = sha
    return result


def observation_relative(obs):
    if obs["mode"] == "trial":
        return EVIDENCE + "trial/" + obs["skill"] + "/" + obs["check_id"] + ".json"
    return (
        EVIDENCE
        + obs["task_id"]
        + "/"
        + obs["run_id"]
        + "/"
        + obs["check_id"]
        + ".json"
    )


def _validate(root, skill, observation_path=None, task_input_path=None):
    root = Path(root).absolute()
    if root.is_symlink() or not root.is_dir():
        fail("closure-escape")
    task, task_raw = (
        load(task_input_path, "input-unbound") if task_input_path else (None, None)
    )
    if task is not None:
        schema(task, "task-input-manifest.schema.json", "input-unbound")
    manifest, raw, closure = discover(root, skill, task)
    if observation_path is None:
        return manifest, None, "manifest-only"
    try:
        candidate = Path(observation_path).absolute().relative_to(root).as_posix()
    except ValueError:
        fail("observation-invalid")
    safe(root, candidate, "observation-invalid", missing=False)
    obs, _ = load(observation_path, "observation-invalid")
    schema(obs, "project-verification-observation.schema.json", "observation-invalid")
    task_fields = {"task_id", "run_id", "task_input_manifest_sha256"}
    run_fields = {"started_at", "finished_at", "exit_code"}
    ran = obs["outcome"] in ("passed", "failed")
    if (task_fields & obs.keys()) != (task_fields if obs["mode"] == "task" else set()):
        fail("observation-invalid")
    if (run_fields & obs.keys()) != (run_fields if ran else set()):
        fail("observation-invalid")
    if ran:
        try:
            dates = [
                datetime.datetime.strptime(obs[k], "%Y-%m-%dT%H:%M:%SZ")
                for k in ("started_at", "finished_at")
            ]
        except ValueError:
            fail("observation-invalid")
        if dates[0] > dates[1] or (
            (obs["exit_code"] == 0) != (obs["outcome"] == "passed")
        ):
            fail("observation-invalid")
    env = obs["environment"]
    if bool(env["missing"]) != (obs["outcome"] == "unavailable"):
        fail("observation-invalid")
    if not set(env["missing"]).issubset(set(manifest["requires"]) | {"runtime"}):
        fail("observation-invalid")
    must_null = "runtime" in env["missing"] or obs["outcome"] == "not-run"
    if (env["runtime_path"] is None) != must_null:
        fail("observation-invalid")
    expected = safe(root, observation_relative(obs), "observation-invalid")
    if Path(observation_path).absolute() != expected:
        fail("observation-invalid")
    if obs["skill"] != skill or obs["check_id"] not in manifest["checks"]:
        fail("skill-mismatch")
    if obs["skill_manifest_sha256"] != digest(raw):
        fail("manifest-digest-mismatch")
    if (obs["mode"] == "task") != (task is not None):
        fail("input-required")
    if task is not None and obs["task_input_manifest_sha256"] != digest(task_raw):
        fail("input-unbound")
    if task is not None and any(obs[k] != task[k] for k in ("task_id", "run_id")):
        fail("run-mismatch")
    records = source_records(root, manifest, task, obs, closure)
    if tree_digest(records) != obs["source"]["tree_sha256"]:
        fail("source-mismatch")
    if ran:
        # Old records remain inspectable history, but cannot supply fresh execution fields.
        if obs["schema"] == "project-verification-observation/v1":
            return manifest, obs, "legacy-runtime-unbound"
        current = runtime_environment(manifest)
        if any(env.get(key) != value for key, value in current.items()):
            fail("runtime-changed")
    return manifest, obs, ("trial-" if obs["mode"] == "trial" else "") + obs["outcome"]


def validate(root, skill, observation_path=None, task_input_path=None):
    try:
        return _validate(root, skill, observation_path, task_input_path)
    except Invalid:
        raise
    except (OSError, ValueError, TypeError, KeyError):
        fail("manifest-invalid")


def project_execution(check, validated):
    """Only execution fields change; callers still own admission and final verdict."""
    result = {k: v for k, v in check.items() if k not in EXECUTION}
    if validated is None:
        return result
    manifest, obs, state = validated
    if state not in ("passed", "failed") or obs["check_id"] != check["id"]:
        return result
    result.update(
        command=json.dumps(
            [
                manifest["runtime"],
                "sdd/skills/" + manifest["name"] + "/" + manifest["entry"],
                *manifest["args"],
            ],
            separators=(",", ":"),
        ),
        started_at=obs["started_at"],
        finished_at=obs["finished_at"],
        exit_code=obs["exit_code"],
        passes=state == "passed",
        evidence=observation_relative(obs),
    )
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(prog="validate-project-skill")
    parser.add_argument("--execution-root", required=True)
    parser.add_argument("--skill", required=True)
    parser.add_argument("--observation")
    parser.add_argument("--task-input-manifest")
    args = parser.parse_args(argv)
    if args.task_input_manifest and not args.observation:
        parser.error("--task-input-manifest requires --observation")
    try:
        _, _, state = validate(
            args.execution_root, args.skill, args.observation, args.task_input_manifest
        )
    except (Invalid, OSError) as exc:
        print(
            "project-skill: INVALID: "
            + (str(exc) if isinstance(exc, Invalid) else "manifest-invalid"),
            file=sys.stderr,
        )
        return 1
    print("project-skill: VALID " + args.skill + " " + state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
