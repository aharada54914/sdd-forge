# RT002 focused regression — 2026-10-01

This is a verification observation, not a formal review or task completion.

- PR: #528
- Checked HEAD: `96761ad2e3455ddc02d2b2925f1826cba3c4511d`
- Verifier SHA-256: `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`
- Executor: local Claude Sonnet; session `0830b573-40e4-42e2-88d9-3a23f2323869`
- Command: `rtk proxy sh tests/check-hook-activation-handshake.tests.sh`
- Actual tool result: successful execution, `PASS: 984`, `FAIL: 0`.

The supervising agent inspected the persisted tool result, not only Claude's
summary. TEST-090 accepted the exact bare operation-bound denial; TEST-091
accepted the exact wrapped denial. Malformed responses and cleanup failures
remained rejected. This is macOS fixture coverage, not installed-host activation.

Commit `ed936b69` already introduced the optional exact `Script error:\n`
prefix. The old human-application candidate's original-byte hash is historical;
its mismatch against the current fixed file is not a new regression and is not
a reason to reapply the old candidate.

The latest checked HEAD had all 37 Actions checks successful, including
`required-checks`. Current-head CI does not replace the outstanding independent
quality gate, component-coverage reconciliation, or native activation evidence.
No task status, approval, historical verdict, or protection was changed.
