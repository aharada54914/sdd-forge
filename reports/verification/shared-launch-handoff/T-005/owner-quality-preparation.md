# T-005 owner quality preparation — blocked before launch

Recorded 2026-10-09 JST. Task: shared-review-launch-repair / T-005. Owner: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`. HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`. Risk: high, existing approved TDD task. Existing dirty candidate, earlier task evidence, ledger and frozen specifications were preserved. This preparation adds only this non-frozen note; no production, task-state, reservation or Git mutation. It is not a formal quality verdict.

## Current implementation and independent audit

The 75-file output was applied and read back previously. The implementation report remains SHA-256 `33e2cc787f23b0e06af18a2e83bee5c51c309182623e9d97e33a25b6b05d7216`; the implementation manifest remains `347c102120352a273c7f83cb1785824ed1cd53837bf451c958a76b9cbcf09218`. Current owner validation and the stdin EOF diagnosis are recorded in `attempt-2/owner-integration-validation.md` and `attempt-2/owner-validation-stdin-eof.jsonl` beside this note. Historical timeout outcomes were retained, not relabeled as successful.

Independent read-only agent `/root/t005_path_audit` completed with Critical 0 / Major 0, not a formal quality verdict. Its exact reviewed test hash was `612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e`. It confirmed these two earlier Major gaps resolved:

- `tests/unified-launch-order.tests.py:97,114` connects the fixture canonical ledger to the real Bash/PowerShell validators.
- Lines 150,266 inject receipt mismatch after actual append and assert retained record/receipt hash, one reservation, no prompt/child, real same-identity retry rejection and unchanged ledger bytes after retry.
- Lines 308 and `specs/shared-review-launch-repair/verification/T-005/attempt-2/fixture-receipts.json` cover Bash/PowerShell × spec/impl/task, all six with preview 1→1 and unchanged bytes, reserve 1→2, rejected retry exit 1 and 2→2 unchanged bytes.
- Lines 284,315 cover pre-reservation canonical ledger invariance, reserve 0 and child 0.

Audit limitations: no independent execution, no full 606-input or all-baseline-suite rehash. Common preflight, stage precheck, native CLI and postflight remain mock. Quality stage is outside the six canonical integration cases. Owner EOF reruns are separate later caller evidence, not part of that audit. Native host/Windows/CI/formal gate proof is not supplied by these fixtures.

## Blocking implementation-manifest binding

The quality-gate skill requires preserving the implementation report and binding its cited implementation manifest exactly. Current deterministic consumers impose both:

1. `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:440` and `.ps1:495` only admit implementation manifest paths matching `^handoffs/[A-Za-z0-9._-]+/manifest(-[A-Za-z0-9][A-Za-z0-9_-]*)?[.]json$`. The real T-005 manifest is `reports/verification/shared-launch-handoff/T-005/attempt-2/manifest.json` and does not match.
2. The shell consumer at lines 277–282 and PowerShell consumer at lines 145–150 require the citation delimiter to be a comma followed by `SHA-256`. The frozen report uses a semicolon. It does not match the strict citation even with the original path/hash.

A read-only Node check reproduced both predicate failures (`schema_path_match: false`, `citation_count: 1`, `citation_match: false`) while report run/session matched the real implementation identity. This was predicate diagnosis, not an executed formal validator verdict. A copied manifest under handoffs would not fix the report's required exact original path citation. The Post-Fix Artifacts channel authorizes extra source/evidence inputs, not replacement of this identity binding. No alias, rewritten report, new identity or consumer weakening was attempted.

## State and next boundary

Task remains In Progress; formal evaluator invocation and reservation NOT RUN; no Default-FAIL contract was opened because the Implementation Complete precondition and launch closure are unresolved. Done/CI/native/merge are not claimed. A sanctioned decision is needed for this already-frozen report/manifest provenance mismatch; do not bypass the consumer or silently rewrite historical evidence.

Read-only preparation checks: `rtk proxy bash scripts/check-sdd-structure.sh <owner>` exited 0 (advisory CLAUDE host github, structure OK); `rtk proxy git diff --check` exited 0. Current task hash `1a6b36bdc946724ee24bd6e77b7af98f9f6c167d8d736397f41b9f5d6dbfb898`; ledger hash `e58f176ffc21da36f1186369c6411b3eabeae29385663bd327473e14d50393f0`. These are observed before any evaluator launch, not new reservations or verdicts.
