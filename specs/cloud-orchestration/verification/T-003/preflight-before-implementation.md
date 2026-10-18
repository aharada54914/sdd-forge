# Implementation Report: T-003

- Task ID: T-003
Run ID: 01a14d65-83d0-76c1-b3a1-d40ee5e2079c
Task Attempt Count: 1
- **Run ID**: 01a14d65-83d0-76c1-b3a1-d40ee5e2079c
- **Session ID**: 01a14d65-83d0-76c1-b3a1-d40ee5e2079c
- **Scratch Root**: /tmp/cloud-T-003-01a14d65
- Agent Instance ID: 01a14d65-83d0-76c1-b3a1-d40ee5e2079c
- Provider / model / effort / tier: openai / gpt-6-astra / high / strong
- Isolation: fresh-agent; identity supplied by caller, not inherited environment
spec_revision: 31f5a76f5902e2d4361d89bb42c106fe2839dd0a9aa0dd9eb6f28822c7ec6922
Input manifest: `specs/cloud-orchestration/verification/T-003/task-input-manifest.json`, SHA-256 `2b933b0f6b1255c40d63e933a5a184385c5a2063437838b25ffa8a8131f8071e`.

## Pre-implementation high-risk preflight

Executed `python3 -B tests/cloud-orchestration-execution.tests.py`: exit 1,
15 failures because the new admission module is absent (`red.log`). These are
new admission tests, not retroactive Red for T-002 or #423 candidate work.
Baseline `python3 -B tests/cloud-orchestration-contracts.tests.py`: exit 0,
23 tests. Snapshot manifest validator: exit 0, TASK_INPUT_OK. Tests and this
preflight are committed before any admission implementation.

| Persisted field / claim | Counterpart | Executed failing mismatch test (Red) |
|---|---|---|
| receipt schema, run_id, unit_id, provider, operation | T-002 receipt schema and immutable request | test_native_positive_both_stages_providers_and_receipt_contract; test_manifest_and_scope_rebinding_never_matches_authenticated_dispatch |
| scope.account_id, scope.region, scope.deployment_scope | trusted external target policy and native account/subscription | test_manifest_and_scope_rebinding_never_matches_authenticated_dispatch; test_provider_identity_and_lease_mismatch_before_each_stage |
| request, dependency_lock, policy, verification_profile, preview path/digests | T-002 verify_binding and authenticated run display_title binding request/preview hashes | test_manifest_and_scope_rebinding_never_matches_authenticated_dispatch; test_native_positive_both_stages_providers_and_receipt_contract |
| issuer, subject, principal | TLS-authenticated GitHub OIDC endpoint response, provider exchange and native identity | test_each_authenticated_oidc_binding_mismatch_denies; test_provider_identity_and_lease_mismatch_before_each_stage |
| ci.repository, workflow, workflow_revision, ref, environment, run_id, run_attempt | authenticated OIDC claims, GitHub run/environment and fixed trusted policy | test_each_authenticated_oidc_binding_mismatch_denies; test_each_authenticated_run_binding_mismatch_denies; test_environment_policy_and_missing_api_data_fail_closed |
| issued_at, expires_at | authenticated OIDC/provider credential lease and stricter policy TTL; never review timestamp | test_each_authenticated_oidc_binding_mismatch_denies; test_provider_identity_and_lease_mismatch_before_each_stage; test_native_positive_both_stages_providers_and_receipt_contract |
| approval_evidence.locator, sha256 | exact authenticated REST approvals bytes and allowed reviewer/environment IDs | test_absent_revoked_denied_unknown_duplicate_approval_history; test_native_positive_both_stages_providers_and_receipt_contract |
| immutable receipt publication and replay denial / REQ-006 admission claim | T-002 exclusive publication, one trusted job, workflow first-attempt rule | test_replay_different_instance_tamper_and_unknown_submission_no_retry; test_timeout_is_not_retried_and_receipt_is_retained |
| zero-write denial / REQ-005, TEST-005 | submit callback count at common boundary | all denial tests, test_local_flags_receipts_and_missing_runtime_never_authorize |
| canonical conservative concurrency / TEST-006 admission | account/subscription-region templates; external exclusive-writer prerequisite | test_concurrency_key_conservative_canonical_and_scope_prerequisite; test_templates_have_distinct_environments_roles_and_no_cancellation |

No cloud result envelope, VERIFIED verdict, task-state or traceability status
is persisted by this task. Runtime receipts use the existing closed schema.
No raw supplied receipts/tokens or reviewer reports are task inputs/evidence.
All fixture credential values are synthetic. Native Windows and live IAM
remain unverified; no unsafe filesystem fallback is planned.

## Boundary plan

Choose `WriteBoundary.write(..., mutation_id, submit, scan)` as the callable
pre-mutation boundary, rather than a boolean approval helper or generic cloud
engine. Trusted provider adapters supply fixed mutation callbacks and stable
mutation IDs. Every call freshly authenticates CI and native identity, checks
all bound bytes and publishes an exclusive receipt before invoking submit once.
No receipt-import/approved flag API. T-010 integrates dependency admission here;
until then nonempty predecessor lists deny. Local receipt exclusion is only
job-local replay protection, not cloud serialization or external durable auth.
Trusted workflow code/policy and native OIDC/IAM remain the external authority.

## Outputs

| Path | SHA-256 |
|---|---|
| tests/cloud-orchestration-execution.tests.py | 1b193e7bf4f79a878313e7bf0b8f2cc0b2750949d982b8f6642bd1de18c04120 |
| specs/cloud-orchestration/verification/T-003/red.log | edb139e7841e2d2ee4a9f5037b8125116a77fecc4705e5b6cc428115133f434b |

## Session Handoff

Preflight only; implementation not yet started. Independent review and final
quality decision belong to the root orchestrator. No task status edited.
