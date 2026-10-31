# RT002 installed update follow-up — 2026-10-03

Observed directly in the bounded-integration checkout; no formal verdict or lifecycle transition.

| Original-path command | Observed result |
|---|---|
| `rtk proxy bash tests/check-hook-activation-handshake.tests.sh` | PASS 984, FAIL 0; process exit 0 |
| `rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1` | PASS 985, FAIL 0; process exit 0 |

Both runs were on macOS, not native Windows. Execution handles were 53879 and 80840. Their terminal output was observed through completion; intermediate output was truncated by the tool and is not represented as a retained full log.

The source verifier and installed 1.18.0 verifier both directly rehashed to `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`. Suite hashes were Bash `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` and PowerShell `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd`.

The new installed-update backup identified by the maintainer (`sdd-rt002-installed-30wspkcp/prior.py`) directly rehashed to `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`. This is a different backup from the older `bb388d...c3d5` backup named in the approved task; they must not be conflated.

This follow-up did not perform native activation or installed restoration. Independent quality verification, lifecycle completion, current-head CI and merge remain separate obligations. No approval, historical verdict, commit, push or merge changed.

## Adapter isolation check

Executed `rtk proxy python3 reports/verification/rt002-installed-118-human-20261003.py --self-test` in this checkout: exit 0, `Installer isolation checks: PASS (apply, restore, two hash refusals, symlink refusal)`.

The adapter verified its pinned helper before invoking the existing temporary-directory self-test. This proves the helper's synthetic apply/restore and refusal paths, not restoration of the actual installed verifier or a byte-for-byte restoration trial with the new backup. The installed target was not modified. The new `d9277...` rollback path remains additional to, not a replacement for, the approved `bb388...` backup criterion.
