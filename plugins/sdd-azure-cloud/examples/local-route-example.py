"""Create a synthetic local routing example, never deployment authority.

All outputs go in a new explicit physical directory. No network, tools or cloud
credentials are used. This minimal discovery fixture cannot compile or deploy.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def create(root: Path, provider: str) -> None:
    if not root.is_absolute() or root != root.resolve() or root.exists():
        raise ValueError("Use a new absolute physical directory")
    root.mkdir(mode=0o700)

    def put(path: str, value: Any) -> dict[str, str]:
        data = value if isinstance(value, bytes) else (json.dumps(value, sort_keys=True) + "\n").encode()
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        with dest.open("xb") as handle:
            handle.write(data)
        return dict(path=path, sha256=hashlib.sha256(data).hexdigest())

    azure = provider == "azure"
    owner = "bicep" if azure else "cdk"
    source = put("bundle/unit/main.bicep" if azure else "bundle/unit/cdk.json",
                 b"targetScope = 'resourceGroup'\n" if azure else b'{"app":"node app.js"}\n')
    scope = dict(account_id="11111111-1111-1111-1111-111111111111" if azure else "111111111111",
                 region="eastus" if azure else "us-east-1", deployment_scope="synthetic-only")
    upstream = put("bundle/upstream/reference.md", b"Synthetic route-only reference, not upstream authority.\n")
    evidence = "specs/cloud-example/verification/T-001/cloud/example-run/example-unit"
    (root / evidence).mkdir(parents=True)
    request = dict(
        schema="cloud-run-request/v1", run_id="example-run", unit_id="example-unit",
        provider=provider, binding_id="synthetic-binding", environment="synthetic",
        scope=scope, owner=owner, route="azure-bicep" if azure else "aws-cdk",
        operation="route", source_revision="a" * 40, predecessor_receipts=[],
        input_artifacts=[dict(kind="source", **source)],
        dependency_lock=put("bundle/lock.json", dict(
            schema="cloud-dependency-lock/v1", adapter_version="1.0.0",
            upstream=[dict(repository="https://example.invalid/synthetic", commit="a" * 40,
                           root="bundle/upstream", files=[dict(**upstream, references=[])])],
            tools=[dict(name="bicep" if azure else "aws-cdk", version="0.48.1" if azure else "2.1145.0",
                        sha256="a" * 64)], managed_endpoints=[])),
        policy=put("bundle/policy.json", dict(
            schema="cloud-deployment-policy/v1", allowed_scopes=[scope],
            allowed_resource_types=["Microsoft.Compute/virtualMachines" if azure else "AWS::EC2::Instance"],
            backup_required=True, private_networking=True,
            budget=dict(ceiling_minor_units=10000, currency="USD"),
            evidence=dict(residency="synthetic-local", retention_days=7, access="restricted"))),
        verification_profile=dict(id="cloud-compute", version="2", **put("bundle/profile.json", dict(
            schema="cloud-verification-profile/v1", id="cloud-compute", version="2",
            required_check_ids=["resource", "network", "identity", "monitoring", "workload", "backup"],
            max_age_seconds=300))),
        local_context=dict(workspace_anchor="CLOUD_WORKSPACE_ROOT", artifact_root="bundle",
            unit_roots=["bundle/unit"], evidence_directory=evidence,
            feature="cloud-example", task_id="T-001",
            ownership=put("bundle/ownership.json", dict(schema="cloud-ownership/v1",
                owners=[dict(owner=owner, root="bundle/unit")], existing_resources=[])),
            provider_config=put("bundle/config.json", dict(
                schema=provider + "-local-config/v1", import_resources=False))),
    )
    put("request.json", request)
    print(root / "request.json")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--provider", choices=("azure", "aws"), default="azure")
    args = parser.parse_args()
    create(args.directory, args.provider)
