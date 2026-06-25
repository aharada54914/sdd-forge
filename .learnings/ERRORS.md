# Errors

Command failures and integration errors.

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
