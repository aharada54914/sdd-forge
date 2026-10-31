# T-001 owner regression readback — 2026-10-03

This is a non-frozen evidence index, not a raw test log or a quality-gate verdict.

The original differential raw logs remain in the source checkout at
`/Users/jrmag/sdd-forge/specs/epic-189-a1-rt002-repair/verification/`.
They are ignored by Git and were found with `rg --files --no-ignore`.
Current read-only SHA-256 and trailing assertion totals are:

| Original log | SHA-256 | Tail |
|---|---|---|
| `third-baseline-bash-20260927.log` | `51303df41675fe9987dd42f0463744c914a8983194653d9fdb9f58bbf2c494c4` | 199 PASS / 211 FAIL |
| `third-candidate-bash-20260927.log` | `abd21bd9ad742c07ce01e6d548ee592662fea32d7e6ec58bc15103a12765a9a7` | 410 PASS / 0 FAIL |
| `third-baseline-pwsh-20260927.log` | `ba80f5ce1014922417c2e8d22a5a5d59a40d05133d67f938a5247752cafc9ba9` | 199 PASS / 211 FAIL |
| `third-candidate-pwsh-20260927.log` | `bebcfd9304511ac24ad023b20ba7811b7cf3eb01a840d8e726ece73abd73a2d0` | 410 PASS / 0 FAIL |

The prior implementation report records differential process exits: baseline 1,
candidate 0 for each shell. This readback independently verified the preserved
bytes and tails, not those old process exits.

In the bounded-integration owner checkout, a new direct execution of
`bash tests/check-hook-activation-handshake.tests.sh` completed with 984 PASS,
0 FAIL, exit 0 (tool session 79139). A sequential new direct execution of
`pwsh -NoLogo -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`
completed with 985 PASS, 0 FAIL, exit 0 (tool session 34938). The tool stream
displayed the assertions and these terminal totals, but output truncation
means this note is **not** a byte-complete original log or a hash claim for
these new runs. The older 984/985 log hashes recorded in
`reports/verification/rt002-two-envelope-validation-20260929.md` have not
been reverified from their original raw files in this readback.

The owner source hashes read before these runs are verifier
`1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`,
Bash suite `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c`,
and PowerShell suite `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd`.
No source or task status was changed by these readbacks.
