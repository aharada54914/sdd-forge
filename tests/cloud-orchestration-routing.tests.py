"""T-004 local real CLI subprocesses. Synthetic scope is never live authority."""

import copy
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


class AzureRouting(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cloud-T004-local-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.contracts = load_contracts()
        self.req = request("apply")
        self.req["scope"] = dict(account_id="11111111-1111-1111-1111-111111111111",
                                 region="eastus", deployment_scope="synthetic-group")
        self.evidence = "specs/cloud-orchestration/verification/T-004/cloud/synthetic-run/synthetic-unit"
        (self.root / self.evidence).mkdir(parents=True)
        self.source = self.put("bundle/unit/main.bicep", b"targetScope = 'resourceGroup'\n")
        self.req["input_artifacts"] = [dict(kind="source", **self.source)]
        self.owner = dict(schema="cloud-ownership/v1",
            owners=[dict(owner="bicep", root="bundle/unit")], existing_resources=[])
        self.policy = dict(schema="cloud-deployment-policy/v1", allowed_scopes=[self.req["scope"]],
            allowed_resource_types=["Microsoft.Compute/virtualMachines"], backup_required=True,
            private_networking=True, budget=dict(ceiling_minor_units=10000, currency="USD"),
            evidence=dict(residency="synthetic-local", retention_days=7, access="restricted"))
        self.profile = dict(schema="cloud-verification-profile/v1", id="synthetic-profile", version="1",
            required_check_ids=["resource", "network", "identity", "monitoring", "workload", "backup"],
            max_age_seconds=300)
        self.config = dict(schema="azure-local-config/v1", import_resources=False)
        file = self.put("bundle/upstream/reference.md", b"Synthetic routing integrity input.\n")
        self.lock = dict(schema="cloud-dependency-lock/v1", adapter_version="1.0.0",
            upstream=[dict(repository="https://example.invalid/synthetic", commit="a" * 40,
                           root="bundle/upstream", files=[dict(**file, references=[])])],
            tools=[dict(name="bicep", version="0.48.1", sha256="a" * 64)], managed_endpoints=[])
        self.req["local_context"] = dict(workspace_anchor="CLOUD_WORKSPACE_ROOT", artifact_root="bundle",
            unit_roots=["bundle/unit"], evidence_directory=self.evidence,
            feature="cloud-orchestration", task_id="T-004")
        self.refresh()

    def put(self, path, value):
        data = value if isinstance(value, bytes) else (json.dumps(value, sort_keys=True) + "\n").encode()
        dest = self.root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return dict(path=path, sha256=hashlib.sha256(data).hexdigest())

    def refresh(self):
        self.req["dependency_lock"] = self.put("bundle/lock.json", self.lock)
        self.req["policy"] = self.put("bundle/policy.json", self.policy)
        self.req["verification_profile"] = dict(id=self.profile["id"], version=self.profile["version"],
            **self.put("bundle/profile.json", self.profile))
        self.req["local_context"]["ownership"] = self.put("bundle/ownership.json", self.owner)
        self.req["local_context"]["provider_config"] = self.put("bundle/config.json", self.config)

    def invoke(self, phase="route", expected=0, output=None, env_extra=None):
        self.put("request.json", self.req)
        env = {"PATH": os.defpath, "HOME": str(self.root), "PYTHONDONTWRITEBYTECODE": "1",
               "CLOUD_WORKSPACE_ROOT": str(self.root)}
        env.update(env_extra or {})
        output = output or self.evidence + "/" + phase + ".json"
        proc = subprocess.run([sys.executable, "-B", str(CLI), phase, "--request", "request.json",
            "--output", output], cwd=self.root, env=env, capture_output=True, timeout=90)
        self.assertEqual(proc.returncode, expected, proc.stderr.decode(errors="replace"))
        self.assertTrue(proc.stdout.strip(), "Missing genuine typed CLI result")
        result = self.contracts.parse_artifact(proc.stdout)
        self.assertEqual(result["operation"], phase)
        self.assertEqual(result["run_id"], self.req["run_id"])
        self.assertNotIn("native_operation_id", result)
        return result

    def test_one_explicit_bicep_owner_routes_with_stable_apply_intent(self):
        result = self.invoke()
        self.assertEqual((result["result"], result["state"]), ("PASS", "ROUTED"))
        self.assertEqual(result["input_manifest_sha256"], hashlib.sha256((self.root/"request.json").read_bytes()).hexdigest())
        manifest = json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        self.assertEqual(manifest["owner"], "bicep")
        self.assertEqual(manifest["route"], "azure-bicep")
        self.assertEqual(manifest["request"]["sha256"], result["input_manifest_sha256"])
        self.assertEqual(manifest["existing_resources"], self.owner["existing_resources"])

    def test_detected_unsupported_owner_cannot_be_hidden_by_inventory(self):
        for name, body in [("main.tf", b""), ("terraform.tfstate", b"{}"),
                           ("azure.yaml", b"name: synthetic"), ("cdk.json", b"{}"),
                           ("sam.yaml", b"Transform: AWS::Serverless-2016-10-31"),
                           ("template.json", b'{"AWSTemplateFormatVersion":"2010-09-09","Resources":{}}')]:
            with self.subTest(name=name):
                ref = self.put("bundle/unit/" + name, body)
                self.assertEqual(self.invoke(expected=2)["error_code"], "OWNER_CONFLICT")
                (self.root/ref["path"]).unlink()

    def test_explicit_unsupported_inventory_and_provider_mismatch(self):
        for owner in ("terraform", "sam", "cloudformation", "azd", "cdk"):
            with self.subTest(owner=owner):
                self.owner["owners"][0]["owner"] = owner
                self.refresh()
                self.assertEqual(self.invoke(expected=2)["result"], "BLOCKED")
        self.owner["owners"][0]["owner"] = "bicep"
        self.refresh()
        self.req.update(provider="aws", owner="cdk", route="aws-cdk")
        self.assertEqual(self.invoke(expected=2)["error_code"], "PROVIDER_MISMATCH")

    def test_missing_owner_import_and_metadata_id_preservation(self):
        self.owner["owners"] = []
        self.refresh()
        self.assertEqual(self.invoke(expected=2)["error_code"], "OWNER_SELECTION_REQUIRED")
        self.owner["owners"] = [dict(owner="bicep", root="bundle/unit")]
        self.config["import_resources"] = True
        self.refresh()
        self.assertEqual(self.invoke(expected=2)["error_code"], "IMPORT_UNSUPPORTED")
        self.config["import_resources"] = False
        self.owner["existing_resources"] = [dict(resource_id="synthetic-preserved-id", owner="terraform", attachments=[])]
        self.refresh()
        result = self.invoke()
        evidence = json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        self.assertEqual(evidence["existing_resources"], self.owner["existing_resources"])

    def test_shared_policy_profile_and_root_mismatches(self):
        cases = [("scope", lambda: self.policy["allowed_scopes"][0].update(region="other")),
                 ("backup", lambda: self.profile["required_check_ids"].remove("backup")),
                 ("budget", lambda: self.policy["budget"].update(ceiling_minor_units=0)),
                 ("evidence", lambda: self.policy["evidence"].update(access="public")),
                 ("owner-root", lambda: self.owner["owners"][0].update(root="outside"))]
        initial = copy.deepcopy((self.policy, self.profile, self.owner))
        for name, mutate in cases:
            with self.subTest(name=name):
                self.policy, self.profile, self.owner = copy.deepcopy(initial)
                mutate(); self.refresh()
                self.assertEqual(self.invoke(expected=2)["result"], "BLOCKED")

    def test_mutated_input_output_escape_alias_and_no_overwrite(self):
        (self.root/self.source["path"]).write_bytes(b"changed")
        self.assertEqual(self.invoke(expected=2)["error_code"], "DIGEST_MISMATCH")
        self.source = self.put(self.source["path"], b"targetScope = 'resourceGroup'\n")
        self.req["input_artifacts"] = [dict(kind="source", **self.source)]
        for output in ("outside.json", "request.json", self.evidence + "/../escape.json"):
            with self.subTest(output=output):
                self.assertEqual(self.invoke(expected=2, output=output)["result"], "BLOCKED")
        self.invoke()
        old = (self.root/self.evidence/"route.json").read_bytes()
        self.assertEqual(self.invoke(expected=2)["result"], "BLOCKED")
        self.assertEqual((self.root/self.evidence/"route.json").read_bytes(), old)

    def test_symlink_root_input_and_output_fail_closed(self):
        link = self.root/"alias"
        link.symlink_to(self.root, target_is_directory=True)
        self.assertEqual(self.invoke(expected=2, env_extra={"CLOUD_WORKSPACE_ROOT": str(link)})["result"], "BLOCKED")
        (self.root/"bundle/unit/link.bicep").symlink_to(self.root/self.source["path"])
        self.assertEqual(self.invoke(expected=2)["result"], "BLOCKED")

    def test_governed_phases_use_phase_not_stable_request_intent(self):
        for phase in ("prepare", "apply", "reconcile", "observe", "verify"):
            with self.subTest(phase=phase):
                result = self.invoke(phase, expected=2)
                self.assertEqual(result["error_code"], "OPERATION_UNIMPLEMENTED")
                self.assertIsNone(result["evidence_manifest_path"])



if __name__ == "__main__":
    unittest.main(verbosity=2)
