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
JAR_SHA256 = "78f7e2c6bf9a8b65eda665a23e94431255587e0b43a834a4e2af1723562d9b4a"
ACQUIRE = "  mkdir \"$lock_dir\" 2>/dev/null ||\n    fail IDENTITY 'canonical identity ledger reservation is already in progress'"
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
fail() { echo "$*" >&2; exit 1; }
sha256_file() { sha256sum "$1" | cut -d ' ' -f 1; }
"""
        setup += (
            'check_feature_scratch_history() {\n'
            '  touch "${ledger}.${run_id}.ready"\n'
            '  while [ ! -f "${ledger}.release" ]; do sleep 0.01; done\n'
            '}\n'
            if mutated else 'check_feature_scratch_history() { :; }\n'
        )
        script = root / "race.sh"
        script.write_text(setup + tail)
        processes = [
            subprocess.Popen(
                ["bash", str(script), str(ledger), actor, bound],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for actor in ("a", "b")
        ]
        results = []
        try:
            if mutated:
                deadline = time.monotonic() + barrier_timeout
                ready = [root / (ledger.name + "." + actor + ".ready") for actor in ("a", "b")]
                while not all(path.exists() for path in ready):
                    if any(p.poll() is not None for p in processes):
                        raise RuntimeError("negative replay contender exited before synchronization")
                    if time.monotonic() >= deadline:
                        raise TimeoutError("negative replay synchronization timeout")
                    time.sleep(0.01)
                (root / (ledger.name + ".release")).touch()
            for p in processes:
                out, err = p.communicate(timeout=10)
                results.append(
                    {
                        "exit_code": p.returncode,
                        "stdout": out.decode(),
                        "stderr": err.decode(),
                    }
                )
        finally:
            for p in processes:
                if p.poll() is None:
                    p.kill()
                p.communicate()
        return {
            "accepted": sum(r["exit_code"] == 0 for r in results),
            "calls": results,
            "ledger": json.loads(ledger.read_text()),
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jar", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if hashlib.sha256(args.jar.read_bytes()).hexdigest() != JAR_SHA256:
        parser.error("expected pinned TLC v1.8.0 jar SHA-256")
    mapping = json.loads((MODEL / "mapping.json").read_text())
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != mapping["source_sha256"]:
        parser.error("source changed: recheck code/model mapping before updating pin")
    args.output.mkdir(parents=True, exist_ok=False)
    report = {
        "distribution_tag": "v1.8.0",
        "observed_tool_version": None,
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
        (directory / "Reservation.cfg").write_text(
            (MODEL / "Reservation.cfg")
            .read_text()
            .replace("UseLock = TRUE", "UseLock = FALSE")
            if mutated
            else (MODEL / "Reservation.cfg").read_text()
        )
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
        expected = (
            counterexample
            if mutated
            else result.returncode == 0 and "No error has been found" in result.stdout
        )
        replay = real_race(mutated)
        replay_expected = replay["accepted"] == (2 if mutated else 1)
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
