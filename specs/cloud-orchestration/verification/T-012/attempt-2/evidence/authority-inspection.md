# Read-only authority inspection (implementation work, not independent review)

The new executed Red/Green matrix covers provider, account, region, resource group,
logical target, deployment-policy digest, operation and exclusive control repository
for both journal and fence paths. The code calls the same pure trusted_binding
before federation or ARM read; no apply preview expiry or write approval is checked.

Other changed authority fields were inspected in existing reused primitives, not
claimed as newly failing tests: GitHubAdmission.oidc constructs exact expected
repository/repository_id/workflow_ref/workflow_sha/ref/sha/environment/event/attempt
and actor membership before returning authenticated claims. AzureIdentity.exchange
compares freshly issued principal object ID, tenant, client ID, audience and token
window before subscription readback; subscription/tenant/enabled state must match.
_policy_valid requires exact exclusive_repository==repository and valid pin/actor/
reviewer/environment configuration. Shared deterministic admission regressions in
the final execution log cover those mechanisms. No injected/local journal can
replace those fresh expectations. The new pure binding supplements them with the
request target and policy comparisons that were missing in read-only recovery.

A malformed/tampered fence identity is rejected as BLOCKED before native reads;
a valid original intent whose expected target policy no longer matches retains
UNKNOWN and the original native ID. Unavailable fresh identity/history cannot
be interpreted as completed recovery. No credentials were inspected or persisted.

Source anchors: `cloud_authorization.py:187` exclusive control;
`cloud_authorization.py:248-266` OIDC expectations;
`cloud_authorization.py:458-475` native principal/subscription expectations;
`azure_execution.py:209-222` pure target/policy binding;
`azure_execution.py:641-705` both read-only recovery paths.
Existing executed test counterparts: `test_each_authenticated_oidc_binding_mismatch_denies`,
`test_provider_identity_and_lease_mismatch_before_each_stage`,
`test_environment_policy_and_missing_api_data_fail_closed` and
`test_revocation_during_federation_and_missing_native_identity_denies`.
