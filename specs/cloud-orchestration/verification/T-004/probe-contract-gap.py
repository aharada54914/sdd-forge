"""Reproduce T-004 input ambiguity without changing or extending shared contracts."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


c = load(ROOT / "plugins/sdd-quality-loop/scripts/cloud_contracts.py", "contracts")
t = load(ROOT / "tests/cloud-orchestration-routing.tests.py", "routing_tests")
schema = json.loads((ROOT / "contracts/cloud-run-request.schema.json").read_bytes())
request = t.request("route")
c.parse_artifact(json.dumps(request).encode())
print("Existing Azure request accepted by shared strict validator.")
print("Complete request property inventory:", ", ".join(sorted(schema["properties"])))
assert schema["additionalProperties"] is False
# Illustrative keys only, NOT proposed additions or accepted wire formats.
for key, value in {
    "workspace_root": "/synthetic/workspace",
    "artifact_root": "/synthetic/artifacts",
    "declared_roots": ["infra"],
    "evidence_directory": "evidence/synthetic-run",
    "ownership_manifest": {"path": "owner.json", "sha256": "a" * 64},
}.items():
    assert key not in schema["properties"]
    try:
        c.parse_artifact(json.dumps({**request, key: value}).encode())
    except c.ContractError as error:
        print(key + ": rejected (" + str(error) + ")")
    else:
        raise AssertionError("Unexpected open request contract")
for key in ("policy", "verification_profile"):
    print(key + " properties:", ", ".join(sorted(schema["properties"][key]["properties"])))
print("No policy-body or deployment-owner metadata schema is registered:")
print(", ".join(sorted(c.VALIDATORS)))
print("Conclusion: explicit adapter root/owner/policy format needs a contract decision; no inferred authority.")
