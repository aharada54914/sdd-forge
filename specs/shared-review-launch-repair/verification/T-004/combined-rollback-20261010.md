# T-004 combined rollback verification

This is local disposable verification, not a formal quality verdict, task-state
transition, installed-host activation, CI result, or release approval.

## Scope and provenance

The candidate snapshot combines T-001 through T-005 at owner HEAD
`9ce19abe90df0cb83e385f96855e4843318a8807`, including its working-tree changes.
`combined-context.json` pins the actual candidate and baseline bytes and modes;
HEAD alone does not identify the dirty candidate.

The existing `reports/verification/shared-launch-handoff/T-001-git-rollback`
baseline and T-001 compact rollback procedure were reused. A fresh inventory of
the three implementation/review/quality plugins, contracts, tests, and `.github`
identified 62 changed targets: 48 byte differences and 14 mode-only differences.
The historical 26-target inventory was not treated as complete. Historical pins
were retained, and 23 additional existing baseline files were independently
matched to Git HEAD blobs and modes (`combined-baseline-provenance.json`).

The disposable checkout was
`/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd-t004-combined-38B2bf/checkout`.
No owner implementation, ledger, approval, task status, or frozen artifact was
changed by this verification. Authority/state documents and historical evidence
were deliberately not rollback targets.

## Executed verification

`rtk proxy node specs/shared-review-launch-repair/verification/T-004/combined-rollback-20261010.mjs`
completed with exit 0. The helper applied the pinned candidate to the disposable
baseline, ran the candidate suites, restored original bytes/modes (including
removing candidate-only targets), and ran baseline suites.

| Phase | Suite | Result |
| --- | --- | --- |
| Candidate | host-review-preflight | 19 passed |
| Candidate | unified-task-launch | 9 passed |
| Candidate | unified-launch-order | 9 passed |
| Candidate | review-conditional-inputs | 16 passed |
| Candidate | quality-nontty-transport | 20 passed |
| Candidate | traceability-freeze-contract | 2 passed |
| Candidate | spec-review-verify-inputs | 2 passed |
| Candidate | review-hash-normalization (PowerShell) | exit 0; baseline equivalence for CRLF, case, invalid inputs |
| Restored | host-review-preflight | 7 passed |
| Restored | unified-task-launch | 9 passed |
| Restored | unified-launch-order | 8 passed |
| Restored | quality-nontty-transport | 18 passed |

Total: 119 Python tests passed, zero failed, plus the successful PowerShell suite.
All 12 subprocesses exited 0 without a termination signal. Raw results are in
`combined-results.json` and the `combined-candidate-*.log` /
`combined-restored-*.log` files.

`combined-restored-readback.json` and `combined-summary.json` confirm all 62
targets restored by hash and mode, and those same 62 owner/baseline targets
remained unchanged. This preservation assertion is scoped to the inventory,
not to all files being edited concurrently in the repository.

## Boundaries and remaining verification

- The later Sonnet alignment changes to `docs/agent-capability-matrix.md`,
  `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md`,
  and both `tests/agent-model-routing.tests.*` are outside this pinned snapshot
  and are not proved by these results.
- Full repository suites, native Windows/installed CLI activation, independent
  formal evaluation, latest-head CI, merge, and post-merge checks are separate.
- No ledger/history restoration was attempted or authorized.
- The initial harness invocation stopped on an unchanged symlink before fixture
  creation; the helper was corrected to accept only identical symlinks and still
  reject changed symlinks. The recorded successful invocation is subsequent.
