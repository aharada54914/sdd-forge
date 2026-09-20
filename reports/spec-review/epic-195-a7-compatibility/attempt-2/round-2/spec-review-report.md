# Specification Review Report: epic-195-a7-compatibility

- Attempt: 2
- Round: 2
- Input hashes: requirements `5a2c278d8d9583a2b8d7f7b8096e38b02fc66d56f48849a80bcc7a18a8deef42`, acceptance tests `7b62c3391ddc58131cf1d1a16644e116b3030562e47a15fcd66ee4ef3c8aa24d`
- Precheck: manual fallback per AGENTS.md's "Review gate precheck fallback"
  (issue #61) — see `manual-precheck-note.md` in this directory for the
  human-authorized deviation record (option B, 2026-07-22).
- Reviewer A: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-a-seq0331`, host session `SESS-spec-spec-reviewer-a-epic-195-a7-compatibility-0331`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-b-seq0332`, host session `SESS-spec-spec-reviewer-b-epic-195-a7-compatibility-0332`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json, integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE,
DOMAIN-CONFORMANCE — 7 checks per its own role file's unconditional order,
see "Reviewer A check-count note" below): 6/7 PASS, 0/7 FAIL, 1/7 SKIP
(DOMAIN-CONFORMANCE, `domain/` absent). Confirmed all three round-1
remedies (AC-007 F4 clarification, AC-043, AC-034 enumeration update)
close round-1's findings.

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS,
DOMAIN-CONFORMANCE — 7 checks, same role-file basis): 5/7 PASS
(AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE, ASSUMPTIONS-RESOLVABLE,
APPROVAL-BOUNDARY), 1/7 FAIL (DOWNSTREAM-READINESS), 1/7 SKIP
(DOMAIN-CONFORMANCE, `domain/` absent). Independently confirmed all three
of round 1's own findings (AMBIGUITY, EDGE-CASE-COVERAGE,
DOWNSTREAM-READINESS) resolved by the remedy — this round's own
DOWNSTREAM-READINESS FAIL is a **new, distinct** finding, not a
recurrence.

Finding counts (both reviewers combined): 0 Critical, 1 Major, 0 Minor.

Failed check IDs and severities only (no raw finding text; see
reviewer-b.json for full evidence, which is not reproduced across a
reviewer input boundary):

- DOWNSTREAM-READINESS (Major, FAIL) — AC-034's own SKIP-candidate
  enumeration (`AC-004, AC-007, AC-019–AC-021, AC-042, AC-043`, plus a
  "Context-present REQ-003 assertion" catch-all) omits AC-036 and AC-037,
  both of which acceptance-tests.md names as "named SKIP until Epic A5
  merges" assertions and which requirements.md's own Non-goals section
  places on the identical Epic-A5 gate as AC-004/AC-021 — the same class
  of enumeration-completeness gap round 1's AC-042/AC-043 remedy closed
  for a different pair of ACs.

`integrated-verdict.json` is derived from both validated reviewer outputs.
A Critical or Major finding produces `NEEDS_WORK` before round three and
`BLOCKED` in round three. Round 2 < round 3, so the merged verdict is
`NEEDS_WORK`. Round 3 is this attempt's own final round: a clean pass
reaches `Spec-Review-Status: Passed`; any surviving Critical/Major finding
in round 3 produces `BLOCKED`.

## Reviewer A check-count note (verbatim record, per orchestrator instruction)

This round's launch prompt for spec-reviewer-a (written by this
orchestrator, following an older, already-documented workaround for a
known role-file/script contradiction — see
`reports/notes/repo-defect-spec-reviewer-domain-conformance-check-count-mismatch.md`)
instructed it to omit the `DOMAIN-CONFORMANCE` check and return the
6-check shape `spec-review-precheck.sh`'s own hardcoded validator expects.
Spec-reviewer-a explicitly declined: per the coordinator's relay of its
final output, it held that its own role file (`spec-reviewer-a.md`)
"mandates a fixed 7-check order [and] SKIP is a legitimate result," that
omitting the check "is a schema change, not a re-serialization," and cited
the fact that this was the second such request (the launch prompt's own
Authority note, plus this specific instruction) as part of its reasoning
for declining further compliance. It returned the full 7-check version
(ending `DOMAIN-CONFORMANCE: SKIP`, citing `domain/`'s absence) as its
authoritative output instead.

This orchestrator did not attempt further persuasion. The refusal is
correct: an orchestrator instruction that contradicts a reviewer's own
authoritative role file (which every launch prompt this session explicitly
told reviewers to treat as the sole authority over any conflicting
embedded persona or prose instruction) should not be followed merely
because it is repeated, and doing so would itself be the kind of
instruction-source violation this repository's own security discipline
warns against. The 7-check output was independently byte-verified
(sha256 `fc12136004aba0f9bea44cdc2e3857f3207a583afedac3d5de4701f17e40090b`)
and persisted unmodified as this round's authoritative reviewer-a
evidence. Reviewer B's own launch prompt was corrected before launch to
quote its role file's checks section verbatim instead, avoiding the same
mistake.

Mechanical confirmation (performed before deciding to accept the 7-check
shape, not assumed): `check-workflow-state.sh` — the one validator
confirmed to actually run against this evidence in the future, via any
`impl-review-precheck.sh`/`task-review-precheck.sh` round — has no
hardcoded spec-stage ID list, only a self-consistency requirement between
each reviewer's own `checks[].id` set and `integrated-summary.json`'s own
recorded ID set, which this round's `integrated-summary.json` was built to
satisfy for reviewer A. `spec-review-precheck.sh`'s own hardcoded 6-ID
`validate_reviewer_output` is reachable only via `validate_contract`,
itself invoked only when a later round or attempt needs to validate this
round as a prior/terminal contract — full analysis and two candidate fix
directions in the defect note above. This is not the same defect as the
attempt-2/round-1 stale-hash issue, but is the same *class* of role-file/
script drift, now confirmed to matter for real (see "Round 3 precheck"
below).

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. `Spec-Review-Status` remains `Pending`. Remedy is
required against the 1 failed check above (add AC-036, AC-037 to AC-034's
own enumeration) before round 3 — this attempt's final round — may run
with `--edit-summary`.
