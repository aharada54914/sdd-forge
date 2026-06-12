---
name: implement-task
description: Restore the current SDD task state and implement exactly one approved task. Use after sdd-bootstrap-interviewer and before quality-gate.
disable-model-invocation: true
---

# Implement Task

Implement one approved task and prepare it for independent quality review.

## Invocation

Codex:

```txt
Use the implement-task skill for specs/<feature>/tasks.md#T-001
```

Claude Code:

```txt
/sdd-implementation:implement-task specs/<feature>/tasks.md#T-001
```

## Preconditions

Before reading any specification, verify that `AGENTS.md` exists at the
repository root and that `scripts/check-sdd-structure.sh` (or `.ps1`) reports
no `missing:` items. If either check fails, stop immediately and direct the user
to run `/sdd-bootstrap:sdd-adopt`. Do not improvise project rules or infer
missing structure from context.

## Required Reading

Read `AGENTS.md`, the target feature requirements, design, tasks, acceptance tests,
traceability, relevant ADRs and contracts, `references/implementation-policy.md`,
and `references/agent-delegation-policy.md`.

### Sudo Mode

If a valid `SDD_SUDO` flag file exists at the project root (see
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`), human approval
checkpoints auto-pass. Record `Approval: Approved (sudo <ISO8601 UTC>)` in
tasks.md and continue. All deterministic gates still apply; every check runs as
normal.

## State Restoration

1. Inspect `tasks.md` and select the named task, an `In Progress` task, or the first
   task with `Approval: Approved` and `Status: Planned`.
2. Inspect `git status` and `git diff`.
3. Preserve unrelated existing changes. If they conflict with the task scope, set
   the task to `Blocked` and stop.
4. Do not start a task whose approval is not `Approved`.

## Delegation And Context

Delegate large-scope surveys (impact analysis, pattern discovery, test
enumeration) following `references/agent-delegation-policy.md`. Keep one
session per task. When crossing a session boundary, write current state to the
Session Handoff section of the implementation report before stopping; on
resume, re-read `tasks.md` and the report before taking any action.

## Implementation Process

1. Set the selected task to `In Progress`.
2. Implement only its `Scope` and `Done When`.
3. Add or update the task-required tests.
4. Run related existing regression tests.
5. Perform a scoped self-review against the approved specification.
6. Create `reports/implementation/<task-id>.md` from the bundled template.
7. Set the task to `Implementation Complete` only when implementation, required
   tests, related regression tests, and the report are complete.

## Block And Stop

Set the task to `Blocked`, record the blocker, and stop when:

- requirements or design are ambiguous
- requirement, architecture, authentication, authorization, or breaking API
  decisions are required
- unrelated changes conflict with the task
- required tests cannot be run
- the requested work exceeds the approved scope

Return specification gaps to `sdd-bootstrap-interviewer`. Do not resolve them by
guessing.

## Boundaries

- Do not run the full repository quality gate unless it is required by the task.
- Do not perform independent critical review or Playwright visual verification.
- Do not set a task to `Done`; only `quality-gate` may do that.
- Do not commit, push, or create a PR/MR unless explicitly requested.
