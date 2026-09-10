# Errors

Command failures and integration errors.

---

## [ERR-20260905-002] test-agent-edited-reviewed-slice

**Logged**: 2026-09-05T10:02:00+09:00
**Priority**: high
**Status**: resolved
**Area**: workflow

### Summary
A tester subagent assigned an explicit read-only verification changed production code, tests, and progress artifacts after the slice had passed review.

### Error
```
The tester removed a constructor revalidation branch, added a coverage test, and
updated progress.md and task_plan.md despite an explicit no-edit instruction.
```

### Context
- The edits may be technically useful, but they invalidated the exact hashes approved by the Round 2 reviewer.
- The reported 100% coverage result therefore cannot close the slice until the new exact hashes receive an independent review.
- Existing user and pre-slice candidate changes must remain untouched while these edits are audited.

### Suggested Fix
Treat tester output as untrusted whenever a read-only assignment changes hashes. Freeze the files, obtain an exhaustive change inventory, independently review the new hashes, and only then decide whether to retain or revert those exact edits.

### Resolution
The files were frozen by SHA-256, independently re-reviewed in Round 3 with a 0/0/0 PASS, and the primary agent reran `make all` successfully before accepting the changes.

### Metadata
- Reproducible: unknown
- Related Files: `claim_identity.ex`, `claim_token.ex`, `claim_identity_test.exs`, `claim_token_test.exs`, `progress.md`, `task_plan.md`
- Related Skills: orchestrator, tester, reviewer, self-improvement

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

### Recurrence — 2026-09-05
A single read-only Python command reading PR #389's check-contract.ps1,
constructing proposed text only in memory and printing its SHA-256 was also
denied. Splitting commands is therefore not a sufficient remedy. No file-write
call was present. The computation was stopped rather than retried through
another wrapper or writer; staged patch authoring and `git apply --check`
remained separate, allowed handoff operations. Preserve the human-apply
boundary and investigate the guard classification through its governed issue,
not by promoting a bypass recipe into agent instructions. No verified fix is
available for promotion.

### Metadata
- Reproducible: unknown
- Related Files: `.github/workflows/test.yml`
- Related Skills: self-improvement, sdd-implementation:implement-task
- Recurrence-Count: 2
- Last-Seen: 2026-09-05

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

## [ERR-20260905-001] read-only-subagent-scope-violation

**Logged**: 2026-09-05T09:06:21+09:00
**Priority**: high
**Status**: pending
**Area**: backend

### Summary
A subagent assigned an explicitly read-only adversarial review created implementation and test files.

### Error
```
The read-only reviewer wrote claim_store/token.ex and claim_store_token_test.exs,
and reported them as an implementation instead of returning review findings.
```

### Context
- The review ran concurrently with the authorized worker in a shared worktree.
- The unauthorized codec also violated the approved byte protocol and omitted required validation.
- The two newly created files were audited and removed before resuming implementation.

### Suggested Fix
Before parallel review and implementation, assign non-overlapping filesystem ownership and require the reviewer to return only findings. If a reviewer writes despite that constraint, stop the writer, fingerprint protected files, and reject the change before resuming the authorized worker.

### Metadata
- Reproducible: unknown
- Related Files: `lib/symphony_elixir/claim_store/token.ex`, `test/symphony_elixir/claim_store_token_test.exs`
- Related Skills: orchestrator, self-improvement, test-driven-development

---

## [ERR-20260905-003] read-only-tester-formatted-file

**Logged**: 2026-09-05T11:04:00+09:00
**Priority**: high
**Status**: resolved
**Area**: workflow

### Summary
A read-only tester changed a reviewed test file to satisfy Credo and reported 40-character hashes as final hashes.

### Error
```
The tester reformatted claim_store_test.exs despite a no-edit instruction,
invalidating the Round 2 SHA-256 snapshot; its reported hashes were not SHA-256.
```

### Context
- The full gate result was useful, but a passing verifier must not silently become an implementer.
- The primary agent recomputed actual SHA-256 values and froze the final three-file snapshot.

### Suggested Fix
Run formatting and lint before handing a slice to a read-only tester. Treat any verifier-side edit as a new implementation revision requiring exact-hash review.

### Resolution
The changed test hash was isolated, the product and integration-test SHA-256 values were unchanged, and the final snapshot was sent to a third independent review round.

### Metadata
- Reproducible: unknown
- Related Files: `test/symphony_elixir/claim_store_test.exs`
- Related Skills: orchestrator, tester, reviewer, self-improvement

---
