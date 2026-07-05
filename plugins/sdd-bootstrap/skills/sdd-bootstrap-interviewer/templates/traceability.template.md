# Traceability: {{feature_name}}

Every Layer Spec cell must contain one or more canonical
`<layer>-spec.md#<section>` anchors, or
`N/A — cross-layer only: <reason>`. Blank cells and bare `N/A` are invalid.

| Requirement | Investigation | Design | Layer Spec | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | INV-001, BL-001 | design.md#architecture | ux-spec.md#scope-and-user-journeys | openapi.yaml / schema | src/ | TEST-001 | tests/ | verification/TEST-001.log | Planned |
| REQ-002 | INV-002 | design.md#components | frontend-spec.md#technology-stack | schema | src/ | TEST-002 | tests/ | verification/TEST-002.log | Planned |
| REQ-003 | INV-003 | design.md#deployment--ci-plan | infra-spec.md#deployment-topology | N/A | scripts/ | TEST-003 | tests/ | verification/TEST-003.log | Planned |
| REQ-004 | INV-004 | design.md#security-boundaries | security-spec.md#trust-boundaries | policy | src/ | TEST-004 | tests/ | verification/TEST-004.log | Planned |
| REQ-005 | INV-005 | design.md#cross-layer-dependencies | ux-spec.md#component-states; frontend-spec.md#state-shape | contract | src/ | TEST-005 | tests/ | verification/TEST-005.log | Planned |
| REQ-006 | INV-006 | design.md#constraint-compliance | N/A — cross-layer only: repository metadata has no single layer owner | N/A | manifests/ | TEST-006 | tests/ | verification/TEST-006.log | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | {{ux_requirements}} | {{ux_acceptance}} | ux-spec.md#scope-and-user-journeys | {{ux_gaps_or_none}} |
| Frontend | {{frontend_requirements}} | {{frontend_acceptance}} | frontend-spec.md#technology-stack | {{frontend_gaps_or_none}} |
| Infrastructure | {{infra_requirements}} | {{infra_acceptance}} | infra-spec.md#deployment-topology | {{infra_gaps_or_none}} |
| Security | {{security_requirements}} | {{security_acceptance}} | security-spec.md#trust-boundaries | {{security_gaps_or_none}} |

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Keep implementation reports as claims, not verification evidence.
