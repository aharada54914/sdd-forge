# CLAUDE.md

Treat `AGENTS.md` as the canonical shared instructions.

Use these public commands in order:

1. `/sdd-bootstrap:bootstrap <mode> <source>` — generate SDD Core specs (`sdd-core-spec`) and run risk-scaled pre-implementation review (`spec-check`), leaving tasks as `Approval: Draft`.
2. Human approval — a human reviews the specs and changes selected tasks in `specs/<feature>/tasks.md` to `Approval: Approved` (agents must never self-approve).
3. `/sdd-ship:ship specs/<feature>/tasks.md` — implement approved tasks (`implement-task` / `implement-tasks` to `Status: Implementation Complete`) and run independent verification (`sdd-gate` for `Status: Done`; optionally pass `--retro` to run `workflow-retrospective` after all selected tasks reach `Done`).
4. `/sdd-quality-loop:fix-by-review-ticket` — apply scoped fixes for review tickets, return the task to `Status: Implementation Complete`, then re-run `/sdd-ship:ship specs/<feature>/tasks.md#<task-id>` for `sdd-gate` re-verification of only that task without starting other `Planned` tasks.

Read the target feature's `requirements.md`, `design.md`, `tasks.md`, contracts,
and relevant ADRs before changing code. Only a human may set `Approval: Approved`,
and only `sdd-gate` (via `/sdd-ship:ship`) may set `Status: Done`. Preserve
unrelated changes and do not perform external Git operations unless explicitly
requested.
