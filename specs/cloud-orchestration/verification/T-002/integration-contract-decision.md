# Integration contract clarification, 2026-10-18

This addendum makes the already-approved declared-root, ownership and immutable-input requirements concrete. It changes no permitted cloud operation, IAM privilege, required check or frozen requirement. It repairs the initial unreleased contracts and immediate caller under RT-20261018-CLOUD-CONTRACT. Later provider tasks consume these inputs; they must not guess them.

## Portable declared filesystem boundary

Add optional strict `local_context` to cloud-run-request/v1. Earlier integrity-only v1 fixtures remain parseable. Provider execution requires this context and otherwise returns typed BLOCKED. Its fields are `workspace_anchor` (constant `CLOUD_WORKSPACE_ROOT`), `artifact_root` (canonical relative directory), `unit_roots` (nonempty unique relative directories), `evidence_directory`, `feature`, `task_id`, and hashed `ownership` and `provider_config` references. The operator/CI explicitly sets CLOUD_WORKSPACE_ROOT to the physical absolute workspace root; absent, relative, symlinked or unsafe roots block. The variable selects a filesystem boundary, never authorization. No cwd/request-parent fallback.

All request references are canonical paths relative to that explicit workspace root. Input files, ownership/config/policy/profile and dependency files must be within artifact_root. Unit roots must be within artifact_root and are recursively scanned without following links. Evidence directory must equal `specs/<feature>/verification/<task_id>/cloud/<run_id>/<unit_id>` and must be disjoint from input roots. Preview/receipt references are within that run evidence directory; predecessor references use their separately validated run/unit evidence paths. All existing no-overwrite, no-alias, no-symlink and digest checks remain. Physical checkout locations may differ across local and CI while relative paths and bytes remain identical.

Add strict typed ownership metadata describing each detected owner/root and explicit existing resource IDs plus additive attachments. Recognize bicep, cdk, terraform, sam, cloudformation and azd; only bicep/cdk can execute. Request owner may express an unsupported recognized owner or no selection and route may be null for discovery; supported execution still requires the exact provider/owner/route tuple. Never infer authorization from extensions or auto-import resources. The owner inventory supplements a real scan, never hides conflicting detected roots.

Define minimal strict local deployment-policy and verification-profile bodies for the existing approved requirements: allowlisted target scope/resource types, mandatory backup, explicit budget ceiling/currency, private networking, evidence residency/retention/access, and required checks/freshness. Keep provider-specific template/probe settings in provider_config, to be validated by each provider. Shared contracts are validators, not a resource engine. All referenced bodies are immutable hash-bound data, never trusted executable code. Include per-field schema/runtime parity tests.

## Stable intent, separate authenticated phases

For the full deployment lifecycle the frozen request has `operation: apply` and a logical target `environment` (for example sandbox). Local plan may emit a new immutable locked request after compilation; prepare and apply then consume those exact same bytes. CLI phase and authorization receipt operation describe the actual stage. Trusted Policy has separate target_environment and protected CI environment. Both prepare and apply policies pin the same deployment-policy JSON digest; their executable trusted configuration is protected by the pinned workflow/executor revision. Do not hash each stage-specific Python file as deployment policy.

verify_binding must take/validate the actual operation when checking phase-dependent requirements. Apply requires a fresh preview; prepare does not. Receipt operation must match the passed actual phase and its protected CI environment must match external trusted policy when used by admission. Do not equate receipt CI environment with the logical target. Offline binding checks never grant authority. The write boundary still authenticates each stage, scope, principal, actor, approval, run, attempt, TTL and exact artifact bytes on every mutation. Test two distinct stage policies with one request reference and ensure wrong stage, target, preview and digest each result in zero submissions.

## Honest output errors

Permit evidence_manifest_path null only on pre-publication BLOCKED/FAIL outcomes when no artifact could safely be published. PASS/NO_CHANGE and UNKNOWN after submission must carry genuine evidence. An invalid identity uses the existing input-error envelope. Never publish into an invalid requested output or manufacture a receipt merely to satisfy the result shape.

## Review and compatibility

This is additive to previously accepted integrity-only request shapes; existing SDD contracts and historical evidence are unchanged. Deployment operations require the new explicit context. No existing released cloud CLI exists. Preserve the prior T-002 quality cycle-3 PASS as a record of its actual scope; this repair needs fresh Red/Green evidence, updated schemas/fixtures/docs and independent review before completion. No live cloud acceptance is inferred from local transport tests.
