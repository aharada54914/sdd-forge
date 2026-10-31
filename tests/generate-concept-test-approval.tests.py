#!/usr/bin/env python3
"""Real signer CLI -> staged sidecar -> standard validator, with isolated key."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SCRIPTS))
from concept_test_render import render_concept_test_md


class ConceptSignerIntegration(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="concept-signer-")
        self.addCleanup(self.tmp.cleanup)
        self.work = Path(self.tmp.name)
        self.feature = "feature-one"
        self.feature_dir = self.work / "specs" / self.feature
        self.feature_dir.mkdir(parents=True)
        (self.work / "sdd").mkdir()
        (self.work / "sdd/approver-registry.yaml").write_text(
            "schema: sdd-approver-registry/v1\napprovers:\n  - id: alice\n    name: Alice\n",
            encoding="utf-8",
        )
        read_input = self.work / "input.txt"
        read_input.write_text("source bytes\n", encoding="utf-8")
        obj = {
            "schema": "sdd-concept-test/v1",
            "feature": self.feature,
            "proposal": "NEW_CONCEPT_CANDIDATE",
            "rationale": "A distinct responsibility needs review.",
            "relation": "different",
            "decision": "proceed",
            "inputs": [{"path": str(read_input), "sha256": hashlib.sha256(read_input.read_bytes()).hexdigest()}],
        }
        self.content = self.feature_dir / "concept-test.json"
        self.content.write_text(json.dumps(obj) + "\n", encoding="utf-8")
        (self.feature_dir / "concept-test.md").write_bytes(render_concept_test_md(obj))
        self.env = {**os.environ, "HOME": str(self.work), "SDD_CONTEXT_KEY": "isolated-test-key"}
        self.env.pop("SDD_CONTEXT_KEY_FILE", None)

    def run_cli(self, script, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPTS / script), *map(str, args)],
            cwd=self.work, env=self.env, text=True, capture_output=True,
        )

    def sign(self, feature=None):
        return self.run_cli(
            "generate-approval-sidecar.py", "--schema", "sdd-concept-test-approval/v1",
            "--feature", feature or self.feature, "--content", self.content,
            "--approver", "alice", "--status", "Approved",
            "--stage-dir", self.work / "stage",
        )

    def test_real_signer_to_standard_validator(self):
        signed = self.sign()
        self.assertEqual(signed.returncode, 0, signed.stderr)
        target = Path("specs/feature-one/concept-test.approval.json")
        stage_sidecar = self.work / "stage" / target
        data = stage_sidecar.read_bytes()
        self.assertEqual(
            (self.work / "stage/MANIFEST.sha256").read_text(),
            f"{hashlib.sha256(data).hexdigest()}  {target}\n",
        )
        if sys.platform == "win32":
            publisher = [
                shutil.which("pwsh") or "pwsh", "-NoLogo", "-NoProfile", "-File",
                str(SCRIPTS / "apply-human-copy.ps1"), "-StagingDir", str(self.work / "stage"),
                "-Manifest", str(self.work / "stage/MANIFEST.sha256"),
            ]
        else:
            publisher = [
                "bash", str(SCRIPTS / "apply-human-copy.sh"), "--staging-dir", str(self.work / "stage"),
                "--manifest", str(self.work / "stage/MANIFEST.sha256"),
            ]
        published = subprocess.run(
            publisher,
            cwd=self.work, env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(published.returncode, 0, published.stderr + published.stdout)
        live_sidecar = self.work / target
        self.assertEqual(live_sidecar.read_bytes(), data)
        checked = self.run_cli(
            "validate-approval-sidecar.py", "--content", self.content,
            "--sidecar", live_sidecar, "--expected-feature", self.feature,
        )
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertEqual(checked.stdout.strip(), "VALID")
        standalone = self.run_cli(
            "validate-approval-sidecar.py", "--content", self.content,
            "--sidecar", live_sidecar,
        )
        self.assertEqual(standalone.returncode, 0, standalone.stderr)

        mismatch = self.run_cli(
            "validate-approval-sidecar.py", "--content", self.content,
            "--sidecar", live_sidecar, "--expected-feature", "feature-two",
        )
        self.assertEqual(mismatch.returncode, 52, mismatch.stderr)
        self.assertIn("CONCEPT_TEST_FEATURE_MISMATCH", mismatch.stderr)

        misplaced_sidecar = self.work / "other.approval.json"
        misplaced_sidecar.write_bytes(live_sidecar.read_bytes())
        misplaced = self.run_cli(
            "validate-approval-sidecar.py", "--content", self.content,
            "--sidecar", misplaced_sidecar, "--expected-feature", self.feature,
        )
        self.assertEqual(misplaced.returncode, 52, misplaced.stderr)
        misplaced_without_caller = self.run_cli(
            "validate-approval-sidecar.py", "--content", self.content,
            "--sidecar", misplaced_sidecar,
        )
        self.assertEqual(misplaced_without_caller.returncode, 52, misplaced_without_caller.stderr)

        copied_dir = self.work / "specs/feature-two"
        copied_dir.mkdir()
        copied_content = copied_dir / "concept-test.json"
        copied_content.write_bytes(self.content.read_bytes())
        (copied_dir / "concept-test.md").write_bytes((self.feature_dir / "concept-test.md").read_bytes())
        copied_sidecar = copied_dir / "concept-test.approval.json"
        copied_sidecar.write_bytes(live_sidecar.read_bytes())
        copied = self.run_cli(
            "validate-approval-sidecar.py", "--content", copied_content,
            "--sidecar", copied_sidecar, "--expected-feature", "feature-two",
        )
        self.assertEqual(copied.returncode, 52, copied.stderr)
        copied_without_caller = self.run_cli(
            "validate-approval-sidecar.py", "--content", copied_content,
            "--sidecar", copied_sidecar,
        )
        self.assertEqual(copied_without_caller.returncode, 52, copied_without_caller.stderr)

    def test_signer_refuses_wrong_destination_and_unsigned_key(self):
        wrong = self.sign("feature-two")
        self.assertEqual(wrong.returncode, 24, wrong.stderr)
        self.assertFalse((self.work / "stage").exists())
        self.env.pop("SDD_CONTEXT_KEY")
        unsigned = self.sign()
        self.assertEqual(unsigned.returncode, 11, unsigned.stderr)
        self.assertFalse((self.work / "stage").exists())

    def test_signer_refuses_changed_input(self):
        (self.work / "input.txt").write_text("changed source bytes\n", encoding="utf-8")
        refused = self.sign()
        self.assertEqual(refused.returncode, 24, refused.stderr)
        self.assertIn("CONCEPT_TEST_INPUT_HASH_MISMATCH", refused.stderr)
        self.assertFalse((self.work / "stage").exists())

    def test_signer_refuses_content_changed_during_preflight(self):
        path = SCRIPTS / "generate-approval-sidecar.py"
        spec = importlib.util.spec_from_file_location("concept_signer_under_test", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original = module._validate_concept_candidate

        def mutate_after_validation(*args):
            original(*args)
            self.content.write_bytes(self.content.read_bytes() + b" ")

        argv = [
            "--schema", "sdd-concept-test-approval/v1", "--feature", self.feature,
            "--content", str(self.content), "--approver", "alice", "--status", "Approved",
            "--stage-dir", str(self.work / "stage"),
        ]
        old_cwd = os.getcwd()
        old_key = os.environ.get("SDD_CONTEXT_KEY")
        try:
            os.chdir(self.work)
            os.environ["SDD_CONTEXT_KEY"] = self.env["SDD_CONTEXT_KEY"]
            with mock.patch.object(module, "_validate_concept_candidate", side_effect=mutate_after_validation):
                self.assertEqual(module.main(argv), 24)
        finally:
            os.chdir(old_cwd)
            if old_key is None:
                os.environ.pop("SDD_CONTEXT_KEY", None)
            else:
                os.environ["SDD_CONTEXT_KEY"] = old_key
        self.assertFalse((self.work / "stage").exists())


if __name__ == "__main__":
    unittest.main()
