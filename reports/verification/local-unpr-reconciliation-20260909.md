# Local unpublished-work reconciliation

Observation date: 2026-09-09. Read-only Git/GitHub inspection; no implementation,
publication, deletion, CI rerun, merge or review-status mutation.

## Committed work

`git ls-remote --heads origin` returned 14 live heads, including main at
4366438f3b243210a4ece5a17f873ca2d920600a. For every local branch,
`git rev-list --count <branch> --not <all 14 live head SHAs>` returned zero.
This second comparison deliberately used live heads rather than potentially
stale cached remote-tracking refs. It establishes commit reachability, not
that all work is merged to main or that uncommitted work is published.

| Local branch | Main-only / branch-only commits | Disposition |
| --- | --- | --- |
| codex/a7-t004-evidence-20260905 | 46 / 0 | Committed base is in main; dirty repair work remains local |
| codex/a9-ci-registry-20260908 | 62 / 8 | Tip is PR #401 head; not integrated |
| codex/consolidation-wave1-20260905 | 47 / 0 | In main; associated worktree is clean |
| codex/issue359-collection-fixtures | 0 / 0 | Same as main; old worktree record is prunable, not pruned |
| codex/pr-doc-review-fixes-20260906 | 43 / 0 | In main; associated worktree is clean |
| codex/pr363-review-fixes-20260906 | 43 / 0 | In main; associated worktree is clean |
| codex/t002-failure-diagnostics | 0 / 5 | Tip is PR #400 head; current worktree has additional unpublished changes |
| main | 37 / 0 | Local main is behind live main; no checkout or pull performed |
| pr395-merge-resolve | 24 / 0 | Committed work is in main; old worktree record retained |

The A7 evidence worktree has ten modified tracked files (451 additions,
24 deletions), including task/review evidence and regression tests. These
must not be discarded merely because its branch tip is an ancestor of main.
Untracked files are outside `git diff --stat`; this is not a full content
inventory of that worktree. No new PR for these old local tips is needed.

## Remote unpublished heads

The earlier reconciliation still holds: A7 and A8 have Draft PRs #404/#405;
auto/improve-20260831 overlaps #402 and remains preserved; the CI-discovery
head belongs to nested PR #382 integrated into pending #381, not main.
There is no newly discovered remote head requiring a duplicate PR.

## Current integration blockers

- #402: terminal mandatory CI failure; repair the two guard mirrors and their
  manifest entries as detailed in pr402-windows-staging-failure-20260909.md.
- #404: all three native test jobs failed; three version-gates jobs were still
  running at this observation. The Ubuntu design-provenance failure is recorded
  in pr404-native-provenance-failure-20260909.md. No unchanged retry requested.
- #405, #403 and #245: GitHub reports DIRTY (conflicting), not green readiness.
- #400: no failed checks, but BLOCKED; formal review and unpublished repairs
  remain. CI success alone is insufficient.
- #390/#394: Windows test and required-checks failed. Dependency-only scope
  does not authorize removing the failing checks.
- #371/#381/#401: mandatory CI failures remain; not merged.

The recovery-entry contract admits RT-20260909-002 repair work, not unrelated
implementation or integration before fresh host activation. This inventory
does not expand that entry or convert advisory review into formal PASS.
Next human publication step remains rt002-spec-human-application-20260909.md;
spec publication alone does not establish activation or complete the repair.
