#!/usr/bin/env python3
"""Ordinary regression for the real reservation tail; TLC remains explicit opt-in."""

import hashlib
import importlib.util
import json
import os
import shutil
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
    def test_source_mapping_current(self):
        mapping = json.loads((P.MODEL / "mapping.json").read_text())
        self.assertEqual(
            mapping["source_sha256"], hashlib.sha256(P.SOURCE.read_bytes()).hexdigest()
        )
        self.assertIn(P.ACQUIRE, P.reservation_tail())

    @unittest.skipUnless(
        os.name == "posix" and shutil.which("jq") and shutil.which("sha256sum"),
        "POSIX jq/sha256sum replay only",
    )
    def test_mutation_and_baseline(self):
        self.assertEqual(P.real_race(True)["accepted"], 2)
        self.assertEqual(P.real_race(False)["accepted"], 1)

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


if __name__ == "__main__":
    unittest.main()
