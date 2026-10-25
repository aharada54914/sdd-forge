#!/usr/bin/env python3
"""Real runner to existing contract/bundle, including negative verdict preservation."""

import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


C = module(
    "collector", ROOT / "plugins/sdd-quality-loop/scripts/collect-project-evidence.py"
)
F = module("fixtures", ROOT / "tests/project-skill-observation.tests.py")


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.fixture = F.Contracts()
        self.fixture.setUp()
        self.addCleanup(self.fixture.temp.cleanup)
        self.fixture.task()
        self.fixture.observation.unlink()
        self.root = self.fixture.root
        self.contract = self.root / "contract.json"
        self.original = {
            "task_id": "T-001",
            "feature": "fixture",
            "checks": [
                {
                    "id": "smoke",
                    "required": True,
                    "passes": False,
                    "evidence": "",
                    "waiver_reason": "",
                }
            ],
        }
        self.original["checks"] += [
            {
                "id": name,
                "required": False,
                "passes": False,
                "evidence": "",
                "waiver_reason": "Not applicable to the isolated collector fixture",
            }
            for name in (
                "build",
                "lint",
                "placeholder-scan",
                "task-state-check",
                "typecheck",
                "unit-tests",
            )
        ]
        self.contract.write_text(json.dumps(self.original))
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(
            [
                "git",
                "-C",
                str(self.root),
                "-c",
                "user.name=Fixture",
                "-c",
                "user.email=fixture@example.invalid",
                "commit",
                "-qm",
                "inputs",
            ],
            check=True,
        )

    def collect(self):
        return C.collect(
            self.root, self.contract, self.fixture.task_path, "example", "smoke"
        )

    def test_actual_run_generates_valid_existing_contract_and_bundle(self):
        result = self.collect()
        self.assertTrue(result["contract_valid"], result)
        self.assertTrue(result["bundle_valid"], result)
        self.assertIsNone(result["task_transition"])
        self.assertEqual(json.loads(self.contract.read_text()), self.original)
        generated = json.loads((self.root / result["contract"]).read_text())
        check = generated["checks"][0]
        self.assertTrue(check["required"])
        self.assertTrue(check["passes"])
        evidence = self.root / check["evidence"]
        self.assertIn(b"real invocation", evidence.read_bytes())
        evidence.write_text("tampered")
        checked = subprocess.run(
            [
                "sh",
                str(ROOT / "plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh"),
                str(self.root / result["bundle"]),
                str(self.root),
            ],
            capture_output=True,
        )
        self.assertNotEqual(checked.returncode, 0)

    def test_failed_real_check_is_not_pass(self):
        entry = self.fixture.skill / "run.py"
        entry.write_text("raise SystemExit(3)\n")
        self.fixture.manifest["files"][0]["sha256"] = C.V.digest(entry.read_bytes())
        self.fixture.write_manifest()
        self.fixture.task()
        self.fixture.observation.unlink()
        result = self.collect()
        self.assertEqual(result["execution_outcome"], "failed")
        self.assertFalse(result["contract_valid"])

    def test_wrong_task_and_check_rejected_before_execution(self):
        for key, value in [("task_id", "T-002"), ("checks", [])]:
            changed = dict(self.original)
            changed[key] = value
            self.contract.write_text(json.dumps(changed))
            with self.assertRaises(C.V.Invalid):
                self.collect()
            self.assertFalse(self.fixture.observation.exists())

    def test_tdd_and_critical_are_not_silently_waived(self):
        for extra in ({"required_workflow": "tdd"}, {"risk": "critical"}):
            self.contract.write_text(json.dumps(self.original | extra))
            with self.assertRaises(C.V.Invalid):
                self.collect()
            self.assertFalse(self.fixture.observation.exists())

    def test_existing_evidence_cannot_be_overwritten(self):
        self.collect()
        with self.assertRaises(ValueError):
            self.collect()

    def test_unbounded_timeout_and_nonobject_manifest_rejected(self):
        for timeout in (0, -1, float("nan"), float("inf"), 3601, True):
            with self.assertRaises(C.V.Invalid):
                C.collect(
                    self.root,
                    self.contract,
                    self.fixture.task_path,
                    "example",
                    "smoke",
                    timeout=timeout,
                )
        self.fixture.task_path.write_text("[]")
        with self.assertRaises(C.V.Invalid):
            self.collect()
        self.assertFalse(self.fixture.observation.exists())


if __name__ == "__main__":
    unittest.main()
