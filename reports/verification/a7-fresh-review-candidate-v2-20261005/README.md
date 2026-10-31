# A7 fresh-review recovery v2 candidate — 2026-10-05

Status: candidate only; NOT APPLIED, NOT BEHAVIORALLY VERIFIED, NOT FORMAL REVIEW.
Owner: /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge
Expected HEAD: d64cffcb22b114779202847be33e41700c4ba11f

## Scope and audit disposition

This separate package amends the five currently applied v1 files. The v1 package,
runner, backup-l4nnz4to and all historical review evidence remain unchanged.

The earlier proposal to prove the 8→9 transition retrospectively is superseded
for this candidate: v2 records transition_legality=not-established and
outputs=diagnostic-only. Neither the historical resumed PASS nor the transcript
is accepted as new review evidence. Terminal and reservation validators remain
mandatory before and after the lock; their success is record integrity, not
proof of intervening transition legality. Old --recover-interrupted is unchanged.

The new authority record is an orchestrator transcription of an actual user
statement, pinned to current inputs and the next attempt. It is expressly NOT a
signature, a registered human identity, a human-authored document, or sudo grant.
The existing validate-approval-sidecar.py is scoped to project-context /
provider-bindings and HMAC/registered approvers; this audit record does not replace
or satisfy that mechanism. sudo-mode-policy.md does not permit agents to mint
sudo authorization. Neither mechanism is invoked or weakened here.

The main orchestrator must save the actual conversation approval before creating
a real contract. Required audit JSON fields (exact):
schema=spec-fresh-review-approval-audit/v1, feature,
next_attempt, origin=current-user-conversation, recorded_by_role=orchestrator,
user_statement (actual quote), scope=quarantine-history-and-start-fresh-review-only,
input_hashes (same current hashes as the recovery contract).
Known approval reported by the main orchestrator:
「全部承認する 追加で何回でもレビュー、限定修正して良い」.
This README is not that approval record. No real recovery contract was generated.

Both approval record and v2 contract must remain under reports/verification.
The evidence array pins approval, diagnostic transcript, all historical files and
both invocations. Precheck persists contract path and SHA. Future mutation fails
hash checks; no historical file, reservation or task status is rewritten.

Fixture-only temporary roots use resolve() to normalize macOS /var aliases;
regular evidence path symlink rejection is unchanged. Synthetic approvals and
transcripts are test data only. The v2 fixture has twelve cases per runtime,
including authority hash/scope and history-disposition negatives. The original
transcript-session case now rejects an unrepinned diagnostic-byte mutation;
it deliberately does not attest to the historical transcript's legality. It has NOT run.

## Checks completed (data and syntax only)

- Bash -n: exit 0.
- PowerShell Parser.ParseFile: exit 0.
- Python AST parse of helper, fixture, runner: exit 0; no module execution.
- git apply --check recovery.patch: exit 0, against current owner bytes.
- Static runner TARGETS inspection: all five before/after hashes match.
- No runner dry-run, --apply, --restore, helper or fixture execution.
- Parent-reported applied-v1 regressions: 48 groups PASS, recorded separately in
  reports/verification/a7-applied-recovery-regressions-20261005.md.
  These are not v2 behavioral evidence.

## Hashes

Runner SHA-256: 346c3677dba0e44bb776bea7f30fb5617f235125685afa7227cd3aa38b56218c
Patch SHA-256: 0a30c008298d49ce8bc06509d3a72ee82a461543a930e479190b85ce69a3c875

plugins/sdd-review-loop/scripts/spec-review-precheck.sh
- before: 7c540cb425de6ee430689d0d4bb02ba6068c0c9dee7401c8d6e5dd8b1a1f24d6
- after: 13edd6165b011ee877eadb84d4cc39b5a0243c24bfd37cfb1b9490d1781bac62

plugins/sdd-review-loop/scripts/spec-review-precheck.ps1
- before: 294956150a5bcfafc2d500e35aa9d6d247e5470162431dd5eb45a965ebb52528
- after: ca23b15becbf404038d3dca0b2ea407d96695fa74ee34af0febebe17938a9d08

plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md
- before: 8828e5103b669e39385f60720d2cc6a02e40f14d6e1e7758d3c07a94dfbfa7d4
- after: f1aeafb2ae59551743867c5d96a64679f056bb831c9ae266f83a060ed45f0264

plugins/sdd-review-loop/scripts/fresh-review-recovery.py
- before: b45adc1a7cb445819ce98f58aeb42db630cc4f32b36e0b950279404c3a8528f0
- after: dd6f639b9e15d0f2668c308c219636e273a5d54e19cba701d62509db9c65ba01

specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py
- before: b42bef4065a3c40f95eb5d96e3b1c76201086fad1e568cf0f76c408bdcd6dd11
- after: 9305fc715d36af779c4adb83ba16f903064e36e0e4710c1378da5825d7b595e1

## Human-only apply and restore

After candidate review, the single apply command is:

```sh
rtk proxy python3 /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-fresh-review-candidate-v2-20261005/human-apply.py --apply --expect-runner-sha256 346c3677dba0e44bb776bea7f30fb5617f235125685afa7227cd3aa38b56218c
```

Omit --apply and --expect-runner-sha256 for the runner's no-write dry-run.
The runner binds owner HEAD, target before hashes and candidate after hashes,
rejects duplicate apply, uses a package lock, backs up all originals with a
receipt, rechecks before writes, and verifies every replacement by readback.
It never runs candidate code or creates a review reservation.
Partial failure is NOT success: inspect its printed Backup path and receipt.

Restore using the exact Backup directory printed by this v2 runner:

```sh
rtk proxy python3 /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-fresh-review-candidate-v2-20261005/human-apply.py --restore /EXACT/PRINTED/V2/backup-directory --expect-runner-sha256 346c3677dba0e44bb776bea7f30fb5617f235125685afa7227cd3aa38b56218c
```

Restore accepts only this package's matching receipt and known before/after
bytes, restoring the applied-v1 baseline. Keep the old v1 backup for any later
separate rollback. Do not run the old runner for this v2 update: its original
before pins reject the current applied-v1 state. Once v2 is applied, v1 restore
also rejects unknown v2 bytes; restore v2 first.

Next: independent static review, human apply, isolated behavioral regressions,
then approval audit/contract preparation and fresh host launch. No PASS, Done,
formal review, reservation, or real attempt-10 admission is claimed here.
