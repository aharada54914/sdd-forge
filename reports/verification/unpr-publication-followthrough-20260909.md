# Remaining remote branches: publication follow-through

Observed main: 4366438f3b243210a4ece5a17f873ca2d920600a.
Read-only live `ls-remote --heads origin` returned 14 heads including main.
Before publication nine heads had open PRs. The remaining four were resolved:

| Head | Disposition |
| --- | --- |
| feature/epic-195-a7-compatibility / e1e019be691b40dcb292fa16c3fb14f578d4433f | Created draft PR #404; preserves post-#247 work and outstanding evidence/CI gates |
| feature/epic-196-a8-integration / a1b958bc648aaf4b22a99a45262df490d64438c7 | Created draft PR #405; preserves post-#248 work and historical BLOCKED evidence |
| auto/improve-20260831 / 32a81f5ebe3b71d72ef274c7bc3776b6db12a70c | Duplicate production intent already tracked by #402; keep pending verified reconciliation, no duplicate PR |
| codex/ci-auto-discovery-wfi-027-028-034 / eba07a297117ec32104fcbdf90c3515a63e2163f | Nested merged #382 belongs to pending #381, not delivered main; do not delete |

For the last row, branch-tip tree equals merge commit
92528375705085967c19d75deb5f12e0fa66c276 (`git diff --stat` empty, exit 0).
`git merge-base --is-ancestor` from that merge to observed main returned 1.
Therefore the MERGED label on #382 is insufficient for main delivery.

Both all-state A7/A8 head lookups had only the old merged PR immediately before
creation. `gh pr create --draft --base main` returned URLs #404 and #405.
Bodies are preserved in a7-unpr-draft-body-20260909.md and
a8-unpr-draft-body-20260909.md. No new commits, pushes, merges, issue closures,
protected publication or formal gate verdict changes were performed.
Local-only branches and dirty worktrees remain preserved; this remote-head
reconciliation does not certify their uncommitted contents as published.

## Recovery helper advisory

Independent reviewer /root/hook_contract_security_review returned no
Critical/Warning findings for rt002-spec-human-application-20260909.md,
SHA-256 490aa26c5f5de5d6b5983de18fad71ffad28fed9126023e226f41c359a50c9aa.
Read-only advisory only: no helper execution or formal PASS. Earlier outer
and inner Bash syntax checks passed without executing the heredoc. Human
publication and all subsequent verification remain outstanding.
