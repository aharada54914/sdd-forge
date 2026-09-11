# Epic 194 scoped verification

Run date: 2026-09-05
CWD: `/Users/jrmag/sdd-forge`
HEAD: `ca023cc85d9db5d44f63ec77e4d3ff73f3f9bfdf`

The original wrapper's exact command was not retained in this report. The raw
summary retains each suite path and exit status. The following equivalent
commands reproduce all 22 suite invocations from the CWD above (this is not a
verbatim wrapper transcript):

```bash
rtk proxy bash -c '
set -e
for suite in human-copy-runner-contract check-risk-upgrade-byte-identical check-risk-upgrade-capability-merge check-risk-upgrade-fragment-fail-closed check-risk-upgrade-ineligible-no-reasons lite-spec-capability-block lite-gate-summary-consumption lite-gate-summary-absent lite-gate-summary-invalid lite-gate-full-upgrade-backstop lite-gate-summary-absent-active-enforcement; do
  bash "tests/$suite.tests.sh"
  pwsh -NoProfile -File "tests/$suite.tests.ps1"
done
'
```

Result summary:

- Bash suites: 11 passed, 0 failed, 0 skipped
- PowerShell suites: 11 passed, 0 failed, 0 skipped
- Suite total: 22 passed, 0 failed, 0 skipped

Assertion-level counts from captured stdout:

- `ok:` assertions: 440
- actual skipped assertions reported: 0

Primary review correction: two lines contain the word `skip`, but neither is
a skipped test. Both are successful assertions verifying a documented skip
clause. Counting these as skipped assertions was incorrect.

- `lite-spec-capability-block.tests.sh.out` and `.ps1.out` each contain `ok: TEST-019-static-f: disabled-legacy (no Project Context) skip clause present`

| Suite | Bash passed | PowerShell passed |
|---|---:|---:|
| human-copy-runner-contract | 56 | 56 |
| check-risk-upgrade-byte-identical | 17 | 17 |
| check-risk-upgrade-capability-merge | 9 | 9 |
| check-risk-upgrade-fragment-fail-closed | 67 | 67 |
| check-risk-upgrade-ineligible-no-reasons | 6 | 6 |
| lite-spec-capability-block | 31 | 31 |
| lite-gate-summary-consumption | 15 | 15 |
| lite-gate-summary-absent | 2 | 2 |
| lite-gate-summary-invalid | 6 | 6 |
| lite-gate-full-upgrade-backstop | 5 | 5 |
| lite-gate-summary-absent-active-enforcement | 6 | 6 |
| Total | 220 | 220 |

Every raw `Results:` footer reports 0 failed. These scoped tests do not prove
end-to-end A2/A5 integration or the issue's timing-regression condition.

Raw outputs:

- `/tmp/epic194-verify.tqGfue/summary.txt`
- `/tmp/epic194-verify.tqGfue/*.out`

Notes:

- No source, hook, or test files were modified.
- No timing/performance claim is made here because there was no baseline comparison.

## Issue-level closure gap audit — 2026-09-06 JST

The primary agent retrieved open issue #194. Its Done conditions explicitly include no execution-time or generated-artifact-count regression, and its dependencies name A2 and A5. These remain issue-level obligations; four Done task statuses do not alone discharge them.

A lightweight investigator claimed T-003 already covered the missing timing and end-to-end proof. Primary inspection of `tasks.md:650-725` does not support that claim: T-003 names REQ-005's pre-generation Block contract and its share of REQ-006 fixtures, and explicitly says its suite does not use T-002's live staged file. That is not a demonstrated performance baseline or live A2/A5 integration test. The proposed rerun of the same 22 suites would not answer the gap and was not performed.

A targeted case-insensitive search for `timing|performance|実行時間|生成物数|軽量性|latency|benchmark` returned no matches in A6 `design.md` or A8 `requirements.md`/`acceptance-tests.md`. A6 `requirements.md:190-197` uses “timing constraint” for pre-generation ordering, not an elapsed-time performance budget. This bounded search does not prove no evidence exists anywhere; it establishes that these locations do not supply the missing measurement contract. A6 `requirements.md:167-188` also distinguishes consumption of A5 output from implementing its resolver. Next closure work must identify or establish the actual baseline, equivalent end-to-end inputs, generated-file inventory and pass criterion through the applicable specification workflow; do not substitute fixture-suite runtime for product runtime or silently widen a frozen task.
