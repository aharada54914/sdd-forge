# RT004 applied producer verification — 2026-09-15

Scope: the four human-applied producer/downstream repairs for
RT-20260908-004. This record supersedes only the earlier unapplied/red
observations in `rt004-producer-handoff-20260911.json` and
`rt004-consumer-chain-gap-20260911.md`; those historical records remain intact.

## Verified files

| File | SHA-256 |
| --- | --- |
| plugins/sdd-review-loop/scripts/impl-review-precheck.sh | 9c79ab9c9cc821a7a4a36df713633063321a34573f320c7b235d5761db89f621 |
| plugins/sdd-review-loop/scripts/impl-review-precheck.ps1 | 72e03cfad7d35f8eb444fdd8db82b2aab705bdc33882e3dd4750d4a8017a47c4 |
| plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh | 003180de314177a2d5c6de0ee119e65dcebe4f4dd38178f72088160edc215057 |
| plugins/sdd-review-loop/scripts/task-review-precheck.ps1 | 0bf80235d96f4cc1f438d4a01df19a3f5e3b8e35548999495d97283b3fb1713b |

## Actual verification

- `bash tests/impl-review-adr-inputs.tests.sh`: exit 0. Admission 448,
  precheck 10, generation 30, downstream 32: 520 passed, zero failed.
  Log: `/tmp/sdd-rt004-applied-regression-20260915.log`.
- `bash tests/impl-review-round2-contract.tests.sh`: exit 0, all four
  reported round-2/investigation binding checks passed.
  Log: `/tmp/sdd-rt004-round2-20260915.log`.
- `bash tests/downstream-review-precheck-parity.tests.sh`: sequential
  rerun exit 0; Bash/PowerShell semantics equivalent.
  Log: `/tmp/sdd-rt004-downstream-parity-serial-20260915.log`.
- `bash tests/workflow-state-parity.tests.sh`: exit 0.
  Log: `/tmp/sdd-rt004-workflow-parity-20260915.log`.
- `git diff --check`: exit 0.

The first downstream parity invocation overlapped the round-2 suite; both
temporarily modify the same registry. Its unknown-feature failure is retained
in `/tmp/sdd-rt004-downstream-parity-20260915.log`, not counted as a pass.
The temporary fixture registry change was removed and verified identical to
the original tracked file before the successful sequential rerun.

All PowerShell results above are macOS executions, not native Windows proof.
The main-agent diff review found no blocking issue in these four repairs;
this is not a replacement for the ticket's independent/fresh formal review.

## Remaining work

The role instructions, orchestration instructions and contract template still
do not describe `adr_inputs` (checked in the two impl reviewer role files,
impl-review-loop/SKILL.md, and impl-review-contract.template.json). Complete
that authorized contract work before a new ADR-reading live review. Preserve
historical reviewer failures and reservations. This report does not set a task
to Done, close RT004, establish host activation, or claim CI/main integration.
