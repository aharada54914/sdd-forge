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
import re
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


def collect(root, contract_path, task_path, skill, check_id, *, timeout=30):
    if (
        type(timeout) not in (int, float)
        or not math.isfinite(timeout)
        or not 0 < timeout <= 3600
    ):
        raise V.Invalid("timeout-invalid")
    root = Path(root).absolute()
    contract, _ = V.load(contract_path, "contract-invalid")
    task, _ = V.load(task_path, "input-unbound")
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
    if contract.get("risk") == "critical":
        raise V.Invalid("critical-requires-existing-clean-tree-signing-route")
    if contract.get("required_workflow") == "tdd":
        raise V.Invalid("tdd-requires-original-red-green-pair")
    checks = contract.get("checks")
    if not isinstance(checks, list) or any(not isinstance(c, dict) for c in checks):
        raise V.Invalid("contract-invalid")
    selected = [c for c in checks if c.get("id") == check_id]
    if len(selected) != 1:
        raise V.Invalid("check-mismatch")
    result = RUNNER.run(
        root, skill, check_id, timeout=timeout, task_path=Path(task_path)
    )
    if not result.get("observation_written") or not result.get("cleanup"):
        raise V.Invalid("execution-incomplete")
    observation_path = V.safe(root, result["observation"], missing=False)
    validated = V.validate(root, skill, observation_path, Path(task_path))
    if validated[2] not in ("passed", "failed"):
        raise V.Invalid("execution-incomplete")
    evidence = observation_path.parent
    transcript = []
    for stream in ("stdout", "stderr"):
        ref = result[stream]
        path = V.safe(root, ref["path"], missing=False)
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != ref["sha256"]:
            raise V.Invalid("log-digest-mismatch")
        transcript.append((stream, raw))
    # The retained combined file contains the original bytes, even if a later
    # reader removes the runner's separate stream files.
    combined = evidence / (check_id + ".execution.log")
    with combined.open("xb") as output:
        for stream, raw in transcript:
            output.write(
                ("stream=" + stream + " bytes=" + str(len(raw)) + "\n").encode()
            )
            output.write(raw)
            output.write(b"\n")
        output.write(b"observation=")
        output.write(observation_path.read_bytes())
    updated = copy.deepcopy(contract)
    projected = V.project_execution(selected[0], validated)
    projected["evidence"] = combined.relative_to(root).as_posix()
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
    args = parser.parse_args(argv)
    try:
        result = collect(
            args.execution_root,
            args.contract,
            args.task_input_manifest,
            args.skill,
            args.check,
            timeout=args.timeout,
        )
    except (V.Invalid, OSError, ValueError, KeyError, TypeError) as exc:
        print(
            "project-evidence: blocked: "
            + (str(exc) if isinstance(exc, V.Invalid) else "invalid-input-or-storage"),
            file=sys.stderr,
        )
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0 if result["contract_valid"] and result["bundle_valid"] else 1


if __name__ == "__main__":
    sys.exit(main())
