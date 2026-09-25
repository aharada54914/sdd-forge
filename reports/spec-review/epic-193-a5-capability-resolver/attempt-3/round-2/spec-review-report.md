# Specification Review Report: epic-193-a5-capability-resolver

- Attempt: 3
- Round: 2
- Context: round 1 returned `NEEDS_WORK`; its remediation landed in `f585cb0e` (mirror the human-approved ruling-A① jointly-caused-abort exception into both AC-056 restatement rows in the amended sentence's own words, anchor "evaluation pass" to REQ-001's steps (f)-(g) no-short-circuit sweep, and name the abort-exception fixture) and `582b588a` (re-extend investigation.md's `## Amendment Re-Review Context` with the round-1 completion chain). Round 2 opened with `spec-review-precheck.sh 3 2 --edit-summary=...` naming exactly those changes.
- Precheck fixed-point: the round-2 precheck's prior-round contract validation recomputes the expected reviewer manifest from **current** on-disk bytes, including `investigation.md`. Because `582b588a` extended `investigation.md` after round 1 pinned it (`3b2ed471…`), that validation failed with `prior round contract is malformed or does not require work`. The disclosed fixed-point procedure (`plugins/sdd-review-loop/references/reviewer-calibration.md`, Amendment Re-Review Context operational notes) was applied verbatim: validate the prior contract against the bytes it reviewed, then restore the amended bytes and let the new round's manifests pin them. Concretely, `investigation.md` was temporarily restored to its `f585cb0e` bytes (verified `3b2ed471fba4c6c19acbd308f2c437c89b251f77b76bbd6e77bb5478e49d694f`, exactly the value round 1's contract pins), the precheck ran and passed, and the amended bytes (`0693dc91fb1e3d29b9b2a72ad7f7f4d431156abd44ba69199cc640a420705883`) were restored immediately afterwards. `investigation.md` was byte-identical to its committed state before and after; only the stale pin was reconciled, and no gate finding was waived. Both round-2 reviewer manifests pin the amended bytes, which are what the reviewers actually read.
- Input hashes: requirements `5461fd7e50a4140cfcc71b07a08503906f698587d1dca377c9bef5c2b96ef618`, acceptance tests `531d47d526f8a51a473869d18e5a3b5e0f8a3f65d9dd6f9d33bdc4b810f6fc33`
- Reviewer A: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-a-a3r2-seq0774`, host session `SESS-spec-spec-reviewer-a-epic-193-a5-capability-resolver-a3r2-0774`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-b-a3r2-seq0775`, host session `SESS-spec-spec-reviewer-b-epic-193-a5-capability-resolver-a3r2-0775`, allowed input manifest: the same plus integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `PASS`
- Warning count: `0`

## Integrated Summary

Reviewer A: 6 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE, no `domain/` directory).

Reviewer B: 6 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE, no `domain/` directory).

Finding counts (both reviewers combined): 0 Critical, 0 Major, 0 Minor.

## Findings

No findings. Each round-1 FAIL was independently re-examined and closed on
evidence:

- Reviewer A's `GOAL-AC-TRACE` and reviewer B's `CONTRADICTION` /
  `DOWNSTREAM-READINESS` — the round-1 root cause was that ruling A①'s
  exception lived only in REQ-004's prose while both AC-056 restatements kept
  the unqualified pre-amendment rule. Reviewer A now traces every REQ to its
  AC rows with the AC-056 mapping intact; reviewer B checked the new AC-056
  exception directly against REQ-004's general at-most-once rule and found it
  consistent rather than conflicting (the exception admits multiple
  `dsl-warn-on-matched-capability` warn entries with no same-id block summary
  while a *different* id carries its own single block entry), and separately
  re-counted the sixteen-row Block table against AC-010 and the twelve-value
  validator enum against AC-021, both matching.
- Reviewer B's `AMBIGUITY` — "evaluation pass" is now anchored to REQ-001's
  own steps (f)-(g) sweep, together with "evaluation abort" and "jointly
  caused".
- Reviewer B's `EDGE-CASE-COVERAGE` — the newly-lawful path now has a named,
  independently-invocable fixture (`evaluate-predicate-failure-after-warn`,
  block suite) asserting the exact forwarded-warn-plus-different-id-block
  shape.

Reviewer B also recorded, under `AMBIGUITY`, that the human approval quotation
「A①B①C①でやれ」 names a third ruling C① that this package's own text does not
describe, and resolved it against investigation.md's own closing sentence as
belonging to the sibling 194/195/196 frozen-document family rather than being
an undocumented gap here. It is reported because the reviewer reported it; it
carries a `PASS` result and no severity weight.

Both reviewers independently confirmed the `## Amendment Re-Review Context`
entry meets the calibration's full evidence bar (full commit hashes,
per-document SHA-256 pins, verbatim dated approval quotation), so the scoped
phase-sequencing suppression applied and every other check was judged normally.

## Disposition

Clean `PASS` at round 2 with `warningCount: 0` and no finding of any severity.
Per the loop's state-transition rule for a Pending package whose round-1
`NEEDS_WORK` was remedied under `--edit-summary`, a validated merged PASS
updates the header, so `Spec-Review-Status` moves from `Pending` to `Passed`.
No finding was waived.
