# Implementation Policy Review Report: epic-191-a3-path-ownership — Round 1 / Attempt 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-191-a3-path-ownership |
| Round | 1 of 3 |
| Attempt | 2 (`--provenance-rereview` — post-implementation evidence re-binding) |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-08-11T09:52:00Z |

## Reviewer-A Findings (Structural Soundness)

- **ADR-PRESENT — FAIL (Major)**: design.md references the new ADR at
  `docs/adr/0025-component-path-ownership-resolver-semantics.md` in three
  places (design.md:158 Components table, design.md:311-312 ADR Change Log,
  design.md:988/991 Risks), each time only hedged as "provisional,
  re-verified at drafting time." That path does not exist on disk:
  `docs/adr/0025-*` is occupied by two unrelated ADRs
  (`0025-human-copy-transactional-bundle.md`,
  `0025-risk-adaptive-adversarial-review-lane.md`). The actual
  resolver-semantics ADR exists at
  `docs/adr/0027-component-path-ownership-resolver-semantics.md`, whose own
  text states "Numbering note: re-verified with `ls docs/adr/` on
  2026-08-08. ADR numbers 0025 and 0026 were occupied after the original
  draft, so this decision was renumbered to the next free slot, 0027." No
  occurrence of "0027" appears anywhere in the current spec package.

All other reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS,
DATA-COVERAGE, API-COVERAGE, SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE,
NO-UNDEFINED-COMPONENT, DESIGN-SYSTEM-CONFORMANCE, DOMAIN-CONFORMANCE)
PASS; FRONTEND-BACKEND-CONSISTENCY is SKIP (no frontend surface).

## Reviewer-B Findings (Implementability/Risk)

- **OPEN-QUESTIONS-RESOLVABLE — FAIL (Major)**: design.md's
  `## Open Questions` section contains only a single terse
  cross-reference sentence carrying OQ-002. The entry names no owning
  role, has no `Blocks Implementation: yes/no` field, and has no
  `Resolution Path:` field, as the check requires; requirements.md's own
  OQ-002 entry likewise states its adopted decision inline ("middle
  path") rather than in the required schema. Per the check's own rule,
  "An open question with no owner is a Major finding."

All other reviewer-B checks (DECISION-JUSTIFIED, ASSUMPTIONS-VALID,
NO-REQ-CONTRADICTION, PERF-ADDRESSED, DEPLOYMENT-CONCRETE,
MIGRATION-PLANNED, INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE,
VERIFICATION-PATH-CONCRETE) PASS; DOMAIN-CONFORMANCE is SKIP (no
`domain/` directory).

## Proposed Changes

1. Update design.md's three references to the resolver-semantics ADR from
   `docs/adr/0025-component-path-ownership-resolver-semantics.md` to
   `docs/adr/0027-component-path-ownership-resolver-semantics.md`
   (Components table row, ADR Change Log, Risks), recording the
   renumbering visibly (the ADR itself documents the 2026-08-08
   renumbering after the 0025/0026 slots were taken by unrelated merged
   ADRs). No design judgment involved — the ADR's content is unchanged;
   only its number moved.
2. Restructure design.md's `## Open Questions` OQ-002 entry into the
   required schema: owning role, `Blocks Implementation: yes/no`, and
   `Resolution Path:`. The substance already exists (requirements.md's
   adopted middle path: T-001/T-002 proceed against the decision-document
   v2 §12 shape; T-001 `Done` is gated on the AC-011 fail-closed
   schema-conformance fixture against Epic A1's merged template) — this
   is recording the already-made decision in the mandated structure, not
   making a new one.

## Next Steps

Apply the two remedy edits above to
`specs/epic-191-a3-path-ownership/design.md` only (both are document
repairs recording already-made decisions; neither requires a product
decision). Re-invoke impl-review-precheck for round 2 with
`--provenance-rereview` semantics preserved and `--edit-summary`
describing the change, then re-run both reviewers with fresh
validator-reserved identities.
