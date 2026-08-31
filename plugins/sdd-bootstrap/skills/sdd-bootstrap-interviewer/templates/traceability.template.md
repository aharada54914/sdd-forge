# Traceability: {{feature_name}}

Every Layer Spec cell must contain one or more canonical
`<layer>-spec.md#<section>` anchors, or
`N/A — cross-layer only: <reason>`. Blank cells and bare `N/A` are invalid.

| Requirement | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|
| REQ-001 | design.md#architecture | ux-spec.md#scope-and-user-journeys | src/ | TEST-001 | Planned |
| REQ-002 | design.md#components | frontend-spec.md#technology-stack | src/ | TEST-002 | Planned |
| REQ-003 | design.md#deployment--ci-plan | infra-spec.md#deployment-topology | scripts/ | TEST-003 | Planned |
| REQ-004 | design.md#security-boundaries | security-spec.md#trust-boundaries | src/ | TEST-004 | Planned |
| REQ-005 | design.md#cross-layer-dependencies | ux-spec.md#component-states; frontend-spec.md#state-shape | src/ | TEST-005 | Planned |
| REQ-006 | design.md#constraint-compliance | N/A — cross-layer only: repository metadata has no single layer owner | manifests/ | TEST-006 | Planned |

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
