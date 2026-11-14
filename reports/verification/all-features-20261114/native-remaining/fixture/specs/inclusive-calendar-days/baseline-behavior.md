# Baseline Behavior: inclusive-calendar-days

| Field | Value |
|---|---|
| Feature | inclusive-calendar-days |
| Date | 2026-11-14 |
| Investigator | Independent native Codex agent `/root/investigate` |

## Behaviors

Source-derived, not runtime observations. Diagnosis will execute these cases.

| BL-ID | Trigger (start, end) | Observable Behavior | Evidence | Must Preserve | Verification Hint |
|---|---|---|---|---|---|
| BL-001 | 2026-11-14, 2026-11-14 | 0 instead of 1 | `calendar_days.py:7`; `README.md:9` | no | assert 1 |
| BL-002 | 2026-11-14, 2026-11-15 | 1 instead of 2 | `calendar_days.py:7`; `README.md:5` | no | assert 2 |
| BL-003 | 2026-11-14, 2026-11-20 | 6 instead of 7 | `calendar_days.py:7`; `README.md:5` | no | assert 7 |
| BL-004 | 2026-01-31, 2026-02-01 | 1 instead of 2 | `calendar_days.py:7`; `README.md:5` | no | assert 2 |
| BL-005 | 2026-12-31, 2027-01-01 | 1 instead of 2 | `calendar_days.py:7`; `README.md:5` | no | assert 2 |
| BL-006 | 2024-02-28, 2024-03-01 | 2 instead of 3 | `calendar_days.py:7`; `README.md:5` | no | assert 3 including leap day |
| BL-007 | 2026-11-14, 2026-11-13 | ValueError | `calendar_days.py:5`; `test_calendar_days.py:5` | yes | retain original test |
| BL-008 | 2026-02-30, 2026-03-01 | ValueError | `calendar_days.py:4`; `test_calendar_days.py:9` | yes | retain original test |
| BL-009 | 2026-02-01, 2026-02-30 | ValueError | `calendar_days.py:4`; `README.md:5` | yes | add invalid-end test |

## Known Defects

BL-001 through BL-006 are intentionally not preserved: every valid count omits one endpoint. Replacement is the respective expected inclusive count above. Evidence: `calendar_days.py:7`, `README.md:5`.

## Environment Notes

No tests/probes ran in the read-only investigator. Runtime version remains unmeasured at this stage. Documented command: `python3 -m unittest -v`. The helper has no clock/timezone access (`calendar_days.py:1`, `calendar_days.py:4`, `calendar_days.py:7`). Production repair is deferred until approval.
