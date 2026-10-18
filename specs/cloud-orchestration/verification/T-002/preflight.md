# T-002 high-risk preflight — before implementation

Classification: synthetic local tests, not cloud authority. Run identity is supplied by the native caller.
All 12 tests executed and failed (red.log, exit 1), because the new module does not exist.
No existing candidate code or historical tests are relabeled Red. These are executable
mismatch tests, initially blocked by the absent implementation, not claims that an
already-running validator was observed to accept each malicious input.

## Affected surfaces enumerated before edits

Eight new root schema documents (run-request, dependency-lock, preview,
authorization-receipt, observation, verification, operation-result, input-error),
one new shared module/parser/reader/binding checker/publisher, and the new suite.
No existing cloud schema mirrors, emitters or runtime consumers exist in this tree.
Packaging mirrors and CLI/admission/observation producers belong to later tasks.
Legacy check-contract.py and code/shell/docs/spec contracts are unchanged.
Existing validate_path.py resolves symlinks and trims strings, incompatible with
this boundary's reject-all-symlinks/canonical-byte requirements; its permissive
behavior must not be changed. Use fd-relative no-follow operations as in the
existing task manifest validator. Reuse the existing sidecar schema validator
only as an independent test oracle (no production import / generic new framework).

## Conservative refinements

Refs are {path, sha256} with bare lowercase exact-byte SHA-256. Scope is explicit
account_id/region/deployment_scope, not a resource DSL. Profile is id/version/ref.
Provider-native preview contents remain opaque hashed files; changes, deletes and
replacements are review metadata, not a generic provider change interpreter.
A trusted adapter must enumerate every actual consumed transitive input and runtime
tool identity. A locally self-consistent declaration cannot prove completeness or
provenance. The lock checker compares these independent observed inputs.
Secret scanning is a required caller-supplied callback on the exact publication
bytes, returning literal True; unavailable/error/negative scanning fails closed.
This module does not claim to recognize every possible secret by pattern.

## Field / counterpart / mismatch checklist

| Persisted evidence field | Sibling contract / traceability counterpart | Executed failing mismatch test |
|---|---|---|
| cloud-run-request/v1: `schema`, `run_id`, `unit_id`, `provider`, `binding_id`, `environment`, `scope`, `scope.account_id`, `scope.region`, `scope.deployment_scope`, `owner`, `route`, `operation`, `predecessor_receipts`, `source_revision`, `input_artifacts`, `input_artifacts.0`, `input_artifacts.0.kind`, `input_artifacts.0.path`, `input_artifacts.0.sha256`, `input_artifacts.1`, `input_artifacts.1.kind`, `input_artifacts.1.path`, `input_artifacts.1.sha256`, `input_artifacts.2`, `input_artifacts.2.kind`, `input_artifacts.2.path`, `input_artifacts.2.sha256`, `input_artifacts.3`, `input_artifacts.3.kind`, `input_artifacts.3.path`, `input_artifacts.3.sha256`, `input_artifacts.4`, `input_artifacts.4.kind`, `input_artifacts.4.path`, `input_artifacts.4.sha256`, `dependency_lock`, `dependency_lock.path`, `dependency_lock.sha256`, `policy`, `policy.path`, `policy.sha256`, `verification_profile`, `verification_profile.id`, `verification_profile.version`, `verification_profile.path`, `verification_profile.sha256` | `contracts/cloud-run-request.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| cloud-dependency-lock/v1: `schema`, `adapter_version`, `upstream`, `upstream.0`, `upstream.0.repository`, `upstream.0.commit`, `upstream.0.root`, `upstream.0.files`, `upstream.0.files.0`, `upstream.0.files.0.path`, `upstream.0.files.0.sha256`, `upstream.0.files.0.references`, `upstream.0.files.0.references.0`, `upstream.0.files.1`, `upstream.0.files.1.path`, `upstream.0.files.1.sha256`, `upstream.0.files.1.references`, `tools`, `tools.0`, `tools.0.name`, `tools.0.version`, `tools.0.sha256`, `managed_endpoints`, `managed_endpoints.0`, `managed_endpoints.0.endpoint`, `managed_endpoints.0.tool_schema`, `managed_endpoints.0.tool_schema.path`, `managed_endpoints.0.tool_schema.sha256` | `contracts/cloud-dependency-lock.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| cloud-preview/v1: `schema`, `run_id`, `unit_id`, `provider`, `scope`, `scope.account_id`, `scope.region`, `scope.deployment_scope`, `request`, `request.path`, `request.sha256`, `dependency_lock`, `dependency_lock.path`, `dependency_lock.sha256`, `policy`, `policy.path`, `policy.sha256`, `verification_profile`, `verification_profile.path`, `verification_profile.sha256`, `preview_identity`, `semantic_sha256`, `changes`, `changes.path`, `changes.sha256`, `replacements`, `deletes`, `created_at`, `expires_at` | `contracts/cloud-preview.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| cloud-authorization-receipt/v1: `schema`, `run_id`, `unit_id`, `provider`, `scope`, `scope.account_id`, `scope.region`, `scope.deployment_scope`, `operation`, `issuer`, `principal`, `subject`, `ci`, `ci.repository`, `ci.workflow`, `ci.workflow_revision`, `ci.ref`, `ci.environment`, `ci.run_id`, `ci.run_attempt`, `request`, `request.path`, `request.sha256`, `preview`, `preview.path`, `preview.sha256`, `dependency_lock`, `dependency_lock.path`, `dependency_lock.sha256`, `policy`, `policy.path`, `policy.sha256`, `verification_profile`, `verification_profile.path`, `verification_profile.sha256`, `issued_at`, `expires_at`, `approval_evidence`, `approval_evidence.locator`, `approval_evidence.sha256` | `contracts/cloud-authorization-receipt.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| cloud-observation/v1: `schema`, `run_id`, `unit_id`, `provider`, `native_operation_id`, `resource_ids`, `resource_ids.0`, `principal`, `query`, `timestamp`, `exit_code`, `status`, `result`, `result.path`, `result.sha256`, `classification` | `contracts/cloud-observation.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| cloud-verification/v1: `schema`, `run_id`, `unit_id`, `provider`, `profile`, `profile.id`, `profile.version`, `profile.path`, `profile.sha256`, `required_check_ids`, `required_check_ids.0`, `checks`, `checks.0`, `checks.0.check_id`, `checks.0.observation`, `checks.0.observation.path`, `checks.0.observation.sha256`, `checks.0.result`, `overall_result`, `evidence_complete` | `contracts/cloud-verification.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| cloud-operation-result/v1: `schema`, `run_id`, `unit_id`, `provider`, `operation`, `state`, `result`, `error_code`, `message`, `input_manifest_sha256`, `evidence_manifest_path` | `contracts/cloud-operation-result.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| cloud-input-error/v1: `schema`, `error_code`, `message`, `field` | `contracts/cloud-input-error.schema.json` exact property/required/type/enum boundaries; design API / public invocation contract | `test_all_object_boundaries_unknown_and_missing_fields`, `test_all_scalar_types_and_schema_versions` |
| request scope, owner, identity, source, binding, environment; all input/compiled/asset/module/parameter/policy/profile/lock refs | preview/receipt request exact-byte digest; preview/receipt matching scope and refs (REQ-004) | `test_every_bound_file_mutation_is_rejected`, `test_bound_scope_owner_profile_policy_identity_and_preview_drift` |
| lock upstream files/references, tool versions/package sha, adapter version, endpoint schemas | actual consumed closure and observed tool versions/package/schema digests | `test_lock_closure_versions_packages_schemas_and_adapter` |
| preview/receipt timestamps and semantic digest | strict UTC order/current time and exact changes bytes | `test_digests_utc_paths_and_scalar_edge_cases`, `test_bound_scope_owner_profile_policy_identity_and_preview_drift` |
| verification check IDs/results/overall/completeness | required check set and conservative result consistency, not authenticated reducer | `test_verification_inconsistent_claims_and_duplicate_checks` |
| operation result/state/error, input-error absence of identity | design exit codes and separate identity-free error envelope | `test_result_exit_mapping_and_invalid_identity` |
| evidence path, byte hash, no overwrite, no secrets | contained regular file bytes and required scanner verdict (REQ-010) | `test_safe_reader_rejects_symlinks_hardlinks_and_nonfiles`, `test_publication_atomic_no_overwrite_containment_and_scan_failure` |
