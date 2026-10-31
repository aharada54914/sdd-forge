# Tasks: shared-review-launch-repair

Task-Review-Status: Passed

## Lifecycle and execution

Draft -> Approved -> In Progress -> Implementation Complete -> Done.
Humans approve; implement-task records execution; only quality-gate sets Done.
Prior candidate code and diagnostic results are not task acceptance evidence.
Execute T-001 -> T-005 -> T-002 -> T-003 -> T-004. One owner serializes shared-file edits and canonical reservations.
Before further code changes, each task records every persisted evidence field, its contract counterpart and an executed failing mismatch case in its implementation report.
Each task records retained pre-fix RED evidence, final commands/results, source/test hashes, spec_revision, environment, Run ID and Task Attempt Count in reports/implementation/shared-review-launch-repair/T-NNN.md and verification/T-NNN/.
Final coverage belongs in these non-frozen addenda, never in frozen artifacts or historical verdicts.

## Rollback for every task

Before changing code, retain the exact base revision and target-scoped before-byte/hash inventory, including existing dirty candidate bytes.
In a disposable checkout, restore only the task-owned code/config targets, verify before-byte hashes and rerun affected baseline regressions. Record executed restoration commands and results under the task's verification directory.
Never restore/truncate ledgers, approvals, reservations, historical reviews or frozen evidence. Consumed identities stay consumed.
T-004 additionally tests reverting the combined code/config changes in an isolated checkout against the recorded base. Failure blocks completion; fixtures do not prove native rollback. Installed-baseline promotion, reinstall and trust changes are not authorized here.

## Scope boundaries

Product #423 T-002 completion, A7/A8/A9 status, later four-point architecture, new ledger/protocol, baseline selection and historical evidence repair are excluded.
T-001 owns CLI arguments and effective permissions; T-005 owns input/dependency admission and reservation ordering after T-001 releases shared launch files. T-002 may touch context validators only after T-005 releases them, solely for the approved normalization rules. T-003 reuses T-001's test driver after release, solely for protection inventory. T-004 owns permanent test registration, integrated CI and merge evidence. Shared-file edits are serialized and each task's diff is restricted to its named behavior.

## T-001 Shared launch arguments and permissions

Source Issue: https://github.com/aharada54914/sdd-forge/issues/423
Approval: Approved
Status: Done
Risk: high
Risk Rationale: Changes formal reviewer CLI arguments and effective permission enforcement.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-001

### Goal

Use one argument and permission assembly for diagnostics and formal launch, preserving session isolation and the existing validator and identity contracts.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md
- authority.md and ../../AGENTS.md
- ../../plugins/sdd-review-loop/references/review-context-boundary.md
- ../../plugins/sdd-review-loop/templates/task-review-contract.template.json
- ../../reports/verification/shared-review-launch-integration.md

### Planned Files

- plugins/sdd-review-loop/scripts/launch-impl-review.py
- plugins/sdd-review-loop/scripts/preflight-host-review.py
- plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py
- plugins/sdd-review-loop/scripts/probe-nontty-review.py
- plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs
- plugins/sdd-review-loop/skills/{spec-review-loop,impl-review-loop,task-review-loop}/SKILL.md
- plugins/sdd-review-loop/references/review-context-boundary.md
- plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py
- plugins/sdd-quality-loop/agents/evaluator.md
- plugins/sdd-quality-loop/skills/quality-gate/SKILL.md
- tests/{host-review-preflight,quality-nontty-transport,unified-task-launch}.tests.py
- reports/implementation/shared-review-launch-repair/T-001.md and specs/shared-review-launch-repair/verification/T-001/

### Done When

- AC-001: TEST-001, TEST-002 and TEST-003a–c prove actual caller arguments, aliases, model and permission enforcement, including compound commands and outside reads.
- Record the task preflight, RED-to-GREEN regressions and disposable rollback test with exact hashes; distinguish fixtures, native execution and CI.
- Independent diff review and formal quality evaluation have no blocking findings. Only quality-gate sets Done; T-004 owns integrated delivery evidence.

### Blockers

None

## T-005 Input admission before reservation

Source Issue: https://github.com/aharada54914/sdd-forge/issues/423
Approval: Approved
Status: Done
Risk: high
Risk Rationale: Changes required-input and dependency admission, receipt identity binding and reservation ordering.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-002

### Goal

Connect required input, dependency and allowed-path checks to the shared launch path before its existing reservation step. Retain ledger semantics and consumed identities.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md
- authority.md and ../../AGENTS.md
- ../../plugins/sdd-review-loop/references/review-context-boundary.md
- ../../plugins/sdd-review-loop/templates/task-review-contract.template.json
- ../../reports/verification/shared-review-launch-integration.md

### Planned Files

- plugins/sdd-review-loop/scripts/{launch-impl-review.py,preflight-host-review.py,spec-review-precheck.sh,spec-review-precheck.ps1}
- plugins/sdd-review-loop/skills/{spec-review-loop,impl-review-loop,task-review-loop}/SKILL.md
- plugins/sdd-review-loop/references/review-context-boundary.md
- plugins/sdd-quality-loop/scripts/{preflight-evaluator-delivery.py,review-conditional-inputs.py,validate-review-context-set.sh,validate-review-context-set.ps1}
- plugins/sdd-quality-loop/skills/quality-gate/SKILL.md
- tests/{review-conditional-inputs,spec-review-verify-inputs,task-structured-output,unified-launch-order,unified-task-launch}.tests.py
- tests/review-context-boundary.tests.sh
- reports/implementation/shared-review-launch-repair/T-005.md and specs/shared-review-launch-repair/verification/T-005/

### Done When

- AC-002: TEST-004 and TEST-005a–h prove required ordered inputs, dependencies, raw invocation binding and receipt consistency; pre-reservation failures leave the ledger unchanged, post-append failures retain the consumed identity without launching or retrying it.
- Record the task preflight, RED-to-GREEN regressions and disposable rollback test with exact hashes; distinguish fixtures, native execution and CI.
- Re-run T-001 launch/permission regressions after shared-file edits; do not change its CLI/permission contract.
- Independent diff review and formal quality evaluation have no blocking findings. Only quality-gate sets Done; T-004 owns integrated delivery evidence.

### Blockers

T-001

## T-002 Freeze and PowerShell normalization

Source Issue: https://github.com/aharada54914/sdd-forge/issues/423
Approval: Approved
Status: Done
Risk: high
Risk Rationale: Changes frozen-input normalization and shared PowerShell hash calculations while preserving stage-specific checks.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-004, REQ-005

### Goal

Complete the approved freeze and powershell normalization portion of the existing candidate without replacing existing validators, identity rules or historical evidence.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md
- authority.md and ../../AGENTS.md
- ../../plugins/sdd-review-loop/references/review-context-boundary.md
- ../../plugins/sdd-review-loop/templates/task-review-contract.template.json
- ../../reports/verification/shared-review-launch-integration.md

### Planned Files

- AGENTS.md
- plugins/sdd-review-loop/scripts/{review-hash-normalization.ps1,impl-review-precheck.ps1,task-review-precheck.ps1}
- plugins/sdd-quality-loop/scripts/validate-review-context-set.{sh,ps1}
- tests/traceability-freeze-contract.tests.py
- tests/review-hash-normalization.tests.ps1
- reports/implementation/shared-review-launch-repair/T-002.md and specs/shared-review-launch-repair/verification/T-002/

### Done When

- AC-004: TEST-007 and TEST-008a–d preserve only authorized REQ final-status normalization and reject other changes.
- AC-005: TEST-009 and TEST-010a–b prove old/new PowerShell recipe equivalence, read errors, case and line-ending behavior, retaining stage-specific checks and outputs.
- Record the task preflight, RED-to-GREEN regressions and disposable rollback test with exact hashes; distinguish fixtures, native execution and CI.
- Independent diff review and formal quality evaluation have no blocking findings. Only quality-gate sets Done; T-004 owns integrated delivery evidence.

### Blockers

T-005

## T-003 Protected entrypoint registration

Source Issue: https://github.com/aharada54914/sdd-forge/issues/423
Approval: Approved
Status: Done
Risk: high
Risk Rationale: Changes protected entrypoint membership and its generated runtime projections.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-006

### Goal

Complete the approved protected entrypoint registration portion of the existing candidate without replacing existing validators, identity rules or historical evidence.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md
- authority.md and ../../AGENTS.md
- ../../plugins/sdd-review-loop/references/review-context-boundary.md
- ../../plugins/sdd-review-loop/templates/task-review-contract.template.json
- ../../reports/verification/shared-review-launch-integration.md

### Planned Files

- plugins/sdd-quality-loop/references/guard-invariants.json
- plugins/sdd-quality-loop/scripts/generate-guard-invariants.py
- plugins/sdd-quality-loop/scripts/generated/{guard-invariants.generated.js,guard-invariants.generated.ps1,guard-invariants.generated.sh,guard_invariants.py}
- tests/host-review-preflight.tests.py
- reports/implementation/shared-review-launch-repair/T-003.md and specs/shared-review-launch-repair/verification/T-003/

### Done When

- AC-006: TEST-011a–f, TEST-012a–d and TEST-013 exercise all six entrypoints, canonical/generated inventory drift, unrelated membership preservation and permanent CI-registration removal.
- TEST-013 supplies the registration-removal negative check; T-004 owns its permanent CI wiring and CI result.
- Record the task preflight, RED-to-GREEN regressions and disposable rollback test with exact hashes; distinguish fixtures, native execution and CI.
- Independent diff review and formal quality evaluation have no blocking findings. Only quality-gate sets Done; T-004 owns integrated delivery evidence.

### Blockers

T-002

## T-004 Regression wiring and integrated delivery

Source Issue: https://github.com/aharada54914/sdd-forge/issues/423
Approval: Approved
Status: In Progress
Risk: high
Risk Rationale: Changes mandatory regression registration and records exact-head integration and merge evidence.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-003, REQ-006

### Goal

Complete the approved regression wiring and integrated delivery portion of the existing candidate without replacing existing validators, identity rules or historical evidence.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md
- authority.md and ../../AGENTS.md
- ../../plugins/sdd-review-loop/references/review-context-boundary.md
- ../../plugins/sdd-review-loop/templates/task-review-contract.template.json
- ../../reports/verification/shared-review-launch-integration.md

### Planned Files

- tests/run-all.sh
- tests/run-all.ps1
- .github/workflows/test.yml
- specs/workflow-state-registry.json
- reports/verification/shared-review-launch-integration.md
- reports/implementation/shared-review-launch-repair/T-004.md and specs/shared-review-launch-repair/verification/T-004/

### Done When

- AC-003: TEST-006a–b run the applicable normal Bash/PowerShell entrypoints and exact-head mandatory CI. Record actual native Windows execution separately; an unavailable required branch is not PASS.
- AC-006 TEST-013 proves permanent regression-registration removal is rejected.
- Exact-final-head mandatory CI and required native Windows branches succeed; review findings and conflicts are resolved before merge. Record PR head, merge commit and successful applicable post-merge run URLs in the delivery addendum. Pending or unavailable results are not completion.
- Record the task preflight, RED-to-GREEN regressions and disposable rollback test with exact hashes; distinguish fixtures, native execution and CI.
- Independent diff review and formal quality evaluation have no blocking findings. Only quality-gate sets Done; T-004 owns integrated delivery evidence.

### Blockers

T-001, T-005, T-002, T-003
