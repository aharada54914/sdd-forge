# T-002 attempt 2 preflight (before production edits)

Ticket RT-20261018-CLOUD-CONTRACT; governing clarification integration-contract-decision.md.
Existing 23 contract and 22 admission methods passed before repair; no retroactive Red claim.
New tests ran against unchanged pre-repair production: red-contracts.log (27 methods,
3 failures/68 errors), red-admission.log (24 methods, 1 failure/92 errors).
Failures include rejected local_context/nullable result, missing helpers/schemas and
Policy's absent target_environment. Most admission negatives cannot yet reach their
assertions because the new Policy constructor is absent; this is explicitly not
proof of a negative path. Green must exercise all these cases.

| Persisted field(s) | Sibling / contract counterpart | Executed failing mismatch test |
|---|---|---|
| local_context.workspace_anchor, artifact_root, unit_roots, evidence_directory, feature, task_id; ownership.path/sha256, provider_config.path/sha256 | request schema and explicit physical workspace boundary, exact run/unit evidence directory, contained immutable input refs | test_repair_local_context_schema_and_each_field; test_repair_physical_workspace_and_declared_boundary |
| ownership.schema, owners[].owner/root, existing_resources[].resource_id/owner/attachments[].resource_type/name | cloud-ownership schema, recognized owners and explicit additive attachment data; router must still inspect scanned files | test_all_object_boundaries_unknown_and_missing_fields; test_all_scalar_types_and_schema_versions (expanded fixtures) |
| deployment-policy.schema, allowed_scopes[].account_id/region/deployment_scope, allowed_resource_types[], backup_required, private_networking, budget.ceiling_minor_units/currency, evidence.residency/retention_days/access | cloud-deployment-policy schema, scope allowlist, explicit budget and restrictive evidence/network requirements | test_all_object_boundaries_unknown_and_missing_fields; test_all_scalar_types_and_schema_versions (expanded fixtures) |
| verification-profile.schema/id/version/required_check_ids[]/max_age_seconds | cloud-verification-profile schema; request profile identity/digest and required freshness | test_all_object_boundaries_unknown_and_missing_fields; test_all_scalar_types_and_schema_versions (expanded fixtures) |
| request.owner/route (discovery), operation and environment | supported execution tuple; immutable apply intent and logical target, not protected stage | test_repair_discovery_and_honest_unpublished_errors; test_repair_explicit_phase_preserves_legacy_integrity_api |
| receipt.operation/ci.environment/request/preview/policy digests and all unchanged binding fields | explicit actual operation, external stage Policy.environment, Policy.target_environment, common JSON policy digest and identical request bytes | test_repair_same_request_prepare_preview_apply_separate_policies; test_repair_stage_target_context_and_digest_controls_zero_submissions |
| operation-result.evidence_manifest_path/result/state/native_operation_id | null only for pre-publication BLOCKED/FAIL, never successful/unknown/submitted result | test_repair_discovery_and_honest_unpublished_errors |
| Existing input/dependency/preview/receipt/observation/verification/result fields, identity and exit mapping | original eight schemas and 23 original contract / 22 admission methods (retained); no new truth claim | before-contracts.log and before-admission.log are baseline Green, not Red; repair tests above isolate changed behavior |

Minimal shared data shapes refine the approved named requirements; no provider
config DSL or authority is introduced. Provider config stays opaque hash-bound
bytes, validated by each provider. Owner detection/preview interpretation is not
implemented here. Integer minor currency units avoid float coercion or rounding.
