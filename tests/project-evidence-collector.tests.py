#!/usr/bin/env python3
"""Real runner to existing contract/bundle, including negative verdict preservation."""

import importlib.util
import json
import os
import copy
from pathlib import Path
import subprocess
import tempfile
import sys
import unittest
from unittest.mock import patch

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

    def test_replaced_failed_observation_cannot_be_promoted_to_pass(self):
        entry = self.fixture.skill / "run.py"
        entry.write_text("raise SystemExit(3)\n")
        self.fixture.manifest["files"][0]["sha256"] = C.V.digest(entry.read_bytes())
        self.fixture.write_manifest()
        self.fixture.task()
        self.fixture.observation.unlink()
        actual = C.RUNNER.run

        def replace_observation(*args, **kwargs):
            result = actual(*args, **kwargs)
            observed = self.root / result["observation"]
            value = json.loads(observed.read_text())
            value.update(outcome="passed", exit_code=0)
            observed.write_text(json.dumps(value))
            return result

        with patch.object(C.RUNNER, "run", side_effect=replace_observation):
            with self.assertRaisesRegex(C.V.Invalid, "observation-execution-mismatch"):
                self.collect()
        self.assertFalse(list(self.root.rglob("T-001.contract.json")))

    def test_wrong_task_and_check_rejected_before_execution(self):
        for key, value in [("task_id", "T-002"), ("checks", [])]:
            changed = dict(self.original)
            changed[key] = value
            self.contract.write_text(json.dumps(changed))
            with self.assertRaises(C.V.Invalid):
                self.collect()
            self.assertFalse(self.fixture.observation.exists())

    def test_tdd_and_critical_are_not_silently_waived(self):
        for extra in ({"risk": "high"}, {"risk": "critical"}):
            self.contract.write_text(json.dumps(self.original | extra))
            with self.assertRaises(C.V.Invalid):
                self.collect()
            self.assertFalse(self.fixture.observation.exists())

    def setup_tdd(self):
        self.fixture.manifest["checks"] = ["unit-tests"]
        entry = self.fixture.skill / "run.py"
        entry.write_text("from pathlib import Path\nassert Path('implementation.txt').read_text() == 'green'\nprint('actual green')\n")
        self.fixture.manifest["files"][0]["sha256"] = C.V.digest(entry.read_bytes())
        self.fixture.write_manifest()
        self.fixture.task()
        self.fixture.observation.unlink()
        implementation = self.root / "implementation.txt"
        implementation.write_text("red")
        doc = self.fixture.task_doc
        doc["allowed_inputs"].append({"path": "implementation.txt", "sha256": C.V.digest(b"red")})
        self.fixture.task_path.write_text(json.dumps(doc))
        self.original["required_workflow"] = "tdd"
        self.original["checks"] = [c for c in self.original["checks"] if c["id"] != "unit-tests"]
        self.original["checks"][0]["id"] = "unit-tests"
        self.contract.write_text(json.dumps(self.original))

        def transition(red):
            self.assertEqual(red["outcome"], "failed")
            implementation.write_text("green")
            green = copy.deepcopy(doc)
            green["run_id"] = "run2"
            green["allowed_outputs"] = ["output/", "reports/project-skill-observations/T-001/run2/"]
            green["allowed_inputs"][-1]["sha256"] = C.V.digest(b"green")
            target = self.root / "green-input.json"
            target.write_text(json.dumps(green))
            return target
        return transition

    def tdd(self, transition, **kwargs):
        return C.collect(self.root, self.contract, self.fixture.task_path, "example", "unit-tests",
                         tdd_transition=transition, tdd_sources=["implementation.txt"], **kwargs)

    def test_original_red_and_green_are_in_the_hash_bound_bundle(self):
        result = self.tdd(self.setup_tdd())
        self.assertTrue(result["contract_valid"], result)
        self.assertTrue(result["bundle_valid"], result)
        contract = json.loads((self.root / result["contract"]).read_text())
        check = contract["checks"][0]
        log = self.root / check["evidence"]
        raw = log.read_bytes()
        self.assertIn(b"red:observation", raw)
        self.assertIn(b"AssertionError", raw)
        self.assertIn(b"green:observation", raw)
        self.assertIn(b"actual green", raw)
        self.assertEqual(check["red_evidence"], check["evidence"])
        log.write_bytes(raw.replace(b"AssertionError", b"fabricated"))
        check_result = subprocess.run(["sh", str(C.HERE / "check-evidence-bundle.sh"),
                                       str(self.root / result["bundle"]), str(self.root)], capture_output=True)
        self.assertNotEqual(check_result.returncode, 0)

    def test_cli_live_red_then_green_handoff(self):
        transition = self.setup_tdd()
        process = subprocess.Popen([
            sys.executable, str(C.HERE / "collect-project-evidence.py"),
            "--execution-root", str(self.root), "--contract", str(self.contract),
            "--task-input-manifest", str(self.fixture.task_path), "--skill", "example",
            "--check", "unit-tests", "--tdd-input-stdin", "--tdd-source", "implementation.txt",
        ], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            line = json.loads(process.stdout.readline())
            red = json.loads((self.root / line["red_observation"]).read_text())
            green = transition(red)
            stdout, stderr = process.communicate(str(green) + "\n", timeout=15)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertTrue(json.loads(stdout)["bundle_valid"])
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()

    def test_timeout_is_retained_but_cannot_be_red(self):
        transition = self.setup_tdd()
        entry = self.fixture.skill / "run.py"
        entry.write_text("import time\ntime.sleep(10)\n")
        self.fixture.manifest["files"][0]["sha256"] = C.V.digest(entry.read_bytes())
        self.fixture.write_manifest()
        task = self.fixture.task_doc
        for item in task["allowed_inputs"]:
            item["sha256"] = C.V.digest((self.root / item["path"]).read_bytes())
        self.fixture.task_path.write_text(json.dumps(task))
        with self.assertRaisesRegex(C.V.Invalid, "tdd-red-must-be-real-failure"):
            self.tdd(transition, timeout=0.1)
        observations = list((self.root / "reports/project-skill-observations/T-001/run1").glob("unit-tests.json"))
        self.assertEqual(len(observations), 1)
        self.assertFalse(list(self.root.rglob("T-001.contract.json")))

    def test_missing_red_is_rejected(self):
        self.setup_tdd()
        with self.assertRaisesRegex(C.V.Invalid, "tdd-requires-original"):
            self.tdd(None)

    def test_same_run_cannot_be_green(self):
        transition = self.setup_tdd()
        def change(red):
            p = transition(red)
            doc = json.loads(p.read_text())
            doc["run_id"] = "run1"
            p.write_text(json.dumps(doc))
            return p
        with self.assertRaisesRegex(C.V.Invalid, "tdd-identity-mismatch"):
            self.tdd(change)

    def test_green_cannot_widen_output_grants(self):
        transition = self.setup_tdd()
        def change(red):
            path = transition(red)
            doc = json.loads(path.read_text())
            doc["allowed_outputs"].append("unrelated/")
            path.write_text(json.dumps(doc))
            return path
        with self.assertRaisesRegex(C.V.Invalid, "tdd-output-lineage-mismatch"):
            self.tdd(change)

    def test_changed_test_cannot_be_green(self):
        transition = self.setup_tdd()
        def change(red):
            p = transition(red)
            self.fixture.manifest["args"] = ["changed"]
            self.fixture.write_manifest()
            return p
        with self.assertRaisesRegex(C.V.Invalid, "tdd-input-lineage-mismatch"):
            self.tdd(change)

    def test_passing_red_cannot_start_transition(self):
        transition = self.setup_tdd()
        (self.root / "implementation.txt").write_text("green")
        doc = self.fixture.task_doc
        doc["allowed_inputs"][-1]["sha256"] = C.V.digest(b"green")
        self.fixture.task_path.write_text(json.dumps(doc))
        with self.assertRaisesRegex(C.V.Invalid, "tdd-red-must-be-real-failure"):
            self.tdd(transition)

    def test_test_replacement_after_lineage_admission_is_rejected(self):
        transition = self.setup_tdd()
        original_execute = C.execute
        calls = 0
        def replace(*args, **kwargs):
            nonlocal calls
            calls += 1
            if calls == 2:
                entry = self.fixture.skill / "run.py"
                entry.write_text("print('replacement test')\n")
                self.fixture.manifest["files"][0]["sha256"] = C.V.digest(entry.read_bytes())
                self.fixture.write_manifest()
                task_path = Path(args[1])
                task = json.loads(task_path.read_text())
                for item in task["allowed_inputs"]:
                    item["sha256"] = C.V.digest((self.root / item["path"]).read_bytes())
                task_path.write_text(json.dumps(task))
            return original_execute(*args, **kwargs)
        with patch.object(C, "execute", side_effect=replace):
            with self.assertRaisesRegex(C.V.Invalid, "tdd-admission-changed"):
                self.tdd(transition)
        self.assertFalse(list(self.root.rglob("T-001.contract.json")))

    def test_transition_cannot_expose_signing_environment_to_green(self):
        transition = self.setup_tdd()
        def change(red):
            path = transition(red)
            os.environ["SDD_EVIDENCE_KEY"] = "synthetic-only"
            return path
        with patch.dict(os.environ):
            with self.assertRaisesRegex(C.V.Invalid, "execution-must-not-inherit-signing-key"):
                self.tdd(change)
        self.assertFalse(list(self.root.rglob("T-001.contract.json")))

    def test_transition_cannot_switch_runtime_to_passing_shim(self):
        transition = self.setup_tdd()
        def change(red):
            path = transition(red)
            directory = self.root / "fake-bin"
            directory.mkdir()
            shim = directory / "python3"
            shim.write_text("#!/bin/sh\nexit 0\n")
            shim.chmod(0o755)
            os.environ["PATH"] = str(directory) + os.pathsep + os.environ["PATH"]
            return path
        with patch.dict(os.environ):
            with self.assertRaisesRegex(C.V.Invalid, "tdd-environment-changed"):
                self.tdd(change, prepare=True)
        self.assertFalse(list(self.root.rglob("T-001.contract.json")))

    def test_prepare_does_not_generate_a_bundle_or_claim_review(self):
        self.original["risk"] = "critical"
        self.contract.write_text(json.dumps(self.original))
        result = C.collect(self.root, self.contract, self.fixture.task_path, "example", "smoke", prepare=True)
        self.assertIsNone(result["bundle"])
        self.assertFalse(result["bundle_valid"])
        self.assertFalse(result["contract_valid"])  # Risk/TDD requirements are still enforced.
        self.assertFalse(list(self.root.rglob("*.evidence.json")))
        self.assertEqual(result["contract_sha256"], C.V.digest((self.root / result["contract"]).read_bytes()))

    def test_critical_prepare_then_existing_clean_tree_signing_route(self):
        transition = self.setup_tdd()
        # Other checks/review are synthetic manual fixtures, not issued authority.
        (self.root / "manual-fixture.log").write_text("synthetic existing check evidence\n")
        self.original["risk"] = "critical"
        for name in ("acceptance-tests", "regression", "requirement-traceability"):
            self.original["checks"].append({"id": name})
        for check in self.original["checks"]:
            if check["id"] != "unit-tests":
                check.update(required=True, passes=True, evidence="manual-fixture.log", waiver_reason="")
            if check["id"] == "acceptance-tests":
                check.update(red_evidence="manual-fixture.log", green_evidence="manual-fixture.log")
        spec = self.root / "specs/fixture"
        spec.mkdir(parents=True)
        (spec / "requirements.md").write_text("synthetic specification\n")
        self.contract.write_text(json.dumps(self.original))
        result = self.tdd(transition, prepare=True)
        self.assertTrue(result["contract_valid"], result)
        self.assertIsNone(result["bundle"])
        review = self.root / "independent-fixture-review.md"
        review.write_text("Task ID: T-001\nFeature: fixture\nVERDICT: PASS\nSynthetic review for test only.\n")
        contract = self.root / result["contract"]
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {"SDD_EVIDENCE_KEY": "synthetic-critical-test-key"}):
            bundle = Path(temporary) / "T-001.evidence.json"
            def generate_and_check():
                generated = subprocess.run(["sh", str(C.HERE / "generate-evidence-bundle.sh"),
                                            str(contract), str(review), str(self.root), str(bundle)], capture_output=True)
                self.assertEqual(generated.returncode, 0, generated.stderr)
                return subprocess.run(["sh", str(C.HERE / "check-evidence-bundle.sh"),
                                       str(bundle), str(self.root)], capture_output=True)
            self.assertNotEqual(generate_and_check().returncode, 0)  # Dirty capture cannot be signed validly.
            subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Fixture", "-c",
                            "user.email=fixture@example.invalid", "commit", "-qm", "prepared synthetic evidence"], check=True)
            checked = generate_and_check()
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
            doc = json.loads(bundle.read_text())
            self.assertFalse(doc["git_generated_dirty"])
            self.assertIn("signature", doc)
            with patch.dict(os.environ, {"SDD_EVIDENCE_KEY": "wrong-synthetic-key"}):
                checked = subprocess.run(["sh", str(C.HERE / "check-evidence-bundle.sh"),
                                          str(bundle), str(self.root)], capture_output=True)
                self.assertNotEqual(checked.returncode, 0)

    def test_signing_environment_is_rejected_before_execution(self):
        for name in ("SDD_EVIDENCE_KEY", "SDD_EVIDENCE_KEY_FILE"):
            with patch.dict(os.environ, {name: "synthetic-not-a-real-key"}):
                with self.assertRaisesRegex(C.V.Invalid, "execution-must-not-inherit-signing-key"):
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
