# T-005 TDD Red Evidence

Recorded: 2026-08-09 (Asia/Tokyo)

The Red oracle was
`specs/epic-196-a8-integration/verification/T-005/permissive-validator.py`.
It deliberately accepts every input, emits `discharged`, and performs no
nonce-ledger write.

## POSIX twin

Command:

```text
LIVE_HOST_VALIDATOR="$PWD/specs/epic-196-a8-integration/verification/T-005/permissive-validator.py" bash tests/validate-live-host-proof.tests.sh
```

Result: exit 1; **2 passed, 81 failed**.

Every required named rejection was red because the stub exited 0 without the
required diagnostic: `ERR_MISSING_CELL`, `ERR_SCHEMA_INVALID`,
`ERR_CELL_RUNTIME_MISMATCH`, `ERR_FEATURE_CONFIG_MISMATCH`,
`ERR_NONCE_UNKNOWN`, `ERR_NONCE_REUSED`, `ERR_NONCE_CELL_MISMATCH`,
`ERR_NONCE_ISSUED_AFTER_SESSION`, `ERR_NONCE_EXPIRED`,
`ERR_NONCE_DUPLICATE_LEDGER_ENTRY`, `ERR_ISSUER_SIGNATURE_INVALID`,
`ERR_HASH_MISMATCH`, `ERR_DIGEST_MISMATCH`, `ERR_SIGNATURE_INVALID`,
`ERR_SIGNER_UNTRUSTED`, `ERR_SIGNER_IDENTITY_MISMATCH`,
`ERR_SIGNER_KEY_COLLISION`, `ERR_SYNTHETIC_SUBSTITUTION`, and
`ERR_STALE_SKIP`.

All 32 required-field presence checks and the independent type/format family
checks were also red. The missing/replayed/malformed signature cases,
automated/manual mismatch, FAIL verdict, the two `pending` states, atomic
all-or-none update, and lock contention failed. Only the deliberately vacuous
discharged check and the no-op byte comparison passed.

## PowerShell twin

Command:

```text
pwsh -NoProfile -Command '$env:LIVE_HOST_VALIDATOR = (Join-Path (Get-Location) "specs/epic-196-a8-integration/verification/T-005/permissive-validator.py"); & (Join-Path (Get-Location) "tests/validate-live-host-proof.tests.ps1"); exit $LASTEXITCODE'
```

Result: exit 1; **2 passed, 81 failed**, with the same per-case outcomes as
the POSIX twin.

This establishes non-vacuity before the validator implementation exists.
