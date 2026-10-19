# Cycle1-fix persisted-field/counterpart preflight

Scope: RT015/RT016 workflow integration and regression tests only. RT017 is caller-owned review admission. P/C/R/W, catalog/helper/schemas and frozen primary V2 are protected. No wire fields or schemas are added; the full previously persisted-field table is retained below from the admitted frozen V2 for unchanged producer/consumer contracts. These new rows identify every affected upload/dispatch/identity transport and new fix evidence. Negative tests succeed only by rejecting the mismatch.

| Persisted field | Independent counterpart | Failing mismatch test |
|---|---|---|
| `upload.if` | Exactly the current row’s declared receipt producer and selected bounded condition; independent of prior assertion failure | `WorkflowIntegrationTests.test_RT015_every_upload_row_matches_selected_receipt_producers` |
| `upload.with.if-no-files-found` | error whenever a required selected producer has no receipt | `WorkflowIntegrationTests.test_RT015_missing_required_receipt_and_hidden_upload_mutations_fail` |
| `upload.with.name` | Same original run/attempt/expanded-job hash; unchanged by this fix | `test_T003_every_existing_runner_persists_a_receipt_and_uploads_it; test_T003_actual_receipt_identity_body_matches_collector` |
| `upload.with.path` | Same producer receipt path pattern; no source or outcome inference from merely existing files | `test_RT015_missing_required_receipt_and_hidden_upload_mutations_fail (stale-file nonproducer fixtures)` |
| `upload producer job/matrix/runner` | Actual W-expanded receipt_required obligations and matching selected run steps: six jobs,16 rows,14 full producers | `test_RT015_every_upload_row_matches_selected_receipt_producers (all rows and selected false/missing)` |
| `planner executable source path` | Capable exact trusted base for modern PR; existing accepted bootstrap for absent or historical shadow-only base | `WorkflowPlanIntegrationTests.test_RT016_present_released_shadow_planner_uses_full_adoption_fallback; test_T003_actual_first_adoption_without_base_planner_stays_full` |
| `planner capability decision` | Accepted P policy: verification-ci-plan/v1 and def plan_main( markers, with P retaining source/revision validation | `test_RT016_present_released_shadow_planner_uses_full_adoption_fallback (actual released SHA325aa985...)` |
| `plan.mode` | FULL for first adoption and conservative non-PR/force-full cases | `test_RT016_present_released_shadow_planner_uses_full_adoption_fallback; existing three T003 actual planner methods` |
| `plan.reason` | base-planner-unavailable for actual shadow/absent base, event-full/force-full for corresponding contexts | `same actual planner methods; WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.api_head_sha` | Exact PR head, even when tested revision is a distinct synthetic merge | `test_RT016_actual_pr_body_binds_api_head_and_distinct_tested_merge` |
| `plan.tested_revision` | Actual checkout HEAD and distinct tested merge SHA | `test_RT016_actual_pr_body_binds_api_head_and_distinct_tested_merge` |
| `plan.base_revision` | Exact trusted base checkout source and API base input | `test_RT016_actual_pr_body_binds_api_head_and_distinct_tested_merge; historical shadow fixture` |
| `plan.pr_head_revision` | Exact PR commit rather than tested merge commit | `test_RT016_actual_pr_body_binds_api_head_and_distinct_tested_merge` |
| `plan.workflow_sha256 / obligation.command_sha256` | Accepted P recomputation of changed workflow/plan step; no altered schema or algorithm | `WireTests.test_every_persisted_field_matches_independent_counterpart; test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan artifact name/output transport` | Original run/planning attempt with all existing output keys and exact API/tested identity | `WorkflowPlanIntegrationTests.invoke_workflow retained exact output comparison` |
| `subject sentinel exit96 / absent plan output` | Reachable code before terminating __main__; forced wrong subject dispatch fails instead of publishing plan | `test_RT016_subject_origin_sentinel_detects_wrong_dispatch; sentinel-sensitivity.json independently records old exit0 vs corrected exit96` |
| `historical fixture bytes / source revision / digest` | Pinned actual git-show observation of released2aaac49c528d0dfe28437082d54fb86a32f04a15,5968bytes,SHA325aa985ddc0746c7276398235fe090700c118b7b0e088baf24e4cb944060ff3 | `Historical test asserts length/digest and lack of plan_main before execution` |
| `fix report actor/run/manifest/output hashes/test exits` | Same authorized implementation actor, pinned125-input snapshot, actual subprocess logs and unchanged product hashes | `red-executions.json and red-source-preservation.json assertions; no inference from fixture to hosted results` |

## Retained unchanged contract-field checklist

Exact table copied as evidence from frozen V2; its original chronology remains historical. Existing algorithms and counterparts are unchanged in this repair.

| Persisted field | Independent counterpart | Mismatch test/check |
|---|---|---|
| `plan.schema` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.mode` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.reason` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.event` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.run_id` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.planning_attempt` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.api_head_sha` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.tested_revision` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.base_revision` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.pr_head_revision` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.merge_base_revision` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.catalog_sha256` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.workflow_sha256` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.trusted_planner_sha256` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.plan_sha256` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.changed_path_count` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.groups` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.obligations` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.omissions` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.activation_evidence` | Accepted P recomputation from tested checkout, trusted base, event/run and exact workflow/catalog bytes | `plan: WireTests.test_every_persisted_field_matches_independent_counterpart` |
| `plan.obligations[].id` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.obligations[].job` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.obligations[].matrix` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.obligations[].runner` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.obligations[].step` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.obligations[].command_sha256` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.obligations[].suites` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.obligations[].receipt_required` | Exact independently reconstructed obligations entry | `plan: WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` |
| `plan.omissions[].id` | Exact independently reconstructed omissions entry | `plan: WireTests.test_omission_and_activation_field_pairs` |
| `plan.omissions[].reason` | Exact independently reconstructed omissions entry | `plan: WireTests.test_omission_and_activation_field_pairs` |
| `plan.activation_evidence[].category` | Exact independently reconstructed activation_evidence entry | `plan: WireTests.test_omission_and_activation_field_pairs` |
| `plan.activation_evidence[].path` | Exact independently reconstructed activation_evidence entry | `plan: WireTests.test_omission_and_activation_field_pairs` |
| `plan.activation_evidence[].sha256` | Exact independently reconstructed activation_evidence entry | `plan: WireTests.test_omission_and_activation_field_pairs` |
| `plan.activation_evidence[].rule_sha256` | Exact independently reconstructed activation_evidence entry | `plan: WireTests.test_omission_and_activation_field_pairs` |
| `plan.activation_evidence[].baseline_revision` | Exact independently reconstructed activation_evidence entry | `plan: WireTests.test_omission_and_activation_field_pairs` |
| `observations.schema` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.repository` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.run_id` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.api_head_sha` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.collected_at` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.api_version` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.run` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.run.path` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `observations.run.sha256` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `observations.jobs` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.jobs[].path` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `observations.jobs[].sha256` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `observations.artifacts` | Read-only same-repository/run API response and accepted observation schema | `ci: BoundaryTests.test_collection_field_counterparts_and_schema` |
| `observations.artifacts[].path` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `observations.artifacts[].sha256` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `observations.artifacts[].job_id` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `observations.artifacts[].source_attempt` | Contained downloaded file bytes, exact job ID and original source attempt | `ci: BoundaryTests.test_collection_field_counterparts_and_schema; AggregateTests.test_manifest_hash_and_containment_counterparts` |
| `result.schema` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.status` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.reason` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.run_id` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.api_head_sha` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.tested_revision` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.plan_sha256` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.results` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `error.schema` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `error.reason` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `error.message` | Accepted C independently validated result/error and plan/API execution evidence | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.results[].obligation_id` | Selected obligation, actual job conclusion/ID and original source attempt | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.results[].status` | Selected obligation, actual job conclusion/ID and original source attempt | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.results[].reason` | Selected obligation, actual job conclusion/ID and original source attempt | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.results[].job_id` | Selected obligation, actual job conclusion/ID and original source attempt | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `result.results[].source_attempt` | Selected obligation, actual job conclusion/ID and original source attempt | `ci: BoundaryTests.test_result_and_error_all_persisted_field_counterparts` |
| `receipt.schema` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.profile` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.revision` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.revision_after` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.clean_before` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.clean_after` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.reusable` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.catalog_sha256` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.selected` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.results` | Accepted R invocation and clean tested checkout; C exact selected-suite comparison | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.results[].suite` | Actual suite source bytes and R execution result; C validates successful required execution | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.results[].source_sha256` | Actual suite source bytes and R execution result; C validates successful required execution | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.results[].status` | Actual suite source bytes and R execution result; C validates successful required execution | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.results[].exit_code` | Actual suite source bytes and R execution result; C validates successful required execution | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.results[].seconds` | Actual suite source bytes and R execution result; C validates successful required execution | `ci: AggregateTests.test_receipt_persisted_fields_counterparts` |
| `receipt.results[].reason (optional failure diagnostics)` | R missing-runtime/process-start failure; status remains failed and C rejects failed receipt | `catalog: CatalogTests.test_missing_runtime_is_failure_unless_profile_explicitly_optional; ci: AggregateTests.test_TEST020_055_056_failure_cancel_skip_timeout_neutral` |
| `ci-plan.outputs.run_<group>` | Unique normalized declared job group and steps.plan.outputs key, lowercase true only | `catalog: WorkflowIntegrationTests.test_T003_planner_outputs_have_one_declared_producer; test_T003_unknown_plan_group_and_output_declarations_fail_closed` |
| `ci-plan.outputs.plan_artifact_name` | Original planning run/attempt artifact, passed directly to exact accepted download step | `ci: WorkflowPlanIntegrationTests.test_T003_actual_planner_body_keeps_non_pr_and_manual_full; catalog: test_T003_required_verifier_uses_accepted_prepared_shape` |
| `CI_EVENT/CI_BASE_SHA/CI_HEAD_SHA/CI_TESTED_SHA/CI_API_HEAD_SHA/CI_FORCE_FULL` | Actions event/ref fields; exact base trusted checkout; conservative force-full parse | `ci: WorkflowPlanIntegrationTests (three actual workflow-shell methods)` |
| `receipt artifact run/attempt/job-name digest` | C receipt artifact naming grammar, API expanded job name, source attempt | `catalog: test_T003_every_existing_runner_persists_a_receipt_and_uploads_it; ci: BoundaryTests.test_collection_artifact_job_name_binding_and_mismatches` |
| `workflow concurrency group/cancellation` | workflow/event/PR number; unique non-PR run ID | `catalog: test_T003_pr_number_cancellation_and_non_pr_run_groups` |
| `cache key OS/runtime/lock-or-package digest/event/PR` | Exact dependency identity; PR writes remain separate from trusted event keys, no restore fallback | `catalog: test_T003_dependency_cache_is_archive_only_pinned_and_event_scoped` |
| `cached Pester archive bytes and manifest digest` | Admitted immutable package and manifest SHA-256; validate hits before reuse | `ci: DependencyCacheIntegrationTests (six methods); isolated Claude extraction tests pending admission` |
| `catalog ci_jobs/profile integration` | Before inventory exact expanded suite argv/shell/OS multiset | `catalog: test_T003_full_suite_invocation_multiset_preserves_shell_args_and_os` |
| `A9 projection and category active/evidence` | Accepted exact two jobs/global env/defaults hash; inactive/None until T011 | `catalog: test_T003_triggers_and_unproven_categories_remain_conservative` |
| `report source hashes, test exits, inventory and claims` | Exact admitted bytes, subprocess exits and complete baseline inventory | `Recorded hash assertions in preflight-provenance.json; Red executions have actual nonzero exits; no hosted claim` |

