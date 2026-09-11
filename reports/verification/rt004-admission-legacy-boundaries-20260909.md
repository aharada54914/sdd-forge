# RT-20260908-004: admission candidate and legacy controls

Date: 2026-09-09
Disposition: incomplete; not ready for human application or merge.

## Candidate progress

`adr-runtime-lexical-candidate-20260909.patch` now includes both Bash and
PowerShell admission call sites, in addition to the lexers, safe-file checks
and complete precheck/design/ADR binding helpers. SHA-256:
`ebbb6f890c72ae6f375608d26cb764d3639435be7dba4f79b4f1bde0e7a5cb1c`.
See `adr-runtime-lexical-candidate-status-20260909.md` for source-review scope,
remaining findings and six checked patch-data hunk counts. Protected validators
were not modified, copied, applied or executed as candidates. No applicability
test or formal independent implementation verdict was produced.

## Actual-runtime test evidence

Added three common fixture modes to `tests/impl-review-adr-inputs.tests.sh`:

- `legacy-declared`: a design may contain an ADR reference while a historical
  precheck lacks the extension; no ADR is admitted and legacy inputs remain valid.
- `legacy-injected`: a legacy precheck cannot authorize an added ADR input.
- `zero-bound`: an empty declaration set with an explicit empty extension is valid.

Each runs for Bash and macOS PowerShell, with both implementation-review roles:
12 additional executions. Positive cases require successful exit and a two-record
ledger; negatives require rejection, no timeout/launch failure, and unchanged
ledger bytes. No product functions are mocked and no existing assertions were
weakened. Primary source review of the fixture changes found no Critical defect;
candidate-wide filesystem/platform warnings remain unresolved.

Commands:

```text
rtk proxy bash -n tests/impl-review-adr-inputs.tests.sh
rtk proxy bash -c 'bash tests/impl-review-adr-inputs.tests.sh > /tmp/rt004-admission-legacy-boundaries-20260909.log 2>&1'
rtk proxy git diff --check
```

Syntax and whitespace checks exited 0. Suite handle 38538 terminated with exit 1:
**112 passed / 64 failed**, across 176 actual-validator executions. All 12 new
compatibility checks passed. The 64 failure lines exactly match the preceding
164-case run; none was fixed or reclassified. These are unchanged-runtime
baseline results, not evidence that the candidate succeeds. Native Windows and
candidate runtime validation were not performed.

Test SHA-256:
`4ab1d3590d9b0dc1f2eb84bb83a74057b29bac221c6a9427d2fceaa9d8db5d2c`.
Log: `/tmp/rt004-admission-legacy-boundaries-20260909.log`, SHA-256
`92257e9ecd8c71ff4bfb5257ab2bad4952c8a091f1994299517bd02506c67f8c`.
An independent count of log result lines confirmed 112/64 and 12 new passes.

## External state and next action

Fresh `gh pr list` returned seven open PRs with unchanged heads: 401, 400, 394,
390, 381, 371 and 245. All CheckRuns were terminal. PR400 retained 25 successful
Actions checks, but its formal local review findings remain unresolved. PR245
had no Actions checks and a merge conflict. The other five retained failures.
No unchanged CI was restarted; no merge, commit, push or issue closure occurred.

Continue the seven downstream runtime consumers and required byte/filesystem
regressions under the approved RT-004 plan. Complete independent security review
before presenting a human-application package. Do not apply this partial patch,
change frozen verdicts or treat this checkpoint as ticket resolution.
