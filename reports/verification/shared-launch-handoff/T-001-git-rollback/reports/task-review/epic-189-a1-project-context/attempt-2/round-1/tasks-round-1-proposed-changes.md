# Task Review Report: epic-189-a1-project-context — Round 1 / Attempt 2 (Post-Implementation Provenance Re-Review)

## Verdict: NEEDS_WORK (merged; round 1 of 3 — HALTED FOR HUMAN DECISION, see Procedural Conflict below)

| Field | Value |
|---|---|
| Feature | epic-189-a1-project-context |
| Round | 1 of 3 |
| Attempt | 2 (post-implementation provenance re-review) |
| Reviewer-A Verdict | PASS (14/14) |
| Reviewer-B Verdict | NEEDS_WORK (8 PASS / 1 SKIP / 1 FAIL) |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |

## Reviewer-A Findings (Structural Coverage)

None — all 14 checks PASS with cited evidence (INITIAL-STATE evaluated
under the post-implementation lifecycle-validity rule; findings `[]`).

## Reviewer-B Findings (Quality and Risk)

- **TASK-SIZE (Major, T-001)**, verbatim:

  > T-001 (specs/epic-189-a1-project-context/tasks.md:122-328) is
  > oversized: its Scope bundles TWO separate schema requirements into one
  > task (REQ-001's contracts/project-context.schema.json +
  > contracts/project-context.template.yaml, AND REQ-002's
  > contracts/provider-bindings.schema.json) plus CI/test wiring and
  > CHANGELOG documentation -- more than three distinct implementation
  > areas -- and its Done When list (tasks.md:229-252) carries 11 distinct
  > checkbox items, the only task in this 13-task list exceeding the
  > >8-item oversized threshold by a wide margin (the next-highest is 9,
  > for single-requirement tasks T-002/T-003/T-005/T-006, each scoped to
  > exactly one script family/requirement). Every other task in this epic
  > maps to exactly one script family or requirement; T-001 alone spans
  > two, increasing the risk that partial completion of one schema is
  > marked Implementation Complete alongside the other within a single
  > session.

## Procedural Conflict (why this round HALTS for a human decision instead of proceeding to remedy)

The finding targets **T-001, which is already implemented and
human-approved**: `Approval: Approved (sudo 2026-07-22T14:31:01Z)`,
implementation landed at `4bd2ec3b` (both-runtime suites passing), staging
items Blocked under 判断1. The sizing content of tasks.md is byte-identical
to what task-review **attempt-1 round-2 PASSED** (`38d525f1`) — TASK-SIZE
is a TYPE-H heuristic and this attempt's reviewer applied the >8-item
indicator more strictly to unchanged content. The risk the check guards
against ("partial completion ... within a single session") was already
discharged for T-001 by its completed, verified implementation.

Three governing rules now conflict (task-review-loop/SKILL.md, verbatim):

1. STEP 6, Round < 3 with Major findings → NEEDS_WORK: "Review proposed
   changes **and edit specs/<feature>/tasks.md**. Then re-invoke with
   --edit-summary."
2. Post-Implementation Provenance Re-Review: "a provenance re-review
   re-binds review evidence to the current artifact hashes; **it does not
   license content changes to frozen artifacts**. Sanctioned post-review
   updates go to non-frozen addenda per AGENTS.md (see ADR 0007)." — and
   the tasks.md body is exactly such a frozen artifact ("the tasks.md body
   or traceability.md after the task review gate passes",
   task-reviewer-a role file, OBSERVABLE-DONE).
3. Post-Implementation Provenance Re-Review: "This is a re-binding of
   existing PASS evidence, **never a first-time review or a findings
   waiver**." — and Sudo Mode: "Sudo mode (SDD_SUDO) does not apply to
   this skill."

The ONLY documented exit from NEEDS_WORK (edit tasks.md → round 2) is the
ONE action the provenance re-review's own boundary forbids; waiving the
finding is also forbidden; and retroactively splitting an implemented,
sudo-approved task would falsify the implementation/approval/QG record
(hash-bound evidence at `4bd2ec3b`, `2f8f3243`, quality-gate reports). No
rule in the SKILL resolves this three-way conflict. Per the orchestration
escalation rule, this halts for a human decision (判断7) — no waiver, no
frozen-content edit, no status change has been performed.

## Options for the human decision (判断7)

- **(A) Non-frozen addendum + round-2**: record an accepted-deviation
  addendum in a non-frozen location (e.g.
  `specs/epic-189-a1-project-context/verification/` — the route the
  re-binding boundary itself sanctions via ADR 0007) stating T-001's
  sizing was reviewed and PASSED at attempt-1, implemented, and verified;
  then re-invoke round 2 with `--edit-summary` describing that addendum
  (no tasks.md content change). Honest and evidence-preserving; residual
  risk: round-2 reviewer-b may still FAIL TASK-SIZE (TYPE-H), and the
  "Re-Invocation After Human Edits" section literally contemplates
  tasks.md edits, so this stretches (but does not contradict) its letter.
- **(B) Authorize a tasks.md content change (split T-001)**: outside the
  provenance re-review's license, requires the human to explicitly own a
  frozen-artifact content change, and retroactively conflicts with T-001's
  landed implementation, sudo approval, and QG evidence. Strongly
  disfavored on evidence-integrity grounds; listed for completeness.
- **(C) Rule the finding out-of-scope for a provenance re-review +
  upstream fix**: the human rules that TYPE-H sizing heuristics on
  already-implemented, previously-passed tasks are outside a re-binding
  review's scope, and directs a WFI (workflow-improvement) item adding a
  provenance-re-review clause to the task-reviewer-b role (e.g. sizing
  indicators on tasks with completed, verified implementations become
  Minor advisories). Cleanest long-term; requires a role-file/SKILL change
  through the normal human-apply channel, then a fresh round.

## Next Steps

Awaiting the human decision (判断7). No further task-review rounds will be
launched until it is recorded. The interim `check-workflow-state` failure
("task reviewer manifest input hash is stale") remains the documented
provenance-re-review in-progress condition; the provenance re-review's own
completion requirement ("run check-workflow-state.sh ... and require exit 0
before reporting completion") is NOT yet met and completion is NOT being
reported.
