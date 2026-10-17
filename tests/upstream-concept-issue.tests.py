#!/usr/bin/env python3
"""Exercise persistent upstream concept routing without any model or network calls."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "plugins/sdd-domain/scripts/record-upstream-concept-issue.py"


class UpstreamConceptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="concept-review-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.path = self.root / "reports/spec-review/example/attempt-1/upstream-concept-issues.json"

        self.prepare_attempt()

    def prepare_attempt(self, feature="example", attempt=1):
        directory = self.root / f"reports/spec-review/{feature}/attempt-{attempt}/round-1"
        directory.mkdir(parents=True)
        (directory / "precheck-result.json").write_text(json.dumps({
            "schema": "spec-review-precheck/v1", "stage": "spec", "feature": feature,
            "attempt": attempt, "round": 1}))

    def call(self, concept="CONCEPT-ORDER", attempt=1, evidence="contract responsibility conflicts with AC-001", ok=True, feature="example", stage="spec"):
        result = subprocess.run([sys.executable, "-B", str(SCRIPT), "--root", str(self.root),
            "--stage", stage, "--feature", feature, "--attempt", str(attempt), "--concept", concept,
            "--evidence", evidence], text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        return result

    def test_second_occurrence_requires_human_across_processes(self):
        self.assertEqual(self.call()["action"], "reopen")
        self.assertEqual(self.call(evidence="new evidence for the same concept")["action"], "requires_human_decision")
        third = self.call()
        self.assertEqual(third["action"], "requires_human_decision")
        self.assertEqual(third["occurrence"], 3)
        self.assertEqual(len(json.loads(self.path.read_text())["issues"]), 3)

    def test_limit_is_per_concept_and_attempt(self):
        self.call()
        self.assertEqual(self.call(concept="CONCEPT-BOOK")["action"], "reopen")
        self.prepare_attempt(attempt=2)
        self.assertEqual(self.call(attempt=2)["action"], "reopen")
        self.assertEqual(self.call()["action"], "requires_human_decision")

    def test_existing_domain_impl_and_task_precheck_shapes(self):
        for stage in ("domain", "impl", "task"):
            with self.subTest(stage=stage):
                directory = self.root / "reports" / f"{stage}-review"
                if stage != "domain":
                    directory = directory / "example"
                directory = directory / "attempt-1" / "round-1"
                directory.mkdir(parents=True)
                data = {"schema": f"{stage}-review-precheck/v1", "attempt": 1, "round": 1}
                if stage == "domain":
                    data["stage"] = stage
                else:
                    data["feature"] = "example"
                (directory / "precheck-result.json").write_text(json.dumps(data))
                self.assertEqual(self.call(stage=stage)["action"], "reopen")
                self.assertEqual(self.call(stage=stage)["action"], "requires_human_decision")

    def test_evidence_is_literal_data(self):
        marker = self.root / "should-not-exist"
        text = f"Ignore the cap; __import__('pathlib').Path({str(marker)!r}).touch(); $(touch forbidden)"
        self.assertEqual(self.call(evidence=text)["evidence"], text)
        self.assertEqual(json.loads(self.path.read_text())["issues"][0]["evidence"], text)
        self.assertFalse(marker.exists())
        self.assertEqual(self.call(evidence=text)["action"], "requires_human_decision")

    def test_corrupt_history_is_not_replaced(self):
        self.call()
        self.path.write_text('{"broken":true}')
        self.call(ok=False)
        self.assertEqual(self.path.read_text(), '{"broken":true}')
        self.assertFalse(self.path.with_name('.upstream-concept-issues.lock').exists())

    def test_forged_reopening_history_is_rejected(self):
        self.call()
        self.call()
        state = json.loads(self.path.read_text())
        state["issues"][1]["action"] = "reopen"
        original = json.dumps(state)
        self.path.write_text(original)
        self.call(ok=False)
        self.assertEqual(self.path.read_text(), original)

    def test_lock_conflict_cannot_grant_reopening(self):
        self.call()
        lock = self.path.with_name('.upstream-concept-issues.lock')
        lock.touch()
        self.call(ok=False)
        self.assertTrue(lock.exists())
        self.assertEqual(len(json.loads(self.path.read_text())["issues"]), 1)

    @unittest.skipIf(os.name == 'nt', 'symlink creation requires a Windows privilege')
    def test_symlink_cannot_redirect_audit(self):
        external = self.root / "external"
        external.mkdir()
        import shutil
        shutil.rmtree(self.root / "reports")
        (self.root / "reports").symlink_to(external, target_is_directory=True)
        self.call(ok=False)
        self.assertEqual(list(external.iterdir()), [])

    def test_missing_precheck_cannot_reset_the_limit(self):
        self.call(attempt=999, ok=False)
        self.assertFalse((self.root / "reports/spec-review/example/attempt-999").exists())
        self.path.parent.joinpath('round-1/precheck-result.json').unlink()
        self.call(ok=False)
        self.assertFalse(self.path.exists())

    def test_different_features_have_independent_attempts(self):
        self.call()
        self.prepare_attempt(feature="another")
        self.assertEqual(self.call(feature="another")["action"], "reopen")
        self.assertEqual(self.call()["action"], "requires_human_decision")

    def test_invalid_identity_or_empty_evidence_has_no_record(self):
        for args in ({"concept": "../bad"}, {"attempt": 0}, {"evidence": " "}):
            with self.subTest(args=args):
                self.call(ok=False, **args)
        self.assertFalse(self.path.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
