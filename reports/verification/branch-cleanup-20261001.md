# Branch audit — 2026-10-01

Baseline: `origin/main` at `49e1602459108fd8ef318b644b51301a3b61d0b1`, fetched immediately before the audit.

## Exact cleanup target

- Local ref: `refs/heads/codex/issue427-empty-phase-extra1`.
- Recovery commit: `2a38dc87c3d8840a7047974ee61ea9eef43dc287`.
- PR: https://github.com/aharada54914/sdd-forge/pull/530, MERGED on 2026-09-28; merge commit `52b5ede85a81608263d7a6c1a66aec42cb8f523b`.
- `git merge-base --is-ancestor <recovery commit> origin/main` returned 0. `git log origin/main..<local ref>` was empty.
- No worktree registration uses this branch. No current root `reports`, `specs`, `docs`, or `.codex` reference to its branch name was found. The task's saved app attachments contain PR #530 but no corresponding worktree.
- `git ls-remote --heads origin codex/issue427-empty-phase-extra1` was empty: the remote ref is already absent.
- Delete only this local ref with its expected old SHA. No files, worktrees, remote refs, review verdicts, or task states are cleanup targets. The commit remains reachable from main; recover the branch with `git branch codex/issue427-empty-phase-extra1 2a38dc87c3d8840a7047974ee61ea9eef43dc287` if needed.

Cleanup executed: expected-SHA `git update-ref -d` returned 0; `git show-ref --verify --quiet` returned 1 afterwards. Only the named local ref was removed. Recovery remains available from the commit above.

## Preservation decisions

Do not prune missing worktree registrations wholesale: a missing checkout is not proof that its branch or detached commit was published. Preserve all checked-out branches, uncommitted changes, unpublished checkpoints, and the cancelled #137 checkpoint. In particular preserve the #423 owner and human-staged isolated clone, PR #401/#512/#513/#528 owners, the A9 recovery checkpoint, and the installed RT002 verifier repair.

This audit and cleanup are not additional implementation, native activation, CI, merge, or Issue resolution evidence.

## Follow-up — October 2 JST

An independent read-only audit matched local `origin/main` to the live remote SHA above. All ten non-main local branches listed by `git branch --merged origin/main` remain attached to worktree registrations. There are no additional unowned, fully merged local refs eligible for deletion. Prunable registrations were preserved rather than treated as permission to remove their history. No further Git state or files were changed.

## Follow-up — October 3 JST

`git merge-base --is-ancestor` returned 0 for both `codex/issue193-live-resolver-ci` (`62704e67`) and `codex/issue311-scratch-isolation` (`493ff5a8`) against the recorded `origin/main`; both ahead logs were empty. The same checks establish that `codex/issue423-t003-capability-20260930` (`06bc32cc`) is contained in `codex/issue423-boundary-checkpoint` (`3b5c38f0`). These refs need no duplicate PR. All remain worktree-registered; no branch or checkout was removed. Commit containment does not establish that unrelated uncommitted files are delivered.
