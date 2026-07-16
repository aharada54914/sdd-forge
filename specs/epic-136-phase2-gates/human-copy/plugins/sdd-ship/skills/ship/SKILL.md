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

### Risk-upgrade scan

`--full` is the only scan bypass. For every remaining default, profile, or
`--lite` route, build a local UTF-8 input by concatenating the selected task's
complete `## T-NNN` block followed by that feature's `requirements.md`. Both
inputs are mandatory; do not retrieve remote issue text and do not use a
partial task block.

Run the platform-local checker before considering a lite branch:

```txt
plugins/sdd-lite/scripts/check-risk-upgrade.sh <task-block-plus-requirements>
powershell -NoProfile -ExecutionPolicy Bypass -File plugins/sdd-lite/scripts/check-risk-upgrade.ps1 -Path <task-block-plus-requirements>
```

- Exit 10 with `full-required: <primary-id>; triggers=<ordered-ids>` forces
  **FULL** track even when `--lite` was requested. Print the checker diagnostic
  followed by `[sdd-ship] Track: full (risk-upgrade)` and verify the full-track
  `acceptance-tests.md` and `traceability.md` artifacts before task start. If either is absent, stop before task start and print `[sdd-ship] Full-track artifacts unavailable. Run /sdd-bootstrap:bootstrap for the full track.`
- Exit 2 with `risk-upgrade: input unavailable` is fail-closed: stop before
  implementation or the lite gate, print that diagnostic, and direct the user
  to restore the selected task block and requirements or run full bootstrap.
- Exit 0 with `lite-eligible` allows the normal remaining priority rules.

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

1. **Cross-model verification runs before the gate.** A task whose tasks.md
   entry carries `Risk: critical` or `Security-Sensitive: true` MUST have
   cross-model verification run in this same ship invocation before it reaches
   the quality gate, **regardless of whether `--verify` was passed**. For each
   such task, invoke
   `/sdd-quality-loop:cross-model-verify specs/<feature>/tasks.md#T-NNN` before
   the gate.
   - **Human-gated waiver.** Skip the required cross-model run for such a task
     only when its tasks.md entry records a `Cross-Model-Waiver:` that is VALID.
     A waiver is valid only when the SAME task also carries a human
     `Approval: Approved` audit mark naming a second distinct human approver
     (the human-only mark the deterministic guard already prevents an agent from
     writing, and the same distinct-approver rule already mandated for critical
     tasks). A `Cross-Model-Waiver:` that lacks that co-located human-approval
     context is treated as ABSENT (fail-closed) and cross-model verification
     remains required. An agent cannot grant itself a waiver, because it cannot
     produce the human approval mark the waiver depends on. Guard-level
     enforcement of the waiver token itself is out of scope here (future
     hardening); the waiver is inert without the human approval context.
   - **Fail-closed stop.** If such a task has neither a completed cross-model
     run in this invocation nor a valid waiver, STOP the ship flow before the
     quality gate and print a diagnostic naming the task:
     `[sdd-ship] Cross-model verification required for T-NNN (Risk: critical or
     Security-Sensitive: true), but it neither ran this invocation nor carries a
     valid Cross-Model-Waiver: (a valid waiver needs a co-located human
     Approval: Approved mark naming a second distinct approver). Run cross-model
     verification or record a valid waiver, then re-invoke.`

   Independently of the requirement above, if the `--verify` flag was passed and
   the task has `Cross-Model: enabled` in its
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
   invoking quality-gate, run the deterministic cycle-limit script for this task
   instead of counting reports by hand:

   ```txt
   plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh T-NNN
   ```

   On a Windows host without `python3`/`node`, run the PowerShell twin instead:

   ```txt
   pwsh plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1 T-NNN
   ```

   The script counts this task's existing gate reports under
   `reports/quality-gate/` (word-boundary match on the task id so `T-001` does
   not match `T-0010`; an absent directory counts zero) and prints its decision:
   - `continue` (exit 0): fewer than three reports — proceed to invoke
     quality-gate for T-NNN.
   - `Escalate-Human` (non-zero exit): three or more reports and the task is
     still not Done — do **not** invoke quality-gate again and do **not** prompt
     for fix-by-review-ticket; stop and instruct the human to investigate
     manually.

   Because each quality-gate run writes a durable timestamped report under
   `reports/quality-gate/`, this limit is computed from disk and holds across
   separate `/sdd-ship:ship` invocations and sessions (it does not reset per
   invocation).

### Lite track

For each task at `Implementation Complete`:
- **Ineligibility check (before the lite gate).** If the task's tasks.md entry
  carries `Risk: critical` or `Security-Sensitive: true`, it is INELIGIBLE for
  the lite track, because the lite track has no cross-model step. The lite gate
  rejects it: STOP and print a diagnostic naming the task and directing the
  human to the full track, e.g.
  `[sdd-ship] T-NNN is Risk: critical or Security-Sensitive: true and is
  ineligible for the lite track (no cross-model step). Re-run on the full track:
  /sdd-ship:ship --full specs/<feature>/tasks.md`
  Do not admit such a task to the lite gate.
Invoke `/sdd-lite:lite-gate specs/<feature>/tasks.md#T-NNN`.
- PASS: task is Done.
- FAIL: stop, surface the report, and instruct the user to fix and re-run.

## Field Definitions

These optional per-task fields live in a tasks.md task entry. They are additive;
existing consumers ignore unknown fields.

- `Security-Sensitive:` — optional per-task boolean trigger. `true` marks the
  task as requiring cross-model verification regardless of its `Risk:` tier (see
  Step 4). The task author proposes it; the human confirms it at approval.
  Absent or `false` means the field does not force cross-model verification (the
  `Risk:` tier still may).
- `Cross-Model-Waiver:` — optional per-task field recording an explicit decision
  to skip the cross-model verification a task would otherwise require. Who may
  set it: a human only. Its audit value is a short human-authored reason. It is
  honored only when the SAME task also carries a human `Approval: Approved`
  audit mark naming a second distinct human approver — the human-only approval
  context that makes the waiver valid; without that context the waiver is
  ignored and cross-model verification remains required (fail-closed). Because
  an agent cannot produce the human approval mark, an agent-written waiver has
  no effect.
- Lite-track rule for critical/security-sensitive tasks: a task with
  `Risk: critical` or `Security-Sensitive: true` is INELIGIBLE for the lite
  track, because the lite track has no cross-model step. The lite gate rejects
  such a task with a diagnostic naming the task and directing the human to the
  full track (see Step 4, Lite track), rather than admitting it to a track that
  would silently drop the cross-model requirement.

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

## Context Compaction

Ship sessions span many tasks. All loop state is persisted on disk (tasks.md
Status fields, `reports/quality-gate/`, review tickets), and both the Resume
behaviour (Step 3) and the disk-based cycle limit (Step 4) are designed to
survive re-invocation — compaction at a task boundary loses nothing.

Compact (or accept auto-compaction) only at task boundaries:

- after a task reaches Done (quality gate PASS)
- after a BLOCKED stop, before starting fix-by-review-ticket
- between Step 3 and Step 4, when all targeted tasks are at
  Implementation Complete

Do not compact while a task is In Progress or a quality-gate cycle is
running: the implementing agent's working context (file paths, partial
changes, verification state) is not yet reflected on disk. After compacting,
re-invoke `/sdd-ship:ship` and rely on Resume behaviour to continue from the
first eligible task.

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
