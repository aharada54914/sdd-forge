#!/usr/bin/env python3
"""Original-path launch checks for provenance review receipts."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil
import uuid

REPO = Path(__file__).resolve().parents[1]
MODULE_SPEC = importlib.util.spec_from_file_location(
    "receipt", REPO / "plugins/sdd-review-loop/scripts/task-prior-pass-receipt.py")
receipt = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(receipt)


class ReceiptLaunchTests(unittest.TestCase):
    def test_provenance_launch_rejects_missing_receipt(self):
        feature = "receipt-fixture-" + uuid.uuid4().hex
        with tempfile.TemporaryDirectory(prefix="sdd-receipt-launch-") as temp:
            root = Path(temp)
            report = root / "reports/task-review" / feature / "attempt-2/round-1/precheck-result.json"
            report.parent.mkdir(parents=True)
            report.write_text(json.dumps({"provenance_rereview": True}))
            command = ["python3", str(REPO / "plugins/sdd-review-loop/scripts/task-prior-pass-receipt.py"),
                       "--root", str(root), "--feature", feature, "--attempt", "2",
                       "--verify", str(report.relative_to(root))]
            result = subprocess.run(command, cwd=REPO, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("missing prior-PASS receipt", result.stdout + result.stderr)
            report.write_text(json.dumps({"provenance_rereview": False, "prior_pass_receipt": None}))
            result = subprocess.run(command, cwd=REPO, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class ReceiptUnitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sdd-receipt-unit-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.feature = "fixture"
        self.source = "reports/task-review/fixture/attempt-1/round-1/task-review-contract.json"
        self.verdict_path = self.source.replace("task-review-contract", "integrated-verdict")
        self.contract = {"schema": "task-review-contract/v1", "feature": "fixture", "stage": "task",
                         "attempt": 1, "round": 1, "run_id": "fixture-only", "verdict": "PASS",
                         "reviewer_a_verdict": "PASS", "reviewer_b_verdict": "PASS",
                         "findings_critical": 0, "findings_major": 0, "findings_minor": 0,
                         "layer_sha256": {}}
        self.verdict = dict(self.contract, schema="integrated-verdict/v1")
        rows = []
        for name, field in (("tasks", "tasks"), ("requirements", "requirements"),
                            ("acceptance-tests", "acceptance"), ("design", "design"),
                            ("traceability", "traceability")):
            path = f"specs/fixture/{name}.md"
            sha = self.put(path, name.encode())
            self.contract[field + "_sha256"] = sha
            rows.append({"path": path, "sha256": sha})
        for name in ("frontend-spec.md", "infra-spec.md", "security-spec.md", "ux-spec.md"):
            path = "specs/fixture/" + name
            sha = self.put(path, name.encode())
            self.contract["layer_sha256"][name] = sha
            rows.append({"path": path, "sha256": sha})
        for path in ("plugins/sdd-review-loop/references/reviewer-calibration.md",
                     "plugins/sdd-quality-loop/references/risk-gate-matrix.md",
                     "plugins/sdd-quality-loop/references/risk-classification-policy.md"):
            rows.append({"path": path, "sha256": self.put(path, path.encode())})
        self.contract["reviewers"] = [{"role": role, "allowed_input_manifest": list(rows)}
                                      for role in ("task-reviewer-a", "task-reviewer-b")]
        self.save()

    def put(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        return hashlib.sha256(content).hexdigest()

    def save(self):
        self.put(self.source, json.dumps(self.contract).encode())
        self.put(self.verdict_path, json.dumps(self.verdict).encode())

    def build(self):
        return receipt.build(self.root, self.feature, 2)

    def test_same_inputs_have_exact_source_hashes_without_new_verdict(self):
        result = self.build()
        self.assertTrue(result["all_inputs_unchanged"])
        self.assertEqual(result["contract"]["sha256"], receipt.digest((self.root / self.source).read_bytes()))
        self.assertEqual(result["verdict"]["sha256"], receipt.digest((self.root / self.verdict_path).read_bytes()))
        self.assertNotIn("PASS", result.values())

    def test_each_changed_input_prevents_identity_claim(self):
        for row in self.build()["bindings"]:
            with self.subTest(path=row["path"]):
                target = self.root / row["path"]
                before = target.read_bytes()
                target.write_bytes(before + b"changed")
                result = self.build()
                self.assertFalse(result["all_inputs_unchanged"])
                self.assertEqual([r["path"] for r in result["bindings"] if not r["unchanged"]], [row["path"]])
                target.write_bytes(before)

    def test_wrong_identity_nonpass_and_mismatch_rejected(self):
        for field, value in (("feature", "other"), ("attempt", 2), ("round", 2),
                             ("stage", "impl"), ("verdict", "NEEDS_WORK"), ("run_id", "other"),
                             ("findings_major", 1), ("reviewer_b_verdict", "NEEDS_WORK")):
            with self.subTest(field=field):
                before = self.contract[field]
                self.contract[field] = value
                self.save()
                with self.assertRaises(ValueError):
                    self.build()
                self.contract[field] = before
                self.save()

    def test_current_future_and_substituted_sources_rejected(self):
        for source in (self.source.replace("attempt-1", "attempt-2"),
                       self.source.replace("attempt-1", "attempt-3"),
                       self.source.replace("fixture", "other"), "../outside.json"):
            with self.subTest(source=source), self.assertRaises(ValueError):
                receipt.build(self.root, self.feature, 2, source)
        target = self.root / self.source
        original = target.read_bytes()
        target.unlink()
        elsewhere = self.root / "other.json"
        elsewhere.write_bytes(original)
        target.symlink_to(elsewhere)
        with self.assertRaises(ValueError):
            self.build()

    def test_verdict_counts_require_integers(self):
        for field in ("findings_critical", "findings_major", "findings_minor"):
            for value in (False, 0.0):
                with self.subTest(field=field, value=repr(value)):
                    self.verdict[field] = value
                    self.save()
                    with self.assertRaises(ValueError):
                        self.build()
                    self.verdict[field] = 0
                    self.save()

    def test_missing_and_duplicate_json_rejected(self):
        target = self.root / self.source
        target.unlink()
        with self.assertRaises(OSError):
            self.build()
        target.write_text('{"schema": "task-review-contract/v1", "schema": "other"}')
        with self.assertRaises(ValueError):
            self.build()

    def test_launch_rejects_stale_or_modified_receipt(self):
        result = self.build()
        path = "reports/task-review/fixture/attempt-2/round-1/precheck-result.json"
        precheck = {"provenance_rereview": True, "prior_pass_receipt": result}
        self.put(path, json.dumps(precheck).encode())
        command = ["python3", str(REPO / "plugins/sdd-review-loop/scripts/task-prior-pass-receipt.py"),
                   "--root", str(self.root), "--feature", "fixture", "--attempt", "2", "--verify", path]
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
        for field, value in (("all_inputs_unchanged", 1), ("source_attempt", True)):
            with self.subTest(type_confusion=field):
                saved = result[field]
                result[field] = value
                self.put(path, json.dumps(precheck).encode())
                self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
                result[field] = saved
        for field in ("sha256", "path"):
            with self.subTest(field=field):
                saved = result["contract"][field]
                result["contract"][field] = "wrong"
                self.put(path, json.dumps(precheck).encode())
                self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
                result["contract"][field] = saved
        self.put(path, json.dumps(precheck).encode())
        self.put(self.source, (self.root / self.source).read_bytes() + b" ")
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

    def test_launch_rejects_receipt_regenerated_after_input_change(self):
        target = self.root / "specs/fixture/tasks.md"
        target.write_bytes(target.read_bytes() + b"changed")
        result = self.build()
        self.assertFalse(result["all_inputs_unchanged"])
        path = "reports/task-review/fixture/attempt-2/round-1/precheck-result.json"
        self.put(path, json.dumps({"provenance_rereview": True,
                                   "prior_pass_receipt": result}).encode())
        command = ["python3", str(REPO / "plugins/sdd-review-loop/scripts/task-prior-pass-receipt.py"),
                   "--root", str(self.root), "--feature", "fixture", "--attempt", "2", "--verify", path]
        completed = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("inputs changed", completed.stderr)


if __name__ == "__main__":
    unittest.main()
