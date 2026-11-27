#!/usr/bin/env python3
"""The optional recorder preserves real owner verdicts and serialized evidence."""

import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "plugins/sdd-quality-loop/scripts/run_measurement.py"


class OwnerIntegration(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve() / "project"
        (self.root / "tests").mkdir(parents=True)
        helper = self.root / HELPER.relative_to(ROOT)
        helper.parent.mkdir(parents=True)
        shutil.copyfile(HELPER, helper)
        shutil.copyfile(
            ROOT / "tests/verification.py", self.root / "tests/verification.py"
        )
        (self.root / "tests/verification-timings.json").write_text(
            json.dumps({"schema": "ci-suite-timings/v1", "suites": {}})
        )
        catalog = {
            "schema": "verification-catalog/v1",
            "suites": [{"path": "tests/case.tests.py", "runtime": "python"}],
            "profiles": {"fixture": ["tests/case.tests.py"]},
        }
        (self.root / "tests/verification-catalog.json").write_text(json.dumps(catalog))
        spec = importlib.util.spec_from_file_location("measurement", HELPER)
        self.m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.m)

    def run_owner(self, code, measured=False):
        (self.root / "tests/case.tests.py").write_text(
            "raise SystemExit(" + str(code) + ")\n"
        )
        receipt = Path(self.tmp.name).resolve() / (
            "measured.json" if measured else "bare.json"
        )
        argv = [
            sys.executable,
            str(self.root / "tests/verification.py"),
            "--suite",
            "tests/case.tests.py",
            "--run",
            "--receipt",
            str(receipt),
        ]
        directory = Path(self.tmp.name).resolve() / "measurement"
        if measured:
            argv += ["--measure-dir", str(directory)]
        result = subprocess.run(argv, cwd=self.root, capture_output=True)
        return result, json.loads(receipt.read_text()), directory, receipt

    def test_receipt_verdict_and_stdout_preserved(self):
        for code in (0, 3):
            with self.subTest(code=code):
                a, ra, _, _ = self.run_owner(code)
                b, rb, d, r = self.run_owner(code, True)
                for row in ra["results"] + rb["results"]:
                    self.assertGreaterEqual(row.pop("seconds"), 0)
                self.assertEqual(
                    (a.returncode, a.stdout, a.stderr),
                    (b.returncode, b.stdout, b.stderr),
                )
                self.assertEqual(ra, rb)
                summary = self.m.summarize(d, as_of=None)
                self.assertTrue(summary["complete"], summary["diagnostics"])
                self.assertEqual(summary["counts"]["started"], 2)
                self.assertEqual(
                    summary["artifacts"][0]["sha256"],
                    hashlib.sha256(r.read_bytes()).hexdigest(),
                )
                shutil.rmtree(d)

    def test_used_directory_rejected_before_execution(self):
        _, _, directory, _ = self.run_owner(0, True)
        marker = self.root / "marker"
        (self.root / "tests/case.tests.py").write_text(
            'from pathlib import Path\nPath("marker").touch()\n'
        )
        result = subprocess.run(
            [
                sys.executable,
                str(self.root / "tests/verification.py"),
                "--suite",
                "tests/case.tests.py",
                "--run",
                "--measure-dir",
                str(directory),
            ],
            cwd=self.root,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertFalse(marker.exists())

    def test_in_tree_measurement_is_rejected_before_either_runner_executes(self):
        marker = self.root / "marker"
        (self.root / "tests/case.tests.py").write_text('from pathlib import Path\nPath("marker").touch()\n')
        result = subprocess.run([
            sys.executable, str(self.root / "tests/verification.py"),
            "--suite", "tests/case.tests.py", "--run",
            "--measure-dir", str(self.root / "measurements"),
        ], cwd=self.root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertFalse(marker.exists())
        self.assertFalse((self.root / "measurements").exists())

    def test_post_start_failure_does_not_change_owner_exit(self):
        import contextlib
        import io

        observer = self.m.Observer(
            Path(self.tmp.name).resolve() / "broken", command_id="test"
        )
        shutil.rmtree(observer.directory)
        captured = io.StringIO()
        with contextlib.redirect_stderr(captured):
            observer.start("command", "test")
            observer.close(3)
        self.assertEqual(captured.getvalue(), "measurement: incomplete\n")

    def test_measurement_flags_require_run(self):
        (self.root / "tests/case.tests.py").write_text("pass\n")
        for flag in ("--list", "--plan"):
            directory = Path(self.tmp.name).resolve() / "not-created"
            result = subprocess.run(
                [
                    sys.executable,
                    str(self.root / "tests/verification.py"),
                    "--suite",
                    "tests/case.tests.py",
                    flag,
                    "--measure-dir",
                    str(directory),
                ],
                capture_output=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertFalse(directory.exists())


class HistoricalLiteMeasurement(unittest.TestCase):
    """sdd-lite left the distribution in v2.0.0 (Q05): its three measurement
    guarantees stay pinned to the v1.26.0 product and its original tests."""

    # git archive --format=zip v1.26.0 (b193c75be2a6f2e6c7074bb65401f514268a65fb)
    #   tests/run-measurement-integration.tests.py tests/verification.py
    #   plugins/sdd-lite/lib/run-lite-gate.py
    #   plugins/sdd-quality-loop/scripts/{run_measurement,canonicalize-sdd-yaml,validate-capability-summary}.py
    ARCHIVE = ROOT / "tests/fixtures/run-measurement-v1.26.0/lite-measurement.zip"
    SHA256 = "0d7e02f27eade50aac51057a498752502b3512ef1959e183cf022c6709ee4a21"

    @classmethod
    def setUpClass(cls):
        payload = cls.ARCHIVE.read_bytes()
        if hashlib.sha256(payload).hexdigest() != cls.SHA256:
            raise ValueError("v1.26.0 Lite measurement fixture digest mismatch")
        temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve()
        with zipfile.ZipFile(cls.ARCHIVE) as bundle:
            bundle.extractall(root)
        spec = importlib.util.spec_from_file_location(
            "v126_run_measurement_integration", root / "tests/run-measurement-integration.tests.py"
        )
        cls.source = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.source)
        cls.source_root = root

    def run_original(self, method):
        self.assertEqual(self.source.ROOT, self.source_root)
        result = unittest.TestResult()
        self.source.OwnerIntegration(method).run(result)
        self.assertEqual(result.testsRun, 1)
        self.assertTrue(result.wasSuccessful(), result.errors + result.failures)
        self.assertEqual(result.skipped, [])

    def test_in_tree_measurement_is_rejected_before_either_runner_executes(self):
        self.run_original("test_in_tree_measurement_is_rejected_before_either_runner_executes")

    def test_lite_measurement_requires_quality_plugin_before_running(self):
        self.run_original("test_lite_measurement_requires_quality_plugin_before_running")

    def test_lite_pass_failure_and_timeout(self):
        self.run_original("test_lite_pass_failure_and_timeout")


if __name__ == "__main__":
    unittest.main()
