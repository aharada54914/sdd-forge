# Specification Review Report: epic-194-a6-lite-integration

- Attempt: 2
- Round: 1
- Input hashes: requirements `2e71e3bde791159a2ca5a9f9bbe4589c183789b994af4b6ebd551fd890d6080b`, acceptance tests `691db158e25045959809f32d67e1132974163cb72ef6729806427b3c193180f5`
- Reviewer A: run `RUN-epic-194-a6-spec-review-a2-r1-reviewer-a-seq765`, host session `SESS-epic-194-a6-spec-review-a2-r1-reviewer-a-765`, allowed input manifest: `plugins/sdd-review-loop/references/spec-review-calibration.md`, `reports/spec-review/epic-194-a6-lite-integration/attempt-2/round-1/precheck-result.json`, `specs/epic-194-a6-lite-integration/acceptance-tests.md`, `specs/epic-194-a6-lite-integration/investigation.md`, `specs/epic-194-a6-lite-integration/requirements.md`
- Reviewer B: run `RUN-epic-194-a6-spec-review-a2-r1-reviewer-b-seq766`, host session `SESS-epic-194-a6-spec-review-a2-r1-reviewer-b-766`, allowed input manifest: `plugins/sdd-review-loop/references/spec-review-calibration.md`, `reports/spec-review/epic-194-a6-lite-integration/attempt-2/round-1/integrated-summary.json`, `reports/spec-review/epic-194-a6-lite-integration/attempt-2/round-1/precheck-result.json`, `specs/epic-194-a6-lite-integration/acceptance-tests.md`, `specs/epic-194-a6-lite-integration/investigation.md`, `specs/epic-194-a6-lite-integration/requirements.md`
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Attempt Context

Attempt 2 opened with `--reset` after attempt 1's terminal round-2 PASS.
Commit `9997091c` (2026-08-21) amended `acceptance-tests.md` AC-010 from a
four-target to a five-target payload set, remediating two Major findings both
vendor slots of the T-001 blind cross-model panel raised independently. The
human approved the frozen-document amendment
(「194/195/196の凍結文書について人間は承認する」), authorizing this fresh
review of the amended documents at a new attempt. The approval authorizes the
running of the review, not its outcome; this round reviews the amended bytes
on their merits.

## Integrated Summary

Reviewer A: 5/7 checks PASS (GOAL-AC-TRACE, AC-OBSERVABLE, SCOPE-BOUNDARY,
CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE); 1 Critical FAIL
(REQ-TESTABILITY); 1 SKIP (DOMAIN-CONFORMANCE, no `domain/` directory).

Reviewer B: 2/7 checks PASS (EDGE-CASE-COVERAGE, ASSUMPTIONS-RESOLVABLE);
2 Critical FAIL (CONTRADICTION, APPROVAL-BOUNDARY); 2 Major FAIL (AMBIGUITY,
DOWNSTREAM-READINESS); 1 SKIP (DOMAIN-CONFORMANCE, no `domain/` directory).

Combined finding counts: Critical 3, Major 2, Minor 0.

`integrated-verdict.json` is derived from both validated reviewer outputs.
Round 1 is below round three, so the Critical/Major findings produce
`NEEDS_WORK` rather than `BLOCKED`.

## Finding Digest

Both reviewers, blind to each other, converged on the same structural
problem: the AC-010 amendment widened the payload contract to five targets
while every sibling statement of that contract remains frozen at four.

- Reviewer A REQ-TESTABILITY (Critical): amended AC-010 cites `tasks.md`'s
  Protected Files item 3 and the "T-001 cross-model verdicts 2026-08-21" as
  established facts, while `requirements.md` (Overview, :40-45) still frames
  this package as Phase 1 only with "no tasks.md/traceability.md exists yet" —
  an internal self-contradiction about the package's own boundary.
- Reviewer B CONTRADICTION (Critical): `acceptance-tests.md` AC-010 (:35,
  five targets including `.github/workflows/test.yml`) directly conflicts with
  the same document's AC-031 row (:54, "declared four-target payload list")
  and with `requirements.md` AC-010/AC-031 rows (:767, :788, four targets).
  The two ACs cannot be satisfied simultaneously.
- Reviewer B APPROVAL-BOUNDARY (Critical): the four-vs-five conflict breaks
  the testability of the human-copy governance boundary itself.
- Reviewer B AMBIGUITY (Major): "a second, optional argument" (REQ-002 body)
  vs. the named `--capability-reasons`/`-CapabilityReasons` flag (AC-027,
  REQ-006(i)) — two incompatible CLI signatures.
- Reviewer B DOWNSTREAM-READINESS (Major): downstream reviewers would have to
  invent the resolution of both gaps.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. `Spec-Review-Status` remains `Pending`; no header change
is made for a `NEEDS_WORK` round. Remedy requires a further frozen-document
amendment cycle with human eyes on it — the 2026-08-21 amendment resolved the
tasks.md-vs-AC-010 conflict by moving it into the spec document set
(`requirements.md` Overview/AC-031 and `acceptance-tests.md` TEST-031 still
carry the four-target/Phase-1 language), exactly the residual tension the
amendment commit itself disclosed. That is a new amendment decision, not a
review-loop step, and is out of scope for this round.
