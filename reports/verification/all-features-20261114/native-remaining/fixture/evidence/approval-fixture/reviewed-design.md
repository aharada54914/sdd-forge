# Design (lite): inclusive-calendar-days

## 1. Approach

At `calendar_days.py:7`, change the valid-range return expression to `(last - first).days + 1` during the approved implementation task. Preserve `date.fromisoformat` for both inputs and the existing `last < first` guard and exception. This directly addresses INV-004 and BL-001–BL-006 without altering preserved BL-007–BL-009 behavior.

## 2. Files

- `calendar_days.py` — the sole planned production edit: include the second endpoint in the count.
- `test_calendar_days.py` and `test_inclusive_calendar_days.py` — retain unchanged and execute as verification; the latter already contains the permanent failing regressions.
- `reports/implementation/inclusive-calendar-days/T-001.md` — future implementation evidence, including commands, outcomes, and the pre-fix commit reference.
- Existing investigation, baseline, diagnosis, intake, and failure records remain intact; subsequent execution evidence uses new files.

## 3. Interface and semantics

Keep `days_inclusive(start: str, end: str) -> int`. Parsing and invalid-input behavior remain delegated to the current standard-library parser. Ordered valid endpoints yield elapsed calendar days plus one; reversed ranges retain `ValueError("end precedes start")`. No date iteration or end-date increment is needed, including at the maximum supported date.

## 4. Verification

The original tests and regression file are already committed as pre-fix evidence at `33d96159b2e0a91237c1129d6aa363da55a72e86`. Diagnosis recorded 12 failing positive-count assertions and passing rejection checks; those records remain historical evidence.

After approval, run the focused same-day command and `python3 -m unittest -v`. All six methods and every boundary/rejection subtest must pass without weakening or deleting assertions. Review the diff for the single arithmetic change and verify original tests and historical evidence hashes. Run the installed Lite completion workflow and its applicable checks; no quality verdict or fixed-production success is claimed in this design.

## 5. Constraints and approval

One task, no dependencies, Python stdlib only. Main regression risk is changing parsing or reversal rejection; the design leaves both unchanged and executes their existing tests. No UI design work applies. Implementation awaits the caller's inspection and permitted approval fixture; this author does not approve tasks.

## 6. Graduation

If later requirements add a higher-risk surface, rerun the unchanged risk check and follow `sdd-bootstrap-interviewer` for additive full-SDD artifacts before proceeding. Current scope remains the private helper bugfix; no full review or extra feature is introduced here.
