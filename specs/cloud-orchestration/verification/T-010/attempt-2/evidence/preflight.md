# WFI-001 pre-implementation checklist

Run/session/agent: 01a14f3e-b525-78c0-9d78-d79635e2a5de. Attempt 2.
Chronology follows caller-preflight-clarification.md, not attempt-1's stronger
positive-control constraint. No production edit yet. Existing 78-test baseline
passes (one existing optional schema-tool SKIP). New tests generate actual T009
in-process collector/profile output through synthetic native-class transports,
then feed valid-format mismatches to the existing WriteBoundary.write callable.
The current blanket DEPENDENCY_ADMISSION_REQUIRED denial is the actual Red
failure point, NOT executed new field-sensitive validation. Setup/syntax failures
in red-initial/red-setup logs are retained and are not behavioral Red.

No new receipt wire schema is needed. Consume existing cloud contracts unchanged.
The proposed protected Policy configuration is data owned by the external
executor, never by a deployment bundle. Its exact request pin binds the entire
consumer request, including its predecessor set. Empty default preserves behavior.

| Persisted field or acceptance claim | Counterpart | Pre-implementation mismatch test / actual boundary |
|---|---|---|
| receipt path, sha256, unit_id | consumer predecessor ref; authenticated downloaded verification | DependencyReceiptCases per-field unit_id; current blanket denial. Existing integrity path/digest checks remain in verify_binding and attempt-1 probe. |
| run_id, unit_id, provider, scope account_id/region/deployment_scope | exact externally pinned predecessor request | per_field_red_mismatches run_id/unit_id/provider/scope; blanket denial |
| request path/sha256; dependency lock, policy and input artifacts; source revision, local context | protected original request bytes and transitively bound files | producer_and_evidence_red_mismatches context/observation/payload; blanket denial; baseline ReducerCases executes context counterpart mismatches independently |
| profile id/version/path/sha256, required check IDs, registry digest | protected cloud-compute v2; original request; selected plan v2 | per_field_red_mismatches profile; producer_and_evidence_red_mismatches plan; blanket denial |
| repository/id, workflow/ref/revision/digest, executor repository/revision | authenticated original run and pinned reviewed workflow/code | per_field_red_mismatches repository_id/workflow_sha256/executor_revision/producer_run_id; blanket denial |
| producer run/attempt/event/status/conclusion/head/title; verify job/steps/status/conclusion/times | authenticated GitHub original verify run/job; exact request/preview | producer_and_evidence_red_mismatches run/job; blanket denial |
| environment/id, reviewers/actors and approval history | external protected environment configuration and authenticated GitHub data | per_field_red_mismatches environment_id; blanket denial |
| artifact ID/digest/name/workflow_run/expired | immutable authenticated GitHub artifact and exact protected verify run | producer_and_evidence_red_mismatches artifact; blanket denial (no artifact fetch at old seam) |
| observation manifest request/context/observations/verification refs, classification, provenance, saved_receipt_authorizes_nothing | exact protected producer artifact; fresh in-process collector output | producer_and_evidence_red_mismatches classification/context/observation/payload; blanket denial |
| context request/run/unit/provider/scope/lock/policy/profile, principal/native_operation_id/resource_ids/classification/completed_at/collected_at | original request and authenticated collector manifest; reducer context contract | context mismatch; blanket denial; baseline ReducerCases context matrix executes existing reducer guards |
| observation run/unit/provider/native_operation_id/resource_ids/principal/classification/query/timestamp/exit_code/status/result | context, selected checks and payload bytes | observation mismatch; blanket denial; baseline ReducerCases observation matrix executes existing reducer guards |
| payload schema/context_sha256/check_id/status/reason/sampled_at/queries locator/request+response digests/http_status | context/observation/schema and freshness policy | payload mismatch; blanket denial; baseline ReducerCases payload matrix executes existing reducer guards |
| verification profile/checks/overall_result/evidence_complete | recomputed fresh reduction and protected profile | verification mismatch; blanket denial |
| contract v3 feature/task/request/preview/verification; plan v2 schema/profile/feature/task/profile_ref/bindings/checks/selection_result/verdict | recomputed protected selection and verified output (saved consumer remains BLOCKED) | plan mismatch; blanket denial; baseline T009 plan/contract negative tests execute existing saved consumer |
| operation schema/run/unit/provider/operation/state/result/error_code/input_manifest_sha256/evidence_manifest_path/native_operation_id | original request, context, authenticated verification | operation mismatch; blanket denial |
| freshness and collection/completion window | protected profile max_age_seconds; authenticated verify step completion | stale mismatch; blanket denial |
| graph units/edges/order, aggregate and blocked transitive dependents | unique units; no self/missing/duplicate/cyclic edges; verified independent results | new ordering helper absent; no graph guard execution claimed. Add helper tests before its implementation; graph return is in-process, no new persisted wire contract. |
| A receipt bytes unchanged; B fails; C zero native prepare/apply | three real adapter/dispatcher units | mandatory integration test pending after seam; no pre-existing acceptance claimed |
| UNKNOWN original operation identity, no blind replay | provider original operation journals and read-only reconcile | existing execution tests; new scheduler integration pending |
| each shared boundary revalidates; local flags cannot skip | first and immediate pre-submit dependency checks; exact consumer request pin | matched-control test currently denied at blanket seam; after implementation exercise revocation between calls and during scan |

All new field guards require matched successful controls and sensitivity after
implementation. This table does not backdate those results. No live cloud or
credentials are used; urllib OpenerDirector.open is denied by an exercised suite
sentinel. No cloud authorization is created by this report or protocol fixtures.

## Per-field expansion before product edits

Earlier red.log/red-boundary.log included setup failures (missing referenced observation/profile, profile collision, and absent AWS verify template), not completed preflight. Corrected fixture copies all required immutable evidence and separates the consumer profile. red-per-field.log now reaches the actual blanket seam for every configured mismatch; four matched controls reach WRITE_ADMISSION_BLOCKED at DEPENDENCY_ADMISSION_REQUIRED. Removing the predecessor list currently admits one synthetic callback despite the configured expected set: a genuine failing behavioral assertion, not missing setup. Graph tests fail component-absence assertions separately.

| Exact field | Counterpart guard to implement | Executed mismatch case |
|---|---|---|
| `pin.unit_id` | `DEPENDENCY_SET_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.unit_id` |
| `pin.verification.path` | `DEPENDENCY_SET_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.verification.path` |
| `pin.verification.sha256` | `DEPENDENCY_SET_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.verification.sha256` |
| `pin.run_id` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.run_id` |
| `pin.provider` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.provider` |
| `pin.scope.account_id` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.scope.account_id` |
| `pin.scope.region` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.scope.region` |
| `pin.scope.deployment_scope` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.scope.deployment_scope` |
| `pin.profile.id` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.profile.id` |
| `pin.profile.version` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.profile.version` |
| `pin.profile.path` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.profile.path` |
| `pin.profile.sha256` | `DEPENDENCY_REQUEST_BINDING` | `test_every_new_trust_and_producer_binding`, `pin.profile.sha256` |
| `pin.request.path` | `UNSAFE_OR_UNAVAILABLE_FILE` | `test_every_new_trust_and_producer_binding`, `pin.request.path` |
| `pin.request.sha256` | `DIGEST_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.request.sha256` |
| `pin.repository` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.repository` |
| `pin.repository_id` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.repository_id` |
| `pin.workflow` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.workflow` |
| `pin.workflow_revision` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.workflow_revision` |
| `pin.ref` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.ref` |
| `pin.producer_run_id` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.producer_run_id` |
| `pin.actors.0.0` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.actors.0.0` |
| `pin.actors.0.1` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.actors.0.1` |
| `pin.workflow_sha256` | `DEPENDENCY_WORKFLOW_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.workflow_sha256` |
| `pin.executor_repository` | `DEPENDENCY_EXECUTOR_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.executor_repository` |
| `pin.executor_revision` | `DEPENDENCY_EXECUTOR_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.executor_revision` |
| `pin.artifact_id` | `ARTIFACT_IDENTITY_CHANGED` | `test_every_new_trust_and_producer_binding`, `pin.artifact_id` |
| `pin.environment_id` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.environment_id` |
| `pin.reviewers.0.0` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.reviewers.0.0` |
| `pin.reviewers.0.1` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `pin.reviewers.0.1` |
| `run.id` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.id` |
| `run.run_attempt` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.run_attempt` |
| `run.status` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.status` |
| `run.conclusion` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.conclusion` |
| `run.event` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.event` |
| `run.head_sha` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.head_sha` |
| `run.head_branch` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.head_branch` |
| `run.path` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.path` |
| `run.display_title` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.display_title` |
| `run.repository.id` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.repository.id` |
| `run.repository.full_name` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.repository.full_name` |
| `run.head_repository.id` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.head_repository.id` |
| `run.head_repository.full_name` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.head_repository.full_name` |
| `run.actor.id` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.actor.id` |
| `run.actor.login` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.actor.login` |
| `run.triggering_actor.id` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.triggering_actor.id` |
| `run.triggering_actor.login` | `DEPENDENCY_RUN_MISMATCH` | `test_every_new_trust_and_producer_binding`, `run.triggering_actor.login` |
| `file.type` | `DEPENDENCY_WORKFLOW_MISMATCH` | `test_every_new_trust_and_producer_binding`, `file.type` |
| `file.path` | `DEPENDENCY_WORKFLOW_MISMATCH` | `test_every_new_trust_and_producer_binding`, `file.path` |
| `file.encoding` | `DEPENDENCY_WORKFLOW_MISMATCH` | `test_every_new_trust_and_producer_binding`, `file.encoding` |
| `file.content` | `DEPENDENCY_WORKFLOW_MISMATCH` | `test_every_new_trust_and_producer_binding`, `file.content` |
| `job.id` | `DEPENDENCY_VERIFY_JOB_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.id` |
| `job.name` | `DEPENDENCY_VERIFY_JOB_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.name` |
| `job.run_id` | `DEPENDENCY_VERIFY_JOB_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.run_id` |
| `job.run_attempt` | `DEPENDENCY_VERIFY_JOB_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.run_attempt` |
| `job.head_sha` | `DEPENDENCY_VERIFY_JOB_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.head_sha` |
| `job.status` | `DEPENDENCY_VERIFY_JOB_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.status` |
| `job.conclusion` | `DEPENDENCY_VERIFY_JOB_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.conclusion` |
| `jobs.total_count` | `PAGINATION_INCOMPLETE` | `test_every_new_trust_and_producer_binding`, `jobs.total_count` |
| `job.started_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.started_at` |
| `job.completed_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.completed_at` |
| `job.steps.0.name` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.0.name` |
| `job.steps.0.status` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.0.status` |
| `job.steps.0.conclusion` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.0.conclusion` |
| `job.steps.0.started_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.steps.0.started_at` |
| `job.steps.0.completed_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.steps.0.completed_at` |
| `job.steps.1.name` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.1.name` |
| `job.steps.1.status` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.1.status` |
| `job.steps.1.conclusion` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.1.conclusion` |
| `job.steps.1.started_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.steps.1.started_at` |
| `job.steps.1.completed_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.steps.1.completed_at` |
| `job.steps.2.name` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.2.name` |
| `job.steps.2.status` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.2.status` |
| `job.steps.2.conclusion` | `DEPENDENCY_VERIFY_STEP_REQUIRED` | `test_every_new_trust_and_producer_binding`, `job.steps.2.conclusion` |
| `job.steps.2.started_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.steps.2.started_at` |
| `job.steps.2.completed_at` | `DEPENDENCY_COMPLETION_WINDOW` | `test_every_new_trust_and_producer_binding`, `job.steps.2.completed_at` |
| `environment.id` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.id` |
| `environment.name` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.name` |
| `environment.can_admins_bypass` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.can_admins_bypass` |
| `environment.deployment_branch_policy.protected_branches` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.deployment_branch_policy.protected_branches` |
| `environment.deployment_branch_policy.custom_branch_policies` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.deployment_branch_policy.custom_branch_policies` |
| `environment.protection_rules.0.type` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.protection_rules.0.type` |
| `environment.protection_rules.0.prevent_self_review` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.protection_rules.0.prevent_self_review` |
| `environment.protection_rules.0.reviewers.0.type` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.protection_rules.0.reviewers.0.type` |
| `environment.protection_rules.0.reviewers.0.reviewer.id` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.protection_rules.0.reviewers.0.reviewer.id` |
| `environment.protection_rules.0.reviewers.0.reviewer.login` | `DEPENDENCY_ENVIRONMENT_MISMATCH` | `test_every_new_trust_and_producer_binding`, `environment.protection_rules.0.reviewers.0.reviewer.login` |
| `approvals.0.state` | `DEPENDENCY_APPROVAL_MISMATCH` | `test_every_new_trust_and_producer_binding`, `approvals.0.state` |
| `approvals.0.user.id` | `DEPENDENCY_APPROVAL_MISMATCH` | `test_every_new_trust_and_producer_binding`, `approvals.0.user.id` |
| `approvals.0.user.login` | `DEPENDENCY_APPROVAL_MISMATCH` | `test_every_new_trust_and_producer_binding`, `approvals.0.user.login` |
| `approvals.0.environments.0.id` | `DEPENDENCY_APPROVAL_MISMATCH` | `test_every_new_trust_and_producer_binding`, `approvals.0.environments.0.id` |
| `approvals.0.environments.0.name` | `DEPENDENCY_APPROVAL_MISMATCH` | `test_every_new_trust_and_producer_binding`, `approvals.0.environments.0.name` |
| `metadata.id` | `ARTIFACT_IDENTITY_CHANGED` | `test_every_new_trust_and_producer_binding`, `metadata.id` |
| `metadata.expired` | `ARTIFACT_IDENTITY_CHANGED` | `test_every_new_trust_and_producer_binding`, `metadata.expired` |
| `metadata.workflow_run.id` | `ARTIFACT_IDENTITY_CHANGED` | `test_every_new_trust_and_producer_binding`, `metadata.workflow_run.id` |
| `metadata.digest` | `ARTIFACT_DIGEST_REQUIRED` | `test_every_new_trust_and_producer_binding`, `metadata.digest` |
| `metadata.digest` | `ARTIFACT_DIGEST_MISMATCH` | `test_every_new_trust_and_producer_binding`, `metadata.digest` |
| `metadata.name` | `DEPENDENCY_ARTIFACT_PRODUCER_MISMATCH` | `test_every_new_trust_and_producer_binding`, `metadata.name` |
| `metadata.workflow_run.head_sha` | `DEPENDENCY_ARTIFACT_PRODUCER_MISMATCH` | `test_every_new_trust_and_producer_binding`, `metadata.workflow_run.head_sha` |
| `metadata.workflow_run.repository_id` | `DEPENDENCY_ARTIFACT_PRODUCER_MISMATCH` | `test_every_new_trust_and_producer_binding`, `metadata.workflow_run.repository_id` |
| `metadata.workflow_run.head_repository_id` | `DEPENDENCY_ARTIFACT_PRODUCER_MISMATCH` | `test_every_new_trust_and_producer_binding`, `metadata.workflow_run.head_repository_id` |

Consumer configuration: `dependency_request_sha256` versus current request SHA (`request-sha`); configured `predecessor_trust` versus actual request predecessor receipts (`trust-omitted`, `trust-added`); omitted/added consumer predecessors invalidate the entire request pin (`receipt-omitted`, `receipt-added`). Exact cases: `test_consumer_request_and_trust_set`.

Unchanged reducer field reuse is **not** a claim of cross-run authentication: `ReducerCases.test_each_context_counterpart_mismatch` independently mutates request, run_id, unit_id, provider, scope, dependency_lock, policy, verification_profile. `test_each_observation_counterpart_mismatch` independently mutates run_id, unit_id, provider, native_operation_id, resource_ids, principal, timestamp, query, classification, result, status, exit_code. `test_each_payload_counterpart_mismatch` independently mutates context_sha256, check_id, status with a rehashed observation reference. `test_context_shape_and_window` covers context unknown/missing shape and future/reversed collection window. `test_query_trace_shape` covers query locator, request_sha256, response_sha256, http_status and unknown fields. `test_check_fail_block_unknown_stale_missing_tampered` covers required missing/duplicate check, stale sampled_at, FAIL/BLOCKED/UNKNOWN and raw payload tamper. `ExpandedBindingCases.test_nested_context_fields_and_untrusted_native_labels` covers nested request/scope/lock/policy/profile values and trusted-native denial. All ran in baseline.log; their unchanged implementations are reused after authenticated acquisition, not overridden. T009 `ProfileCompletionCases.test_every_plan_leaf_and_closed_object` and `ProfileSavedConsumers.test_saved_contract_each_field_and_binding_guard` enumerate saved contract/plan fields; their deliberate saved-file BLOCKED decision remains unchanged.

Owner wiring discovered before production: AWS generator currently lacks verify job although governed CLI accepts verify; Azure generated sandbox-verify cannot pass the current apply-only policy suffix check. Minimal explicit read-only verify policy wiring is needed; WriteBoundary must explicitly reject that read-only environment. The AWS fixture's desired verify job is test-first synthetic shape, not falsely attributed to the current generator.
