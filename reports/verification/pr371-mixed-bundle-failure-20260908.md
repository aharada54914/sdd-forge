# Golden comparison mixed-failure defect

Date: 2026-09-08
Ticket: RT-20260908-005 (new, pending scoped human approval)
Checkout: root worktree HEAD 8fa3eb8561d6f59b692ec574900f87e181145928,
with the pre-existing dirty changes retained. Not PR371's exact checkout.

## Executed evidence

From `mcp/sdd-forge-mcp`, `rtk proxy npm run pretest` completed exit 0.
Then executed:

```sh
rtk proxy bash -o pipefail -c 'node --test dist-test/tests/golden/task-state-golden.test.js dist-test/tests/golden/environment-dependence.test.js 2>&1 | tee /tmp/pr371-current-golden-20260908.log'
```

Session 70366 completed exit 0: seven passed, zero failed, zero skipped;
duration 9055.466542 ms. The complete output is in the named local log.
This runs macOS live shell comparison and recorded fixtures, not Windows CI.

A separate read-only Node invocation imported the freshly compiled original
`environmentDependentBundleFailures` and `extractOwnFailureMessages`.
It supplied one bundle summary and both of these machine detail lines:

```text
 - git_commit does not exist in repository: a3a5c66c905211a3ad2dfe21814c6f6a9d8ba38d
 - artifact sha256 mismatch: specs/f/verification/T-010.green.log
 - T-010 evidence bundle failed validation: specs/f/verification/T-010.evidence.json
```

Expected causes: empty array, so the strict comparison remains active.
Actual causes: the orphaned-commit detail alone. The invocation reported
`strictComparisonPreserved:false` and exited 1 by explicit assertion.
This is an isolated predicate reproduction, not a new full acceptance suite.

## Cause and next action

`shell-runner.ts:152` rejects non-bundle own failures, but lines 155-162 only
collect matching environment details and never reject other detail failures.
The existing negative controls cover content failure alone and a separate
task-state failure, not mixed bundle details. Thus seven passing tests do
not prove the documented exclusion boundary at lines 138-143.

Do not use the current helper's green tests as sufficient reason to merge
PR371 or PR381. A bounded test-helper correction and negative controls are
proposed in the ticket; no implementation, test-source, protected-file,
task-state, GitHub or frozen-evidence change was made by this diagnosis.
The original PR371 shell failure's precise cause remains unproven; this new
defect concerns the existing main/PR381 mitigation, not a claim of that cause.
