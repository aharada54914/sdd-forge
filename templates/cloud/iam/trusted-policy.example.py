"""INERT external policy sketch; never import from deployment inputs.

Replace placeholders/zero IDs via owner review in the pinned executor repository.
One file per stage. Both pin the SAME reviewed deployment-policy JSON digest.
Trusted Python configuration is protected by the workflow/executor revision.
"""

from cloud_authorization import Policy

POLICY = Policy(
    provider="aws",
    repository="REPLACE_ORG/REPLACE_CONTROL_REPO",
    repository_id=0,
    workflow=".github/workflows/cloud-aws.yml",
    workflow_revision="REPLACE_40_HEX_CONTROL_WORKFLOW_COMMIT",
    ref="refs/heads/main",
    operation="prepare",
    environment="sandbox-prepare",
    target_environment="sandbox",
    environment_id=0,
    account_id="REPLACE_AWS_ACCOUNT_ID",
    region="REPLACE_AWS_REGION",
    deployment_scope="REPLACE_STACK",
    policy_sha256="REPLACE_64_HEX_REVIEWED_DEPLOYMENT_POLICY_JSON_SHA256",
    actors=((0, "REPLACE_OPERATOR_LOGIN"),),
    reviewers=((0, "REPLACE_REVIEWER_LOGIN"),),
    exclusive_repository="REPLACE_ORG/REPLACE_CONTROL_REPO",
    ttl_seconds=120,
    aws_role_arn="arn:aws:iam::REPLACE_AWS_ACCOUNT_ID:role/REPLACE_PREPARE_ROLE",
)
# Azure policy uses provider='azure', exact subscription/resource-group/region,
# and distinct azure_tenant, azure_client and azure_principal per stage. The
# policy_sha256 pins data in cloud-deployment-policy/v1, never this Python file.
