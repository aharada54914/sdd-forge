# Debugging & Error-Recovery Policy

A systematic method for diagnosing failures and recovering a stuck task. Use it
when applying a fix under `fix-by-review-ticket`, when a `quality-gate` check
fails for a non-obvious reason, or when `implement-task` hits a failure it must
understand before deciding whether to continue or set the task `Blocked`.

The goal is the smallest correct fix backed by evidence — not the fastest
green. A fix that hides a symptom without addressing the cause is a `Critical`
finding under `evaluation-rubric.md`.

## Method

1. **Reproduce.** Get a reliable, minimal repro and capture the exact failing
   output (command, stack trace, log) as evidence. An intermittent failure is
   not understood until it is reproducible or its non-determinism is explained.
2. **Isolate.** Narrow to the smallest input, commit range, or code path that
   triggers it. Use `git bisect`, binary search, or targeted logging rather
   than reading everything.
3. **Hypothesize.** State a specific, falsifiable cause ("the handler reads the
   field before validation populates it"), not a vague area.
4. **Test the hypothesis.** Confirm with a probe (a failing test, a log line,
   a debugger) before changing code. If the probe disproves it, return to
   step 3 — do not start editing on a hunch.
5. **Fix minimally at the cause.** Change only what the confirmed cause
   requires. Stay inside the task/ticket scope.
6. **Verify.** Re-run the original repro and the related regression tests;
   capture passing output as evidence. Confirm no new failures appear.
7. **Prevent regression.** Add or adjust a test that fails without the fix and
   passes with it, so the bug cannot return silently.

## Anti-patterns

- **Shotgun debugging**: changing several things at once hoping one works.
  Change one variable at a time.
- **Symptom suppression**: swallowing the error, broadening a `catch`,
  loosening a type, or adding a retry to mask a real fault.
- **Green by deletion**: skipping/deleting the failing test, or weakening an
  assertion, instead of fixing the behavior.
- **Hardcoding to the fixture**: returning data shaped like the test fixture so
  the test passes without the real behavior.
- **Scope drift**: turning a focused fix into an unrelated refactor.

## Boundaries

- `fix-by-review-ticket` applies only human-approved, in-scope ticket fixes and
  then re-runs the gate; it does not redesign or expand scope.
- If the diagnosis reveals a requirement, architecture, auth, or breaking-API
  decision, stop and defer to a human (set the task `Blocked` or raise a
  ticket with `requires_human_decision: true`).
- Capture the diagnosis and evidence in the relevant report or ticket; do not
  keep it only in conversation memory.

## Source

Adapted for SDD from the open-source `addyosmani/agent-skills`
`debugging-and-error-recovery` skill, reconciled with SDD's review-ticket and
Block-and-Stop rules.
