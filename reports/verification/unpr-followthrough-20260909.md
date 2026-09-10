# Additional unPR follow-through

## Published for integration review

Created draft https://github.com/aharada54914/sdd-forge/pull/403 from existing
remote `staging/cycle2-regate` at
`f748a6030b63d884b9cea9b15cda5b7abe7ac08e`. The all-state PR head lookup was
empty immediately before creation. Remote SHA was confirmed with ls-remote;
the original occupied worktree was clean and left untouched.

The body is preserved in `cycle2-regate-draft-pr-body-20260909.md`.
It explicitly retains T-007's cross-model FAIL, the open
RT-20260828-001 risk-source decision, whitespace failures, and incomplete
formal/CI gates. Publication is not review completion or a task Done decision.

## Two false unPR candidates resolved by tree identity

Pinned main: `4366438f3b243210a4ece5a17f873ca2d920600a`.

| Branch | Remote head | Existing merged PR / merge commit |
|---|---|---|
| fix/human-copy-shared-file-class-lock | 9199ee2a872d7652eb093175b55a78d73b3e739d | #268 / e4042f2f9555c9024997a1b40cc116f798f27ae8 |
| claude/peaceful-rubin-cb3425 | d53c41234aac8223985a8c6a74489e9577cc3b1d | #305 / 9800296d144069676f372541991e1dba302f1a61 |

For each row, `git diff --name-status <head> <merge>` produced no differences
and exited 0. `git merge-base --is-ancestor <merge> origin/main` exited 0.
Therefore each entire branch-tip tree was integrated, despite the apparent
unique individual commits caused by differing history. No duplicate PR is
needed for these exact tips. Later main changes are not regressions merely
because they differ from these old snapshots.

No branches, worktrees or evidence were deleted. No code was committed or
pushed, no merge was performed and no issue was closed in this follow-through.

## Separate advisory result retained

The independent advisory of the inert RT002 spec amendment returned no
Critical findings and two Warnings: incomplete distinct rejection-case rows
and review-time wording that could reintroduce the recovery-entry deadlock.
These remain unresolved; this advisory is not a formal PASS. Its reviewed
candidate hash remains
`22fbec40e088d99dfa77a164f43a9f5d59dd66ae8583bb256f68e0f9ea46facd`.
