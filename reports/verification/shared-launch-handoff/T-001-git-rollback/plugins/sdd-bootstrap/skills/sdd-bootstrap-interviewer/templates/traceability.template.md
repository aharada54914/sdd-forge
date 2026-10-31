# Traceability: {{feature_name}}

Every Layer Spec cell must contain one or more canonical
`<layer>-spec.md#<section>` anchors, or
`N/A — cross-layer only: <reason>`. Blank cells and bare `N/A` are invalid.

The Investigation column records the actual supporting INV/BL identifiers from
`investigation.md`; use a reasoned N/A when no investigation item applies.
Do not invent evidence identifiers merely to fill the column.

| Requirement | Investigation | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|---|
| REQ-001 | {{req_001_investigation_ids_or_reasoned_na}} | design.md#architecture | ux-spec.md#scope-and-user-journeys | src/ | TEST-001 | Planned |
| REQ-002 | {{req_002_investigation_ids_or_reasoned_na}} | design.md#components | frontend-spec.md#technology-stack | src/ | TEST-002 | Planned |
| REQ-003 | {{req_003_investigation_ids_or_reasoned_na}} | design.md#deployment--ci-plan | infra-spec.md#deployment-topology | scripts/ | TEST-003 | Planned |
| REQ-004 | {{req_004_investigation_ids_or_reasoned_na}} | design.md#security-boundaries | security-spec.md#trust-boundaries | src/ | TEST-004 | Planned |
| REQ-005 | {{req_005_investigation_ids_or_reasoned_na}} | design.md#cross-layer-dependencies | ux-spec.md#component-states; frontend-spec.md#state-shape | src/ | TEST-005 | Planned |
| REQ-006 | {{req_006_investigation_ids_or_reasoned_na}} | design.md#constraint-compliance | N/A — cross-layer only: repository metadata has no single layer owner | manifests/ | TEST-006 | Planned |

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
