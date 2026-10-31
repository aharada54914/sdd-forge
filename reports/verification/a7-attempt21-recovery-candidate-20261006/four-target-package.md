# A21 four-target candidate package — UNRELEASED

Task: A7 A21 prospective diagnostic recovery contract alignment, 2026-10-06.
Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7` (existing dirty checkout preserved).
Risk: protected evidence/identity contract; candidate-only work, no original application.

The earlier three-Python-file independent safety review does not cover this new
skill/package revision. Final independent review of these four exact targets is
pending. `human-apply.py:19` retains `RELEASE_READY = False`; the owner helper was
not executed, even for inspection. Protected application still requires genuine
human operation under `docs/development-policy.md:35-38`. No source, ledger,
approval, reservation, frozen artifact, verdict or task state was changed.

## Bounded document alignment

The full original skill was read before creating its candidate. Its existing
allocation requirement at `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:87-88`
remains verbatim; the candidate adds one explicit diagnostic-only exception
immediately after the existing complete-round validator requirement. Only
`failed_turn.failure_mode: native-nontty-malformed-result` may preserve a failed
final round lacking original allocation/proposal evidence; that absence is not
backfilled, authenticated or promoted into historical host evidence. The new
paragraph requires `failed_turn_sha256`, exact inventory, invocation/reservation,
expected prompt/receipt/native transcript equality and completed end_turn, while
retaining canonical ledger/input/complete-round contracts. Ordinary and completed
round allocation/proposal/preflight requirements remain mandatory.

The failed inventory remains exactly `precheck-result.json`,
`reviewer-a-cli-stderr.txt`, `reviewer-a-cli-wrapper.json`,
`reviewer-a-first-turn.txt`, `reviewer-a-reservation-receipt.txt` and
`reviewer-a-role-config.json` (`failed-last-attempt.candidate.py:92-95`). Earlier
completed rounds retain the exact23 inventory and canonical validator checks;
the source algorithm is unchanged in this package revision. Proposal step7 is
now drafted as a candidate skill alignment, not formally applied or completed.

## Fixed package hashes

| Original target | Original SHA-256 | Candidate SHA-256 |
|---|---|---|
| `plugins/sdd-review-loop/scripts/failed-last-attempt.py` | `e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f` | `438431a8f75ff83d302413ed69c8d66bf0b44aab80d5d7c1ab72cb55b1e74dc5` |
| `plugins/sdd-review-loop/scripts/fresh-review-recovery.py` | `88a2775809e587008d2aefdd9b05f1aaef1fde6b0a3e604b6249d4c2a3e1e037` | `7c61cfdfb92cf885a974881d3264418ef09f10264db2eb87701237cc15cfb6c1` |
| `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` | `fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd` | `fe5274cf4f49c324c6ef05efaf079c2d66ab11b05af3ef08e60ffe63b6b71b64` |
| `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` | `eb1a7d506ee3308817aebb6f02b3b41e9562dc134347e3b1470fa7bcfca05d1b` | `2b7763cb3b49c5fad4a82b677b70a9d336f0edbd9ed9731e8cafb76584635e3b` |

`candidate.patch`: `8359ff939c5da6fc5dfab435ebabb73097c62f7af1283debb1e90508277970ca`.
`human-apply.py`: `c19a383971bfa07a7e2d1ca5e7bcc2da96e353bc62c513f338a9a9476f051c49`.
`human-apply.tests.py`: `50ee5eca3dfa1beb89d8e5112b566a4df2c31ec75a0472dbbb7743c218132ad2`.
All four original hashes were reread and match the preparation pins.

## Executed fixture verification

All commands used `rtk proxy python3`, login=false, from the owner checkout.
`human-apply.tests.py`: existing9 plus fourth-target source-hash mismatch =10,
exit0. Disposable roots only: normal four-target git apply --check/apply,
backup/readback and no-op; unreleased flag refusal; patch/candidate/source
mismatch; partial apply; symlink; mid-backup mismatch. Output retained in
`four-target-suite-0.stdout.txt`.
`recovery.tests.py`:19 exit0 (`four-target-suite-1.stdout.txt`).
`additional.tests.py`:34 exit0 (`four-target-suite-2.stdout.txt`), including full
A21 authority/inventory/ledger/canonical complete-round admission, historical
and current mismatches, old truncated fixtures, valid ordinary raw JSON,
duplicate wrapper refusal, and bash/PowerShell precheck/lock parity.

These 53 recovery regressions plus10 fixture apply checks are candidate evidence,
not formal review, live-host acceptance, protected application or task completion.
Earlier reports and evidence remain retained; this revision supersedes only the
three-target release-package hashes in human-apply-preparation.md.
