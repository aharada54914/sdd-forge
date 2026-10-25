#!/usr/bin/env python3
"""Explicit project skill sealing, isolated trials, maintenance and host projection.

Temporary directories isolate run data, not hostile code. Project entrypoints are
trusted executable input; this tool is not an OS sandbox or an approval issuer.
"""

import argparse
import datetime
import importlib.util
import json
import math
import re
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "project_skill_validator",
    HERE.parents[1] / "sdd-quality-loop/scripts/validate-project-skill.py",
)
V = importlib.util.module_from_spec(spec)
spec.loader.exec_module(V)


def save(path, value, exclusive=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x" if exclusive else "w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def seal(root, name, runtime, entry, checks, requires):
    directory = V.safe(root, "sdd/skills/" + V.relative(name))
    if not directory.is_dir():
        raise ValueError("skill-directory-missing")
    target = directory / "skill-manifest.json"
    if target.exists():
        raise ValueError(
            "manifest-exists; review changes and explicitly remove the old manifest before resealing"
        )
    files = V.files_under(root, "sdd/skills/" + name, "closure-escape")
    prefix = "sdd/skills/" + name + "/"
    manifest = {
        "schema": "project-skill-manifest/v1",
        "name": name,
        "checks": checks,
        "runtime": runtime,
        "entry": entry,
        "args": [],
        "requires": requires,
        "files": [
            {"path": path[len(prefix) :], "sha256": sha}
            for path, sha in sorted(files.items())
        ],
    }
    V.schema(manifest, "project-skill-manifest.schema.json", "manifest-invalid")
    if entry not in [f["path"] for f in manifest["files"]]:
        raise ValueError("entry-not-in-closure")
    save(target, manifest, exclusive=True)
    try:
        V.validate(root, name)
    except Exception:
        target.unlink()
        raise
    return {
        "status": "draft",
        "manifest": target.relative_to(root).as_posix(),
        "reason": "generation-is-not-validation",
    }


def execute(argv, cwd, timeout, limit):
    """Bound capture; the dedicated Linux subreaper owns detached descendants."""
    validate_limits(timeout, limit)
    if sys.platform != "linux":
        return None, b"", b"", "platform-process-ownership-unverified", False
    read_fd, write_fd = os.pipe()
    try:
        process = subprocess.Popen(
            [
                sys.executable,
                str(HERE / "project-skill-process.py"),
                "--status-fd",
                str(write_fd),
                "--timeout",
                str(timeout),
                "--",
                *argv,
            ],
            cwd=cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
            pass_fds=(write_fd,),
        )
    finally:
        os.close(write_fd)
    data = [bytearray(), bytearray()]
    overflow = threading.Event()

    def drain(stream, index):
        while True:
            chunk = stream.read(4096)
            if not chunk:
                return
            remaining = limit - len(data[index])
            data[index].extend(chunk[: max(0, remaining)])
            if len(chunk) > remaining:
                overflow.set()

    threads = [
        threading.Thread(target=drain, args=(stream, i), daemon=True)
        for i, stream in enumerate((process.stdout, process.stderr))
    ]
    for thread in threads:
        thread.start()
    cancelled = False
    deadline = time.monotonic() + timeout + 7
    while process.poll() is None:
        if overflow.is_set() and not cancelled:
            process.terminate()
            cancelled = True
        if time.monotonic() >= deadline:
            process.kill()
            break
        time.sleep(0.01)
    process.wait()
    for thread in threads:
        thread.join(timeout=1)
    process.stdout.close()
    process.stderr.close()
    metadata = os.read(read_fd, 4096)
    os.close(read_fd)
    try:
        status = json.loads(metadata)
    except (ValueError, UnicodeError):
        status = {
            "cleanup": False,
            "reason": "process-owner-status-missing",
            "exit_code": 125,
        }
    reason = "output-limit" if overflow.is_set() else status.get("reason")
    cleanup = status.get("cleanup") is True
    code = (
        125 if reason == "output-limit" or not cleanup else status.get("exit_code", 125)
    )
    return code, bytes(data[0]), bytes(data[1]), reason, cleanup


def validate_limits(timeout, output_limit):
    if (
        isinstance(timeout, bool)
        or not isinstance(timeout, (int, float))
        or not math.isfinite(timeout)
        or not 0 < timeout <= 3600
    ):
        raise ValueError("timeout must be finite and between 0 and 3600 seconds")
    if (
        isinstance(output_limit, bool)
        or not isinstance(output_limit, int)
        or not 0 < output_limit <= 16 * 1024 * 1024
    ):
        raise ValueError("output limit must be an integer between 1 and 16777216")


def run(root, name, check, timeout=30, inputs=(), task_path=None, output_limit=1048576):
    validate_limits(timeout, output_limit)
    manifest, _unused, _state = V.validate(root, name)
    if check not in manifest["checks"]:
        raise ValueError("check-not-declared")
    raw_manifest = (root / "sdd/skills" / name / "skill-manifest.json").read_bytes()
    closure = V.files_under(root, "sdd/skills/" + name, "closure-escape")
    task, task_raw = V.load(task_path, "input-unbound") if task_path else (None, None)
    if task:
        V.schema(task, "task-input-manifest.schema.json", "input-unbound")
        admitted = {p["path"]: p["sha256"] for p in task["allowed_inputs"]}
        if inputs:
            raise ValueError("task-inputs-owned-by-manifest")
    else:
        admitted = dict(closure)
        for path in inputs:
            source = V.safe(root, path, "input-unbound", missing=False)
            if not source.is_file():
                raise ValueError("trial-input-must-be-file")
            admitted[path] = V.digest(source.read_bytes())
    runtime = shutil.which(manifest["runtime"])
    missing = ([] if runtime else ["runtime"]) + [
        p for p in manifest["requires"] if shutil.which(p) is None
    ]
    observation = {
        "schema": "project-verification-observation/v1",
        "mode": "task" if task else "trial",
        "skill": name,
        "check_id": check,
        "skill_manifest_sha256": V.digest(raw_manifest),
        "source": {"commit": None, "tree_sha256": "0" * 64},
        "environment": {
            "os": {"linux": "linux", "darwin": "darwin", "win32": "windows"}.get(
                sys.platform, "linux"
            ),
            "host": "project-skill-local-runner",
            "runtime_path": runtime,
            "missing": missing,
        },
        "outcome": "unavailable" if missing else "not-run",
    }
    if task:
        observation.update(
            task_id=task["task_id"],
            run_id=task["run_id"],
            task_input_manifest_sha256=V.digest(task_raw),
        )
    relative = V.observation_relative(observation)
    if task:
        evidence_dir = relative.rsplit("/", 1)[0] + "/"
        if not any(
            output.endswith("/") and evidence_dir.startswith(output)
            for output in task["allowed_outputs"]
        ):
            raise ValueError("runner-evidence-directory-unbound")
        for output in task["allowed_outputs"]:
            if any(
                not path.startswith(evidence_dir)
                for path in V.files_under(root, output, "source-mismatch")
            ):
                raise ValueError("runner-output-not-empty")
    destination = V.safe(root, relative, "observation-invalid")
    if task and destination.exists():
        raise ValueError("task-evidence-immutable")
    before = time.monotonic()
    result = {
        "schema": "project-skill-trial/v1",
        "skill": name,
        "check_id": check,
        "inputs": admitted,
        "isolation": "temporary-data-directory; not an OS sandbox",
        "reason": None,
        "observed_outputs": {},
        "observation": relative,
        "cleanup": False,
    }
    stdout = stderr = b""
    process_cleanup = bool(missing)
    failure = None
    try:
        with tempfile.TemporaryDirectory(prefix="sdd-project-skill-") as temporary:
            execution = Path(temporary)
            for path, sha in admitted.items():
                source = V.safe(root, path, "input-unbound", missing=False)
                if not source.is_file() or V.digest(source.read_bytes()) != sha:
                    raise ValueError("input-unbound")
                target = V.safe(execution, path, "input-unbound")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read_bytes())
            _m, _raw, skill_closure = V.discover(execution, name, task)
            # Validate admission/output boundaries before executing any command.
            if task:
                V.source_records(execution, manifest, task, observation, skill_closure)
            if not missing:
                started = datetime.datetime.now(datetime.timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                )
                code, stdout, stderr, reason, process_cleanup = execute(
                    [
                        runtime,
                        "sdd/skills/" + name + "/" + manifest["entry"],
                        *manifest["args"],
                    ],
                    execution,
                    timeout,
                    output_limit,
                )
                result["reason"] = reason
                if code is not None:
                    observation.update(
                        outcome="passed" if code == 0 else "failed",
                        exit_code=code,
                        started_at=started,
                        finished_at=datetime.datetime.now(
                            datetime.timezone.utc
                        ).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    )
                else:
                    observation["environment"]["runtime_path"] = None
            after = V.files_under(execution, "sdd", "source-mismatch")
            for path in execution.iterdir():
                if path.name != "sdd":
                    after.update(V.files_under(execution, path.name, "source-mismatch"))
            changed = {
                path: sha for path, sha in after.items() if admitted.get(path) != sha
            }
            removed = set(admitted) - set(after)
            violation = (
                "runner-modified-input"
                if removed
                or any(after.get(path) != sha for path, sha in admitted.items())
                else None
            )
            if task and any(
                not any(V.covers(output, path) for output in task["allowed_outputs"])
                for path in changed
            ):
                violation = "runner-output-unbound"
            if violation:
                result["reason"] = violation
                observation.update(outcome="failed", exit_code=126)
            result["observed_outputs"] = changed
            observation["source"]["tree_sha256"] = V.tree_digest(
                V.source_records(
                    root if violation else execution,
                    manifest,
                    task,
                    observation,
                    skill_closure,
                )
            )
            # Publish only owned declared task outputs, and never overwrite caller files.
            if task and not violation:
                for path in changed:
                    target = V.safe(root, path, "source-mismatch")
                    if target.exists():
                        raise ValueError("publication-conflict")
                for path in changed:
                    target = V.safe(root, path, "source-mismatch")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with target.open("xb") as output:
                        output.write((execution / path).read_bytes())
    except (ValueError, OSError) as exc:
        failure = str(exc)
        result["reason"] = failure
        observation["outcome"] = "failed"
    result.update(
        cleanup=process_cleanup,
        directory_cleanup=True,
        seconds=time.monotonic() - before,
        outcome=observation["outcome"],
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    log_stem = destination.parent / (check + "-" + uuid.uuid4().hex)
    for suffix, data in [(".stdout", stdout), (".stderr", stderr)]:
        path = log_stem.with_suffix(suffix)
        with path.open("xb") as output:
            output.write(data)
        result[suffix[1:]] = {
            "path": path.relative_to(root).as_posix(),
            "sha256": V.digest(data),
        }
    if failure is None:
        save(destination, observation, exclusive=bool(task))
        V.validate(root, name, destination, task_path)
    result["observation_written"] = failure is None
    save(log_stem.with_suffix(".receipt.json"), result, exclusive=True)
    result["receipt"] = (
        log_stem.with_suffix(".receipt.json").relative_to(root).as_posix()
    )
    return result


def maintain(root, name, baseline, timeout):
    old, _ = V.load(baseline, "baseline-invalid")
    manifest, _, _ = V.validate(root, name)
    if (
        not isinstance(old, dict)
        or old.get("schema") != "project-skill-trial/v1"
        or old.get("skill") != name
        or old.get("check_id") not in manifest["checks"]
        or not isinstance(old.get("inputs"), dict)
    ):
        raise ValueError("baseline-identity-invalid")
    for path, sha in old["inputs"].items():
        V.relative(path, "baseline-input-invalid")
        if not isinstance(sha, str) or not re.fullmatch("[0-9a-f]{64}", sha):
            raise ValueError("baseline-input-invalid")
    feature_dir = root / "sdd/skills" / name / "features"
    if feature_dir.exists():
        feature_files = sorted(
            p.name for p in feature_dir.glob("*.md") if p.name != "README.md"
        )
        index = feature_dir / "README.md"
        indexed = (
            set(re.findall(r"\]\(([^)]+\.md)\)", index.read_text(encoding="utf-8")))
            if index.is_file()
            else set()
        )
        missing = [path for path in feature_files if path not in indexed]
        dangling = sorted(indexed - set(feature_files))
        unmapped = []
        for path in feature_files:
            matches = re.findall(
                r"^Check ID:[ \t]*([a-z0-9][a-z0-9-]*)[ \t]*$",
                (feature_dir / path).read_text(encoding="utf-8"),
                re.M,
            )
            if len(matches) != 1 or matches[0] not in manifest["checks"]:
                unmapped.append(path)
        if missing or dangling or unmapped:
            return {
                "status": "blocked",
                "classification": "harness-gap",
                "missing_index": missing,
                "dangling_index": dangling,
                "unmapped_features": unmapped,
                "results": [],
                "unexecuted": feature_files,
            }
    results = [
        run(
            root,
            name,
            check,
            timeout,
            inputs=[
                p for p in old["inputs"] if not p.startswith("sdd/skills/" + name + "/")
            ],
        )
        for check in manifest["checks"]
    ]
    changed = any(result["inputs"] != old["inputs"] for result in results)
    blocked = any(result["outcome"] != "passed" for result in results)
    return {
        "status": "blocked" if blocked else "changed" if changed else "clean",
        "classification": "environment-unavailable"
        if any(r["outcome"] in ("unavailable", "not-run") for r in results)
        else "product-regression-or-harness-gap"
        if blocked
        else "source-drift"
        if changed
        else "none",
        "results": results,
        "unexecuted": [],
    }


def project(root, name, host, check=False):
    V.validate(root, name)
    canonical = V.safe(
        root, "sdd/skills/" + name + "/SKILL.md", "closure-escape", missing=False
    )
    text = canonical.read_text(encoding="utf-8")
    frontmatter = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", text, re.S)
    if not frontmatter:
        raise ValueError("skill-frontmatter-missing")
    header = frontmatter.group(1)
    # The projection accepts a bounded plain-key dialect rather than silently
    # interpreting YAML aliases, quoted keys or merge precedence differently.
    if re.search(r"^[ \t]*[\"'][^\n]*[\"'][ \t]*:", header, re.M) or re.search(
        r"^[ \t]*<<[ \t]*:", header, re.M
    ):
        raise ValueError("skill-frontmatter-key-dialect-unsupported")
    for line in header.splitlines():
        if line and not line[0].isspace() and not line.startswith("#"):
            if not re.match(r"^[A-Za-z][A-Za-z0-9_-]*[ \t]*:", line):
                raise ValueError("skill-frontmatter-key-dialect-unsupported")
    names = re.findall(r"^name[ \t]*:[ \t]*(.*)$", header, re.M)
    if len(names) != 1:
        raise ValueError("skill-frontmatter-name-invalid")
    declared_name = names[0].split("#", 1)[0].strip()
    if (
        len(declared_name) >= 2
        and declared_name[0] == declared_name[-1]
        and declared_name[0] in "\"'"
    ):
        declared_name = declared_name[1:-1]
    if declared_name != name:
        raise ValueError("skill-frontmatter-name-mismatch")
    flags = {}
    for key in ("user-invocable", "disable-model-invocation"):
        values = re.findall(r"^\s*" + key + r"\s*:\s*([^\n]*)$", header, re.M)
        if len(values) > 1:
            raise ValueError("skill-frontmatter-duplicate")
        if values:
            value = values[0].split("#", 1)[0].strip()
            if value not in ("true", "false"):
                raise ValueError("skill-invocation-flag-invalid")
            flags[key] = value == "true"
    if (
        flags.get("user-invocable") is False
        and flags.get("disable-model-invocation") is True
    ):
        raise ValueError("skill-unreachable")
    if host != "claude" and (
        flags.get("user-invocable") is False
        or flags.get("disable-model-invocation") is True
        or re.search(
            r"^\s*(allowed-tools|model|effort|context|agent)\s*:", header, re.M
        )
    ):
        raise ValueError("host-required-controls-unverified")
    directory = {"claude": ".claude", "codex": ".agents", "copilot": ".github"}[host]
    relative = directory + "/skills/" + name + "/SKILL.md"
    target = V.safe(root, relative, "projection-conflict")
    content = (
        "---\n"
        + header
        + "\n---\n\nRead and follow [the canonical project skill](../../../sdd/skills/"
        + name
        + "/SKILL.md).\nKeep its prerequisites, allowed effects, observations and cleanup unchanged.\n"
    ).encode()
    ledger_path = V.safe(root, "sdd/skill-projections.json", "projection-conflict")
    ledger = (
        V.load(ledger_path, "projection-ledger-invalid")[0]
        if ledger_path.exists()
        else {"schema": "project-skill-projections/v1", "files": {}}
    )
    if (
        not isinstance(ledger, dict)
        or set(ledger) != {"schema", "files"}
        or ledger.get("schema") != "project-skill-projections/v1"
        or not isinstance(ledger.get("files"), dict)
    ):
        raise ValueError("projection-ledger-invalid")
    for path, sha in ledger["files"].items():
        V.relative(path, "projection-ledger-invalid")
        if not isinstance(sha, str) or not re.fullmatch("[0-9a-f]{64}", sha):
            raise ValueError("projection-ledger-invalid")
    if target.exists() and target.read_bytes() != content:
        if ledger["files"].get(relative) != V.digest(target.read_bytes()):
            raise ValueError("projection-user-edit-conflict")
    if check:
        if not target.is_file() or target.read_bytes() != content:
            raise ValueError("projection-drift")
        if ledger["files"].get(relative) != V.digest(content):
            raise ValueError("projection-ledger-drift")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        ledger["files"][relative] = V.digest(content)
        save(ledger_path, ledger)
    return {
        "status": "checked" if check else "generated",
        "path": relative,
        "native_host_verification": "unverified",
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("seal", "run", "maintain", "project"):
        p = sub.add_parser(command)
        p.add_argument("--root", required=True, type=Path)
        p.add_argument("--name", required=True)
        if command == "seal":
            p.add_argument("--runtime", required=True)
            p.add_argument("--entry", required=True)
            p.add_argument("--check", action="append", required=True)
            p.add_argument("--requires", action="append", default=[])
        elif command == "run":
            p.add_argument("--check", required=True)
            p.add_argument("--timeout", type=float, default=30)
            p.add_argument("--input", action="append", default=[])
            p.add_argument("--task-input-manifest", type=Path)
        elif command == "maintain":
            p.add_argument("--baseline", required=True, type=Path)
            p.add_argument("--timeout", type=float, default=30)
        else:
            p.add_argument(
                "--host", choices=["claude", "codex", "copilot"], required=True
            )
            p.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    if hasattr(args, "timeout") and (not 0 < args.timeout <= 3600):
        parser.error("--timeout must be between 0 and 3600 seconds")
    try:
        root = args.root.absolute()
        if args.command == "seal":
            result = seal(
                root, args.name, args.runtime, args.entry, args.check, args.requires
            )
        elif args.command == "run":
            result = run(
                root,
                args.name,
                args.check,
                args.timeout,
                args.input,
                args.task_input_manifest,
            )
        elif args.command == "maintain":
            result = maintain(root, args.name, args.baseline, args.timeout)
        else:
            result = project(root, args.name, args.host, args.check)
        print(json.dumps(result, sort_keys=True))
        return (
            1
            if result.get("outcome") in ("failed", "unavailable", "not-run")
            or result.get("status") == "blocked"
            else 0
        )
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "blocked", "reason": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
