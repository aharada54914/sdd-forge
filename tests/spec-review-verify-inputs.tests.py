#!/usr/bin/env python3
"""Exercise the real spec precheck read-only replay path in disposable roots."""

import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-review-loop/scripts"


def digest(data):
    return hashlib.sha256(data).hexdigest()


class VerifyInputsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        scripts = self.root / "plugins/sdd-review-loop/scripts"
        scripts.mkdir(parents=True)
        for name in ("spec-review-precheck.sh", "spec-review-precheck.ps1",
                     "review-contract-validate.sh", "review-contract-validate.ps1"):
            shutil.copy2(SCRIPTS / name, scripts / name)
        self.spec = self.root / "specs/example"
        self.spec.mkdir(parents=True)
        self.requirements = self.spec / "requirements.md"
        self.acceptance = self.spec / "acceptance-tests.md"
        self.investigation = self.spec / "investigation.md"
        self.requirements.write_bytes(b"Spec-Review-Status: Pending\n")
        self.acceptance.write_bytes(b"acceptance\n")
        self.investigation.write_bytes(b"investigation\n")
        calibration = self.root / "plugins/sdd-review-loop/references/spec-review-calibration.md"
        calibration.parent.mkdir(parents=True)
        calibration.write_bytes(b"calibration\n")
        self.round_dir = self.root / "reports/spec-review/example/attempt-1/round-2"
        self.round_dir.mkdir(parents=True)
        req = digest(self.requirements.read_bytes())
        acc = digest(self.acceptance.read_bytes())
        inv = digest(self.investigation.read_bytes())
        record = {
            "schema": "spec-review-precheck/v1", "stage": "spec", "feature": "example",
            "attempt": 1, "round": 2, "spec_review_status_field": "Pending",
            "requirements_sha256": req, "acceptance_sha256": acc,
            "investigation_sha256": inv, "calibration_sha256": digest(calibration.read_bytes()),
            "input_sha256": digest(f"{req}:{acc}:{inv}".encode()),
            "edit_summary": "fixed", "reset": False,
            "generated_at": "2026-10-07T00:00:00Z",
        }
        self.precheck = self.round_dir / "precheck-result.json"
        self.write_record(record)

    def write_record(self, record):
        self.precheck.write_text(json.dumps(record), encoding="utf-8")

    def run_precheck(self, shell, attempt="1", round_number="2"):
        script = self.root / "plugins/sdd-review-loop/scripts" / f"spec-review-precheck.{shell}"
        if shell == "sh":
            argv = ["bash", str(script), "example", attempt, round_number, "--verify-inputs"]
        else:
            argv = ["pwsh", "-NoProfile", "-File", str(script), "-Feature", "example",
                    "-Attempt", attempt, "-Round", round_number, "-VerifyInputs"]
        before = self.snapshot()
        result = subprocess.run(argv, capture_output=True, text=True)
        self.assertEqual(before, self.snapshot(), f"{shell} mutated fixture: {result.stderr}")
        return result

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes()
                for p in self.root.rglob("*") if p.is_file()}

    def write_prior_contract(self, conditional=(), mutate=None):
        """Seal a synthetic round-one NEEDS_WORK review for real next-round prechecks."""
        self.requirements.write_bytes(b"Spec-Review-Status: Pending\n")
        prior = self.round_dir.parent / "round-1"
        prior.mkdir(exist_ok=True)
        req_sha = digest(self.requirements.read_bytes())
        acc_sha = digest(self.acceptance.read_bytes())
        inv_sha = digest(self.investigation.read_bytes())
        calibration = self.root / "plugins/sdd-review-loop/references/spec-review-calibration.md"
        cal_sha = digest(calibration.read_bytes())
        precheck = {
            "schema": "spec-review-precheck/v1", "stage": "spec", "feature": "example",
            "attempt": 1, "round": 1, "requirements_sha256": req_sha,
            "acceptance_sha256": acc_sha, "investigation_sha256": inv_sha,
            "calibration_sha256": cal_sha,
        }
        def write(name, value):
            path = prior / name
            path.write_text(json.dumps(value), encoding="utf-8")
            return path
        precheck_path = write("precheck-result.json", precheck)
        ids_a = ("REQ-TESTABILITY", "GOAL-AC-TRACE", "AC-OBSERVABLE",
                 "SCOPE-BOUNDARY", "CONSTRAINTS-EXPLICIT", "RISK-VALIDATION-SURFACE",
                 "DOMAIN-CONFORMANCE")
        ids_b = ("AMBIGUITY", "CONTRADICTION", "EDGE-CASE-COVERAGE",
                 "ASSUMPTIONS-RESOLVABLE", "APPROVAL-BOUNDARY",
                 "DOWNSTREAM-READINESS", "DOMAIN-CONFORMANCE")
        checks_a = [{"id": name, "result": "FAIL" if index == 0 else "PASS",
                     "severity": "Major" if index == 0 else "Minor",
                     "finding": "synthetic finding"} for index, name in enumerate(ids_a)]
        checks_b = [{"id": name, "result": "PASS", "severity": "Minor",
                     "finding": "synthetic pass"} for name in ids_b]
        summary = {
            "schema": "integrated-summary/v1", "attempt": 1, "round": 1,
            "reviewer_a_checks": [{key: check[key] for key in ("id", "result", "severity")}
                                  for check in checks_a],
            "reviewer_a_fail_count": 1, "reviewer_a_pass_count": 6,
            "reviewer_a_skip_count": 0, "generated_at": "2026-10-07T00:00:00Z",
        }
        summary_path = write("integrated-summary.json", summary)
        def entry(path, sha):
            return {"path": str(path), "sha256": sha}
        common = [entry(self.requirements, req_sha), entry(self.acceptance, acc_sha),
                  entry(self.investigation, inv_sha),
                  entry(precheck_path, digest(precheck_path.read_bytes())),
                  entry(calibration, cal_sha)]
        for name in conditional:
            domain_file = self.root / name
            domain_file.parent.mkdir(exist_ok=True)
            domain_file.write_bytes(f"sealed {name}\n".encode())
            common.append(entry(domain_file, digest(domain_file.read_bytes())))
        manifests = [common, common + [entry(summary_path, digest(summary_path.read_bytes()))]]
        reviewers = []
        for role, checks, manifest, verdict, suffix in (
            ("spec-reviewer-a", checks_a, manifests[0], "NEEDS_WORK", "a"),
            ("spec-reviewer-b", checks_b, manifests[1], "PASS", "b"),
        ):
            reviewer = {"schema": f"{role}/v1", "stage": "spec", "role": role,
                        "run_id": f"synthetic-{suffix}", "host_session_id": f"session-{suffix}",
                        "allowed_input_manifest": manifest, "checks": checks, "verdict": verdict}
            write(f"reviewer-{suffix}.json", reviewer)
            reviewers.append({key: reviewer[key] for key in
                              ("role", "run_id", "host_session_id", "allowed_input_manifest")})
        contract = {
            "schema": "spec-review-contract/v1", "stage": "spec", "feature": "example",
            "attempt": 1, "round": 1, "requirements_sha256": req_sha,
            "acceptance_sha256": acc_sha, "investigation_sha256": inv_sha,
            "reviewers": reviewers, "run_id": "synthetic-orchestrator",
            "verdict": "NEEDS_WORK", "warningCount": 0,
        }
        write("integrated-verdict.json", {
            "schema": "spec-review-integrated-verdict/v1", "stage": "spec",
            "feature": "example", "attempt": 1, "round": 1,
            "reviewer_a_run_id": "synthetic-a", "reviewer_b_run_id": "synthetic-b",
            "reviewer_a_host_session_id": "session-a",
            "reviewer_b_host_session_id": "session-b",
            "finding_counts": {"critical": 0, "major": 1, "minor": 0},
            "verdict": "NEEDS_WORK", "warningCount": 0,
        })
        if mutate:
            mutate(contract, prior)
        write("spec-review-contract.json", contract)
        self.requirements.write_bytes(b"Spec-Review-Status: Pending\nchanged for round two\n")
        if self.round_dir.exists():
            shutil.rmtree(self.round_dir)

    def run_next_round(self, shell):
        script = self.root / "plugins/sdd-review-loop/scripts" / f"spec-review-precheck.{shell}"
        if shell == "sh":
            argv = ["bash", str(script), "example", "1", "2", "--edit-summary=fixed"]
        else:
            argv = ["pwsh", "-NoProfile", "-File", str(script), "-Feature", "example",
                    "-Attempt", "1", "-Round", "2", "-EditSummary", "fixed"]
        return subprocess.run(argv, capture_output=True, text=True)

    def test_historical_conditional_contracts(self):
        domain_paths = ("domain/context-map.md", "domain/domain-contract.json")
        def relocate(contract, prior):
            old_root = "/synthetic-previous-checkout"
            for reviewer in contract["reviewers"]:
                for item in reviewer["allowed_input_manifest"]:
                    item["path"] = item["path"].replace(str(self.root), old_root, 1)
            for suffix in ("a", "b"):
                path = prior / f"reviewer-{suffix}.json"
                reviewer = json.loads(path.read_text())
                for item in reviewer["allowed_input_manifest"]:
                    item["path"] = item["path"].replace(str(self.root), old_root, 1)
                path.write_text(json.dumps(reviewer), encoding="utf-8")
        cases = (
            ("both_after_live_change", domain_paths, None, True),
            ("one_after_live_removal", domain_paths[:1], None, True),
            ("absent", (), None, True),
            ("other_checkout", domain_paths, relocate, True),
            ("reviewer_hash_mismatch", domain_paths,
             lambda contract, _: contract["reviewers"][1]["allowed_input_manifest"][5].update(
                 sha256="f" * 64), False),
            ("reviewer_path_mismatch", domain_paths,
             lambda contract, _: contract["reviewers"][1]["allowed_input_manifest"].pop(5), False),
            ("duplicate", domain_paths,
             lambda contract, _: contract["reviewers"][0]["allowed_input_manifest"].append(
                 dict(contract["reviewers"][0]["allowed_input_manifest"][5])), False),
            ("unknown_extra", domain_paths,
             lambda contract, _: contract["reviewers"][0]["allowed_input_manifest"].append(
                 {"path": str(self.root / "domain/unknown.md"), "sha256": "e" * 64}), False),
            ("unknown_extra_b", domain_paths,
             lambda contract, _: contract["reviewers"][1]["allowed_input_manifest"].append(
                 {"path": str(self.root / "domain/unknown.md"), "sha256": "e" * 64}), False),
        )
        for shell in ("sh", "ps1"):
            if shell == "ps1" and not shutil.which("pwsh"):
                continue
            for name, paths, mutate, expected in cases:
                with self.subTest(shell=shell, case=name):
                    self.write_prior_contract(paths, mutate)
                    if name == "both_after_live_change":
                        for path in paths:
                            (self.root / path).write_bytes(b"changed since sealing\n")
                    elif name == "one_after_live_removal":
                        (self.root / paths[0]).unlink()
                    # The sealed domain hash is historical, not a live hash.
                    result = self.run_next_round(shell)
                    self.assertEqual(result.returncode == 0, expected, result.stderr)
                    if self.round_dir.exists():
                        shutil.rmtree(self.round_dir)

    def test_success_and_rejections(self):
        for shell in ("sh", "ps1"):
            if shell == "ps1" and not shutil.which("pwsh"):
                self.skipTest("pwsh unavailable")
            with self.subTest(shell=shell, case="success"):
                self.assertEqual(self.run_precheck(shell).returncode, 0)
            with self.subTest(shell=shell, case="identity"):
                self.assertNotEqual(self.run_precheck(shell, round_number="1").returncode, 0)
            with self.subTest(shell=shell, case="changed"):
                self.acceptance.write_bytes(b"changed\n")
                self.assertNotEqual(self.run_precheck(shell).returncode, 0)
                self.acceptance.write_bytes(b"acceptance\n")
            with self.subTest(shell=shell, case="missing"):
                self.investigation.unlink()
                self.assertNotEqual(self.run_precheck(shell).returncode, 0)
                self.investigation.write_bytes(b"investigation\n")
            with self.subTest(shell=shell, case="precheck_identity"):
                record = json.loads(self.precheck.read_text())
                record["feature"] = "other"
                self.write_record(record)
                self.assertNotEqual(self.run_precheck(shell).returncode, 0)
                record["feature"] = "example"
                record["attempt"] = 2
                self.write_record(record)
                self.assertNotEqual(self.run_precheck(shell).returncode, 0)
                record["attempt"] = 1
                self.write_record(record)
            with self.subTest(shell=shell, case="missing_precheck"):
                self.precheck.unlink()
                self.assertNotEqual(self.run_precheck(shell).returncode, 0)
                self.write_record(record)
            with self.subTest(shell=shell, case="absent_investigation_null_vs_empty"):
                self.investigation.unlink()
                absent = dict(record)
                absent["investigation_sha256"] = None
                absent["input_sha256"] = digest(
                    f"{record['requirements_sha256']}:{record['acceptance_sha256']}".encode())
                self.write_record(absent)
                self.assertEqual(self.run_precheck(shell).returncode, 0)
                absent["investigation_sha256"] = ""
                self.write_record(absent)
                self.assertNotEqual(self.run_precheck(shell).returncode, 0)
                self.investigation.write_bytes(b"investigation\n")
                self.write_record(record)


if __name__ == "__main__":
    unittest.main()
