---
name: implement-tasks
description: Batch-implement all approved tasks in dependency order, then auto-transition to quality-gate when every task reaches Implementation Complete. Use after sdd-bootstrap-interviewer and before quality-gate.
disable-model-invocation: true
---

# Implement Tasks (Batch)

Implement all approved tasks for a feature in dependency order.
After every approved task reaches `Implementation Complete`, automatically
invoke `quality-gate` for the feature.

## Invocation

Claude Code:

```txt
/sdd-implementation:implement-tasks specs/<feature>/tasks.md
```

Codex:

```txt
Use the implement-tasks skill for specs/<feature>/tasks.md
```

## Preconditions

Before reading any specification, verify that `AGENTS.md` exists at the
repository root and that `scripts/check-sdd-structure.sh` (or `.ps1`) reports
no `missing:` items. If either check fails, stop immediately and direct the
user to run `/sdd-bootstrap:sdd-adopt`. Do not improvise project rules or
infer missing structure from context.

## Required Reading

Read `AGENTS.md`, the target feature requirements, design, tasks, acceptance
tests, traceability, relevant ADRs and contracts,
`references/implementation-policy.md`, and
`references/agent-delegation-policy.md`.

### Sudo Mode

If a valid `SDD_SUDO` flag file exists at the project root (see
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`), the per-task
approval checkpoint auto-passes. Record
`Approval: Approved (sudo <ISO8601 UTC>)` in tasks.md for each auto-passed
task.

Sudo does **not** bypass Block-and-Stop decisions: requirement, architecture,
authentication, authorization, breaking-API, or security decisions still
require a human. Set the task to `Blocked` and defer to the human even under
sudo.

## Task Selection Algorithm

Execute this algorithm before each implementation pass:

1. Read `tasks.md` and collect all tasks.
2. **Eligible set**: tasks where both of these hold:
   - `Approval: Approved`
   - `Status: Planned` or `Status: In Progress`
3. **Dependency filter**: for each eligible task, parse its `### Blockers`
   section.
   - Scan for task-ID references matching the pattern `T-\d+`.
   - For each referenced task ID, check its `Status` in `tasks.md`.
   - If the referenced task's `Status` is **not** `Implementation Complete`
     or `Done`, remove the current task from the eligible set for this pass.
   - A task with `### Blockers\nNone` or a blank `### Blockers` section has
     no dependencies and remains eligible once approved.
4. Select the task that appears **earliest** in `tasks.md` from the eligible
   set.
5. If no eligible task exists, report which tasks remain and why
   (unapproved / dependency-blocked / all done), then stop and go to
   **Completion Check**.

## Implementation Loop

For each selected task:

1. Inspect `git status` and `git diff`. Preserve unrelated existing changes.
   If they conflict with the task scope, set the task to `Blocked` and stop.
2. Set the selected task to `In Progress`.
3. Implement only its `Scope` and `Done When`, following
   `references/implementation-policy.md` in full.
4. Add or update the task-required tests. When `Required Workflow: tdd`
   (`high`/`critical` risk), follow Red→Green: write the failing test first
   and save its output, then implement until it passes and save the passing
   output.
5. Run related existing regression tests.
6. Perform a scoped self-review against the approved specification.
7. Delegate large-scope surveys following
   `references/agent-delegation-policy.md`. Record delegation conclusions in
   the Working Notes section of the implementation report immediately.
8. Create `reports/implementation/<task-id>.md` from the bundled template.
9. Set the task to `Implementation Complete` only when implementation,
   required tests, related regression tests, and the report are all complete.
10. Re-evaluate the eligible set (Task Selection steps 1–4) — completed
    tasks may unblock previously dependency-blocked tasks.
11. If a new eligible task exists, loop back to step 1. Otherwise proceed
    to **Completion Check**.

## Block And Stop

Set the current task to `Blocked`, record the blocker, and stop the entire
batch when:

- Requirements or design are ambiguous.
- Requirement, architecture, authentication, authorization, breaking-API, or
  security decisions are required.
- Unrelated changes conflict with the task.
- Required tests cannot be run.
- The requested work exceeds the approved scope.

Return specification gaps to `sdd-bootstrap-interviewer`. Do not resolve them
by guessing. On resumption, re-invoke this skill — it re-evaluates eligibility
and picks up from the first incomplete eligible task automatically.

## Completion Check and Auto Quality-Gate Transition

After each task reaches `Implementation Complete`, evaluate:

**All-done condition**: every task in `tasks.md` with `Approval: Approved`
has `Status: Implementation Complete` or `Status: Done`.

### If the all-done condition IS met

1. Report to the user: list all tasks now at `Implementation Complete`.
2. **Automatically start `quality-gate`** for the feature, processing tasks
   in `tasks.md` order, beginning with the first `Implementation Complete`
   task. Follow the `quality-gate` skill (in `plugins/sdd-quality-loop`)
   in full for each task.

### If the all-done condition is NOT met

Report which approved tasks remain and their current blocking reason
(dependency-blocked, still `Blocked`, or pending approval), then stop.
Do not start quality-gate until the all-done condition is satisfied.

## Boundaries

- Do not start quality-gate mid-batch for individual tasks; only start it
  when **all** approved tasks are `Implementation Complete`.
- Do not set any task to `Done`; only `quality-gate` may do that.
- Do not commit, push, or create a PR/MR unless explicitly requested.
- Do not start a task whose `Approval` is not `Approved`.
- Do not run the full repository quality gate unless required by a task.
- Do not perform independent critical review or Playwright visual verification
  during the implementation loop (those happen in quality-gate).
