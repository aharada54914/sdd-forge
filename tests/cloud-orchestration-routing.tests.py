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
            [sys.executable, "-B", str(getattr(self, "cli", CLI)), operation, "--request", str(source),
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


class LocalRoutingFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cloud-T004-local-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.contracts = load_contracts()
        spec = importlib.util.spec_from_file_location("azure_schema_oracle",
            ROOT / "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py")
        assert spec and spec.loader
        self.oracle = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.oracle)
        self.req = request("apply")
        self.req["scope"] = dict(account_id="11111111-1111-1111-1111-111111111111",
                                 region="eastus", deployment_scope="synthetic-group")
        self.evidence = "specs/cloud-orchestration/verification/T-004/cloud/synthetic-run/synthetic-unit"
        (self.root / self.evidence).mkdir(parents=True)
        self.source = self.put("bundle/unit/main.bicep", b"targetScope = 'resourceGroup'\n")
        self.req["input_artifacts"] = [dict(kind="source", **self.source)]
        self.owner: dict = dict(schema="cloud-ownership/v1",
            owners=[dict(owner="bicep", root="bundle/unit")], existing_resources=[])
        self.policy: dict = dict(schema="cloud-deployment-policy/v1", allowed_scopes=[self.req["scope"]],
            allowed_resource_types=["Microsoft.Compute/virtualMachines"], backup_required=True,
            private_networking=True, budget=dict(ceiling_minor_units=10000, currency="USD"),
            evidence=dict(residency="synthetic-local", retention_days=7, access="restricted"))
        self.profile: dict = dict(schema="cloud-verification-profile/v1", id="synthetic-profile", version="1",
            required_check_ids=["resource", "network", "identity", "monitoring", "workload", "backup"],
            max_age_seconds=300)
        self.config: dict = dict(schema="azure-local-config/v1", import_resources=False)
        file = self.put("bundle/upstream/reference.md", b"Synthetic routing integrity input.\n")
        self.lock: dict = dict(schema="cloud-dependency-lock/v1", adapter_version="1.0.0",
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
        proc = subprocess.run([sys.executable, "-B", str(getattr(self, "cli", CLI)), phase, "--request", str(self.root / "request.json"),
            "--output", output], cwd=self.root, env=env, capture_output=True, timeout=90)
        self.assertEqual(proc.returncode, expected, proc.stderr.decode(errors="replace"))
        self.assertTrue(proc.stdout.strip(), "Missing genuine typed CLI result")
        result = self.contracts.parse_artifact(proc.stdout)
        self.assertEqual(result["operation"], phase)
        self.assertEqual(result["run_id"], self.req["run_id"])
        self.assertNotIn("native_operation_id", result)
        if result.get("evidence_manifest_path"):
            manifest = json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
            schema = json.loads((ROOT/("plugins/sdd-" + self.req["provider"] + "-cloud/references/" + self.req["provider"] + "-local-evidence.schema.json")).read_bytes())
            self.assertEqual(self.oracle._schema_validate(schema, manifest), [])
        return result


class AzureRouting(LocalRoutingFixture):
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
                           ("raw.yml", b"Resources: {}"),
                           ("template.json", b'{"AWSTemplateFormatVersion":"2010-09-09","Resources":{}}')]:
            with self.subTest(name=name):
                ref = self.put("bundle/unit/" + name, body)
                self.assertEqual(self.invoke(expected=2)["error_code"], "OWNER_CONFLICT")
                (self.root/ref["path"]).unlink()

    def test_encoded_cloudformation_keys_and_ambiguous_yaml_block_owner_route(self):
        escaped = b'{"' + bytes([92]) + b'u0052esources":{"Bucket":{"Type":"AWS::S3::Bucket"}}}'
        for name, body in (("escaped.json", escaped), ("escaped.yml", escaped),
                           ("quoted.yaml", b'"' + bytes([92]) + b'u0052esources": {}')):
            with self.subTest(name=name):
                ref = self.put("bundle/unit/" + name, body)
                try:
                    result = self.invoke(expected=2)
                    self.assertEqual(result["result"], "BLOCKED")
                    self.assertIn(result["error_code"], ("OWNER_CONFLICT", "OWNER_UNRESOLVED"))
                finally:
                    (self.root / ref["path"]).unlink()
                    for artifact in (self.root / self.evidence).iterdir():
                        if artifact.is_file():
                            artifact.unlink()
        self.put("bundle/unit/settings.json", {"description": "Resources", "enabled": True})
        self.assertEqual(self.invoke()["state"], "ROUTED")

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


    def test_unsupported_only_unit_is_not_migrated(self):
        (self.root/self.source["path"]).unlink()
        self.source = self.put("bundle/unit/main.tf", b"# Existing Terraform owner, not imported.\n")
        self.req["input_artifacts"] = [dict(kind="source", **self.source)]
        self.req.update(operation="route", owner="terraform", route=None)
        self.owner["owners"][0]["owner"] = "terraform"
        self.refresh()
        before = (self.root/self.source["path"]).read_bytes()
        self.assertEqual(self.invoke(expected=2)["error_code"], "OWNER_UNSUPPORTED")
        self.assertEqual((self.root/self.source["path"]).read_bytes(), before)

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
                mutate()
                self.refresh()
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
                self.assertEqual(result["error_code"], "TRUSTED_COLLECTOR_REQUIRED" if phase in ("observe", "verify") else "OPERATION_UNIMPLEMENTED")
                self.assertIsNone(result["evidence_manifest_path"])


    def test_missing_installed_runtime_and_unknown_config_are_typed_denials(self):
        self.put("request.json", self.req)
        proc = subprocess.run([sys.executable, "-B", str(getattr(self, "cli", CLI)), "route", "--request", str(self.root/"request.json"),
            "--output", str(self.root/self.evidence/"missing.json")],
            env={"PATH": os.defpath, "CLOUD_SHARED_RUNTIME_ROOT": str(self.root/"missing")}, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(self.contracts.parse_artifact(proc.stdout)["error_code"], "SHARED_RUNTIME_UNAVAILABLE")
        self.config["unknown"] = True
        self.refresh()
        self.assertEqual(self.invoke(expected=2)["result"], "BLOCKED")


    def test_explicit_installed_shared_runtime_and_output_link_boundary(self):
        runtime = self.root/"trusted-shared"
        runtime.mkdir()
        (runtime/"cloud_contracts.py").write_bytes((ROOT/"plugins/sdd-quality-loop/scripts/cloud_contracts.py").read_bytes())
        self.assertEqual(self.invoke(env_extra={"CLOUD_SHARED_RUNTIME_ROOT": str(runtime)})["state"], "ROUTED")
        outside = self.root/"outside"
        outside.mkdir()
        (self.root/self.evidence/"link").symlink_to(outside, target_is_directory=True)
        self.assertEqual(self.invoke(expected=2, output=self.evidence+"/link/escape.json")["result"], "BLOCKED")
        self.assertFalse(list(outside.iterdir()))

    def test_secret_marker_publication_is_denied(self):
        self.owner["existing_resources"] = [dict(resource_id="synthetic-" + "secret" + "-canary", owner="terraform", attachments=[])]
        self.refresh()
        self.assertEqual(self.invoke(expected=2)["error_code"], "SECRET_SCAN_FAILED")
        self.assertFalse(list((self.root/self.evidence).iterdir()))


class AzureNativePreparation(AzureRouting):
    """Actual compiler when explicitly installed; no compiler or provider mocks."""
    def setUp(self):
        super().setUp()
        self.binary = Path(os.environ.get("CLOUD_BICEP_BIN", "/workspace/.tools/cloud/bicep/0.48.1/bicep"))
        preserved = ROOT / "specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream"
        self.upstream = Path(os.environ.get("CLOUD_AZURE_UPSTREAM_ROOT", str(preserved)))
        self.env = {"CLOUD_BICEP_BIN": str(self.binary)}
        prefix = "/subscriptions/" + self.req["scope"]["account_id"] + "/resourceGroups/synthetic-group/providers/"
        self.params = dict(vmName="synthetic-vm", location="eastus", vmSize="Standard_D2s_v5",
            imageId=prefix + "Microsoft.Compute/galleries/synthetic/images/linux/versions/1.0.0",
            adminUsername="syntheticadmin", adminPublicKey="ssh-ed25519 " + "A" * 68,
            subnetId=prefix + "Microsoft.Network/virtualNetworks/synthetic/subnets/private",
            identityId=prefix + "Microsoft.ManagedIdentity/userAssignedIdentities/synthetic",
            dataCollectionRuleId=prefix + "Microsoft.Insights/dataCollectionRules/synthetic",
            vaultName="synthetic-vault", backupPolicyId=prefix + "Microsoft.RecoveryServices/vaults/synthetic-vault/backupPolicies/synthetic")
        self.config = dict(schema="azure-local-config/v1", entrypoint="bundle/unit/main.bicep",
            parameters="bundle/unit/parameters.json", upstream_root="bundle/upstream", output_directory="bundle/generated",
            import_resources=False,
            network=dict(subnet_id=self.params["subnetId"], private_management=True, inbound_internet=False),
            identity=dict(resource_id=self.params["identityId"]),
            monitoring=dict(data_collection_rule_id=self.params["dataCollectionRuleId"]),
            backup=dict(policy_id=self.params["backupPolicyId"]),
            cost=dict(estimated_minor_units=100, currency="USD", duration_hours=1),
            evidence=copy.deepcopy(self.policy["evidence"]))
        self.policy["allowed_resource_types"] = ["Microsoft.Network/networkInterfaces",
            "Microsoft.Compute/virtualMachines", "Microsoft.Compute/virtualMachines/extensions",
            "Microsoft.Insights/dataCollectionRuleAssociations",
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems"]
        self.owner["existing_resources"] = [
            dict(resource_id=self.params[key], owner="terraform", attachments=[dict(resource_type=typ, name=name)])
            for key, typ, name in [
                ("subnetId", "Microsoft.Network/networkInterfaces", "synthetic-vm-nic"),
                ("identityId", "Microsoft.Compute/virtualMachines", "synthetic-vm"),
                ("dataCollectionRuleId", "Microsoft.Insights/dataCollectionRuleAssociations", "synthetic-vm-monitor"),
                ("backupPolicyId", "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems", "synthetic-vm")]]
        example = ROOT/"plugins/sdd-azure-cloud/examples/private-vm.bicep"
        if example.exists():
            self.source = self.put("bundle/unit/main.bicep", example.read_bytes())
        self.write_parameters()
        pins = ROOT/"plugins/sdd-azure-cloud/references/upstream-lock.json"
        if pins.exists() and self.upstream.is_dir():
            pin = json.loads(pins.read_bytes())
            files = []
            for f in pin["files"]:
                files.append(dict(**self.put("bundle/upstream/" + f["path"], (self.upstream/f["path"]).read_bytes()),
                    references=["bundle/upstream/" + p for p in f["references"]]))
            self.lock.update(upstream=[dict(repository=pin["repository"], commit=pin["commit"], root="bundle/upstream", files=files)],
                tools=[dict(name="bicep", version="0.48.1", sha256="b09ec25a9d376c1f8e33ede6ed22b587f915ad68488d5db77a6f9541748c7f6e")])
        (self.root/"bundle/generated").mkdir()
        self.refresh()

    def write_parameters(self):
        parameters = self.put("bundle/unit/parameters.json", {
            "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
            "contentVersion": "1.0.0.0", "parameters": {k: {"value": v} for k, v in self.params.items()}})
        self.req["input_artifacts"] = [dict(kind="source", **self.source), dict(kind="parameters", **parameters)]

    def invoke(self, phase="route", expected=0, output=None, env_extra=None):
        return super().invoke(phase, expected, output, {**self.env, **(env_extra or {})})

    def native_prerequisites(self):
        if not self.binary.is_file() or not self.upstream.is_dir():
            self.skipTest("Native pinned Bicep/upstream unavailable; native local compile NOT validated")

    def test_real_compile_locked_plan_and_validate_exact_bytes(self):
        self.native_prerequisites()
        result = self.invoke("plan")
        self.assertEqual(result["state"], "PLANNED")
        evidence = json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        self.assertEqual(evidence["compiler"]["version"], "0.48.1")
        self.assertEqual(evidence["compiler"]["exit_code"], 0)
        self.assertFalse(evidence["cloud_validated"])
        locked = evidence["locked_request"]
        data = self.contracts.read_verified(self.root, locked)
        self.req = self.contracts.parse_artifact(data)
        self.assertEqual(self.req["operation"], "apply")
        compiled = [a for a in self.req["input_artifacts"] if a["kind"] == "compiled"]
        self.assertEqual(len(compiled), 1)
        arm = json.loads(self.contracts.read_verified(self.root, {k: compiled[0][k] for k in ("path", "sha256")}))
        self.assertNotIn("Microsoft.Network/publicIPAddresses", json.dumps(arm))
        self.assertNotIn("securityRules", json.dumps(arm))
        self.assertEqual(self.invoke("validate")["state"], "LOCAL_VALIDATED")
        (self.root/compiled[0]["path"]).write_bytes(b"{}")
        self.assertEqual(self.invoke("validate", expected=2, output=self.evidence+"/tamper.json")["error_code"], "DIGEST_MISMATCH")

    def test_policy_config_mismatch_matrix_before_compiler(self):
        mutations = [lambda: self.config["network"].update(inbound_internet=True),
            lambda: self.config["network"].update(private_management=False),
            lambda: self.config["identity"].update(resource_id="wrong"),
            lambda: self.config["monitoring"].update(data_collection_rule_id="wrong"),
            lambda: self.config.update(backup=None),
            lambda: self.config["cost"].update(estimated_minor_units=10001),
            lambda: self.config["cost"].update(currency="EUR"),
            lambda: self.config["evidence"].update(retention_days=8),
            lambda: self.config.update(unrecognized=True),
            lambda: self.owner["existing_resources"][0].update(attachments=[]),
            lambda: self.policy.update(allowed_resource_types=["Microsoft.Compute/virtualMachines"]),
            lambda: self.params.update(location="westus"),
            lambda: self.params.update(imageId="latest"),
            lambda: self.params.update(backupPolicyId="wrong")]
        initial = copy.deepcopy((self.config, self.owner, self.policy, self.params))
        for i, mutate in enumerate(mutations):
            with self.subTest(case=i):
                self.config, self.owner, self.policy, self.params = copy.deepcopy(initial)
                mutate()
                self.write_parameters()
                self.refresh()
                result = self.invoke("plan", expected=2)
                self.assertEqual(result["error_code"], "LOCAL_POLICY_DENIED")
                self.assertFalse(list((self.root/"bundle/generated").iterdir()))

    def test_missing_compiler_and_transitive_source_rejected(self):
        self.assertEqual(self.invoke("plan", expected=2, env_extra={"CLOUD_BICEP_BIN": "/missing/bicep"})["error_code"], "BICEP_UNAVAILABLE")
        self.put("bundle/unit/hidden.bicep", b"param hidden string")
        self.assertEqual(self.invoke("plan", expected=2)["error_code"], "UNLOCKED_SOURCE")

    def test_unlocked_and_mutated_upstream_and_tool_pin(self):
        self.native_prerequisites()
        original = copy.deepcopy(self.lock)
        for mutate in (lambda: self.lock["tools"][0].update(sha256="a"*64),
                       lambda: self.lock["upstream"][0].update(commit="a"*40),
                       lambda: self.lock["upstream"][0]["files"].pop()):
            self.lock = copy.deepcopy(original)
            mutate()
            self.refresh()
            self.assertEqual(self.invoke("plan", expected=2)["result"], "BLOCKED")


    def install_independent_module(self):
        # Independently authored resource graph, not a copy or fixture hash of the example.
        module = r"""
param settings object
var name = settings.vmName
resource machine 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: name
  location: settings.location
  tags: { purpose: 'independent-module-case' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${settings.identityId}': {} }
  }
  properties: {
    hardwareProfile: { vmSize: settings.vmSize }
    storageProfile: {
      imageReference: { id: settings.imageId }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        diskSizeGB: 64
        deleteOption: 'Detach'
      }
    }
    osProfile: {
      computerName: name
      adminUsername: settings.adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: { publicKeys: [{ path: '/home/${settings.adminUsername}/.ssh/authorized_keys', keyData: settings.adminPublicKey }] }
      }
    }
    networkProfile: { networkInterfaces: [{ id: connection.id }] }
  }
}
resource connection 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${name}-internal'
  location: settings.location
  properties: {
    enableIPForwarding: false
    enableAcceleratedNetworking: true
    ipConfigurations: [{ name: 'internal', properties: { subnet: { id: settings.subnetId }, privateIPAllocationMethod: 'Dynamic' } }]
  }
}
resource telemetry 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: machine
  name: 'monitorAgent'
  location: settings.location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: false
    enableAutomaticUpgrade: false
    settings: { authentication: { managedIdentity: { 'identifier-name': 'mi_res_id', 'identifier-value': settings.identityId } } }
  }
}
resource monitoring 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  scope: machine
  name: '${name}-signals'
  properties: { dataCollectionRuleId: settings.dataCollectionRuleId }
}
resource protection 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-04-01' = {
  name: '${settings.vaultName}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${name}/vm;iaasvmcontainerv2;${resourceGroup().name};${name}'
  properties: { protectedItemType: 'Microsoft.Compute/virtualMachines', sourceResourceId: machine.id, policyId: settings.backupPolicyId }
}
"""
        module_ref = self.put("bundle/unit/modules/private.bicep", module.encode())
        declarations = "\n".join("param " + k + " string" for k in self.params)
        forwarding = "\n".join("      " + k + ": " + k for k in self.params)
        main = declarations + "\nmodule workload './modules/private.bicep' = {\n  name: 'private-unit'\n  params: {\n    settings: {\n" + forwarding + "\n    }\n  }\n}\n"
        self.source = self.put("bundle/unit/main.bicep", main.encode())
        self.write_parameters()
        self.req["input_artifacts"].append(dict(kind="module", **module_ref))
        self.owner["existing_resources"][0]["attachments"][0]["name"] = "synthetic-vm-internal"
        self.owner["existing_resources"][2]["attachments"][0]["name"] = "synthetic-vm-signals"
        self.policy["allowed_resource_types"].append("Microsoft.Resources/deployments")
        self.refresh()

    def test_independent_module_resource_order_names_and_settings_compile(self):
        self.native_prerequisites()
        self.install_independent_module()
        result = self.invoke("plan")
        manifest = json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        self.assertEqual(len(manifest["source_closure"]), 3)
        self.req = self.contracts.read_artifact(self.root, manifest["locked_request"], "cloud-run-request/v1")
        self.assertEqual(self.invoke("validate")["state"], "LOCAL_VALIDATED")

    def test_compiled_public_ip_ingress_and_existing_resource_mutation(self):
        self.native_prerequisites()
        original = (self.root/self.source["path"]).read_bytes()
        mutations = [(
            "Microsoft.Network/publicIPAddresses", "PUBLIC_NETWORK_DENIED", """
resource publicAddress 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'forbidden-public'
  location: location
  properties: { publicIPAllocationMethod: 'Static' }
  sku: { name: 'Standard' }
}
"""), ("Microsoft.Network/networkSecurityGroups", "PUBLIC_NETWORK_DENIED", """
resource ingress 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'forbidden-ingress'
  location: location
  properties: {
    securityRules: [{ name: 'internet', properties: {
      priority: 100
      access: 'Allow'
      direction: 'Inbound'
      protocol: 'Tcp'
      sourceAddressPrefix: 'Internet'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '22'
    } }]
  }
}
"""), ("Microsoft.Network/virtualNetworks/subnets", "EXISTING_RESOURCE_MUTATION", """
resource network 'Microsoft.Network/virtualNetworks@2024-05-01' existing = { name: 'synthetic' }
resource changed 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: network
  name: 'private'
  properties: { addressPrefix: '10.99.0.0/24' }
}
""")]
        for typ, expected, extra in mutations:
            with self.subTest(resource_type=typ):
                self.source = self.put("bundle/unit/main.bicep", original + extra.encode())
                self.write_parameters()
                self.policy["allowed_resource_types"].append(typ)
                self.refresh()
                result = self.invoke("plan", expected=2)
                self.assertEqual(result["error_code"], expected)
                self.assertFalse(list((self.root/"bundle/generated").iterdir()))



    def test_provider_schema_required_fields_and_types_match_cli(self):
        schema = json.loads((ROOT/"plugins/sdd-azure-cloud/references/azure-local-config.schema.json").read_bytes())
        self.assertEqual(self.oracle._schema_validate(schema, self.config), [])
        original = copy.deepcopy(self.config)
        for key in original:
            for mode in ("missing", "null"):
                with self.subTest(key=key, mode=mode):
                    self.config = copy.deepcopy(original)
                    if mode == "missing":
                        del self.config[key]
                    else:
                        self.config[key] = None
                    self.assertTrue(self.oracle._schema_validate(schema, self.config))
                    self.refresh()
                    self.assertEqual(self.invoke("plan", expected=2)["result"], "BLOCKED")
        self.config = original
        self.refresh()


    def test_compiled_outputs_and_variables_have_no_hidden_runtime_reads(self):
        self.native_prerequisites()
        original = (self.root/self.source["path"]).read_bytes()
        unsafe = [
            "\noutput hidden object = listKeys('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/synthetic-group/providers/Microsoft.Storage/storageAccounts/synthetic', '2023-05-01')\n",
            "\nvar hidden = reference('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/synthetic-group/providers/Microsoft.Storage/storageAccounts/synthetic', '2023-05-01')\noutput expose object = hidden\n"]
        for extra in unsafe:
            self.source = self.put("bundle/unit/main.bicep", original + extra.encode())
            self.write_parameters()
            self.assertEqual(self.invoke("plan", expected=2)["error_code"], "ARM_EXPRESSION_UNSUPPORTED")
            self.assertFalse(list((self.root/"bundle/generated").iterdir()))
        benign = "\noutput machineId string = resourceId('Microsoft.Compute/virtualMachines', vmName)\n"
        self.source = self.put("bundle/unit/main.bicep", original + benign.encode())
        self.write_parameters()
        self.assertEqual(self.invoke("plan")["state"], "PLANNED")

    def test_commented_unlocked_compiler_reads_fail_closed(self):
        # Whitespace/comments must not hide an absolute compiler dependency.
        additions = ["\nmodule /* gap */ other '/outside/main.bicep' = { name: 'no' }\n",
                     "\nvar hidden = loadTextContent(/* gap */ '/etc/hosts')\n"]
        original = (self.root/self.source["path"]).read_bytes()
        for extra in additions:
            self.source = self.put("bundle/unit/main.bicep", original + extra.encode())
            self.write_parameters()
            self.assertEqual(self.invoke("plan", expected=2)["error_code"], "UNLOCKED_SOURCE")


    def test_expression_depth_has_an_explicit_bound(self):
        probe = """import sys
sys.path.insert(0, sys.argv[1])
import cloud
from azure_graph import Expressions
expression = '[' + 'toLower(' * 100 + "parameters('name')" + ')' * 100 + ']'
try:
    Expressions({'name':'synthetic'}, {}, {}).value(expression)
except cloud.c.ContractError as exc:
    print(str(exc))
else:
    raise SystemExit(1)
"""
        proc = subprocess.run([sys.executable, "-B", "-c", probe, str(CLI.parent)],
            env={"PATH": os.defpath}, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 0, proc.stderr.decode())
        self.assertEqual(proc.stdout.strip(), b"ARM_EXPRESSION_LIMIT")

    def test_directory_scan_recursion_is_a_typed_cli_denial(self):
        self.put("request.json", self.req)
        deep = self.root/"bundle/unit"
        for _ in range(180):
            deep = deep/"d"
            deep.mkdir()
        bootstrap = "import sys,runpy; sys.setrecursionlimit(150); sys.argv=sys.argv[1:]; runpy.run_path(sys.argv[0],run_name='__main__')"
        proc = subprocess.run([sys.executable, "-B", "-c", bootstrap, str(getattr(self, "cli", CLI)), "route", "--request", str(self.root/"request.json"),
            "--output", str(self.root/self.evidence/"deep.json")], env={"PATH": os.defpath,
            "CLOUD_WORKSPACE_ROOT": str(self.root)}, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 2, proc.stderr.decode())
        result = self.contracts.parse_artifact(proc.stdout)
        self.assertEqual((result["result"], result["error_code"]), ("BLOCKED", "NESTING_LIMIT"))
        self.assertNotIn(b"Traceback", proc.stderr)

    def test_unsupported_filesystem_subprocess(self):
        self.put("request.json", self.req)
        bootstrap = "import os,runpy,sys; os.supports_dir_fd=set(); sys.argv=sys.argv[1:]; runpy.run_path(sys.argv[0],run_name='__main__')"
        proc = subprocess.run([sys.executable, "-B", "-c", bootstrap, str(getattr(self, "cli", CLI)), "route", "--request", str(self.root/"request.json"),
            "--output", str(self.root/self.evidence/"unsupported.json")],
            env={"PATH": os.defpath, "CLOUD_WORKSPACE_ROOT": str(self.root)}, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(self.contracts.parse_artifact(proc.stdout)["error_code"], "UNSUPPORTED_FILESYSTEM")
        self.assertFalse((self.root/self.evidence/"unsupported.json").exists())




AWS_CLI = ROOT / "plugins/sdd-aws-cloud/scripts/cloud.py"
AWS_PLUGIN = AWS_CLI.parent.parent


class AwsCliContract(AzureCliContract):
    cli = AWS_CLI

    def invoke(self, operation, data, extra=(), output=None):
        try:
            body = json.loads(data)
            if isinstance(body, dict) and body.get("schema") == "cloud-run-request/v1":
                body.update(provider="aws", owner="cdk", route="aws-cdk")
                data = json.dumps(body).encode()
        except (ValueError, UnicodeError):
            pass
        return super().invoke(operation, data, extra, output)

    def test_governed_operations_are_typed_blocked_not_fake_success(self):
        for phase in ("prepare", "apply", "reconcile", "observe", "verify"):
            value = self.invoke(phase, json.dumps(request("apply")).encode())
            self.assertEqual((value["provider"], value["operation"], value["error_code"]),
                             ("aws", phase, "TRUSTED_COLLECTOR_REQUIRED" if phase in ("observe", "verify") else "OPERATION_UNIMPLEMENTED"))
            self.assertNotIn("native_operation_id", value)


class AwsRouting(LocalRoutingFixture):
    cli = AWS_CLI

    def setUp(self):
        super().setUp()
        (self.root/self.source["path"]).unlink()
        self.req.update(provider="aws", owner="cdk", route="aws-cdk")
        self.req["scope"] = dict(account_id="111111111111", region="us-east-1", deployment_scope="SyntheticPrivate")
        self.policy["allowed_scopes"] = [copy.deepcopy(self.req["scope"])]
        self.evidence = "specs/cloud-orchestration/verification/T-005/cloud/synthetic-run/synthetic-unit"
        (self.root/self.evidence).mkdir(parents=True)
        self.req["local_context"].update(task_id="T-005", evidence_directory=self.evidence)
        self.source = self.put("bundle/unit/cdk.json", dict(app="node app.js"))
        self.req["input_artifacts"] = [dict(kind="source", **self.source)]
        self.owner["owners"] = [dict(owner="cdk", root="bundle/unit")]
        self.config = dict(schema="aws-local-config/v1", import_resources=False)
        self.refresh()

    test_shared_policy_profile_and_root_mismatches = AzureRouting.test_shared_policy_profile_and_root_mismatches
    test_symlink_root_input_and_output_fail_closed = AzureRouting.test_symlink_root_input_and_output_fail_closed
    test_governed_phases_use_phase_not_stable_request_intent = AzureRouting.test_governed_phases_use_phase_not_stable_request_intent
    test_missing_installed_runtime_and_unknown_config_are_typed_denials = AzureRouting.test_missing_installed_runtime_and_unknown_config_are_typed_denials
    test_explicit_installed_shared_runtime_and_output_link_boundary = AzureRouting.test_explicit_installed_shared_runtime_and_output_link_boundary
    test_secret_marker_publication_is_denied = AzureRouting.test_secret_marker_publication_is_denied
    test_encoded_cloudformation_keys_and_ambiguous_yaml_block_owner_route = AzureRouting.test_encoded_cloudformation_keys_and_ambiguous_yaml_block_owner_route
    test_directory_scan_recursion_is_a_typed_cli_denial = AzureNativePreparation.test_directory_scan_recursion_is_a_typed_cli_denial
    test_unsupported_filesystem_subprocess = AzureNativePreparation.test_unsupported_filesystem_subprocess

    def test_route_owner_identity_and_stable_intent(self):
        self.owner["existing_resources"] = [dict(resource_id="vpc-11111111", owner="terraform", attachments=[])]
        self.refresh()
        result = self.invoke()
        evidence = json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        self.assertEqual((result["state"], evidence["owner"], evidence["route"]), ("ROUTED", "cdk", "aws-cdk"))
        self.assertEqual(evidence["existing_resources"], self.owner["existing_resources"])
        self.assertEqual(evidence["request"]["sha256"], result["input_manifest_sha256"])
        self.assertEqual(self.req["operation"], "apply")
        self.assertFalse(evidence["cloud_validated"])

    def test_mixed_unsupported_missing_import_and_provider(self):
        for name, body in [("main.tf", b""), ("main.bicep", b""), ("azure.yaml", b"name: x"),
                           ("sam.json", b'{"Transform":"AWS::Serverless-2016-10-31"}'),
                           ("raw.json", b'{"Resources":{}}')]:
            self.put("bundle/unit/"+name, body)
            self.assertEqual(self.invoke(expected=2)["error_code"], "OWNER_CONFLICT")
            (self.root/"bundle/unit"/name).unlink()
        initial = copy.deepcopy((self.owner, self.config, self.req))
        for edit in (lambda: self.owner.update(owners=[]),
                     lambda: self.config.update(import_resources=True),
                     lambda: self.req.update(provider="azure", owner="bicep", route="azure-bicep")):
            edit()
            self.refresh()
            self.assertEqual(self.invoke(expected=2)["result"], "BLOCKED")
            self.owner, self.config, self.req = copy.deepcopy(initial)
        (self.root/self.source["path"]).unlink()
        self.source = self.put("bundle/unit/main.tf", b"# No import")
        self.req["input_artifacts"] = [dict(kind="source", **self.source)]
        self.req.update(owner="terraform", route=None, operation="route")
        self.owner["owners"][0]["owner"] = "terraform"
        self.refresh()
        self.assertEqual(self.invoke(expected=2)["error_code"], "OWNER_UNSUPPORTED")

    def test_output_and_source_integrity(self):
        for output in ("request.json", "other.json", self.evidence+"/../escape.json"):
            self.assertEqual(self.invoke(expected=2, output=output)["result"], "BLOCKED")
        self.invoke()
        before = (self.root/self.evidence/"route.json").read_bytes()
        self.assertEqual(self.invoke(expected=2)["error_code"], "OUTPUT_EXISTS")
        self.assertEqual((self.root/self.evidence/"route.json").read_bytes(), before)
        (self.root/self.source["path"]).write_bytes(b"{}")
        self.assertEqual(self.invoke(expected=2)["error_code"], "DIGEST_MISMATCH")


class AwsNativePreparation(AwsRouting):
    def setUp(self):
        super().setUp()
        self.toolroot = Path(os.environ.get("CLOUD_CDK_ROOT", "/workspace/.tools/cloud/cdk/2.1145.0"))
        self.node = Path(os.environ.get("CLOUD_NODE_BIN", "/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin/node"))
        self.env = {"CLOUD_CDK_ROOT": str(self.toolroot), "CLOUD_NODE_BIN": str(self.node)}
        self.params = dict(account="111111111111", region="us-east-1", stackName="SyntheticPrivate",
            vpcId="vpc-11111111", subnetId="subnet-11111111", instanceProfile="synthetic-profile",
            imageId="ami-11111111111111111", instanceType="t3.small", backupPlanId="synthetic-plan",
            backupRoleArn="arn:aws:iam::111111111111:role/synthetic-backup")
        self.config = dict(schema="aws-local-config/v1", import_resources=False, entrypoint="bundle/unit/app.js",
            parameters="bundle/unit/parameters.json", upstream_root="bundle/upstream", output_directory="bundle/generated",
            private_management=True, cost=dict(estimated_minor_units=100, currency="USD", duration_hours=1),
            evidence=copy.deepcopy(self.policy["evidence"]))
        self.policy["allowed_resource_types"] = ["AWS::EC2::Instance", "AWS::EC2::SecurityGroup", "AWS::CloudWatch::Alarm", "AWS::Backup::BackupSelection"]
        self.owner["existing_resources"] = [dict(resource_id=rid, owner="terraform", attachments=[dict(resource_type=typ,name=name)])
            for rid,typ,name in [(self.params["vpcId"],"AWS::EC2::SecurityGroup","PrivateGroup"),
                (self.params["subnetId"],"AWS::EC2::Instance","Workload"),
                (self.params["instanceProfile"],"AWS::EC2::Instance","Workload"),
                (self.params["backupPlanId"],"AWS::Backup::BackupSelection","Protection"),
                (self.params["backupRoleArn"],"AWS::Backup::BackupSelection","Protection")]]
        self.source_refs = [self.source]
        for name in ("app.js", "package.json", "package-lock.json"):
            path = AWS_PLUGIN/"examples/private-ec2"/name
            if path.exists():
                self.source_refs.append(self.put("bundle/unit/"+name,path.read_bytes()))
        pinpath = AWS_PLUGIN/"references/upstream-lock.json"
        if pinpath.exists():
            pin=json.loads(pinpath.read_bytes())
            files=[dict(**self.put("bundle/upstream/"+f["path"],(AWS_PLUGIN/"references/upstream"/f["path"]).read_bytes()),
                        references=["bundle/upstream/"+p for p in f["references"]]) for f in pin["files"]]
            tools=json.loads((AWS_PLUGIN/"references/toolchain-lock.json").read_bytes())["tools"]
            self.lock.update(upstream=[dict(repository=pin["repository"],commit=pin["commit"],root="bundle/upstream",files=files)],tools=tools)
        (self.root/"bundle/generated").mkdir()
        self.write_parameters()
        self.refresh()

    def write_parameters(self):
        ref=self.put("bundle/unit/parameters.json",self.params)
        self.req["input_artifacts"]=[dict(kind="source",**r) for r in self.source_refs]+[dict(kind="parameters",**ref)]

    def invoke(self, phase="route", expected=0, output=None, env_extra=None):
        return super().invoke(phase,expected,output,{**self.env,**(env_extra or {})})

    def native_prerequisites(self):
        if not (self.toolroot/"node_modules/aws-cdk/bin/cdk").is_file():
            self.skipTest("Pinned CDK unavailable: native synthesis NOT validated")

    def test_real_synth_complete_locked_assembly_validate_without_execution(self):
        self.native_prerequisites()
        original=json.dumps(self.req,sort_keys=True)
        result=self.invoke("plan")
        ev=json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        self.assertEqual(ev["compiler"]["version"],"2.1145.0")
        self.assertEqual(ev["compiler"]["exit_code"],0)
        self.assertEqual(json.dumps(self.req,sort_keys=True),original)
        self.req=self.contracts.read_artifact(self.root,ev["locked_request"],"cloud-run-request/v1")
        self.assertEqual(self.req["operation"],"apply")
        self.assertTrue(any(a["path"].endswith("manifest.json") for a in self.req["input_artifacts"]))
        self.assertTrue(any(a["path"].endswith(".assets.json") for a in self.req["input_artifacts"]))
        # Validation does not execute source or regenerate assembly, even without a tool installation.
        self.assertEqual(self.invoke("validate",env_extra={"CLOUD_CDK_ROOT":"/missing"})["state"],"LOCAL_VALIDATED")
        compiled=next(a for a in self.req["input_artifacts"] if a["path"].endswith(".template.json"))
        (self.root/compiled["path"]).write_bytes(b"{}")
        self.assertEqual(self.invoke("validate",expected=2,output=self.evidence+"/tamper.json")["error_code"],"DIGEST_MISMATCH")

    def test_policy_and_bound_field_mismatch_preflight(self):
        initial=copy.deepcopy((self.config,self.params,self.policy,self.owner,self.lock))
        edits=[lambda:self.config.update(private_management=False),lambda:self.config.update(import_resources=True),
               lambda:self.config["cost"].update(estimated_minor_units=10001),lambda:self.config["evidence"].update(retention_days=9),
               lambda:self.params.update(region="us-west-2"),lambda:self.params.update(imageId="latest"),
               lambda:self.params.update(backupPlanId="wrong"),lambda:self.owner["existing_resources"][0].update(attachments=[]),
               lambda:self.lock["tools"][0].update(version="2.0.0"),lambda:self.lock["upstream"][0].update(commit="b"*40),
               lambda:self.policy.update(allowed_resource_types=["AWS::EC2::Instance"])]
        for i,edit in enumerate(edits):
            with self.subTest(case=i):
                self.config,self.params,self.policy,self.owner,self.lock=copy.deepcopy(initial)
                edit()
                self.write_parameters()
                self.refresh()
                self.assertEqual(self.invoke("plan",expected=2)["result"],"BLOCKED")
                self.assertEqual(list((self.root/"bundle/generated").iterdir()),[])

    def test_ambient_credentials_are_rejected_before_application(self):
        for env in ({"AWS_ACCESS_KEY_ID":"synthetic"},{"AWS_PROFILE":"synthetic"},
                    {"AWS_WEB_IDENTITY_TOKEN_FILE":"/synthetic"},{"ACTIONS_ID_TOKEN_REQUEST_URL":"https://example.invalid"}):
            self.assertEqual(self.invoke("plan",expected=2,env_extra=env)["error_code"],"AMBIENT_CREDENTIALS")
        self.put(".aws/credentials",b"[synthetic]\n")
        self.assertEqual(self.invoke("plan",expected=2)["error_code"],"AMBIENT_CREDENTIALS")

    def test_generated_output_inside_source_and_hidden_owners_block(self):
        self.config["output_directory"]="bundle/unit/generated"
        self.refresh()
        self.assertEqual(self.invoke("plan",expected=2)["error_code"],"LOCAL_POLICY_DENIED")
        self.put("bundle/unit/cdk.out/raw.json",dict(Resources={}))
        self.assertEqual(self.invoke(expected=2)["error_code"],"OWNER_CONFLICT")

    def test_literal_and_composed_markers_are_not_resource_references(self):
        self.native_prerequisites()
        result=self.invoke('plan')
        ev=json.loads((self.root/result['evidence_manifest_path']).read_bytes())
        locked=self.contracts.read_artifact(self.root,ev['locked_request'],'cloud-run-request/v1')
        ref=next(a for a in locked['input_artifacts'] if a['path'].endswith('.template.json'))
        original=json.loads((self.root/ref['path']).read_bytes())
        for kind in ('alarm','backup'):
            marker='@Workload' if kind=='alarm' else 'arn:aws:ec2:us-east-1:111111111111:instance/@Workload'
            forms=[marker,{'Fn::Join':['',[marker[:-4],marker[-4:]]]},
                {'Fn::Sub':['${literal}',{'literal':marker}]},
                {'Fn::Sub':['${left}${right}',{'left':marker[:-4],'right':marker[-4:]}]}]
            for i,value in enumerate(forms):
                with self.subTest(kind=kind,form=i):
                    self.req=copy.deepcopy(locked)
                    body=copy.deepcopy(original)
                    if kind=='alarm':
                        body['Resources']['Health']['Properties']['Dimensions'][0]['Value']=value
                    else:
                        body['Resources']['Protection']['Properties']['BackupSelection']['Resources']=[value]
                    changed=self.put(ref['path'],body)
                    next(a for a in self.req['input_artifacts'] if a['path']==ref['path']).update(changed)
                    self.assertEqual(self.invoke('validate',expected=2,output=self.evidence+f'/spoof-{kind}-{i}.json')['result'],'BLOCKED')

    def test_malformed_compiled_outputs_always_typed_and_no_receipt(self):
        self.native_prerequisites()
        result=self.invoke('plan')
        ev=json.loads((self.root/result['evidence_manifest_path']).read_bytes())
        locked=self.contracts.read_artifact(self.root,ev['locked_request'],'cloud-run-request/v1')
        artifacts={a['path']:(self.root/a['path']).read_bytes() for a in locked['input_artifacts'] if a['kind']=='compiled'}
        manifest=next(p for p in artifacts if p.endswith('/manifest.json'))
        assets=next(p for p in artifacts if p.endswith('.assets.json'))
        template=next(p for p in artifacts if p.endswith('.template.json'))
        cases=[(manifest,{'version':'54.0.0','artifacts':{'bad':None}}),
            (manifest,[]),(assets,{'version':'54.0.0','files':{'bad':None}}),
            (template,{'Resources':{'bad':None}}),(template,{'Resources':{},'Parameters':[]}),
            (template,b'{"Resources":{},"Resources":{}}'),(assets,b'{"version":NaN}')]
        for i,(path,body) in enumerate(cases):
            with self.subTest(case=i):
                for name,data in artifacts.items():
                    (self.root/name).write_bytes(data)
                self.req=copy.deepcopy(locked)
                ref=self.put(path,body)
                next(a for a in self.req['input_artifacts'] if a['path']==path).update(ref)
                result=self.invoke('validate',expected=2,output=self.evidence+f'/malformed-{i}.json')
                self.assertEqual(result['result'],'BLOCKED')
                self.assertIsNone(result['evidence_manifest_path'])

    def test_fixed_tool_and_upstream_schema_lock_mismatch(self):
        initial=copy.deepcopy(self.lock)
        for mode in ('tool-hash','schema','upstream-file','adapter'):
            self.lock=copy.deepcopy(initial)
            if mode=='tool-hash':
                self.lock['tools'][0]['sha256']='a'*64
            elif mode=='adapter':
                self.lock['adapter_version']='99.0.0'
            elif mode=='upstream-file':
                self.lock['upstream'][0]['files'].pop()
            else:
                ref=self.put('bundle/schema.json',{'type':'changed-schema'})
                self.lock['managed_endpoints']=[dict(endpoint='https://example.invalid',tool_schema=ref)]
            self.refresh()
            self.assertEqual(self.invoke('plan',expected=2)['result'],'BLOCKED')
            self.assertFalse(list((self.root/'bundle/generated').iterdir()))

    def test_replanning_is_immutable_and_non_json_asset_is_typed_unsupported(self):
        self.native_prerequisites()
        result=self.invoke('plan')
        ev=json.loads((self.root/result['evidence_manifest_path']).read_bytes())
        initial={a['path']:(self.root/a['path']).read_bytes() for a in ev['assembly']}
        self.assertEqual(self.invoke('plan',expected=2,output=self.evidence+'/repeat.json')['error_code'],'PLAN_EXISTS')
        self.assertEqual({p:(self.root/p).read_bytes() for p in initial},initial)
        # Add a real file asset; current adapter deliberately supports template-only publication.
        ref=self.put('bundle/unit/file.txt',b'harmless local asset')
        self.source_refs.append(ref)
        original=(self.root/'bundle/unit/app.js').read_text()
        self.replace_app(original.replace('app.synth();', "new cdk.aws_s3_assets.Asset(stack,'File',{path:require('path').join(__dirname,'file.txt')}); app.synth();"))
        self.assertEqual(self.invoke('plan',expected=2,output=self.evidence+'/asset.json')['error_code'],'ASSET_TYPE_UNSUPPORTED')
        self.assertEqual(len(list((self.root/'bundle/generated').iterdir())),2)

    def replace_app(self, body):
        ref=self.put("bundle/unit/app.js",body.encode())
        self.source_refs=[ref if r["path"]==ref["path"] else r for r in self.source_refs]
        self.write_parameters()
        self.refresh()

    def test_independently_authored_private_graph(self):
        self.native_prerequisites()
        self.replace_app(r"""
const { App, Stack, CfnResource, CfnParameter, Fn, Validations, DefaultStackSynthesizer } = require('aws-cdk-lib');
const settings = require('./parameters.json');
const application = new App();
const unit = new Stack(application, 'Independent', { env: {region:settings.region,account:settings.account},
  stackName:settings.stackName, synthesizer:new DefaultStackSynthesizer({generateBootstrapVersionRule:false}) });
const image = new CfnParameter(unit,'SelectedImage',{type:'AWS::EC2::Image::Id',default:settings.imageId});
const policy = new CfnResource(unit, 'EndpointAccess', {type:'AWS::EC2::SecurityGroup',properties:{
  VpcId:settings.vpcId, GroupDescription:'Independent private endpoint access',
  SecurityGroupEgress:[{CidrIp:'172.16.4.0/24',IpProtocol:'tcp',FromPort:443,ToPort:443}] }});
const vm = new CfnResource(unit,'Compute',{type:'AWS::EC2::Instance',properties:{
  InstanceType:settings.instanceType, ImageId:image.valueAsString, IamInstanceProfile:settings.instanceProfile,
  NetworkInterfaces:[{SubnetId:settings.subnetId, DeviceIndex:'0', AssociatePublicIpAddress:false,
    GroupSet:[policy.getAtt('GroupId')],DeleteOnTermination:true}],
  Monitoring:true, MetadataOptions:{HttpTokens:'required',HttpEndpoint:'enabled'},
  Tags:[{Key:'purpose',Value:'independent-positive'}],
  BlockDeviceMappings:[{DeviceName:'/dev/sda1',Ebs:{VolumeSize:32,VolumeType:'gp2',Encrypted:true,DeleteOnTermination:false}}]
}});
Validations.of(vm).acknowledge({id:'CloudFormation-Validate::W9010',reason:'Explicit immutable image input, not a mutable lookup.'});
new CfnResource(unit,'Retention',{type:'AWS::Backup::BackupSelection',properties:{BackupPlanId:settings.backupPlanId,
  BackupSelection:{SelectionName:'independent-retention',IamRoleArn:settings.backupRoleArn,
    Resources:[Fn.sub('arn:aws:ec2:${AWS::Region}:${AWS::AccountId}:instance/${Compute}')]}}});
new CfnResource(unit,'StatusAlarm',{type:'AWS::CloudWatch::Alarm',properties:{
  Dimensions:[{Name:'InstanceId',Value:vm.ref}], TreatMissingData:'breaching',
  ComparisonOperator:'GreaterThanThreshold', Threshold:0, EvaluationPeriods:3, Period:120,
  Statistic:'Maximum', MetricName:'StatusCheckFailed',Namespace:'AWS/EC2'}});
application.synth();
""")
        for row in self.owner["existing_resources"]:
            for a in row["attachments"]:
                a["name"]={"PrivateGroup":"EndpointAccess","Workload":"Compute","Protection":"Retention"}[a["name"]]
        self.refresh()
        result=self.invoke("plan")
        ev=json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        self.req=self.contracts.read_artifact(self.root,ev["locked_request"],"cloud-run-request/v1")
        self.assertEqual(self.invoke("validate")["state"],"LOCAL_VALIDATED")

    def test_actual_synth_public_mutation_and_missing_backup_negatives(self):
        self.native_prerequisites()
        original=(self.root/"bundle/unit/app.js").read_text()
        cases=[(original.replace('associatePublicIpAddress: false','associatePublicIpAddress: true'),'PUBLIC_NETWORK_DENIED'),
            (original.replace("cidrIp: '10.0.0.0/16'","cidrIp: '0.0.0.0/0'"),'PUBLIC_NETWORK_DENIED'),
            (original.replace('app.synth();',"new cdk.aws_ec2.CfnSubnet(stack,'ChangedSubnet',{vpcId:p.vpcId,cidrBlock:'10.9.0.0/24'}); app.synth();"),'EXISTING_RESOURCE_MUTATION'),
            (original.replace('app.synth();',"stack.node.tryRemoveChild('Protection'); app.synth();"),'BACKUP_REQUIRED'),
            (original.replace('monitoring: true','monitoring: false'),'LOCAL_POLICY_DENIED')]
        for body,code in cases:
            with self.subTest(code=code):
                self.replace_app(body)
                result=self.invoke("plan",expected=2)
                self.assertEqual(result["error_code"],code)
                self.assertFalse(list((self.root/"bundle/generated").iterdir()))

    def test_native_assembly_schema_assets_and_executable_surface_denials(self):
        self.native_prerequisites()
        result=self.invoke("plan")
        ev=json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
        locked=self.contracts.read_artifact(self.root,ev["locked_request"],"cloud-run-request/v1")
        files={a["path"]:(self.root/a["path"]).read_bytes() for a in locked["input_artifacts"] if a["kind"]=="compiled"}
        manifest=next(p for p in files if p.endswith('/manifest.json'))
        assets=next(p for p in files if p.endswith('.assets.json'))
        template=next(p for p in files if p.endswith('.template.json'))
        cases=[(manifest,lambda b:b.update(version='999.0.0'),'ASSEMBLY_SCHEMA_DRIFT'),
               (assets,lambda b:b.update(version='999.0.0'),'ASSET_SCHEMA_DRIFT'),
               (assets,lambda b:b.update(dockerImages={'synthetic':{}}),'ASSET_TYPE_UNSUPPORTED'),
               (assets,lambda b:next(iter(b['files'].values()))['source'].update(executable=['sh']),'ASSET_TYPE_UNSUPPORTED'),
               (assets,lambda b:next(iter(b['files'].values()))['source'].update(packaging='zip'),'ASSET_TYPE_UNSUPPORTED'),
               (template,lambda b:b.update(Transform='AWS::Serverless-2016-10-31'),'CFN_STRUCTURE_UNSUPPORTED'),
               (template,lambda b:b['Resources']['Workload']['Properties'].update(UserData={'Fn::Base64':'untrusted'}),'CFN_EXPRESSION_UNSUPPORTED'),
               (template,lambda b:b.update(Outputs={'Bad':{'Value':{'Fn::ImportValue':'external'}}}),'CFN_EXPRESSION_UNSUPPORTED')]
        for i,(path,mutate,code) in enumerate(cases):
            with self.subTest(code=code):
                for name,data in files.items():
                    (self.root/name).write_bytes(data)
                self.req=copy.deepcopy(locked)
                body=json.loads(files[path])
                mutate(body)
                ref=self.put(path,body)
                next(a for a in self.req['input_artifacts'] if a['path']==path).update(ref)
                self.assertEqual(self.invoke('validate',expected=2,output=self.evidence+f'/negative-{i}.json')['error_code'],code)

    def test_config_schema_required_and_unknown_fields(self):
        schema=json.loads((AWS_PLUGIN/'references/aws-local-config.schema.json').read_bytes())
        self.assertEqual(self.oracle._schema_validate(schema,self.config),[])
        original=copy.deepcopy(self.config)
        for key in original:
            self.config=copy.deepcopy(original)
            del self.config[key]
            self.assertTrue(self.oracle._schema_validate(schema,self.config))
            self.refresh()
            self.assertEqual(self.invoke('plan',expected=2)['result'],'BLOCKED')

    def test_expression_depth_and_noncanonical_native_windows_root(self):
        probe="""import sys
sys.path.insert(0,sys.argv[1])
import cloud
from aws_graph import Expressions
value='x'
for _ in range(100): value={'Fn::Join':['',[value]]}
try: Expressions({},{}).value(value)
except cloud.c.ContractError as exc: print(str(exc))
else: raise SystemExit(1)
"""
        proc=subprocess.run([sys.executable,'-B','-c',probe,str(AWS_CLI.parent)],env={'PATH':os.defpath},capture_output=True,timeout=15)
        self.assertEqual(proc.returncode,0)
        self.assertEqual(proc.stdout.strip(),b'CFN_EXPRESSION_LIMIT')
        self.assertEqual(self.invoke(expected=2,env_extra={'CLOUD_WORKSPACE_ROOT':'C:'+chr(92)+'workspace'})['result'],'BLOCKED')

    def test_explicit_node_location_and_bytes(self):
        self.native_prerequisites()
        self.assertEqual(self.invoke("plan",expected=2,env_extra={"CLOUD_NODE_BIN":""})["error_code"],"NODE_UNAVAILABLE")
        alternate=self.root/"trusted-node"
        alternate.write_bytes(self.node.read_bytes())
        alternate.chmod(0o700)
        self.assertEqual(self.invoke("plan",env_extra={"CLOUD_NODE_BIN":str(alternate)})["state"],"PLANNED")
        alternate.write_bytes(b"#!/bin/sh\nexit 0\n")
        self.assertEqual(self.invoke("plan",expected=2,env_extra={"CLOUD_NODE_BIN":str(alternate)},output=self.evidence+"/wrong-node.json")["error_code"],"NODE_RUNTIME_DRIFT")

    def test_installed_runtime_mutation_denied(self):
        self.native_prerequisites()
        import shutil
        clone=self.root/"toolchain"
        shutil.copytree(self.toolroot,clone,symlinks=True)
        target=clone/"node_modules/aws-cdk/bin/cdk"
        target.write_bytes(target.read_bytes()+b"\n// altered runtime\n")
        self.assertEqual(self.invoke("plan",expected=2,env_extra={"CLOUD_CDK_ROOT":str(clone)})["error_code"],"CDK_RUNTIME_DRIFT")
        self.assertEqual(list((self.root/"bundle/generated").iterdir()),[])

    def test_unsupported_executable_config_and_unlocked_sources(self):
        self.put("bundle/unit/hidden.js",b"// not locked")
        self.assertEqual(self.invoke("plan",expected=2)["error_code"],"UNLOCKED_SOURCE")


# T-011: real installed subprocess integration, never a native model-host trial.
class BootstrapInstalled(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import shutil
        cls.temp = tempfile.TemporaryDirectory(prefix="cloud-T011-installed-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.install = Path(cls.temp.name).resolve() / "installed"
        source = Path(cls.temp.name).resolve() / "source"
        source.mkdir()
        spec = importlib.util.spec_from_file_location("install_cloud", ROOT / "tests/install-cloud.tests.py")
        assert spec and spec.loader
        packaging = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(packaging)
        packaging.fixture(source)
        if os.name == "nt":
            shell = shutil.which("pwsh")
            if not shell:
                raise AssertionError("Native Windows packaging requires PowerShell")
            command = [shell, "-NoProfile", "-Command",
                       "& '" + str(ROOT / "install.ps1") + "' -InstallRoot '" + str(cls.install)
                       + "' -SourceDirectory '" + str(source)
                       + "' -Target FilesOnly -Plugins 'sdd-bootstrap','sdd-azure-cloud','sdd-aws-cloud'"
                       + " -SkipAgentInstall -SkipMcp"]
        else:
            command = ["bash", str(ROOT / "install.sh"), "--install-root", str(cls.install),
                       "--target", "FilesOnly", "--plugins", "sdd-bootstrap,sdd-azure-cloud,sdd-aws-cloud",
                       "--skip-agent-install", "--skip-mcp", "--source-directory", str(source)]
        result = subprocess.run(command, text=True, capture_output=True, timeout=180)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    def fixture(self, provider):
        case = AwsRouting() if provider == "aws" else LocalRoutingFixture()
        case.setUp()
        self.addCleanup(case.doCleanups)
        return case

    def call(self, case, provider, phase, bootstrap, request_bytes=None, extra=()):
        source = case.root / "request.json"
        raw = request_bytes if request_bytes is not None else json.dumps(case.req).encode()
        source.write_bytes(raw)
        plugin = self.install / "plugins" / ("sdd-" + provider + "-cloud")
        output = case.evidence + "/" + ("bootstrap" if bootstrap else "direct") + ".json"
        command = [sys.executable, "-B"]
        if bootstrap:
            command += [str(self.install / "plugins/sdd-bootstrap/scripts/cloud-routing.py"),
                        "--provider", provider, "--plugin-root", str(plugin)]
        else:
            command += [str(plugin / "scripts/cloud.py")]
        command += [phase, "--request", str(source), "--output", output, *extra]
        env = {"PATH": os.defpath, "HOME": str(case.root), "PYTHONDONTWRITEBYTECODE": "1",
               "CLOUD_WORKSPACE_ROOT": str(case.root),
               "CLOUD_SHARED_RUNTIME_ROOT": str(plugin / "runtime/scripts")}
        result = subprocess.run(command, cwd=case.root, env=env, capture_output=True, timeout=30)
        self.assertEqual(source.read_bytes(), raw, "Canonical request bytes changed")
        self.assertTrue(result.stdout.strip(), result.stderr.decode(errors="replace"))
        value = case.contracts.parse_artifact(result.stdout)
        for artifact in (case.root / case.evidence).iterdir():
            if artifact.is_file():
                artifact.unlink()
        return result.returncode, value

    def test_same_canonical_request_route_and_direct_write_denial(self):
        for provider in ("azure", "aws"):
            case = self.fixture(provider)
            for phase in ("route", "prepare", "apply"):
                with self.subTest(provider=provider, phase=phase):
                    direct_code, direct = self.call(case, provider, phase, False)
                    code, routed = self.call(case, provider, phase, True)
                    self.assertEqual(code, direct_code)
                    for key in ("run_id", "unit_id", "provider", "operation", "state", "result",
                                "error_code", "input_manifest_sha256"):
                        self.assertEqual(routed[key], direct[key], key)
                    self.assertNotIn("native_operation_id", routed)
                    if os.name == "nt":
                        self.assertEqual(code, 2)
                        self.assertEqual(routed["error_code"], "UNSUPPORTED_FILESYSTEM")
                    else:
                        self.assertEqual(code, 0 if phase == "route" else 2)
                        self.assertEqual(routed["state"], "ROUTED" if phase == "route" else "BLOCKED")

    def test_request_mismatches_and_no_implicit_approval(self):
        if os.name == "nt":
            self.skipTest("POSIX request-file guards unavailable; native typed refusal tested separately")
        for provider in ("azure", "aws"):
            for field, value, error in (("provider", "aws" if provider == "azure" else "azure", "PROVIDER_MISMATCH"),
                                        ("owner", "terraform", "OWNER_UNSUPPORTED"),
                                        ("route", "other", "ROUTE_UNSUPPORTED")):
                with self.subTest(provider=provider, field=field):
                    case = self.fixture(provider)
                    self.assertEqual(self.call(case, provider, "route", False)[0], 0)
                    case.req[field] = value
                    direct_code, direct = self.call(case, provider, "route", False)
                    self.assertEqual(direct_code, 2)
                    self.assertIn(direct["schema"], ("cloud-input-error/v1", "cloud-operation-result/v1"))
                    code, routed = self.call(case, provider, "route", True)
                    self.assertEqual((code, routed["error_code"]), (direct_code, direct["error_code"]))
            case = self.fixture(provider)
            for raw in (b'{"provider":"azure","provider":"aws"}', b'{"schema":"cloud-run-request/v9"}'):
                self.assertEqual(self.call(case, provider, "route", True, raw)[0], 2)
            for phase in ("prepare", "apply"):
                code, value = self.call(case, provider, phase, True, extra=("--approve",))
                self.assertEqual(code, 2)
                self.assertEqual(value["schema"], "cloud-input-error/v1")

    def test_explicit_provider_and_installed_identity_are_required(self):
        case = self.fixture("azure")
        seam = self.install / "plugins/sdd-bootstrap/scripts/cloud-routing.py"
        for arguments in ([], ["--provider", "Azure"], ["--provider", "azure", "--plugin-root",
                           str(self.install / "plugins/sdd-aws-cloud")]):
            result = subprocess.run([sys.executable, "-B", str(seam), *arguments, "route",
                                     "--request", str(case.root / "request.json"), "--output", "out.json"],
                                    capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(json.loads(result.stdout)["schema"], "cloud-input-error/v1")


class NormalDriverRegistration(unittest.TestCase):
    def test_catalog_and_every_native_ci_cell_admit_all_six_suites(self):
        spec = importlib.util.spec_from_file_location("verification", ROOT / "tests/verification.py")
        assert spec and spec.loader
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        catalog = runner.load_catalog(ROOT / "tests/verification-catalog.json", ROOT)
        expected = {"tests/cloud-orchestration-" + name + ".tests.py"
                    for name in ("contracts", "routing", "execution", "verification")}
        expected.update(("tests/install-cloud.tests.py", "tests/sdd-domain-multitarget-foundation.tests.py"))
        for profile in ("local-posix", "local-powershell", "ci-cloud"):
            self.assertTrue(expected <= set(catalog["profiles"].get(profile, [])), profile)
        spec = importlib.util.spec_from_file_location("verification_workflow", ROOT / "tests/verification-workflow.py")
        assert spec and spec.loader
        workflow = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(workflow)
        data = workflow.load_workflow(ROOT / ".github/workflows/test.yml")
        self.assertEqual(workflow.coverage_errors(data, catalog), [])
        for os_name in ("ubuntu-latest", "macos-latest", "windows-latest"):
            isolated = copy.deepcopy(data)
            isolated["jobs"] = {"test": isolated["jobs"]["test"]}
            isolated["jobs"]["test"]["strategy"]["matrix"]["os"] = [os_name]
            self.assertTrue(expected <= workflow.workflow_coverage(isolated, catalog)["test"], os_name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
