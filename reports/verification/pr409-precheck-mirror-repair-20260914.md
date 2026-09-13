# PR #409: applied precheck mirror repair

Date: 2026-09-14 (JST)
Baseline: 5d6bb51eca3b3eb3102796f0a8a92132d7b17227

## Reproduced failure and cause

CI run 34764358486, Ubuntu job 103742578608 and macOS job
103742578642, failed TEST-036.4 with `applied hash mismatch` for
`plugins/sdd-review-loop/scripts/spec-review-precheck.sh` (45 passed,
1 failed). The authorized live precheck repair was not yet reflected in
the A3 applied human-copy bundle. The mirror checker also reported exactly
two stale applied mirrors before repair.

## Change and review

Ran the existing `scripts/sync-human-copy-mirrors.py` synchronizer. Only the
A3 Bash and PowerShell precheck copies and their two manifest rows changed.
Inspected the complete scoped diff: copies reproduce the already-applied
precheck repair; no test, enforcement condition, review verdict, or task
status was relaxed or rewritten. Pending candidate bundles were left alone.
Unrelated dirty review evidence and specification changes are excluded.

## Executed verification

On macOS, one sequential command completed with exit 0:

```sh
bash tests/check-component-coverage.tests.sh &&
pwsh -NoProfile -File tests/check-component-coverage.tests.ps1 &&
bash tests/human-copy-mirror-freshness.tests.sh
```

- Bash component coverage: 46 passed, 0 failed.
- PowerShell component coverage: 47 passed, 0 failed.
- Both runtimes passed TEST-036.4, including all 12 bundle hash and live-byte checks.
- Mirror freshness: 6 passed, 0 failed, 17 pending (informational, not passes).
- Execution output is in the task tool transcript; no complete disk log was captured.

This addresses the mirror failure only. The separate stale task-plan
provenance failure, blocked formal reviewer launch, required approvals,
latest-commit CI, and merge remain unresolved. macOS PowerShell verification
is not a Windows execution or proof of live host activation.
