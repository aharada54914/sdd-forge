#!/usr/bin/env python3
"""Opt-in existing owner admission, fixed inputs and fresh source gate checks."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
from unittest.mock import patch
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SCRIPTS))
from research_evidence import digest  # noqa: E402 - sibling runtime path is explicit.


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


fixture = load("owner_fixture", ROOT / "tests/research-consumers.tests.py")
conditional = load("research_conditional", SCRIPTS / "review-conditional-inputs.py")
binder = load("research_binder", SCRIPTS / "research-evidence-tools.py")
contract = load("research_contract", SCRIPTS / "check-contract.py")


class Owners(unittest.TestCase):
    graph = fixture.Consumers.graph

    def setUp(self):
        fixture.Consumers.setUp(self)
        self.relations = self.graph()
        self.records = (
            self.root / "specs/sample/research/records/research-evidence.json"
        )
        self.records.parent.mkdir(parents=True)
        self.records.write_text(json.dumps(self.doc))
        self.relations_path = self.records.parents[1] / "relations.json"
        self.relations_path.write_text(json.dumps(self.relations))
        self.manifest = self.root / "snapshots.json"
        self.manifest.write_text(json.dumps(self.snapshots))
        self.packet = self.records.parents[1] / "review-input.json"
        (self.root / "specs/sample/design.md").write_text("# Design\n")

    def bind(self):
        return binder.main(
            [
                "bind",
                "--file",
                str(self.records),
                "--repo-root",
                str(self.root),
                "--relations",
                str(self.relations_path),
                "--snapshots",
                str(self.manifest),
                "--snapshot-root",
                str(self.root),
                "--output",
                str(self.packet),
            ]
        )

    def test_optional_absent_and_actual_spec_impl_resolver(self):
        before = conditional.resolve(self.root, "sample", "spec")
        self.assertEqual([], before["inputs"])
        self.assertEqual(0, self.bind())
        for stage in ("spec", "impl"):
            result = conditional.resolve(self.root, "sample", stage)
            self.assertEqual(
                {
                    self.records.relative_to(self.root).as_posix(),
                    self.relations_path.relative_to(self.root).as_posix(),
                    self.packet.relative_to(self.root).as_posix(),
                },
                {e["path"] for e in result["inputs"]},
            )
        self.packet.unlink()
        self.assertEqual(before, conditional.resolve(self.root, "sample", "spec"))

    def test_existing_bash_and_powershell_admission(self):
        pwsh = shutil.which("pwsh")
        if pwsh is None:
            self.skipTest("pwsh required for runtime parity")
        self.assertEqual(0, self.bind())
        directory = self.root / "reports/review-context"
        directory.mkdir(parents=True)
        previous = digest(b"1|spec|spec-reviewer-a|prior-run|prior-session|")
        ledger = directory / "identity-ledger.json"
        ledger.write_text(
            json.dumps(
                dict(
                    schema="review-identity-ledger/v1",
                    records=[
                        dict(
                            sequence=1,
                            stage="spec",
                            role="spec-reviewer-a",
                            run_id="prior-run",
                            host_session_id="prior-session",
                            previous_record_sha256="",
                            record_sha256=previous,
                        )
                    ],
                )
            )
        )
        required = "specs/sample/requirements.md"
        for stage in ("spec", "impl"):
            inputs = conditional.resolve(self.root, "sample", stage)["inputs"]
            inputs += [
                dict(path=required, sha256=digest((self.root / required).read_bytes()))
            ]
            for role in (stage + "-reviewer-a", stage + "-reviewer-b"):
                manifest = dict(
                    schema="review-context-invocation/v2",
                    input_mode="file-manifest",
                    fallback_mode="none",
                    read_only=True,
                    stage=stage,
                    role=role,
                    feature="sample",
                    run_id="next-run",
                    host_session_id="next-session",
                    sequence=2,
                    identity_ledger_path="reports/review-context/identity-ledger.json",
                    identity_ledger_sha256=digest(ledger.read_bytes()),
                    previous_record_sha256=previous,
                    allowed_input_manifest=inputs,
                )
                path = self.root / "manifest.json"
                for omit in (False, True):
                    manifest["allowed_input_manifest"] = inputs[:-2] if omit else inputs
                    path.write_text(json.dumps(manifest))
                    commands = [
                        [
                            "bash",
                            str(SCRIPTS / "validate-review-context-set.sh"),
                            str(path),
                            str(self.root),
                        ],
                        [
                            pwsh,
                            "-NoProfile",
                            "-File",
                            str(SCRIPTS / "validate-review-context-set.ps1"),
                            "-Manifest",
                            str(path),
                            "-RepositoryRoot",
                            str(self.root),
                        ],
                    ]
                    for command in commands:
                        with self.subTest(
                            stage=stage, role=role, omit=omit, runtime=command[0]
                        ):
                            result = subprocess.run(
                                command, text=True, capture_output=True
                            )
                            if omit:
                                self.assertNotEqual(
                                    0, result.returncode, result.stdout + result.stderr
                                )
                            else:
                                self.assertEqual(
                                    0, result.returncode, result.stdout + result.stderr
                                )

    def test_worktree_changes_do_not_change_fixed_reviewer_inputs(self):
        self.assertEqual(0, self.bind())
        for args in (
            ["init", "-q"],
            ["add", "."],
            [
                "-c",
                "user.name=Fixture",
                "-c",
                "user.email=fixture@example.invalid",
                "commit",
                "-qm",
                "research",
            ],
        ):
            subprocess.run(["git", "-C", str(self.root), *args], check=True)
        revision = subprocess.check_output(
            ["git", "-C", str(self.root), "rev-parse", "HEAD"], text=True
        ).strip()
        fixed = conditional.resolve(self.root, "sample", "impl", revision)
        self.records.write_text("{}")
        self.assertEqual(
            fixed, conditional.resolve(self.root, "sample", "impl", revision)
        )
        with self.assertRaises(ValueError):
            conditional.resolve(self.root, "sample", "impl")

    def test_packet_result_identity_status_and_closed_fields(self):
        self.assertEqual(0, self.bind())
        baseline = json.loads(self.packet.read_text())
        import copy

        for change in ("extra", "complete", "citation", "hash", "status", "path"):
            packet = copy.deepcopy(baseline)
            result = packet["source_verification"]
            if change == "extra":
                result["authenticated"] = True
            if change == "complete":
                result["complete"] = False
            if change == "citation":
                result["results"][0]["citation"] = True
            if change == "hash":
                result["results"][0]["content_sha256"] = "0" * 64
            if change == "status":
                packet["status"] = "open-questions"
            if change == "path":
                result["results"][0]["original"] = "/private/original"
            self.packet.write_text(json.dumps(packet))
            with self.subTest(change=change), self.assertRaises(ValueError):
                conditional.resolve(self.root, "sample", "spec")

    def test_bind_rejects_replacement_after_verification(self):
        verify = binder.verify_originals

        def swap(*args, **kwargs):
            result = verify(*args, **kwargs)
            self.records.write_text('{"invalid":"replacement after checking"}')
            return result

        with (
            patch.object(binder, "verify_originals", side_effect=swap),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(1, self.bind())
        self.assertFalse(self.packet.exists())

    def test_contract_owner_rechecks_original_and_requires_runtime_cache(self):
        evidence = self.root / "source-check.json"
        evidence.write_text(
            json.dumps(
                dict(
                    schema="source-evidence-check/v1",
                    file=self.records.relative_to(self.root).as_posix(),
                    records_sha256=digest(self.records.read_bytes()),
                    snapshots="snapshots.json",
                    snapshots_sha256=digest(self.manifest.read_bytes()),
                    matching="exact",
                )
            )
        )
        checks = [dict(id="source-evidence", passes=True, evidence="source-check.json")]
        with patch.dict(os.environ, {"SDD_RESEARCH_SNAPSHOT_ROOT": str(self.root)}):
            failures = []
            contract._pass_research_evidence(checks, self.root, failures)
            self.assertEqual([], failures)
            (self.root / "original").write_text("changed original")
            contract._pass_research_evidence(checks, self.root, failures)
            self.assertTrue(failures)
        with patch.dict(os.environ, {}, clear=True):
            failures = []
            contract._pass_research_evidence(checks, self.root, failures)
            self.assertTrue(failures)
        failures = []
        contract._pass_research_evidence([], self.root, failures)
        self.assertEqual([], failures)


if __name__ == "__main__":
    unittest.main()
