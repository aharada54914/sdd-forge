"""Immediate trusted CI caller. External protected configuration is data, not code.

Run only from the reviewed executor checkout using python -I. Bundle locators and
hashes are untrusted input; GitHub/OIDC/native federation still gate every mutation.
No arbitrary policy path/import, checkout, installation or synthesis from artifacts.
"""

from __future__ import annotations

import argparse
from dataclasses import fields as dataclass_fields
import json
import os
from pathlib import Path
import re
import sys

# -I ignores ambient Python paths; only this immutable reviewed checkout is code.
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
os.environ["CLOUD_SHARED_RUNTIME_ROOT"] = str(
    HERE.parents[1] / "sdd-quality-loop/scripts"
)
from cloud import c, decode, digest as digest, encode, run  # noqa: E402
from azure_arm import Response  # noqa: E402,F401
from azure_execution import AzureExecutor  # noqa: E402
from cloud_authorization import Policy, Runtime, WriteBoundary, _policy_valid  # noqa: E402

# Shared bounded acquisition has no dependency on either provider plugin.
from cloud_dependencies import (  # noqa: E402,F401
    ARCHIVE_LIMIT, ArtifactRedirect, ArtifactHttps, acquire_bundle as _acquire_bundle, verification_job,
)


def acquire_bundle(root: Path, repository: str, artifact_id: int, run_id: int, token: str, *, transport=None) -> dict:
    # Preserve the existing provider transport-injection seam for protocol tests.
    return _acquire_bundle(root, repository, artifact_id, run_id, token,
                           transport=transport if transport is not None else ArtifactHttps())


def load_policy(text: str, stage: str) -> Policy:
    """Caller passes a fixed protected-environment variable, never a bundle field."""
    value = decode(text.encode())
    c._require(
        type(value) is dict
        and set(value) <= {f.name for f in dataclass_fields(Policy)},
        "CONTROL_POLICY_INVALID",
    )
    for field in ("actors", "reviewers"):
        c._require(type(value[field]) is list, "CONTROL_POLICY_INVALID")
        value[field] = tuple(tuple(pair) for pair in value[field])
    if "predecessor_trust" in value:
        c._require(type(value["predecessor_trust"]) is list, "CONTROL_POLICY_INVALID")
        value["predecessor_trust"] = tuple(value["predecessor_trust"])
    policy = Policy(**value)
    _policy_valid(policy)
    c._require(
        policy.provider == "azure" and policy.operation == ("apply" if stage == "verify" else stage)
        and (stage != "verify" or policy.environment == "sandbox-verify"),
        "CONTROL_POLICY_INVALID",
    )
    return policy


def workflow_template(
    *,
    executor_repository: str | None = None,
    executor_revision: str | None = None,
    subscription: str | None = None,
    region: str | None = None,
    input_repository: str | None = None,
) -> dict:
    supplied = (
        executor_repository,
        executor_revision,
        subscription,
        region,
        input_repository,
    )
    if any(v is not None for v in supplied):
        c._require(
            all(type(v) is str and "REPLACE_" not in v for v in supplied),
            "CONFIGURATION_INCOMPLETE",
        )
        c._require(
            re.fullmatch(r"[a-f0-9]{40}", str(executor_revision)),
            "EXECUTOR_PIN_REQUIRED",
        )
        for repository in (executor_repository, input_repository):
            c._require(
                re.fullmatch(r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", str(repository)),
                "REPOSITORY_INVALID",
            )
        c._require(
            re.fullmatch(
                r"[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}", str(subscription)
            )
            and re.fullmatch(r"[a-z0-9-]+", str(region)),
            "SCOPE_INVALID",
        )
    executor_repository = executor_repository or "REPLACE_EXECUTOR_REPOSITORY"
    executor_revision = executor_revision or "REPLACE_REVIEWED_EXECUTOR_COMMIT"
    subscription = subscription or "REPLACE_SUBSCRIPTION"
    region = region or "REPLACE_REGION"
    input_repository = input_repository or "REPLACE_INPUT_REPOSITORY"
    inputs = {
        name: dict(required=True, type="string")
        for name in (
            "request_sha256",
            "preview_sha256",
            "artifact_id",
            "artifact_run_id",
        )
    }
    inputs["operation"] = dict(
        required=True,
        type="choice",
        options=["prepare", "apply", "reconcile", "observe", "verify"],
    )
    workflow: dict = {
        "name": "Governed Azure",
        "run-name": "cloud:${{ inputs.request_sha256 }}:${{ inputs.preview_sha256 }}",
        "on": {"workflow_dispatch": {"inputs": inputs}},
        "permissions": {},
        "concurrency": {
            "group": f"cloud-azure-{subscription}-{region}",
            "cancel-in-progress": False,
        },
        "jobs": {},
    }
    for stage in ("prepare", "apply", "reconcile", "observe", "verify"):
        operation = stage
        repo = input_repository if stage == "prepare" else "${{ github.repository }}"
        workflow["jobs"][stage] = {
            "if": "${{ github.run_attempt == 1 && inputs.operation == '"
            + stage
            + "' }}",
            "runs-on": "ubuntu-24.04",
            "environment": "sandbox-" + stage,
            "permissions": {"contents": "read", "actions": "read", "id-token": "write"},
            "timeout-minutes": 30,
            "steps": [
                {
                    "name": "Reviewed executor only",
                    "uses": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
                    "with": {
                        "repository": executor_repository,
                        "ref": executor_revision,
                        "path": "executor",
                        "persist-credentials": False,
                    },
                },
                {
                    "name": "Execute original apply; require native completion"
                    if stage == "apply"
                    else "Execute fixed read-only " + stage
                    if stage in ("reconcile", "observe", "verify")
                    else "Execute fixed prepare",
                    "shell": "bash",
                    "env": {
                        "AZURE_CONTROL_POLICY": "${{ vars.AZURE_"
                        + stage.upper()
                        + "_POLICY }}",
                        "GH_TOKEN": "${{ github.token }}",
                        "ARTIFACT_TOKEN": "${{ secrets.INPUT_ARTIFACT_READ_TOKEN }}"
                        if stage == "prepare"
                        else "${{ github.token }}",
                        "ARTIFACT_REPOSITORY": repo,
                        "ARTIFACT_ID": "${{ inputs.artifact_id }}",
                        "ARTIFACT_RUN_ID": "${{ inputs.artifact_run_id }}",
                        "REQUEST_SHA256": "${{ inputs.request_sha256 }}",
                        "PREVIEW_SHA256": "${{ inputs.preview_sha256 }}",
                    },
                    "run": "set -euo pipefail\npython3 -I executor/plugins/sdd-azure-cloud/scripts/azure_governed.py "
                    + operation
                    + ' --workspace "$RUNNER_TEMP/azure-data"'
                    + (" --require-native-apply" if stage == "apply" else ""),
                },
                {
                    "name": "Retain immutable data and original operation identity even on failure",
                    "if": "${{ always() }}",
                    "uses": "actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9",
                    "with": {
                        "name": "azure-" + stage + "-${{ github.run_id }}",
                        "path": "${{ runner.temp }}/azure-data/",
                        "if-no-files-found": "error",
                        "include-hidden-files": True,
                        "retention-days": "${{ vars.AZURE_EVIDENCE_RETENTION_DAYS }}",
                    },
                },
            ],
        }
    workflow["jobs"]["verify"] = verification_job("azure", executor_repository, executor_revision)
    return workflow


def role_setup(subscription: str, group: str) -> dict:
    c._require(
        re.fullmatch(r"[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}", subscription)
        and re.fullmatch(r"[A-Za-z0-9_-]+", group),
        "ROLE_SCOPE_INVALID",
    )
    read = [
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Resources/deployments/read",
        "Microsoft.Resources/deployments/operations/read",
        "Microsoft.Resources/deployments/operationstatuses/read",
        "Microsoft.Resources/deployments/whatIf/action",
        "Microsoft.Resources/deployments/validate/action",
    ]
    # These scope-local actions cover the supported private VM graph, not role assignments.
    resource_read = [
        t + "/read"
        for t in (
            "Microsoft.Compute/virtualMachines",
            "Microsoft.Compute/disks",
            "Microsoft.Compute/virtualMachines/extensions",
            "Microsoft.Network/networkInterfaces",
            "Microsoft.Insights/dataCollectionRuleAssociations",
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems",
        )
    ]
    writes = [action.removesuffix("/read") + "/write" for action in resource_read]
    result = {}
    for stage in ("prepare", "apply"):
        result[stage] = dict(
            Name="Governed Azure " + stage,
            IsCustom=True,
            Description="Supported private VM path only. External reference joins require separately scoped assignments.",
            Actions=read
            + resource_read
            + (
                ["Microsoft.Resources/deployments/write"] + writes
                if stage == "apply"
                else []
            ),
            NotActions=[],
            DataActions=[],
            NotDataActions=[],
            AssignableScopes=[f"/subscriptions/{subscription}/resourceGroups/{group}"],
        )
    return result


def require_native_apply(result: dict, executor) -> None:
    """A successful fixed APPLY job must have submitted and completed, not no-op/reconcile."""
    c._require(
        result["operation"] == "apply"
        and result["result"] == "PASS"
        and result["state"] == "OBSERVED"
        and result.get("native_operation_id") == executor.client.native_id
        and executor.may_have_submitted
        and executor.submission is not None,
        "ORIGINAL_APPLY_COMPLETION_REQUIRED",
    )


def main(argv: list[str]) -> dict:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument(
        "operation", choices=("prepare", "apply", "reconcile", "observe", "verify")
    )
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--require-native-apply", action="store_true")
    args = parser.parse_args(argv)
    try:
        c._require(
            not args.require_native_apply or args.operation == "apply", "STAGE_MISMATCH"
        )
        stage = "prepare" if args.operation == "prepare" else "apply"
        policy = load_policy(os.environ["AZURE_CONTROL_POLICY"], "verify" if args.operation == "verify" else stage)
        if args.operation in ("reconcile", "observe", "verify"):
            c._require(
                policy.environment == "sandbox-" + args.operation,
                "READ_ONLY_ENVIRONMENT_REQUIRED",
            )
        root = Path(args.workspace)
        c._require(root.is_absolute() and root.resolve() == root, "UNSAFE_ROOT")
        request_sha = os.environ["REQUEST_SHA256"]
        c._sha(request_sha)
        preview_sha = os.environ["PREVIEW_SHA256"]
        c._require(
            preview_sha == "none"
            if stage == "prepare"
            else bool(re.fullmatch(r"[a-f0-9]{64}", preview_sha)),
            "PREVIEW_DIGEST_REQUIRED",
        )
        acquire_bundle(
            root,
            os.environ["ARTIFACT_REPOSITORY"],
            int(os.environ["ARTIFACT_ID"]),
            int(os.environ["ARTIFACT_RUN_ID"]),
            os.environ["ARTIFACT_TOKEN"],
        )
        os.environ["CLOUD_WORKSPACE_ROOT"] = str(root)
        ref = dict(path="request.json", sha256=request_sha)
        request = c.read_artifact(root, ref, "cloud-run-request/v1")
        directory = request["local_context"]["evidence_directory"]
        c.verify_local_context(root, request, execution=True)
        (root / directory).mkdir(parents=True, exist_ok=True, mode=0o700)
        runtime = Runtime(
            os.environ["GH_TOKEN"],
            os.environ["ACTIONS_ID_TOKEN_REQUEST_URL"],
            os.environ["ACTIONS_ID_TOKEN_REQUEST_TOKEN"],
        )
        executor = AzureExecutor(
            root, ref, WriteBoundary(policy, runtime, root / directory)
        )
        output = directory + "/" + args.operation + "-result.json"
        if args.operation in ("apply", "reconcile"):
            executor.preview_ref = dict(
                path=directory + "/preview.json", sha256=preview_sha
            )
        result = run(
            [args.operation, "--request", "request.json", "--output", output],
            executor=executor,
        )
        if args.require_native_apply:
            require_native_apply(result, executor)
        return result
    except Exception:
        return c.input_error("GOVERNED_PREREQUISITE_REQUIRED", "runtime")


if __name__ == "__main__":
    if sys.argv[1:] == ["--render-template"]:
        print(json.dumps(workflow_template(), indent=2))
    else:
        result = main(sys.argv[1:])
        sys.stdout.buffer.write(encode(result))
        sys.exit(c.exit_code(result))
