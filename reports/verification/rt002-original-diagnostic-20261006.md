# RT002 original-path diagnostic regression — 2026-10-06

Scope: current-checkout diagnostics only. This is not a formal implementation
revalidation, evaluator verdict, native activation, CI result, or Done decision.
No reservation, canonical report replacement, task-state update, or Git operation
was performed. Historical records and the old 67-input manifest are preserved.

## Observed execution

- Checkout: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`
- HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`
- Branch: `codex/rt002-host-denial-repair`
- The checkout has pre-existing tracked and untracked work; it was not cleaned.
- Shell launches used `rtk proxy`, with login shell disabled.
- Logs: `/tmp/rt002-original-diagnostic.JmxDwp/`

| Original-path command | PASS | FAIL | Exit | Log |
|---|---:|---:|---:|---|
| `bash tests/check-hook-activation-handshake.tests.sh` | 984 | 0 | 0 | `bash.log` |
| `pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1` | 985 | 0 | 0 | `pwsh.log` |

Both logs contain actual command output; `bash.exit` and `pwsh.exit` each contain
`0`. These are fixture suites, not a real host-dispatch/canary observation.

## SHA-256 readback

```text
0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c  tests/check-hook-activation-handshake.tests.sh
49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd  tests/check-hook-activation-handshake.tests.ps1
1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d  plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py
abde8035c825c318a56a3d9e1b24b2fd618553f10f9784ceae8ab2173eeadf0c  plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh
b15ef1ee7b8b89fb7717ed09b4d7c0e6150bbbd87478594f61a146b6596b30fb  plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1
b4d5f30b7c0ea192ec922ba99c95f2cfbd0fa13afd070674b7a740e5ecc14c2d  bash.log
ac17a42fe793e87d87f43f1f59d7637ccbbc52d0ccca638a33850706cd19c040  pwsh.log
```

## Input closure: confirmed gap, not a blanket completeness claim

The old manifest is
`reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/RUN-RT002-T001-REVALIDATION-20261005T043106Z-497150f9-9afe-4686-9f8a-9619f4014c6d/task-input-manifest.json`.
Its historical SHA-256 is
`affe26456f270f2fdf79552076f39ec1c43f18605569f52efaab4072fee7cfa5`.

It contains the two suites, both handshake wrappers, and Python verifier but
omits two executable dependencies:

- `check-hook-activation-handshake.sh:18` sources `lib/py-dispatch.sh`.
- `check-hook-activation-handshake.ps1:14` dot-sources `lib/py-dispatch.ps1`.

Both dispatcher files were read completely. They select an installed Python
runtime and execute the supplied master path; neither loads another repository
helper. The Python verifier imports standard-library modules. Thus adding these
two paths repairs the *identified handshake runtime gap*. It produces 69 entries
if the old 67-path set is retained unchanged; that arithmetic is not proof that
the complete new formal verification closure consists of exactly 69 inputs.

The old set also contains historical evidence, review records, and validator
inputs. A new formal run must select its actual commands and current inputs,
check their dependencies and hashes, and bind its own identity and output paths.
The current diagnostic logs and new recovery records may themselves become new
review inputs. No new 69-input manifest was created or declared complete here.

The inspected task-input validator uses embedded Python standard-library code;
`scripts/check-sdd-structure.sh` checks repository structure without sourcing
another script. Its advisory shared files/directories and the formal consumer
closure are not made hash-bound merely by this observation.

## Governance and next operation

`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:160-192` requires complete
input binding and an isolated, current-code recovery verification before canonical
adoption; it does not prohibit ordinary checkout regression diagnostics. Lines
195-228 retain evaluator identity/prelaunch/reservation requirements.

Next: prepare a fresh sanctioned recovery snapshot with the two dispatcher inputs
included and a checked complete dependency inventory for its chosen commands;
execute both original suites within that run, preserving raw logs and exit codes;
then perform independent old/new evidence comparison before adopting a canonical
report. Do not reuse the old run/session or reserve an evaluator on the strength
of this diagnostic record. Native activation, formal evaluation, CI, merge and
Done remain unverified by this record.
