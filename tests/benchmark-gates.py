#!/usr/bin/env python3
"""Manual frozen-input gate benchmark; never a CI timing threshold or verdict cache."""

import argparse
from contextlib import ExitStack, contextmanager, nullcontext
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location(
    "run_measurement", ROOT / "plugins/sdd-quality-loop/scripts/run_measurement.py"
)
M = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(M)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(root, *args):
    result = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, check=False
    )
    if result.returncode:
        raise ValueError("git input unavailable")
    return result.stdout


def relative(value):
    if (
        not isinstance(value, str)
        or not value
        or "\\" in value
        or ":" in value
        or any(p in ("", ".", "..", ".git") for p in value.split("/"))
    ):
        raise ValueError("invalid relative benchmark path")
    return value


def covered(path, prefixes):
    return any(path == prefix or path.startswith(prefix + "/") for prefix in prefixes)


def validate_manifest(root, manifest, revision):
    required = {
        "schema",
        "baseline_head",
        "code_paths",
        "inputs",
        "trials",
        "pinned",
        "skill_source",
        "recipes",
        "lifecycles",
        "temperatures",
        "primary",
        "compare_cases",
        "repeat_count",
    }
    if (
        not isinstance(manifest, dict)
        or set(manifest) != required
        or manifest["schema"] != "sdd-gate-benchmark/v1"
        or type(manifest["trials"]) is not int
        or manifest["trials"] != 5
    ):
        raise ValueError("invalid benchmark manifest")
    baseline = (
        git(root, "rev-parse", manifest["baseline_head"] + "^{commit}").decode().strip()
    )
    candidate = git(root, "rev-parse", revision + "^{commit}").decode().strip()
    paths = manifest["code_paths"]
    if not isinstance(paths, list) or not paths or any(relative(p) != p for p in paths):
        raise ValueError("invalid code paths")
    if type(manifest["repeat_count"]) is not int or manifest["repeat_count"] < 0:
        raise ValueError("invalid repeat count")
    if not isinstance(manifest["pinned"], dict) or set(manifest["pinned"]) != {
        "feature",
        "task_id",
        "risk",
        "contract",
    }:
        raise ValueError("missing task pin")
    if not isinstance(manifest["inputs"], list) or not manifest["inputs"]:
        raise ValueError("missing input pins")
    pins = manifest["inputs"] + [manifest["skill_source"]]
    for item in pins:
        if not isinstance(item, dict) or set(item) != {"path", "sha256"}:
            raise ValueError("invalid input pin")
        path = relative(item["path"])
        if covered(path, paths) or any(covered(code, [path]) for code in paths):
            raise ValueError("code overlaps frozen input")
        if sha(git(root, "show", baseline + ":" + path)) != item["sha256"]:
            raise ValueError("frozen input mismatch")
        if (
            item in manifest["inputs"]
            and sha(git(root, "show", candidate + ":" + path)) != item["sha256"]
        ):
            raise ValueError("candidate changed frozen input")
    if not isinstance(manifest["recipes"], dict) or not manifest["recipes"]:
        raise ValueError("missing recipes")
    steps = []
    for recipe in manifest["recipes"].values():
        if not isinstance(recipe, list) or not recipe:
            raise ValueError("empty recipe")
        steps.extend(recipe)
    for step in steps + manifest["compare_cases"]:
        if (
            not isinstance(step, dict)
            or not isinstance(step.get("argv"), list)
            or not step["argv"]
            or any(not isinstance(a, str) or "\0" in a for a in step["argv"])
            or type(step.get("expected_exit")) is not int
        ):
            raise ValueError("invalid step")
        if step.get("cwd") != ".":
            relative(step.get("cwd"))
        if not any(covered(arg, paths) for arg in step["argv"]):
            raise ValueError("step does not invoke pinned code")
    if (
        set(manifest["lifecycles"]) - {"initial", "resume", "after-repair"}
        or not manifest["lifecycles"]
    ):
        raise ValueError("invalid lifecycle")
    if set(manifest["temperatures"]) - {"cold", "warm"} or not manifest["temperatures"]:
        raise ValueError("invalid temperature")
    for name, config in manifest["lifecycles"].items():
        if not isinstance(config, dict):
            raise ValueError("invalid lifecycle configuration")
        if name == "resume" and not any(
            s.get("step_id") == config.get("resume_after") for s in steps
        ):
            raise ValueError("invalid resume boundary")
        if name == "after-repair":
            patch = config.get("defect_patch", {})
            path = relative(patch.get("path"))
            if patch.get("source", "baseline") not in ("baseline", "harness"):
                raise ValueError("invalid defect patch source")
            raw = (
                (root / path).read_bytes()
                if patch.get("source") == "harness"
                else git(root, "show", baseline + ":" + path)
            )
            if not config.get("defect_expected") or sha(raw) != patch.get("sha256"):
                raise ValueError("invalid defect patch")
    primary = manifest["primary"]
    if (
        not isinstance(primary, dict)
        or primary.get("recipe") not in manifest["recipes"]
        or primary.get("lifecycle") not in manifest["lifecycles"]
        or primary.get("temperature") not in manifest["temperatures"]
        or primary.get("statistic") != "median"
        or primary.get("value") != "session_ns"
    ):
        raise ValueError("invalid primary statistic")
    for case in manifest["compare_cases"]:
        if (
            case.get("class") not in ("normal", "invalid", "tampered", "boundary")
            or not case.get("case_id")
            or not case.get("family")
        ):
            raise ValueError("invalid comparison case")
        if bool(case.get("fixture_paths")) == bool(case.get("builder")):
            raise ValueError("comparison requires exactly one input source")
        if case.get("builder"):
            builder = case["builder"]
            if not isinstance(builder, dict) or set(builder) != {
                "script",
                "sha256",
                "case",
            }:
                raise ValueError("invalid case builder")
            path = relative(builder["script"])
            if builder["case"] not in (
                "valid",
                "stale",
                "forged",
                "invalid",
                "boundary",
            ) or covered(path, paths):
                raise ValueError("invalid case builder")
            if sha((root / path).read_bytes()) != builder["sha256"]:
                raise ValueError("case builder changed")
        for path in case.get("fixture_paths", []):
            path = relative(path)
            if not any(p["path"] == path for p in manifest["inputs"]):
                raise ValueError("comparison fixture is not frozen")
    return baseline, candidate


@contextmanager
def export(root, baseline, revision, code_paths):
    with tempfile.TemporaryDirectory(prefix="gate-benchmark-") as temporary:
        target = Path(temporary) / "project"
        git(root, "worktree", "add", "--quiet", "--detach", str(target), baseline)
        try:
            for path in code_paths:
                destination = target / path
                if destination.is_dir():
                    shutil.rmtree(destination)
                elif destination.exists():
                    destination.unlink()
                archive = git(root, "archive", revision, "--", path)
                with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
                    tar.extractall(target, filter="data")
            yield target
        finally:
            git(root, "worktree", "remove", "--force", str(target))


def input_tree_digest(root):
    records = []
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError("linked generated fixture")
        if path.is_file():
            records.append([path.relative_to(root).as_posix(), sha(path.read_bytes())])
    return sha(json.dumps(records, separators=(",", ":")).encode())


def materialize_case(harness_root, work, case, destination):
    if "builder" not in case:
        return case, None
    builder = case["builder"]
    source = harness_root / builder["script"]
    if sha(source.read_bytes()) != builder["sha256"]:
        raise ValueError("case builder changed")
    command = 'source "$1"; ROOT="$2"; materialize_workflow_state_case "$3" "$4"'
    result = subprocess.run(
        [
            "bash",
            "-euo",
            "pipefail",
            "-c",
            command,
            "benchmark-builder",
            str(source),
            str(work),
            builder["case"],
            str(destination),
        ],
        capture_output=True,
        check=False,
    )
    if result.returncode or not destination.is_dir():
        raise ValueError("case builder failed")
    generated = input_tree_digest(destination)
    actual = dict(
        case,
        argv=[arg.replace("<CASE_ROOT>", str(destination)) for arg in case["argv"]],
    )
    return actual, generated


def run_steps(
    root,
    steps,
    output,
    *,
    measured,
    attempt=1,
    parent_run_id=None,
    trial_id="trial",
    scenario_id="scenario",
):
    outer_begin = time.monotonic_ns()
    output.mkdir(parents=True, exist_ok=False)
    directory = output / "measurement"
    run_id = scenario_id + "-" + trial_id + "-" + str(attempt)
    if measured:
        M.open_measurement(
            directory,
            measurement_id=run_id,
            run_id=run_id,
            scope="all",
            scenario_id=scenario_id,
            trial_id=trial_id,
            attempt=attempt,
            parent_run_id=parent_run_id,
            rerun_reason="initial" if attempt == 1 else "resume",
        )
        session = M.start_span(directory, phase="session", command_id="benchmark")
    rows = []
    for index, step in enumerate(steps):
        span = (
            M.start_span(
                directory,
                phase="gate",
                command_id=step["step_id"],
                parent_span_id=session,
            )
            if measured
            else None
        )
        started = time.monotonic_ns()
        try:
            result = subprocess.run(
                step["argv"],
                cwd=root / step["cwd"],
                capture_output=True,
                timeout=300,
                check=False,
            )
            code, stdout, stderr, outcome = (
                result.returncode,
                result.stdout,
                result.stderr,
                "success" if result.returncode == 0 else "failure",
            )
        except subprocess.TimeoutExpired as exc:
            code, stdout, stderr, outcome = (
                None,
                exc.stdout or b"",
                exc.stderr or b"",
                "timeout",
            )
        elapsed = time.monotonic_ns() - started
        out, err = output / (str(index) + ".stdout"), output / (str(index) + ".stderr")
        out.write_bytes(stdout)
        err.write_bytes(stderr)
        if measured:
            M.finish_span(
                directory,
                span,
                outcome=outcome,
                exit_code=code,
                logs=[("stdout", str(out)), ("stderr", str(err))],
            )
        rows.append(
            {
                "step_id": step["step_id"],
                "exit_code": code,
                "expected_exit": step["expected_exit"],
                "elapsed_ns": elapsed,
                "stdout": str(out),
                "stderr": str(err),
                "stdout_sha256": sha(stdout),
                "stderr_sha256": sha(stderr),
            }
        )
    if measured:
        M.finish_span(
            directory,
            session,
            outcome="success"
            if all(r["exit_code"] == r["expected_exit"] for r in rows)
            else "failure",
        )
        summary = M.summarize(directory, as_of=None)
    else:
        summary = None
    return {
        "measurement": str(directory) if measured else None,
        "summary": summary,
        "outer_ns": time.monotonic_ns() - outer_begin,
        "steps": rows,
        "run_id": run_id,
    }


def aggregate_trials(recipe, trials):
    samples = []
    for trial in trials:
        attempts = trial["attempts"]
        censored = not attempts or any(not a["summary"]["complete"] for a in attempts)
        failed = any(
            row["exit_code"] != row["expected_exit"]
            for a in attempts
            for row in a["steps"]
        )
        kind = "censored" if censored else "failed" if failed else "successful"
        value = (
            sum(a["summary"]["elapsed"]["session_ns"] for a in attempts)
            if kind == "successful"
            else None
        )
        samples.append(
            {
                "trial_id": trial["trial_id"],
                "class": kind,
                "value": value,
                "attempts": attempts,
                "setup_runs": trial.get("setup_runs", []),
            }
        )
    counts = {
        k: sum(s["class"] == k for s in samples)
        for k in ("successful", "failed", "censored")
    }
    return {
        "n": len(samples),
        "attempts_started": sum(len(s["attempts"]) for s in samples),
        **counts,
        "completed": counts["successful"] + counts["failed"],
        "statistics": M.statistics(
            [s["value"] for s in samples if s["class"] == "successful"]
        ),
        "admissible": counts["successful"] == len(samples) == 5,
        "samples": samples,
    }


def fingerprint(manifest, environment):
    fixture = {k: v for k, v in manifest.items() if k != "baseline_head"}
    return sha(
        json.dumps(
            {"manifest": fixture, "environment": environment},
            sort_keys=True,
            separators=(",", ":"),
        ).encode()
    )


def comparable(left, right):
    return (
        isinstance(left.get("baseline_head"), str)
        and left["baseline_head"] == right.get("baseline_head")
        and left["fixture_fingerprint"] == right["fixture_fingerprint"]
        and left["primary"]["admissible"]
        and right["primary"]["admissible"]
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--code-revision", default="HEAD")
    modes = parser.add_mutually_exclusive_group(required=True)
    for name in ("run", "overhead", "compare"):
        modes.add_argument("--" + name, action="store_true")
    args = parser.parse_args(argv)
    try:
        root = Path(
            git(args.manifest.parent, "rev-parse", "--show-toplevel").decode().strip()
        )
        manifest = json.loads(args.manifest.read_text(), object_pairs_hook=M._pairs)
        baseline, revision = validate_manifest(root, manifest, args.code_revision)
        if args.output.exists():
            raise ValueError("output already exists")
        args.output.mkdir(parents=True)
        environment = {
            "os": platform.system(),
            "arch": platform.machine(),
            "python": platform.python_version(),
            "os_page_cache": "uncontrolled",
        }
        result = {
            "schema": "sdd-gate-benchmark-result/v1",
            "baseline_head": baseline,
            "implementation_revision": revision,
            "dirty": bool(git(root, "status", "--porcelain")),
            "environment": environment,
            "fixture_fingerprint": fingerprint(manifest, environment),
            "instrumentation_sha256": sha(Path(M.__file__).read_bytes()),
            "scenarios": {},
        }
        if args.run:
            for recipe, steps in manifest["recipes"].items():
                for lifecycle, config in manifest["lifecycles"].items():
                    for temperature in manifest["temperatures"]:
                        scenario = recipe + "-" + lifecycle + "-" + temperature
                        trials = []
                        with ExitStack() as stack:
                            prepared = None
                            if temperature == "warm":
                                prepared = stack.enter_context(
                                    export(
                                        root, baseline, revision, manifest["code_paths"]
                                    )
                                )
                                run_steps(
                                    prepared,
                                    steps,
                                    args.output / (scenario + "-warmup"),
                                    measured=False,
                                )
                            for number in range(5):
                                context = (
                                    nullcontext(prepared)
                                    if prepared
                                    else export(
                                        root, baseline, revision, manifest["code_paths"]
                                    )
                                )
                                with context as work:
                                    setup_runs = []
                                    if lifecycle == "after-repair":
                                        pin = config["defect_patch"]
                                        patch = (
                                            root
                                            if pin.get("source") == "harness"
                                            else work
                                        ) / pin["path"]
                                        if sha(patch.read_bytes()) != pin["sha256"]:
                                            raise ValueError("defect patch changed")
                                        git(work, "apply", str(patch))
                                        defect = run_steps(
                                            work,
                                            steps,
                                            args.output
                                            / (
                                                scenario + "-" + str(number) + "-defect"
                                            ),
                                            measured=False,
                                        )
                                        if any(
                                            config["defect_expected"].get(
                                                r["step_id"], r["expected_exit"]
                                            )
                                            != r["exit_code"]
                                            for r in defect["steps"]
                                        ):
                                            raise ValueError("defect did not reproduce")
                                        setup_runs.append(defect)
                                        git(work, "apply", "--reverse", str(patch))
                                    split = next(
                                        (
                                            i + 1
                                            for i, s in enumerate(steps)
                                            if s["step_id"]
                                            == config.get("resume_after")
                                        ),
                                        len(steps),
                                    )
                                    parts = (
                                        [steps[:split], steps[split:]]
                                        if lifecycle == "resume"
                                        else [steps]
                                    )
                                    attempts = []
                                    for attempt, part in enumerate(parts, 1):
                                        parent = (
                                            attempts[-1]["run_id"] if attempts else None
                                        )
                                        attempts.append(
                                            run_steps(
                                                work,
                                                part,
                                                args.output
                                                / (
                                                    scenario
                                                    + "-"
                                                    + str(number)
                                                    + "-"
                                                    + str(attempt)
                                                ),
                                                measured=True,
                                                attempt=attempt,
                                                parent_run_id=parent,
                                                trial_id="trial" + str(number),
                                                scenario_id=scenario,
                                            )
                                        )
                                    trials.append(
                                        {
                                            "trial_id": "trial" + str(number),
                                            "attempts": attempts,
                                            "setup_runs": setup_runs,
                                        }
                                    )
                        result["scenarios"][scenario] = aggregate_trials(recipe, trials)
            p = manifest["primary"]
            result["primary"] = result["scenarios"][
                p["recipe"] + "-" + p["lifecycle"] + "-" + p["temperature"]
            ]
        elif args.overhead:
            for recipe, steps in manifest["recipes"].items():
                pairs = []
                for number in range(5):
                    with export(
                        root, baseline, revision, manifest["code_paths"]
                    ) as work:
                        values = {}
                        for measured in (
                            (False, True) if number % 2 == 0 else (True, False)
                        ):
                            label = "measured" if measured else "bare"
                            values[label] = run_steps(
                                work,
                                steps,
                                args.output
                                / (recipe + "-" + str(number) + "-" + label),
                                measured=measured,
                            )
                        pairs.append(
                            {
                                "bare": values["bare"],
                                "measured": values["measured"],
                                "difference_ns": values["measured"]["outer_ns"]
                                - values["bare"]["outer_ns"],
                            }
                        )
                result["scenarios"][recipe] = {
                    "pairs": pairs,
                    "absolute_difference_ns": M.statistics(
                        [p["difference_ns"] for p in pairs]
                    ),
                    "relative_difference": M.statistics(
                        [p["difference_ns"] / p["bare"]["outer_ns"] for p in pairs]
                    ),
                }
            result["primary"] = {"admissible": False, "reason": "overhead-only"}
        else:
            for case in manifest["compare_cases"]:
                step = dict(case, step_id=case["case_id"])
                with export(root, baseline, revision, manifest["code_paths"]) as work:
                    step, generated = materialize_case(
                        root, work, step, args.output / (case["case_id"] + "-inputs")
                    )
                    bare = run_steps(
                        work,
                        [step],
                        args.output / (case["case_id"] + "-bare"),
                        measured=False,
                    )
                    measured = run_steps(
                        work,
                        [step],
                        args.output / (case["case_id"] + "-measured"),
                        measured=True,
                    )

                    def normalized(run):
                        row = run["steps"][0]
                        content = b"\0".join(
                            Path(row[k])
                            .read_bytes()
                            .replace(str(work).encode(), b"<ROOT>")
                            .replace(b"\r\n", b"\n")
                            for k in ("stdout", "stderr")
                        )
                        return row["exit_code"], sha(content)

                    equal = (
                        normalized(bare) == normalized(measured)
                        and bare["steps"][0]["exit_code"] == case["expected_exit"]
                    )
                    if (
                        generated is not None
                        and input_tree_digest(
                            args.output / (case["case_id"] + "-inputs")
                        )
                        != generated
                    ):
                        raise ValueError("case-input-changed")
                    result["scenarios"][case["case_id"]] = {
                        "generated_inputs_sha256": generated,
                        "equal": equal,
                        "bare": bare,
                        "measured": measured,
                    }
            result["primary"] = {"admissible": False, "reason": "comparison-only"}
        (args.output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
        return (
            0
            if not args.compare or all(x["equal"] for x in result["scenarios"].values())
            else 1
        )
    except (ValueError, KeyError, TypeError, OSError, M.MeasurementError):
        print(
            "gate-benchmark: invalid or incomplete benchmark input/execution",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    sys.exit(main())
