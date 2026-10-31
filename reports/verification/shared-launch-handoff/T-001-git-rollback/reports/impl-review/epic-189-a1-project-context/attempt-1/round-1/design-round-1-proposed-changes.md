# Implementation Policy Review Report: epic-189-a1-project-context — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-189-a1-project-context |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-21T23:38:21Z |

## Reviewer-A Findings (Structural Soundness)

All checks PASS or SKIP except:

- **ADR-PRESENT (Major, FAIL)**: design.md's `## ADR Change Log` (lines
  268-281) states "No new ADR. Every design decision this epic makes is
  already recorded in docs/adr/0016..0020,0023.md" — all five files verified
  to exist. However, design.md's own "Human-copy publisher transactional
  bundle contract" (lines 911-1001) and its paired "New decision (NEW —
  multi-target atomicity)" Design Decision entry (lines 1382-1400) introduce
  a journaled, multi-target atomic-transaction protocol (prepare/journal/
  commit/complete sequence plus automatic crash-recovery converging every
  target to exactly one of two terminal states, never a standing
  partial-publish mix — also Security Boundaries B8, design.md:1481). This
  is a materially new integration pattern NOT covered by the ADR design.md
  itself cites as this mechanism's precedent: docs/adr/0011's own
  Consequences section states the opposite, explicitly-accepted limitation
  verbatim — "Each target rename is atomic, but the 18-target batch is not
  one transaction. A rename-time OS failure may leave a deterministic
  installed prefix and must be recovered with a reviewed full rollback
  batch." ADR-0011 explicitly accepts the exact partial-publish risk as an
  unautomated, human-reviewed residual; design.md's new protocol claims
  automatic convergence to one of two terminal states with no
  human-reviewed rollback step. No other ADR in docs/adr/ (0001-0024) covers
  multi-file transaction/journaling semantics. design.md's own ADR Change
  Log closing text already anticipates exactly this kind of impl-review
  judgment for a narrower case (OQ-001's approver-registry file, "if
  impl-review disagrees, promoting it to its own ADR is a low-cost
  follow-up") but did not extend that same self-check to this transaction
  protocol.

## Reviewer-B Findings (Implementability/Risk)

No FAIL findings. All 10 checks PASS (DECISION-JUSTIFIED,
OPEN-QUESTIONS-RESOLVABLE, ASSUMPTIONS-VALID, NO-REQ-CONTRADICTION,
PERF-ADDRESSED, DEPLOYMENT-CONCRETE, MIGRATION-PLANNED,
INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE),
plus DOMAIN-CONFORMANCE (SKIP — no `domain/` directory in this repository).

## Proposed Changes

Promote the already-approved "Human-copy publisher transactional bundle
contract" / "New decision (NEW — multi-target atomicity)" content (design.md
lines 911-1001, 1382-1400) to a new ADR (`docs/adr/0025-*.md`), matching the
existing ADR format precedent (Status/Date/Context/Decision/Consequences/
Verification, per ADR-0011's own shape). This is a pure documentation/
traceability remedy — it formalizes content already fixed and
Spec-Review-Status: Passed in design.md; it does not change the
transactional bundle's substantive mechanism (journal-write-before-rename,
atomic renames in recorded commit order, crash-recovery-to-one-of-two-
terminal-states, publisher self-protection). Update design.md's `## ADR
Change Log` section to cite the new ADR alongside the existing five.

## Next Steps

Apply the proposed changes to `docs/adr/` and `specs/epic-189-a1-project-context/design.md`,
commit, then re-invoke impl-review-loop for round 2 with `--edit-summary`
describing the change.
