#!/usr/bin/env python3
"""Project actual runner observations into existing contract/report/bundle formats.

This command runs a check; it never imports a caller-supplied PASS observation.
It prepares candidate evidence, not a task transition or reviewer verdict.
"""

import argparse
import copy
import hashlib
import importlib.util
import json
import math
import os
import re
import shutil
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


V = load_module("project_validation", HERE / "validate-project-skill.py")
RUNNER = load_module(
    "project_runner", HERE.parents[1] / "sdd-bootstrap/scripts/project-skill.py"
)


def runtime_identity(skill_bytes):
    runtime = shutil.which(json.loads(skill_bytes)["runtime"])
    return (runtime, V.digest(Path(runtime).read_bytes()) if runtime else None)


def execute(root, task_path, skill, check_id, timeout, expected=None):
    if os.environ.get("SDD_EVIDENCE_KEY") or os.environ.get("SDD_EVIDENCE_KEY_FILE"):
        raise V.Invalid("execution-must-not-inherit-signing-key")
    task_bytes = Path(task_path).read_bytes()
    skill_bytes = V.discover(root, skill)[1]
    if expected is not None:
        if (task_bytes, skill_bytes) != expected[:2]:
            raise V.Invalid("tdd-admission-changed")
        if dict(os.environ) != expected[2] or runtime_identity(skill_bytes) != expected[3]:
            raise V.Invalid("tdd-environment-changed")
    result = RUNNER.run(
        root, skill, check_id, timeout=timeout, task_path=Path(task_path)
    )
    if not result.get("observation_written") or not result.get("cleanup"):
        raise V.Invalid("execution-incomplete")
    observation_path = V.safe(root, result["observation"], missing=False)
    observation, observation_bytes = V.load(observation_path, "observation-invalid")
    if hashlib.sha256(observation_bytes).hexdigest() != result.get(
        "observation_sha256"
    ):
        raise V.Invalid("observation-execution-mismatch")
    validated = V.validate(root, skill, observation_path, Path(task_path))
    if (
        validated[2] not in ("passed", "failed")
        or validated[2] != result.get("outcome")
        or observation.get("exit_code") != result.get("exit_code")
        or validated[1] != observation
    ):
        raise V.Invalid("observation-execution-mismatch")
    transcript = []
    for stream in ("stdout", "stderr"):
        ref = result[stream]
        path = V.safe(root, ref["path"], missing=False)
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != ref["sha256"]:
            raise V.Invalid("log-digest-mismatch")
        transcript.append((stream, raw))
    if expected is not None and (
        dict(os.environ) != expected[2] or runtime_identity(skill_bytes) != expected[3]
        or observation["environment"]["runtime_path"] != expected[3][0]
    ):
        raise V.Invalid("tdd-environment-changed")
    transcript.append(("observation", observation_bytes))
    if (V.digest(task_bytes) != observation["task_input_manifest_sha256"]
        or V.digest(skill_bytes) != observation["skill_manifest_sha256"]):
        raise V.Invalid("observation-input-mismatch")
    transcript.append(("task-input-manifest", task_bytes))
    transcript.append(("skill-manifest", skill_bytes))
    return result, validated, transcript


def write_transcript(output, transcript, phase):
    for stream, raw in transcript:
        output.write((phase + ":" + stream + " bytes=" + str(len(raw)) + "\n").encode())
        output.write(raw)
        output.write(b"\n")


def collect(root, contract_path, task_path, skill, check_id, *, timeout=30,
            tdd_transition=None, tdd_sources=(), prepare=False):
    if (
        type(timeout) not in (int, float)
        or not math.isfinite(timeout)
        or not 0 < timeout <= 3600
    ):
        raise V.Invalid("timeout-invalid")
    root = Path(root).absolute()
    contract, _ = V.load(contract_path, "contract-invalid")
    task, task_bytes = V.load(task_path, "input-unbound")
    if (
        not isinstance(contract, dict)
        or not isinstance(task, dict)
        or contract.get("task_id") != task.get("task_id")
    ):
        raise V.Invalid("task-mismatch")
    if not isinstance(contract.get("feature"), str) or not re.fullmatch(
        "[a-z0-9][a-z0-9-]*", contract["feature"]
    ):
        raise V.Invalid("feature-invalid")
    if contract.get("risk") in {"high", "critical"} and not prepare:
        raise V.Invalid("high-risk-requires-existing-review-signing-route")
    needs_pair = contract.get("required_workflow") == "tdd" and check_id in {"unit-tests", "acceptance-tests"}
    if tdd_transition is not None and not needs_pair:
        raise V.Invalid("tdd-check-mismatch")
    checks = contract.get("checks")
    if not isinstance(checks, list) or any(not isinstance(c, dict) for c in checks):
        raise V.Invalid("contract-invalid")
    selected = [c for c in checks if c.get("id") == check_id]
    if len(selected) != 1:
        raise V.Invalid("check-mismatch")
    red = None
    expected = None
    if needs_pair:
        if not callable(tdd_transition) or not tdd_sources:
            raise V.Invalid("tdd-requires-original-red-green-pair")
        before = {item["path"]: item["sha256"] for item in task["allowed_inputs"]}
        _, skill_bytes, skill_files = V.discover(root, skill)
        protected = set(skill_files) | {"sdd/skills/" + skill + "/skill-manifest.json"}
        mutable = set(tdd_sources)
        if not mutable <= before.keys() or mutable & protected:
            raise V.Invalid("tdd-source-boundary-invalid")
        environment = dict(os.environ)
        runtime = runtime_identity(skill_bytes)
        red_result, red_validated, red = execute(root, task_path, skill, check_id, timeout,
                                               (task_bytes, skill_bytes, environment, runtime))
        if red_validated[2] != "failed" or red_result["exit_code"] <= 0 or red_result.get("reason") is not None:
            raise V.Invalid("tdd-red-must-be-real-failure")
        # Red stays in this process; no caller-authored checkpoint can become Red.
        task_path = Path(tdd_transition(copy.deepcopy(red_result)))
        green, green_bytes = V.load(task_path, "input-unbound")
        ignored = {"run_id", "allowed_inputs", "allowed_outputs"}
        if (not isinstance(green, dict)
            or {k: v for k, v in task.items() if k not in ignored}
            != {k: v for k, v in green.items() if k not in ignored}
            or task["run_id"] == green.get("run_id")):
            raise V.Invalid("tdd-identity-mismatch")
        red_directory = red_result["observation"].rsplit("/", 1)[0] + "/"
        green_directory = V.observation_relative({
            "mode": "task", "task_id": green["task_id"],
            "run_id": green["run_id"], "check_id": check_id,
        }).rsplit("/", 1)[0] + "/"
        expected_outputs = [green_directory if path == red_directory else path
                            for path in task["allowed_outputs"]]
        if green.get("allowed_outputs") != expected_outputs:
            raise V.Invalid("tdd-output-lineage-mismatch")
        after = {item["path"]: item["sha256"] for item in green["allowed_inputs"]}
        if (before.keys() != after.keys()
            or any(before[p] != after[p] for p in before.keys() - mutable)
            or V.discover(root, skill)[1] != skill_bytes):
            raise V.Invalid("tdd-input-lineage-mismatch")
        task = green
        expected = (green_bytes, skill_bytes, environment, runtime)
    result, validated, transcript = execute(root, task_path, skill, check_id, timeout, expected)
    evidence = V.safe(root, result["observation"], missing=False).parent
    combined = evidence / (check_id + ".execution.log")
    with combined.open("xb") as output:
        if red is not None:
            write_transcript(output, red, "red")
        write_transcript(output, transcript, "green" if red is not None else "execution")
    updated = copy.deepcopy(contract)
    projected = V.project_execution(selected[0], validated)
    projected["evidence"] = combined.relative_to(root).as_posix()
    if red is not None:
        # Both originals are retained in the existing hash-bound evidence artifact.
        projected["red_evidence"] = projected["evidence"]
        projected["green_evidence"] = projected["evidence"]
    updated["checks"] = [projected if c.get("id") == check_id else c for c in checks]
    output_contract = evidence / (task["task_id"] + ".contract.json")
    with output_contract.open("x", encoding="utf-8") as output:
        json.dump(updated, output, indent=2)
        output.write("\n")
    checked = subprocess.run(
        [
            sys.executable,
            str(HERE / "check-contract.py"),
            str(output_contract),
            str(root),
        ],
        capture_output=True,
        check=False,
    )
    report = evidence / (task["task_id"] + ".report.md")
    with report.open("x", encoding="utf-8") as output:
        output.write("# Actual execution evidence\n\n")
        output.write(
            "Task ID: " + task["task_id"] + "\nRun ID: " + task["run_id"] + "\n"
        )
        output.write("Feature: " + contract["feature"] + "\n")
        output.write(
            "VERDICT: " + ("PASS" if checked.returncode == 0 else "FAIL") + "\n"
        )
        output.write("Check: " + check_id + "\nOutcome: " + validated[2] + "\n")
        output.write("Observation: " + result["observation"] + "\n")
        output.write(
            "Input manifest SHA-256: "
            + validated[1]["task_input_manifest_sha256"]
            + "\n"
        )
        output.write("Raw execution: " + projected["evidence"] + "\n\n")
        output.write(
            "Verdict scope: deterministic contract verification only. Other checks are retained unchanged. No independent review or Done decision is inferred.\n"
        )
    if prepare:
        return {
            "task_id": task["task_id"], "run_id": task["run_id"], "check_id": check_id,
            "execution_outcome": validated[2], "contract": str(output_contract.relative_to(root)),
            "contract_sha256": V.digest(output_contract.read_bytes()),
            "report": str(report.relative_to(root)), "bundle": None,
            "contract_valid": checked.returncode == 0, "bundle_valid": False,
            "task_transition": None,
        }
    bundle = evidence / (task["task_id"] + ".evidence.json")
    generator = HERE / "generate-evidence-bundle.sh"
    generated = subprocess.run(
        [
            "sh",
            str(generator),
            str(output_contract),
            str(report),
            str(root),
            str(bundle),
        ],
        capture_output=True,
        check=False,
    )
    if generated.returncode != 0:
        raise V.Invalid("bundle-generation-failed")
    bundle_checked = subprocess.run(
        ["sh", str(HERE / "check-evidence-bundle.sh"), str(bundle), str(root)],
        capture_output=True,
        check=False,
    )
    return {
        "task_id": task["task_id"],
        "run_id": task["run_id"],
        "check_id": check_id,
        "execution_outcome": validated[2],
        "contract": str(output_contract.relative_to(root)),
        "report": str(report.relative_to(root)),
        "bundle": str(bundle.relative_to(root)),
        "contract_valid": checked.returncode == 0,
        "bundle_valid": bundle_checked.returncode == 0,
        "task_transition": None,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("execution-root", "contract", "task-input-manifest", "skill", "check"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("--prepare", action="store_true",
                        help="Prepare evidence only; review, commit and signing remain in the existing route")
    parser.add_argument("--tdd-input-stdin", action="store_true",
                        help="After actual Red, read the new Green task manifest path from stdin")
    parser.add_argument("--tdd-source", action="append", default=[],
                        help="Implementation input allowed to change between Red and Green")
    args = parser.parse_args(argv)

    def transition(red):
        print(json.dumps({"red_observation": red["observation"],
                          "next": "supply-green-task-manifest-path"}), flush=True)
        path = sys.stdin.readline().strip()
        if not path:
            raise V.Invalid("tdd-green-missing")
        return path
    try:
        result = collect(
            args.execution_root,
            args.contract,
            args.task_input_manifest,
            args.skill,
            args.check,
            timeout=args.timeout,
            tdd_transition=transition if args.tdd_input_stdin else None,
            tdd_sources=args.tdd_source,
            prepare=args.prepare,
        )
    except (V.Invalid, OSError, ValueError, KeyError, TypeError) as exc:
        print(
            "project-evidence: blocked: "
            + (str(exc) if isinstance(exc, V.Invalid) else "invalid-input-or-storage"),
            file=sys.stderr,
        )
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0 if result["contract_valid"] and (args.prepare or result["bundle_valid"]) else 1


if __name__ == "__main__":
    sys.exit(main())
