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

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "plugins/sdd-quality-loop/scripts/run_measurement.py"


class OwnerIntegration(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "project"
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
        receipt = Path(self.tmp.name) / ("measured.json" if measured else "bare.json")
        argv = [
            sys.executable,
            str(self.root / "tests/verification.py"),
            "--suite",
            "tests/case.tests.py",
            "--run",
            "--receipt",
            str(receipt),
        ]
        directory = Path(self.tmp.name) / "measurement"
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

    def test_lite_pass_failure_and_timeout(self):
        scripts = self.root / "scripts"
        scripts.mkdir()
        for name, body in [
            ("pass", "exit 0"),
            ("fail", "exit 3"),
            ("timeout", "sleep 5"),
        ]:
            (scripts / (name + ".sh")).write_text(body + "\n")
            (scripts / (name + ".ps1")).write_text("exit 0\n")
            argv = [
                sys.executable,
                str(ROOT / "plugins/sdd-lite/lib/run-lite-gate.py"),
                "--repo-root",
                str(self.root),
                "--runtime",
                "posix",
                "--enforcement",
                "none",
                "--check",
                name,
                "--timeout",
                "0.05",
            ]
            bare = subprocess.run(argv, capture_output=True)
            directory = Path(self.tmp.name) / ("lite-" + name)
            measured = subprocess.run(
                argv + ["--measure-dir", str(directory)], capture_output=True
            )
            self.assertEqual(bare.returncode, measured.returncode)
            self.assertEqual(bare.stderr, measured.stderr)
            a, b = json.loads(bare.stdout), json.loads(measured.stdout)
            for payload in (a, b):
                payload.pop("recorded_at")
                for check in payload["checks"]:
                    check.pop("duration_ms")
            self.assertEqual(a, b)
            summary = self.m.summarize(directory, as_of=None)
            gate = next(s for s in summary["spans"] if s["phase"] == "gate")
            self.assertEqual(
                gate["outcome"],
                {"pass": "success", "fail": "failure", "timeout": "timeout"}[name],
            )

    def test_post_start_failure_does_not_change_owner_exit(self):
        import contextlib
        import io

        observer = self.m.Observer(Path(self.tmp.name) / "broken", command_id="test")
        shutil.rmtree(observer.directory)
        captured = io.StringIO()
        with contextlib.redirect_stderr(captured):
            observer.start("command", "test")
            observer.close(3)
        self.assertEqual(captured.getvalue(), "measurement: incomplete\n")

    def test_measurement_flags_require_run(self):
        (self.root / "tests/case.tests.py").write_text("pass\n")
        for flag in ("--list", "--plan"):
            directory = Path(self.tmp.name) / "not-created"
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


if __name__ == "__main__":
    unittest.main()
