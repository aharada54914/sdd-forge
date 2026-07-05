---
name: ship
description: Implement approved SDD tasks through the quality gate to Done — the second of the two-command workflow. Run after /sdd-bootstrap:bootstrap and human task approval.
disable-model-invocation: true
---

# SDD Ship

Orchestrate approved tasks from implementation through quality verification to Done.
This skill does not write specifications; use `/sdd-bootstrap:bootstrap` for that.

## Invocation

Claude Code:

```txt
/sdd-ship:ship specs/<feature>/tasks.md
/sdd-ship:ship specs/<feature>/tasks.md#T-001
/sdd-ship:ship
/sdd-ship:ship --lite specs/<feature>/tasks.md
/sdd-ship:ship --full specs/<feature>/tasks.md
/sdd-ship:ship --verify specs/<feature>/tasks.md
/sdd-ship:ship --retro specs/<feature>/tasks.md
```

Codex:

```txt
Use the ship skill for specs/<feature>/tasks.md
Use the ship skill (no argument — context-aware selection)
```

### Flags

| Flag | Effect |
|---|---|
| `--lite` | Force lite track (lite-gate) regardless of AGENTS.md spec_profile |
| `--full` | Force full track (quality-gate); verifies acceptance-tests.md + traceability.md exist |
| `--verify` | Before quality-gate, run cross-model-verify for tasks that have `Cross-Model: enabled` |
| `--retro` | Run workflow-retrospective after all tasks reach Done |

**`--fix RT-NNN` is NOT a sdd-ship flag.** Apply a review ticket directly:
`/sdd-quality-loop:fix-by-review-ticket docs/review-tickets/RT-NNN.yml`

## Preconditions

Before doing any work, verify that `AGENTS.md` exists at the repository root and
that `scripts/check-sdd-structure.sh` (or `.ps1`) reports no `missing:` items.
If either check fails, stop immediately and direct the user to run
`/sdd-bootstrap:bootstrap adopt`. Do not proceed without it.

Do **not** invoke `sdd-sudo`, create `SDD_SUDO`, or modify the `SDD_SUDO` file.
Sudo management is always a separate human action.

## Step 1 — Target Selection

### With a path argument

Use the given `specs/<feature>/tasks.md` (with optional `#T-NNN` task selector).
If `#T-NNN` is given, only process that single task.

### Zero-argument (no path given)

1. Read `AGENTS.md` at the repository root. Look for an `## Active Spec Directories`
   section listing feature paths.
2. For each listed path, check `specs/<feature>/tasks.md` for at least one task
   with `Approval: Approved` and `Status: Planned` or `Status: In Progress`.
3. **Exactly one match**: print `[sdd-ship AUTO-SELECT] specs/<feature>/tasks.md`
   and proceed without asking the user.
4. **Zero matches**: print "No active features with Approval: Approved tasks found.
   Run /sdd-bootstrap:bootstrap first." and stop.
5. **Multiple matches**: list all candidates with task counts and print
   "Multiple active features found. Re-run: /sdd-ship:ship specs/<feature>/tasks.md"
   and stop without touching any feature.

## Step 2 — Track Detection

Execute in this priority order (first match wins):

1. `--full` flag present → **FULL** track. Print `[sdd-ship] Track: full (--full override)`.
   Verify that `specs/<feature>/acceptance-tests.md` and `specs/<feature>/traceability.md`
   both exist. If either is missing, stop and instruct the user to run full-track
   sdd-bootstrap or drop `--full` and use `--lite`.
2. `--lite` flag present → **LITE** track. Print `[sdd-ship] Track: lite (--lite override)`.
3. Read `AGENTS.md`. If `spec_profile: lite` appears on any line → **LITE** track.
   Print `[sdd-ship] Track: lite (spec_profile: lite in AGENTS.md)`.
4. Default → **FULL** track. Print `[sdd-ship] Track: full (no lite profile detected)`.

The track message is always printed **before** any task is started.
If the wrong track is selected, the user can cancel (Ctrl-C) and re-run with
the correct `--lite` or `--full` flag.

## Step 3 — Implementation Loop

### Full track

Invoke `/sdd-implementation:implement-tasks specs/<feature>/tasks.md`.
That skill handles dependency ordering, per-task state transitions
(Planned → In Progress → Implementation Complete), and implementation reports.

Do **not** re-implement the dependency resolution logic here; delegate entirely
to implement-tasks.

### Lite track

Invoke `/sdd-implementation:implement-task specs/<feature>/tasks.md#T-NNN` for
each Approved + Planned/In-Progress task in tasks.md order. Lite track has no
dependency graph; implement tasks in document order.

### Resume behaviour

On re-invocation after interruption, skip tasks already at `Implementation Complete`
or `Done`. Resume from the first eligible task (Approved + Planned or In Progress).

## Step 4 — Quality Gate Loop

Execute after all targeted tasks reach `Implementation Complete`.

### Full track

For each task at `Implementation Complete`, in tasks.md document order:

1. If `--verify` flag was passed and the task has `Cross-Model: enabled` in its
   tasks.md entry: invoke `/sdd-quality-loop:cross-model-verify specs/<feature>/tasks.md#T-NNN`
   before the gate.
   - If no task in the batch has `Cross-Model: enabled`, print a warning:
     `[sdd-ship] --verify passed but no tasks have Cross-Model: enabled. Add
     the field to task entries that require panelist verification.`
   - On lite track, `--verify` is silently ignored with the same warning.
2. Invoke `/sdd-quality-loop:quality-gate specs/<feature>/tasks.md#T-NNN`.
3. **PASS (Done)**: task transitions to Done. Continue to next task.
4. **BLOCKED (review tickets created)**: stop immediately. Print:
   `[sdd-ship] Quality gate blocked for T-NNN. Review tickets written to
   docs/review-tickets/. Address each ticket, then re-invoke:
   /sdd-quality-loop:fix-by-review-ticket docs/review-tickets/RT-NNN.yml`
   Do not proceed to other tasks while any task is Blocked.
5. Cycle limit (disk-based — survives re-invocation across sessions): before
   invoking quality-gate, count this task's existing gate reports — the files in
   `reports/quality-gate/` whose contents reference the task id (use a read-only
   `grep -l` over that directory and count the matching files). If the count is
   `3` or more and the task is still not Done, do **not** invoke quality-gate
   again and do **not** prompt for fix-by-review-ticket: stop with
   `Escalate-Human` and instruct the human to investigate manually. Because each
   quality-gate run writes a durable timestamped report under
   `reports/quality-gate/`, this limit is computed from disk and holds across
   separate `/sdd-ship:ship` invocations and sessions (it does not reset per
   invocation).

### Lite track

For each task at `Implementation Complete`:
Invoke `/sdd-lite:lite-gate specs/<feature>/tasks.md#T-NNN`.
- PASS: task is Done.
- FAIL: stop, surface the report, and instruct the user to fix and re-run.

## Step 5 — Completion Check

After all targeted tasks reach Done:

- If `--retro` flag was passed, or if all tasks in the feature (not just the
  targeted subset) have reached Done for the first time in this session:
  invoke `/sdd-quality-loop:workflow-retrospective specs/<feature>`.
- Print a summary: number of tasks implemented, number Done, any remaining
  non-Done tasks (with their current Status).

## State Machine Summary

```
IDLE
→ TARGET_SELECTED    (path argument or zero-arg auto-select)
→ TRACK_DETECTED     (print [sdd-ship] Track: ... message)
→ IMPLEMENTING       (implement-tasks for full / implement-task loop for lite)
→ QUALITY_GATE_LOOP  (quality-gate or lite-gate per task)
   ├── task Done → continue loop
   ├── task Blocked → STOP (surface review tickets)
   └── ≥3 disk gate reports for task and not Done → STOP (Escalate-Human)
→ COMPLETION_CHECK   (all targeted tasks Done?)
   └── yes → [--retro or all-Done] RETROSPECTIVE → DONE
```

## Security Boundaries

- **Never** invoke `sdd-sudo` or create/modify the `SDD_SUDO` file.
- **Never** set `Approval: Approved` on any task. The approval guard will block
  this; attempting it causes confusing error messages.
- **Never** modify gate scripts (`scripts/*.sh`, `scripts/*.ps1`) or hook files.
- **Never** push to remote, create pull requests, or merge branches unless the
  user explicitly requests it in this session.
- **Never** modify files under `plugins/sdd-quality-loop/hooks/` or
  `plugins/sdd-quality-loop/scripts/sdd-hook-guard.*`.
- Do not exceed the scope of the targeted tasks. Do not make changes to files
  unrelated to the approved tasks.

## Handoff

After sdd-ship completes, report:

- Tasks implemented and their final status (Done / Blocked)
- Any review tickets created (with file paths)
- Next action for the user:
  - If all Done: "Feature complete. Consider re-running /sdd-ship:ship --retro
    specs/<feature>/tasks.md to capture improvements."
  - If Blocked: "Address review tickets, apply fixes with
    /sdd-quality-loop:fix-by-review-ticket, then re-run /sdd-ship:ship."
