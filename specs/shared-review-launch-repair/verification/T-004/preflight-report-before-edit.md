# Implementation Report: T-004

Report Schema: implementation-report/v2
Run ID: T-004-01a12608-3c98-7fc0-9d9f-461daa965549
Task Attempt Count: 1

## High-risk Preflight

Recorded before any production edit. See `specs/shared-review-launch-repair/verification/T-004/preflight-mismatch-results.json` for executed mismatches. Existing registrations use mutation RED, not original-production RED. All 62 input hashes and copied source bytes match. No node_modules exists before the dependency experiment.

| Persisted field or claim | Counterpart | Executed failing mismatch |
|---|---|---|
| `consuming-install` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `consuming-install-order` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-direct-transport` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-traceability` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-transport` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-traceability` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-python-execution` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `powershell-transport` | `tests/run-all.ps1` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `powershell-hash-parity` | `tests/run-all.ps1` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `powershell-python-execution` | `tests/run-all.ps1` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `registry-full-profile` | `specs/workflow-state-registry.json` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-review-conditional-inputs` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-review-conditional-inputs` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-spec-review-verify-inputs` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-spec-review-verify-inputs` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-host-review-preflight` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-host-review-preflight` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-unified-launch-order` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-unified-launch-order` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-unified-task-launch` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-unified-task-launch` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-task-structured-output` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-task-structured-output` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-supplemental-delivery-declaration` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-supplemental-delivery-declaration` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `bash-t001-evaluation-preparation` | `tests/run-all.sh` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `ci-t001-evaluation-preparation` | `.github/workflows/test.yml` executable registration / REQ-003, REQ-006 | One deletion or order change; exit 1 |
| `task_id` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `task_id` |
| `run_id` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `run_id` |
| `session_id` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `session_id` |
| `agent_instance_id` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `agent_instance_id` |
| `isolation_mode` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `isolation_mode` |
| `task_attempt_count` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `task_attempt_count` |
| `manifest_sha256` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `manifest_sha256` |
| `scratch_root` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `scratch_root` |
| `spec_revision` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `spec_revision` |
| `input:.github/workflows/test.yml` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:.github/workflows/test.yml` |
| `input:AGENTS.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:AGENTS.md` |
| `input:contracts/agent-model-capabilities.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:contracts/agent-model-capabilities.json` |
| `input:contracts/agent-model-capabilities.v2.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:contracts/agent-model-capabilities.v2.json` |
| `input:contracts/task-input-manifest.schema.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:contracts/task-input-manifest.schema.json` |
| `input:contracts/workflow-state-registry.schema.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:contracts/workflow-state-registry.schema.json` |
| `input:handoffs/shared-review-launch-repair-T-003-attempt-1/t004-ci-dependency-preparation.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:handoffs/shared-review-launch-repair-T-003-attempt-1/t004-ci-dependency-preparation.md` |
| `input:handoffs/shared-review-launch-repair-T-004-attempt-1/before-byte-inventory.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:handoffs/shared-review-launch-repair-T-004-attempt-1/before-byte-inventory.json` |
| `input:handoffs/shared-review-launch-repair-T-004-attempt-1/inputs.txt` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:handoffs/shared-review-launch-repair-T-004-attempt-1/inputs.txt` |
| `input:handoffs/shared-review-launch-repair-T-004-attempt-1/native-instructions.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:handoffs/shared-review-launch-repair-T-004-attempt-1/native-instructions.md` |
| `input:handoffs/shared-review-launch-repair-T-004-attempt-1/registry-topology.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:handoffs/shared-review-launch-repair-T-004-attempt-1/registry-topology.json` |
| `input:mcp/ci-mcp/package-lock.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:mcp/ci-mcp/package-lock.json` |
| `input:mcp/ci-mcp/package.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:mcp/ci-mcp/package.json` |
| `input:plugins/sdd-implementation/scripts/validate-implementation-report.sh` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-implementation/scripts/validate-implementation-report.sh` |
| `input:plugins/sdd-implementation/skills/implement-task/SKILL.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-implementation/skills/implement-task/SKILL.md` |
| `input:plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md` |
| `input:plugins/sdd-implementation/skills/implement-task/references/implementation-craft-policy.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-implementation/skills/implement-task/references/implementation-craft-policy.md` |
| `input:plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md` |
| `input:plugins/sdd-implementation/templates/implementation-report.template.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-implementation/templates/implementation-report.template.md` |
| `input:plugins/sdd-quality-loop/references/guard-invariants.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/references/guard-invariants.json` |
| `input:plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` |
| `input:plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` |
| `input:plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` |
| `input:plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` |
| `input:plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` |
| `input:plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py` |
| `input:plugins/sdd-quality-loop/scripts/review-conditional-inputs.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/review-conditional-inputs.py` |
| `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` |
| `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` |
| `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` |
| `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh` |
| `input:plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` |
| `input:plugins/sdd-review-loop/references/review-context-boundary.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/references/review-context-boundary.md` |
| `input:plugins/sdd-review-loop/scripts/launch-impl-review.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/scripts/launch-impl-review.py` |
| `input:plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs` |
| `input:plugins/sdd-review-loop/scripts/preflight-host-review.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/scripts/preflight-host-review.py` |
| `input:plugins/sdd-review-loop/scripts/probe-nontty-review.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/scripts/probe-nontty-review.py` |
| `input:plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` |
| `input:plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` |
| `input:plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` |
| `input:plugins/sdd-review-loop/skills/task-review-loop/SKILL.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/skills/task-review-loop/SKILL.md` |
| `input:plugins/sdd-review-loop/templates/task-review-contract.template.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:plugins/sdd-review-loop/templates/task-review-contract.template.json` |
| `input:reports/verification/issue137-model-registration-candidate-20260928/launch-candidates.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:reports/verification/issue137-model-registration-candidate-20260928/launch-candidates.json` |
| `input:reports/verification/issue137-model-registration-candidate-20260928/report.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:reports/verification/issue137-model-registration-candidate-20260928/report.md` |
| `input:reports/verification/shared-review-launch-integration.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:reports/verification/shared-review-launch-integration.md` |
| `input:scripts/check-sdd-structure.sh` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:scripts/check-sdd-structure.sh` |
| `input:specs/shared-review-launch-repair/acceptance-tests.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/acceptance-tests.md` |
| `input:specs/shared-review-launch-repair/authority.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/authority.md` |
| `input:specs/shared-review-launch-repair/design.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/design.md` |
| `input:specs/shared-review-launch-repair/frontend-spec.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/frontend-spec.md` |
| `input:specs/shared-review-launch-repair/infra-spec.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/infra-spec.md` |
| `input:specs/shared-review-launch-repair/requirements.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/requirements.md` |
| `input:specs/shared-review-launch-repair/security-spec.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/security-spec.md` |
| `input:specs/shared-review-launch-repair/tasks.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/tasks.md` |
| `input:specs/shared-review-launch-repair/traceability.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/traceability.md` |
| `input:specs/shared-review-launch-repair/ux-spec.md` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/shared-review-launch-repair/ux-spec.md` |
| `input:specs/workflow-state-registry.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:specs/workflow-state-registry.json` |
| `input:tests/host-review-preflight.tests.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:tests/host-review-preflight.tests.py` |
| `input:tests/run-all.ps1` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:tests/run-all.ps1` |
| `input:tests/run-all.sh` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:tests/run-all.sh` |
| `input:tests/task-structured-output.tests.py` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:tests/task-structured-output.tests.py` |
| `input:handoffs/shared-review-launch-repair-T-004-attempt-1/source-modes.json` | snapshot raw SHA-256 and admitted manifest | Single-field mismatch rejected: `input:handoffs/shared-review-launch-repair-T-004-attempt-1/source-modes.json` |
| `original-wiring-red:command` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-wiring-red:command` |
| `original-wiring-red:cwd` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-wiring-red:cwd` |
| `original-wiring-red:exit` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-wiring-red:exit` |
| `original-wiring-red:stdout` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-wiring-red:stdout` |
| `original-wiring-red:stderr` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-wiring-red:stderr` |
| `original-wiring-red:source_sha256` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-wiring-red:source_sha256` |
| `original-missing-ajv-red:command` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-missing-ajv-red:command` |
| `original-missing-ajv-red:cwd` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-missing-ajv-red:cwd` |
| `original-missing-ajv-red:exit` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-missing-ajv-red:exit` |
| `original-missing-ajv-red:stdout` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-missing-ajv-red:stdout` |
| `original-missing-ajv-red:stderr` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-missing-ajv-red:stderr` |
| `original-missing-ajv-red:source_sha256` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `original-missing-ajv-red:source_sha256` |
| `baseline-test013:command` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `baseline-test013:command` |
| `baseline-test013:cwd` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `baseline-test013:cwd` |
| `baseline-test013:exit` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `baseline-test013:exit` |
| `baseline-test013:stdout` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `baseline-test013:stdout` |
| `baseline-test013:stderr` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `baseline-test013:stderr` |
| `baseline-test013:source_sha256` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `baseline-test013:source_sha256` |
| `TEST-006a` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `TEST-006a` |
| `TEST-006b` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `TEST-006b` |
| `native-windows` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `native-windows` |
| `combined-rollback` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `combined-rollback` |
| `independent-review` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `independent-review` |
| `quality-gate` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `quality-gate` |
| `merge` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `merge` |
| `postmerge` | manifest identity, admitted base HEAD, or captured command record; downstream observations remain NOT RUN | Single-field mismatch rejected: `postmerge` |

Original RED: `original-wiring-red.json` fails only consuming-install. `original-missing-ajv-red.json` records actual MODULE_NOT_FOUND. TEST-013 baseline is GREEN. No production change yet. Two evidence-harness defects (case-name suffix collision, last-loop-token delimiter) were corrected; both failed executions are retained.
