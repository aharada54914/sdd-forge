#!/usr/bin/env python3
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "benchmark", ROOT / "tests/benchmark-gates.py"
)
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)


class BenchmarkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repository"
        self.root.mkdir()
        (self.root / "gates").mkdir()
        (self.root / "gates/check.py").write_text('print("marker-B")\n')
        (self.root / "input.txt").write_text("fixed input")
        (self.root / "skill.md").write_text("fixed gate protocol")
        B.git(self.root, "init", "-q")
        B.git(self.root, "add", ".")
        B.git(
            self.root,
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-qm",
            "baseline",
        )
        self.baseline = B.git(self.root, "rev-parse", "HEAD").decode().strip()
        (self.root / "gates/check.py").write_text('print("marker-C")\n')
        B.git(self.root, "add", ".")
        B.git(
            self.root,
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-qm",
            "candidate",
        )
        self.candidate = B.git(self.root, "rev-parse", "HEAD").decode().strip()
        step = {
            "step_id": "gate",
            "argv": [sys.executable, "gates/check.py"],
            "cwd": ".",
            "expected_exit": 0,
        }

        def pin(p):
            return {
                "path": p,
                "sha256": hashlib.sha256((self.root / p).read_bytes()).hexdigest(),
            }

        self.manifest = {
            "schema": "sdd-gate-benchmark/v1",
            "baseline_head": self.baseline,
            "code_paths": ["gates"],
            "inputs": [pin("input.txt")],
            "trials": 5,
            "pinned": {
                "feature": "fixture",
                "task_id": "T-001",
                "risk": "low",
                "contract": "fixture-contract",
            },
            "skill_source": pin("skill.md"),
            "recipes": {"single": [step]},
            "lifecycles": {"initial": {}},
            "temperatures": ["cold"],
            "primary": {
                "recipe": "single",
                "scope": "all",
                "lifecycle": "initial",
                "temperature": "cold",
                "statistic": "median",
                "value": "session_ns",
            },
            "compare_cases": [
                dict(
                    step,
                    case_id="normal",
                    family="fixture",
                    **{"class": "normal"},
                    fixture_paths=["input.txt"],
                )
            ],
            "repeat_count": 0,
        }
        self.path = self.root / "manifest.json"
        self.path.write_text(json.dumps(self.manifest))

    def test_selected_revision_executed_with_frozen_inputs(self):
        output = Path(self.temp.name) / "results"
        self.assertEqual(
            B.main(
                [
                    "--manifest",
                    str(self.path),
                    "--output",
                    str(output),
                    "--code-revision",
                    self.candidate,
                    "--run",
                ]
            ),
            0,
        )
        results = json.loads((output / "results.json").read_text())
        self.assertEqual(results["implementation_revision"], self.candidate)
        self.assertEqual(results["primary"]["n"], 5)
        self.assertTrue(results["primary"]["admissible"])
        for sample in results["primary"]["samples"]:
            self.assertEqual(
                Path(sample["attempts"][0]["steps"][0]["stdout"]).read_text(),
                "marker-C\n",
            )
        self.assertEqual(
            len(
                B.git(self.root, "worktree", "list", "--porcelain")
                .decode()
                .split("worktree ")
            )
            - 1,
            1,
        )

    def test_invalid_pins_axes_and_recipes_rejected_before_execution(self):
        variants = []
        for key, value in [
            ("trials", 3),
            ("code_paths", []),
            ("temperatures", ["hot"]),
            ("lifecycles", {"later": {}}),
            ("repeat_count", None),
            ("pinned", {}),
        ]:
            m = copy.deepcopy(self.manifest)
            m[key] = value
            variants.append(m)
        m = copy.deepcopy(self.manifest)
        m["inputs"][0]["sha256"] = "0" * 64
        variants.append(m)
        m = copy.deepcopy(self.manifest)
        m["recipes"]["single"][0].pop("expected_exit")
        variants.append(m)
        for manifest in variants:
            with self.assertRaises(ValueError):
                B.validate_manifest(self.root, manifest, self.candidate)

    def test_changed_candidate_input_rejected(self):
        (self.root / "input.txt").write_text("changed")
        B.git(self.root, "add", ".")
        B.git(
            self.root,
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-qm",
            "changed frozen input",
        )
        with self.assertRaises(ValueError):
            B.validate_manifest(self.root, self.manifest, "HEAD")

    def test_failure_and_censoring_stay_in_denominator(self):
        def attempt(value, complete=True, exit_code=0):
            return {
                "summary": {"complete": complete, "elapsed": {"session_ns": value}},
                "steps": [{"exit_code": exit_code, "expected_exit": 0}],
            }

        trials = [
            {"trial_id": str(i), "attempts": [a]}
            for i, a in enumerate(
                [
                    attempt(4),
                    attempt(6),
                    attempt(7, exit_code=1),
                    attempt(0, False),
                    attempt(0, False),
                ]
            )
        ]
        r = B.aggregate_trials("fixture", trials)
        self.assertEqual(
            (
                r["n"],
                r["successful"],
                r["failed"],
                r["censored"],
                r["attempts_started"],
            ),
            (5, 2, 1, 2, 5),
        )
        self.assertEqual(r["statistics"]["median"], 5)
        self.assertFalse(r["admissible"])

    def test_fingerprints_and_primary_admissibility(self):
        env = {"python": "fixture"}
        fp = B.fingerprint(self.manifest, env)
        changed = copy.deepcopy(self.manifest)
        changed["baseline_head"] = "other"
        self.assertEqual(fp, B.fingerprint(changed, env))
        changed["recipes"]["single"][0]["argv"].append("extra")
        self.assertNotEqual(fp, B.fingerprint(changed, env))
        self.assertFalse(
            B.comparable(
                {"fixture_fingerprint": fp, "primary": {"admissible": True}},
                {"fixture_fingerprint": fp, "primary": {"admissible": False}},
            )
        )

    def test_comparison_runs_real_gate_both_ways(self):
        output = Path(self.temp.name) / "compare"
        self.assertEqual(
            B.main(
                ["--manifest", str(self.path), "--output", str(output), "--compare"]
            ),
            0,
        )
        self.assertTrue(
            json.loads((output / "results.json").read_text())["scenarios"]["normal"][
                "equal"
            ]
        )


if __name__ == "__main__":
    unittest.main()
