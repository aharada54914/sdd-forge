#!/usr/bin/env python3
"""check-evidence-bundle: relative-root handling and .sh/.ps1 case parity.

The .sh (Python) checker compares identities case-sensitively; the .ps1 port
must reject the same mis-cased inputs (AGENTS.md sweep rule 1). The PowerShell
half runs only where pwsh is installed.
"""

import hashlib
import hmac
import json
import os
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
        self.extra_artifacts = []
        self.extra_files = {}
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
        artifacts = [{"path": p, "sha256": sha(self.root / p)} for p in paths]
        artifacts += [{"path": p, "sha256": "0" * 64} for p in self.extra_artifacts]
        for name, text in self.extra_files.items():
            (self.root / name).write_text(text, encoding="utf-8")
            artifacts.append({"path": name, "sha256": sha(self.root / name)})
        bundle = {
            "quality_report": self.report_name,
            "verification_contract": self.contract_name,
            "git_commit": self.commit,
            "artifacts": artifacts,
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
    """The .ps1 runner is None without pwsh, so each test reports that half as skipped."""
    yield "sh", run_sh
    yield "ps1", run_ps1 if PWSH else None


def canonical(bundle, order="code-point"):
    """Mirror of the v1 signers: Python sorted by code point, PowerShell by UTF-16 unit."""
    def s(v):
        return str(v if v is not None else "").strip()
    key = (lambda p: p.encode("utf-16-be")) if order == "utf-16" else None
    pairs = sorted((str(a.get("path", "")).strip() + "\x00" + str(a.get("sha256", "")).strip().lower()
                    for a in bundle.get("artifacts") or []), key=key)
    digest = hashlib.sha256("\n".join(pairs).encode("utf-8")).hexdigest()
    rv = bundle.get("review_verdict")
    return "\n".join([
        "sdd-evidence-v1", s(bundle.get("task_id")), s(bundle.get("feature")), s(bundle.get("risk")),
        s(bundle.get("required_workflow")), s(bundle.get("spec_revision")), s(bundle.get("git_commit")),
        "true" if bundle.get("git_generated_dirty") is True else "false",
        str(rv.get("verdict", "")).strip() if isinstance(rv, dict) else "", digest,
    ])


class BaselineTests(unittest.TestCase):
    def test_fixture_passes_on_every_runner(self):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            bundle = fx.write()
            for name, run in runners():
                with self.subTest(runner=name):
                    if run is None:
                        self.skipTest("pwsh is not installed; the .ps1 half did not run")
                    result = run(bundle, fx.root, fx.root)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_relative_root_matches_absolute_root(self):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            bundle = fx.write()
            for name, run in runners():
                with self.subTest(runner=name):
                    if run is None:
                        self.skipTest("pwsh is not installed; the .ps1 half did not run")
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
                    if run is None:
                        self.skipTest("pwsh is not installed; the .ps1 half did not run")
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

    def test_signed_fields_must_be_strings(self):
        # Python's str() and PowerShell's [string] render a number, array or
        # object differently, so the signed canonical form would differ.
        for field, value in (("required_workflow", 5), ("required_workflow", ["full"]),
                             ("required_workflow", {"name": "full"}), ("git_commit", 7)):
            with self.subTest(field=field, value=value):
                def mutate(fx):
                    fx.contract["risk"] = "critical"
                    fx.bundle.update({
                        "risk": "critical", "spec_revision": "a" * 64, "build_env": {"os": "linux"},
                        "review_verdict": {"verdict": "PASS"},
                        "signature": {"alg": "hmac-sha256", "value": "ab"},
                    })
                    fx.bundle[field] = value
                self.assert_rejected(mutate, "critical bundle field %s must be a string" % field)

    def test_upper_case_risk_is_not_a_provenance_tier(self):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            fx.bundle["risk"] = "HIGH"
            bundle = fx.write()
            for name, run in runners():
                with self.subTest(runner=name):
                    if run is None:
                        self.skipTest("pwsh is not installed; the .ps1 half did not run")
                    result = run(bundle, fx.root, fx.root)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class StrictValueTests(unittest.TestCase):
    """Values the Python checker reads strictly; the .ps1 port must not coerce them."""

    def assert_absent(self, mutate, message, sign=False, order="code-point"):
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            mutate(fx)
            bundle = fx.write()
            if sign:
                data = json.loads(bundle.read_text(encoding="utf-8"))
                data["signature"]["value"] = hmac.new(b"parity-key", canonical(data, order).encode("utf-8"),
                                                      hashlib.sha256).hexdigest()
                bundle.write_text(json.dumps(data), encoding="utf-8")
            for name, run in runners():
                with self.subTest(runner=name):
                    if run is None:
                        self.skipTest("pwsh is not installed; the .ps1 half did not run")
                    result = run(bundle, fx.root, fx.root)
                    # The final verdict line proves the checker ran to the end.
                    self.assertIn("Evidence bundle FAILED for task T-1:", result.stdout)
                    self.assertNotIn(message, result.stdout + result.stderr)

    @staticmethod
    def critical(fx, dirty):
        fx.contract["risk"] = "critical"
        fx.bundle.update({
            "risk": "critical", "spec_revision": "a" * 64, "build_env": {"os": "linux"},
            "review_verdict": {"verdict": "PASS"}, "git_generated_dirty": dirty,
            "signature": {"alg": "hmac-sha256", "value": "00"},
        })

    def test_string_true_is_not_a_dirty_tree(self):
        self.assert_absent(lambda fx: self.critical(fx, "true"), "dirty working tree")

    def test_string_false_signs_as_clean(self):
        os.environ["SDD_EVIDENCE_KEY"] = "parity-key"
        self.addCleanup(os.environ.pop, "SDD_EVIDENCE_KEY", None)
        for message in ("HMAC mismatch", "cannot be verified", "null-valued"):
            self.assert_absent(lambda fx: self.critical(fx, "false"), message, sign=True)

    def test_either_v1_signer_order_verifies_on_both_runners(self):
        # U+E000 sorts before U+1F4C4 by code point but after it by UTF-16 unit.
        os.environ["SDD_EVIDENCE_KEY"] = "parity-key"
        self.addCleanup(os.environ.pop, "SDD_EVIDENCE_KEY", None)
        def mutate(fx):
            self.critical(fx, False)
            fx.extra_files = {"\ue000.txt": "private use\n", "\U0001f4c4.txt": "page\n"}
        for order in ("code-point", "utf-16"):
            with self.subTest(order=order):
                self.assert_absent(mutate, "HMAC mismatch", sign=True, order=order)

    def test_wrong_key_still_fails_the_signature(self):
        os.environ["SDD_EVIDENCE_KEY"] = "another-key"
        self.addCleanup(os.environ.pop, "SDD_EVIDENCE_KEY", None)
        with tempfile.TemporaryDirectory() as base:
            fx = Fixture(base)
            self.critical(fx, True)
            bundle = fx.write()
            data = json.loads(bundle.read_text(encoding="utf-8"))
            data["signature"]["value"] = hmac.new(b"parity-key", canonical(data).encode("utf-8"),
                                                  hashlib.sha256).hexdigest()
            bundle.write_text(json.dumps(data), encoding="utf-8")
            for name, run in runners():
                with self.subTest(runner=name):
                    if run is None:
                        self.skipTest("pwsh is not installed; the .ps1 half did not run")
                    output = run(bundle, fx.root, fx.root).stdout
                    self.assertIn("critical bundle signature is invalid (HMAC mismatch)", output)
                    self.assertIn("dirty working tree", output)

    def test_kelvin_sign_is_not_a_drive_letter(self):
        def mutate(fx):
            fx.extra_artifacts = ["\u212a:x.txt"]
        self.assert_absent(mutate, "is an absolute path")


if __name__ == "__main__":
    unittest.main()
