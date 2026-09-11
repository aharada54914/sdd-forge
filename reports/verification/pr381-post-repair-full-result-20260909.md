# PR381 complete post-repair regression — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db`
Command: `rtk proxy bash tests/run-all.sh`
Handle: `56623`, terminal, exit **1**. Do not poll as live or blindly restart.
Full log: `/tmp/pr381-post-repair.REuP55/full.log`
SHA256: `eac8198cf525cd17f231bd717ba65c1a5304db0dfc0d31d78f5f2964844d4c46`

The runner reached all 141 suite entry points, including the final PowerShell guard-port suite (60 passed, 0 failed on macOS). Compared with `/tmp/pr381-posix-20260909.WaPopD/full.log`, the original 43 suite-level failures are reduced to three, with no newly failing suite. Suite process success is not proof that every assertion or platform requirement passed.

Remaining failing suites:

- `human-copy-mirror-freshness.tests.sh`: A6 applied workflow mirror stale against live workflow; 13 other staged entries are informational PENDING, not permission to overwrite them.
- `deterministic-lane-selfcheck.tests.sh`: candidate omits live `posix-regression` job; 24 passed, 1 failed, 4 designed-red.
- `design-system-contract.tests.sh`: TEST-039 CI-entry assertion remains designed-red; 120 passed, 1 failed.

Additional unresolved assertion: standing-consent emits deferred FAIL TEST-054 for CI reachability despite process exit zero. It is not a pass. Existing SKIPs and the four designed-red registrations also remain unproven. Missing PowerShell CI registrations are documented separately in `pr381-ci-reachability-audit-20260909.md`.

Approved loop-helper repair passed in the complete run: 26 passed, 0 failed. Recovery checkout `git diff --check` exited 0 afterward.

RT-20260909-001 remains open awaiting explicit approval of the frozen needs-contract amendment. General goal continuation is not that approval. Preserve every existing dependency and add mandatory POSIX success only under the specified scoped amendment, negative regression controls and formal re-review.

Fresh GitHub inspection: seven open PRs retain existing heads and no CheckRuns are active. PR400 has no failed CI but unresolved formal reviews; PR245 has no Actions checks, not proof of success. Other five PRs retain failed checks. Native mandatory CI, formal reviews/QG, integration and issue closure remain outstanding.

No source was changed during this run. No commit, push, merge, issue closure, review-verdict rewrite or task-Done transition was performed.
