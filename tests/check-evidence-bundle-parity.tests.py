#!/usr/bin/env python3
"""check-evidence-bundle: relative-root handling and .sh/.ps1 case parity.

The .sh (Python) checker compares identities case-sensitively; the .ps1 port
must reject the same mis-cased inputs (AGENTS.md sweep rule 1). The PowerShell
half runs only where pwsh is installed.
"""

import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
SH = SCRIPTS / "check-evidence-bundle.sh"
PS1 = SCRIPTS / "check-evidence-bundle.ps1"
PWSH = shutil.which("pwsh")
BASELINE = ("lint", "typecheck", "unit-tests", "build", "placeholder-scan", "task-state-check")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Fixture:
    """A git repository holding one passing T-1 evidence bundle."""

    def __init__(self, base):
        self.root = pathlib.Path(base) / "repo"
        (self.root / "qg").mkdir(parents=True)
        self.report_name = "qg/T-1.md"
        self.contract_name = "qg/T-1.contract.json"
        self.bundle_name = "T-1.evidence.json"
        self.report = {"task": "Task ID: T-1", "feature": "Feature: foo"}
        self.contract = {"task_id": "T-1", "feature": "foo", "checks": []}
        for check_id in BASELINE:
            log = self.root / "qg" / (check_id + ".log")
            log.write_text(check_id + " ok\n", encoding="utf-8")
            self.contract["checks"].append({
                "id": check_id, "required": True, "passes": True,
                "evidence": "qg/" + log.name,
            })
        self.bundle = {"task_id": "T-1", "feature": "foo"}
        git = ["git", "-C", str(self.root)]
        subprocess.run(git + ["init", "-q"], check=True)
        (self.root / "README").write_text("fixture\n", encoding="utf-8")
        subprocess.run(git + ["add", "README"], check=True)
        subprocess.run(git + ["-c", "user.name=t", "-c", "user.email=t@example.invalid",
                              "commit", "-qm", "fixture"], check=True)
        self.commit = subprocess.run(git + ["rev-parse", "HEAD"], capture_output=True,
                                     text=True, check=True).stdout.strip()

    def write(self):
        report = self.root / self.report_name
        report.write_text("# QG\n\n" + self.report["task"] + "\n" + self.report["feature"]
                          + "\nVERDICT: PASS\n", encoding="utf-8")
        contract = self.root / self.contract_name
        contract.write_text(json.dumps(self.contract), encoding="utf-8")
        paths = [self.report_name, self.contract_name]
        paths += [c["evidence"] for c in self.contract["checks"]]
        bundle = {
            "quality_report": self.report_name,
            "verification_contract": self.contract_name,
            "git_commit": self.commit,
            "artifacts": [{"path": p, "sha256": sha(self.root / p)} for p in paths],
        }
        bundle.update(self.bundle)
        path = self.root / self.bundle_name
        path.write_text(json.dumps(bundle), encoding="utf-8")
        return path


def run_sh(bundle, root, cwd):
    return subprocess.run(["sh", str(SH), str(bundle), str(root)], cwd=cwd,
                          capture_output=True, text=True)


def run_ps1(bundle, root, cwd):
    return subprocess.run([PWSH, "-NoProfile", "-File", str(PS1), "-BundlePath", str(bundle),
                           "-RepoRoot", str(root)], cwd=cwd, capture_output=True, text=True)


def runners():
    yield "sh", run_sh
    if PWSH:
        yield "ps1", run_ps1


class BaselineTests(unittest.TestCase):
    def test_fixture_passes_on_every_runner(self):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            bundle = fx.write()
            for name, run in runners():
                with self.subTest(runner=name):
                    result = run(bundle, fx.root, fx.root)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_relative_root_matches_absolute_root(self):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            bundle = fx.write()
            for name, run in runners():
                with self.subTest(runner=name):
                    result = run(bundle, "repo", base)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class MisCasedInputTests(unittest.TestCase):
    """Each case mutates the passing fixture with an upper-case variant."""

    def assert_rejected(self, mutate, message):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            mutate(fx)
            bundle = fx.write()
            for name, run in runners():
                with self.subTest(runner=name):
                    result = run(bundle, fx.root, fx.root)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn(message, result.stdout + result.stderr)

    def test_task_id_pattern(self):
        def mutate(fx):
            fx.bundle["task_id"] = "t-1"
            fx.bundle_name = "t-1.evidence.json"
        self.assert_rejected(mutate, "task_id is invalid: t-1")

    def test_feature_pattern(self):
        def mutate(fx):
            fx.bundle["feature"] = "Foo"
            fx.contract["feature"] = "Foo"
            fx.report["feature"] = "Feature: Foo"
        self.assert_rejected(mutate, "feature is invalid: Foo")

    def test_bundle_filename(self):
        def mutate(fx):
            fx.bundle_name = "T-1.evidence.JSON"
        self.assert_rejected(mutate, "bundle filename does not match task_id")

    def test_report_task_id_line(self):
        def mutate(fx):
            fx.report["task"] = "task id: T-1"
        self.assert_rejected(mutate, "quality_report missing Task ID: T-1")

    def test_report_extension(self):
        def mutate(fx):
            fx.report_name = "qg/T-1.MD"
        self.assert_rejected(mutate, "quality_report must point to a markdown report")

    def test_contract_extension(self):
        def mutate(fx):
            fx.contract_name = "qg/T-1.CONTRACT.JSON"
        self.assert_rejected(mutate, "verification_contract must point to a contract JSON file")

    def test_contract_task_id(self):
        def mutate(fx):
            fx.contract["task_id"] = "t-1"
        self.assert_rejected(mutate, "verification_contract task_id mismatch")

    def test_contract_feature(self):
        def mutate(fx):
            fx.contract["feature"] = "FOO"
        self.assert_rejected(mutate, "verification_contract feature mismatch")

    def test_contract_risk(self):
        def mutate(fx):
            fx.contract["risk"] = "HIGH"
            fx.bundle["risk"] = "high"
        self.assert_rejected(mutate, "bundle risk 'high' != contract risk 'HIGH'")

    def test_signature_algorithm(self):
        def mutate(fx):
            fx.contract["risk"] = "critical"
            fx.bundle.update({
                "risk": "critical", "spec_revision": "a" * 64, "build_env": {"os": "linux"},
                "review_verdict": {"verdict": "PASS"},
                "signature": {"alg": "HMAC-SHA256", "value": "ab"},
            })
        self.assert_rejected(mutate, "unsupported signature alg: HMAC-SHA256")

    def test_upper_case_risk_is_not_a_provenance_tier(self):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            fx.bundle["risk"] = "HIGH"
            bundle = fx.write()
            for name, run in runners():
                with self.subTest(runner=name):
                    result = run(bundle, fx.root, fx.root)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
