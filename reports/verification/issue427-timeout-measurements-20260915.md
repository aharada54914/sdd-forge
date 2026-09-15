# Issue 427: boundary timing diagnostics

Base: cfe65c02b604cb6426e7405b9244d00bb0ace67d

This diagnostic change does not resolve Issue #427. It reports existing
invocation and stub-start receipts after the runner returns, and calculates
startup elapsed inside the runner deadline. Missing receipts are not inferred
to prove that a child did not start. Actual child-exit timing remains unproven.

The two-second budget, 800 ms output margin, five repetitions per runner,
verdict checks, fake CLI, and cleanup assertions are unchanged. No observer
work was added inside the measured child deadline. The previous main CI run
34858247648 had no downloadable artifacts when checked; its missing raw
receipts cannot be recovered from that API.

## Local verification

- macOS PowerShell: `pwsh -NoProfile -File tests/cross-model.tests.ps1`:
  64 passed, 0 failed, exit 0.
- PowerShell syntax and extracted diagnostic calculation: valid receipt,
  missing start, and missing deadline: 3 passed, 0 failed.
- `git diff --check`: exit 0.
- All ten local boundary iterations emitted the new measurement. Derived
  startup elapsed inside budget was 290–306 ms; this is not Windows evidence.
- Log: `/tmp/sdd-427-timestamp-regression-20260915.log`, SHA-256
  `b7bd2dce4e6e65863834b6d88c19a5c7fa768b1f62be4953e0a9084e4c5b261d`.
- Test source SHA-256:
  `966d1c578ce8625f8acb675c70025898226c7be4404d6fa40360a42b04d785ac`.

Scope review found no changed assertions or production behavior and no secret
values in the new output. This is not an independent SDD verdict. Windows CI
on the new commit remains necessary before drawing a root-cause conclusion;
even a passing run alone does not prove the intermittent failure is repaired.
