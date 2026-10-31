# Issue #423 T-002 formal NEEDS_WORK follow-up — 2026-10-07

This is a non-frozen verification note, not a quality-gate verdict or an amendment to the existing formal evaluator output. The evaluator session `4e434839-9c1a-4bd9-b63a-e2392111afd3` remains **NEEDS_WORK**. No reservation, task-state change, source edit, or old report rewrite was made here.

## Ownership and scope

- Owner checkout: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`; HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`, with pre-existing dirty changes retained.
- Another active contributor confirmed work only on an A7 checkout note, with no overlap in #423 verification paths.
- T-002 is Approved / Implementation Complete, Risk medium; its four Done When items are ownership boundaries, Provider neutrality, ci-mcp read-only behavior, and mismatch fixtures (`specs/sdd-domain-multitarget/tasks.md`). This check supplies only the focused missing test evidence for formal finding Major 1.

## Major 1 — current test execution

Command, from the owner checkout (shell via rtk proxy, no installation):

```text
rtk proxy python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root . -v
```

Exit status: `0`; tool chunk `c94958`; elapsed wall time `2.198534166s`; unittest reported `Ran 29 tests in 0.714s` and `OK`. The added `test_provider_keys_in_predicates_are_rejected` ran and passed. Current test-source SHA-256: `cb053e841ca41379ee7a0313e0132e9baca4efc05b66051a5f1fe143ff4793ca`; current validator SHA-256: `843f473f1234572426d1a4b23e6a4cd03515dc214ae3b9b16590df7ed9f819c5` (`rtk proxy shasum -a 256`). Full captured test output:

```text
test_actual_registry_has_no_provider_terms (__main__.CapabilityRegistryProviderNeutralityTests.test_actual_registry_has_no_provider_terms) ... ok
test_capability_registry_schema_rejects_provider_extra_field (__main__.CapabilityRegistryProviderNeutralityTests.test_capability_registry_schema_rejects_provider_extra_field) ... ok
test_mutated_registry_with_provider_name_is_detected (__main__.CapabilityRegistryProviderNeutralityTests.test_mutated_registry_with_provider_name_is_detected) ... ok
test_nested_predicate_credentials_and_state_keys_are_rejected (__main__.CapabilityRegistryProviderNeutralityTests.test_nested_predicate_credentials_and_state_keys_are_rejected) ... ok
test_provider_keys_in_predicates_are_rejected (__main__.CapabilityRegistryProviderNeutralityTests.test_provider_keys_in_predicates_are_rejected) ... ok
test_provider_neutral_nested_predicate_values_are_accepted (__main__.CapabilityRegistryProviderNeutralityTests.test_provider_neutral_nested_predicate_values_are_accepted) ... ok
test_actual_tools_are_exactly_the_five_read_only_tools (__main__.CiMcpReadOnlyBoundaryTests.test_actual_tools_are_exactly_the_five_read_only_tools) ... ok
test_core_api_dependency_mutations_are_rejected (__main__.CiMcpReadOnlyBoundaryTests.test_core_api_dependency_mutations_are_rejected) ... ok
test_core_contracts_have_no_api_dependency (__main__.CiMcpReadOnlyBoundaryTests.test_core_contracts_have_no_api_dependency) ... ok
test_duplicate_tool_is_rejected (__main__.CiMcpReadOnlyBoundaryTests.test_duplicate_tool_is_rejected) ... ok
test_mutated_api_dependency_is_rejected (__main__.CiMcpReadOnlyBoundaryTests.test_mutated_api_dependency_is_rejected) ... ok
test_mutated_non_get_method_is_rejected (__main__.CiMcpReadOnlyBoundaryTests.test_mutated_non_get_method_is_rejected) ... ok
test_mutated_write_tool_is_rejected (__main__.CiMcpReadOnlyBoundaryTests.test_mutated_write_tool_is_rejected) ... ok
test_removed_fetch_calls_are_rejected (__main__.CiMcpReadOnlyBoundaryTests.test_removed_fetch_calls_are_rejected) ... ok
test_row1_core_owns_lifecycle_not_provider_identity (__main__.OwnershipBoundaryTests.test_row1_core_owns_lifecycle_not_provider_identity) ... ok
test_row2_capability_registry_owns_obligations_not_provider_identity (__main__.OwnershipBoundaryTests.test_row2_capability_registry_owns_obligations_not_provider_identity) ... ok
test_row3_provider_binding_owns_identity_not_core_policy (__main__.OwnershipBoundaryTests.test_row3_provider_binding_owns_identity_not_core_policy) ... ok
test_row4_host_adapter_boundary_is_recorded (__main__.OwnershipBoundaryTests.test_row4_host_adapter_boundary_is_recorded) ... ok
test_row5_ui_provider_boundary_is_recorded (__main__.OwnershipBoundaryTests.test_row5_ui_provider_boundary_is_recorded) ... ok
test_context_projection_keeps_legal_shapes_and_binding_ids (__main__.ProjectContextBoundaryTests.test_context_projection_keeps_legal_shapes_and_binding_ids) ... ok
test_context_projection_rejects_provider_fields (__main__.ProjectContextBoundaryTests.test_context_projection_rejects_provider_fields) ... ok
test_negative_provider_field_at_characteristics_rejected (__main__.ProjectContextBoundaryTests.test_negative_provider_field_at_characteristics_rejected) ... ok
test_negative_provider_field_at_root_rejected (__main__.ProjectContextBoundaryTests.test_negative_provider_field_at_root_rejected) ... ok
test_negative_provider_fields_at_component_rejected (__main__.ProjectContextBoundaryTests.test_negative_provider_fields_at_component_rejected) ... ok
test_negative_provider_fields_at_remaining_object_boundaries (__main__.ProjectContextBoundaryTests.test_negative_provider_fields_at_remaining_object_boundaries) ... ok
test_positive_ordinary_fields_and_binding_ids_accepted (__main__.ProjectContextBoundaryTests.test_positive_ordinary_fields_and_binding_ids_accepted) ... ok
test_provider_binding_schema_accepts_provider_product_credentials_state (__main__.ProjectContextBoundaryTests.test_provider_binding_schema_accepts_provider_product_credentials_state) ... ok
test_runtime_resolver_and_contract_reader_keep_legal_shapes (__main__.ProjectContextBoundaryTests.test_runtime_resolver_and_contract_reader_keep_legal_shapes) ... ok
test_shared_path_shape_stays_exclusive_and_typed (__main__.ProjectContextBoundaryTests.test_shared_path_shape_stays_exclusive_and_typed) ... ok

----------------------------------------------------------------------
Ran 29 tests in 0.714s

OK
```

The formal evaluator did not have this post-review log in its admitted manifest. This later local pass is evidence for a future review, **not** retroactive PASS for that evaluation.

## Major 2 — stale canonical Outputs (investigation and proposed addendum)

The canonical implementation report's Outputs table still declares `6c4ea9c9ec0fe43657f47b15c7724de3ef94ef55492f9b2b02b858359b884399` for `contract-boundaries.tests.py` and `68fd8421489cd549d8dcf51c48236a4dde9bc1d057f941d4fa3ecd9f93753b72` for `validate-capability-registry.py`. Current bytes are the hashes recorded above. `git diff --` confirms the test adds provider-key predicate rejection in both trigger/conditional branches; the validator adds `walk(k, ...)` to inspect dictionary keys as well as existing values, with other type annotations. The prior 28-test report is historical snapshot evidence, not current 29-test evidence.

Proposed non-frozen follow-up: a separately named implementation/evidence addendum should explicitly bind the two current hashes, identify the incremental provider-key repair and this exact 29-test log, and declare remaining unrun checks. It should point to, not rewrite, the canonical historical report. Its exact admitted paths/hashes and reviewer input set need a fresh preflight; no new formal outcome is claimed by this note.

## Major 3 — installer delta is a separate scope (investigation and proposed separation)

The existing focused diff includes `install.sh` and `tests/install.tests.sh`. Current SHA-256 values are `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50` and `648d093acbda64a1c3dff445fb2a97f537688a6f6426a64bd2701e36ff444bf4`, respectively. `git diff --` shows the installer EXIT trap only invokes rollback when exit status is nonzero; its test delta checks retained-install warning and successful FilesOnly output. These are distribution/installer behavior, not T-002's four ownership/contract Done When items, and they are absent from T-002's canonical Outputs. The prior `issue423-t002-installer-impact-20261004.md` explains why the installer delta affects whole-tree distribution claims but not those T-002 boundary assertions; it does not make the delta T-002 implementation work.

Proposed non-frozen follow-up: provide a new T-002-only focused diff/input declaration that excludes the unrelated installer files, while keeping the old mixed diff intact as historical evidence; track installer validation and independent review in its own scoped record. No source or protected-contract change, and no evaluator input substitution, was done here.

## Remaining boundary

Major 2/3 need an authoritative, current-byte declaration and independently admitted review; the old formal `NEEDS_WORK` is unchanged. This focused run does not establish CI, installed-host behavior, a new formal review, or task Done.
