# T-002 reopening: post-human-application regression

Date: 2026-09-09
Scope: existing regression only; no implementation or historical verdict edits.

The earlier report `rt005-reopening-contract-20260908.md` records the
pre-application RED result. Its pending-human-application statement is now
historical: the human supplied application output and the original repository
validators below now pass this bounded matrix. This does not resolve the
separate global phase4-docs provenance failure or confer a formal gate PASS.

Command: `rtk proxy python3 tests/workflow-state-t002-reopening.tests.py`
Working directory: `/Users/jrmag/sdd-forge`
Exit: 0

Complete stdout/stderr, joining the initial and final tool chunks:

```text
test_runtime_matrix (__main__.ReopeningTests.test_runtime_matrix) ... ok

----------------------------------------------------------------------
Ran 1 test in 30.033s

OK
```

The one unittest contains 24 cases × two runtimes (Bash and PowerShell) ×
two newline encodings (LF and CRLF): 96 successful subcases, zero failures.
Required runtime availability is asserted; no subcases were skipped.
Fixtures are disposable data; the actual repository validators were executed
without copying, renaming, or modifying them. This is macOS execution, not
native Windows evidence. Coverage percentage was not measured.

SHA-256 of the inspected inputs:

| Input | SHA-256 |
|---|---|
| tests/workflow-state-t002-reopening.tests.py | 2c13a604a8c007d2fb7a906d34c4830556829362fa1969f8542323d54ba972fc |
| plugins/sdd-quality-loop/scripts/check-workflow-state.sh | 15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e |
| plugins/sdd-quality-loop/scripts/check-workflow-state.ps1 | 7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644 |
| specs/workflow-state-registry.json | 21b10cd863c13a5d8399ea26dcc86ff9a0dedbe5eb3e91f89b6dbb134f0d18cf |

Remaining: existing/global suites, fresh formal manifest and independent
quality verification. No task status, ticket resolution, commit, push, merge,
or issue closure was performed. The formal-entry evidence mismatch is recorded
separately in `rt001-approved-amendment-progress-20260909.md`.
