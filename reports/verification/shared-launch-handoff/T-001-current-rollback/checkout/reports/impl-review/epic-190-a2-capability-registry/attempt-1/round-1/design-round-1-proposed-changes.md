# Implementation Policy Review Report: epic-190-a2-capability-registry — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-190-a2-capability-registry |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | BLOCKED |
| Critical Findings | 1 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-07-21T22:56:49Z |

## Reviewer-A Findings (Structural Soundness)

- **ADR-PRESENT (Major, FAIL)**: design.md's `## ADR Change Log` states "No new ADR is proposed by this spec" and grounds every decision in existing ADRs (0017/0018/0020/0021/0022). However, two mechanisms this spec itself introduces are explicitly described, in design.md's own words, as "this spec's own proposal, not found verbatim in decision v2 or an ADR": (1) the Registry discovery contract (script-relative resolution → git-root fallback → fail-closed → per-artifact version check → vendored-copy drift gate), which Cross-Layer Dependencies states will also be Epic A5's Resolver's own discovery path — a reusable, cross-Epic integration pattern, not local-only detail; and (2) the Gate implementation identity mechanism (scan-root + `check-` prefix convention + wrapper-grouping + symlink resolution). No new ADR is proposed for either, leaving future Epics/implementers with no citable, versioned, repo-reviewed standard to consume or amend beyond this one Epic's design.md prose.

All other reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS, DATA-COVERAGE, API-COVERAGE, SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT) PASS; FRONTEND-BACKEND-CONSISTENCY, DESIGN-SYSTEM-CONFORMANCE, and DOMAIN-CONFORMANCE are correctly SKIPped (no UI/design-system/domain surface in this repository relevant to this feature).

## Reviewer-B Findings (Implementability/Risk)

- **NO-REQ-CONTRADICTION (Critical, FAIL)**: design.md's `## Constraint Compliance` section exists (so the Critical/primary rule applies) but lists only 3 bullets (Gate-stage scope, AC-034 no-file-changes, no-new-plugin). It omits at least three explicit "must"-level constraints stated elsewhere in requirements.md: (a) REQ-002's forbidden-operator/no-dynamic-evaluation constraint (ADR-0020); (b) REQ-003(g)'s provider-neutrality constraint (ADR-0018); (c) the cross-runtime byte-identical-output/determinism constraint (AC-031/032/033). All three are substantively designed for elsewhere in the document (Global Constraints, Security Boundaries, Test Strategy) but are not restated or cross-referenced inside Constraint Compliance itself, which this check treats as the authoritative compliance checklist.
- **OPEN-QUESTIONS-RESOLVABLE (Major, FAIL)**: (1) OQ-004's status is stated inconsistently — investigation.md's own Open Questions section says "Status: open, materially expanded," while investigation.md's Adversarial Spec Review Response section and design.md's Design Decisions section both separately say "fully closed 2026-07-22 — orchestrator ruling P8," and design.md's own Open Questions section still lists OQ-004 as "carried forward... not re-litigated." (2) design.md's Open Questions' fifth, unnumbered entry (four-language vs. JSON-only projection generation) has no named owner, no `Blocks Implementation:` field, and no `Resolution Path:`.

All other reviewer-B checks (DECISION-JUSTIFIED, ASSUMPTIONS-VALID, PERF-ADDRESSED, DEPLOYMENT-CONCRETE, MIGRATION-PLANNED, INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE) PASS; DOMAIN-CONFORMANCE is SKIP (no `domain/` directory exists in this repository).

## Proposed Changes

1. **Constraint Compliance completeness (resolves NO-REQ-CONTRADICTION, Critical).** Add three bullets to design.md's `## Constraint Compliance` section, cross-referencing existing content rather than restating it:
   - Forbidden-operator/no-dynamic-evaluation constraint (ADR-0020) → satisfied by the closed 8-operator schema grammar (API / Contract Plan `#/definitions/predicate`), Global Constraints' first bullet, and Security Boundary B2.
   - Provider-neutrality constraint (ADR-0018) → satisfied by REQ-003(g)'s `provider-terms.json` scan, Global Constraints' third bullet, and Security Boundary B1.
   - Cross-runtime byte-identical-output/determinism constraint (AC-031/032/033) → satisfied by Global Constraints' second bullet and Test Strategy items 1/3/7.
2. **OQ-004 status reconciliation (resolves half of OPEN-QUESTIONS-RESOLVABLE, Major).** Align investigation.md's Open Questions section OQ-004 status line with its own Adversarial Spec Review Response section and design.md's Design Decisions section (both already say "fully closed 2026-07-22 — orchestrator ruling P8"); update design.md's `## Open Questions` section to state OQ-004 is closed rather than "carried forward... not re-litigated," per that same ruling.
3. **Fifth open question ownership (resolves the other half of OPEN-QUESTIONS-RESOLVABLE, Major).** Add an owner, `Blocks Implementation: no`, and a `Resolution Path:` to design.md's fifth (four-language-vs-JSON-only) open question, consistent with how OQ-001/OQ-004 already state an owner ("Human maintainer") elsewhere in the package.
4. **ADR-PRESENT (Major).** Either propose a new ADR for the Registry discovery contract and/or the Gate implementation identity mechanism (tasks.md-scheduled implementation-phase work is acceptable per this gate's precedent elsewhere in this repository), or add an explicit design.md statement of why no ADR is warranted for either pattern at this stage. A remedy decision is needed from the human here — this is a scope/process judgment, not a content-only fix.

## Next Steps

Edit `specs/epic-190-a2-capability-registry/design.md` (and `investigation.md` for the OQ-004 status reconciliation) per the Proposed Changes above, then re-invoke impl-review-loop for round 2 with `--edit-summary` describing the changes made.
