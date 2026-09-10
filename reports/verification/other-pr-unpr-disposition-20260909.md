# Other PR and unpublished-branch disposition

Observed: 2026-09-08 23:17 UTC (2026-09-09 JST).
Read-only primary investigation. No implementation, test execution, CI rerun,
publication, deletion, merge, issue closure or formal verdict change.

## Unpublished remote heads: content checked, not just names

Live `git ls-remote --heads origin` returned 14 heads, matching 11 open PRs,
main, and the following two heads without an open PR.

### auto/improve-20260831

Head: 32a81f5ebe3b71d72ef274c7bc3776b6db12a70c.
GitHub PR search for this head returned no PR. Relative to current main
4366438f3b243210a4ece5a17f873ca2d920600a, exactly one commit is outstanding.
That commit changes four files, 28 additions and two deletions.

Primary `git show` inspection compared this commit with PR #402 head
f6e7427c9648085ca86a0d0835fa28df8e5ff300 (also one commit outside main).
Both change the same executable predicates: Python uses `count(cmd) > 0`
instead of a raw approval regex; PowerShell uses `Get-Count` instead of
the raw regex. Comments and regression tests differ; these are NOT identical
patches or identical branch trees.

The unpublished variant checks Japanese reason text for Python/PowerShell.
PR #402 checks English reason text and the copilot-mode exit code, and adds
a Node comparison. Thus the inspected unpublished patch adds no distinct
production behavior requiring a duplicate PR. This is static comparison,
not proof of comprehensive coverage or runtime parity. Retain the branch
until #402's reviewed implementation and required CI are integrated.

### codex/ci-auto-discovery-wfi-027-028-034

Head: eba07a297117ec32104fcbdf90c3515a63e2163f.
GitHub records PR #382 as merged into PR #381's branch on 2026-08-31,
with merge commit 92528375705085967c19d75deb5f12e0fa66c276.

Important ancestry distinction: the original head is NOT an ancestor of
current PR #381 head 3971c93a5705dc15f86ba56cc62118613e4b19db (exit 1).
The single-parent squash commit 92528375 IS an ancestor (exit 0), but is
NOT an ancestor of current main (exit 1). Therefore absence of the original
head from ancestry does not justify a duplicate PR or claiming lost work.
Retain this branch until #381 is integrated; no deletion performed.

## Current other-PR queue

| PR | Observed blocker | Next scoped action |
| --- | --- | --- |
| #390 / #394 | Windows test and required-checks failed | Complete the approved #400 fixture-repair formal chain, then validate each dependency integration with unchanged deadlines and all mandatory checks |
| #371 | Windows test and two MCP jobs failed | Reconcile current-main MCP fix and RT005 with the ten-file adversarial-review contribution; preserve strict mixed-failure checks |
| #381 | POSIX inventory, native tests, routing, version gates and required-checks failed | Apply the approved full-check-preserving workflow/registration repair through its formal review and protected-file path |
| #402 | Three native tests and required-checks failed | Repair the two guard mirrors and manifest entries; retain guard parity and reason regressions |
| #404 | Three native tests failed; Windows version-gates still running | Repair stale design provenance through a new review; do not overwrite historical verdicts |
| #245 / #403 / #405 | DIRTY | Resolve approved conflicts/contracts before required validation; no CI checks is not green evidence |
| #400 | Draft / BLOCKED, no failed checks | Complete outstanding formal evidence repairs before readiness or merge |
| #401 | Three native tests and required-checks failed | Complete A9 specification/review and mandatory validation |

#404 run 34288587300 now has 20 successful jobs, three failed native tests,
and one running Windows version-gates job. macOS and Ubuntu version-gates
have completed successfully since the preceding inventory. Overall run is
still in progress, not successful. No unchanged retries requested.

## Implementation boundary

`hook-recovery-entry-contract-20260909.md`, Recovery entry item 1, explicitly
does not admit unrelated implementation or integration before fresh host
activation. These read-only findings do not expand that admission. The next
human publication step remains `rt002-spec-human-application-20260909.md`;
publication alone does not complete activation, formal review or this queue.
No new approval request is inferred merely from listing the existing queue.
