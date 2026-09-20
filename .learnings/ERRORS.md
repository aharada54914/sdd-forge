# Errors

Command failures and integration errors.

---

## [ERR-20260825-001] deterministic-pretool-read-bundle

**Logged**: 2026-08-25T00:00:00+09:00
**Priority**: low
**Status**: pending
**Area**: config

### Summary
A bundled read-only final-state command was rejected because it named a
protected workflow path alongside unrelated status/hash checks.

### Error
```
SDD deterministic gate: agents must not modify gate scripts, hook
configuration, or critical test files.
```

### Context
- The command combined `git status`, file listing, diff statistics, a
  read-only workflow diff, and a workflow SHA-256 read.
- No write was requested; splitting protected-path reads from ordinary final
  checks avoids an ambiguous bundled command without bypassing the gate.

### Suggested Fix
Keep protected-path read verification in a single, clearly read-only command
and run unrelated worktree checks separately.

### Metadata
- Reproducible: unknown
- Related Files: `.github/workflows/test.yml`
- Related Skills: self-improvement, sdd-implementation:implement-task

---

## [ERR-20260623-001] memoryctl-task-sync

**Logged**: 2026-06-23T00:00:00Z
**Priority**: low
**Status**: pending
**Area**: config

### Summary
The team-memory-sync workflow references `memoryctl`, but this workspace does
not provide that executable.

### Error
```
zsh:1: command not found: memoryctl
```

### Context
- Attempted to synchronize the blocked task-review result.
- Repository review artifacts remain the authoritative handoff record.

### Suggested Fix
Install or document the workspace-specific `memoryctl` dependency, or make the
skill degrade explicitly to repository artifacts when it is unavailable.

### Metadata
- Reproducible: yes
- Related Skills: team-memory-sync

---
