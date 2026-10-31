# Specification Review Report: epic-195-a7-compatibility

- Attempt: 3
- Round: 3 (terminal)
- Input hashes: requirements `fc5f9ffe66edb9c94c865193e8bca9565eb24e91e7fcf55dba354e883106a505`, acceptance tests `d982efe1eef57b5efdb42c1e40398ee3cd27ec4790da1c9914f0a78b17a09d04`
- Reviewer A: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-a-seq0769`, host session `SESS-spec-spec-reviewer-a-epic-195-a7-compatibility-0769`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-b-seq0770`, host session `SESS-spec-spec-reviewer-b-epic-195-a7-compatibility-0770`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json, integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `BLOCKED`
- Warning count: `0`

## Edit under review

Round 3 reviewed the phase-framing remediation (edit summary in
`precheck-result.json`): a dated (2026-08-23) amendment note added to
requirements.md's Overview stating the "Phase 1 only" framing described
authoring time, that the implementation phase has since run, and that the
T-005/T-006 re-baseline AC-009 references is recorded history, with a
matching cross-reference in Non-goals. The round-1 AC-009/TEST-009
remediation was untouched.

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE,
DOMAIN-CONFORMANCE): 5/7 PASS, 1 FAIL (CONSTRAINTS-EXPLICIT, Critical),
1 SKIP (DOMAIN-CONFORMANCE). Verdict: NEEDS_WORK.

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS,
DOMAIN-CONFORMANCE): 4/7 PASS, 2 FAIL (CONTRADICTION Critical,
DOWNSTREAM-READINESS Major), 1 SKIP (DOMAIN-CONFORMANCE). Verdict:
NEEDS_WORK.

Finding counts (both reviewers combined): 2 Critical, 1 Major, 0 Minor.

Failed check IDs and severities only (no raw finding text reproduced
across a reviewer input boundary; see `reviewer-a.json` /
`reviewer-b.json` for full evidence):

- CONSTRAINTS-EXPLICIT (Critical, FAIL, reviewer A) — the amendment
  note's factual claims (implementation ran; tasks.md exists;
  human-approved) carry a bare path citation with no file:line, sha256,
  commit, or ledger reference, below the citation-rigor bar (AC-017)
  the document imposes on every other repository-state claim, and the
  retained original sentence still contradicts the note for a reader
  deciding what a task author must do.
- CONTRADICTION (Critical, FAIL, reviewer B) — explicitly the same
  defect round-2 reviewer B raised: the note elaborates rather than
  removes the phase-state contradiction, and adds an unverifiable
  claim of prior human approval with no citable approval record.
- DOWNSTREAM-READINESS (Major, FAIL, reviewer B) — downstream reviewers
  still cannot resolve which world-state is real from the package's own
  artifacts.

Round 3 with Critical/Major findings produces `BLOCKED` per the state
transition rules. Attempt 3 is terminal.

## Transition

`Spec-Review-Status` remains `Pending`. Attempt 3 is BLOCKED; a future
attempt requires `--reset` after human re-thought of the amendment
approach. Both round-2 and round-3 independent reviewers rejected the
phase-framing treatment (round-2: truth conflicts with frame; round-3:
the frame-note is unverifiable self-assertion), so per the governing
instruction no further wording attempt is made. The reviewers' combined
diagnosis: an in-document narrative note cannot certify its own
approval or the repository's implementation state; the resolution needs
either an approval record citable from within the package (hash/commit/
ledger-referenced) or a workflow answer outside the document text.
