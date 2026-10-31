# Traceability: shared-review-launch-repair

This plan maps expected checks, not executed outcomes. Investigation is N/A: the bounded repair uses existing candidate evidence cited in requirements.md and authority.md, not a separate investigation or invented baseline. T-001 owns REQ-001; T-005 owns REQ-002; T-002 owns REQ-004/005; T-003 owns REQ-006 inventory and local drift checks; T-004 owns REQ-003 and permanent REQ-006 CI registration (TEST-013). Execute T-001 -> T-005 -> T-002 -> T-003 -> T-004 to serialize shared-file edits. After review freeze, record coverage in reports/implementation/shared-review-launch-repair/T-NNN.md and verification/T-NNN/ rather than editing this table.

| Requirement | Investigation | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|---|
| REQ-001 | N/A — existing candidate evidence | design.md#bounded-approach | ux-spec.md#scope-and-user-journeys; security-spec.md#trust-boundaries | shared launcher, CLI validator, probe and session guard | TEST-001, TEST-002, TEST-003a, TEST-003b, TEST-003c (AC-001) | Planned |
| REQ-002 | N/A — existing candidate evidence | design.md#risk-and-persisted-evidence-preflight | security-spec.md#threats-and-authorization; frontend-spec.md#state-routes-api-client-and-performance | launcher, conditional-input resolver, context validators | TEST-004, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h (AC-002) | Planned |
| REQ-003 | N/A — existing candidate evidence | design.md#validation-and-deployment | infra-spec.md#cicd-sequence; frontend-spec.md#dependencies-and-testing | tests/run-all.sh, tests/run-all.ps1, .github/workflows/test.yml | TEST-006a, TEST-006b (AC-003) | Planned |
| REQ-004 | N/A — existing candidate evidence | design.md#acceptance-mapping | security-spec.md#data-protection-and-security-tests | AGENTS.md, task-stage traceability binding | TEST-007, TEST-008a, TEST-008b, TEST-008c, TEST-008d (AC-004) | Planned |
| REQ-005 | N/A — existing candidate evidence | design.md#acceptance-mapping | infra-spec.md#runtime-dependencies-and-environment; frontend-spec.md#dependencies-and-testing | review-hash-normalization.ps1, impl/task PowerShell prechecks | TEST-009, TEST-010a, TEST-010b (AC-005) | Planned |
| REQ-006 | N/A — existing candidate evidence | design.md#bounded-approach | security-spec.md#trust-boundaries; infra-spec.md#observability-and-rollback | guard-invariants.json, generator and four projections; six protected entrypoints | TEST-011a, TEST-011b, TEST-011c, TEST-011d, TEST-011e, TEST-011f, TEST-012a, TEST-012b, TEST-012c, TEST-012d, TEST-013 (AC-006) | Planned |

## Layer Coverage

| Layer | Requirements / AC | Scope | Gaps |
|---|---|---|---|
| UX | REQ-001/002; AC-001/002 | ux-spec.md: diagnostic states and actionable rejection, no new graphical interface | Native diagnostics must be observed, not inferred from fixtures |
| Frontend | REQ-002/003/005; AC-002/003/005 | frontend-spec.md: CLI client state and dependency/test boundary | No web frontend; CLI caller coverage remains required |
| Infrastructure | REQ-003/005/006; AC-003/005/006 | infra-spec.md: cross-platform tests, native CLI, CI and rollback | Exact-head hosted CI and native Windows remain required |
| Security | REQ-001/002/004/006; AC-001/002/004/006 | security-spec.md: least privilege, identity, freeze and protection | Fixtures do not substitute for native enforcement evidence |
