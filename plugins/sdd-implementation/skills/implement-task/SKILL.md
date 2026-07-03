---
name: implement-task
description: Restore the current SDD task state and implement exactly one approved task. Use after sdd-bootstrap-interviewer and before quality-gate.
disable-model-invocation: true
user-invocable: false
---

> **Caller**: This skill is invoked by `sdd-ship`. Do not invoke directly.
> Results are returned to the caller; no downstream skill is auto-invoked.

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
`references/implementation-craft-policy.md`, and
`references/agent-delegation-policy.md`.

### Sudo Mode

If a valid `SDD_SUDO` flag file exists at the project root (see
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`), the routine task
**approval** checkpoint auto-passes. Record
`Approval: Approved (sudo <ISO8601 UTC>)` in tasks.md and continue.

Sudo does **not** bypass the Block-and-Stop decisions below: requirement,
architecture, authentication, authorization, breaking-API, or security
decisions still require a human. Set the task to `Blocked` and defer to the
human even under sudo. All deterministic gates apply; every check runs as normal.

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
2. Implement only its `Scope` and `Done When`, building in thin vertical slices
   and verifying each slice (implement → run task-required tests → confirm
   behavior) before starting the next, per `references/implementation-craft-policy.md`.
3. Add or update the task-required tests. When the task's `Required Workflow`
   is `tdd` (high/critical risk), follow Red→Green: write the failing test
   first and save its failing output (e.g. under
   `specs/<feature>/verification/`), then implement until it passes and save
   the passing output. quality-gate's risk-aware `check-contract` requires
   non-empty `red_evidence` and `green_evidence` for every test-type check, so
   capture both as you go rather than reconstructing them later.
4. Run related existing regression tests.
5. Perform a scoped self-review against the approved specification.
6. When the task qualifies as a UI task (the feature has
   `specs/<feature>/ux-spec.md` or `specs/<feature>/mockups/`, and the task
   scope includes UI-layer files), run the `visual-verify-loop` skill. It is
   advisory and non-blocking: record its screenshots and findings in the
   implementation report's Visual Evidence section; when it is skipped,
   record the skip reason instead.
7. Create `reports/implementation/<task-id>.md` from the bundled template.
8. Set the task to `Implementation Complete` only when implementation, required
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
guessing. When a failure is in-scope but non-obvious, diagnose it
systematically with
`plugins/sdd-quality-loop/references/debugging-recovery-policy.md` before
deciding whether to continue or set the task `Blocked`.

## Common Rationalizations

Counter these excuses; each one is how a task quietly ships incomplete work.

- "Tests can come after I finish" — required tests are part of the task; write
  them with the slice, and Red→Green first for high/critical risk.
- "While I'm here I'll also fix/refactor X" — out-of-scope work belongs in a new
  task or a review ticket, not this change.
- "It's basically done, I'll set it to Done" — only `quality-gate` (or
  `lite-gate`) sets `Done`; stop at `Implementation Complete`.
- "I'll just approve this task to unblock myself" — approval is human-only and
  hook-guarded; never self-approve.
- "The spec is unclear but I can guess the intent" — stop and set `Blocked`;
  return the gap to `sdd-bootstrap-interviewer`.

## Red Flags

- A large amount of code written before any test runs.
- Edits to files outside the task's `Scope`.
- An unrelated refactor mixed into the task's diff.
- A test made to pass by hardcoding data shaped like the fixture.
- Setting `Done`, or adding `Approval: Approved`, from inside the session.

## Boundaries

- Do not run the full repository quality gate unless it is required by the task.
- Do not perform independent critical review; visual checks are limited to the
  advisory `visual-verify-loop` step of the Implementation Process.
- Do not set a task to `Done`; only `quality-gate` may do that.
- Do not commit, push, or create a PR/MR unless explicitly requested.
