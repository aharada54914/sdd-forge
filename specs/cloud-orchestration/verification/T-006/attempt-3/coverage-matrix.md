# T-006 finite acceptance and persisted-counterpart matrix

All final executions use synthetic transport responses and an AssertionError live
network prohibition; actual subtest results are in matrix-execution.json. Historical
masked Red and invalid pre-guard negative results are not execution proof.

| Required invariant / persisted fields | Actual callable tests and counterparts |
|---|---|
| Six native checks: healthy, unhealthy, denied, missing; signal staleness | NativeCollectorCases + PublicObservationCases.test_public_all_checks_matrix_native_protocol_fixtures; actual EC2/IAM/CloudWatch/Backup and ARM parsing, then public cloud.run→observe→publication |
| Native IDs/scope/principal and unavailable/unknown/tampered/incomplete results | NativeAdversarialCases.test_native_response_binding_pagination_and_unknown; AzureClosureAndDcrCases; AzureMetricContextCases; AwsObservationOrchestration membership/current-operation tests; AzureResourceBindingCases |
| Same-principal direct assignment/definition scope closure, conditional/group/wildcard/data/NotActions/ID/pagination/denied/empty/caller mismatch and drift | AzureClosureAndDcrCases executes every mismatch under both injected and actual native-class mocked I/O, with an independent fixture policy and supported positive control |
| DCR identity/location/Linux/provisioning/source/counter/interval/stream/workspace/flow/transform/denial/missing/pagination | AzureClosureAndDcrCases.test_dcr_readback_and_mismatches; DCR plus actual CPU signal, not desired IaC success |
| Native current/original operation, compiled membership and no adoption after newer operation | AwsObservationOrchestration.test_newer_or_ambiguous_stack_operation_rejected; AzureResourceBindingCases; positive original CREATE/UPDATE and immutable original request controls |
| Azure original apply run/job/step/repository/pins/time and complete metadata | AzureCompletionCases; AzureObservationOrchestration; final execution regression retains governed admission/no-op/reconcile tests |
| Native request/response digest/locator/http_status | ExpandedBindingCases.test_query_digests_are_exact_transport_bytes checks trace against captured exact native bytes; ReducerCases.test_query_trace_shape and test_native_denial_cannot_be_overridden_by_healthy_label |
| Context schema/request/run/unit/provider/each scope and each lock/policy/profile subfield | ReducerCases.test_each_context_counterpart_mismatch + ExpandedBindingCases.test_nested_context_fields_and_untrusted_native_labels; original request/profile byte hashes remain independently checked |
| Observation schema/run/unit/provider/native ID/resources/principal/query/time/classification/result ref/status/exit | ReducerCases.test_each_observation_counterpart_mismatch, test_each_payload_counterpart_mismatch, test_check_fail_block_unknown_stale_missing_tampered; all checks have actual per-field mismatch executions |
| Timestamp lower/upper/freshness/order and exact selected minute window | FreshnessCases; NativeAdversarialCases; lease before and after each native read in ExpandedBindingCases.test_every_check_lease_expiry_during_native_response; final-publication expiry test |
| Within-bucket and across-bucket workload health | WorkloadRangeCases: native Minimum+Maximum [1,1] positive, [0,1]/[1,2]/[0,2] unhealthy; FreshnessCases mixed points/stale/future controls |
| Required backup versus profile/policy-optional backup, post-completion discovery and recovery state | NativeCollectorCases optional/required and discovery cases; actual native unhealthy/denied/stale/missing/tampered cases; unknown status blocks |
| Verification schema/run/unit/provider/profile/required-checks/check refs/result/completeness | ReducerCases and public emitted schema test; synthetic all-check PASS never yields public production evidence completeness |
| Evidence manifest request/context/observations/results/verification/provenance/classification; public result input/evidence refs | PublicObservationCases.test_publication_bindings_scan_no_overwrite_escape_and_secret_redaction joins all exact-byte refs and original request; fake-native labels are ignored |
| Every emitted contract field, nested path/hash, query, check and enum schema counterpart | PublicObservationCases.test_all_emitted_required_fields_have_closed_schema_counterparts recursively removes each emitted field and adds unknown fields, against actual independent JSON schemas; optional envelope native ID explicitly excepted for genuine no-op contract |
| Secret scan required, scanner unavailable/false, exact raw native bytes restricted, no overwrite/symlink escape, request drift | PublicObservationCases publication tests and final contracts regression; literal synthetic secret marker assembled at runtime, only digest/locators published |
| CLI trusted collector admission, changed run/unit/scope/profile and credential/principal denial | EntryPreflight actual child CLI entry with live-I/O guard; PublicObservationCases.test_public_request_and_trusted_policy_counterparts; actual public cloud.run uses existing trusted executor, not saved JSON |
| Guard sensitivity | Final rollback.json and sensitivity logs: 20 scoped mutations, each with assertion failure (no missing imports/setup accepted); shared guards cover related fields without redundant Cartesian inflation |

Resource/network/identity configuration is sampled by fresh synchronous native
reads; there is no invented provider sample timestamp for those configuration
objects. Their stale-read branch is credential lease expiry. Metrics/recovery
have actual provider timestamps and are tested against the post-completion window.

TEST-003/005/009 live acceptance remains BLOCKED by OQ-001: owner scope, federation,
health/backup, images, bootstrap, budget and retention are not supplied. No
independent reviewer or quality gate ran in this attempt. Full repository suite,
release, tags, pushes, merges and registry/dependency scheduling remain root-owned.
