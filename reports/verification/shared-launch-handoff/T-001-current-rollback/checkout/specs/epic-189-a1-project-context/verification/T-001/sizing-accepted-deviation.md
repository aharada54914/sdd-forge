# T-001 sizing — accepted deviation record (human decision 判断7 = A, 2026-07-29)

Non-frozen addendum per the task-review-loop Post-Implementation Provenance
Re-Review boundary ("Sanctioned post-review updates go to non-frozen addenda
per AGENTS.md (see ADR 0007)"). The tasks.md body is unchanged.

## Finding being recorded (task-review attempt-2 round-1, task-reviewer-b seq0339, verbatim)

> T-001 (specs/epic-189-a1-project-context/tasks.md:122-328) is oversized:
> its Scope bundles TWO separate schema requirements into one task
> (REQ-001's contracts/project-context.schema.json +
> contracts/project-context.template.yaml, AND REQ-002's
> contracts/provider-bindings.schema.json) plus CI/test wiring and
> CHANGELOG documentation -- more than three distinct implementation areas
> -- and its Done When list (tasks.md:229-252) carries 11 distinct checkbox
> items, the only task in this 13-task list exceeding the >8-item oversized
> threshold by a wide margin (the next-highest is 9, for single-requirement
> tasks T-002/T-003/T-005/T-006, each scoped to exactly one script
> family/requirement). Every other task in this epic maps to exactly one
> script family or requirement; T-001 alone spans two, increasing the risk
> that partial completion of one schema is marked Implementation Complete
> alongside the other within a single session.

Evidence chain: `reports/task-review/epic-189-a1-project-context/attempt-2/round-1/`
(reviewer-b.json sha256 `ad2f200f86a8c2f6082786547883c1d27eba4d05e39771a6b0fdd854a83ffd05`,
merged verdict NEEDS_WORK, commit `19b6b614`).

## Why this is recorded as an accepted deviation rather than remedied by re-decomposition

1. **The identical sizing content already passed this same gate.** T-001's
   Scope and Done When are byte-identical to the content task-review
   attempt-1 round-2 PASSED (`38d525f1`, task-review-contract at
   `reports/task-review/epic-189-a1-project-context/attempt-1/round-2/`,
   TASK-SIZE PASS). TASK-SIZE is a TYPE-H heuristic ("should",
   "Indicators of oversized tasks"); this attempt's reviewer applied the
   >8-item indicator more strictly to unchanged content — a calibration
   difference between reviewer instances, not new content or new risk.
2. **The risk the check guards against has already been discharged for
   T-001.** The finding's stated harm is prospective ("increasing the risk
   that partial completion of one schema is marked Implementation Complete
   alongside the other within a single session"). T-001's implementation
   is COMPLETE and verified: commit `4bd2ec3b`, both-runtime suites
   passing (see `verification/T-001/acceptance-sh.log` /
   `acceptance-ps1.log` in this directory), human approval recorded
   (`Approval: Approved (sudo 2026-07-22T14:31:01Z)`), remaining Status:
   Blocked items are CI-staging-only (判断1, out of this record's scope).
   Both bundled schemas were completed and verified together; the partial
   completion scenario can no longer occur.
3. **Re-decomposing T-001 retroactively would falsify landed evidence.**
   Splitting an implemented, sudo-approved task would break the
   hash-bound implementation/approval/quality records
   (`4bd2ec3b`, quality-gate evidence, tasks.md audit-marked approval) —
   a worse integrity outcome than the sizing deviation itself.

## Decision provenance

- Escalation record (判断7, three options, verbatim SKILL citations):
  `reports/task-review/epic-189-a1-project-context/attempt-2/round-1/tasks-round-1-proposed-changes.md`
- Human decision (2026-07-29, option A — this addendum + round-2, tasks.md
  unchanged): `reports/notes/epic-189-a1-decision-7-task-size-resolution.md`
- Standing rule for FUTURE decompositions is unaffected: this record
  accepts the deviation for the already-implemented T-001 only; it does
  not license oversized tasks in future epics or future task lists.
