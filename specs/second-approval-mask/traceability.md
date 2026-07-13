# Traceability: second-approval-mask

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | INV — RT-20260712-003 (Second Approval line trips the frozen task plan hash; discovered completing the first critical two-person approval) | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#components; design.md#test-strategy | No interface change; normalized-hash treatment of one line prefix only | plugins/sdd-quality-loop/scripts/check-workflow-state.sh; plugins/sdd-quality-loop/scripts/check-workflow-state.ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005 | tests/second-approval-mask.tests.sh | reports/quality-gate/ for T-001 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CLI validator change | ux-spec.md#scope-and-user-journeys | Diagnostic format unchanged; no rendered surface. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI validator change | frontend-spec.md#technology-stack | Bash/PowerShell scripts are not a frontend surface. |
| Infrastructure | REQ-001 | AC-004 | infra-spec.md#ci-cd-sequence | Suite registration in run-all only; no topology change. |
| Security | REQ-001 | AC-001, AC-002, AC-003, AC-004, AC-005 | security-spec.md#trust-boundaries; security-spec.md#security-tests | None. |

## Task Map

| Task | Requirements | Tests | Evidence Expectation |
|---|---|---|---|
| T-001 | REQ-001 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005 | high-risk implementation report, cross-model consensus, independent quality-gate report |
