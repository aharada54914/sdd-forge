# Specification Review Report: epic-194-a6-lite-integration

- Attempt: 2
- Round: 2
- Input hashes: requirements `580cce4d0f10ccf11667f90fd9d0286ab9b735fc257379bbc051d5ea6e7a4be5`, acceptance tests `d782157cd90594388008cd221c1fcdc4c619dab2e84ec3895ae5e8fb37d7367b`
- Reviewer A: run `RUN-epic-194-a6-spec-review-a2-r2-reviewer-a-seq767`, host session `SESS-epic-194-a6-spec-review-a2-r2-reviewer-a-767`, allowed input manifest: `plugins/sdd-review-loop/references/spec-review-calibration.md`, `reports/spec-review/epic-194-a6-lite-integration/attempt-2/round-2/precheck-result.json`, `specs/epic-194-a6-lite-integration/acceptance-tests.md`, `specs/epic-194-a6-lite-integration/investigation.md`, `specs/epic-194-a6-lite-integration/requirements.md`
- Reviewer B: run `RUN-epic-194-a6-spec-review-a2-r2-reviewer-b-seq768`, host session `SESS-epic-194-a6-spec-review-a2-r2-reviewer-b-768`, allowed input manifest: `plugins/sdd-review-loop/references/spec-review-calibration.md`, `reports/spec-review/epic-194-a6-lite-integration/attempt-2/round-2/integrated-summary.json`, `reports/spec-review/epic-194-a6-lite-integration/attempt-2/round-2/precheck-result.json`, `specs/epic-194-a6-lite-integration/acceptance-tests.md`, `specs/epic-194-a6-lite-integration/investigation.md`, `specs/epic-194-a6-lite-integration/requirements.md`
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Round Context

Round 2 remediated all five round-1 findings (see the precheck's edit
summary): the four-vs-five-target sibling rows were widened to the
five-target declared set mirroring the amended AC-010 wording; the
Overview gained a dated note making the Phase 1 framing historical; and the
positional-argument CLI wording was aligned to the
`--capability-reasons`/`-CapabilityReasons` flag the staged implementation
actually uses (verified against the staged runner scripts before editing).

## Integrated Summary

Reviewer A: 5/7 checks PASS (REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, RISK-VALIDATION-SURFACE); 1 Critical FAIL
(CONSTRAINTS-EXPLICIT); 1 SKIP (DOMAIN-CONFORMANCE, no `domain/` directory).

Reviewer B: 3/7 checks PASS (AMBIGUITY, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE); 2 Critical FAIL (CONTRADICTION, APPROVAL-BOUNDARY);
1 Major FAIL (DOWNSTREAM-READINESS); 1 SKIP (DOMAIN-CONFORMANCE).

Combined finding counts: Critical 3, Major 1, Minor 0.

Round 2 is below round three, so the Critical/Major findings produce
`NEEDS_WORK` rather than `BLOCKED`.

## Finding Digest

The round-1 findings are closed: both reviewers confirm the five-target set
is now stated consistently (A: SCOPE/AC checks PASS; B: AMBIGUITY PASS with
the flag wording verified at every call site, CONTRADICTION no longer cites
the payload set).

The remaining failure is a single structural issue both reviewers found
independently, blind to each other: the dated Overview note (requirements.md
:47-55) truthfully discloses that tasks.md, traceability.md, and T-001
implementation-phase cross-model verdicts already exist — and the reviewers
judge that disclosure to be an in-band admission that later-phase work
preceded the spec gate now open, contradicting the package's own
`Spec-Review-Status: Pending` header, AC-023/AC-024, and
acceptance-tests.md's "no suite file exists yet / every row Planned"
framing. Reviewer A classifies it under CONSTRAINTS-EXPLICIT (Critical);
reviewer B under CONTRADICTION + APPROVAL-BOUNDARY (Critical) and
DOWNSTREAM-READINESS (Major).

This is a structural paradox, not a wording defect: round 1 failed because
the document cited implementation artifacts a Phase-1 package denies
existing; round 2's truthful disclosure of exactly that state is itself
judged a workflow-boundary violation under the same Phase-1 calibration.
A post-implementation amendment re-review cannot state the truth about its
own timeline without tripping the calibration's phase-sequencing class.
Two independent rounds rejecting means the amendment needs human
re-thought — resolution requires either a calibration/gate accommodation
for human-approved post-implementation amendment re-reviews, or a different
document strategy — not a third wording attempt.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. `Spec-Review-Status` remains `Pending`; no header
change is made for a `NEEDS_WORK` round.
