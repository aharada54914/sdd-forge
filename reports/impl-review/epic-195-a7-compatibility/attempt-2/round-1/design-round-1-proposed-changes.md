# Implementation Policy Review Report: epic-195-a7-compatibility — Round 1 / Attempt 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-195-a7-compatibility |
| Round | 1 of 3 |
| Attempt | 2 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-23T10:35:34Z |

Round 1 < 3, one Major finding, zero Critical → `NEEDS_WORK` per SKILL.md
STEP 5/6. `Impl-Review-Status` remains `Pending`. Re-invoke round 2 with
`--edit-summary` after remedy (SKILL.md's normal mid-attempt flow, not a
`--reset`).

## Reviewer-A Findings (Structural Soundness)

11/11 PASS or SKIP, 0 FAIL. Fresh evaluation of the post-remedy design.md
(attempt-1 remedy applied), including on-disk verification of all
referenced ADRs. No findings.

## Reviewer-B Findings (Implementability/Risk)

10/11 PASS/SKIP, 1 FAIL:

- **NO-REQ-CONTRADICTION (Critical, PASS)** — independently confirmed
  resolved: the same check that found attempt 1's own terminal finding
  (missing AC-042/AC-043 citations) now passes against the remedied
  design.md.
- **DECISION-JUSTIFIED (Major, FAIL)** — the fixture-matrix builder
  contract AC-014 (`requirements.md`) requires ("a single, named
  fixture-builder contract (design.md fixes its signature)") is
  referenced from three points in design.md (Components table, Data
  Plan's `PROJECT_CONTEXT_INVALID` variant plan, Test Strategy item 1)
  but never actually defined in either Design Decisions or API / Contract
  Plan — no script/function name, no complete parameter signature
  (contrasted with the golden-baseline scripts, which do have concrete
  names/signatures). Only 2 of AC-014's required parameters
  (`valid_or_invalid`, `track_flag`) are mentioned in prose; the
  remaining required parameters (`project-context.yaml` presence,
  `AGENTS.md` marker presence, `capability_enforcement` value) are not.

## Proposed Changes

Add the fixture-matrix builder's concrete name and complete parameter
signature to design.md's own Design Decisions or API / Contract Plan
section (a single, authoritative definition — not duplicated in both),
naming all parameters AC-014 requires: `project-context.yaml`
presence/absence, `AGENTS.md` marker presence/absence,
`capability_enforcement` value, and the already-mentioned
`valid_or_invalid`/`track_flag`. Update the three existing cross-reference
points (Components table, Data Plan, Test Strategy item 1) so each
actually points at the real definition rather than deferring to each
other circularly. No new design judgment — formalize what AC-014 already
requires and what the golden-baseline scripts' own naming precedent
already establishes as the expected level of concreteness.

## Next Steps

Apply the remedy to design.md only (requirements.md/acceptance-tests.md
unaffected — AC-014's own text is not being changed, only design.md's
compliance with it). Re-run `impl-review-precheck.sh
epic-195-a7-compatibility 2 2 --verify-inputs`-equivalent flow per
SKILL.md's own re-invocation rules (STEP 1 with incremented round,
requiring design.md to have changed since round 1 — DESIGN-REQ-DRIFT
logic), then proceed through both reviewers again.
