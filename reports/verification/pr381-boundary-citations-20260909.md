# PR381 boundary citation repair

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db`, with existing recovery changes preserved.

Scope: the user's explicit approval to update stale source-line references, without weakening validation. This repair changes only citation positions in `plugins/sdd-review-loop/references/review-context-boundary.md` and the matching anchor rows in `tests/review-context-boundary.tests.sh`. It does not implement or resolve the separate ADR-extension ticket RT-20260908-004.

## Evidence

- Before: `rtk proxy bash tests/review-context-boundary.tests.sh` exited 1 because the schema predicate was cited at line 245, while the actual predicate is at line 271.
- Source constructs were inspected before selecting each new span. All 31 anchor patterns were preserved. The previous-round summary and mode-admission references remain unchanged because they are still correct.
- After: `rtk proxy bash -o pipefail -c 'bash tests/review-context-boundary.tests.sh 2>&1 | tee /tmp/pr381-posix-20260909.WaPopD/review-context-boundary-after-citations.log'` exited 0 (session 95611 terminal). All 31 anchors and 22 runtime cases passed, including both Bash and macOS PowerShell. Native Windows is not implied.
- Primary review: no Critical finding in this citation-only diff. A read-only Node assertion normalized only citation positions and proved both files otherwise byte-identical to HEAD. All runtime fixtures, rejection diagnostics and executable assertions are unchanged. This is not an independent quality-gate verdict.
- Bash syntax and `git diff --check` exited 0.

SHA256:

```text
fb282fb064f18a85b59c2893b754b34874ee9340a87190591c6bed0eb05d90a4  plugins/sdd-review-loop/references/review-context-boundary.md
8ae0f120a7d4778ba1370fd4f5056cb0c8a61a28ea7da25273eb7dfeb0842b9a  tests/review-context-boundary.tests.sh
adc3fcaad7d17abff2fde01570a7c72bdf4033589e0cecfaca238285d2fb4620  /tmp/pr381-posix-20260909.WaPopD/review-context-boundary-after-citations.log
```

## Remaining work

Of the original 43 failing suites, adversarial-review-contracts and review-context-boundary now pass scoped reruns. The remaining 41 baseline failures are unresolved; no new full-run PASS is claimed. Formal independent gates, complete native CI and merge remain pending. Historical FAIL evidence, task statuses, review verdicts and identity ledger were not changed.
