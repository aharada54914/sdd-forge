# Diagnosis Report: inclusive-calendar-days

- **Symptom (user's words)**: days_inclusive('2026-11-14','2026-11-14') returns zero instead of one.
- **Source**: README.md:5 and :9; complete request in evidence/intake/user-source.txt.
- **Identity**: native Codex parent `/root`; separate investigator `/root/investigate`. No managed routing or model overrides.
- **Context**: AGENTS.md and investigation/codemap/baseline read; no module ADR or CONTEXT.md exists.

## Phase 1 — Feedback loop

Already-run command:

```sh
python3 -m unittest -v test_inclusive_calendar_days.InclusiveCalendarDays.test_same_date
```

Actual red output excerpt (complete raw output in evidence/diagnosis/phase1-red.txt):

```text
test_same_date (test_inclusive_calendar_days.InclusiveCalendarDays.test_same_date) ... FAIL
AssertionError: 0 != 1
Ran 1 test in 0.003s
FAILED (failures=1)
exit_code=1
elapsed_seconds=0.062115
```

Loop properties: red-capable [x] · deterministic [x] · fast [x] · agent-runnable [x]. The test directly calls production with fixed literal dates and asserts 1. Existing suite passed its two rejection tests first (existing-suite.txt).

## Phase 2 — Reproduce + minimize

Repeated the exact loop: `0 != 1`, exit 1, about 0.06 seconds (phase2-minimized-red.txt). One function call with equal valid endpoints and one assertion is the minimal correct seam. No clock, external fixture, service, or state is involved. This reproduces the user's exact symptom.

## Phase 3 — Hypotheses (ranked, falsifiable)

Presented in user-facing commentary before probing:

1. If elapsed-day arithmetic omits one endpoint, comparing elapsed and inclusive counts gives a consistent difference of one; an isolated arithmetic probe adding one matches fixed expected values. **Survived**.
2. If parsing changes dates, parsed ISO values reveal a mismatch. **Refuted for inspected inputs**: all eight round-trip unchanged.
3. If the equality/range guard mishandles equal dates, equal/ascending/reversed inputs expose incorrect branching. **Refuted**: equal/ascending pass; reversed raises ValueError correctly.

## Phase 4 — Instrumentation

Three separate Python process-memory probes, one boundary each, tagged DEBUG-calendar-h1/h2/h3. Sources and actual outputs are in evidence/diagnosis/phase4-h1-arithmetic.txt, phase4-h2-parser.txt, and phase4-h3-guard.txt. All exited 0. No production/test instrumentation was inserted.

Actual count → inclusive expectation: same date 0→1, adjacent 1→2, multi-day 6→7, month boundary 1→2, year boundary 1→2, leap interval 2→3. Each elapsed-plus-one probe matched its fixed oracle. Parsing preserved eight ISO values. Reversal comparison was false for equal/ascending and true for reversed; reversed raised `end precedes start`.

The native PreToolUse deterministic gate rejected an initial probe wrapper for ambiguous shell parsing; that command did not execute. Simplifying its transcript formatting allowed the same authorized probes to execute. A later combined report-writing/commit command received the same rejection and did not execute; report writing and VCS commands were subsequently separated. No hook bypass or permission change occurred.

## Phase 5 — Root cause + fix

- **Root cause**: calendar_days.py:7 returns elapsed days, omitting the extra endpoint required by README.md:5 (INV-004; BL-001–BL-006).
- **Correct seam existed?** Yes: direct call to calendar_days.days_inclusive.
- **Regression test**: test_inclusive_calendar_days.py. Exact symptom written/run red first; extended with adjacent/multi-day/month/year/leap intervals, Gregorian century cases, date extrema, invalid inputs at either endpoint, and reversed boundaries.
- **Test-before-fix**: full discovery ran 6 methods with 12 failing positive-count assertions, exit 1 (phase5-full-red.txt). Original and expanded rejection checks ran 4 methods, all passing, exit 0 (phase5-rejection-preserved.txt).
- **Fix summary**: NOT APPLIED. The repair part of phase 5 is deferred by this skill's Boundaries, AGENTS.md, and user instruction to an approved implement-task. Proposed minimal repair: add one to the elapsed-day result, retaining parsing and the reversal guard.
- **Cleanup**: no temporary DEBUG probes in root Python files. Only permanent regression tests remain. All original hashes still match (unchanged-original-hashes.json).

## Handoff

Lite candidate, subject to mandatory lite-spec entry checks. Preserve INV-002/INV-003 and BL-007–BL-009 while correcting BL-001–BL-006 at the existing seam, with stdlib and no new dependencies. Stop before approval/implementation. No fixed-production green run is claimed.
