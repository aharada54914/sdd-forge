# Spec Review — Round 1 Proposed Changes (epic-136-phase1-guards)

Verdict: NEEDS_WORK (Critical 1, Major 3). Reviewer A: PASS. Reviewer B:
NEEDS_WORK. The following edits to `requirements.md` and `acceptance-tests.md`
resolve every finding. All edits are to agent-editable Phase 1 artifacts.

## Finding: APPROVAL-BOUNDARY (Critical, reviewer B)

The REQ-004 cross-model waiver was agent-settable because `tasks.md` is not a
protected human-copy surface, and AC-008/AC-009 tested only presence, not human
authorship.

Change: bind the waiver's *validity* to the existing human-only approval mark.
Define `Cross-Model-Waiver:` as an optional per-task field that is honored ONLY
when the task also carries a human `Approval: Approved` audit mark bearing a
second distinct named human approver (the same human-only mark the guard
already prevents an agent from writing, and the same distinct-approver rule
already mandated for critical tasks). A `Cross-Model-Waiver:` value without that
human approval context is ignored and cross-model verification remains required
(fail-closed). Full guard-level enforcement of the waiver token itself is noted
as future hardening (out of scope for this batch) but is unnecessary here
because an agent cannot produce the human approval context the waiver depends
on. New AC-008 asserts the fail-closed behavior; AC-009 asserts the field
definition is documented.

## Finding: AMBIGUITY + DOWNSTREAM-READINESS(1) (Major, reviewer B)

The "security-sensitive marking" had no defined field name or values.

Change: define the trigger precisely. Cross-model verification is required for a
task when `Risk: critical`, OR when the task carries `Security-Sensitive: true`.
`Security-Sensitive:` is a per-task boolean field, proposed by the task author
and confirmed by the human at approval. REQ-004 and the acceptance criteria name
this field explicitly so no implementer has to invent a syntax.

## Finding: EDGE-CASE-COVERAGE + DOWNSTREAM-READINESS(2) (Major, reviewer B)

The mandated "no PR created -> guard passes vacuously" path had no acceptance
criterion.

Change: add AC-014 / TEST-014 asserting the REQ-005 guard step passes when the
automated session created no branch or PR.

## Net changes

- requirements.md: REQ-004 reworded with explicit `Security-Sensitive: true`
  trigger and `Cross-Model-Waiver:` human-gated validity; Roles updated; AC-008
  and AC-009 reworded; AC-014 added; a Field Definitions note added.
- acceptance-tests.md: AC-008 and AC-009 rows reworded; AC-014 / TEST-014 row
  added.
