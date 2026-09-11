#!/usr/bin/env python3
"""RT-20260908-003: recovery approvals must have a distinct signed purpose.

These contract tests do not load a signing key, sign a real authorization,
modify historical evidence, or execute a recovery transition.
"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
RECOVERY_SCHEMA = "sdd-review-recovery-approval/v1"


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RecoveryPurposeTests(unittest.TestCase):
    def test_sidecar_contract_accepts_distinct_recovery_purpose(self):
        schema = json.loads((ROOT / "contracts/approval-sidecar.schema.json").read_text())
        self.assertIn(RECOVERY_SCHEMA, schema["properties"]["schema"]["enum"])

    def test_signer_exposes_distinct_recovery_purpose(self):
        signer = load_module("recovery_test_signer", "generate-approval-sidecar.py")
        self.assertIn(RECOVERY_SCHEMA, signer.SCHEMA_BASENAMES)

    def test_validator_dispatches_to_dedicated_recovery_content_contract(self):
        validator = load_module("recovery_test_validator", "validate-approval-sidecar.py")
        self.assertIn(RECOVERY_SCHEMA, validator.CONTENT_SCHEMA_INFO)
        self.assertEqual(
            validator.CONTENT_SCHEMA_INFO[RECOVERY_SCHEMA]["schema_filename"],
            "review-recovery-request.schema.json",
        )

    def test_provenance_only_mode_cannot_authorize_recovery(self):
        validator = load_module("recovery_provenance_validator", "validate-approval-sidecar.py")
        sidecar = {
            "schema": RECOVERY_SCHEMA,
            "context_sha256": "sha256:" + "0" * 64,
            "primary_approval": {
                "status": "Approved", "approver": "fixture-only",
                "approved_at": "2026-09-08T00:00:00Z",
            },
            "second_approval": None,
            "effective_at": None,
            "predecessor_context_sha256": None,
            "weakening_verdict": None,
            "approval_epoch": 1,
            "hmac": "0" * 64,
        }
        with tempfile.TemporaryDirectory(prefix="sdd-recovery-purpose-test-") as tmp:
            path = Path(tmp) / "fixture.approval.json"
            path.write_text(json.dumps(sidecar), encoding="utf-8")
            # Isolate only credential resolution; all validator logic remains real.
            # Never consult the user's environment, key file or home key fallback.
            with patch.object(validator, "_resolve_key_or_raise", return_value=b"fixture-only-not-a-secret"):
                with self.assertRaises(validator.ValidateApprovalSidecarError) as caught:
                    validator.run_verify_provenance(str(path))
            self.assertEqual(caught.exception.category, "RECOVERY_REQUIRES_FULL_VALIDATION")


if __name__ == "__main__":
    unittest.main()
