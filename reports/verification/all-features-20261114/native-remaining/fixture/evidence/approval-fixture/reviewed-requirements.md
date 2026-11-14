# Requirements (lite): inclusive-calendar-days

- **Source**: complete caller resubmission in `evidence/intake/user-source-revised.txt`; existing contract in `README.md:5`; `reports/diagnosis/inclusive-calendar-days.md`.
- **Purpose**: Correct the private calendar helper's off-by-one result so every valid ordered date range counts both endpoints. Retain its existing input rejection behavior and standard-library implementation.

## Requirements

| ID | Requirement | Source |
|---|---|---|
| REQ-001 | `days_inclusive(start, end)` returns the integer count of calendar dates from start through end, inclusive. Equal valid dates return 1; all other valid ordered ranges return elapsed days plus 1. | INV-001, INV-004; BL-001–BL-006 |
| REQ-002 | Counts remain correct across adjacent days, multiple days, month/year transitions, leap days, and Gregorian century boundaries, using the existing date semantics. | INV-002, INV-006, INV-008; BL-002–BL-006; diagnosis boundary regressions |
| REQ-003 | Invalid dates at either endpoint and reversed ranges continue to raise `ValueError`. Preserve the existing parser and range guard, including the existing reversed-range message; do not introduce a new input-format policy. | INV-002, INV-003, INV-007; BL-007–BL-009 |
| REQ-004 | Use the existing function seam and Python stdlib without new dependencies or additional product behavior. Preserve the original rejection tests, recorded failing regressions, investigation, and genuine red diagnostic evidence. | INV-005, INV-006, INV-009, INV-010; caller resubmission |

## Observable acceptance examples

| Start | End | Expected |
|---|---|---|
| 2026-11-14 | 2026-11-14 | 1 |
| 2026-11-14 | 2026-11-15 | 2 |
| 2026-11-14 | 2026-11-20 | 7 |
| 2026-01-31 | 2026-02-01 | 2 |
| 2026-12-31 | 2027-01-01 | 2 |
| 2024-02-28 | 2024-03-01 | 3 |
| 2024-02-29 | 2024-02-29 | 1 |
| 2026-02-28 | 2026-03-01 | 2 |
| 2000-02-28 | 2000-03-01 | 3 |
| 1900-02-28 | 1900-03-01 | 2 |
| 0001-01-01 | 0001-01-01 | 1 |
| 9999-12-31 | 9999-12-31 | 1 |

Existing regression tests also require `ValueError` for invalid start/end values (including invalid leap dates and malformed strings) and reversed ordinary/month/year/leap ranges. Keep all those assertions unchanged.

## Scope exclusions

- authentication, authorization, oauth, oidc
- servers, sharing, sync
- external APIs, third-party APIs
- credentials, tokens, passwords, secrets
- MCP, GitHub Actions

## Other non-goals

No application UI, persistence, network behavior, new dependency, or additional feature. No production repair occurs during specification preparation.

## Open Questions

None. README, the revised caller request, and the existing diagnosis define the behavior.
