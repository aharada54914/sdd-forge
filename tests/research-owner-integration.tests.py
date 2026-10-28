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

    def test_review_status_transition_preserves_exact_original_pin(self):
        path = self.root / 'specs/sample/requirements.md'
        original = b'Spec-Review-Status: Pending\n' + path.read_bytes()
        path.write_bytes(original)
        self.relations['edges'][0]['to']['document_sha256'] = digest(original)
        self.relations_path.write_text(json.dumps(self.relations))
        self.assertEqual(0, self.bind())
        packet = self.packet.read_bytes()
        passed = original.replace(b'Spec-Review-Status: Pending', b'Spec-Review-Status: Passed')
        path.write_bytes(passed)
        resolved = conditional.resolve(self.root, 'sample', 'spec')
        pins = {entry['path']: entry['sha256'] for entry in resolved['research_inputs']}
        self.assertEqual(digest(original), pins['specs/sample/requirements.md'])
        self.assertEqual(digest(passed), resolved['observed']['specs/sample/requirements.md'])
        self.assertEqual(packet, self.packet.read_bytes())
        for changed in (passed + b'Changed requirement\n', passed.replace(b'REQ-001 First', b'REQ-001 Other'),
                        passed + b'Spec-Review-Status: Passed\n',
                        passed.replace(b'Spec-Review-Status: Passed', b'Spec-Review-Status: Unknown')):
            with self.subTest(content=changed), self.assertRaises(ValueError):
                path.write_bytes(changed)
                conditional.resolve(self.root, 'sample', 'spec')

    def test_existing_bash_and_powershell_admission(self):
        pwsh = shutil.which("pwsh")
        if pwsh is None:
            self.skipTest("pwsh required for runtime parity")
        adr_path = "docs/adr/0001-research.md"
        adr = self.root / adr_path
        adr.parent.mkdir(parents=True)
        adr.write_text("# Research ADR\n")
        self.relations["edges"].append(dict(
            relation="justifies", **{"from": self.relations["edges"][0]["from"],
            "to": dict(kind="ADR", id="ADR-0001", path=adr_path,
                       document_sha256=digest(adr.read_bytes()))}))
        self.relations_path.write_text(json.dumps(self.relations))
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
            if stage == "impl":
                design_adr = self.root / "docs/adr/0002-design.md"
                design_adr.write_text("# Design ADR\n")
                design = self.root / "specs/sample/design.md"
                design.write_text("# Design\n`docs/adr/0002-design.md`\n")
                precheck = self.root / "reports/impl-review/sample/attempt-1/round-1/precheck-result.json"
                precheck.parent.mkdir(parents=True)
                precheck.write_text(json.dumps(dict(
                    schema="impl-review-precheck/v1", feature="sample", attempt=1, round=1,
                    design_sha256=digest(design.read_bytes()),
                    adr_inputs=[dict(path="docs/adr/0002-design.md", sha256=digest(design_adr.read_bytes()))])))
                inputs += [dict(path=p.relative_to(self.root).as_posix(), sha256=digest(p.read_bytes()))
                           for p in (design, precheck, design_adr)]
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
                cases = ["complete", "missing-research"]
                if stage == "impl":
                    cases += ["missing-design", "unlisted-adr"]
                for case in cases:
                    selected = list(inputs)
                    if case == "missing-research":
                        selected = [entry for entry in selected if entry["path"] != adr_path]
                    elif case == "missing-design":
                        selected = [entry for entry in selected if entry["path"] != "docs/adr/0002-design.md"]
                    elif case == "unlisted-adr":
                        extra = self.root / "docs/adr/0003-unlisted.md"
                        extra.write_text("# Unlisted\n")
                        selected.append(dict(path="docs/adr/0003-unlisted.md", sha256=digest(extra.read_bytes())))
                    manifest["allowed_input_manifest"] = selected
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
                            stage=stage, role=role, case=case, runtime=command[0]
                        ):
                            result = subprocess.run(
                                command, text=True, capture_output=True
                            )
                            if case != "complete":
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

    def test_powershell_research_opt_in_requires_exact_string_id(self):
        pwsh = shutil.which("pwsh")
        if pwsh is None:
            self.skipTest("pwsh required for runtime parity")
        # No dispatcher/Python module is installed beside this copy. Old-route
        # inputs must still work; the exact opt-in must attempt delegation.
        script = self.root / "check-contract.ps1"
        script.write_bytes((SCRIPTS / "check-contract.ps1").read_bytes())
        (self.root / "evidence.log").write_text("Synthetic legacy evidence\n")
        path = self.root / "contract.json"
        ids = (
            "lint",
            "typecheck",
            "unit-tests",
            "build",
            "placeholder-scan",
            "task-state-check",
        )
        for schema in (None, "verification-contract/v2"):
            for check_id in (
                True,
                False,
                ["source-evidence"],
                [True],
                None,
                1,
                "SOURCE-EVIDENCE",
                "source-evidence",
            ):
                document = dict(
                    task_id="T-001",
                    checks=[
                        dict(id=i, required=True, passes=True, evidence="evidence.log")
                        for i in ids
                    ],
                )
                document["checks"].append(
                    dict(
                        id=check_id,
                        required=False,
                        passes=False,
                        waiver_reason="Fixture waiver",
                    )
                )
                if schema is not None:
                    document["schema"] = schema
                path.write_text(json.dumps(document))
                result = subprocess.run(
                    [
                        pwsh,
                        "-NoProfile",
                        "-File",
                        str(script),
                        str(path),
                        str(self.root),
                    ],
                    text=True,
                    capture_output=True,
                )
                with self.subTest(schema=schema, check_id=check_id):
                    if check_id == "source-evidence":
                        self.assertNotEqual(0, result.returncode)
                        self.assertIn("py-dispatch.ps1", result.stderr)
                    elif check_id is None:
                        # Historical PowerShell null-key validation still fails
                        # in the legacy owner, without loading Python.
                        self.assertNotEqual(0, result.returncode)
                        self.assertNotIn("py-dispatch", result.stderr)
                        self.assertIn("ContainsKey", result.stderr)
                    else:
                        self.assertEqual(
                            0, result.returncode, result.stdout + result.stderr
                        )
                        self.assertNotIn("py-dispatch", result.stderr)
                        self.assertEqual(
                            "Verification contract passed for task T-001.\n",
                            result.stdout,
                        )

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
