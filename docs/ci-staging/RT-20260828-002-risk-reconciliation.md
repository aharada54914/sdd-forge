# RT-20260828-002 risk-source reconciliation

This staging bundle records the protected-file repair for the risk-source
asymmetry identified in PR #403. The contract's `risk` value is compared with
`tasks.md`; a non-empty mismatch fails closed, and a present contract risk is
used for the critical two-person approval decision. Contracts without `risk`
retain the legacy task-file behavior.

The live protected files were not changed by the supervisor. Apply the three
patches below in the target checkout through the approved human path:

```sh
git apply --unidiff-zero docs/ci-staging/rt-20260828-002-check-state-bash.patch
git apply --unidiff-zero docs/ci-staging/rt-20260828-002-check-state-pwsh.patch
git apply --unidiff-zero docs/ci-staging/rt-20260828-002-gates-test.patch
```

## Candidate verification

- Bash candidate syntax: `sh -n` passed.
- Bash disposable full gate suite: `PASS: 164`, `FAIL: 0`; the added C-07.4
  mismatch case passed.
- PowerShell disposable candidate syntax: parser exit `0`.
- PowerShell disposable mismatch fixture: `risk_mismatch=detected`; the
  diagnostic contained both `contract risk` and `does not match`.
- All candidate diffs passed `git diff --check`; the zero-context handoff
  patches apply cleanly with `git apply --check --unidiff-zero`.
- The broad `tests/scripts.tests.ps1` run was started but did not complete
  within 1 minute 43 seconds on this macOS host and was terminated; it is not
  counted as a passing result. The focused PowerShell parser and mismatch
  fixture above are the completed checks.

The patch files are content-addressed for the handoff:

| File | SHA-256 |
| --- | --- |
| `rt-20260828-002-check-state-bash.patch` | `e7d5cc4e9eb150ecc5e9e2b138ff7ae83ae814adef754bc22aa4f397831e5840` |
| `rt-20260828-002-check-state-pwsh.patch` | `a3ef35fa52a26600cb3c308efa606b9991270548376691794457abaa9ff488ed` |
| `rt-20260828-002-gates-test.patch` | `ba46618a58768c6897604398b902672a7df05e051773634b8051a3fdbb654b8b` |
