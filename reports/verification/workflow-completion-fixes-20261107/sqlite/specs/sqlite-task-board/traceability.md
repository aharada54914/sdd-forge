# Traceability: SQLite Task Board

Requirements are assigned to T-001 storage/unit, T-002 HTTP/integration and T-003 UI/browser; shared AC scopes differ by test level. No deferred or invented investigation findings. Application code/tests and verification evidence do not yet exist; all statuses remain Planned.

| Requirement | Investigation | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|---|
| REQ-001 | N/A — fresh project, no investigation | design.md#architecture | ux-spec.md#scope-and-user-journeys; frontend-spec.md#routes-and-api-client-strategy | T-003 browser / T-002 HTTP / T-001 storage: app.py, static/index.html, static/app.js | TEST-001 / AC-001 | Planned |
| REQ-002 | N/A — fresh project, no investigation | design.md#api--contract-plan | frontend-spec.md#admitted-api-and-dto-contract; security-spec.md#security-tests | T-003 browser / T-002 HTTP / T-001 storage: validation.py, repository.py, app.py, static/app.js | TEST-002 / AC-002 | Planned |
| REQ-003 | N/A — fresh project, no investigation | design.md#api--contract-plan | frontend-spec.md#state-shape | T-003 browser / T-002 HTTP / T-001 storage: repository.py, app.py, static/app.js | TEST-003 / AC-003 | Planned |
| REQ-004 | N/A — fresh project, no investigation | design.md#api--contract-plan | ux-spec.md#interaction-sequence; frontend-spec.md#admitted-api-and-dto-contract | T-003 browser / T-002 HTTP / T-001 storage: repository.py, app.py, static/app.js | TEST-004 / AC-004 | Planned |
| REQ-005 | N/A — fresh project, no investigation | design.md#data-plan | infra-spec.md#rollback; frontend-spec.md#state-shape | T-003 browser / T-002 HTTP / T-001 storage: schema.py, repository.py, app.py | TEST-005 / AC-005 | Planned |
| REQ-006 | N/A — fresh project, no investigation | design.md#design-system-compliance | ux-spec.md#responsive-behavior; ux-spec.md#design-tokens | T-003 browser / T-002 HTTP / T-001 storage: static/index.html, static/styles.css, design-system/build/tokens.css | TEST-006 / AC-006 | Planned |
| REQ-007 | N/A — fresh project, no investigation | design.md#test-strategy | ux-spec.md#accessibility; frontend-spec.md#empty-loading-error-and-success-behavior | T-003 browser / T-002 HTTP / T-001 storage: static/index.html, static/app.js, static/styles.css | TEST-007 / AC-007 | Planned |
| REQ-008 | N/A — fresh project, no investigation | design.md#security-boundaries | security-spec.md#trust-boundaries; security-spec.md#security-tests; infra-spec.md#infrastructure-as-code-and-scaling | T-003 browser / T-002 HTTP / T-001 storage: app.py, validation.py, repository.py, schema.py | TEST-008 / AC-008 | Planned |

## Layer Coverage
| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | REQ-001, REQ-002, REQ-003, REQ-004, REQ-006, REQ-007 | AC-001, AC-002, AC-003, AC-004, AC-006, AC-007 | ux-spec.md#scope-and-user-journeys; ux-spec.md#accessibility; ux-spec.md#responsive-behavior | None; T-001/T-002/T-003 |
| Frontend | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008 | frontend-spec.md#state-shape; frontend-spec.md#admitted-api-and-dto-contract | None; T-001/T-002/T-003 |
| Infrastructure | REQ-005, REQ-008 | AC-005, AC-008 | infra-spec.md#deployment-topology; infra-spec.md#rollback | None; local-only T-001/T-002/T-003 |
| Security | REQ-002, REQ-005, REQ-008 | AC-002, AC-005, AC-008 | security-spec.md#trust-boundaries; security-spec.md#security-tests | None; T-001/T-002/T-003 |

## Final Status
T-001, T-002, T-003 remain Planned / Draft. This plan body is frozen after task review. Actual delivery evidence maps belong in non-frozen reports/implementation/sqlite-task-board/verification-addendum.md; only plugin-permitted lifecycle/status normalization may update frozen statuses. Implementation reports are claims, not independent verification.
