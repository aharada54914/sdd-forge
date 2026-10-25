#!/usr/bin/env python3
"""Deterministic observation checks; no credentials, model calls or elapsed-time thresholds."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "measurement", ROOT / "plugins/sdd-quality-loop/scripts/run_measurement.py"
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class MeasurementTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.d = Path(self.tmp.name).resolve() / "measurement"
        m.open_measurement(self.d, measurement_id="m1", run_id="r1", scope="all")

    def at(self, ns, func, *args, domain="boot:fixture", **kwargs):
        with patch.object(
            m, "_clock", return_value=(domain, ns, "2026-10-25T00:00:00Z")
        ):
            return func(*args, **kwargs)

    def span(self, name, phase, start, end, parent=None, outcome="success", **kwargs):
        self.at(
            start,
            m.start_span,
            self.d,
            span_id=name,
            phase=phase,
            command_id=name,
            parent_span_id=parent,
        )
        self.at(end, m.finish_span, self.d, name, outcome=outcome, **kwargs)

    def test_timeline_union_effort_and_lead_times(self):
        self.span("s0", "session", 0, 10000)
        self.span("g1", "gate", 1000, 4000, "s0")
        self.span("g2", "gate", 2000, 6000, "s0", "failure", exit_code=1)
        self.span(
            "m1",
            "model",
            7000,
            8000,
            "s0",
            token_usage={"input": 10, "output": 5, "source_ref": "usage-1"},
        )
        self.span("w1", "human-wait", 8000, 9500, "s0")
        self.span("h1", "human-active", 8500, 9000, "s0")
        for name, ns in [
            ("idea-received", 0),
            ("comparable-ready", 6000),
            ("human-decision", 9500),
        ]:
            self.at(ns, m.mark, self.d, name)
        s = m.summarize(self.d, as_of=None)
        self.assertTrue(s["complete"], s["diagnostics"])
        e = s["elapsed"]
        self.assertEqual(
            (e["phases"]["gate"]["elapsed_ns"], e["phases"]["gate"]["effort_ns"]),
            (5000, 7000),
        )
        self.assertEqual(
            (e["machine_elapsed_ns"], e["machine_effort_ns"], e["session_ns"]),
            (6000, 8000, 10000),
        )
        self.assertEqual((e["human_wait_ns"], e["human_active_ns"]), (1500, 500))
        self.assertEqual(s["lead_times"]["idea_to_comparable_ns"], 6000)
        self.assertEqual(s["lead_times"]["comparable_to_decision_ns"], 3500)
        self.assertIsNone(s["lead_times"]["decision_to_verified_ns"])
        self.assertEqual(s["counts"]["started"], 6)
        self.assertEqual(s["token_usage"], {"input": 10, "output": 5})

    def test_nested_machine_span_not_double_counted(self):
        self.span("s", "session", 0, 10000)
        self.span("c", "command", 1000, 5000, "s")
        self.span("g", "gate", 1500, 3000, "c")
        s = m.summarize(self.d, as_of=None)
        self.assertEqual(s["elapsed"]["machine_effort_ns"], 4000)
        self.assertIsNone(s["elapsed"]["human_active_ns"])

    def test_open_cross_domain_negative_and_overlap(self):
        self.span("s", "session", 0, 10000)
        self.at(
            100, m.start_span, self.d, span_id="open", phase="gate", command_id="open"
        )
        self.at(
            100, m.start_span, self.d, span_id="cross", phase="gate", command_id="cross"
        )
        self.at(200, m.finish_span, self.d, "cross", outcome="success", domain="other")
        self.span("negative", "gate", 200, 100)
        self.span("a", "human-active", 100, 300)
        self.span("b", "human-active", 200, 400)
        s = self.at(500, m.summarize, self.d)
        self.assertFalse(s["complete"])
        self.assertTrue(
            {
                "open-span",
                "clock-domain-mismatch",
                "negative-duration",
                "human-active-overlap",
            }
            <= {r["code"] for r in s["diagnostics"]}
        )
        self.assertEqual(
            next(x for x in s["spans"] if x["span_id"] == "open")["censored_ns"], 400
        )

    def test_semantic_retries_and_conflict(self):
        self.at(
            10,
            m.start_span,
            self.d,
            span_id="g",
            phase="gate",
            command_id="suite:tests/x.tests.py",
        )
        original = (self.d / "spans/g.start.json").read_bytes()
        self.at(
            20,
            m.start_span,
            self.d,
            span_id="g",
            phase="gate",
            command_id="suite:tests/x.tests.py",
        )
        self.assertEqual(original, (self.d / "spans/g.start.json").read_bytes())
        self.at(30, m.finish_span, self.d, "g", outcome="failure", exit_code=124)
        with self.assertRaises(m.MeasurementError):
            m.finish_span(self.d, "g", outcome="success")
        self.assertEqual(
            m.summarize(self.d, as_of=None)["counts"]["by_outcome"]["timeout"], 0
        )

    def test_artifact_integrity_and_missing_logs(self):
        p = Path(self.tmp.name).resolve() / "receipt"
        p.write_text("original")
        self.span(
            "s", "session", 0, 100, artifacts=[("verification-receipt", str(p), None)]
        )
        self.assertTrue(m.summarize(self.d, as_of=None)["complete"])
        p.write_text("changed")
        self.assertIn(
            "ref-changed",
            {x["code"] for x in m.summarize(self.d, as_of=None)["diagnostics"]},
        )
        self.span("g", "gate", 0, 10, logs=[("stderr", str(p.parent / "missing"))])
        self.assertIn(
            "missing-ref",
            {x["code"] for x in m.summarize(self.d, as_of=None)["diagnostics"]},
        )

    def test_invalid_inputs_and_record_tamper(self):
        for name in ["../escape", "..", "a/b", "a" * 65]:
            with self.assertRaises(m.MeasurementError):
                m.start_span(self.d, phase="gate", command_id="g", span_id=name)
        with self.assertRaises(m.MeasurementError):
            m.start_span(self.d, phase="Gate", command_id="g")
        with self.assertRaises(m.MeasurementError):
            m.open_measurement(
                self.d / "other", measurement_id="m", run_id="r", scope="feature"
            )
        self.span("s", "session", 0, 100)
        p = self.d / "spans/s.finish.json"
        d = json.loads(p.read_text())
        d["unknown"] = True
        p.write_text(json.dumps(d))
        self.assertFalse(m.summarize(self.d, as_of=None)["complete"])

    def test_symlink_and_secret_exclusion(self):
        link = Path(self.tmp.name).resolve() / "linked"
        link.symlink_to(self.d, target_is_directory=True)
        with self.assertRaises(m.MeasurementError):
            m.open_measurement(link, measurement_id="m", run_id="r", scope="all")
        self.assertEqual(
            m.statistics([5, 1, 3, 9, 7]), {"median": 5, "min": 1, "max": 9, "mad": 2}
        )
        self.assertNotIn("argv", (self.d / "measurement.json").read_text())

    def test_owned_temp_root_can_be_canonicalized_without_admitting_links(self):
        physical = Path(self.tmp.name).resolve() / "physical-temp"
        physical.mkdir()
        alias = physical.parent / "temp-alias"
        alias.symlink_to(physical, target_is_directory=True)
        with tempfile.TemporaryDirectory(dir=alias) as temporary:
            raw = Path(temporary) / "measurement"
            with self.assertRaises(m.MeasurementError):
                m.open_measurement(raw, measurement_id="m", run_id="r", scope="all")
            self.assertFalse(raw.exists())
            owned_root = Path(temporary).resolve()
            destination = owned_root / "measurement"
            m.open_measurement(destination, measurement_id="m", run_id="r", scope="all")
            nested_link = owned_root / "evidence-alias"
            nested_link.symlink_to(destination, target_is_directory=True)
            for rejected in (nested_link, nested_link / "child"):
                with self.assertRaises(m.MeasurementError):
                    m.open_measurement(
                        rejected, measurement_id="m", run_id="r", scope="all"
                    )
            self.assertFalse((destination / "child").exists())

    def test_all_outcomes(self):
        self.span("s", "session", 0, 100)
        for i, outcome in enumerate(m.OUTCOMES):
            self.span("g" + str(i), "gate", 0, 10, outcome=outcome)
        s = m.summarize(self.d, as_of=None)
        self.assertEqual(s["counts"]["by_outcome"]["success"], 2)
        for outcome in set(m.OUTCOMES) - {"success"}:
            self.assertEqual(s["counts"]["by_outcome"][outcome], 1)

    def test_reader_rejects_malformed_types_and_naive_dates(self):
        self.span("s", "session", 0, 100)
        header = self.d / "measurement.json"
        original = header.read_text()
        for field, value in [
            ("head", 42),
            ("input_manifest_sha256", []),
            ("tools", []),
        ]:
            data = json.loads(original)
            data["environment"][field] = value
            header.write_text(json.dumps(data))
            with self.assertRaises(m.MeasurementError):
                m.summarize(self.d)
        header.write_text(original)
        finish = self.d / "spans/s.finish.json"
        data = json.loads(finish.read_text())
        data["utc"] = "2026-10-25T00:00:00"
        finish.write_text(json.dumps(data))
        self.assertIn(
            "record-invalid", {x["code"] for x in m.summarize(self.d)["diagnostics"]}
        )
        for value in (float("nan"), float("inf"), True):
            with self.assertRaises(m.MeasurementError):
                m.statistics([value])

    def test_retried_finish_mark_and_changed_input(self):
        path = Path(self.tmp.name).resolve() / "input"
        path.write_text("one")
        self.at(
            10,
            m.start_span,
            self.d,
            span_id="g",
            phase="gate",
            command_id="gate",
            inputs=[path],
        )
        first = self.at(20, m.finish_span, self.d, "g", outcome="success")
        self.assertEqual(
            first, self.at(30, m.finish_span, self.d, "g", outcome="success")
        )
        mark = self.at(30, m.mark, self.d, "human-decision", ref="dec-1")
        self.assertEqual(
            mark, self.at(40, m.mark, self.d, "human-decision", ref="dec-1")
        )
        with self.assertRaises(m.MeasurementError):
            m.mark(self.d, "human-decision", ref="dec-2")
        path.write_text("two")
        with self.assertRaises(m.MeasurementError):
            m.start_span(
                self.d, span_id="g", phase="gate", command_id="gate", inputs=[path]
            )

    def test_schema_keys_match_written_records(self):
        schema = json.loads(
            (ROOT / "contracts/run-measurement.schema.json").read_text()
        )
        variants = {x["properties"]["kind"]["const"]: x for x in schema["oneOf"]}
        self.span("s", "session", 0, 100)
        self.at(50, m.mark, self.d, "human-decision", ref="decision")
        for path in self.d.rglob("*.json"):
            record = json.loads(path.read_text())
            self.assertEqual(set(record), set(variants[record["kind"]]["required"]))
            self.assertFalse(variants[record["kind"]]["additionalProperties"])

    def test_milestone_and_parent_failures(self):
        self.span("s", "session", 0, 100)
        self.span("outside", "gate", 50, 150, "s")
        self.span("orphan", "gate", 10, 20, "missing")
        self.at(50, m.mark, self.d, "comparable-ready")
        self.at(10, m.mark, self.d, "human-decision")
        summary = m.summarize(self.d, as_of=None)
        self.assertTrue(
            {"child-outside-parent", "parent-missing", "milestone-order"}
            <= {x["code"] for x in summary["diagnostics"]}
        )
        self.assertIsNone(summary["lead_times"]["comparable_to_decision_ns"])

    def test_parent_owner_and_no_session_finish(self):
        self.at(
            0,
            m.start_span,
            self.d,
            span_id="parent",
            phase="session",
            command_id="batch",
        )
        observer = m.Observer(self.d, command_id="nested", parent_span_id="parent")
        span = observer.start("command", "child")
        observer.finish(span, "success", 0)
        observer.close(0)
        self.assertFalse((self.d / "spans/parent.finish.json").exists())
        self.assertEqual(len(list((self.d / "spans").glob("*.start.json"))), 2)
        with self.assertRaises(m.MeasurementError):
            m.Observer(self.d, command_id="nested", parent_span_id="missing")

    def test_cli_semantic_retries_and_outcomes(self):
        import contextlib
        import io

        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            self.assertEqual(
                m.main(
                    [
                        "start",
                        "--dir",
                        str(self.d),
                        "--phase",
                        "gate",
                        "--command-id",
                        "gate",
                        "--span-id",
                        "cli",
                    ]
                ),
                0,
            )
            self.assertEqual(
                m.main(
                    [
                        "start",
                        "--dir",
                        str(self.d),
                        "--phase",
                        "gate",
                        "--command-id",
                        "gate",
                        "--span-id",
                        "cli",
                    ]
                ),
                0,
            )
            self.assertEqual(
                m.main(
                    [
                        "finish",
                        "--dir",
                        str(self.d),
                        "--span-id",
                        "cli",
                        "--outcome",
                        "failure",
                        "--exit-code",
                        "124",
                    ]
                ),
                0,
            )
        self.assertEqual(stdout.getvalue().splitlines()[:2], ["cli", "cli"])
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(
                m.main(
                    [
                        "finish",
                        "--dir",
                        str(self.d),
                        "--span-id",
                        "cli",
                        "--outcome",
                        "Success",
                    ]
                ),
                2,
            )

    def test_tokens_partial_and_zero_observed_duration(self):
        self.span("s", "session", 0, 100)
        self.span(
            "m1",
            "model",
            10,
            20,
            token_usage={"input": 10, "output": 5, "source_ref": "usage"},
        )
        self.span("m2", "model", 30, 40)
        self.span("g", "gate", 50, 50)
        summary = m.summarize(self.d, as_of=None)
        self.assertIsNone(summary["token_usage"])
        self.assertEqual(summary["token_usage_missing_reason"], "incomplete")
        self.assertEqual(summary["elapsed"]["phases"]["gate"]["elapsed_ns"], 0)

    def test_attempt_chain_keeps_undecided_and_decision_changes(self):
        directories = []
        for attempt, decision in [(1, "dec-1"), (2, None), (3, "dec-2")]:
            directory = Path(self.tmp.name).resolve() / ("attempt-" + str(attempt))
            directories.append(directory)
            m.open_measurement(
                directory,
                measurement_id="m" + str(attempt),
                run_id="r" + str(attempt),
                scope="all",
                attempt=attempt,
                parent_run_id=None if attempt == 1 else "r" + str(attempt - 1),
                scenario_id="scenario",
                trial_id="trial",
                rerun_reason="initial" if attempt == 1 else "resume",
            )
            self.at(
                0,
                m.start_span,
                directory,
                span_id="s",
                phase="session",
                command_id="session",
            )
            self.at(
                100,
                m.finish_span,
                directory,
                "s",
                outcome="undecided" if attempt == 2 else "rejected",
            )
            if decision:
                self.at(50, m.mark, directory, "human-decision", ref=decision)
        result = m.join_attempts(directories)
        self.assertTrue(result["complete"])
        self.assertEqual(result["n"], 3)
        self.assertEqual(
            [x["decision_changed"] for x in result["groups"][0]["attempts"]],
            [None, None, True],
        )
        result = m.join_attempts(directories + [directories[1]])
        self.assertFalse(result["complete"])
        self.assertIn("attempt-duplicate", {x["code"] for x in result["diagnostics"]})


if __name__ == "__main__":
    unittest.main()
