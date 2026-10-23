# Traceability: Structural Error Prevention

Preliminary planning map; all implementation and verification remain Planned. Task references denote proposals in tasks-proposal.md, not a formal task plan. Author: Codex. No formal review evidence or approval is supplied by this map.

| Requirement | Investigation | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|---|
| REQ-001 | N/A — existing contributor source map and Issue #601; no new investigation identifiers | design.md#source-map | ux-spec.md#scope-and-user-journeys | docs/contributor/issue-601-structural-prevention.md | TEST-001a, TEST-001b, TEST-001c, TEST-003a, TEST-003b, TEST-003c, TEST-003d, TEST-003e, TEST-003f, TEST-003g, TEST-003h, TEST-003i, TEST-003j, TEST-003k, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h, TEST-005i, TEST-005j | Planned |
| REQ-002 | N/A — current-tree excluded entry and call-site check recorded in design | design.md#registration-and-regression-integration | infra-spec.md#deployment-topology | tests/verification-catalog.json | TEST-002a, TEST-002b, TEST-002c | Planned |
| REQ-003 | N/A — existing fixture sources enumerated in design | design.md#registration-and-regression-integration | infra-spec.md#runtime-and-failure-handling | tests/human-copy-mirrors-classification.tests.py; tests/cross-model-encoding.tests.ps1 (bounded BOM negative); existing self-improvement suite (reuse) | TEST-003a, TEST-003b, TEST-003c, TEST-003d, TEST-003e, TEST-003f, TEST-003g, TEST-003h, TEST-003i, TEST-003j, TEST-003k, TEST-004a, TEST-004b, TEST-004c, TEST-004d, TEST-004e, TEST-004f, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h, TEST-005i, TEST-005j | Planned |
| REQ-004 | N/A — existing #619/#620 corrections and source map | design.md#evidence-and-handoff | ux-spec.md#component-states; security-spec.md#trust-boundaries | docs/contributor/issue-601-structural-prevention.md | TEST-004a, TEST-004b, TEST-004c, TEST-004d, TEST-004e, TEST-004f, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h, TEST-005i, TEST-005j, TEST-009a, TEST-009b, TEST-009c, TEST-009d, TEST-009e | Planned |
| REQ-005 | N/A — existing consumer map; no new evidence identifiers | design.md#duplicate-validator-assessment | security-spec.md#compatibility-controls | existing approval/admission/mirror/generator consumers (unchanged); contributor candidate assessment | TEST-006a, TEST-006b, TEST-006c, TEST-006d, TEST-006e, TEST-006f, TEST-006g, TEST-006h, TEST-006i, TEST-006j, TEST-006k, TEST-006l, TEST-006m | Planned |
| REQ-006 | N/A — existing catalog runner and native suite routes | design.md#registration-and-regression-integration | infra-spec.md#runtime-and-failure-handling | tests/verification-catalog.json; existing catalog/native suites | TEST-007a, TEST-007b, TEST-007c, TEST-007d, TEST-007e, TEST-007f | Planned |
| REQ-007 | N/A — Issue #600 ownership and existing retrospective conventions | design.md#evidence-and-handoff | ux-spec.md#scope-and-user-journeys; security-spec.md#compatibility-controls | docs/contributor/issue-601-structural-prevention.md | TEST-008a, TEST-008b, TEST-008c, TEST-008d, TEST-009a, TEST-009b, TEST-009c, TEST-009d, TEST-009e | Planned |

## Proposed Task Coverage

| Task | Requirements | Tests | Status |
|---|---|---|---|
| T-001 | REQ-002, REQ-005, REQ-006 | TEST-002a, TEST-002b, TEST-002c, TEST-006a, TEST-006b, TEST-006c, TEST-006d, TEST-006e, TEST-006f, TEST-006g, TEST-006h, TEST-006i, TEST-006j, TEST-006k, TEST-006l, TEST-006m, TEST-007a, TEST-007b, TEST-007c, TEST-007d, TEST-007e, TEST-007f | Planned |
| T-002 | REQ-001, REQ-003, REQ-004, REQ-005, REQ-006 | TEST-003a, TEST-003b, TEST-003c, TEST-003d, TEST-003e, TEST-003f, TEST-003g, TEST-003h, TEST-003i, TEST-003j, TEST-003k, TEST-004a, TEST-004b, TEST-004c, TEST-004d, TEST-004e, TEST-004f, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h, TEST-005i, TEST-005j, TEST-006a, TEST-006b, TEST-006c, TEST-006d, TEST-006e, TEST-006f, TEST-006g, TEST-006h, TEST-006i, TEST-006j, TEST-006k, TEST-006l, TEST-006m, TEST-007a, TEST-007b, TEST-007c, TEST-007d, TEST-007e, TEST-007f | Planned |
| T-003 | REQ-001, REQ-004, REQ-005, REQ-007 | TEST-001a, TEST-001b, TEST-001c, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h, TEST-005i, TEST-005j, TEST-006a, TEST-006b, TEST-006c, TEST-006d, TEST-006e, TEST-006f, TEST-006g, TEST-006h, TEST-006i, TEST-006j, TEST-006k, TEST-006l, TEST-006m, TEST-008a, TEST-008b, TEST-008c, TEST-008d, TEST-009a, TEST-009b, TEST-009c, TEST-009d, TEST-009e | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | REQ-001, REQ-004, REQ-007 | AC-001, AC-004, AC-007 | ux-spec.md#scope-and-user-journeys | Contributor evidence reading only; no UI entry point |
| Frontend | N/A — no frontend change | N/A — no UI acceptance | frontend-spec.md#technology-stack | No routes/components/client state |
| Infrastructure | REQ-002, REQ-003, REQ-006 | AC-002, AC-003, AC-006 | infra-spec.md#deployment-topology | Native results unexecuted in Draft |
| Security | REQ-004, REQ-005, REQ-007 | AC-004, AC-005, AC-007 | security-spec.md#trust-boundaries | Existing gates preserved; no new authority |

## Final Status

No implementation, test success, gate verdict, human approval, held-out result or retention outcome is recorded here. Later evidence belongs in the tasks' non-frozen verification/implementation addenda. Only authorized normalized status updates may touch this map after a binding review; implementation reports are claims, not independent quality-gate evidence.
