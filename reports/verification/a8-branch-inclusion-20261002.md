# A8 historical branch inclusion audit

Compared committed branches against PR #513 remote head `ef97fd9d275780cacb82c69884ac6a34ee8bae54`. This is inclusion evidence, not test, review, native activation, or merge evidence. Dirty owner-worktree changes were not modified.

- `codex/a8-t003-matrix`: `git cherry` marks `c466e93df74b3793661307cfc8860c8223c4bc55` patch-equivalent to the PR branch.
- `codex/a8-t008-live-proof-agent`: `git cherry` marks `7f476eb1e353f6f0e859e3e766c2624bc40f7ffd` patch-equivalent to the PR branch.
- `codex/a8-t002-drift`: no differences for tracked paths matching `*drift*`. Registry and projection differences add the three T-007 gates; they retain installed-plugin-drift. Parity fixture differences add those same three scripts. Non-equivalent commit IDs alone do not establish missing implementation.
- `codex/a8-t007-process-integrity`: no differences in the nine classification/scope/citation implementation scripts, process-integrity tests, capability-registry parity tests, canonical registry, or PowerShell test runner. The POSIX inventory difference adds `tests/impl-review-adr-inputs.tests.sh` in the PR branch.

No redundant cherry-pick or new PR is justified by these implementation comparisons. This does not assert equality of all historical reports, candidate patches, or human-copy artifacts. Checked-out branches and local records are retained; no branch or worktree was deleted.
