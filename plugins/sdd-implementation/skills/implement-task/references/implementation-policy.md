# Implementation Policy

- Implement exactly one approved task at a time.
- Treat `tasks.md` as the source of truth for approval and work status.
- Preserve unrelated user changes.
- Prefer existing repository patterns and dependencies.
- Add tests required by the task and run related regression tests.
- Stop rather than guess when specification or scope is ambiguous.
- Produce an implementation report before handing work to `quality-gate`.
- `Implementation Complete` means ready for independent review, not `Done`.

## Context Management

- Prefer fresh context over accumulated conversation state.
- `tasks.md` and the implementation report are the source of truth for work
  status; do not rely on conversation memory.
- When resuming after a break or session boundary, re-read `tasks.md` and
  `reports/implementation/<task-id>.md` before taking any action.
- Record delegation conclusions in the Working Notes section of the report
  immediately after receiving them; do not keep them only in memory.
- If the session has grown long or compaction has occurred, write the current
  state to the Session Handoff section of the report and end the session.
