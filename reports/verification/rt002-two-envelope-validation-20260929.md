# RT002 two-envelope regression verification — 2026-09-29

Scope: the human-applied two-line repair in
`plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py`.
This record is regression evidence, not a quality-gate verdict or task completion.

## Repair

The shared `_verify_codex_host_denial` parser accepts the exact bare host denial
and the same denial with exactly one `Script error:\n` wrapper. Whole-string
matching, the closed evidence schema, nonce validation and mutation rejection
remain in place. Both dispatcher surfaces exercise this shared parser.

- Prior source SHA-256: `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`.
- Applied source SHA-256: `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`.
- Diff: two line replacements; no test, acceptance criterion or approval changed.

## Executed regressions

Host: macOS. PowerShell: 7.6.2. Each full suite ran through its actual dispatcher.

| Command | Passed checks | Failed checks | Exit |
|---|---:|---:|---:|
| `rtk proxy bash tests/check-hook-activation-handshake.tests.sh` | 984 | 0 | 0 |
| `rtk proxy pwsh -NoLogo -NoProfile -File tests/check-hook-activation-handshake.tests.ps1` | 985 | 0 | 0 |

The suites include exact bare/wrapped acceptance and negative wrapper, nonce,
runtime, schema and cleanup cases. These counts are assertions, not distinct
end-to-end host activations.

Retained full-log SHA-256 values:

- Bash: `b4d5f30b7c0ea192ec922ba99c95f2cfbd0fa13afd070674b7a740e5ecc14c2d`.
- PowerShell: `ac17a42fe793e87d87f43f1f59d7637ccbbc52d0ccca638a33850706cd19c040`.

`git diff --check` also succeeded.

## Still required

The installed verifier was observed at the prior source hash, not the applied
candidate hash. Installed adoption, fresh native challenge/denial verification,
independent implementation quality verification, native Windows and current-head
CI, main integration and post-merge checks remain unproven by this record.
macOS PowerShell success does not establish native Windows success. The task and
historical review verdicts were not changed.
