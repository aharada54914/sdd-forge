# Independent Major1 candidate re-review — 2026-10-06

Result: PASS for the bounded three-Python candidate safety review and Major1 repair. Release/application readiness remains INCOMPLETE because the required contract documentation is absent (see below). This is not a formal SDD verdict, approval, quality gate, or permission to apply/reserve/launch.

Unresolved findings in this reviewed scope: Critical 0; Major 0. The previous Major1 is resolved by the evidence below. The original `independent-candidate-review.md` remains unchanged as historical NEEDS_WORK evidence.

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`; HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. Existing dirty work retained. This new non-frozen review report is the only authored file during re-review. No original implementation, reservation, ledger, approval, task state or formal verdict was changed.

## Exact candidate and change boundary

- Patch SHA-256: `bc99b48a357ac3209a20242ce06facc6bb09fa2bf620ca43f99a85480e78834c`.
- Failed helper candidate: `438431a8f75ff83d302413ed69c8d66bf0b44aab80d5d7c1ab72cb55b1e74dc5`.
- Fresh helper candidate unchanged: `7c61cfdfb92cf885a974881d3264418ef09f10264db2eb87701237cc15cfb6c1`.
- Non-TTY helper candidate unchanged: `fe5274cf4f49c324c6ef05efaf079c2d66ab11b05af3ef08e60ffe63b6b71b64`.

Independently read the actual diff and computed the prior failed-helper hash after replacing only the new `meaningful` termination block with the previous `assistants` block in memory. The result equals the previously reviewed `d58ea713d87099c5f600916bc8bc8ee0534f1e93966b68d980ce698dc618ace8`. Thus this repair changes only the new malformed diagnostic's completion check; old truncated branch and shared delivery/postflight code remain byte-identical to the prior candidate.

`failed-last-attempt.candidate.py:210-213` now requires the last meaningful user/assistant event itself to be an assistant with `stop_reason == end_turn`. A trailing unanswered tool-result user therefore cannot inherit the earlier assistant completion.

## Independent executions

All commands were executed from the owner checkout through `rtk proxy`, with `login=false` and `PYTHONDONTWRITEBYTECODE=1`. Fixture writes were confined to disposable temporary trees.

1. `python3 reports/verification/a7-attempt21-recovery-candidate-20261006/recovery.tests.py`: exit 0, 19 PASS cases. New negative output:

   ```text
   PASS reject unanswered tool-result after end_turn native failed turn did not end
   ```

2. `python3 reports/verification/a7-attempt21-recovery-candidate-20261006/additional.tests.py`: exit 0, 34 reported PASS cases, including 18 old truncated-mode cases, ordinary raw JSON postflight success, duplicate-wrapper refusal, completed-round allocation requirement, historical admission, shell/PowerShell completed-contract validation, locking and replay refusal. The script additionally runs the 19-case suite with captured stdout; this is not counted as additional unique cases.

3. Independently repeated the exact mutation from the previous review without using the new negative test function: copied the fixture, appended a user event containing only a `tool_result` after the completed assistant, recomputed the fixture transcript pin, then called `inspect()` directly. Required a `ValueError` with the exact text `native failed turn did not end` rather than accepting any exception. Exit 0:

   ```text
   PASS only the reviewed Major1 block changed from previous candidate
   PASS independent original reproduction rejected: native failed turn did not end
   ```

The independent mutation was the same JSON payload recorded in `independent-candidate-review.md`; only the expectation changed from acceptance to exact rejection. Ordinary fenced output remains rejected by postflight; ordinary raw JSON returns transport-only `DELIVERY_OK`. Existing historical/current hash separation and closed evidence/approval bindings were untouched by this repair.

## Original-source readback and limits

Original source SHA-256 values independently match the prior review/status:

- failed helper: `e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f`.
- fresh helper: `88a2775809e587008d2aefdd9b05f1aaef1fde6b0a3e604b6249d4c2a3e1e037`.
- Non-TTY helper: `fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd`.

53 unique existing/new fixture cases passed, plus the separate independent reproduction. No installed native-host execution, exact-HEAD CI, formal SDD review/quality gate, original-source application or A21 reservation was performed. Synthetic fixture authority remains fixture-only. This candidate re-review must not be promoted to any of those statuses.

## Contract-documentation gap before application

Proposal step 7 explicitly requires documenting the new diagnostic opt-in in `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`. The candidate patch contains only three Python files, and the current skill has no `native-nontty-malformed-result` or `failed_turn_sha256` description. Its lines 87-88 still require the failed-round host allocation, while the new diagnostic mode intentionally has exactly six files without that allocation. Lines 91-106 describe the older round-1 transport inventory and its approval binding, but not the new later-round combination, six-file diagnostic inventory, successful completed-round 23-file inventory or scoped failed-turn approval binding.

This is an outstanding proposal deliverable and a contract-documentation inconsistency, separate from the resolved Python safety finding. A bounded documentation candidate must explicitly distinguish the diagnostic-only exception from ordinary mandatory caller-proposal/preflight, state the closed new shapes and approval digest, and preserve historical/current hash and lock-revalidation rules before a complete application package can be reviewed. No skill edit was made by this reviewer. The three-Python PASS does not establish proposal completion or authorize running ordinary precheck against the owner checkout.
