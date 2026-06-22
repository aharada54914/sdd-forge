# Plugin Contracts

This document defines the inter-plugin interfaces for sdd-forge. These contracts
govern how plugins communicate and hand off control at version boundaries.

## implement-tasks → quality-gate (v0.12.0+)

**Source**: `plugins/sdd-implementation/skills/implement-tasks/SKILL.md`
**Target**: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`

### Handoff Preconditions

Before invoking quality-gate, implement-tasks must verify:

1. **All approved tasks implemented**: Every task with `Approval: Approved` in
   `specs/<feature>/tasks.md` has reached `Implementation Complete` status.
2. **No blocked tasks**: No task with `Approval: Approved` is in `Blocked` status.
3. **Dependency order satisfied**: All `### Blockers` references between tasks
   have been resolved in dependency order.

### Signal Format

implement-tasks signals handoff by announcing completion in the session and
invoking quality-gate as the next skill. There is no machine-written file for
this handoff — the session continuity is the signal.

### Precondition Assertion (quality-gate preflight)

quality-gate should verify on entry:
- At least one task exists in `Implementation Complete` state
- Every task with `Approval: Approved` is in `Implementation Complete` state (not `Draft` or `Blocked`)
- All `### Blockers` references between tasks have been resolved in dependency order

If preconditions are not met, quality-gate should pause and report the gap
rather than proceeding with an incomplete implementation set.

---

## sdd-ship → internal plugins (v0.15.0+)

**Source**: `plugins/sdd-ship/skills/run/SKILL.md`
**Targets**: sdd-implementation (implement-tasks), sdd-quality-loop (quality-gate, lite-gate via sdd-lite), sdd-bootstrap (sdd-adopt preflight)

### Orchestration Contract

sdd-ship is a thin orchestrator. It does not re-implement logic from its dependencies:

1. **Implementation**: delegates entirely to `/sdd-implementation:implement-tasks` (full track) or `/sdd-implementation:implement-task` in document order (lite track).
2. **Quality gate (full)**: delegates to `/sdd-quality-loop:quality-gate` per task. BLOCKED verdict halts the batch immediately.
3. **Quality gate (lite)**: delegates to `/sdd-lite:lite-gate` per task. FAIL verdict halts the batch.
4. **Cross-model verify**: delegates to `/sdd-quality-loop:cross-model-verify` only when `--verify` flag is present AND the task has `Cross-Model: enabled`.
5. **Retrospective**: delegates to `/sdd-quality-loop:workflow-retrospective` when `--retro` is passed or all tasks reach Done for the first time in the session.

### Security Invariants

- sdd-ship must never invoke `sdd-sudo` or create/modify `SDD_SUDO`.
- sdd-ship must never set `Approval: Approved` on any task.
- sdd-ship must never modify files under `plugins/sdd-quality-loop/hooks/` or any `sdd-hook-guard.*` script.
- sdd-ship must never push to remote or create pull requests without explicit user instruction.

### Track Detection (priority order)

1. `--full` flag → FULL (verifies acceptance-tests.md + traceability.md exist)
2. `--lite` flag → LITE
3. `spec_profile: lite` in AGENTS.md → LITE
4. Default → FULL

---

## Plugin Dependency Declarations

| Plugin | Depends On | Notes |
|--------|------------|-------|
| sdd-ship | sdd-bootstrap, sdd-implementation, sdd-quality-loop, sdd-lite | orchestrates all implementation and verification phases |
| sdd-implementation | sdd-quality-loop | quality-gate invocation |
| sdd-lite | sdd-quality-loop | check-task-state-lite mirrors check-task-state logic |
| sdd-bootstrap | (none) | standalone |
| sdd-quality-loop | (none) | standalone |

---

## Cross-Plugin Script References

If a future refactoring merges `check-task-state-lite` into `check-task-state`
(via `--lite` flag), sdd-lite would gain a runtime dependency on the
sdd-quality-loop scripts directory. This dependency must be declared in
`plugins/sdd-lite/.plugin/plugin.json` before the merge proceeds.
