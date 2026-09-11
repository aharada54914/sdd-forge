# Read-only integration refresh — 2026-09-11

Source: live `gh pr list`, `gh pr view 400`, `gh issue list`, and
`gh run view 34288587300 --log-failed`, repository aharada54914/sdd-forge.
No remote mutation or integration was performed.

26 issues and 11 PRs remain open. No open PR's returned check rollup has an
IN_PROGRESS or QUEUED check; these are terminal results, not a running CI wait.

| PR | Merge state | Failed checks |
| --- | --- | --- |
| 405 | DIRTY | 0 (not proof of CI completeness) |
| 404 | BEHIND | 4 |
| 403 | DIRTY | 0 (not proof of CI completeness) |
| 402 | BEHIND | 4 |
| 401 | BEHIND | 4 |
| 400 | BLOCKED | 0 |
| 394 | BLOCKED | 2 |
| 390 | BEHIND | 2 |
| 381 | BEHIND | 11 |
| 371 | BEHIND | 4 |
| 245 | DIRTY | 0 (not proof of CI completeness) |

PR 400 head `8fa3eb8561d6f59b692ec574900f87e181145928` has 25 completed
successful CheckRuns, including required-checks, plus successful CodeRabbit.
Review decision is REVIEW_REQUIRED. This is not a finding that all non-CI
merge prerequisites are satisfied. Revalidate exact head and required contexts
at integration time after the recovery entry exit is actually proven.

PR 404 run 34288587300 fails all three OS test jobs at PowerShell workflow-state
validation: `epic-195-a7-compatibility: stage-provenance: implementation design
hash is stale`. required-checks fails consequentially. This is a provenance
failure, not evidence of a transient runner fault; a blind rerun is not a fix.

The four RT004 producer/downstream protected originals still have their
pre-application hashes. The two human-only helper commands remain pending.
Recovery entry item 1 prohibits ordinary implementation/integration before its
item 6 live exit proof. Do not use the admin-review bypass approval to override
that distinct condition. Continue original-path regressions and repair-specific
reviews after human application; preserve prior failures as failures.
