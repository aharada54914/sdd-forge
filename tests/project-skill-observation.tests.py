#!/usr/bin/env python3
"""Exercise project-skill trust boundaries against real temporary trees."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import shlex
from unittest.mock import patch
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "plugins/sdd-quality-loop/scripts/validate-project-skill.py"
spec = importlib.util.spec_from_file_location("project_skill", SCRIPT)
V = importlib.util.module_from_spec(spec)
spec.loader.exec_module(V)


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.skill = self.root / "sdd/skills/example"
        self.skill.mkdir(parents=True)
        (self.skill / "run.py").write_text('print("real invocation")\n')
        self.manifest = {
            "schema": "project-skill-manifest/v1",
            "name": "example",
            "checks": ["smoke"],
            "runtime": "python3",
            "entry": "run.py",
            "args": [],
            "requires": [],
            "files": [
                {
                    "path": "run.py",
                    "sha256": V.digest((self.skill / "run.py").read_bytes()),
                }
            ],
        }
        self.write_manifest()
        self.obs = {
            "schema": "project-verification-observation/v2",
            "mode": "trial",
            "skill": "example",
            "check_id": "smoke",
            "skill_manifest_sha256": V.digest(
                (self.skill / "skill-manifest.json").read_bytes()
            ),
            "source": {
                "commit": None,
                "tree_sha256": V.tree_digest(
                    {"sdd/skills/example/run.py": self.manifest["files"][0]["sha256"]}
                ),
            },
            "environment": {
                "os": "linux",
                "host": "fixture",
                **V.runtime_environment(self.manifest),
                "missing": [],
            },
            "outcome": "passed",
            "started_at": "2026-10-25T00:00:00Z",
            "finished_at": "2026-10-25T00:00:01Z",
            "exit_code": 0,
        }
        self.task_path = None
        self.write_observation()

    def write_manifest(self):
        (self.skill / "skill-manifest.json").write_text(json.dumps(self.manifest))

    def write_observation(self):
        self.observation = self.root / V.observation_relative(self.obs)
        self.observation.parent.mkdir(parents=True, exist_ok=True)
        self.observation.write_text(json.dumps(self.obs))

    def validate(self):
        return V.validate(self.root, "example", self.observation, self.task_path)

    def invalid(self, code):
        with self.assertRaisesRegex(V.Invalid, "^" + code + "$"):
            self.validate()

    def task(self):
        inputs = [
            {"path": "sdd/skills/example/" + p.name, "sha256": V.digest(p.read_bytes())}
            for p in sorted(self.skill.iterdir())
        ]
        self.task_doc = {
            "schema": "task-input-manifest/v1",
            "task_id": "T-001",
            "run_id": "run1",
            "session_id": "s1",
            "agent_instance_id": "a1",
            "model_tier": "standard",
            "provider": "fixture",
            "model": "fixture",
            "estimated_cost_per_attempt_usd": "0",
            "cost_estimate_source": "fixture",
            "cost_estimate_timestamp": "2026-10-25T00:00:00Z",
            "isolation_mode": "fresh-agent",
            "fallback_reason": "",
            "handoff_reload_evidence_hash": "",
            "allowed_inputs": inputs,
            "allowed_outputs": [
                "output/",
                "reports/project-skill-observations/T-001/run1/",
            ],
        }
        self.task_path = self.root / "input.json"
        self.task_path.write_text(json.dumps(self.task_doc))
        self.obs.update(
            mode="task",
            task_id="T-001",
            run_id="run1",
            task_input_manifest_sha256=V.digest(self.task_path.read_bytes()),
        )
        self.obs["source"]["tree_sha256"] = V.tree_digest(
            {p["path"]: p["sha256"] for p in inputs}
        )
        self.write_observation()

    def test_manifest_only(self):
        self.assertEqual(V.validate(self.root, "example")[2], "manifest-only")

    def test_legacy_record_is_history_not_fresh_execution(self):
        self.obs["schema"] = "project-verification-observation/v1"
        self.obs["environment"].pop("toolchain")
        self.obs["environment"].pop("variables_sha256")
        self.write_observation()
        validated = self.validate()
        self.assertEqual(validated[2], "legacy-runtime-unbound")
        self.assertNotIn("passes", V.project_execution({"id": "smoke"}, validated))

    @unittest.skipUnless(sys.platform == "linux", "actual runner ownership is Linux-only")
    def test_actual_pass_rejected_after_runtime_replacement_at_same_path(self):
        runtime = self.root / "runtime-probe"
        runtime.write_text("#!/bin/sh\nexec " + shlex.quote(sys.executable) + ' "$@"\n')
        runtime.chmod(0o755)
        self.manifest["runtime"] = "runtime-probe"
        self.write_manifest()
        self.task()
        self.observation.unlink()
        runner_spec = importlib.util.spec_from_file_location(
            "runtime_runner", ROOT / "plugins/sdd-bootstrap/scripts/project-skill.py")
        runner = importlib.util.module_from_spec(runner_spec)
        runner_spec.loader.exec_module(runner)
        with patch.dict(os.environ, {"PATH": str(self.root) + os.pathsep + os.environ["PATH"]}):
            result = runner.run(self.root, "example", "smoke", task_path=self.task_path)
            self.assertEqual(result["outcome"], "passed")
            observation = self.root / result["observation"]
            self.assertEqual(V.validate(self.root, "example", observation, self.task_path)[2], "passed")
            runtime.write_text("#!/bin/sh\nexit 3\n")
            with self.assertRaisesRegex(V.Invalid, "runtime-changed"):
                V.validate(self.root, "example", observation, self.task_path)

    def test_declared_helper_replacement_and_environment_change_invalidate(self):
        helper = self.root / "tool-probe"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        with patch.dict(os.environ, {"PATH": str(self.root) + os.pathsep + os.environ["PATH"]}):
            self.manifest["requires"] = ["tool-probe"]
            self.write_manifest()
            self.obs["skill_manifest_sha256"] = V.digest((self.skill / "skill-manifest.json").read_bytes())
            self.obs["environment"].update(V.runtime_environment(self.manifest))
            self.write_observation()
            self.assertEqual(self.validate()[2], "trial-passed")
            with patch.dict(os.environ, {"SDD_FIXTURE_RUNTIME_INPUT": "changed"}):
                self.invalid("runtime-changed")
            helper.write_text("#!/bin/sh\nexit 2\n")
            self.invalid("runtime-changed")

    def test_valid_trial(self):
        self.assertEqual(self.validate()[2], "trial-passed")

    def test_valid_task(self):
        self.task()
        self.assertEqual(self.validate()[2], "passed")

    def test_required_override(self):
        self.manifest["required"] = False
        self.write_manifest()
        self.invalid("manifest-invalid")

    def test_duplicate_json(self):
        p = self.skill / "skill-manifest.json"
        p.write_text(
            p.read_text().replace(
                '"name": "example"', '"name": "example", "name":"example"'
            )
        )
        self.invalid("manifest-invalid")

    def test_changed_helper(self):
        (self.skill / "run.py").write_text("changed")
        self.invalid("digest-mismatch")

    def test_unlisted_helper(self):
        (self.skill / "extra.py").write_text("extra")
        self.invalid("closure-incomplete")

    def test_missing_helper(self):
        (self.skill / "run.py").unlink()
        self.invalid("closure-missing")

    def test_name_mismatch(self):
        self.manifest["name"] = "different"
        self.write_manifest()
        self.invalid("name-mismatch")

    def test_collision(self):
        other = self.root / "sdd/skills/other"
        other.mkdir()
        m = copy.deepcopy(self.manifest)
        m["name"] = "other"
        (other / "skill-manifest.json").write_text(json.dumps(m))
        self.invalid("check-collision")

    def test_escape_paths(self):
        for path in (
            "../escape",
            "/outside",
            "a//b",
            "a/./b",
            "a\\b",
            "C:escape",
            "x\0y",
        ):
            with self.subTest(path=path):
                self.manifest["files"][0]["path"] = path
                self.manifest["entry"] = path
                self.write_manifest()
                self.invalid("closure-escape")

    def test_shell_arguments(self):
        for arg in ("../secret", "--file=/etc/passwd", "a;b", "$(echo x)"):
            with self.subTest(arg=arg):
                self.manifest["args"] = [arg]
                self.write_manifest()
                self.invalid("manifest-invalid")

    def test_linked_helper(self):
        target = self.root / "outside"
        target.write_text("outside")
        (self.skill / "run.py").unlink()
        try:
            (self.skill / "run.py").symlink_to(target)
        except OSError:
            self.skipTest("symlink privilege unavailable")
        self.invalid("closure-escape")

    def test_special_entry(self):
        if not hasattr(os, "mkfifo"):
            self.skipTest("FIFO unavailable")
        os.mkfifo(self.skill / "pipe")
        self.invalid("closure-escape")

    def test_outcome_combinations(self):
        for mutation in (
            {"exit_code": 1},
            {"outcome": "not-run"},
            {"outcome": "unavailable"},
            {"started_at": "2026-13-25T00:00:00Z"},
            {"finished_at": "2025-10-25T00:00:00Z"},
            {"passes": True},
            {"exit_code": True},
        ):
            with self.subTest(mutation=mutation):
                original = copy.deepcopy(self.obs)
                self.obs.update(mutation)
                self.write_observation()
                self.invalid("observation-invalid")
                self.obs = original

    def test_unavailable(self):
        self.obs["outcome"] = "unavailable"
        self.obs["environment"].update(runtime_path=None, missing=["runtime"])
        for key in ("started_at", "finished_at", "exit_code"):
            self.obs.pop(key)
        self.write_observation()
        self.assertEqual(self.validate()[2], "trial-unavailable")

    def test_trial_never_projects(self):
        check = {
            "id": "smoke",
            "required": True,
            "waiver_reason": "keep",
            "passes": True,
            "command": "old",
            "evidence": "old",
        }
        self.assertEqual(
            V.project_execution(check, self.validate()),
            {"id": "smoke", "required": True, "waiver_reason": "keep"},
        )

    def test_task_projection_preserves_obligations(self):
        self.task()
        check = {
            "id": "smoke",
            "required": False,
            "waiver_reason": "keep",
            "custom": "keep",
        }
        projected = V.project_execution(check, self.validate())
        self.assertTrue(projected["passes"])
        for key in check:
            self.assertEqual(projected[key], check[key])

    def test_no_input_manifest(self):
        self.task()
        self.task_path = None
        self.invalid("input-required")

    def test_trial_with_task(self):
        original = copy.deepcopy(self.obs)
        self.task()
        self.obs = original
        self.write_observation()
        self.invalid("input-required")

    def test_tampered_task(self):
        self.task()
        self.task_doc["model"] = "changed"
        self.task_path.write_text(json.dumps(self.task_doc))
        self.invalid("input-unbound")

    def test_changed_admitted_source(self):
        self.task()
        extra = self.root / "source.txt"
        extra.write_text("original")
        self.task_doc["allowed_inputs"].append(
            {"path": "source.txt", "sha256": V.digest(extra.read_bytes())}
        )
        self.task_path.write_text(json.dumps(self.task_doc))
        self.obs["task_input_manifest_sha256"] = V.digest(self.task_path.read_bytes())
        self.write_observation()
        extra.write_text("changed")
        self.invalid("input-unbound")

    def test_changed_output(self):
        self.task()
        (self.root / "output").mkdir()
        (self.root / "output/new.txt").write_text("new")
        self.invalid("source-mismatch")

    def test_unadmitted_observation(self):
        self.task()
        self.task_doc["allowed_outputs"] = ["output/"]
        self.task_path.write_text(json.dumps(self.task_doc))
        self.obs["task_input_manifest_sha256"] = V.digest(self.task_path.read_bytes())
        self.write_observation()
        self.invalid("input-unbound")

    def test_forbidden_fallback(self):
        self.task()
        self.task_doc["fallback_reason"] = "not empty"
        self.task_path.write_text(json.dumps(self.task_doc))
        self.invalid("input-unbound")

    def test_source_mismatch(self):
        self.obs["source"]["tree_sha256"] = "0" * 64
        self.write_observation()
        self.invalid("source-mismatch")

    def test_wrong_observation_path(self):
        self.observation = self.root / "wrong.json"
        self.observation.write_text(json.dumps(self.obs))
        self.invalid("observation-invalid")

    def test_oversized_json_rejected(self):
        (self.skill / "skill-manifest.json").write_bytes(b" " * (V.MAX_JSON_BYTES + 1))
        self.invalid("manifest-invalid")

    def test_malformed_document_shapes(self):
        for value in ([], None, True, "not an object"):
            with self.subTest(value=value):
                (self.skill / "skill-manifest.json").write_text(json.dumps(value))
                self.invalid("manifest-invalid")

    def test_other_run_evidence_is_not_excluded(self):
        self.task()
        self.task_doc["allowed_outputs"] = [
            "output/",
            "reports/project-skill-observations/",
        ]
        self.task_path.write_text(json.dumps(self.task_doc))
        self.obs["task_input_manifest_sha256"] = V.digest(self.task_path.read_bytes())
        self.write_observation()
        other = self.root / "reports/project-skill-observations/T-001/other/old.json"
        other.parent.mkdir(parents=True)
        other.write_text("{}")
        self.invalid("source-mismatch")

    def test_observation_symlink_refused(self):
        outside = self.root / "outside.json"
        outside.write_text(json.dumps(self.obs))
        self.observation.unlink()
        try:
            self.observation.symlink_to(outside)
        except OSError:
            self.skipTest("symlink privilege unavailable")
        self.invalid("observation-invalid")

    def test_schema_copies_identical(self):
        for filename in (
            "project-skill-manifest.schema.json",
            "project-verification-observation.schema.json",
        ):
            self.assertEqual(
                (ROOT / "contracts" / filename).read_bytes(),
                (SCRIPT.parent.parent / "contracts" / filename).read_bytes(),
            )

    def test_cli_and_shell(self):
        for command in (
            [sys.executable, str(SCRIPT)],
            ["bash", str(SCRIPT.with_suffix(".sh"))],
        ):
            if command[0] == "bash" and os.name == "nt":
                continue
            result = subprocess.run(
                [
                    *command,
                    "--execution-root",
                    str(self.root),
                    "--skill",
                    "example",
                    "--observation",
                    str(self.observation),
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                result.stdout, "project-skill: VALID example trial-passed\n"
            )

    def test_cli_rejects_unknown(self):
        r = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--execution-root",
                str(self.root),
                "--skill",
                "example",
                "--unsafe",
            ],
            capture_output=True,
        )
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
