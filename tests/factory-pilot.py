#!/usr/bin/env python3
"""Run the #624 deterministic single-host fixture protocol; no real-app UX claim."""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "factory_fixture", ROOT / "tests/factory-workflow.tests.py"
)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


def pilot(output):
    if output.exists():
        raise ValueError(
            "output must be a new directory; earlier attempts are never overwritten"
        )
    output.mkdir(parents=True)
    revision = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
        timeout=30,
    ).stdout.strip()
    dirty = bool(
        subprocess.run(
            ["git", "-C", str(ROOT), "status", "--porcelain"],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        ).stdout
    )
    protocol = {
        "schema": "factory-fixture-protocol/v1",
        "repetitions": 3,
        "alternatives": ["a", "b"],
        "initial_input": "Find completed task 2",
        "success": [
            "both stdout logs equal completed task: 2",
            "no task/approval changes",
            "candidate exposes both source logs and unknown human decision",
        ],
        "tolerance": "exact output and state equality; no timing threshold",
        "stop": {"seconds": 30, "subprocess_seconds": 3, "max_runs": 12},
        "rollback": "discard only this new isolated fixture directory; no product files modified",
        "configuration": {
            "revision": revision,
            "dirty": dirty,
            "os": platform.platform(),
            "python": platform.python_version(),
            "model": None,
            "model_reason": "deterministic fixture; no model invoked",
        },
        "baseline": "existing raw-log presentation",
        "candidate": "playbook route and passive packet display",
        "app_evaluation": "pending",
        "human_choice": "pending",
        "parallel_executor": "unavailable",
    }
    raw = json.dumps(protocol, sort_keys=True, indent=2).encode()
    (output / "protocol.json").write_bytes(raw)
    protocol_hash = hashlib.sha256(raw).hexdigest()
    started = time.monotonic()
    runs = []
    for trial in range(1, 4):
        for variant in (
            ("baseline", "candidate") if trial % 2 else ("candidate", "baseline")
        ):
            trial_root = output / f"{trial}-{variant}"
            trial_root.mkdir()
            packet = fixture.fixture(trial_root)
            task_before = (trial_root / "specs/pilot/tasks.md").read_bytes()
            before = time.monotonic()
            row = {
                "trial": trial,
                "variant": variant,
                "outcome": "not-run",
                "reason": None,
                "seconds": None,
                "token": None,
                "cost": None,
                "metrics_reason": "no model or cost meter",
                "human_active_seconds": None,
                "human_wait_seconds": None,
                "human_time_reason": "no human participant in fixture",
                "artifacts": [],
                "protocol_sha256": protocol_hash,
            }
            if time.monotonic() - started >= protocol["stop"]["seconds"]:
                row["reason"] = "experiment time limit reached"
                runs.append(row)
                continue
            preparation = None
            try:
                if variant == "candidate":
                    route = fixture.route.route(fixture.request())
                    (trial_root / "route.json").write_text(json.dumps(route, indent=2))
                for alternative in packet["alternatives"]:
                    run_id = f"{variant}-{trial}-{alternative['id']}"
                    observation = fixture.observe(
                        trial_root, alternative["id"], run_id=run_id
                    )
                    alternative["observations"] = [observation]
                    observed = (
                        trial_root / observation["evidence"]["path"]
                    ).read_text()
                    if observed != "completed task: 2\n":
                        raise ValueError("fixture output changed")
                    row["artifacts"].append(observation["evidence"])
                presentation = trial_root / "presentation-measurement"
                fixture.measurement.open_measurement(
                    presentation,
                    measurement_id=f"presentation-{variant}-{trial}",
                    run_id=f"presentation-{variant}-{trial}",
                    scope="feature",
                    feature="pilot",
                    task="T-001",
                    parent_run_id="experiment-1",
                    experiment_ref=protocol_hash,
                    variant_ref=variant,
                )
                preparation = fixture.measurement.start_span(
                    presentation,
                    phase="session",
                    command_id="fixture-presentation-session",
                    span_id="presentation-session",
                )
                preparation = fixture.measurement.start_span(
                    presentation,
                    phase="review-preparation",
                    command_id="fixture-presentation",
                    parent_span_id="presentation-session",
                    inputs=[trial_root / ref["path"] for ref in row["artifacts"]],
                )
                if variant == "candidate":
                    digest = fixture.packet.packet_digest(packet)
                    result = fixture.packet.validate(
                        trial_root, packet, "pilot", "T-001", "experiment-1", digest
                    )
                    (trial_root / "packet.json").write_text(
                        json.dumps(packet, indent=2)
                    )
                    (trial_root / "packet.sha256").write_text(digest + "\n")
                    (trial_root / "packet.md").write_text(fixture.packet.render(result))
                    if result["human_decision"] != "pending":
                        raise ValueError("fixture acquired human authority")
                else:
                    (trial_root / "logs.txt").write_text(
                        "\n".join(ref["path"] for ref in row["artifacts"]) + "\n"
                    )
                if (trial_root / "specs/pilot/tasks.md").read_bytes() != task_before:
                    raise ValueError("task/approval changed")
                row["outcome"] = "success"
            except subprocess.TimeoutExpired:
                row.update(
                    outcome="timeout", reason="fixture subprocess deadline exceeded"
                )
            except (OSError, ValueError, RuntimeError) as exc:
                row.update(outcome="failure", reason=str(exc))
            finally:
                if preparation is not None:
                    fixture.measurement.finish_span(
                        presentation,
                        preparation,
                        outcome=row["outcome"],
                        exit_code=0 if row["outcome"] == "success" else 1,
                    )
                    fixture.measurement.finish_span(
                        presentation,
                        "presentation-session",
                        outcome=row["outcome"],
                        exit_code=0 if row["outcome"] == "success" else 1,
                    )
                    summary = fixture.measurement.summarize(
                        presentation, ref_root=trial_root
                    )
                    (trial_root / "presentation-summary.json").write_text(
                        json.dumps(summary, indent=2)
                    )
                    row["presentation_measurement"] = fixture.reference(
                        trial_root, "presentation-summary.json"
                    )
                row["seconds"] = time.monotonic() - before
                runs.append(row)
                (trial_root / "trial.json").write_text(json.dumps(row, indent=2))
    summaries = {}
    for variant in ("baseline", "candidate"):
        selected = [r for r in runs if r["variant"] == variant]
        samples = [r["seconds"] for r in selected if r["seconds"] is not None]
        summaries[variant] = {
            "n": len(selected),
            "k_success": sum(r["outcome"] == "success" for r in selected),
            "all_success": all(r["outcome"] == "success" for r in selected),
            "median_seconds": statistics.median(samples) if samples else None,
            "range_seconds": [min(samples), max(samples)] if samples else None,
        }
    report = {
        "schema": "factory-fixture-report/v1",
        "protocol_sha256": protocol_hash,
        "runs": runs,
        "summaries": summaries,
        "acceptance": "fixture-only",
        "real_app_evaluation": "pending",
        "human_adoption": "pending",
        "wfi_disposition": "pending human decision",
        "safety_regression": any(r["outcome"] == "failure" for r in runs),
        "limits": [
            "No model comparison or human UX observation",
            "No product implementation/gate cycle",
            "No actual human choice; signed-choice contract tested separately with synthetic keys",
            "No supported parallel executor; no 2/4/8 claims",
            "Timing is local rendering overhead, not quality or user benefit",
        ],
    }
    (output / "report.json").write_text(json.dumps(report, indent=2))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        report = pilot(args.output.resolve())
        print(
            json.dumps(
                {
                    "report": str(args.output / "report.json"),
                    "summaries": report["summaries"],
                    "real_app_evaluation": "pending",
                }
            )
        )
        return 0 if all(s["all_success"] for s in report["summaries"].values()) else 1
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
