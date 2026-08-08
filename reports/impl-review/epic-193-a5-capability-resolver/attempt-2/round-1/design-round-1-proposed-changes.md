# Implementation Policy Review Report: epic-193-a5-capability-resolver — Round 1 / Attempt 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-193-a5-capability-resolver |
| Round | 1 of 3 |
| Attempt | 2 |
| Context | fresh re-review after cross-epic addendum (Epic A6 finding B5) narrowed `lite-check-source-undefined` in requirements.md/acceptance-tests.md/design.md |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-22T04:51:16Z |

## Reviewer-A Findings (Structural Soundness)

All nine reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS, DATA-COVERAGE, API-COVERAGE,
SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT, ADR-PRESENT) PASS with
cited evidence; FRONTEND-BACKEND-CONSISTENCY is SKIP (cli feature type, no frontend
surface). Reviewer-A specifically confirmed the narrowed `lite-check-source-undefined`
addendum is internally consistent across requirements.md/acceptance-tests.md/design.md.

## Reviewer-B Findings (Implementability/Risk)

- **NO-REQ-CONTRADICTION — FAIL (Major)**: design.md's `## Constraint Compliance` section
  is present but its own content is limited to two bullets (AGENTS.md governance rules;
  the `plugins/**` scope boundary) and does not itself address requirements.md's
  substantive security or compatibility constraints (Security Boundaries bullet 1's
  Provider-API/credential/write-path constraint; REQ-005's no-clock/no-network
  orchestration guarantee). Calibrated Major, not Critical: both constraints ARE
  substantively addressed elsewhere in this same design.md (`## Security Boundaries`,
  `## Global Constraints`, `## ADR Change Log`), so no constraint is actually absent
  from or contradicted by the design as a whole — this is a structural consolidation
  gap in one dedicated section, not a missing or contradicted constraint. Remediation
  is low-cost: add cross-referencing sentences to Constraint Compliance pointing to the
  three sections that already carry the substance.

All nine other reviewer-B checks (DECISION-JUSTIFIED, OPEN-QUESTIONS-RESOLVABLE,
ASSUMPTIONS-VALID, PERF-ADDRESSED, DEPLOYMENT-CONCRETE, MIGRATION-PLANNED,
INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE) PASS with cited
evidence. Reviewer-B independently confirmed the narrowed `required_lite_checks` sourcing
logic (design.md API/Contract Plan step 10b) is internally consistent, implementable, and
honestly scoped (no fabricated fixture for the not-yet-reachable required-present-empty
state). Reviewer-B also noted, non-blocking, a pre-existing editorial slip at
design.md's Data Plan prose ("14-value" enum reference, superseded by the actual
sixteen-value JSON Schema and prose elsewhere in the same document) — out of scope for
this addendum's own remedy, not raised as a formal finding.

## Proposed Changes

1. Expand design.md's `## Constraint Compliance` section with two new bullets
   cross-referencing the security constraint (Security Boundaries / Global Constraints)
   and the compatibility constraint (ADR Change Log / upstream contract content-freeze),
   rather than restating that content — a structural consolidation fix, not a new design
   judgment.

## Remedy Applied

Applied directly to `specs/epic-193-a5-capability-resolver/design.md`'s `## Constraint
Compliance` section: added a "**Security constraints**" bullet cross-referencing `##
Security Boundaries`/`## Global Constraints`, and a "**Compatibility constraints**"
bullet cross-referencing `## ADR Change Log` and the upstream Epic A1-A4
content-freeze guarantee (Dependencies, requirements.md). No other section changed.

## Next Steps

Re-invoke impl-review-precheck for round 2 with `--edit-summary` describing this change,
then re-run both reviewers fresh.
