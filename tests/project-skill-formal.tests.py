#!/usr/bin/env python3
"""Ordinary regression for the real reservation tail; TLC remains explicit opt-in."""

import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "pilot", ROOT / "tests/verify-review-reservation.py"
)
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)


class Reservation(unittest.TestCase):
    def test_wrong_tool_bytes_are_rejected_before_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            jar = Path(directory) / "wrong.jar"
            jar.write_bytes(b"not the pinned tool")
            output = Path(directory) / "evidence"
            result = subprocess.run(
                [sys.executable, P.__file__, "--jar", str(jar), "--output", str(output)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("jar SHA-256", result.stderr)
            self.assertFalse(output.exists())

    def test_source_mapping_current(self):
        mapping = json.loads((P.MODEL / "mapping.json").read_text())
        self.assertEqual(
            mapping["source_sha256"], hashlib.sha256(P.SOURCE.read_bytes()).hexdigest()
        )
        tail = P.reservation_tail()
        self.assertEqual(mapping["reservation_tail_sha256"], hashlib.sha256(tail.encode()).hexdigest())
        self.assertIn(P.ACQUIRE, tail)

    def test_negative_model_requires_a_completed_invariant_violation(self):
        message = "Error: Invariant OneAccepted is violated.\n"
        result = subprocess.CompletedProcess([], 12, stdout=message)
        self.assertTrue(P.expected_tlc_result(result, True))
        result.returncode = 1
        self.assertFalse(P.expected_tlc_result(result, True))

    def test_successful_reservation_must_publish_the_winning_actor(self):
        replay = {
            "calls": [{"actor": "a", "exit_code": 0}, {"actor": "b", "exit_code": 1,
                       "stderr": "IDENTITY canonical identity ledger reservation is already in progress"}],
            "entered": ["a"],
            "ledger": {"records": []},
        }
        self.assertFalse(P.expected_replay(replay, False))
        replay["ledger"]["records"] = [{"run_id": "b"}]
        self.assertFalse(P.expected_replay(replay, False))
        replay["ledger"]["records"] = [{"run_id": "a"}]
        self.assertTrue(P.expected_replay(replay, False))
        replay["entered"].append("b")
        self.assertFalse(P.expected_replay(replay, False))

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("jq") and shutil.which("sha256sum"),
        "POSIX jq/sha256sum replay only",
    )
    def test_mutation_and_baseline(self):
        for mutated in (True, False):
            replay = P.real_race(mutated)
            self.assertTrue(P.expected_replay(replay, mutated), replay)
            if not mutated:
                events = replay["trace"]
                winner = {"a": 1, "b": 2}[replay["entered"][0]]
                self.assertEqual([e["action"] for e in events], ["Init", "Acquire", "Check", "Publish", "Release"])
                self.assertEqual([e.get("actor") for e in events], [None] + [winner] * 4)
                self.assertEqual([e["state"]["accepted"] for e in events], [[], [], [], [winner], [winner]])
                self.assertEqual([e["step"] for e in events], list(range(5)))

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("jq") and shutil.which("sha256sum"),
        "POSIX jq/sha256sum replay only",
    )
    def test_delayed_contender_still_reaches_negative_barrier(self):
        original = P.subprocess.Popen
        count = 0
        def delayed(*args, **kwargs):
            nonlocal count
            count += 1
            if count == 2:
                time.sleep(0.8)
            return original(*args, **kwargs)
        with patch.object(P.subprocess, "Popen", side_effect=delayed):
            self.assertEqual(P.real_race(True)["accepted"], 2)

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("jq") and shutil.which("sha256sum"),
        "POSIX jq/sha256sum replay only",
    )
    def test_negative_barrier_timeout_is_reported(self):
        original = P.Path.exists
        def never_ready(path):
            return False if path.name.endswith(".ready") else original(path)
        with patch.object(P.Path, "exists", never_ready):
            with self.assertRaisesRegex(TimeoutError, "synchronization timeout"):
                P.real_race(True, barrier_timeout=0.05)

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("jq") and shutil.which("sha256sum"),
        "POSIX jq/sha256sum replay only",
    )
    def test_spawn_failure_cleans_up_first_contender(self):
        original = P.subprocess.Popen
        started = []
        def failing(*args, **kwargs):
            if started:
                raise OSError("synthetic spawn failure")
            process = original(*args, **kwargs)
            started.append(process)
            return process
        try:
            with patch.object(P.subprocess, "Popen", side_effect=failing):
                with self.assertRaisesRegex(OSError, "synthetic spawn failure"):
                    P.real_race(True)
            self.assertIsNotNone(started[0].poll())
        finally:
            if started and started[0].poll() is None:
                started[0].kill()
                started[0].communicate()


if __name__ == "__main__":
    unittest.main()
