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
        proc = subprocess.run([sys.executable, "-B", str(CLI), phase, "--request", str(self.root / "request.json"),
            "--output", output], cwd=self.root, env=env, capture_output=True, timeout=90)
        self.assertEqual(proc.returncode, expected, proc.stderr.decode(errors="replace"))
        self.assertTrue(proc.stdout.strip(), "Missing genuine typed CLI result")
        result = self.contracts.parse_artifact(proc.stdout)
        self.assertEqual(result["operation"], phase)
        self.assertEqual(result["run_id"], self.req["run_id"])
        self.assertNotIn("native_operation_id", result)
        if result.get("evidence_manifest_path"):
            manifest = json.loads((self.root/result["evidence_manifest_path"]).read_bytes())
            schema = json.loads((ROOT/"plugins/sdd-azure-cloud/references/azure-local-evidence.schema.json").read_bytes())
            self.assertEqual(self.oracle._schema_validate(schema, manifest), [])
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
                           ("raw.yml", b"Resources: {}"),
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
                self.assertEqual(result["error_code"], "OPERATION_UNIMPLEMENTED")
                self.assertIsNone(result["evidence_manifest_path"])


    def test_missing_installed_runtime_and_unknown_config_are_typed_denials(self):
        self.put("request.json", self.req)
        proc = subprocess.run([sys.executable, "-B", str(CLI), "route", "--request", str(self.root/"request.json"),
            "--output", str(self.root/self.evidence/"missing.json")],
            env={"PATH": os.defpath, "CLOUD_SHARED_RUNTIME_ROOT": str(self.root/"missing")}, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(self.contracts.parse_artifact(proc.stdout)["error_code"], "SHARED_RUNTIME_UNAVAILABLE")
        self.config["unknown"] = True
        self.refresh()
        self.assertEqual(self.invoke(expected=2)["result"], "BLOCKED")

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
        self.upstream = Path(os.environ.get("CLOUD_AZURE_UPSTREAM_ROOT",
            "/tmp/cloud-T004-01a14d9e-7a63-71c2-a07c-aa71d275b9de/upstream/azure-skills-cf79ce8778ad063eeac19dbe8bf982d71b466ce0"))
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

    def test_unsupported_filesystem_subprocess(self):
        self.put("request.json", self.req)
        bootstrap = "import os,runpy,sys; os.supports_dir_fd=set(); sys.argv=sys.argv[1:]; runpy.run_path(sys.argv[0],run_name='__main__')"
        proc = subprocess.run([sys.executable, "-B", "-c", bootstrap, str(CLI), "route", "--request", str(self.root/"request.json"),
            "--output", str(self.root/self.evidence/"unsupported.json")],
            env={"PATH": os.defpath, "CLOUD_WORKSPACE_ROOT": str(self.root)}, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(self.contracts.parse_artifact(proc.stdout)["error_code"], "UNSUPPORTED_FILESYSTEM")
        self.assertFalse((self.root/self.evidence/"unsupported.json").exists())



if __name__ == "__main__":
    unittest.main(verbosity=2)
