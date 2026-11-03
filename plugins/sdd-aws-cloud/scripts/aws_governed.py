"""Immediate trusted CI caller. External protected configuration is data, not code.

Run only from the reviewed executor checkout using python -I. Bundle locators and
hashes are untrusted input; GitHub/OIDC/native federation still gate every mutation.
No arbitrary policy path/import, checkout, installation or synthesis from artifacts.
"""

from __future__ import annotations

import argparse
import copy
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
from aws_native import Response  # noqa: E402,F401
from aws_execution import AwsExecutor  # noqa: E402
from aws_control import Control  # noqa: E402
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
        policy.provider == "aws" and policy.operation == ("apply" if stage == "verify" else stage)
        and (stage != "verify" or policy.environment == "sandbox-verify"),
        "CONTROL_POLICY_INVALID",
    )
    return policy


def workflow_template(
    *,
    executor_repository: str | None = None,
    executor_revision: str | None = None,
    account: str | None = None,
    region: str | None = None,
    input_repository: str | None = None,
) -> dict:
    supplied = (
        executor_repository,
        executor_revision,
        account,
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
            re.fullmatch(r"[0-9]{12}", str(account))
            and re.fullmatch(r"[a-z0-9-]+", str(region)),
            "SCOPE_INVALID",
        )
    executor_repository = executor_repository or "REPLACE_EXECUTOR_REPOSITORY"
    executor_revision = executor_revision or "REPLACE_REVIEWED_EXECUTOR_COMMIT"
    account = account or "REPLACE_ACCOUNT"
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
        required=True, type="choice", options=["prepare", "apply", "reconcile"]
    )
    workflow: dict = {
        "name": "Governed AWS",
        "run-name": "cloud:${{ inputs.request_sha256 }}:${{ inputs.preview_sha256 }}",
        "on": {"workflow_dispatch": {"inputs": inputs}},
        "permissions": {},
        "concurrency": {
            "group": f"cloud-aws-{account}-{region}",
            "cancel-in-progress": False,
        },
        "jobs": {},
    }
    for stage in ("prepare", "apply"):
        operation = "${{ inputs.operation }}"
        repo = input_repository if stage == "prepare" else "${{ github.repository }}"
        workflow["jobs"][stage] = {
            "if": "${{ github.run_attempt == 1 && "
            + (
                "inputs.operation == 'prepare'"
                if stage == "prepare"
                else "(inputs.operation == 'apply' || inputs.operation == 'reconcile')"
            )
            + " }}",
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
                    "name": "Integrity checked data acquisition and governed execution",
                    "shell": "bash",
                    "env": {
                        "AWS_CONTROL_POLICY": "${{ vars.AWS_"
                        + stage.upper()
                        + "_POLICY }}",
                        "AWS_EXECUTION_CONTROL": "${{ vars.AWS_EXECUTION_CONTROL }}",
                        "GH_TOKEN": "${{ github.token }}",
                        "ARTIFACT_TOKEN": "${{ secrets.INPUT_ARTIFACT_READ_TOKEN }}"
                        if stage == "prepare"
                        else "${{ github.token }}",
                        "ARTIFACT_REPOSITORY": repo,
                        "ARTIFACT_ID": "${{ inputs.artifact_id }}",
                        "ARTIFACT_RUN_ID": "${{ inputs.artifact_run_id }}",
                        "REQUEST_SHA256": "${{ inputs.request_sha256 }}",
                        "PREVIEW_SHA256": "${{ inputs.preview_sha256 }}",
                        "CLOUD_PHASE": operation,
                    },
                    "run": 'set -euo pipefail\npython3 -I executor/plugins/sdd-aws-cloud/scripts/aws_governed.py "$CLOUD_PHASE" --workspace "$RUNNER_TEMP/aws-data"',
                },
                {
                    "name": "Retain immutable data and original operation identity even on failure",
                    "if": "${{ always() }}",
                    "uses": "actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9",
                    "with": {
                        "name": "aws-" + stage + "-${{ github.run_id }}",
                        "path": "${{ runner.temp }}/aws-data/",
                        "if-no-files-found": "error",
                        "include-hidden-files": True,
                        "retention-days": "${{ vars.AWS_EVIDENCE_RETENTION_DAYS }}",
                    },
                },
            ],
        }
    recovery = copy.deepcopy(workflow["jobs"]["apply"])
    recovery["if"] = "${{ github.run_attempt == 1 && inputs.operation == 'reconcile' }}"
    recovery["environment"] = "sandbox-recovery-apply"
    recovery["steps"][1]["env"]["AWS_CONTROL_POLICY"] = (
        "${{ vars.AWS_RECOVERY_POLICY }}"
    )
    recovery["steps"][2]["with"]["name"] = "aws-reconcile-${{ github.run_id }}"
    workflow["jobs"]["apply"]["if"] = (
        "${{ github.run_attempt == 1 && inputs.operation == 'apply' }}"
    )
    workflow["jobs"]["reconcile"] = recovery
    workflow["jobs"]["verify"] = verification_job("aws", executor_repository, executor_revision)
    workflow["on"]["workflow_dispatch"]["inputs"]["operation"]["options"].append("verify")
    return workflow


def role_setup(account: str, region: str, stack: str, control: Control) -> dict:
    """Inactive identity-policy examples; service role is a separate owner prerequisite.

    AWS service authorization reference: Create/ExecuteChangeSet resource is stack;
    RoleArn condition exists only for CreateChangeSet. No implicit role creation.
    """
    c._require(
        re.fullmatch(r"[0-9]{12}", account)
        and re.fullmatch(r"[a-z]{2}-[a-z]+-[1-9]", region)
        and re.fullmatch(r"[A-Za-z][A-Za-z0-9-]{0,127}", stack),
        "IAM_SCOPE_INVALID",
    )
    c._require(
        re.fullmatch(
            r"arn:aws:iam::" + account + r":role/[A-Za-z0-9_+=,.@/-]+",
            control.execution_role_arn,
        ),
        "IAM_ROLE_INVALID",
    )
    c._require(
        control.bucket == "cdk-hnb659fds-assets-" + account + "-" + region,
        "IAM_BUCKET_INVALID",
    )
    arn = "arn:aws:cloudformation:" + region + ":" + account + ":stack/" + stack + "/*"
    s3 = "arn:aws:s3:::" + control.bucket
    reads = [
        dict(
            Effect="Allow",
            Action=[
                "cloudformation:" + op
                for op in (
                    "DescribeChangeSet",
                    "GetTemplate",
                    "DescribeStacks",
                    "DescribeStackEvents",
                )
            ],
            Resource=arn,
        ),
        dict(
            Effect="Allow",
            Action=[
                "s3:GetBucketLocation",
                "s3:GetBucketVersioning",
                "s3:GetBucketPublicAccessBlock",
            ],
            Resource=s3,
            Condition={"StringEquals": {"s3:ResourceAccount": account}},
        ),
        dict(
            Effect="Allow",
            Action="s3:GetObjectVersion",
            Resource=s3 + "/*.json",
            Condition={"StringEquals": {"s3:ResourceAccount": account}},
        ),
    ]
    # Tag dependent actions are confined to exactly the fixed ownership tags and
    # stack. Do not grant UntagResource: this path never removes ownership tags.
    tags = dict(
        Effect="Allow",
        Action="cloudformation:TagResource",
        Resource=arn,
        Condition={
            "ForAllValues:StringEquals": {"aws:TagKeys": ["sdd-unit", "sdd-owner"]},
            "StringEquals": {
                "aws:RequestTag/sdd-unit": control.unit_id,
                "aws:RequestTag/sdd-owner": "cdk",
            },
        },
    )
    create = dict(
        Effect="Allow",
        Action="cloudformation:CreateChangeSet",
        Resource=arn,
        Condition={
            "ArnEquals": {"cloudformation:RoleArn": control.execution_role_arn},
            "StringLike": {
                "cloudformation:ChangeSetName": "sdd-*",
                "cloudformation:TemplateUrl": "https://"
                + control.bucket
                + ".s3."
                + region
                + ".amazonaws.com/*.json?versionId=*",
            },
            "StringEquals": {
                "aws:RequestTag/sdd-unit": control.unit_id,
                "aws:RequestTag/sdd-owner": "cdk",
            },
        },
    )
    passing = dict(
        Effect="Allow",
        Action="iam:PassRole",
        Resource=control.execution_role_arn,
        Condition={
            "StringEquals": {"iam:PassedToService": "cloudformation.amazonaws.com"}
        },
    )
    publishing = dict(
        Effect="Allow",
        Action="s3:PutObject",
        Resource=s3 + "/*.json",
        Condition={
            "StringEquals": {
                "s3:ResourceAccount": account,
                "s3:x-amz-server-side-encryption": "AES256",
            }
        },
    )
    execute = dict(
        Effect="Allow",
        Action="cloudformation:ExecuteChangeSet",
        Resource=arn,
        Condition={
            "StringLike": {
                "cloudformation:ChangeSetName": "arn:aws:cloudformation:"
                + region
                + ":"
                + account
                + ":changeSet/sdd-*/*"
            }
        },
    )
    return {
        "prepare": dict(
            Version="2012-10-17", Statement=reads + [tags, create, passing, publishing]
        ),
        "apply": dict(Version="2012-10-17", Statement=reads + [tags, execute]),
    }


def main(argv: list[str]) -> dict:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("operation", choices=("prepare", "apply", "reconcile", "observe", "verify"))
    parser.add_argument("--workspace", required=True)
    args = parser.parse_args(argv)
    try:
        stage = "prepare" if args.operation == "prepare" else "apply"
        policy = load_policy(os.environ["AWS_CONTROL_POLICY"], "verify" if args.operation == "verify" else stage)
        control_value = decode(os.environ["AWS_EXECUTION_CONTROL"].encode())
        c._require(
            set(control_value) == {f.name for f in dataclass_fields(Control)},
            "CONTROL_INVALID",
        )
        control = Control(**control_value)
        root = Path(args.workspace)
        c._require(root.is_absolute() and root.resolve() == root, "UNSAFE_ROOT")
        request_sha = os.environ["REQUEST_SHA256"]
        c._sha(request_sha)
        preview_sha = os.environ["PREVIEW_SHA256"]
        c._require(
            preview_sha == "none"
            if stage == "prepare"
            else (
                preview_sha == "none"
                if args.operation == "reconcile" and preview_sha == "none"
                else bool(re.fullmatch(r"[a-f0-9]{64}", preview_sha))
            ),
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
        executor = AwsExecutor(
            root, ref, WriteBoundary(policy, runtime, root / directory), control
        )
        output = directory + "/" + args.operation + "-result.json"
        if args.operation in ("apply", "reconcile") and preview_sha != "none":
            executor.preview_ref = dict(
                path=directory + "/preview.json", sha256=preview_sha
            )
        return run(
            [args.operation, "--request", "request.json", "--output", output],
            executor=executor,
        )
    except Exception:
        return c.input_error("GOVERNED_PREREQUISITE_REQUIRED", "runtime")


if __name__ == "__main__":
    if sys.argv[1:] == ["--render-template"]:
        print(json.dumps(workflow_template(), indent=2))
    else:
        result = main(sys.argv[1:])
        sys.stdout.buffer.write(encode(result))
        sys.exit(c.exit_code(result))
