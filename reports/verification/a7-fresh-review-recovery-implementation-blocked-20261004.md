# A7 fresh-review recovery — implementation blocked

Status: BLOCKED (implementation incomplete; no review or gate PASS)
Owner checkout: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`

## Approved narrow scope and intended admission

Separate `--fresh-review-contract=<path>` / `-FreshReviewContract` from the
existing no-output `--recover-interrupted` path. Preserve the terminal attempt,
both interrupted attempts, all outputs and reservations. Require next-attempt
round 1, current Pending input hashes, a pinned terminal → no-output interruption
→ invalid same-context resumed-output chain (A7 attempts 7 → 8 → 9), and validate
the terminal contract and persisted reservations again after acquiring the lock.
Success produces only the next precheck, not PASS, release of a consumed identity,
or reviewer launch. Python is needed only by the new explicitly selected route;
ordinary and old recovery paths retain their dependencies. Bash's existing
old-recovery lock recheck also needs the persisted reservation revalidation
already present in PowerShell.

## Work actually performed

- Backed up the three pre-existing dirty files (`spec-review-precheck.sh`,
  `spec-review-precheck.ps1`, `SKILL.md`) to `/tmp/a7-fresh-review-backup.jcm8uY/`.
- Added candidate helper `plugins/sdd-review-loop/scripts/fresh-review-recovery.py`.
  It is not called by either shipped precheck and has not been regression-tested.
- Added an initial dedicated fixture
  `specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py`.
  Its initial invocation before adding the helper exited 1 with
  `AssertionError: fresh-review recovery admission helper is missing`.
  This RED demonstrates missing entrypoint only, not semantic mismatch coverage.
- The fixture is incomplete: it still refers to a not-implemented
  `make_fixture_contract` fixture builder. Do not treat it as runnable acceptance
  evidence or put test-data construction into the production helper.
- Existing recovery fixture was not edited. No Git writes, real ledger writes,
  real reservation, reviewer launch or status changes were performed.

## Exact blocking operation and refusal

The first `apply_patch` update of
`plugins/sdd-review-loop/scripts/spec-review-precheck.sh` (new option parsing,
read-only helper integration and post-lock reservation validation) was denied
before execution. No portion of that patch was applied. PowerShell and skill
updates were not attempted after this refusal.

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo..
```

The action was stopped as required by `sdd-verification-apply`; no alternate
executor, direct filesystem write, copied-script replacement, or hook bypass
was used. This remains a real protection boundary despite the user's scope
approval. Do not retry an equivalent mutation by a different tool.

## Remaining work

1. Resolve the protected-write boundary through the legitimate owner workflow;
   do not relax the old recovery option or reinterpret invalid attempt-9 PASS.
2. Complete the fixture's own data builder and semantic negative tests before
   finishing Bash/PowerShell/skill integration. Pin existing output and host
   transcript as diagnostics, never as independent verdict evidence.
3. Verify strict source inventories, full historical legal chain, current-input
   mismatch, missing/broken reservations, output/transcript/session mismatch,
   wrong attempt, replay, symlinks, casing parity and lock-time ledger changes.
   Review the candidate helper for malformed JSON/types and transcript completeness.
4. Preserve old outputs and reservations; independently review the completed
   change, then rerun both fixtures with final source hashes. Current candidate
   code and initial RED are not implementation-complete or quality-gate evidence.

Future review launch diagnostics belong in a separate non-review host session.
A retry permitted by a hook within the same first turn is not a new turn; after
BLOCKED `end_turn`, reusing that reserved context via `--resume` is prohibited.
