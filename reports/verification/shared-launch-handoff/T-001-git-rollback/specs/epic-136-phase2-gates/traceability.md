# Traceability: epic-136-phase2-gates

Every layer-spec cell contains canonical anchors or a reasoned N/A. Requirement
status changes only from saved deterministic test evidence and independent
quality-gate reports; implementation reports are claims, not verification.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Evidence | Status |
|---|---|---|---|---|---|---|---|---|
| REQ-001 | N/A — observed guard behavior is specified in requirements.md | security-spec.md#trust-boundaries; security-spec.md#security-tests | design.md#components; design.md#test-strategy | Existing guard decision protocol | Guard twins (.py/.js/.ps1) | TEST-001, TEST-002 | reports/quality-gate/ for T-001 | Planned |
| REQ-002 | N/A — observed guard behavior is specified in requirements.md | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#api--contract-plan; design.md#test-strategy | Internal `Test-SudoSignatureConstantTime` helper | sdd-hook-guard.ps1 | TEST-003, TEST-004 | reports/quality-gate/ for T-002 | Planned |
| REQ-003 | N/A — observed contract behavior is specified in requirements.md | security-spec.md#security-tests; infra-spec.md#ci-cd-sequence | design.md#api--contract-plan; design.md#test-strategy | Internal structured `Test-EvidencePath` result | check-contract.ps1 | TEST-005, TEST-006 | reports/quality-gate/ for T-003 | Planned |
| REQ-004 | N/A — policy and user decision are specified in requirements.md | security-spec.md#trust-boundaries; infra-spec.md#ci-cd-sequence | design.md#risk-policy-lexical-implementation-contract; design.md#api--contract-plan | Risk-checker exit/diagnostic contract | risk policy/checkers; lite-spec and ship skills | TEST-007, TEST-008, TEST-009 | reports/quality-gate/ for T-004 | Planned |
| REQ-005 | N/A — existing duplicate invariants are specified in requirements.md | security-spec.md#trust-boundaries; infra-spec.md#ci-cd-sequence | design.md#native-module-loading-contract; design.md#human-copy-integrity-contract; design.md#protected-suffix-preservation | Canonical schema v1, generated module exports, human-copy manifest, embedded `AnchoredCopySession` native-handle contract | T-005 canonical/generator/modules/guard twins/test.yml; T-006 root-handle-relative copy runner | TEST-010, TEST-011, TEST-012, TEST-013; regression TEST-001..004 | reports/quality-gate/ for T-005 and T-006 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A | N/A | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface. |
| Frontend | N/A | N/A | frontend-spec.md#technology-stack | CLI/CI scripts are not a browser frontend. |
| Infrastructure | REQ-004, REQ-005 | AC-007..013 | infra-spec.md#ci-cd-sequence | CI generator check and workflow trust-anchor protection; no service deployment. |
| Security | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005 | AC-001..013 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | None. |

## Task Mapping

| Task | Requirement | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001 | TEST-001, TEST-002 | High-risk preflight, RED/GREEN parity evidence, independent quality-gate report |
| T-002 | REQ-002 | TEST-003, TEST-004 | High-risk preflight, RED/GREEN PS5.1 evidence, independent quality-gate report |
| T-003 | REQ-003 | TEST-005, TEST-006 | High-risk preflight, reviewed golden fixtures, independent quality-gate report |
| T-004 | REQ-004 | TEST-007, TEST-008, TEST-009 | High-risk preflight, sh/PS parity and workflow evidence, independent quality-gate report |
| T-005 | REQ-005 | TEST-010, TEST-011, TEST-012; TEST-001..004 regression | Critical generation/loading preflight, cross-model consensus, signed bundle, second approver, independent quality-gate report |
| T-006 | REQ-005 | TEST-013 | Critical publication/rollback preflight, cross-model consensus, signed bundle, second approver, independent quality-gate report |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-002 |
| AC-004 | TEST-004 | T-002 |
| AC-005 | TEST-005 | T-003 |
| AC-006 | TEST-006 | T-003 |
| AC-007 | TEST-007 | T-004 |
| AC-008 | TEST-008 | T-004 |
| AC-009 | TEST-009 | T-004 |
| AC-010 | TEST-010 | T-005 |
| AC-011 | TEST-011 | T-005 |
| AC-012 | TEST-012 | T-005 |
| AC-013 | TEST-013 | T-006 |

## Final Status

Update each row only from the corresponding saved quality-gate report and
deterministic test evidence.
