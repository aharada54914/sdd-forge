# WFI-042 — human migration of the 8 non-conforming approval lines

Staged: 2026-08-22. Patch: `wfi-042-approval-line-migration.patch` (same
directory). Apply from the repository root with:

```sh
git apply reports/notes/wfi-042-approval-line-migration.patch
```

## What it changes, and why a human applies it

These 8 lines are human approval records in completed epics, so rewriting
them is a human action (WFI-042 `## Proposed Change`, row 3). Each rewrite
preserves the approver and the instant and only normalizes the timestamp
shape to the strict `Approved (<id> <ISO8601, seconds, Z>)` grammar:

| File | Lines | Rewrite |
|---|---|---|
| `specs/epic-136-phase2-gates/tasks.md` | 4× `Approval:` | drop fractional seconds (`…T05:53:16.481Z` → `…T05:53:16Z`) |
| `specs/epic-192-a4-facet-manifest/tasks.md` | 4× `Approval:` | add seconds (`…T03:35Z` → `…T03:35:00Z`) |

## Sequencing notes

- The grammar unification itself (checker twins + parity fixtures) landed
  with the commit whose message contains `WFI-042` and does not depend on
  this patch: CI stays green either way, because no CI job runs the
  task-state checkers against these two completed epics (the MCP golden
  feature list does not include them — verified at implementation).
- After applying, `## Verification Plan` item 2's corpus sweep reads zero
  non-conforming lines:
  `grep -rn "Approved (" specs/*/tasks.md | grep -vE "\([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)"` → no output.
- Both epics are complete; no active review-context reservation binds these
  files, so no rebind is triggered. Any future re-reservation would have
  needed a fresh binding anyway (raw digests change with any byte edit —
  the WFI-025 mechanism).
