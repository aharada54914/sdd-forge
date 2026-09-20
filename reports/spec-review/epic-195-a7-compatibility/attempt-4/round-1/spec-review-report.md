# Specification Review Report: epic-195-a7-compatibility

- Attempt: 4
- Round: 1
- Input hashes: requirements `b302af8dabdee7c59a797d3cf3b25d25937da41313f865a67738ae7c40902811`, acceptance tests `d982efe1eef57b5efdb42c1e40398ee3cd27ec4790da1c9914f0a78b17a09d04`
- Reviewer A: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-a-seq0771`, host session `SESS-spec-spec-reviewer-a-epic-195-a7-compatibility-0771`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-b-seq0772`, host session `SESS-spec-spec-reviewer-b-epic-195-a7-compatibility-0772`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json, integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Context for this attempt

Attempt 3 terminated BLOCKED (round 3) on the phase-framing defect: any
truthful in-package provenance of the epic's completed T-005/T-006
re-baseline contradicted the frozen "Phase 1 only" Overview/Non-goals
framing, and a narrative amendment note could not certify its own
approval. The human authorized limited deployment of the amendment
re-review lane (「限定デプロイ + WFI 起票でやれ」, 2026-08-23, following
「194/195/196の凍結文書について人間は承認する」). This attempt runs
against: the cherry-picked lane (`12abe245`, from `726240f9`:
`## Amendment Re-Review Context` recognition in the calibration and both
reviewer roles), the amendment-completion commit `a5681c67`, the
note-repoint commit `27843332`, and the committed evidence-bar-conforming
`## Amendment Re-Review Context` entry in investigation.md (`a3fd30b7`).

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE,
DOMAIN-CONFORMANCE): 6/7 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE).
Verdict: PASS.

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS,
DOMAIN-CONFORMANCE): 4/7 PASS, 2 FAIL (AMBIGUITY Major,
DOWNSTREAM-READINESS Major), 1 SKIP (DOMAIN-CONFORMANCE). Verdict:
NEEDS_WORK.

The amendment lane itself succeeded: reviewer B's CONTRADICTION check
PASSES, explicitly verifying the `## Amendment Re-Review Context` entry
against the calibration's full evidence bar (three full commit hashes;
per-commit document SHA-256 values matching the manifest's own pins; two
verbatim dated approval quotations; commit/SHA-256 citations for every
referenced later-phase artifact) and suppressing the phase-sequencing
finding basis per the lane's rule. The attempt-3 defect class is closed.

Finding counts (both reviewers combined): 0 Critical, 2 Major, 0 Minor.

Failed check IDs and severities only (no raw finding text reproduced
across a reviewer input boundary; see `reviewer-b.json` for full
evidence):

- AMBIGUITY (Major, FAIL, reviewer B) — fresh finding, unrelated to the
  amendment: requirements.md AC-010 scopes TEST-019's
  capability-applicability assertion to "a Context-present round drive",
  but unlike every sibling Context-present-scoped AC (AC-007,
  AC-019-021, AC-042, AC-043) neither AC-010 nor the acceptance-tests.md
  AC-010/TEST-010 row carries a named-SKIP/allowlist annotation gating
  it on Epic A1, while INV-014/AC-009 imply the assertion could instead
  run unconditionally against the `disabled-legacy` value — two
  implementers would diverge on SKIP-vs-ASSERT for a named test case.
- DOWNSTREAM-READINESS (Major, FAIL, reviewer B) — the same AC-010 gap
  forces a downstream reviewer to invent the missing disposition.

`integrated-verdict.json` is derived from both validated reviewer
outputs. A Major finding produces `NEEDS_WORK` before round three.

## Transition

`Spec-Review-Status` remains `Pending`. The AC-010/TEST-019 disposition
is a fresh specification decision (which fixture state gates TEST-019,
and whether it takes a named SKIP) — a substantive spec change outside
the standing amendment approval's scope, so it is reported for human
decision rather than remediated under this authorization. Round 2 with
`--edit-summary` can run once that decision is made.
