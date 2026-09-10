# PR381 four registration consumers: primary review

Candidate worktree: `/private/tmp/pr381-verify.7id2mX/worktree`
Base HEAD: `3971c93a5705dc15f86ba56cc62118613e4b19db`
Date: 2026-09-06

This is an ordinary code review of the uncommitted four-file registration
diff, not a formal SDD verdict, T-005 evaluation, or PR merge authorization.

## Scope and assessment

The capability-registry-schema, context-projection-schema,
generate-gate-capabilities and second-approval-mask POSIX suites now query
the actual runner with `--list` and match complete newline-delimited paths.
They do not extract the removed static runner array. Nonzero list execution
fails the assertion even if stdout contains the expected path. The capability
suite's `fail()` exits 1; the other checks short-circuit before membership on
command failure. Existing PowerShell and non-registration assertions remain.

Primary inspected the complete four-file diff (235451), the runner (874ab7),
and capability failure behavior (f82fbc). Critical findings: 0. Regression
validation is delegated to an independent lightweight tester; no formal
review identity is claimed for that ordinary test activity.

Primary syntax checks each ran as a separate `/bin/bash -n <file>` invocation:
14b0a9, 8e9af5, 279f53, 55ebbf, all exit 0. Scoped `git diff --check` also
returned 0 (1e9374).

## Remaining failure is not waived

The actual generator suite log `/tmp/pr381-generate-gate.XXXXXX.log`, inspected
in bbd1de, reports 21 passed, 1 failed and 1 designed-red. The rebuilt workflow
candidate and staged workflow omit the live `posix-regression` job. This is
not an overall PASS and has not been proven pre-existing against a baseline.
Do not remove that check or accept the staged workflow as safe to apply.

Historical T-005 FAILs and all mandatory CI conditions remain unchanged.

## Independent regression execution

Tester `pr381_four_validation` executed the four full suites in the correct
worktree. Primary inspected their actual log tails in ea5a46. Logs are under
`/private/tmp/pr381-verify.7id2mX/worktree/reports/verification/pr381-20260906-01/`:

- capability-registry-schema: exit 0, 6 accept and 16 reject fixtures.
- context-projection-schema: exit 0, 40 passed and 0 failed.
- generate-gate-capabilities: exit 1, 21 passed, 1 failed, 1 designed-red.
- second-approval-mask: exit 0, 39 passed, 0 failed, 0 skipped.

The tester's first negative-control claim is rejected for these four files:
the submitted `pr381-registration-negative-controls.log` actually names only
loop-inventory and bump-version-gate (primary inspection 1e1b7b). It does not
prove the four newly changed consumers. The tester was asked to exercise
their actual blocks; those negative controls remain pending at this record.

## Primary actual-block controls (supersedes pending state only)

The subsequent proposed worker harness was also rejected before relying on it:
it ran full suites that reset ROOT, and `if ! command; then $?` would record
the inverted status. That diagnostic is not verification evidence. Primary
stopped the worker and supplied a bounded `primary-controls.sh` diagnostic
in the same log directory plus an executable mock-list fixture. No product
source was modified by this correction.

Primary executed:
`rtk proxy env PATH=/bin:/usr/bin:/opt/homebrew/bin:/usr/local/bin /bin/bash reports/verification/pr381-20260906-01/primary-controls.sh`

Actual tool output c0a9fc, exit 0, prints source SHA-256, exact extracted blocks
and the original outcome functions. All 16 controls met expectations: each
of four consumers accepts the real-name listing and rejects omission,
`.bak` near-match, and exit-7 listing even with correct stdout. Counters are
checked as well as exit status. Extraction requires exactly one block.
These are primary-run block-level controls, not independent full-repository
mutation tests. Independent full-suite results and the generator failure
remain exactly as recorded above.
