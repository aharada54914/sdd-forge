# Issue #619: aggregate encoding across PowerShell runtimes

The correction is limited to `check-cross-model.ps1`: explicitly write UTF-8
without BOM and resolve the output against the PowerShell location. Consensus
policy and exit codes are unchanged. Implementation and regression tests were
delegated to Claude; the parent reviewed the diff and collected native CI results.

## Actual native comparison

| Stage | Commit / run | Producer | Result |
| --- | --- | --- | --- |
| Before production edit | `b055ffcb949b8f20a037fcc3a0eae16feb24f34a`, [39807715805](https://github.com/aharada54914/sdd-forge/actions/runs/39807715805) | Windows PowerShell 5.1.26100.33438 | 3 passed, 6 failed: `EF BB BF`, strict Python and Node rejected both aggregates |
| Before production edit | same | PowerShell Core 7.6.6 on Windows | 9 passed, 0 failed |
| After correction | `6f9728ab17cb38575a6d18f1ab55b5c28b4fcf41`, [39809502404](https://github.com/aharada54914/sdd-forge/actions/runs/39809502404) | Windows PowerShell 5.1.26100.33648 | 17 passed, 0 failed; prefix `7B 0D 0A` |
| After correction | same | PowerShell Core 7.6.7 on Windows | 17 passed, 0 failed; prefix `7B 0D 0A` |

The runner images changed patch versions between runs; each actual version is
recorded above. Windows jobs were respectively 119925300697 / 119925300116
and 119931592128 / 119931591655. Initial runs 39807574778 and 39807572586
failed at checkout because the diagnostic workflow omitted `core.longpaths`;
their skipped tests are not Red evidence. The next commit added the same
long-path environment used by the normal CI workflow.

The regression invokes the selected producer itself, checks its edition/version,
and gives its output to strict Python and Node consumers. It preserves PASS/FAIL
and non-ASCII model values. The correction also tests relative `--spec-root` and
an in-session PowerShell location different from the process working directory.
The extra two path cases explain the increase from 9 to 17 assertions.

## Local verification and continuing coverage

Linux PowerShell 7.6.7: encoding helper 17/17, cross-model suite 105/0,
empty-phase regression passed. Bash cross-model suite 82/0; version-heading
checks 23/23 and release-validation checks 8/8. Catalog tests passed (47 tests,
one existing skip) after supplying the already locked js-yaml dependency inside
the checkout. A symlink to another checkout was correctly rejected by its input
boundary and replaced by a local copy of the identical installed dependency.

Temporary mutations proved the regression rejects both a BOM-writing encoder
and a writer resolving against the process directory. These mutations are test
sensitivity evidence; the native before-edit run above is the actual defect
reproduction. Native 5.1 is explicitly skipped on Linux, never counted as PASS.

`tests/cross-model.tests.ps1` delegates to the new registered helper. The existing
Windows `gates` CI lane runs that suite and now exercises both Core and Desktop.
The branch-only diagnostic workflow is removed after native verification; its
run records remain accessible at the links above.

## Limits and historical files

The six previously reported BOM-bearing historical records are unchanged. Their
presence does not establish which runtime originally produced them. Other
`Set-Content -Encoding Utf8` writers remain investigation candidates, not proven
fixed by this change. Issue #620 additionally requires a valid complete weekly
audit; this producer correction alone does not establish its recovery.

This branch targets the user's `work` branch. Native results prove the bounded
fix at the tested commit; they do not mean it is merged into the default branch
or that all open issues are resolved.
