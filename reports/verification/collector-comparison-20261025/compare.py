#!/usr/bin/env python3
"""Offline matched fixture comparison; counts scripted transfers, never human work."""

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
import time
from unittest.mock import patch

REVISION = "aecd3136278cdc18c377fac269e60b037d34dc25"


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def load(path):
    spec = importlib.util.spec_from_file_location("collector_comparison_fixture", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inventory(root):
    return {
        p.relative_to(root).as_posix(): digest(p.read_bytes())
        for p in sorted(root.rglob("*"))
        if p.is_file() and ".git" not in p.relative_to(root).parts
    }


def stats(values):
    middle = statistics.median(values)
    return dict(
        n=len(values),
        median=middle,
        minimum=min(values),
        maximum=max(values),
        mad=statistics.median(abs(x - middle) for x in values),
    )


def manual(C, root, actions):
    original = json.loads((root / "contract.json").read_text())
    task = json.loads((root / "input.json").read_text())
    result = C.RUNNER.run(
        root, "example", "smoke", timeout=30, task_path=root / "input.json"
    )
    assert result["cleanup"] and result["observation_written"]
    obs_path = root / result["observation"]
    obs_bytes = obs_path.read_bytes()
    assert digest(obs_bytes) == result["observation_sha256"]
    manifest, obs, state = C.V.validate(root, "example", obs_path, root / "input.json")
    assert obs == json.loads(obs_bytes) and state == result["outcome"]
    assert obs["exit_code"] == result["exit_code"]
    folder = obs_path.parent
    combined = folder / "smoke.execution.log"

    def transfer(value, source, destination):
        raw = (
            value
            if isinstance(value, bytes)
            else json.dumps(value, sort_keys=True).encode()
        )
        actions.append(
            dict(
                kind="scripted-transfer",
                source=source,
                destination=destination,
                value_sha256=digest(raw),
            )
        )
        return value

    with combined.open("xb") as stream:
        for name in [
            "stdout",
            "stderr",
            "observation",
            "task-input-manifest",
            "skill-manifest",
        ]:
            if name in ("stdout", "stderr"):
                raw = (root / result[name]["path"]).read_bytes()
                assert digest(raw) == result[name]["sha256"]
            elif name == "observation":
                raw = obs_bytes
            elif name == "task-input-manifest":
                raw = (root / "input.json").read_bytes()
            else:
                raw = (root / "sdd/skills/example/skill-manifest.json").read_bytes()
            transfer(raw, name, "smoke.execution.log:" + name)
            stream.write(
                ("execution:" + name + " bytes=" + str(len(raw)) + "\n").encode()
                + raw
                + b"\n"
            )
    actions.append(
        dict(kind="scripted-artifact-write", path=combined.relative_to(root).as_posix())
    )
    contract = copy.deepcopy(original)
    check = next(row for row in contract["checks"] if row["id"] == "smoke")
    fields = {
        "command": json.dumps(
            [
                manifest["runtime"],
                "sdd/skills/" + manifest["name"] + "/" + manifest["entry"],
                *manifest["args"],
            ],
            separators=(",", ":"),
        ),
        "started_at": obs["started_at"],
        "finished_at": obs["finished_at"],
        "exit_code": obs["exit_code"],
        "passes": state == "passed",
        "evidence": combined.relative_to(root).as_posix(),
    }
    for key, value in fields.items():
        check[key] = transfer(
            value, "validated-execution:" + key, "contract:smoke." + key
        )
    output = folder / "T-001.contract.json"
    with output.open("x") as stream:
        stream.write(json.dumps(contract, indent=2) + "\n")
    actions.append(
        dict(kind="scripted-artifact-write", path=output.relative_to(root).as_posix())
    )
    checked = subprocess.run(
        [sys.executable, str(C.HERE / "check-contract.py"), str(output), str(root)],
        capture_output=True,
    )
    report = folder / "T-001.report.md"
    values = [
        ("Task ID", task["task_id"]),
        ("Run ID", task["run_id"]),
        ("Feature", original["feature"]),
        ("VERDICT", "PASS" if checked.returncode == 0 else "FAIL"),
        ("Check", "smoke"),
        ("Outcome", state),
        ("Observation", result["observation"]),
        ("Input manifest SHA-256", obs["task_input_manifest_sha256"]),
        ("Raw execution", fields["evidence"]),
    ]
    with report.open("x") as stream:
        stream.write("# Actual execution evidence\n\n")
        for key, value in values:
            stream.write(
                key
                + ": "
                + transfer(value, "observed-or-retained:" + key, "report:" + key)
                + "\n"
            )
        stream.write(
            "\nVerdict scope: deterministic contract verification only. Other checks are retained unchanged. No independent review or Done decision is inferred.\n"
        )
    actions.append(
        dict(kind="scripted-artifact-write", path=report.relative_to(root).as_posix())
    )
    bundle = folder / "T-001.evidence.json"
    generated = subprocess.run(
        [
            "sh",
            str(C.HERE / "generate-evidence-bundle.sh"),
            str(output),
            str(report),
            str(root),
            str(bundle),
        ],
        capture_output=True,
    )
    assert generated.returncode == 0
    checked_bundle = subprocess.run(
        ["sh", str(C.HERE / "check-evidence-bundle.sh"), str(bundle), str(root)],
        capture_output=True,
    )
    return dict(
        task_id=task["task_id"],
        run_id=task["run_id"],
        check_id="smoke",
        execution_outcome=state,
        contract=output.relative_to(root).as_posix(),
        report=report.relative_to(root).as_posix(),
        bundle=bundle.relative_to(root).as_posix(),
        contract_valid=checked.returncode == 0,
        bundle_valid=checked_bundle.returncode == 0,
        task_transition=None,
    )


def trial(C, root, route, evidence):
    evidence.mkdir()
    actions, processes, commands, executions = [], [], [], []
    original_popen, original_run, original_runner = (
        subprocess.Popen,
        subprocess.run,
        C.RUNNER.run,
    )

    def traced_popen(*args, **kwargs):
        process = original_popen(*args, **kwargs)
        processes.append(
            (
                process,
                dict(
                    argv=[str(x) for x in (args[0] if args else kwargs["args"])],
                    cwd=str(kwargs.get("cwd") or Path.cwd()),
                ),
            )
        )
        return process

    def traced_run(*args, **kwargs):
        result = original_run(*args, **kwargs)
        commands.append(
            (
                result,
                dict(
                    argv=[str(x) for x in result.args],
                    cwd=str(kwargs.get("cwd") or Path.cwd()),
                ),
            )
        )
        return result

    def traced_runner(*args, **kwargs):
        before = time.monotonic_ns()
        result = original_runner(*args, **kwargs)
        executions.append(
            dict(elapsed_ns=time.monotonic_ns() - before, receipt=copy.deepcopy(result))
        )
        return result

    started = time.monotonic_ns()
    with (
        patch.object(subprocess, "Popen", traced_popen),
        patch.object(subprocess, "run", traced_run),
        patch.object(C.RUNNER, "run", traced_runner),
    ):
        if route == "manual-format":
            result = manual(C, root, actions)
        else:
            result = C.collect(
                root, root / "contract.json", root / "input.json", "example", "smoke"
            )
    elapsed = time.monotonic_ns() - started
    command_rows = []
    for number, (command, metadata) in enumerate(commands):
        row = dict(metadata, exit_code=command.returncode)
        for stream in ("stdout", "stderr"):
            raw = getattr(command, stream) or b""
            if isinstance(raw, str):
                raw = raw.encode()
            name = str(number) + "." + stream
            (evidence / name).write_bytes(raw)
            row[stream] = dict(path=name, sha256=digest(raw))
        command_rows.append(row)
    for process, metadata in processes:
        metadata["exit_code"] = process.returncode
    for child in ["reports", "output"]:
        if (root / child).exists():
            shutil.copytree(root / child, evidence / child)
    record = dict(
        route=route,
        total_ns=elapsed,
        runner_ns=sum(x["elapsed_ns"] for x in executions),
        result=result,
        action_events=actions,
        commands=command_rows,
        launched_processes=[x[1] for x in processes],
        executions=executions,
        output_hashes=inventory(evidence),
        post_validation_corrections=0,
        human_active_ns=None,
        human_reason="no human operator observed",
    )
    normalized_contract = json.loads((root / result["contract"]).read_text())
    for row in normalized_contract["checks"]:
        row.pop("started_at", None)
        row.pop("finished_at", None)
    record["contract_semantics_sha256"] = digest(
        json.dumps(normalized_contract, sort_keys=True).encode()
    )
    record["report_sha256"] = digest((root / result["report"]).read_bytes())
    record["nonrunner_ns"] = elapsed - record["runner_ns"]
    (evidence / "record.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = args.source_root.resolve()
    revision = (
        subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"])
        .decode()
        .strip()
    )
    assert revision == REVISION
    assert not subprocess.check_output(
        ["git", "-C", str(source), "status", "--porcelain"]
    )
    args.output.mkdir(parents=True, exist_ok=False)
    output = args.output.resolve()
    F = load(source / "tests/project-evidence-collector.tests.py")
    C = F.C
    rows = []
    for scenario in ("success", "nonzero"):
        fixture = F.CollectorTests()
        fixture.setUp()
        try:
            if scenario == "nonzero":
                entry = fixture.fixture.skill / "run.py"
                entry.write_text(
                    'print("real failing invocation")\nraise SystemExit(3)\n'
                )
                fixture.fixture.manifest["files"][0]["sha256"] = digest(
                    entry.read_bytes()
                )
                fixture.fixture.write_manifest()
                fixture.fixture.task()
                fixture.fixture.observation.unlink()
                subprocess.run(["git", "-C", str(fixture.root), "add", "."], check=True)
                subprocess.run(
                    [
                        "git",
                        "-C",
                        str(fixture.root),
                        "-c",
                        "user.name=Fixture",
                        "-c",
                        "user.email=fixture@example.invalid",
                        "commit",
                        "-qm",
                        "nonzero control",
                    ],
                    check=True,
                )
            frozen = inventory(fixture.root)
            inputs = output / (scenario + "-inputs")
            shutil.copytree(fixture.root, inputs, ignore=shutil.ignore_patterns(".git"))
            for pair in range(3):
                order = (
                    ["manual-format", "collector"]
                    if pair % 2 == 0
                    else ["collector", "manual-format"]
                )
                matched = {}
                for route in order:
                    label = scenario + "-" + str(pair) + "-" + route
                    work = output / (label + "-work")
                    shutil.copytree(fixture.root, work)
                    assert inventory(work) == frozen
                    record = trial(C, work, route, output / label)
                    assert inventory(work)["contract.json"] == frozen["contract.json"]
                    matched[route] = record
                    rows.append(
                        dict(
                            scenario=scenario,
                            pair=pair,
                            order=order,
                            label=label,
                            input_digest=digest(
                                json.dumps(frozen, sort_keys=True).encode()
                            ),
                            record=record,
                        )
                    )
                    shutil.rmtree(work)
                a, b = (matched[k]["result"] for k in ("manual-format", "collector"))
                assert a == b, (a, b)
                for field in ("contract_semantics_sha256", "report_sha256"):
                    assert (
                        matched["manual-format"][field] == matched["collector"][field]
                    )

                assert a["execution_outcome"] == (
                    "passed" if scenario == "success" else "failed"
                )
                assert a["contract_valid"] == (scenario == "success")
                assert a["bundle_valid"] == (scenario == "success")
        finally:
            fixture.doCleanups()
    summary = dict(
        source_revision=revision,
        source_root=str(source),
        harness_sha256=digest(Path(__file__).read_bytes()),
        environment=dict(
            os=platform.platform(),
            python=platform.python_version(),
            host_load="uncontrolled; root runs shared verification concurrently",
        ),
        scope="scripted same-fixture API paths, no human-time/cognitive-load or TDD/critical comparison",
        rows=rows,
        statistics={},
    )
    for scenario in ("success", "nonzero"):
        summary["statistics"][scenario] = {}
        for route in ("manual-format", "collector"):
            chosen = [
                x["record"]
                for x in rows
                if x["scenario"] == scenario and x["record"]["route"] == route
            ]
            summary["statistics"][scenario][route] = {
                field: stats([x[field] for x in chosen])
                for field in ("total_ns", "runner_ns", "nonrunner_ns")
            }
    (output / "results.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary["statistics"], indent=2))


if __name__ == "__main__":
    main()
