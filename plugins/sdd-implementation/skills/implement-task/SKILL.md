---
name: implement-task
description: Restore the current SDD task state and implement exactly one approved task. Use after sdd-bootstrap-interviewer and before quality-gate.
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

## Required Reading

Read `AGENTS.md`, the target feature requirements, design, tasks, acceptance tests,
traceability, relevant ADRs and contracts, and `references/implementation-policy.md`.

## State Restoration

1. Inspect `tasks.md` and select the named task, an `In Progress` task, or the first
   task with `Approval: Approved` and `Status: Planned`.
2. Inspect `git status` and `git diff`.
3. Preserve unrelated existing changes. If they conflict with the task scope, set
   the task to `Blocked` and stop.
4. Do not start a task whose approval is not `Approved`.

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
