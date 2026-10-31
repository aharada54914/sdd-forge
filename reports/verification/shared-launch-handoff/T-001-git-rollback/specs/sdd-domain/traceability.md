# Traceability: sdd-domain (DDD Upstream Lane Plugin)

| Requirement | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|
| REQ-001 | Components; Architecture | ux-spec.md#scope-and-user-journeys | T-001, T-004 | AC-001, AC-011 | Planned |
| REQ-002 | Data Plan; API / Contract Plan | ux-spec.md#interaction-sequence | T-001, T-002, T-004 | AC-002, AC-003, AC-016 | Planned |
| REQ-003 | Components | ux-spec.md#component-states | T-002, T-003 | AC-004 | Planned |
| REQ-004 | Architecture; Assumptions | N/A — cross-layer only: review/approval-gate infrastructure has no single UX/frontend/infra/security owner | T-005, T-011 | AC-005, AC-006, AC-017 | Planned |
| REQ-005 | Security Boundaries | security-spec.md#authorization | T-005, T-006 | AC-007, AC-014 | Planned |
| REQ-006 | Cross-Layer Dependencies | N/A — cross-layer only: injects into the existing cross-plugin bootstrap Phase 1 flow, which has no single layer owner | T-007 | AC-008 | Planned |
| REQ-007 | Constraint Compliance | security-spec.md#security-tests | T-008 | AC-009, AC-015 | Planned |
| REQ-008 | Constraint Compliance | N/A — cross-layer only: absence-regression is a whole-repository invariant, not a single layer's concern | T-007 | AC-010 | Planned |
| REQ-009 | Deployment / CI Plan | infra-spec.md#cicd-sequence | T-001, T-010 | AC-011 | Planned |
| REQ-010 | Test Strategy | infra-spec.md#observability | T-009 | AC-012 | Planned |
| REQ-011 | Components | ux-spec.md#accessibility | T-002 | AC-013 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | REQ-001, REQ-002, REQ-003, REQ-011 | AC-001, AC-002, AC-004, AC-013, AC-016 | ux-spec.md#scope-and-user-journeys, #interaction-sequence, #component-states, #accessibility | None — CLI-only feature; graphical-UI sections are reasoned N/A within ux-spec.md itself |
| Frontend | None | None | frontend-spec.md#technology-stack | N/A — no change: no graphical frontend, no client-side state (frontend-spec.md) |
| Infrastructure | REQ-009, REQ-010 | AC-011, AC-012 | infra-spec.md#deployment-topology, #cicd-sequence, #observability | None — no deployed services; CI-only surface |
| Security | REQ-005, REQ-006, REQ-007 | AC-007, AC-008, AC-009, AC-014, AC-015 | security-spec.md#trust-boundaries, #authorization, #stride-analysis, #security-tests | None |

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Keep implementation reports as claims, not verification evidence.
