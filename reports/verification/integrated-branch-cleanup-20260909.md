# Verified integrated branch cleanup

Main verified locally and by `git ls-remote`:
`4366438f3b243210a4ece5a17f873ca2d920600a`.

The user authorized inspection and deletion of unnecessary merged branches.
For every target below, `git diff --name-status <head> <merge>` returned
empty output with exit 0; `git merge-base --is-ancestor <merge> origin/main`
returned 0. This establishes exact branch-tip tree integration, not merely
patch-ID similarity. Live remote heads matched the listed expected heads.
All nine open PRs target main; none uses these branches as its head or base.
No matching local branch existed, and no listed worktree used these heads.

| Deleted remote branch | Head | Integrated PR / merge | Local recovery ref |
|---|---|---|---|
| fix/human-copy-shared-file-class-lock | 9199ee2a872d7652eb093175b55a78d73b3e739d | #268 / e4042f2f9555c9024997a1b40cc116f798f27ae8 | refs/archive/20260909/fix-human-copy-shared-file-class-lock |
| claude/peaceful-rubin-cb3425 | d53c41234aac8223985a8c6a74489e9577cc3b1d | #305 / 9800296d144069676f372541991e1dba302f1a61 | refs/archive/20260909/claude-peaceful-rubin-cb3425 |
| wfi/048-guard-patch-target-extraction | a494ca6a841909f64ed657cddd2cfa8b3184a00c | #355 / 0bf70b5add8d9eeb93d7748f1e022aa0f9224b0f | refs/archive/20260909/wfi-048-guard-patch-target-extraction |

Created each recovery ref using an expected absent old value. Then deleted
the three remote refs in one atomic push, with a separate exact-head lease
for each target. Git returned exit 0 and confirmed all three deletions.
The saved local refs retain the original commits and permit restoring each
remote branch. No source files, worktrees or historical review evidence were
deleted. No new main merge or issue closure is implied.

The apparent two unique WFI-048 commits were history-shape differences:
the full head tree equals PR #355's merge tree already in main. Do not open
a duplicate PR based solely on `git log main..branch` for this head.
