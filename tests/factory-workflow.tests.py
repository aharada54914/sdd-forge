#!/usr/bin/env python3
"""Offline routing and decision packet contracts, including real measurement handoff."""

import copy
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
from unittest.mock import patch
from datetime import datetime, timedelta, timezone

ROOT = Path(__file__).resolve().parents[1]


def load(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


route = load("factory_route", "plugins/sdd-bootstrap/scripts/workflow-playbook.py")
packet = load("factory_packet", "plugins/sdd-bootstrap/scripts/decision-packet.py")
measurement = load(
    "factory_measurement", "plugins/sdd-quality-loop/scripts/run_measurement.py"
)


def request(purpose="prototype", track="full"):
    return {
        "schema": "workflow-playbook-request/v1",
        "purpose": purpose,
        "track": track,
        "requested_effect": route.ROUTES[purpose][1],
        "objective": "Find finished tasks",
        "scenario": "One user opens the completed task list",
        "constraints": ["no product writes"],
        "hypotheses": ["A dedicated completed view reduces scanning"],
        "selection_criteria": ["same completed task IDs"],
        "budget": {
            "seconds": 10,
            "max_runs": 6,
            "cost_limit": None,
            "cost_reason": "no monetary observation",
        },
    }


def fixture(root):
    (root / "specs/pilot").mkdir(parents=True)
    files = {
        "specs/pilot/tasks.md": "## T-001 Explore\nApproval: Draft\nStatus: Planned\n",
        "scenario.txt": "Find completed task 2.",
        "a.html": "<p>All tasks; completed: 2</p>",
        "b.html": "<p>Completed tasks: 2</p>",
        "a.diff": "all list",
        "b.diff": "completed view",
    }
    for path, data in files.items():
        (root / path).write_text(data, encoding="utf-8")
    return {
        "schema": "decision-packet/v1",
        "feature": "pilot",
        "task": "T-001",
        "run_id": "experiment-1",
        "objective": "Find completed tasks",
        "scenario": "Open completed task 2",
        "hypotheses": ["Separate list may reduce scanning"],
        "inputs": [reference(root, "scenario.txt")],
        "approval": reference(root, "specs/pilot/tasks.md"),
        "alternatives": [
            {
                "id": name,
                "description": "Task view " + name,
                "preview": reference(root, name + ".html"),
                "diff": reference(root, name + ".diff"),
                "observations": [
                    {
                        "outcome": "not-run",
                        "reason": "not yet executed",
                        "evidence": None,
                        "measurement": None,
                    }
                ],
                "counterevidence": ["No human UX test"],
                "unknowns": ["User preference"],
            }
            for name in ("a", "b")
        ],
        "recommendation": {"alternative": None, "reason": "Need user evidence"},
        "unknowns": ["No real app selected"],
        "risks": ["Fixture is not UX evidence"],
        "next_action": "Run equal-condition fixture; retain human decision pending",
        "previous": None,
        "concept_test": False,
    }


def reference(root, path):
    return {
        "path": path,
        "sha256": hashlib.sha256((root / path).read_bytes()).hexdigest(),
    }


def observe(root, name="a", outcome="success", run_id="a-run", exit_code=0):
    log = root / (run_id + ".log")
    directory = root / ("measure-" + run_id)
    measurement.open_measurement(
        directory,
        measurement_id=run_id,
        run_id=run_id,
        scope="feature",
        feature="pilot",
        task="T-001",
        experiment_ref="experiment-1",
        variant_ref=name,
        parent_run_id="experiment-1",
    )
    sid = measurement.start_span(
        directory,
        phase="session",
        command_id="fixture",
        span_id="fixture",
        inputs=[
            root / p
            for p in (
                "scenario.txt",
                "specs/pilot/tasks.md",
                name + ".html",
                name + ".diff",
            )
        ],
    )
    result = subprocess.run(
        [sys.executable, "-I", "-c", 'print("completed task: 2")'],
        capture_output=True,
        timeout=3,
        check=False,
    )
    log.write_bytes(result.stdout)
    measurement.finish_span(
        directory, sid, outcome=outcome, exit_code=exit_code, logs=[("stdout", log)]
    )
    return {
        "outcome": outcome,
        "reason": "Actual deterministic subprocess; no UX judgment",
        "evidence": reference(root, log.name),
        "measurement": {
            "directory": directory.name,
            "span_id": sid,
            "run_id": run_id,
            "records": [
                reference(root, p.relative_to(root).as_posix())
                for p in sorted(directory.rglob("*.json"))
            ],
        },
    }


class FactoryContracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.p = fixture(self.root)

    def tearDown(self):
        self.temp.cleanup()

    def validate(self, p=None, **kwargs):
        p = self.p if p is None else p
        return packet.validate(
            self.root,
            p,
            kwargs.get("feature", "pilot"),
            kwargs.get("task", "T-001"),
            kwargs.get("run_id", "experiment-1"),
            kwargs.get("digest", packet.packet_digest(p)),
        )

    def test_routes_preserve_all_tracks(self):
        for purpose in route.ROUTES:
            for track in ("full", "lite", "legacy"):
                req = request(purpose, track)
                before = copy.deepcopy(req)
                result = route.route(req)
                self.assertEqual(result, route.route(req))
                self.assertEqual(req, before)
                self.assertEqual(result["track"], track)
                self.assertEqual(result["authorization"], "none")
                self.assertTrue(
                    (ROOT / "plugins/sdd-bootstrap" / result["playbook"]).is_file()
                )

    def test_no_write_upgrade(self):
        for purpose in route.ROUTES:
            req = request(purpose)
            req["requested_effect"] = "product-write"
            with self.assertRaises(ValueError):
                route.route(req)

    def test_route_rejects_unknown_fields_and_unbounded_budget(self):
        for key, value in [
            ("seconds", 0),
            ("max_runs", True),
            ("cost_limit", float("nan")),
            ("cost_reason", ""),
        ]:
            req = request()
            req["budget"][key] = value
            with self.assertRaises(ValueError):
                route.route(req)
        req = request()
        req["force_lite"] = True
        with self.assertRaises(ValueError):
            route.route(req)

    def test_unknown_and_not_run_are_preserved(self):
        self.p["alternatives"][1]["observations"][0]["outcome"] = "unknown"
        result = self.validate()
        rendered = packet.render(result)
        self.assertIn("not-run", rendered)
        self.assertIn("unknown", rendered)
        self.assertIn("No human UX test", rendered)
        self.assertEqual(result["human_decision"], "pending")

    def test_actual_observation_is_bound(self):
        self.p["alternatives"][0]["observations"] = [observe(self.root)]
        self.assertIn("Reported success", packet.render(self.validate()))
        self.p["alternatives"][0]["observations"][0]["outcome"] = "failure"
        with self.assertRaises(ValueError):
            self.validate()

    def test_arbitrary_log_cannot_claim_success(self):
        observation = self.p["alternatives"][0]["observations"][0]
        observation.update(
            outcome="success", evidence=reference(self.root, "scenario.txt")
        )
        with self.assertRaises(ValueError):
            self.validate()

    def test_failure_timeout_and_cancellation_sources(self):
        for name, code in [("failure", 1), ("timeout", 124), ("interrupted", None)]:
            observation = observe(self.root, outcome=name, run_id=name, exit_code=code)
            if name == "interrupted":
                observation["outcome"] = "cancelled"
            self.p["alternatives"][0]["observations"] = [observation]
            self.assertIn(observation["outcome"], packet.render(self.validate()))

    def test_incomplete_measurement_fails(self):
        obs = observe(self.root)
        self.p["alternatives"][0]["observations"] = [obs]
        directory = self.root / obs["measurement"]["directory"]
        measurement.start_span(
            directory, phase="command", command_id="unfinished", span_id="unfinished"
        )
        obs["measurement"]["records"] = [
            reference(self.root, p.relative_to(self.root).as_posix())
            for p in directory.rglob("*.json")
        ]
        with self.assertRaises(ValueError):
            self.validate()

    def test_wrong_run_evidence_fails(self):
        obs = observe(self.root)
        obs["measurement"]["run_id"] = "other-run"
        self.p["alternatives"][0]["observations"] = [obs]
        with self.assertRaises(ValueError):
            self.validate()

    def test_cross_alternative_reuse_fails(self):
        self.p["alternatives"][1]["observations"] = [observe(self.root)]
        with self.assertRaises(ValueError):
            self.validate()

    def test_reselected_preview_cannot_reuse_old_measurement(self):
        self.p["alternatives"][0]["observations"] = [observe(self.root)]
        (self.root / "new.html").write_text("Different interaction")
        self.p["alternatives"][0]["preview"] = reference(self.root, "new.html")
        with self.assertRaises(ValueError):
            self.validate()

    def test_measurement_reduction_uses_admitted_snapshot(self):
        obs = observe(self.root)
        self.p["alternatives"][0]["observations"] = [obs]
        original_module = packet.module
        original_summarize = measurement.summarize
        seen = []

        def altered(directory, **kwargs):
            # A source changes after pin admission; reducer must never consume it.
            source = (
                self.root
                / obs["measurement"]["directory"]
                / "spans/fixture.finish.json"
            )
            value = json.loads(source.read_text())
            value["outcome"] = "failure"
            value["exit_code"] = 1
            source.write_text(json.dumps(value))
            seen.append(Path(directory) != self.root / obs["measurement"]["directory"])
            return original_summarize(directory, **kwargs)

        def selected(name, relative):
            return (
                measurement
                if name == "decision_measurement"
                else original_module(name, relative)
            )

        with (
            patch.object(packet, "module", side_effect=selected),
            patch.object(measurement, "summarize", side_effect=altered),
        ):
            self.assertEqual(
                self.validate()["packet"]["alternatives"][0]["observations"][0][
                    "outcome"
                ],
                "success",
            )
        self.assertEqual(seen, [True])
        with self.assertRaises(ValueError):
            self.validate()

    def test_unrelated_log_fails(self):
        obs = observe(self.root)
        obs["evidence"] = reference(self.root, "scenario.txt")
        self.p["alternatives"][0]["observations"] = [obs]
        with self.assertRaises(ValueError):
            self.validate()

    def test_source_changes_fail_resume(self):
        for target in ("scenario.txt", "specs/pilot/tasks.md", "a.html", "a.diff"):
            original = (self.root / target).read_bytes()
            (self.root / target).write_bytes(original + b"changed")
            with self.assertRaises(ValueError):
                self.validate()
            (self.root / target).write_bytes(original)

    def test_packet_replacement_fails(self):
        digest = packet.packet_digest(self.p)
        self.p["alternatives"].reverse()
        with self.assertRaises(ValueError):
            self.validate(digest=digest)

    def test_other_targets_fail(self):
        for override in ({"feature": "other"}, {"task": "T-002"}, {"run_id": "other"}):
            with self.assertRaises(ValueError):
                self.validate(**override)

    def test_no_agent_human_choice_or_approval(self):
        for key in ("human_decision", "approval_status", "done", "decision"):
            bad = copy.deepcopy(self.p)
            bad[key] = "approved"
            with self.assertRaises(ValueError):
                self.validate(bad)

    def test_concept_decision_requires_original_signed_evidence(self):
        self.p["concept_test"] = True
        with self.assertRaises(ValueError):
            self.validate()

    def test_history_is_preserved_but_not_authority(self):
        old = copy.deepcopy(self.p)
        old["recommendation"]["reason"] = "Previously held: no keyboard evidence"
        (self.root / "previous.json").write_text(json.dumps(old))
        self.p["previous"] = reference(self.root, "previous.json")
        result = self.validate()
        self.assertIn("Previously held", packet.render(result))
        self.assertEqual(result["human_decision"], "pending")
        (self.root / "previous.json").write_text("{}")
        with self.assertRaises(ValueError):
            self.validate()

    def test_unsafe_and_symlinked_references(self):
        for path in ("../secret", "/etc/passwd", "C:/x", "a\\b"):
            bad = copy.deepcopy(self.p)
            bad["inputs"][0]["path"] = path
            with self.assertRaises(ValueError):
                self.validate(bad)
        try:
            (self.root / "linked").symlink_to(self.root / "scenario.txt")
        except OSError:
            self.skipTest("host does not permit symlink creation")
        self.p["inputs"][0]["path"] = "linked"
        with self.assertRaises(ValueError):
            self.validate()

    def test_bad_reference_type_is_rejected(self):
        for ref in (None, [], "path", {"path": "scenario.txt", "sha256": 7}):
            with self.assertRaises(ValueError):
                packet.pin(self.root, ref)

    def test_escape_untrusted_display(self):
        self.p["objective"] = "<script>run()</script> [click](javascript:run())"
        display = packet.render(self.validate())
        self.assertNotIn("<script>", display)
        self.assertIn("\\[click\\]", display)

    def test_limit_and_duplicate_options(self):
        self.p["alternatives"] *= 2
        with self.assertRaises(ValueError):
            self.validate()
        self.p["alternatives"] = self.p["alternatives"][:2]
        self.p["alternatives"][1]["id"] = "a"
        with self.assertRaises(ValueError):
            self.validate()

    def test_cli_json_markdown_and_no_writes(self):
        (self.root / "packet.json").write_text(json.dumps(self.p))
        before = {
            p.relative_to(self.root).as_posix(): p.read_bytes()
            for p in self.root.rglob("*")
            if p.is_file()
        }
        command = [
            sys.executable,
            "-B",
            str(ROOT / "plugins/sdd-bootstrap/scripts/decision-packet.py"),
            "--root",
            str(self.root),
            "--packet",
            "packet.json",
            "--feature",
            "pilot",
            "--task",
            "T-001",
            "--run-id",
            "experiment-1",
            "--packet-sha256",
            packet.packet_digest(self.p),
        ]
        for fmt in ("json", "markdown"):
            result = subprocess.run(
                command + ["--format", fmt], capture_output=True, text=True, timeout=10
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        after = {
            p.relative_to(self.root).as_posix(): p.read_bytes()
            for p in self.root.rglob("*")
            if p.is_file()
        }
        self.assertEqual(before, after)
        result = subprocess.run(command + ["--force"], capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 2)

    def test_versioned_schemas_accept_control_and_reject_extra_authority(self):
        validator = load(
            "factory_schema",
            "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py",
        )
        for filename, document in [
            ("decision-packet.v1.schema.json", self.p),
            ("workflow-playbook-request.v1.schema.json", request()),
        ]:
            schema = json.loads((ROOT / "contracts" / filename).read_text())
            self.assertEqual(validator._schema_validate(schema, document), [])
            invalid = dict(document, human_decision="approved")
            self.assertTrue(validator._schema_validate(schema, invalid))

    def sign_choice(
        self, identifier="choice-1", choice="adopt", previous=None, **updates
    ):
        folder = self.root / "specs/pilot/decisions" / identifier
        folder.mkdir(parents=True, exist_ok=True)
        (self.root / "sdd").mkdir(exist_ok=True)
        (self.root / "sdd/approver-registry.yaml").write_text(
            "schema: sdd-approver-registry/v1\napprovers:\n  - id: fixture\n    name: Synthetic approver\n"
        )
        record = dict(
            schema="decision-choice/v1",
            decision_id=identifier,
            feature="pilot",
            task="T-001",
            run_id="experiment-1",
            packet_sha256=packet.packet_digest(self.p),
            alternative="a",
            choice=choice,
            reason=choice + " reason retained",
            previous=previous,
            valid_until=(datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
        )
        record.update(updates)
        path = folder / "decision-choice.json"
        path.write_text(json.dumps(record))
        destination = self.root / ("stage-" + identifier)
        env = dict(
            os.environ, SDD_CONTEXT_KEY="synthetic-factory-test-key-not-production"
        )
        command = [
            sys.executable,
            str(ROOT / "plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"),
            "--schema",
            "sdd-decision-choice-approval/v1",
            "--repo",
            str(self.root),
            "--feature",
            "pilot",
            "--decision-id",
            identifier,
            "--content",
            str(path),
            "--approver",
            "fixture",
            "--status",
            "Approved",
            "--stage-dir",
            str(destination),
        ]
        result = subprocess.run(
            command, cwd=self.root, env=env, capture_output=True, text=True, timeout=30
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        shutil.copyfile(
            destination
            / "specs/pilot/decisions"
            / identifier
            / "decision-choice.approval.json",
            folder / "decision-choice.approval.json",
        )
        return (
            record,
            reference(self.root, path.relative_to(self.root).as_posix()),
            command,
            env,
        )

    def choice(self, identifier, digest, env):
        with patch.dict(os.environ, {"SDD_CONTEXT_KEY": env["SDD_CONTEXT_KEY"]}):
            return packet.attach_choice(self.root, self.validate(), identifier, digest)

    def test_signed_choices_are_separate_from_task_approval(self):
        before = (self.root / "specs/pilot/tasks.md").read_bytes()
        previous = None
        for status in ("adopt", "reject", "hold"):
            record, ref, _, env = self.sign_choice("choice-" + status, status, previous)
            result = self.choice(record["decision_id"], ref["sha256"], env)
            self.assertEqual(result["human_decision"], status)
            self.assertIn(status + " reason retained", packet.render(result))
            previous = {
                "record": ref,
                "approval": reference(
                    self.root,
                    "specs/pilot/decisions/"
                    + record["decision_id"]
                    + "/decision-choice.approval.json",
                ),
            }
        self.assertEqual(before, (self.root / "specs/pilot/tasks.md").read_bytes())

    def test_unsigned_choice_and_signature_tamper_rejected(self):
        record, ref, _, env = self.sign_choice()
        sidecar = (
            self.root / "specs/pilot/decisions/choice-1/decision-choice.approval.json"
        )
        raw = json.loads(sidecar.read_text())
        raw["hmac"] = "0" * 64
        sidecar.write_text(json.dumps(raw))
        with self.assertRaises(ValueError):
            self.choice(record["decision_id"], ref["sha256"], env)
        sidecar.unlink()
        with self.assertRaises((ValueError, OSError)):
            self.choice(record["decision_id"], ref["sha256"], env)

    def test_choice_cannot_replay_on_other_packet_or_target(self):
        record, ref, _, env = self.sign_choice()
        self.p["objective"] += " changed"
        with self.assertRaises(ValueError):
            self.choice(record["decision_id"], ref["sha256"], env)
        self.p["objective"] = "Find completed tasks"
        wrong, wrong_ref, _, env = self.sign_choice("wrong-task", task="T-002")
        with self.assertRaises(ValueError):
            self.choice(wrong["decision_id"], wrong_ref["sha256"], env)

    def test_choice_expiry_and_unknown_option_rejected(self):
        previous = None
        for identifier, update in [
            ("expired", {"valid_until": "2000-01-01T00:00:00+00:00"}),
            ("unknown-option", {"alternative": "absent"}),
        ]:
            record, ref, _, env = self.sign_choice(
                identifier, previous=previous, **update
            )
            with self.assertRaises(ValueError):
                self.choice(record["decision_id"], ref["sha256"], env)
            previous = {
                "record": ref,
                "approval": reference(
                    self.root,
                    "specs/pilot/decisions/"
                    + identifier
                    + "/decision-choice.approval.json",
                ),
            }

    def test_signed_rejection_history_and_superseded_replay(self):
        first, first_ref, _, env = self.sign_choice("first", "reject")
        previous = {
            "record": first_ref,
            "approval": reference(
                self.root, "specs/pilot/decisions/first/decision-choice.approval.json"
            ),
        }
        second, second_ref, _, env = self.sign_choice("second", "hold", previous)
        result = self.choice(second["decision_id"], second_ref["sha256"], env)
        self.assertIn(
            "Previous reject a: reject reason retained", packet.render(result)
        )
        with self.assertRaises(ValueError):
            self.choice(first["decision_id"], first_ref["sha256"], env)

    def test_choice_identifier_cannot_be_resigned_in_place(self):
        _, _, command, env = self.sign_choice()
        result = subprocess.run(
            command, cwd=self.root, env=env, capture_output=True, text=True, timeout=30
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid immutable decision content", result.stderr)

    def test_deleted_successor_content_cannot_restore_old_choice(self):
        first, first_ref, _, env = self.sign_choice("first", "adopt")
        previous = {
            "record": first_ref,
            "approval": reference(
                self.root, "specs/pilot/decisions/first/decision-choice.approval.json"
            ),
        }
        _, second_ref, _, env = self.sign_choice("second", "reject", previous)
        (self.root / second_ref["path"]).unlink()
        with self.assertRaises(ValueError):
            self.choice(first["decision_id"], first_ref["sha256"], env)

    def test_issuer_rejects_disconnected_successor(self):
        record, _, command, env = self.sign_choice("first")
        record.update(decision_id="second", choice="reject", previous=None)
        path = self.root / "specs/pilot/decisions/second/decision-choice.json"
        path.parent.mkdir()
        path.write_text(json.dumps(record))
        command[command.index("--decision-id") + 1] = "second"
        command[command.index("--content") + 1] = str(path)
        command[command.index("--stage-dir") + 1] = str(self.root / "stage-second")
        result = subprocess.run(
            command, cwd=self.root, env=env, capture_output=True, text=True, timeout=30
        )
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.root / "stage-second").exists())

    def test_live_publisher_journal_blocks_choice_from_any_cwd(self):
        record, ref, _, env = self.sign_choice()
        journal = self.root / "sdd/.staging/fixture/TRANSACTION.json"
        journal.parent.mkdir(parents=True)
        journal.write_text(json.dumps({"targets": [{"live_path": ref["path"]}]}))
        with self.assertRaises(ValueError):
            self.choice(record["decision_id"], ref["sha256"], env)

    def test_signer_rejects_alternate_choice_source_path(self):
        _, _, command, env = self.sign_choice()
        path = self.root / "elsewhere.json"
        path.write_bytes(
            (
                self.root / "specs/pilot/decisions/choice-1/decision-choice.json"
            ).read_bytes()
        )
        command[command.index("--content") + 1] = str(path)
        result = subprocess.run(
            command, cwd=self.root, env=env, capture_output=True, text=True, timeout=30
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid immutable decision content", result.stderr)

    def test_adapter_inventory_cannot_grant_admission(self):
        readiness = load(
            "factory_readiness",
            "plugins/sdd-bootstrap/scripts/factory-adapter-readiness.py",
        )
        for root in (ROOT, self.root):
            result = readiness.inspect(root)
            self.assertEqual(result["schema"], "factory-adapter-readiness/v1")
            self.assertFalse(result["admissible"])
            self.assertEqual(result["authority"], "none")
            self.assertEqual(len(result["candidates"]), 3)
            self.assertTrue(
                all(
                    set(c["required_capabilities"].values()) == {"not-demonstrated"}
                    for c in result["candidates"]
                )
            )

    def test_pilot_protocol_retains_all_runs_and_refuses_overwrite(self):
        pilot = load("factory_pilot_check", "tests/factory-pilot.py")
        destination = self.root / "pilot-results"
        report = pilot.pilot(destination)
        self.assertEqual(len(report["runs"]), 6)
        self.assertTrue(all(row["outcome"] == "success" for row in report["runs"]))
        self.assertEqual(sum(len(row["artifacts"]) for row in report["runs"]), 12)
        self.assertEqual(report["real_app_evaluation"], "pending")
        self.assertEqual(report["human_adoption"], "pending")
        for row in report["runs"]:
            trial_root = destination / f"{row['trial']}-{row['variant']}"
            summary = json.loads(
                (trial_root / row["presentation_measurement"]["path"]).read_text()
            )
            self.assertTrue(summary["complete"])
            self.assertIsNone(row["human_active_seconds"])
        protocol = (destination / "protocol.json").read_bytes()
        self.assertEqual(
            report["protocol_sha256"], hashlib.sha256(protocol).hexdigest()
        )
        with self.assertRaises(ValueError):
            pilot.pilot(destination)

    def test_pilot_retains_failed_trials(self):
        pilot = load("factory_pilot_fail", "tests/factory-pilot.py")
        with patch.object(
            pilot.fixture, "observe", side_effect=ValueError("controlled bad output")
        ):
            report = pilot.pilot(self.root / "failed-pilot")
        self.assertEqual(len(report["runs"]), 6)
        self.assertTrue(all(row["outcome"] == "failure" for row in report["runs"]))
        self.assertTrue(report["safety_regression"])


if __name__ == "__main__":
    unittest.main()
