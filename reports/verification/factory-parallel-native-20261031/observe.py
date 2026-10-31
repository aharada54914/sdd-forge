#!/usr/bin/env python3
"""Finite fixture benchmark, not an external work-order dispatcher."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import platform
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

PROGRAM = """import hashlib,json,socket,sqlite3
from pathlib import Path
seed=Path("seed.txt").read_text()
with socket.socket() as port, sqlite3.connect("trial.sqlite") as db:
 port.bind(("127.0.0.1",0))
 db.execute("create table items (id integer primary key, value text)")
 db.executemany("insert into items values (?,?)", ((i,seed) for i in range(10000)))
 db.commit()
 count,total=db.execute("select count(*),sum(id) from items").fetchone()
 assert (count,total)==(10000,49995000)
 value=seed.encode()*65536
 for _ in range(128): value=hashlib.sha256(value).digest()+value[32:]
 print(json.dumps({"count":count,"total":total,"seed":seed,"digest":hashlib.sha256(value).hexdigest(),"port":port.getsockname()[1]}))
"""


def load(root, relative, name):
    spec = importlib.util.spec_from_file_location(name, root / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def save(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--parallel", type=int, choices=(2, 4, 8), required=True)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    runner = load(
        source, "plugins/sdd-bootstrap/scripts/project-skill.py", "trial_runner"
    )
    admission = load(
        source,
        "plugins/sdd-bootstrap/scripts/factory-adapter-readiness.py",
        "trial_admission",
    )
    measure = load(
        source,
        "plugins/sdd-quality-loop/scripts/run_measurement.py",
        "trial_measurement",
    )
    head = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    dirty = bool(
        subprocess.check_output(["git", "-C", str(source), "status", "--porcelain"])
    )
    result = dict(
        schema="factory-parallel-observation/v1",
        source=head,
        dirty=dirty,
        machine=dict(
            uname=list(platform.uname()),
            cpu_count=os.cpu_count(),
            image=os.environ.get("ImageVersion"),
        ),
        comparison_limit="Separate hosted jobs and fixed order; not a causal speedup experiment.",
        native={
            key: os.environ.get(key)
            for key in (
                "GITHUB_REPOSITORY",
                "GITHUB_RUN_ID",
                "GITHUB_RUN_ATTEMPT",
                "GITHUB_JOB",
                "GITHUB_SHA",
            )
        },
        parallel=args.parallel,
        scope="eight synthetic isolated SQLite/hash jobs per trial; no human or model throughput claim",
        authority="none; native metadata requires independent API reconciliation",
        trials=[],
    )
    save(output / "result.json", result)
    for trial in range(3):
        trial_out = output / str(trial)
        trial_out.mkdir()
        measurement = trial_out / "measurement"
        measure.open_measurement(
            measurement,
            measurement_id=f"p{args.parallel}-t{trial}",
            run_id=f"p{args.parallel}-t{trial}",
            scope="all",
            scenario_id="sqlite-hash-eight",
            trial_id=str(trial),
            head=head,
            dirty=dirty,
            target_count=8,
        )
        session = measure.start_span(
            measurement, phase="session", command_id="factory-fixture"
        )
        request = dict(
            schema="factory-admission-request/v1",
            limits=dict(
                parallel=args.parallel,
                features=args.parallel,
                reviewers=0,
                remaining_runs=8,
                remaining_seconds=480,
                ready_limit=8,
                wait_limit_seconds=600,
            ),
            active=[],
            completed=[],
            decision_queue=dict(ready_count=0, mean_review_seconds=None),
            queued=[
                dict(
                    id=f"item-{i}",
                    feature=f"feature-{i}",
                    kind="isolated_prototype",
                    workspace=f"workspace-{i}",
                    dependencies=[],
                    paths=["trial.sqlite"],
                    ports=[],
                    databases=[f"db-{i}"],
                    seeds=[f"seed-{i}"],
                    seconds=60,
                    reviewers=0,
                )
                for i in range(8)
            ],
        )
        started = time.monotonic()
        rows, plans = [], []
        trial_record = dict(status="running", request=request, rows=rows, plans=plans)
        result["trials"].append(trial_record)
        save(output / "result.json", result)
        save(trial_out / "protocol.json", request)
        failure = None
        try:
            with tempfile.TemporaryDirectory(prefix="factory-batch-") as temp:
                roots = {}
                for i in range(8):
                    root = Path(temp) / str(i)
                    skill = root / "sdd/skills/probe"
                    skill.mkdir(parents=True)
                    (skill / "SKILL.md").write_text(
                        "---\nname: probe\ndescription: isolated SQLite and hash fixture\n---\nRun the local fixture.\n"
                    )
                    (skill / "run.py").write_text(PROGRAM)
                    (root / "seed.txt").write_text(str(i))
                    runner.seal(root, "probe", "python3", "run.py", ["check"], [])
                    roots[f"item-{i}"] = root

                def execute(item):
                    begin = time.monotonic()
                    destination = trial_out / item
                    destination.mkdir()
                    record = dict(id=item, outcome="not-run", cleanup=False)
                    save(destination / "record.json", record)
                    span = measure.start_span(
                        measurement,
                        phase="command",
                        command_id="project-skill-trial",
                        parent_span_id=session,
                    )
                    succeeded = False
                    try:
                        record.update(
                            runner.run(
                                roots[item],
                                "probe",
                                "check",
                                timeout=60,
                                inputs=["seed.txt"],
                            )
                        )
                        for relative in (
                            record["observation"],
                            record["stdout"]["path"],
                            record["stderr"]["path"],
                        ):
                            shutil.copyfile(
                                roots[item] / relative,
                                destination / Path(relative).name,
                            )
                        record["fixture_output"] = json.loads(
                            (roots[item] / record["stdout"]["path"]).read_text()
                        )
                        actual = record["fixture_output"]
                        assert actual["seed"] == item.removeprefix("item-")
                        assert (actual["count"], actual["total"]) == (10000, 49995000)
                        assert (
                            record["outcome"] == "passed"
                            and record["cleanup"]
                            and record["directory_cleanup"]
                        )
                        succeeded = True
                        return record
                    except BaseException as error:
                        record["error"] = str(error)
                        raise
                    finally:
                        record.update(
                            started_seconds=begin - started,
                            finished_seconds=time.monotonic() - started,
                        )
                        save(destination / "record.json", record)
                        measure.finish_span(
                            measurement,
                            span,
                            outcome="success" if succeeded else "failure",
                            exit_code=0 if succeeded else 1,
                        )

                while request["queued"]:
                    proposal = admission.plan(request)
                    assert proposal["dispatch_authorized"] is False
                    plans.append(
                        dict(request=json.loads(json.dumps(request)), proposal=proposal)
                    )
                    save(trial_out / f"wave-{len(plans)}.json", plans[-1])
                    selected = proposal["selected"]
                    assert selected and len(selected) <= args.parallel
                    # This explicit benchmark owns only its local fixture items. The proposal is not authority.
                    with ThreadPoolExecutor(max_workers=args.parallel) as pool:
                        rows.extend(pool.map(execute, selected))
                    request["completed"].extend(selected)
                    request["queued"] = [
                        job for job in request["queued"] if job["id"] not in selected
                    ]
                    request["limits"]["remaining_runs"] -= len(selected)
                    request["limits"]["remaining_seconds"] -= 60 * len(selected)
        except BaseException as error:
            failure = error
            trial_record["error"] = str(error)
            raise
        finally:
            measure.finish_span(
                measurement,
                session,
                outcome="success" if failure is None else "failure",
                exit_code=0 if failure is None else 1,
            )
            summary = measure.summarize(measurement)
            save(trial_out / "summary.json", summary)
            events = sorted(
                [(row["started_seconds"], 1) for row in rows]
                + [(row["finished_seconds"], -1) for row in rows]
            )
            active, peak = 0, 0
            for _, delta in events:
                active += delta
                peak = max(peak, active)
            trial_record.update(
                status="success" if failure is None else "failure",
                seconds=time.monotonic() - started,
                peak_wrapper_concurrency=peak if failure is None else None,
                peak_missing_reason="partial worker collection after failure"
                if failure
                else None,
                human_wait=None,
                cost=None,
                cost_reason="provider billing not observed",
            )
            save(output / "result.json", result)
        assert len(rows) == 8 and peak <= args.parallel and not Path(temp).exists()
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(
        json.dumps(
            dict(
                parallel=args.parallel,
                seconds=[r["seconds"] for r in result["trials"]],
                peak_wrapper_concurrency=[
                    r["peak_wrapper_concurrency"] for r in result["trials"]
                ],
            )
        )
    )


if __name__ == "__main__":
    main()
