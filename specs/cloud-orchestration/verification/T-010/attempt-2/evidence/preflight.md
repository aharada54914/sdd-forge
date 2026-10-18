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
