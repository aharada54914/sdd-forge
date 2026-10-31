# A8 T-005 through T-008 current readiness

Read-only task assessment and existing-test execution on 2026-10-04, owner `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`. Not a quality verdict, lifecycle transition, native-host attestation, or three-OS CI claim.

## Current execution

All six commands below ran through `rtk proxy` on macOS. Complete combined stdout/stderr is saved in sibling logs with observed exit codes:

| Command | Result | Log |
|---|---|---|
| `bash tests/validate-live-host-proof.tests.sh` | 91 passed / 0 failed, exit 0 | `live-host-sh.log` |
| `pwsh -NoProfile -File tests/validate-live-host-proof.tests.ps1` | 91 passed / 0 failed, exit 0 | `live-host-ps1.log` |
| `bash tests/path-lineending-regression.tests.sh` | 63 passed / 0 failed, exit 0 | `path-sh.log` |
| `pwsh -NoProfile -File tests/path-lineending-regression.tests.ps1` | 63 passed / 0 failed, exit 0 | `path-ps1.log` |
| `bash tests/check-a8-process-integrity.tests.sh` | 9 passed / 0 failed, exit 0 | `process-sh.log` |
| `pwsh -NoProfile -File tests/check-a8-process-integrity.tests.ps1` | 9 passed / 0 failed, exit 0 | `process-ps1.log` |

These are existing fixture suites independent of the T-004 review-context recovery contract. Live-host-proof tests use disposable fixture registries, ledgers and generated test keys (`tests/fixtures/live-host-proof/run_cases.py:207-220,378-384,426-431`), not real operator keys or production nonce consumption. No duplicate review reservation or host signing was performed. A process inventory observed two PowerShell PIDs, both already exited on targeted follow-up before this work started its suites; unrelated application processes were left alone.

## Scope and remaining conditions

- `tasks.md:815,1121,1264,1441` still records T-005 through T-008 as Planned. Historical implementation reports do not supersede task lifecycle state.
- T-005 is the validator engine, not genuine five-cell host proof. Its Done When includes schema/errors/signing/replay/aggregate/registration/TDD/traceability and independent quality verification (`tasks.md:1045-1086`). Its historical report is still a preflight with pending summary/evidence and empty Outputs; current green tests alone do not repair that report or establish implementation provenance.
- T-006 has current local 63/0 pairwise fixture evidence. Its full existing three-OS CI, staged/cumulative registration evidence and formal quality verdict must be bound to the final integration head (`tasks.md:1224-1249`); local PowerShell on macOS is not native Windows execution.
- T-007 real-document tests and negative mutations currently pass. Its registration Done When still literally requires the already-CI-only T-004 `cli-hook-enforcement.ps1` in aggregate runners, plus all seven feature suites (`tasks.md:1401-1410`). The T-004 scope prohibits new registration. This cross-task wording must be reconciled through approved task provenance if consumed literally, not silently inferred satisfied. Current POSIX registration uses `tests/suite-inventory.posix:132-133,161`; PowerShell uses `tests/run-all.ps1:85-89`. No registration edit was made.
- T-008 alone owns genuine five-cell discharge and the human two-party signing step (`tasks.md:1618-1634,1650-1666`). Its five committed records remain `SKIP`, `UNSIGNED`, with `PENDING_HUMAN_OPERATOR` / `PENDING_HUMAN_REVIEWER` identities and null raw capture references. `a8-trusted-signers.json` has zero signers; `nonce-ledger.json` has zero entries. Thus no existing committed host proof or signer reservation can be reused as a genuine record.
- Agent generation/signing of genuine host records is explicitly out of scope. Fresh authentic sessions, registered independent operator/reviewer/issuer identities and attributable raw captures must precede validator `discharged`; fixture all-PASS control is not discharge of the production matrix. No canary or handshake was fabricated or borrowed from another session.

Production ledger SHA-256 after the fixture runs: `2042affc954b460842f6cf1294998eb4e2ee0e8b09e06f0ada63b8dccc8a3857`. Trusted-signers SHA-256: `f6ec9affdaec7ce9eab180b5dcad45a468dd083a0261aebba64392ead8176886`. Historical T-004 report remains `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f`.
