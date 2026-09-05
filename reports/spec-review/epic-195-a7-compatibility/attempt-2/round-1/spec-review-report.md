# Specification Review Report: epic-195-a7-compatibility

- Attempt: 2
- Round: 1
- Input hashes: requirements `b93bb7985d757c6ef1674a89e16d7e499ea8ac46222d77fe1d94053d94ab5938`, acceptance tests `2ce298e5c6f9ef242683b8946cb02e3e036349d831b676658f38944b1114fe3c`
- Reviewer A: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-a-seq0329`, host session `SESS-spec-spec-reviewer-a-epic-195-a7-compatibility-0329`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-195-a7-compatibility-spec-spec-reviewer-b-seq0330`, host session `SESS-spec-spec-reviewer-b-epic-195-a7-compatibility-0330`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json, integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE, SCOPE-BOUNDARY,
CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE): 6/6 PASS, 0 FAIL, 0 SKIP.
Confirmed AC-042/TEST-042 close the F3/REQ-002 structural gap and that both
requirements.md and acceptance-tests.md mirror it.

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS): 3/6 PASS
(CONTRADICTION, ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY), 3/6 FAIL
(AMBIGUITY, EDGE-CASE-COVERAGE, DOWNSTREAM-READINESS).

Finding counts (both reviewers combined): 0 Critical, 3 Major, 0 Minor.

Failed check IDs and severities only (no raw finding text; see reviewer-b.json
for full evidence, which is not reproduced across a reviewer input boundary):

- AMBIGUITY (Major, FAIL) — AC-007 (requirements.md:340-347) does not name
  which track (`full`/F4 or `lite`/F6) its "Context-present, required"
  fixture is, and reads two ways alongside AC-014's F1-F4-only
  fixture-builder scope.
- EDGE-CASE-COVERAGE (Major, FAIL) — the F5/F6 (`lite`-track,
  Context-present) matrix rows have no AC/TEST at all: AC-014 is scoped to
  F1-F4 only, and AC-034's allowlist-manifest catch-all only enumerates
  REQ-003 assertions, not a REQ-002 structural assertion for F5/F6.
- DOWNSTREAM-READINESS (Major, FAIL) — AC-028/AC-029's own
  exhaustive-cell-citation requirement has no citable AC/TEST for the
  F5xREQ-002/F6xREQ-002 cells, forcing a future design reviewer to invent
  product scope design.md itself does not fix.

`integrated-verdict.json` is derived from both validated reviewer outputs. A
Critical or Major finding produces `NEEDS_WORK` before round three and
`BLOCKED` in round three. Round 1 < round 3, so the merged verdict is
`NEEDS_WORK`.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. `Spec-Review-Status` remains `Pending`. Remedy is
required against the 3 failed checks above before round 2 may run with
`--edit-summary`.

## Orchestrator note: precheck-result.json stale-hash defect surfaced this round

Reviewer B also disclosed (non-finding, process observation, out of its own
six-check scope) that this round's own `precheck-result.json` records
`requirements_sha256: 0314f09c0e563ff276b6bb2db376e4491638ac37094c5238ab8373fbed3cea99`,
which does not match the live `requirements.md` this round's own contract
above correctly uses (`b93bb7985d75...`, the value both reviewers actually
read and both echoed back in their own `allowed_input_manifest`). This
confirms the landmine flagged pre-emptively in commit `59bdd0c`:
`spec-review-precheck.sh` computes `requirements_sha256` **before** its own
`--reset` sed rewrites `Spec-Review-Status: Passed` to `Pending`, so any
`--reset` invocation against a spec whose content was edited in the same
turn produces a `precheck-result.json` permanently out of step with the
post-reset live file. This contract deliberately uses the live/honest hash
(matching what both reviewers actually reviewed and what is separately
required by `validate_reviewer_output`'s own self-consistency check) rather
than propagating the stale precheck value — this is the only choice that
keeps the reviewer-output self-consistency check honest, at the cost of this
round's own contract *not* equaling this round's own precheck-result.json
value. See `reports/notes/repo-defect-spec-review-precheck-reset-hash-staleness.md`
for the full analysis and the recommended script fix, filed as a WFI
candidate rather than edited into `plugins/**` (out of this orchestrator's
remit).
