# RT002 current regression and review boundary

Verification note only; this is not an independent quality-gate verdict.

## Verified candidate

The bounded integration checkout was rechecked after the human three-file
application. SHA-256 values match the supplied application readback:

| File | SHA-256 |
| --- | --- |
| plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py | 1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d |
| tests/check-hook-activation-handshake.tests.sh | 0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c |
| tests/check-hook-activation-handshake.tests.ps1 | 49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd |

Read-only hash checks also confirmed the primary checkout's same three bytes
and the installed sdd-quality-loop 1.18.0 verifier's same `1057d1fc…` digest.
Byte identity alone is not fresh installed-host activation evidence.

Sequential macOS execution observed in this continuation:

- `rtk proxy bash tests/check-hook-activation-handshake.tests.sh`: 984 PASS,
  0 FAIL, exit 0 (execution session 56812).
- `rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`:
  985 PASS, 0 FAIL, exit 0 (execution session 65796).
- `rtk proxy git diff --check`: exit 0.

These observations do not establish native Windows execution, a fresh native
host activation, independent review, CI, or merge. The root checkout's earlier
runner-mismatch execution is not used as candidate regression evidence; see
`rt002-root-runner-mismatch-20261003.md`.

## Shared review repair must not be adopted unchanged

Read-only inspection of the issue423 shared candidate found a policy mismatch:
`implementation_input_is_declared` becomes a final quality evaluator input
authorizer in `validate-review-context-set.sh` (lines 285–313, 350–362), with
the corresponding PowerShell authorization at lines 923–926. Hash-pinned
membership in implementation `allowed_inputs` can admit an otherwise
undeclared path. The quality-gate skill instead requires individual report
declarations through `## Outputs` or `## Post-Fix Artifacts`.

Retain that existing declaration boundary; do not use manifest membership as
an additional authorization policy. The independent diagnostic agent's
isolated fixture was refused by PreToolUse before execution, so this is a
line-level finding, not a claimed successful negative test. Neither RT002
shared-repair candidate patch has been applied here. Formal launch remains
pending correction and verification of this shared boundary.

No task status, approval, review verdict, reservation, commit, push, or merge
was changed by this note.
