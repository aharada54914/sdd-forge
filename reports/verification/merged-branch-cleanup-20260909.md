# Main-integrated remote branch cleanup

Main checked: `4366438f3b243210a4ece5a17f873ca2d920600a`.
Authority: user's earlier instruction to inspect and delete unnecessary merged
branches, continued by the request to handle other PRs and unPR work.

GitHub live heads equal the merged PR heads below. Each commit is an ancestor
of main (exit 0), with zero commits in `main..head`. All seven open PRs target
main and none uses these branches as its head. Local branches, worktrees,
uncommitted changes and historical evidence will be preserved.

| Remote branch | PR | Recoverable commit |
|---|---|---|
| feature/wfi-058-059-implementation | 389 | ec0bfe248c88667a22a78571dbcb9b839c81e5ea |
| fix/npm-audit-fasturi-qs-20260903 | 386 | 1bd368aa3584a6a435e9b7ad4849dfb7019e3ec7 |
| epic-194/qg-20260828 | 367 | 015429ef8a6e77f9e0a65f283815b3a20ddbe959 |
| wfi/055-amend-partial-comparison | 364 | 45767f10daa15ec706ca88b635a4041cc2df518d |
| wfi/057-installer-cache-verification | 363 | f507ecf32e25719a27b19c298dd812570a8b3ab8 |

Deletion is constrained by exact-head leases, atomically. Any changed head
must stop the operation. These commits remain reachable from main; restoring
a deleted remote name uses `git push origin <commit>:refs/heads/<name>`.

Retain `wfi/048-guard-patch-target-extraction`: despite PR355 being merged,
its current head has two non-ancestor commits. A merged PR label alone does
not justify deleting it. Retain both auto/improve branches pending comparison
of their distinct Python/PowerShell guard diagnostic fixes. Retain PR382's
branch: it is merged into PR381, not delivered to main.

Status: all five remote names deleted by one atomic exact-head-leased push
(exit 0). Subsequent `git ls-remote --heads origin` restricted to those five
names returned no entries (exit 0). No local branch/worktree was deleted and
main was not changed. No new issue-resolution or quality PASS is claimed.
