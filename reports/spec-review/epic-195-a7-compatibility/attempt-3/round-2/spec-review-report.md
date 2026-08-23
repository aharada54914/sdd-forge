# Specification Review Report: epic-195-a7-compatibility

- Attempt: 3
- Round: 2
- Input hashes: requirements `a95d3f68a4394bf50d9f6991483ab84af6d812ca72f633f704aed71b0241d6c9`, acceptance tests `d982efe1eef57b5efdb42c1e40398ee3cd27ec4790da1c9914f0a78b17a09d04`
- Reviewer A: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-a-seq0767`, host session `SESS-spec-spec-reviewer-a-epic-195-a7-compatibility-0767`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-b-seq0768`, host session `SESS-spec-spec-reviewer-b-epic-195-a7-compatibility-0768`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json, integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Edit under review

Round 2 reviewed the completion of the human-approved `7652d01b` amendment
(edit summary in `precheck-result.json`): requirements.md AC-009's
"themselves unmodified" clause was aligned with acceptance-tests.md
TEST-009's amended wording, and TEST-009's dangling cross-references
(TEST-009.2 / "T-005 cycle-2 correction" / "pre-T-006 body") were replaced
by two explicit locked hash values with in-repo locations plus a
provenance note labelled a historical record.

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE,
DOMAIN-CONFORMANCE): 6/7 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE — no
`domain/` directory). Reviewer A's verdict: PASS — it found the round-1
REQ-TESTABILITY contradiction closed and the dangling references gone.

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS,
DOMAIN-CONFORMANCE): 4/7 PASS, 2 FAIL (CONTRADICTION Critical,
DOWNSTREAM-READINESS Major), 1 SKIP (DOMAIN-CONFORMANCE). Reviewer B's
verdict: NEEDS_WORK.

Finding counts (both reviewers combined): 1 Critical, 1 Major, 0 Minor.

Failed check IDs and severities only (no raw finding text reproduced
across a reviewer input boundary; see `reviewer-b.json` for full
evidence):

- CONTRADICTION (Critical, FAIL, reviewer B) — requirements.md's own
  Overview and Non-goals still state that tasks.md and all Phase 2/3
  work "follow in a later phase" and were not produced, while the
  amended AC-009/TEST-009 provenance note truthfully narrates, in the
  past tense, a completed later-phase implementation cycle recorded in
  `specs/epic-195-a7-compatibility/tasks.md` T-005/T-006 that
  re-baselined the locked hashes. The package contradicts itself about
  what phase it is in — a workflow-boundary contradiction.
- DOWNSTREAM-READINESS (Major, FAIL, reviewer B) — the same phase-frame
  conflict leaves a downstream reader unable to determine whether the
  two locked hash values are a Phase-1 pre-commitment or values fixed by
  out-of-package work the package's own Non-goals disclaims.

`integrated-verdict.json` is derived from both validated reviewer
outputs. A Critical or Major finding produces `NEEDS_WORK` before round
three. Round 2 < round 3, so the merged verdict is `NEEDS_WORK`.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. `Spec-Review-Status` remains `Pending`. Per the
governing instruction for this attempt, no further wording-only round is
attempted: two consecutive rounds of independent reviewers rejecting the
amendment mean the amendment itself — specifically the frozen
Overview/Non-goals phase framing, which makes any truthful post-hoc
provenance note self-contradictory — requires human re-thought before
round 3 may run.
