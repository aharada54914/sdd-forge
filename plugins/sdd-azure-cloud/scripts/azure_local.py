"""Local Bicep preparation and bounded Azure VM graph policy, not ARM validation.

Compile exact locked sources with no restore or credentials, then validate actual
resource semantics. Unsupported Azure structures block rather than gain authority.
"""
from __future__ import annotations

import copy
import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile

from cloud import c, decode, digest, encode, publish_bytes, safe_publication

VERSION = "0.48.1"
BINARY_SHA = "b09ec25a9d376c1f8e33ede6ed22b587f915ad68488d5db77a6f9541748c7f6e"
ADAPTER_VERSION = "1.0.0"
PLUGIN = Path(__file__).resolve().parents[1]
TYPES = ["Microsoft.Network/networkInterfaces", "Microsoft.Compute/virtualMachines",
         "Microsoft.Compute/virtualMachines/extensions", "Microsoft.Insights/dataCollectionRuleAssociations",
         "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems"]
PARAMS = ("vmName", "location", "vmSize", "imageId", "adminUsername", "adminPublicKey", "subnetId",
          "identityId", "dataCollectionRuleId", "vaultName", "backupPolicyId")


def observation_configuration(value: dict) -> None:
    from azure_observation import configuration as validate_observation
    validate_observation(value)


def configuration(cfg: dict, *, discovery: bool = False) -> None:
    if discovery and set(cfg) == {"schema", "import_resources"}:
        c._record(cfg, {"schema": lambda v: c._enum(v, ("azure-local-config/v1",)),
                        "import_resources": lambda v: c._require(v is False)})
        return
    c._record(cfg, {
        "schema": lambda v: c._enum(v, ("azure-local-config/v1",)),
        "entrypoint": c._path, "parameters": c._path, "upstream_root": c._path,
        "output_directory": c._path, "import_resources": lambda v: c._require(v is False),
        "network": lambda v: c._record(v, {"subnet_id": c._text,
            "private_management": lambda x: c._require(x is True),
            "inbound_internet": lambda x: c._require(x is False)}),
        "identity": lambda v: c._record(v, {"resource_id": c._text}),
        "monitoring": lambda v: c._record(v, {"data_collection_rule_id": c._text}),
        "backup": lambda v: c._record(v, {"policy_id": c._text}),
        "cost": lambda v: c._record(v, {"estimated_minor_units": lambda n: c._integer(n, 1),
            "currency": lambda x: c._match(x, r"[A-Z]{3}"), "duration_hours": lambda n: c._integer(n, 1)}),
        "evidence": lambda v: c._record(v, {"residency": c._id, "retention_days": lambda n: c._integer(n, 1),
            "access": lambda x: c._enum(x, ("restricted",))})}, {"observation": observation_configuration})


def local_policy(root: Path, request: dict) -> tuple[dict, dict]:
    """Closed provider config/parameter shapes and cross-artifact policy checks."""
    try:
        cfg = decode(c.read_verified(root, request["local_context"]["provider_config"]))
        configuration(cfg)
        context = request["local_context"]
        c._require(request["operation"] == "apply")
        c._require(c._within(cfg["output_directory"], context["artifact_root"]))
        c._require(not any(c._within(cfg["output_directory"], u) or c._within(u, cfg["output_directory"])
                           for u in context["unit_roots"]))
        by_path = {a["path"]: a for a in request["input_artifacts"]}
        c._require(by_path[cfg["entrypoint"]]["kind"] == "source" and cfg["entrypoint"].endswith(".bicep"))
        ref = by_path[cfg["parameters"]]
        c._require(ref["kind"] == "parameters")
        body = decode(c.read_verified(root, c._file_ref(ref)))
        c._record(body, {"$schema": lambda v: c._enum(v, (
            "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",)),
            "contentVersion": lambda v: c._enum(v, ("1.0.0.0",)),
            "parameters": lambda v: c._record(v, {p: lambda x: c._record(x, {"value": c._text}) for p in PARAMS})})
        p = {k: body["parameters"][k]["value"] for k in PARAMS}
        for name in ("vmName", "adminUsername", "vaultName"):
            c._match(p[name], r"[a-z][a-z0-9-]{1,30}")
        c._match(p["vmSize"], r"Standard_[A-Za-z0-9_]{1,60}")
        c._match(p["adminPublicKey"], r"ssh-(?:ed25519|rsa) [A-Za-z0-9+/]{40,1024}={0,2}")
        scope = request["scope"]
        c._match(scope["account_id"], r"[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}")
        c._require(p["location"] == scope["region"])
        prefix = "/subscriptions/" + scope["account_id"] + "/resourceGroups/"
        generic = re.escape(prefix) + r"[A-Za-z0-9_-]+/providers/"
        patterns = {
            "subnetId": "Microsoft.Network/virtualNetworks/[A-Za-z0-9_-]+/subnets/[A-Za-z0-9_-]+",
            "identityId": "Microsoft.ManagedIdentity/userAssignedIdentities/[A-Za-z0-9_-]+",
            "dataCollectionRuleId": "Microsoft.Insights/dataCollectionRules/[A-Za-z0-9_-]+",
            "imageId": r"Microsoft.Compute/galleries/[A-Za-z0-9_-]+/images/[A-Za-z0-9_-]+/versions/[0-9]+\.[0-9]+\.[0-9]+"}
        for name, pattern in patterns.items():
            c._match(p[name], generic + pattern.replace("Microsoft.", r"Microsoft\."))
        c._match(p["backupPolicyId"], re.escape(prefix + scope["deployment_scope"] +
            "/providers/Microsoft.RecoveryServices/vaults/" + p["vaultName"] + "/backupPolicies/") + r"[A-Za-z0-9_-]+")
        c._require(cfg["network"]["subnet_id"] == p["subnetId"] and
                   cfg["identity"]["resource_id"] == p["identityId"] and
                   cfg["monitoring"]["data_collection_rule_id"] == p["dataCollectionRuleId"] and
                   cfg["backup"]["policy_id"] == p["backupPolicyId"])
        policy = c.read_artifact(root, request["policy"], "cloud-deployment-policy/v1")
        c._require(set(TYPES) <= set(policy["allowed_resource_types"]))
        c._require(cfg["cost"]["currency"] == policy["budget"]["currency"] and
                   cfg["cost"]["estimated_minor_units"] <= policy["budget"]["ceiling_minor_units"])
        c._require(cfg["evidence"] == policy["evidence"])
        ownership = c.read_artifact(root, context["ownership"], "cloud-ownership/v1")
        required = [(p["subnetId"], TYPES[0], p["vmName"] + "-nic"),
                    (p["identityId"], TYPES[1], p["vmName"]),
                    (p["dataCollectionRuleId"], TYPES[3], p["vmName"] + "-monitor"),
                    (p["backupPolicyId"], TYPES[4], p["vmName"])]
        resources = ownership["existing_resources"]
        c._require({r["resource_id"] for r in resources} == {r[0] for r in required})
        for rid, typ, name in required:
            resource = next(r for r in resources if r["resource_id"] == rid)
            c._require(len(resource["attachments"]) == 1 and
                       resource["attachments"][0]["resource_type"] == typ)
        # No existing VM/NIC is claimed/imported. References keep their original owner.
        return cfg, p
    except (c.ContractError, ValueError, KeyError, TypeError, StopIteration):
        raise c.ContractError("LOCAL_POLICY_DENIED") from None


def source_snapshot(root: Path, request: dict, files: list[str], cfg: dict) -> dict[str, bytes]:
    refs = [a for a in request["input_artifacts"] if a["kind"] != "compiled"]
    c._require(set(files) == {a["path"] for a in refs}, "UNLOCKED_SOURCE")
    snapshot = {a["path"]: c.read_verified(root, c._file_ref(a)) for a in refs}
    for path, data in snapshot.items():
        c._require(Path(path).name != "bicepconfig.json", "UNSUPPORTED_BICEP_CONFIG")
        if not path.endswith(".bicep"):
            continue
        text = data.decode("utf-8")
        # Preserve quoted text while removing comments between compiler-read tokens.
        text = re.sub(r"'(?:\\.|[^'\\])*'|//[^\n]*|/\*[\s\S]*?\*/",
                      lambda m: m[0] if m[0].startswith("'") else " ", text)
        c._require(not re.search(r"\b(extension|provider|readEnvironmentVariable)\b", text), "UNSUPPORTED_SOURCE")
        # All compiler file reads are literal and must be locked. No registry/cache fetch.
        matches = re.findall(r"\b(?:module\s+\w+|from|using)\s+'([^']+)'|\bload\w+\s*\(\s*'([^']+)'", text)
        declarations = re.findall(r"\bmodule\s+\w+|\bfrom|\busing", text)
        literal_declarations = re.findall(r"\b(?:module\s+\w+|from|using)\s+'[^']+'", text)
        c._require(len(declarations) == len(literal_declarations), "UNLOCKED_SOURCE")
        for pair in matches:
            dep = next(x for x in pair if x)
            c._require(not dep.startswith("/") and ":" not in dep and "\\" not in dep, "UNLOCKED_SOURCE")
            normalized = os.path.normpath(str(PurePosixPath(path).parent / dep))
            c._path(normalized)
            c._require(normalized in snapshot, "UNLOCKED_SOURCE")
        # Unknown/nonliteral read forms are not supported by this local adapter.
        reads = re.findall(r"\bload\w+\s*\(", text)
        literal_reads = re.findall(r"\bload\w+\s*\(\s*'[^']+'", text)
        c._require(len(reads) == len(literal_reads), "UNLOCKED_SOURCE")
    c._require(cfg["entrypoint"] in snapshot, "UNLOCKED_SOURCE")
    return snapshot


def compiler() -> tuple[Path, dict]:
    path = Path(os.environ.get("CLOUD_BICEP_BIN", ""))
    c._require(path.is_absolute() and path.resolve() == path and path.is_file(), "BICEP_UNAVAILABLE")
    info = path.stat()
    c._require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, "BICEP_UNAVAILABLE")
    with path.open("rb") as stream:
        sha = hashlib.file_digest(stream, "sha256").hexdigest()
    c._require(sha == BINARY_SHA, "BICEP_PIN_MISMATCH")
    result = subprocess.run([str(path), "--version"], capture_output=True, timeout=15,
                            env={"PATH": os.defpath, "DOTNET_CLI_TELEMETRY_OPTOUT": "1"})
    c._require(result.returncode == 0 and result.stdout.strip() ==
               b"Bicep CLI version 0.48.1 (cec7951cf6)", "BICEP_VERSION_MISMATCH")
    return path, dict(name="bicep", version=VERSION, sha256=sha)


def upstream(root: Path, request: dict, cfg: dict, tool: dict) -> None:
    pin = decode((PLUGIN / "references/upstream-lock.json").read_bytes())
    lock = c.read_artifact(root, request["dependency_lock"], "cloud-dependency-lock/v1")
    base = cfg["upstream_root"]
    expected = dict(repository=pin["repository"], commit=pin["commit"], root=base,
                    files=[dict(path=base + "/" + f["path"], sha256=f["sha256"],
                                references=[base + "/" + p for p in f["references"]]) for f in pin["files"]])
    c._require(lock["upstream"] == [expected], "UPSTREAM_PIN_MISMATCH")
    c.verify_lock(root, lock, consumed_paths=[f["path"] for f in expected["files"]],
                  tools=[tool], adapter_version=ADAPTER_VERSION, tool_schemas={})


def prepare_local(root: Path, request: dict, files: list[str], phase: str, request_ref: dict) -> dict:
    cfg, parameters = local_policy(root, request)
    snapshot = source_snapshot(root, request, files, cfg)
    binary, tool = compiler()
    upstream(root, request, cfg, tool)
    with tempfile.TemporaryDirectory(prefix="azure-local-bicep-") as temporary:
        scratch = Path(temporary).resolve()
        for path, data in snapshot.items():
            destination = scratch / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        proc = subprocess.run([str(binary), "build", str(scratch / cfg["entrypoint"]),
                               "--no-restore", "--stdout"], cwd=scratch, capture_output=True,
                              timeout=60, env={"PATH": os.defpath, "HOME": str(scratch),
                                  "DOTNET_CLI_TELEMETRY_OPTOUT": "1"})
    c._require(proc.returncode == 0, "BICEP_COMPILE_FAILED")
    actual = decode(proc.stdout)
    from azure_graph import validate_graph
    validate_graph(actual, parameters, request,
                   c.read_artifact(root, request["policy"], "cloud-deployment-policy/v1"),
                   c.read_artifact(root, request["local_context"]["ownership"], "cloud-ownership/v1"))
    # Recheck the original sources/config/lock after compile; freeze only the exact inputs.
    c._require(c.verify_local_context(root, request) == files, "INPUT_DRIFT")
    c._require(source_snapshot(root, request, files, cfg) == snapshot, "INPUT_DRIFT")
    compiled = [a for a in request["input_artifacts"] if a["kind"] == "compiled"]
    if phase == "plan":
        c._require(not compiled, "PLAN_ALREADY_LOCKED")
        prefix = cfg["output_directory"] + "/" + request_ref["sha256"]
        # Check both final names before publication, never replace a prior plan.
        for path in (prefix + ".arm.json", prefix + ".request.json"):
            with c._parent(root, path) as (fd, name):
                try:
                    os.stat(name, dir_fd=fd, follow_symlinks=False)
                except FileNotFoundError:
                    continue
                raise c.ContractError("PLAN_EXISTS")
        arm_ref = publish_bytes(root, prefix + ".arm.json", proc.stdout)
        locked = copy.deepcopy(request)
        locked["input_artifacts"].append(dict(kind="compiled", **arm_ref))
        c.parse_artifact(encode(locked), "cloud-run-request/v1")
        locked_ref = c.publish_artifact(root, prefix + ".request.json", encode(locked), scan=safe_publication)
    else:
        c._require(len(compiled) == 1, "COMPILED_ARTIFACT_REQUIRED")
        arm_ref = c._file_ref(compiled[0])
        c._require(c.read_verified(root, arm_ref) == proc.stdout, "COMPILED_MISMATCH")
        locked_ref = request_ref
    return dict(locked_request=locked_ref, compiled=arm_ref,
                compiler={**tool, "exit_code": proc.returncode, "diagnostics_sha256": digest(proc.stderr)},
                local_policy="PASS", parameter_sha256=next(a["sha256"] for a in request["input_artifacts"]
                    if a["path"] == cfg["parameters"]),
                source_closure=[dict(path=p, sha256=digest(b)) for p, b in sorted(snapshot.items())])
