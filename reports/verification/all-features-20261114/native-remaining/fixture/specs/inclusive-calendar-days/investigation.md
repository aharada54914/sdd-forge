# Investigation: inclusive-calendar-days

| Field | Value |
|---|---|
| Feature | inclusive-calendar-days |
| Mode | bugfix |
| Date | 2026-11-14 |
| Investigator | Independent native Codex agent `/root/investigate`; no model override or managed routing |

## Scope

Read-only source investigation of `days_inclusive`, README, and existing tests. Parent persisted these findings returned by the independent investigator. No tests/probes ran during investigation; diagnosis supplies runtime evidence.

## Summary

The helper parses ISO dates, rejects reversed ranges, and returns elapsed days. README requires both endpoints. Existing tests cover rejection, with no successful-count assertion.

## Findings

| INV-ID | Category | Finding | Evidence | Confidence |
|---|---|---|---|---|
| INV-001 | api | Existing private helper seam is `days_inclusive(start: str, end: str) -> int`. | `calendar_days.py:3`; `README.md:3`; `README.md:5` | high |
| INV-002 | business-rule | Both endpoints use `date.fromisoformat` before comparison. | `calendar_days.py:4` | high |
| INV-003 | business-rule | Reversed parsed ranges raise ValueError. | `calendar_days.py:5`; `calendar_days.py:6` | high |
| INV-004 | business-rule | Return expression counts elapsed days; README requires inclusive endpoints. | `calendar_days.py:7`; `README.md:5`; `README.md:9` | high |
| INV-005 | data | Only two local date values and subtraction; no mutable shared state or persistence. | `calendar_days.py:3`; `calendar_days.py:4`; `calendar_days.py:7` | high |
| INV-006 | dependency | Production datetime and test unittest are Python stdlib. | `calendar_days.py:1`; `test_calendar_days.py:1` | high |
| INV-007 | test-coverage | Existing tests assert reversed-range and invalid-start rejection only. | `test_calendar_days.py:4`; `test_calendar_days.py:5`; `test_calendar_days.py:9` | high |
| INV-008 | test-coverage | No same-date, adjacent, multi-day, month/year/leap boundary or invalid-end test exists. Documented command is unittest discovery. | `test_calendar_days.py:4`; `test_calendar_days.py:14`; `README.md:7` | high |
| INV-009 | constraint | Diagnosis may add failing tests, but production repair awaits approved implementation. Tasks must start Draft/Planned. | `AGENTS.md:54`; `AGENTS.md:55`; `AGENTS.md:56` | high |
| INV-010 | constraint | Network/authentication/database/UI/migration/API feature work is excluded; no UI inventory applies. | `README.md:5`; `AGENTS.md:53` | high |

## Open Questions

None for product behavior. Runtime verification remains pending diagnosis.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Existing rejection-only tests miss defective positive counts. | high | medium | Add red positive-count regression tests before any repair. |
| Repair alters rejection behavior. | low | medium | Retain original tests, add invalid-end coverage, preserve parser and guard. |
| Same-date-only test misses calendar boundaries. | medium | low | Add adjacent, multi-day, month/year/leap cases. |

## Recommended Next Steps

1. Diagnose with actual failing tests and targeted probes.
2. Preserve production bytes and original tests.
3. Prepare Lite Draft/Planned specifications from evidence, subject to mandatory entry checks.
