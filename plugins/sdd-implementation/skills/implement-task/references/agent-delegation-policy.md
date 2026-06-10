# Agent Delegation Policy

## Principle

`implement-task` acts as an orchestrator. Delegate context-heavy secondary work
(impact analysis, pattern surveys, test-case enumeration) to single-purpose
helpers and receive only conclusions. Keep the main session focused on the
approved task scope.

## Claude Code — Subagent Delegation

- Spawn a read-only Explore subagent for each distinct investigation unit.
- One delegation = one purpose. Do not reuse a subagent across purposes.
- Pass only: task Scope, Done When, and the required file paths.
  Do not pass the full conversation history.
- Prefer lightweight models (Haiku-class) for survey work.
- Accept only the conclusion back into the main context; discard intermediate
  reasoning.

## Codex / No-Subagent Environments

- Run the same investigation unit in a fresh session.
- Record the conclusion in the Working Notes section of
  `reports/implementation/<task-id>.md` before returning to the main task.
- Treat each fresh session as a single-purpose unit; do not carry prior
  conversation state into it.

## Context Hygiene

- Enforce one session per task.
- If the context has grown long, or if compaction has occurred, write the
  current state to the Session Handoff section of the implementation report
  and end the session. Do not rely on summaries or compacted context.
- When resuming, the first actions are: read `tasks.md` and the implementation
  report. Reconstruct state from those files, not from memory.
- Compaction-based continuity is Lossy Compaction; avoid it entirely by
  persisting state to files.

## What Must Not Be Delegated

- Edits to `tasks.md` (status transitions are the orchestrator's sole
  responsibility).
- The final scoped self-review against the approved specification.
- `Blocked` judgments and the decision to stop.

## Cost Guidance

Survey and exploration tasks do not require a large model. Use the lightest
model available in the environment (Haiku-class in Claude Code, or any fast
model in Codex). Reserve the full-capability model for writing and reviewing
implementation code.
