# Attempt 3 high-risk preflight — before product changes

Run ID: 01a14e9b-59d8-7aa1-b988-8c2551229993
Task Attempt Count: 3

Existing fields and their contract counterparts remain the following; existing
mismatch bodies are real candidate tests, not retroactive Red. Baseline: 36 PASS.
Publication entries below will be completed by this attempt's adversarial tests.

| Persisted field(s) | Counterpart / required invariant | Executable mismatch test |
|---|---|---|
| context.schema | cloud-collection-context/v1 closed shape | test_context_shape_and_window |
| context.request.path/sha256 | exact original request locator/bytes | test_each_context_counterpart_mismatch(request) |
| context.run_id/unit_id/provider | original request identity | test_each_context_counterpart_mismatch(run_id/unit_id/provider) |
| context.scope.account_id/region/deployment_scope | original request target | test_each_context_counterpart_mismatch(scope) |
| context.dependency_lock.path/sha256 | original request dependency lock | test_each_context_counterpart_mismatch(dependency_lock) |
| context.policy.path/sha256 | original request policy | test_each_context_counterpart_mismatch(policy) |
| context.verification_profile.id/version/path/sha256 | original request and strict profile exact bytes | test_each_context_counterpart_mismatch(verification_profile); test_profile_policy_and_check_set |
| context.native_operation_id | original provider execution ID, never a new operation | test_each_observation_counterpart_mismatch(native_operation_id); native collector operation cases |
| context.resource_ids | explicit configured resources and native readback IDs | test_each_observation_counterpart_mismatch(resource_ids); native collector identity cases |
| context.principal | fresh federated principal, bound to native transport | test_each_observation_counterpart_mismatch(principal); native collector principal cases |
| context.completed_at/collected_at/classification | native completion and fresh collection window; transport provenance | test_context_shape_and_window; test_all_checks_synthetic_never_complete |
| observation.schema | strict cloud-observation/v1 | test_each_observation_counterpart_mismatch; shared contract regressions |
| observation.run_id/unit_id/provider/native_operation_id/resource_ids/principal/classification | collection context, not caller assertions | test_each_observation_counterpart_mismatch |
| observation.query | selected profile check_id / fixed collector check | test_each_observation_counterpart_mismatch(query) |
| observation.timestamp | context.collected_at | test_each_observation_counterpart_mismatch(timestamp) |
| observation.exit_code/status | actual collection outcome and payload status | test_each_observation_counterpart_mismatch(exit_code/status) |
| observation.result.path/sha256 | exact redacted payload bytes and canonical contained locator | test_each_observation_counterpart_mismatch(result); test_check_fail_block_unknown_stale_missing_tampered |
| result.schema/context_sha256/check_id/status | closed check-result schema; exact context digest, selected check and observation outcome | test_each_payload_counterpart_mismatch |
| result.reason/sampled_at | fixed reason enum; actual native signal/check time in profile post-completion/freshness window | test_check_fail_block_unknown_stale_missing_tampered; test_context_shape_and_window |
| result.queries[].locator/request_sha256/response_sha256/http_status | fixed read-only request and exact native response digest/status; raw body is not published | test_query_trace_shape; native wire transport cases |
| verification.schema/run_id/unit_id/provider/profile/required_check_ids | cloud-verification/v1 and original request/profile | test_profile_policy_and_check_set; test_all_checks_synthetic_never_complete |
| verification.checks[].check_id/observation.path/sha256/result | exact collected observation bytes and evaluated status | test_check_fail_block_unknown_stale_missing_tampered |
| verification.overall_result/evidence_complete | all mandatory checks, freshness, trusted collection, no synthetic completion | test_all_checks_synthetic_never_complete; test_check_fail_block_unknown_stale_missing_tampered |
| evidence manifest context/request/observation refs/verification ref/classification | original immutable request, exact collection context/bytes and verdict | publication binding tests |
| operation envelope schema/run_id/unit_id/provider/operation/state/result/error_code/message/input_manifest_sha256/evidence_manifest_path/native_operation_id | cloud-operation-result/v1; canonical verification and collection manifest | native CLI publication tests; related execution/routing suites |

## Corrective fields / native counterpart / actual failing test

| Persisted field | Counterpart | Failing mismatch test |
|---|---|---|
| identity payload.status/reason, observation.status/exit_code, verification checks/result/completeness | Complete assignedTo subscription assignment closure; bound scope/principal/role definitions and actual same-principal permissions | AzureClosureAndDcrCases.test_permission_closure_mismatches: injected transport principal/group/scope/condition/wildcard/data/notActions/role-ID/assignment-ID/pagination/denied/empty/caller-disagrees/drift variants |
| identity queries[].locator/request_sha256/response_sha256/http_status and context.principal | Fixed native assignedTo and roleDefinition reads, strict 200/complete/bounded response; actual workload identity | Same mismatch test, plus test_native_positive_permission_closure_protocol |
| monitoring payload.status/reason, observation.status/exit_code, verification checks/result/completeness | Actual DCR identity/location/kind/provisioning/source/counter/interval/stream/destination/flow and received signal | AzureClosureAndDcrCases.test_dcr_readback_and_mismatches |
| monitoring queries[] and provider_config digest | Explicit workspace resource ID (closed config), fixed supported Linux CPU DCR, native GET exact response bytes | DCR mismatch test, executable schema/config cases before contract extension |

Actual Red in red-closure-dcr.log: 3 tests, 29 failed subtests and one error.
The existing injected identity path accepts mismatched closure responses (never
queries them) and DCR path never reads the DCR. These execute the existing callable
collector boundary; they do NOT establish that the new closure/DCR mismatch guards
already executed. Native positive fails the deliberate quarantine. Native negative
variants are currently masked by that quarantine, not proof of replacement guards.
After implementation both native-class mocked I/O and synthetic transports must
execute each body, with a positive control and targeted guard-removal sensitivity.
No live/native production evidence follows from these protocol fixtures.

## Current/original operation and metric context correction (before product edits)

context.native_operation_id/resource_ids and observation counterparts join the
original operation, not a later operation's current resource selector. Actual
native current stack history / complete Azure resource-group deployment list
must still identify the original as latest with no active/ambiguous competitor.
AwsObservationOrchestration.test_newer_or_ambiguous_stack_operation_rejected and
AzureResourceBindingCases.test_compiled_and_original_operation_membership feed
newer/ambiguous/active/paginated/denied native responses to existing observe/bind
boundaries. The root probe is synthetic and does not establish a public native
exploit. AzureMetricContextCases.test_metric_context_counterparts mismatches
actual metric ID/namespace/region/interval/window and duplicate dimensions against
the fixed query/configuration (payload status/trace and verification counterparts).
The first explicit-workspace config Red fails admission (44 errors), not DCR guard
execution; subsequent green-closure-dcr.log executes all closure/DCR guard bodies.

## Unknown-state and final lease preflight

NativeAdversarialCases feeds unknown EC2 state/Backup status and Azure power/
backup status to actual collector methods. Counterparts are native documented
enums versus result.status/reason, observation.status/exit_code, and verification
checks/overall_result. Unknown must BLOCK, not classify as a real unhealthy FAIL.
Its postcollection expiry case expires the actual read lease during recovery
readback; final recheck/publication must not publish a stale authenticated result.
red-unknown-expiry.log: four executed unknown-state assertion failures plus one
Azure postcollection publication failure (AWS already blocks before publication).
Public matrix first failure was fixture targeting: Azure unhealthy changed VM
provisioning state but the scoped injection targeted instanceView only; repaired
fixture now supplies actual stopped power state. It is not a product Red.

## Within-bucket workload range preflight

Root's static range concern is confirmed by executed WorkloadRangeCases. Persisted
workload status/query digest/sample and verification result must agree with both
configured minimum and maximum versus actual native bucket Minimum/Maximum.
red-workload-range.log feeds a real collector bucket with minimum=0, maximum=1
against required [1,1]; both providers accept it before correction. Query-shape
assertions additionally expose absent requested Minimum. Matched [1,1] and high/
mixed unhealthy controls are included. This is synthetic protocol Red, not live.
