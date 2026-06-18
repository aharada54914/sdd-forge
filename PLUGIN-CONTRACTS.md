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
- No task with `Approval: Approved` remains in `Draft` or `Blocked` state

If preconditions are not met, quality-gate should pause and report the gap
rather than proceeding with an incomplete implementation set.

---

## Plugin Dependency Declarations

| Plugin | Depends On | Notes |
|--------|------------|-------|
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
