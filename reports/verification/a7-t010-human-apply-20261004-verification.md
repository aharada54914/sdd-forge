# T-010 latest human-only batch candidate

Date: 2026-10-04
Status: candidate only; human apply NOT EXECUTED; independent review NOT PERFORMED.

New script: `reports/verification/a7-t010-human-apply-20261004.sh`
SHA256: `05b89334ea1d790992b28d5bab96c17eb7833c968819f4eee9a7cd6ad16e9724`

Preserved old script: `reports/verification/a7-t010-human-apply-20261003.sh`
SHA256: `2441435d554dd693c615d483ed165112425eec88268599fce73babad7cb372af`

## Scope and authority

The human authorized preparation of the latest bounded application candidate, not agent execution of the application branch. `tasks.md:1368–1376` still records T-010 Approved (sudo 2026-08-08T16:33:11Z), Planned; that historical approval does not validate newly amended contract bytes. `AGENTS.md:46–59` freezes passed inputs; `spec-review-loop/SKILL.md:28–38,67–70` and `spec-review-precheck.sh:59–60` bind canonical input paths, not candidate overlays. The script consolidates the necessary human adoption operation; it does not release freeze authority, reset review statuses, reserve identities or claim a gate result.

The coder skill informed the minimal implementation, bounded checks and preservation of existing artifacts. No original specification, code target, prior candidate, old script, log, ticket, review verdict or task field was edited.

## Pins and target coverage

Three candidates are pinned and target order/uniqueness verified before any write:

1. Five-document contract patch: `ef99dc8a5e0da14164c07da63350dbdd84b61ae7666ed1e005d5747125403cf5`.
2. Security supplement: `dc27734d6d5663098c6a5221b309b0ecf8e349075d5f641b0698c14de0301e1e`.
3. Latest literal/case code and test patch (20261004): `1b6887a9eea1305042546a683ba1f8e4f34063e592b89c98468cfdccd3a40ca1`.

The same nine-target array governs preimage checks, backup, changed-byte readback and output hashing: requirements, design, acceptance tests, tasks, traceability, security layer, PowerShell evaluator, Bash suite, PowerShell suite. Each preimage hash was reread live and is pinned in the script. After read-only validation all nine hashes still matched those pins. The proposed security output additionally has a fixed postimage hash `6323026f1b1b867364cab929b056f55c3ef06e08f0609fe4de3c403362db25e5`.

The human-only branch backs up all nine preimages, checks the backups and live pins again, then uses a single combined `git apply --unidiff-zero`. It reads back all nine outputs and verifies reverse applicability without restoring or changing them. Ordinary `git apply` does not stage or commit. Zero-context acceptance is bounded by exact patch and preimage hashes. On failure the backup path is retained and no automatic restore is attempted.

## Executed checks

All shell entry calls used `rtk proxy`, login=false.

```text
rtk proxy bash -n reports/verification/a7-t010-human-apply-20261004.sh
exit 0; empty stdout/stderr

rtk proxy bash reports/verification/a7-t010-human-apply-20261004.sh --check
exit 0
CHECK OK: 3 hash-pinned patches; 9 unique preimages; combined applicability.
Backup/readback targets:
specs/epic-195-a7-compatibility/requirements.md
specs/epic-195-a7-compatibility/design.md
specs/epic-195-a7-compatibility/acceptance-tests.md
specs/epic-195-a7-compatibility/tasks.md
specs/epic-195-a7-compatibility/traceability.md
specs/epic-195-a7-compatibility/security-spec.md
tests/lib/skip-allowlist-evaluator.ps1
tests/skip-allowlist-manifest.tests.sh
tests/skip-allowlist-manifest.tests.ps1
Read-only check complete. No backup, target write, reservation or gate transition.
```

Backup and post-apply branches were inspected, not executed. This is applicability/script-syntax evidence, not end-to-end human application, tests, CI or independent gate evidence. No actual protection refusal occurred in these read-only checks; no alternate route was attempted.

## Single human operation and next boundary

Only if the human chooses adoption of these exact pins, from the owner checkout:

```text
rtk proxy bash reports/verification/a7-t010-human-apply-20261004.sh --human-apply <human-identifier>
```

This command is not executed by the agent. Successful adoption would still require freshly authorized spec/design/task review transitions and fresh manifests for every admitted layer. Historical Passed fields/reports remain historical evidence, never proof for amended bytes. The identity-allocation-before-first-turn requirement must also be satisfied before independent reviewer launch; this script does not attempt it. T-010 dependencies and final implementation/quality-gate conditions remain unresolved.
