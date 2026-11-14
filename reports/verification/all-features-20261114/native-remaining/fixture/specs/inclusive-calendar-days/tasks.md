# Tasks (lite): inclusive-calendar-days

## T-001 Correct the inclusive calendar-day count
Approval: Approved
Status: Done

### Scope

- Satisfy REQ-001–REQ-004 using design.md sections 1–4. Source findings: INV-001–INV-010; correct BL-001–BL-006 and preserve BL-007–BL-009.
- After approval, add one to the existing elapsed-day return in `calendar_days.py`; keep the function signature, parser, reversal guard, and exception behavior unchanged.
- Preserve both existing test files and all prior investigation, diagnosis, intake, and failure evidence. No new dependency or additional product behavior.
- Record actual implementation/check results in `reports/implementation/inclusive-calendar-days/T-001.md`, referencing pre-fix commit `33d96159b2e0a91237c1129d6aa363da55a72e86`.
- Dependencies: none. This is the first and only task.

### Done When

- Same-day, adjacent, multi-day, month/year, leap-day, century, and date-extrema examples in requirements.md return the specified inclusive counts.
- Invalid dates at either endpoint and reversed ranges still raise `ValueError`; existing rejection behavior is unchanged.
- `python3 -m unittest -v test_inclusive_calendar_days.InclusiveCalendarDays.test_same_date` and `python3 -m unittest -v` both exit 0, with all existing assertions retained.
- The reviewed production diff is limited to the inclusive-count correction; historical evidence and both test files are preserved, with no temporary debug probes.
- Implementation evidence is recorded and the installed Lite gate completes its required checks. This draft does not assert any implementation or quality result.

### Blockers

- Implementation awaits caller inspection and the previously permitted disposable approval fixture. No product question or environment blocker remains after the revised intake checks.
