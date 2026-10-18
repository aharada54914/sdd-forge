# Attempt 2 preflight, before continuation product changes

This continues implemented candidate code, not a new baseline. Original actual
Red commits cba7a7ad and f2d51e4a and first-handoff-report.md remain unchanged.
The first attempt did NOT execute every mismatch before implementation; this
chronology cannot be retroactively repaired. The following is a current guard
coverage checklist, not an invented historical Red claim. New defects must have
an executed failing assertion committed before their product repair.

| Persisted field | Counterpart | Failing-mismatch case (current guard, matched control) |
|---|---|---|
| Registry schema/profiles[].id/version/required/conditional/preflight IDs | closed configuration schema and protected_selection | Contracts.test_protected_registry_configuration_schema_and_runtime; ProfileSavedConsumers.test_registry_protection_and_old_schema_mirrors |
| Contract schema/profile/feature/task_id | explicit v3/cloud, request.local_context | ProfileSavedConsumers.test_saved_contract_each_field_and_binding_guard |
| Contract request/preview/verification path+sha256 | actual contained artifact bytes | same saved-contract matrix plus path contract suite |
| Plan schema/profile/feature/task_id/profile_ref.id/version/path/sha256 | recomputed saved_profile_plan and plan v2 schema | ProfileCompletionCases.test_every_plan_leaf_and_closed_object |
| Plan bindings.request_sha256/verification_sha256/registry_sha256 | actual request, verification and registry bytes | same leaf matrix; existing test_plan_fields_match_schema_and_recomputed_counterparts |
| Plan checks[].id/required/result/evidence.path/sha256 | protected selected IDs, fresh T006 checks, actual compiled/policy/preview/observation refs | same leaf matrix; both public paths and native protocol control |
| Plan selection_result/verdict | deterministic selection vs fresh native verification completeness | same leaf matrix; saved consumers always BLOCKED; native-class mock remains synthetic testing |
| Preview run/unit/provider/scope/request/lock/policy/profile | exact request | saved-contract matrix and bound-preview sensitivity |
| Preview changes digest/semantic digest/deletes/replacements/window | exact bytes/non-destructive preflight/completion | ProfileCompletionCases.test_preview_guard_matrix |
| Verification identity/profile/required IDs; observations identity/query | request and profile check ID | saved-contract matrix; ProfileCompletionCases.test_saved_observation_mismatch_sensitivity |
| AWS preview semantic request/scope/template/change-set/stack/no_change/create | executor.check, immutable IDs and native response | ProfileAwsReadbackCases.test_semantic_native_and_policy_guards |
| AWS native ChangeSetId/StackId/ChangeSetName/StackName/Description/Capabilities/Parameters/Status/ExecutionStatus/Tags/TemplateBody | original executed operation and exact input | same AWS matrix, guard-specific bypass sensitivity |
| AWS forbidden execution options; Changes and each resource policy field | exact preview semantics and compiled resources | same AWS matrix, matched and selective bypass controls |

No new persisted production field is planned for this continuation. Necessary
integration: explicit configuration schema inventory and sanctioned stale mirror
refresh using the existing sync tool, pending bundles untouched. No independent
review or quality verdict. Live TEST-003/005/009 remain BLOCKED.
