# RT002 original entrypoint full-transcript rerun

Date: 2026-10-05. Owner checkout: this worktree, HEAD
`1e86fb272643e798db4e1ca0c89f0402317a2fc8`. Existing dirty changes retained.

This run supplements `rt002-original-path-regressions-20261005.md`: that
earlier run reported final totals but did not capture an untruncated transcript.
These are fixture regressions through the original dispatchers, not live-host
activation, independent evaluation, or delivery evidence.

Commands ran through `rtk proxy bash -o pipefail -c`, piping stdout/stderr to
`tee` without suppressing the suite exit code:

- `bash tests/check-hook-activation-handshake.tests.sh`: exit 0, 984 PASS,
  0 FAIL. Full log `/tmp/rt002-original-bash-20261005-current.log`, SHA-256
  `b4d5f30b7c0ea192ec922ba99c95f2cfbd0fa13afd070674b7a740e5ecc14c2d`.
- `pwsh -NoLogo -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`:
  exit 0, 985 PASS, 0 FAIL. Full log
  `/tmp/rt002-original-pwsh-20261005-current.log`, SHA-256
  `ac17a42fe793e87d87f43f1f59d7637ccbbc52d0ccca638a33850706cd19c040`.

Post-run readback confirmed the Python verifier and both test-suite hashes
below unchanged. PowerShell ran on macOS; this is not Windows-native proof.

Inputs observed during execution (SHA-256):

| Input | Digest |
| --- | --- |
| verifier Python | 1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d |
| check-hook-activation-handshake.sh wrapper | c9a6a330238e8b466a3e08345affc3e0d51545091c84150ade94f8f8a7b06e12 |
| check-hook-activation-handshake.ps1 wrapper | 5837fcfa74fd7ea277163df531e1b0d42841aa8a5f8ca68c2500f8e5d59a9f00 |
| Bash suite | 0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c |
| PowerShell suite | 49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd |

Additional post-run observations: installed 1.18.0 verifier equals source
`1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`;
`scripts/lib/py-dispatch.sh` hashes to
`abde8035c825c318a56a3d9e1b24b2fd618553f10f9784ceae8ab2173eeadf0c`,
and `scripts/lib/py-dispatch.ps1` to
`b15ef1ee7b8b89fb7717ed09b4d7c0e6150bbbd87478594f61a146b6596b30fb`.
These are post-run observations, not a pre-run dependency-complete manifest.

No reservation, historical verdict, approval, task status, installed guard,
commit, push, merge or Issue state was changed by these executions.
