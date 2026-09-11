# PR #402: preserve the hook correction in the distribution bundle

Base PR head: f6e7427c9648085ca86a0d0835fa28df8e5ff300.
Related issues: #295, #380. This is not an issue-completion or gate verdict.

## Cause and change

The PR changed the live Python and PowerShell approval counters, but left the
Phase 2 human-copy bundle at the previous implementation. Applying that bundle
would restore the incorrect primary-approval classification. CI run 34285985088,
Ubuntu job 102261582294, identified exactly those two out-of-sync paths.

Copy the existing PR correction into the two corresponding staged files and
update their existing manifest rows. Do not change live guard behavior, tests,
inventory, required checks, or historical review verdicts in this follow-up.

## Actual verification on macOS

- Before: `bash tests/phase2-guard-invariants.tests.sh`: 41 passed, 1 failed,
  exit 1; the failure named both stale staged guards.
- After: same command: 42 passed, 0 failed, exit 0.
- `bash tests/guards.tests.sh`: 135 passed, 0 failed, exit 0.
- `pwsh -NoProfile -File tests/hooks.tests.ps1`: Hook guard tests passed, exit 0.
- `pwsh -NoProfile -File tests/phase2-guard-invariants.tests.ps1`:
  51 passed, 0 failed, 1 skipped, exit 0. The existing runner-install-path skip
  remains: the installed runner still expects an evicted staged canonical.
  This run does not prove that skipped installer path or actual Windows behavior.
- `git diff --check`: exit 0.

Local logs: `/tmp/pr402-mirror-red-20260911.log`,
`/tmp/pr402-mirror-green-20260911.log`, `/tmp/pr402-guards-bash-20260911.log`,
`/tmp/pr402-hooks-pwsh-20260911.log`, `/tmp/pr402-mirror-pwsh-20260911.log`.

## Review and remaining conditions

Reviewed the complete three-file implementation delta: the two staged files
are byte-identical to the live files; only their two manifest rows changed.
No new secrets, dependencies, test skips, or relaxed checks were introduced.
This is author-side review, not the required third-party GitHub approval.
Latest-head CI, branch currency, required approval, merge and post-merge
verification remain required before closing either related issue.
