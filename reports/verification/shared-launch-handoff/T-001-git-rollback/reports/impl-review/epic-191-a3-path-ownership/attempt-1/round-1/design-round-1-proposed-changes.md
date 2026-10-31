# Implementation Policy Review Report: epic-191-a3-path-ownership — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-191-a3-path-ownership |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | BLOCKED (reviewer-local formula; round-aware integrated outcome is NEEDS_WORK per SKILL.md STEP 6, round < 3) |
| Critical Findings | 1 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-07-21T23:05:00Z |

## Reviewer-A Findings (Structural Soundness)

- **DATA-COVERAGE — FAIL (Major)**: design.md's `## Data Plan` (lines 341-402) has explicit `Data Entities:` and `Existing Data Affected:` content but no `Migration Strategy:` sub-field anywhere in the document (`grep -in migration design.md` returns zero matches). This feature introduces genuinely new data shapes (resolver-output JSON, `ownership_digest`, the `check-component-coverage-verdict/v1` evidence record), so the "no data changes" exemption does not apply, and no "no migration required, because ..." statement closes the gap explicitly.

All other reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS, API-COVERAGE, SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT, ADR-PRESENT) PASS; FRONTEND-BACKEND-CONSISTENCY is SKIP (no frontend surface).

## Reviewer-B Findings (Implementability/Risk)

- **NO-REQ-CONTRADICTION — FAIL (Critical)**: design.md's `## Constraint Compliance` section (lines 832-841, 6 rows) exists, so the full constraint-reconciliation check path applies. Three explicit, normatively-worded requirements.md constraints have no row in that table: (a) the Windows/macOS/Linux path-semantics-must-not-depend-on-host-OS compatibility constraint (requirements.md lines 64-69); (b) the submodule/symlink reference-only boundary (requirements.md Security Boundaries bullet 4); (c) the Fail-6 credential-exclusion constraint (requirements.md Security Boundaries bullet 5). The substance of all three exists elsewhere in the document (Design Decisions, Security Boundaries, security-spec.md), but the designated compliance-reconciliation table does not track them.
- **DEPLOYMENT-CONCRETE — FAIL (Major)**: design.md's `## Deployment / CI Plan` section (lines 821-830) covers only test-suite CI registration. It does not describe or cross-reference the feature's actual staged-rollout mechanism — the `disabled-legacy`/`advisory`/`required` capability-derived applicability model (REQ-004, ADR-0016) — nor its interaction with this repository's own current absence of `project-context.yaml` (INV-002) and `check-contract`'s capability-state-blind tier-minimum set (INV-018). This content exists elsewhere (Architecture, Design Decisions, Security Boundaries B5) but is not consolidated into or cross-referenced from the Deployment/CI Plan section.

All other reviewer-B checks (DECISION-JUSTIFIED, OPEN-QUESTIONS-RESOLVABLE, ASSUMPTIONS-VALID, PERF-ADDRESSED, MIGRATION-PLANNED, INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE) PASS.

## Proposed Changes

1. Add a `Migration Strategy:` sub-field to design.md's `## Data Plan` section stating explicitly that no schema/database migration exists (no database, no runtime storage — infra-spec.md's Data Residency and Retention section already confirms this) and that the three new data shapes (resolver output, `ownership_digest`, Gate evidence record) are net-new, additive artifacts consumed by `quality-gate`'s evidence bundle with no prior-version compatibility concern.
2. Add three rows to design.md's `## Constraint Compliance` table reconciling: (a) the cross-OS path-semantics constraint (requirements.md lines 64-69) against the glob-normalization Design Decisions and REQ-009's parity harness; (b) the submodule/symlink reference-only constraint against Security Boundaries / security-spec.md B4; (c) the Fail-6 credential-exclusion constraint against Security Boundaries bullet 5 / security-spec.md Secrets Management.
3. Extend design.md's `## Deployment / CI Plan` section with a short paragraph or cross-reference describing the `disabled-legacy`/`advisory`/`required` staged-rollout mechanism (REQ-004, ADR-0016) and noting that this repository's own current lack of `project-context.yaml` resolves to the safe `disabled-legacy` evidence-record path via the ADR-0016 file-absence fallback, rather than an unexpected block, cross-referencing Architecture / Design Decisions / Security Boundaries B5 rather than duplicating their content.

## Next Steps

Apply the three remedy edits above to `specs/epic-191-a3-path-ownership/design.md` only (no new design judgment — cross-references and reconciliation of content already stated elsewhere in the same document). Re-invoke impl-review-precheck for round 2 with `--edit-summary` describing the change, then re-run both reviewers.
