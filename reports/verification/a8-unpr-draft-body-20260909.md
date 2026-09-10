## Purpose

Expose the existing post-#248 branch work and preserved failures for integration
tracking. Draft publication is not formal review, implementation completion,
current live-host evidence or permission to merge.

Pinned head: a1b958bc648aaf4b22a99a45262df490d64438c7.
Compared main: 4366438f3b243210a4ece5a17f873ca2d920600a.
The contribution diff contains 197 files, 25900 insertions and 1094 deletions;
these counts do not establish semantic uniqueness against newer main.

## Existing work

Cross-runtime handoff, installed-plugin drift, installation matrix,
live-host proof validation, path/line-ending and process-integrity checks,
plus staged/applied historical WFI changes and review evidence.

## Not ready to merge

- Preserve T-001 BLOCKED and all historical failing reviews/tickets.
- Complete the authorized specification amendment and evidence-ledger recovery
  through their formal review paths; local worktree amendments are NOT in this
  remote head.
- Genuine live-host proof and signer/activation requirements remain unresolved;
  fixture results or unsigned records are not proof of a real session.
- Reconcile shared guard, workflow and generated-file changes with current main
  and other PRs; do not overwrite newer safety fixes with an old snapshot.
- Require all mandatory CI and independent formal provenance/quality gates.

No tests were rerun for draft publication. Ordinary implementation/integration
remains subject to the unresolved hook activation gate; publication does not
extend the recovery-only admission. No review status or task status was changed.

Related issue: #196. Do not automatically close it on publication.
