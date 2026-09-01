# Traceability: epic-197-a9-dogfood

Status: Draft

## Requirement Mapping

| REQ | Investigation | Design / Layer | AC / TEST | Task | Status |
|---|---|---|---|---|---|
| REQ-001 | INV-002, INV-004, INV-007, INV-015 | design Data Plan; security B1 | AC/TEST-001–002 | T-002 | Planned |
| REQ-002 | INV-005, INV-012 | design Components; OQ-001 | AC/TEST-003–004 | T-002 | Planned |
| REQ-003 | INV-006, INV-007, INV-017, INV-023 | design Data/Test Plan; OQ-002 | AC/TEST-005–006 | T-002 | Planned |
| REQ-004 | INV-009–INV-014 | security B4/B5 | AC/TEST-007 | T-002 | Planned |
| REQ-005 | INV-008, INV-016, INV-025 | design API Plan; resolved OQ-005; OQ-006 | AC/TEST-008–009 | T-003 | Planned |
| REQ-006 | INV-001, INV-017, INV-022 | design Architecture/Test Plan | AC/TEST-010–011, 027 | T-004 | Planned |
| REQ-007 | INV-002, INV-017 | design promotion concept; OQ-003 | AC/TEST-012–013 | T-004 | Planned |
| REQ-008 | INV-002, INV-022 | design phase table; post-promotion feature evidence | AC/TEST-014–015, 028 | T-005 | Planned |
| REQ-009 | INV-003, INV-015 | security B1/B3; OQ-004 | AC/TEST-016–018 | T-005 | Planned |
| REQ-010 | INV-019, INV-022 | design WFI component/result | AC/TEST-019, 029 | T-006 | Planned |
| REQ-011 | INV-017, INV-018, INV-020, INV-024 | design Global Constraints | AC/TEST-020–021 | T-001 | Planned |
| REQ-012 | INV-001, INV-010, INV-013, INV-014 | infra CI/CD; frontend Testing | AC/TEST-022–024 | T-005 | Planned |
| REQ-013 | INV-006, INV-023 | design Context Data Plan; UX adoption | AC/TEST-025 | T-002 | Planned |
| REQ-014 | INV-017, INV-024 | design Global Constraints; frontend Dependencies | AC/TEST-026 | T-001 | Planned |

## Deferred / Non-Task Acceptance Criteria

None. All 29 acceptance criteria map to a planned task. TEST-029 requires an
explicit `none` result when no reproducible friction exists; it is still a task
assertion, not deferred work.

## Layer Coverage

| Layer | Requirements | Rationale |
|---|---|---|
| UX | REQ-006–REQ-010, REQ-013 | operator evidence, promotion, rollback, WFI, bootstrap-ownership journeys |
| Frontend | N/A UI; contract support for all | no browser/mobile surface |
| Infrastructure | REQ-006–REQ-014 | CI, release, environments, rollback, dependencies |
| Security | REQ-001, REQ-004, REQ-007–REQ-009, REQ-012 | protected approval, tokens, publication, weakening |

## Task Mapping

| Task | Requirements | Tests | State |
|---|---|---|---|
| T-001 | REQ-011, REQ-014 | TEST-020–021, TEST-026 | Draft / Planned |
| T-002 | REQ-001–REQ-004, REQ-013 | TEST-001–007, TEST-025 | Draft / Planned |
| T-003 | REQ-005 | TEST-008–009 | Draft / Planned |
| T-004 | REQ-006–REQ-007 | TEST-010–013, TEST-027 | Draft / Planned |
| T-005 | REQ-008–REQ-009, REQ-012 | TEST-014–018, TEST-022–024, TEST-028 | Draft / Planned |
| T-006 | REQ-010 | TEST-019, TEST-029 | Draft / Planned |

## Acceptance Mapping

| Range | Task |
|---|---|
| AC/TEST-001–007 | T-002 |
| AC/TEST-008–009 | T-003 |
| AC/TEST-010–013 | T-004 |
| AC/TEST-014–018 | T-005 |
| AC/TEST-019 | T-006 |
| AC/TEST-020–021 | T-001 |
| AC/TEST-022–024 | T-005 |
| AC/TEST-025 | T-002 |
| AC/TEST-026 | T-001 |
| AC/TEST-027 | T-004 |
| AC/TEST-028 | T-005 |
| AC/TEST-029 | T-006 |

## Final Status

All requirements, acceptance tests, and tasks are Planned. No implementation or
independent verification evidence exists. Human decisions OQ-001–OQ-004 and
OQ-006 and all mandated review gates remain pending; OQ-005 is issue-resolved.
