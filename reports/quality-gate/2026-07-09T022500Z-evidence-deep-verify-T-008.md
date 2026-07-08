# Quality Gate — T-008 統合検証(決定論・tools/list スモーク)と dist 再ビルド

Task: T-008
Task ID: T-008
Feature: evidence-deep-verify
Risk: medium
Required Workflow: acceptance-first
Gate Date: 2026-07-09 (UTC 2026-07-09T022500Z)
Run ID: qg-orch-evidence-deep-verify-t008-20260709-o1
Reviewer: orchestrator gate-owner (medium/low tier — high-full / medium-low-light gate-depth policy)

VERDICT: PASS
Critical: 0
Major: 0
Minor: 0

## Deterministic Checks (contract-bound evidence)

| Check | Result | Evidence |
|-------|--------|----------|
| lint / typecheck | PASS | specs/evidence-deep-verify/verification/qg/T-008/typecheck.log |
| build | PASS | specs/evidence-deep-verify/verification/qg/T-008/build.log |
| placeholder-scan | PASS | specs/evidence-deep-verify/verification/qg/T-008/check-placeholders.log |
| task-state-check | PASS | specs/evidence-deep-verify/verification/qg/T-008/check-task-state.log |
| unit/acceptance/regression | PASS | specs/evidence-deep-verify/verification/qg/T-008/tests.log (205/205) |

Contract: specs/evidence-deep-verify/verification/T-008.contract.json — check-contract PASS this session.
Acceptance-first evidence: T-008-acceptance-first.txt honestly records the first run (AC-013 determinism 3/3 pass unmodified; AC-016 smoke 2/2 FAIL on stale dist — proving the smoke has teeth) → dist rebuilt via esbuild → T-008-green.txt 7/7.

## Orchestrator Light-Gate Review

- AC-013: three determinism variants (same-connection, independent-connection, error-envelope) assert byte-equality of repeated identical calls — verified present in tests/tools/deep-verify-determinism.test.ts and green in the orchestrator's independent full-suite rerun at gate HEAD (205/205, tests.log).
- AC-016: inspector smoke extended to assert 6 evidence tools sorted and a registration-order test proving evidence_deep_verify is literally the 6th; the initial failure on stale dist and post-rebuild pass demonstrate the check genuinely inspects dist.
- dist/index.js rebuilt by the worker (npm run build) and verified loadable; committed in the T-008 commit (dist-parity per ADR-0003). build.log at gate HEAD is clean.
- Scope discipline: no src/, contracts/, package.json changes (git-verified at T-008 commit time).

### Findings

None.

## Decision

All required contract checks pass with evidence, acceptance-first evidence honestly recorded, traceability intact (medium tier: requirement-traceability not mandated; check ran green anyway this session). Task T-008 → Done.
