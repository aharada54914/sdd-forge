# Specification Review Report: epic-195-a7-compatibility

- Attempt: 3
- Round: 1
- Input hashes: requirements `be0cd28571cc64784c89d687c5c38b8ccbe14bd7dfab0a5ba4c73c8a26311ac9`, acceptance tests `54f6ace65a05570cb8b81a418a5c597bd10ba47c10ebc9c20f97ae5de4c60992`
- Reviewer A: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-a-seq0765`, host session `SESS-spec-spec-reviewer-a-epic-195-a7-compatibility-0765`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-b-seq0766`, host session `SESS-spec-spec-reviewer-b-epic-195-a7-compatibility-0766`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json, integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Context for this attempt

Attempt 2 terminated with a round-3 PASS and `Spec-Review-Status: Passed`
(contract pinned acceptance tests at `7b62c339...`). Commit `7652d01b`
subsequently amended `acceptance-tests.md` (the AC-009/TEST-009 row's
"remain unmodified" wording moved with the design decision that relocated
the `done-transition:assert-terminal` emission inside `assert_terminal`),
a frozen-document amendment the human explicitly approved
(「194/195/196の凍結文書について人間は承認する」). That approval authorizes
re-running this stage's review against the amended documents at a new
attempt — hence this attempt 3, opened through the legitimate `--reset`
lane, which restored `Spec-Review-Status: Pending`. The reviewers judged
the amended documents on their merits with no knowledge of the approval.

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE,
DOMAIN-CONFORMANCE): 5/7 PASS, 1 FAIL (REQ-TESTABILITY), 1 SKIP
(DOMAIN-CONFORMANCE — no `domain/` directory).

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS,
DOMAIN-CONFORMANCE): 5/7 PASS, 1 FAIL (AMBIGUITY), 1 SKIP
(DOMAIN-CONFORMANCE — no `domain/` directory).

Finding counts (both reviewers combined): 1 Critical, 1 Major, 0 Minor.

Failed check IDs and severities only (no raw finding text reproduced across
a reviewer input boundary; see `reviewer-a.json` / `reviewer-b.json` for
full evidence):

- REQ-TESTABILITY (Critical, FAIL, reviewer A) — requirements.md AC-009
  (lines 357-367) still states `assert_terminal` is "themselves unmodified
  by this addition", while the amended acceptance-tests.md TEST-009 row
  (line 13) asserts `assert_terminal` carries exactly one sanctioned change
  (the `_loop_trace_emit done-transition:assert-terminal` call) locked at a
  re-baselined hash. The two primary Phase 1 artifacts assert mutually
  exclusive truth conditions for the same AC, so AC-009 cannot be validated
  as written.
- AMBIGUITY (Major, FAIL, reviewer B) — the amended TEST-009 row references
  "TEST-009.2", a "T-005 cycle-2 correction", and a "pre-T-006 body":
  objects that do not resolve inside this Phase 1 package (no tasks.md; the
  Test ID column lists only TEST-009), leaving a downstream task author
  unable to determine whether these are binding pre-commitments, stale
  leakage, or placeholders.

Both reviewers converged independently on the same AC-009/TEST-009 locus
from their two different check lenses.

`integrated-verdict.json` is derived from both validated reviewer outputs.
A Critical or Major finding produces `NEEDS_WORK` before round three.
Round 1 < round 3, so the merged verdict is `NEEDS_WORK`.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. `Spec-Review-Status` remains `Pending`. Remedy is
required against the 2 failed checks above before round 2 may run with
`--edit-summary`. Note the remedy locus: the amendment `7652d01b` moved
TEST-009's wording but requirements.md AC-009's "remain unmodified" clause
was not moved with it, and the TEST-009 row's task/cycle cross-references
(T-005/T-006/TEST-009.2) are unresolvable from the frozen Phase 1 package
itself.
