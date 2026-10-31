# T-004 approved recovery: applied-contract validation

Date: 2026-10-04
Owner: /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge

## Applied bytes and regression

The human reported applying the reviewed eight-target patch with backup at
`/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-t004-recovery-human-backup-5HTDlb`.
All eight current file hashes were read back and matched the after pins in
`reports/verification/a8-t004-recovery-v2-pins.json`.

| Command | Observed result | Saved capture |
|---|---|---|
| bash tests/review-context-boundary.tests.sh | exit 0, PASS 84 / FAIL 0 | boundary.log |
| python3 tests/issue311-scratch-isolation.tests.py --repo . | exit 0, PASS 60 / FAIL 0 | scratch.log |
| python3 tests/review-scratch-history.tests.py --repo . | exit 0, PASS 26 / FAIL 0 | history.log |
| bash tests/review-agent-isolation.tests.sh | exit 0, sequential identities/hash-chain successful; nested history PASS 26 / FAIL 0 | isolation.log |
| bash reports/verification/a8-t004-recovery-reserve-fixture.sh | exit 0, 14 negative cases plus archive authorization and positive controls, bash and pwsh | reserve.log |
| git diff --check | exit 0 | observed tool output empty |

All commands ran through rtk proxy with login=false on macOS. No live session
remains. These are contract regressions, not a primary evaluator verdict or
native host activation proof. Captures preserve tool-returned output, including
truncation markers in boundary.log; they are not reconstructed full stdout.

The original canonical implementation report remains byte-identical:
`48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f`.

## Next legitimate boundary

The applied quality-gate recovery paragraph requires a fresh isolated
implementation context, not this longstanding coordinating session. That fresh
context must verify pinned current task/source inputs and run the T-004 checks,
then emit a new noncanonical recovery report plus a task-input-manifest/v1 with
observed fresh run/session/agent identities and canonical absolute scratch root.
No historical identity or scratch path may be reconstructed.

The task-input validator permits exactly its required schema keys; scratch root
belongs in the implementation report, not an invented manifest extension.
Manifest inputs and outputs must not overlap. Therefore the old canonical
report can be an input while the new report initially has a distinct output
path. Archive the exact old bytes without replacing them, pin the archive and
old former path in the supersession note, and have both reports and hashes
independently checked before promoting the new report to the canonical path.
An archive needed by the evaluator requires an explicit Outputs path/hash row.

New evidence, source, contract, guard dependencies, baseline preservation
evidence, and deterministic checks intended for evaluator use must each have
exact Outputs path/hash authorization; no broad directory grants. The input
manifest must be cited exactly and declared by implementation_manifest in the
later one-role review-context-invocation/v2. Real reservation is last, immediately
before actual isolated evaluator launch; do not reserve speculative sessions or
insert an implementation reservation.

No formal evaluator was reserved or launched here. The parent must confirm the
installed evaluator's actual startup contract and the final input boundary
before formal launch. Evaluator scratch allocation does not grant write
permission; the evaluator remains read-only, including within scratch. Do not
introduce evaluator self-canary requirements. Independent evaluation, current
head CI, contract completion, evidence bundle and Done remain unproven.

