# T-003 pre-product field/counterpart preflight

Actor: work-agent:root:t003_implementation. This is local protocol and test evidence, not hosted acceptance. Existing P/C/R algorithms and schemas remain accepted and unchanged. Tests named `plan` are in tests/verification-ci-plan.tests.py; `ci` in tests/verification-ci.tests.py; `catalog` in tests/verification-catalog.tests.py. Existing negative tests succeed only when the mismatched input is rejected; new feature tests currently fail against the unintegrated workflow. The optional receipt diagnostic is informational and cannot turn failure into success. No activation proofs are newly emitted because all live categories remain inactive.

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

Pre-product chronology: product editing remains prohibited until Root inspects and commits the real Red checkpoint. The isolated Claude test draft requires separate pinned admission before reuse. Exact source preservation is recorded separately.
