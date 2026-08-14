# Specification Review Report: epic-191-a3-path-ownership

- Attempt: 1
- Round: 2
- Edit summary: Removed undefined Fail-6 "binding facet/binding revision"
  clause from REQ-004/AC-033; adapter_paths glob match against an
  EXCLUSIVE-owned changed path is now the sole trigger condition, aligned
  with design.md's Fail-6 scope decision; TEST-033 updated to match.
- Input hashes: requirements `4ebfe16c671c17bff55898001ae06c4849453af06b6364026769909212dbcd04`, acceptance tests `cb577b7f86364b505bb258c747058f39f458b60c862f3fd3d122f69652cd10d5`
- Reviewer A: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-a-a1r2-seq0322`, host session `SESS-spec-spec-reviewer-a-epic-191-a3-path-ownership-a1r2-0322`
- Reviewer B: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-b-a1r2-seq0323`, host session `SESS-spec-spec-reviewer-b-epic-191-a3-path-ownership-a1r2-0323`
- Verdict: `NEEDS_WORK`
- Warning count: 0

## Findings

1. Critical — `REQ-TESTABILITY` (reviewer A) / `CONTRADICTION` (reviewer B,
   independently corroborating): the round-1 remedy corrected REQ-004's
   Fail-6 trigger in requirements.md/acceptance-tests.md to a single
   condition (adapter_paths glob match), but did not propagate to
   investigation.md's OQ-001 "Resolved" section, which still asserts the
   old, undefined two-part condition ("without the corresponding binding
   facet/revision also present in the diff"). Because requirements.md's
   Dependencies section cites investigation.md OQ-001 as the resolution
   authority, this is a direct in-package contradiction between two
   reviewed Phase 1 artifacts over a normative Fail-condition trigger rule.
   (investigation.md was deliberately kept byte-identical to its round-1
   state between rounds 1 and 2 because `spec-review-precheck.sh` does not
   version investigation.md's hash per round — only requirements.md and
   acceptance-tests.md hashes are pinned inside each round's contract, so
   editing investigation.md between rounds breaks revalidation of the
   prior round's contract. The correction belongs in round 3, applied
   immediately before round 3's precheck runs.)

All other checks from both reviewers (GOAL-AC-TRACE, AC-OBSERVABLE,
SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE, AMBIGUITY,
EDGE-CASE-COVERAGE, ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY,
DOWNSTREAM-READINESS) passed.

## Transition

Round 3 requires human-directed specification edits and a non-empty
`--edit-summary`. Round 3 is the terminal round of attempt 1 per the
state-transition table: a clean or Minor-only round-3 result is
recoverable (PASS, possibly with `warningCount > 0`), but any remaining
Major/Critical finding at round 3 is `BLOCKED` and requires
`--reset` to start attempt 2.
