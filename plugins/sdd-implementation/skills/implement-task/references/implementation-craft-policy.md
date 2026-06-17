# Implementation Craft Policy

How to build one approved task well. This complements `implementation-policy.md`
(which governs *what* an implementation session may do) with *how* to keep the
work small, verifiable, and reviewable. It does not relax any boundary in the
`implement-task` skill: one approved task at a time, no self-approval, and
**no commit/push/PR unless explicitly requested**.

## Build in thin vertical slices

Within the single approved task, split the work into thin end-to-end slices and
finish one before starting the next. Prefer a complete narrow path over a wide
unfinished layer.

- Vertical (preferred): a small end-to-end behavior that is independently
  demonstrable.
- Contract-first: define the interface/signature, then implement against it.
- Risk-first: tackle the most uncertain slice early to surface blockers before
  sunk cost.

Avoid horizontal slicing within a task (all schema, then all handlers, then all
UI) — it hides integration risk until the end and produces nothing verifiable
in between.

## Verify each slice (not commit each slice)

Run a short loop per slice: **implement → run the task-required tests → verify
behavior**. Keep the tree compilable and the related tests green between slices,
so a failure points at the last small change. When the task's `Required
Workflow` is `tdd` (high/critical risk), the slice loop is Red→Green: write the
failing test first and capture its output, then implement until it passes and
capture that, per `implementation-policy.md` and the skill.

This is a *verification* checkpoint, not a commit checkpoint. SDD's commit
policy is unchanged: `implement-task` does not commit, push, or open a PR/MR
unless the user explicitly asks. Capture progress in the implementation report,
not in throwaway commits.

## Scope discipline

- Touch only the files the task's `Scope` and `Done When` require. Out-of-scope
  improvements belong in a new task or a review ticket, not this change.
- One logical change at a time; do not interleave unrelated refactors with
  feature work.
- If a slice reveals that the task needs decisions beyond its scope
  (architecture, auth, breaking API, ambiguous requirements), stop and follow
  the skill's Block-and-Stop rules rather than expanding scope.

## Simplicity first

- Ask "what is the minimal correct solution?" before adding abstraction.
- Reuse existing repository patterns and dependencies over introducing new ones.
- Prefer conservative, opt-in defaults for risky behavior; hide incomplete
  work behind a flag rather than shipping a half-built path.
- Remove code the change orphans; do not leave dead code or commented-out
  blocks behind.

## Red flags

- Writing a large amount of code before running any test.
- A slice that cannot be demonstrated end to end.
- Edits to files outside the task scope.
- Mixing an unrelated refactor or cleanup into the task.
- "I'll add tests / simplify / clean up later" — do it within the slice.

## Source

Adapted for SDD from the open-source `addyosmani/agent-skills`
`incremental-implementation` and `code-simplification` skills, reconciled with
SDD's one-task / no-self-commit boundaries.
