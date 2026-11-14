# Traceability: task-board

Rows map to implementation owners T-001 (store), T-002 (HTTP), T-003 (tokens), T-004 (UI) and T-005 (final acceptance). No existing-code investigation applies: this is a new app. Evidence below is planned, not a verification claim.

| Requirement | Investigation | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|---|
| REQ-001 | N/A — greenfield | design.md#api--contract-plan | ux-spec.md#scope-and-user-journeys; frontend-spec.md#state-shape | T-001/T-002/T-004/T-005: server.py, web/app.js | TEST-001, TEST-002 | Done |
| REQ-002 | N/A — greenfield | design.md#ui-state-and-reference-mapping | ux-spec.md#component-states; frontend-spec.md#state-shape | T-001/T-002/T-004/T-005: store.py, web/app.js | TEST-003 | Done |
| REQ-003 | N/A — greenfield | design.md#api--contract-plan | ux-spec.md#interaction-sequence | T-001/T-002/T-004/T-005: store.py, web/app.js | TEST-004 | Done |
| REQ-004 | N/A — greenfield | design.md#storage-transaction-and-restart-semantics | infra-spec.md#data-residency-and-retention | T-001/T-002/T-005: store.py, server.py | TEST-003, TEST-004, TEST-005, TEST-011 | Done |
| REQ-005 | N/A — greenfield | design.md#ui-state-and-reference-mapping | frontend-spec.md#api-client-strategy; ux-spec.md#component-states | T-004/T-005: web/app.js | TEST-006, TEST-007 | Done |
| REQ-006 | N/A — greenfield | design.md#design-system-compliance | ux-spec.md#responsive-behavior; ux-spec.md#design-tokens | T-003/T-004/T-005: web/styles.css, scripts/generate_tokens.py | TEST-008 | Done |
| REQ-007 | N/A — greenfield | design.md#request-trust-checks | security-spec.md#trust-boundaries; infra-spec.md#deployment-topology | T-002/T-005: server.py | TEST-009, TEST-012 | Done |
| REQ-008 | N/A — greenfield | design.md#verification-strategy-and-evidence-matrix | ux-spec.md#accessibility; frontend-spec.md#testing | T-004/T-005: web/app.js, tests/browser_checks.py | TEST-008, TEST-010 | Done |

## Task Mapping
T-001 → REQ-001..004 (store); T-002 → REQ-001..004/007 (HTTP); T-003 → REQ-006 (tokens); T-004 → REQ-001..003/005/006/008 (UI); T-005 → REQ-001..008 → AC-001..013 → TEST-001..012 (final acceptance owner). TEST-001 covers AC-001/002; TEST-002 AC-003; TEST-003 AC-004; TEST-004 AC-005; TEST-005 AC-006; TEST-006 AC-007; TEST-007 AC-008; TEST-008 AC-009; TEST-009 AC-010; TEST-010 AC-011; TEST-011 AC-012; TEST-012 AC-013.

## Layer Coverage
| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | REQ-001..008 | AC-001..005, AC-007..011 | ux-spec.md#scope-and-user-journeys | None |
| Frontend | REQ-001..003, REQ-005/006/008 | AC-001..005, AC-007..011 | frontend-spec.md#state-shape | None |
| Infrastructure | REQ-004/007 | AC-006/012/013 | infra-spec.md#deployment-topology | None |
| Security | REQ-004/007 | AC-010/012/013 | security-spec.md#trust-boundaries | None |

## Final Status
All delivery statuses remain Planned until actual evidence and quality-gate findings justify lifecycle updates. Implementation reports are claims; independent quality-gate owns final verification and Done.
