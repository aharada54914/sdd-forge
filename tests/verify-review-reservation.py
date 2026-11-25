#!/usr/bin/env python3
"""Opt-in bounded TLC pilot and a two-process real reservation-tail mutation."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "tests/fixtures/project-skills/formal-review-reservation"
SOURCE = ROOT / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
JAR_SHA256 = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
ASSET_ID = 184694200  # GitHub release asset id of tla2tools.jar under tag v1.7.4
ACQUIRE = """  python3 -c 'import os, sys; os.mkdir(sys.argv[1])' "$lock_dir" 2>/dev/null ||
    fail IDENTITY 'canonical identity ledger reservation is already in progress'"""
RELEASE = (
    "  rmdir \"$lock_dir\" ||\n    fail IO 'cannot release identity-ledger reservation'"
)


def reservation_tail():
    source = SOURCE.read_text()
    start = source.index('if $reserve; then\n  lock_dir="$ledger.lock"')
    end = source.index("\nfi\n", start) + 4
    tail = source[start:end]
    if (
        ACQUIRE not in tail
        or RELEASE not in tail
        or '"$bound_ledger_sha256"' not in tail
    ):
        raise ValueError("source mapping stale")
    return tail


def wait_for_barrier(ready, processes, deadline, *, allow_exit=False):
    while True:
        arrived = [path.exists() for path in ready]
        exited = [p.poll() is not None for p in processes]
        if all(arrived):
            return
        unfinished = [done for reached, done in zip(arrived, exited) if not reached]
        if allow_exit and any(arrived) and all(unfinished):
            return
        if (not allow_exit and any(unfinished)) or all(exited):
            raise RuntimeError("replay contender exited before synchronization")
        if time.monotonic() >= deadline:
            raise TimeoutError("replay synchronization timeout")
        time.sleep(0.01)


def real_race(mutated=False, *, barrier_timeout=10):
    if not shutil.which("bash") or not shutil.which("jq"):
        raise ValueError("bash and jq required")
    tail = reservation_tail()
    if mutated:
        tail = tail.replace(ACQUIRE, "  : # negative mutation: lock removed").replace(
            RELEASE, "  : # no lock to release"
        )
    with tempfile.TemporaryDirectory(prefix="reservation-pilot-") as temporary:
        root = Path(temporary)
        ledger = root / "identity-ledger.json"
        ledger.write_text('{"records":[]}\n')
        bound = hashlib.sha256(ledger.read_bytes()).hexdigest()
        setup = """set -euo pipefail
ledger=$1
run_id=$2
bound_ledger_sha256=$3
reserve=true
sequence=1
stage=spec
role=spec-reviewer-a
host_session_id=$run_id
previous_record_sha256=""
record_hash=$run_id
scratch_binding=""
input_binding=""
exec 9>"${ledger}.${run_id}.trace"
BASH_XTRACEFD=9
PS4='+ ${LINENO}: '
set -x
fail() { echo "$*" >&2; exit 1; }
sha256_file() { sha256sum "$1" | cut -d ' ' -f 1; }
check_feature_scratch_history() {
  touch "${ledger}.${run_id}.entered"
  while [ ! -f "${ledger}.release" ]; do sleep 0.01; done
}
touch "${ledger}.${run_id}.ready"
while [ ! -f "${ledger}.start" ]; do sleep 0.01; done
"""
        script = root / "race.sh"
        script.write_text(setup + tail)
        actors = ("a", "b")
        processes = []
        results = []
        try:
            for actor in actors:
                processes.append(
                    subprocess.Popen(
                        ["bash", str(script), str(ledger), actor, bound],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    )
                )
            ready = [root / f"{ledger.name}.{actor}.ready" for actor in actors]
            entered = [root / f"{ledger.name}.{actor}.entered" for actor in actors]
            wait_for_barrier(ready, processes, time.monotonic() + barrier_timeout)
            (root / f"{ledger.name}.start").touch()
            # Hold each real writer after its ledger hash check. In the baseline
            # its peer must finish its attempt before the holder can release.
            wait_for_barrier(entered, processes, time.monotonic() + barrier_timeout, allow_exit=not mutated)
            (root / f"{ledger.name}.release").touch()
            for actor, p in zip(actors, processes):
                out, err = p.communicate(timeout=10)
                results.append(
                    {
                        "actor": actor,
                        "exit_code": p.returncode,
                        "stdout": out.decode(),
                        "stderr": err.decode(),
                    }
                )
        except (RuntimeError, TimeoutError) as error:
            diagnostics = [str(error)]
            for actor in actors:
                trace = root / f"{ledger.name}.{actor}.trace"
                if trace.exists():
                    diagnostics.append(f"actor {actor}, last Bash commands:\n{trace.read_text()[-2000:]}")
            raise type(error)("\n".join(diagnostics)) from error
        finally:
            for p in processes:
                if p.poll() is None:
                    p.kill()
                p.communicate()
        replay = {
            "accepted": sum(r["exit_code"] == 0 for r in results),
            "calls": results,
            "entered": [actor for actor, marker in zip(actors, entered) if marker.exists()],
            "ledger": json.loads(ledger.read_text()),
        }
        if not expected_replay(replay, mutated):
            for call in results:
                call["bash_trace"] = (root / f"{ledger.name}.{call['actor']}.trace").read_text()
        return replay


def expected_replay(replay, mutated):
    accepted = [call["actor"] for call in replay["calls"] if call["exit_code"] == 0]
    if replay["entered"] != accepted:
        return False
    if mutated:
        return len(accepted) == 2
    records = replay["ledger"]["records"]
    refused = [call for call in replay["calls"] if call["exit_code"] != 0]
    return (len(accepted) == 1 and [record["run_id"] for record in records] == accepted
            and len(refused) == 1 and refused[0]["exit_code"] == 1
            and "IDENTITY canonical identity ledger reservation is already in progress" in refused[0]["stderr"])


def expected_tlc_result(result, mutated):
    lines = result.stdout.splitlines()
    if mutated:
        return result.returncode == 12 and "Error: Invariant OneAccepted is violated." in lines
    return result.returncode == 0 and "Model checking completed. No error has been found." in lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jar", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if hashlib.sha256(args.jar.read_bytes()).hexdigest() != JAR_SHA256:
        parser.error("expected pinned TLC v1.7.4 asset 184694200 jar SHA-256")
    mapping = json.loads((MODEL / "mapping.json").read_text())
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != mapping["source_sha256"]:
        parser.error("source changed: recheck code/model mapping before updating pin")
    args.output.mkdir(parents=True, exist_ok=False)
    report = {
        "distribution_tag": "v1.7.4",
        "observed_tool_version": None,
        "tool_asset_id": ASSET_ID,
        "jar_sha256": JAR_SHA256,
        "source_sha256": mapping["source_sha256"],
        "scope": "two contenders, one original ledger hash, one attempt each; no crashes, retries, hostile filesystem or OS-wide proof",
        "runs": [],
    }
    for mutated in (True, False):
        label = "negative" if mutated else "baseline"
        directory = args.output / label
        directory.mkdir()
        shutil.copyfile(MODEL / "Reservation.tla", directory / "Reservation.tla")
        cfg = "Reservation.negative.cfg" if mutated else "Reservation.cfg"
        shutil.copyfile(MODEL / cfg, directory / "Reservation.cfg")
        start = time.monotonic()
        result = subprocess.run(
            [
                "java",
                "-cp",
                str(args.jar.resolve()),
                "tlc2.TLC",
                "-workers",
                "1",
                "-config",
                "Reservation.cfg",
                "Reservation",
            ],
            cwd=directory,
            capture_output=True,
            text=True,
            timeout=60,
        )
        (directory / "tlc.log").write_text(result.stdout + result.stderr)
        report["observed_tool_version"] = (
            result.stdout.splitlines()[0] if result.stdout else None
        )
        counterexample = "Invariant OneAccepted is violated" in result.stdout
        expected = expected_tlc_result(result, mutated)
        replay = real_race(mutated)
        replay_expected = expected_replay(replay, mutated)
        report["runs"].append(
            {
                "case": label,
                "exit_code": result.returncode,
                "seconds": time.monotonic() - start,
                "counterexample": counterexample,
                "expected_result": expected,
                "real_code_replay": replay,
                "replay_expected": replay_expected,
            }
        )
    report["passed"] = all(
        r["expected_result"] and r["replay_expected"] for r in report["runs"]
    )
    (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
