# Quality Gate — T-005 host スクリプト判定一致ゴールデン(parity)

Task: T-005
Task ID: T-005
Feature: evidence-deep-verify
Risk: medium
Required Workflow: acceptance-first
Gate Date: 2026-07-09 (UTC 2026-07-09T023000Z)
Run ID: qg-orch-evidence-deep-verify-t005-20260709-o1
Reviewer: orchestrator gate-owner (medium/low tier — high-full / medium-low-light gate-depth policy)

VERDICT: PASS
Critical: 0
Major: 0
Minor: 0

## Deterministic Checks (contract-bound evidence)

| Check | Result | Evidence |
|-------|--------|----------|
| lint / typecheck | PASS | specs/evidence-deep-verify/verification/qg/T-005/typecheck.log |
| build | PASS | specs/evidence-deep-verify/verification/qg/T-005/build.log |
| placeholder-scan | PASS | specs/evidence-deep-verify/verification/qg/T-005/check-placeholders.log |
| task-state-check | PASS | specs/evidence-deep-verify/verification/qg/T-005/check-task-state.log |
| unit/acceptance/regression | PASS | specs/evidence-deep-verify/verification/qg/T-005/tests.log (205/205) |

Contract: specs/evidence-deep-verify/verification/T-005.contract.json — check-contract PASS this session.
Acceptance-first evidence: T-005-acceptance-first.txt honestly records first-run green 4/4 (no defect found in the shipped core); T-005-green.txt confirms.

## Orchestrator Light-Gate Review

- AC-012 both-direction parity: 4 fixture classes (consistent/pass, tampered on-disk artifact/fail, spec drift/fail, tampered recorded hash/fail), each a throwaway git-backed synthetic SDD root, comparing check-evidence-bundle.sh exit code against evidenceDeepVerify() verdict — verified present in tests/golden/deep-verify-parity.test.ts + helpers and green in the orchestrator's independent full-suite rerun at gate HEAD (205/205).
- The worker manually confirmed each fail-case fails for exactly the intended tampered dimension (recorded in the implementation report).
- Design finding documented in the test and report (accepted as spec clarification, no action): the host checker never recomputes spec_revision from content (shape+presence only, high/critical only), so the drift fixture uses risk:high with recorded spec_revision:"" for genuine two-sided agreement.
- Scope discipline: tests/golden/ only; no src/, contracts/, tasks.md changes (git-verified at T-005 commit time). evidence_deep_verify itself spawns no git/shell (T-003 static check still green); the test harness legitimately runs the host script for comparison.

### Findings

None.

## Decision

All required contract checks pass with evidence, acceptance-first evidence honestly recorded, host-parity proven in both directions. Task T-005 → Done.
