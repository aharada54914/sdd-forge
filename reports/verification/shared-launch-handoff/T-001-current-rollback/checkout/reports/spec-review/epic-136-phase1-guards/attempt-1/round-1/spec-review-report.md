# Specification Review Report — epic-136-phase1-guards (attempt 1, round 1)

Verdict: NEEDS_WORK
Finding counts: Critical 1, Major 3, Minor 0. warningCount 0.

## Reviewers

- spec-reviewer-a (run spec-a-epic136guards-a1r1-20260711-d4e5): PASS. All
  seven checks PASS/SKIP; requirements testable, goals traced, acceptance
  observable, scope bounded, constraints explicit, risks tied to validation
  surfaces.
- spec-reviewer-b (run spec-b-epic136guards-a1r1-20260711-e6f7): NEEDS_WORK.

## Findings (reviewer B)

1. APPROVAL-BOUNDARY (Critical): the REQ-004 cross-model waiver was
   agent-settable — tasks.md is not a protected surface and AC-008/AC-009
   tested only presence, not human authorship.
2. AMBIGUITY (Major): the "security-sensitive marking" had no defined field
   name or values.
3. EDGE-CASE-COVERAGE (Major): the mandated "no PR created -> vacuous pass"
   path had no acceptance criterion.
4. DOWNSTREAM-READINESS (Major): (1) the marking field and (2) the waiver
   human-only mechanism would otherwise fall to the downstream reviewer.

## Resolution

See `spec-round-1-proposed-changes.md`. requirements.md and
acceptance-tests.md were revised: REQ-004 now names `Security-Sensitive: true`
as the explicit trigger and binds `Cross-Model-Waiver:` validity to a
co-located human `Approval: Approved` mark (second distinct approver), making
it inert when agent-written; a Field Definitions section was added; AC-008 and
AC-009 were reworded; AC-014 was added for the vacuous-pass path. Proceeding to
round 2.
