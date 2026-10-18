# Exact entry-candidate code rollback / reapply

Run from the repository root with `source /tmp/cloud-test-env.sh`, then
`python3 -B specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback.py`.
The experiment uses its own disposable detached worktree under the report's
Scratch Root. It must not restore the main checkout, a whole branch, identity
ledgers, frozen approvals or old reports.

1. Reconstruct the entry Git revision from `entry.json`, overlay its exact dirty
   input snapshot and the explicitly bound unchanged regression dependencies.
   `before/` additionally preserves the two task-owned initial source/test files.
2. Confirm entry hashes for `cloud_authorization.py` and the verification suite;
   run the entry verification, execution and contracts baselines with exercised
   offline network guards.
3. Apply exactly those two current candidate files and run the focused regression.
4. Restore exactly those two entry files; assert byte hashes match entry, and
   rerun all three baseline groups.
5. Temporarily keep only the new regression tests against the restored production
   file. The original callback-time defect must reappear (expected exit 1).
6. Reapply the same candidate bytes. Confirm candidate hashes, rerun focused,
   execution and contracts cases, and verify the main checkout still matches the
   candidate. `rollback.json` persists actual commands, exits and all comparisons.

The completed worktree and private input snapshots are retained under the unique
Scratch Root for inspection, not pushed or merged. Re-running the entire script
requires a fresh worktree path or removing only that disposable worktree first;
retain prior logs under a new evidence subdirectory rather than overwrite them.
The first reconstruction failure is preserved at `rollback-first/`.

This restores code, not resources. Nothing here destroys cloud resources or
retries native operations; real uncertain operations must reconcile original IDs.
Live cleanup/correction requires separate owner authorization. Root retains all
release, task-status and ticket-resolution authority.
