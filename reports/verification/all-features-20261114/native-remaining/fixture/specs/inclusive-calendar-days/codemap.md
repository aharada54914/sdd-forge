# Codemap: inclusive-calendar-days

| Field | Value |
|---|---|
| Feature | inclusive-calendar-days |
| Date | 2026-11-14 |
| Derived From | investigation.md (INV-001–INV-010) |

Read this map first; regenerate whenever investigation changes.

## Entry Points

| Path | Role | Evidence |
|---|---|---|
| `calendar_days.py` | Importable helper | `calendar_days.py:3` |
| `test_calendar_days.py` | Unit tests and direct runner | `test_calendar_days.py:4`; `test_calendar_days.py:13` |
| `README.md` | Contract and test command | `README.md:5`; `README.md:7` |

## Module Topology

| Module / Directory | Responsibility | Key Files | Depends On |
|---|---|---|---|
| Helper | Parse → reject reversal → count | `calendar_days.py` | datetime.date |
| Tests | Rejection assertions | `test_calendar_days.py` | unittest, helper |
| Contract/workflow | Intended behavior and approval boundary | README.md, AGENTS.md | None |

## Key Symbols

| Symbol | Kind | Location | Referenced By |
|---|---|---|---|
| days_inclusive | function | `calendar_days.py:3` | `test_calendar_days.py:2`; `README.md:5` |
| date.fromisoformat | function | `calendar_days.py:4` | days_inclusive |
| ExistingChecks | class | `test_calendar_days.py:4` | unittest discovery |
| test_reversed_range | function | `test_calendar_days.py:5` | ExistingChecks |
| test_invalid_date | function | `test_calendar_days.py:9` | ExistingChecks |

## External Dependencies

| Dependency | Version / Source | Used From |
|---|---|---|
| datetime.date | Python stdlib; version pending runtime diagnosis | `calendar_days.py:1` |
| unittest | Python stdlib | `test_calendar_days.py:1` |

No third-party service/package in the inspected target.

## Test Map

| Test Suite | Covers | Location |
|---|---|---|
| ExistingChecks.test_reversed_range | ValueError on reversal | `test_calendar_days.py:5` |
| ExistingChecks.test_invalid_date | ValueError on invalid start | `test_calendar_days.py:9` |

## Not Covered

Runtime outcomes and Python version await diagnosis. Positive counts and invalid-end rejection have no existing tests. UI/network/database/authentication/migration features are outside scope. Preserve existing ISO parser behavior; no expanded format policy is requested.
