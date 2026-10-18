"""T-004 initial CLI contract Red tests; local subprocesses, no cloud transports.

Positive routing awaits a reviewed root/owner-input contract. These tests only
assert already specified malformed-input and unavailable-operation boundaries.
"""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "plugins/sdd-azure-cloud/scripts/cloud.py"


def load_contracts():
    path = ROOT / "plugins/sdd-quality-loop/scripts/cloud_contracts.py"
    spec = importlib.util.spec_from_file_location("cloud_contracts", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def reference(path: str) -> dict[str, str]:
    return {"path": path, "sha256": hashlib.sha256(b"synthetic").hexdigest()}


def request(operation: str) -> dict:
    return {
        "schema": "cloud-run-request/v1",
        "run_id": "synthetic-run",
        "unit_id": "synthetic-unit",
        "provider": "azure",
        "binding_id": "synthetic-binding",
        "environment": "synthetic",
        "scope": {
            "account_id": "synthetic-subscription",
            "region": "synthetic-region",
            "deployment_scope": "synthetic-group",
        },
        "owner": "bicep",
        "route": "azure-bicep",
        "operation": operation,
        "predecessor_receipts": [],
        "source_revision": "a" * 40,
        "input_artifacts": [{"kind": "source", **reference("main.bicep")}],
        "dependency_lock": reference("lock.json"),
        "policy": reference("policy.json"),
        "verification_profile": {
            "id": "synthetic-profile", "version": "1", **reference("profile.json")
        },
    }


class AzureCliContract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cloud-T004-routing-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()  # physical root on macOS too
        self.contracts = load_contracts()

    def invoke(self, operation, data, extra=(), output=None):
        source = self.root / "request.json"
        source.write_bytes(data)
        destination = output or self.root / "result.json"
        # Deliberately do not inherit cloud credentials or host identity.
        env = {"PATH": os.defpath, "HOME": str(self.root), "PYTHONDONTWRITEBYTECODE": "1"}
        result = subprocess.run(
            [sys.executable, "-B", str(CLI), operation, "--request", str(source),
             "--output", str(destination), *extra],
            cwd=self.root, env=env, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode, 2, result.stderr.decode(errors="replace"))
        self.assertTrue(result.stdout.strip(), "CLI must emit a typed JSON envelope, not merely exit 2")
        value = self.contracts.parse_artifact(result.stdout)
        self.assertEqual(source.read_bytes(), data)
        return value

    def test_local_operations_reject_malformed_json_with_identity_free_envelope(self):
        for operation in ("route", "plan", "validate"):
            for data in (b"{", b"[]", b'{"run_id":"x","run_id":"y"}', b'{"x":NaN}'):
                with self.subTest(operation=operation, data=data):
                    value = self.invoke(operation, data)
                    self.assertEqual(value["schema"], "cloud-input-error/v1")
                    self.assertEqual(set(value), {"schema", "error_code", "message", "field"})
                    self.assertFalse((self.root / "result.json").exists())

    def test_governed_operations_are_typed_blocked_not_fake_success(self):
        for operation in ("prepare", "apply", "reconcile", "observe", "verify"):
            with self.subTest(operation=operation):
                data = json.dumps(request(operation)).encode()
                self.contracts.parse_artifact(data, "cloud-run-request/v1")
                value = self.invoke(operation, data)
                self.assertEqual(value["schema"], "cloud-operation-result/v1")
                for key in ("run_id", "unit_id", "provider", "operation"):
                    self.assertEqual(value[key], request(operation)[key])
                self.assertEqual((value["result"], value["state"]), ("BLOCKED", "BLOCKED"))
                self.assertNotIn("native_operation_id", value)

    def test_unknown_operation_and_flag_are_typed_rejections(self):
        for operation, extra in (("deploy", ()), ("route", ("--approve",))):
            with self.subTest(operation=operation):
                value = self.invoke(operation, b"{}", extra)
                self.assertEqual(value["schema"], "cloud-input-error/v1")
                self.assertFalse((self.root / "result.json").exists())

    def test_input_output_alias_is_not_overwritten(self):
        value = self.invoke("route", b"{", output=self.root / "request.json")
        self.assertEqual(value["schema"], "cloud-input-error/v1")


if __name__ == "__main__":
    unittest.main(verbosity=2)
