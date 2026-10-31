# Implementation Policy Review Report: epic-195-a7-compatibility — Round 1 / Attempt 4

## Verdict: BLOCKED

| Field | Value |
|---|---|
| Feature | epic-195-a7-compatibility |
| Round | 1 of 3 |
| Attempt | 4 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | BLOCKED |
| Critical Findings | 1 |
| Major Findings | 3 |
| Minor Findings | 0 |
| Generated | 2026-08-27T03:06:17Z |

## Reviewer-A Findings (Structural Soundness)

- **DATA-COVERAGE (Major):** design.md:251 uniquely assigns PROJECT_CONTEXT_INVALID to producer skip-stop-message:stop and explicitly forbids quality-gate-outcome, consistent with requirements.md:463-469, but design.md:1127 describes it as a dedicated skip-stop-message/quality-gate-outcome-kind event. This contradictory schema mapping leaves the persisted event kind and producer contract ambiguous for AC-019 through AC-021.
- **TEST-STRATEGY-COVERAGE (Major):** The Test Strategy supplies integration, static/schema, acceptance, command, suite, and artifact plans but does not define unit-test scope or what is mocked. It also has no implementable passing path for AC-026: acceptance-tests.md:30 leaves TEST-026 Planned while stating that its producer firing condition is known-unsatisfied by the implementation AC-009 pins; requirements.md:511-532 and OQ-004 at lines 919-952 explain that failing comparisons emit a transition and early returns emit none, while design.md:1141-1150 incorrectly says all open questions are resolved. The design therefore cannot yield passing verification evidence for this acceptance criterion without a further formal amendment.

## Reviewer-B Findings (Implementability/Risk)

- **NO-REQ-CONTRADICTION (Critical):** requirements.md AC-026 and Open Questions OQ-004 state that the AC-009-pinned implementation violates the Done-transition producer firing condition: it emits before terminal-state comparison, emits on a failed comparison, and emits nothing on either early return. design.md Data Plan nevertheless requires that producer to fire exactly once per round at the instant it evaluates the freshly read terminal state, while design.md Constraint Compliance contains no compliance statement or disposition for this known-unsatisfied compatibility constraint and design.md Open Questions says only OQ-001 through OQ-003 exist and are resolved. The current amended design therefore presents an unsatisfied compatibility invariant as implementable without carrying its governing open resolution into the implementation policy. This is a primary TYPE-D missing constraint-compliance statement and can cause downstream work or verification to claim a contract the pinned implementation cannot meet; the provenance re-review context re-binds these current bytes but does not waive the defect.
- **VERIFICATION-PATH-CONCRETE (Major):** The high-risk Done-transition compatibility claim has no concrete validation path for its producer firing semantics. design.md Data Plan requires exactly one emission per round at terminal-state evaluation, but acceptance-tests.md TEST-026 checks only that the event is last within TEST-018 and TEST-019. requirements.md AC-026/OQ-004 explicitly records that failed comparisons and early returns violate the firing condition and that no check in the package detects the deviation. Thus the named verification artifact cannot validate the applicable high-risk claim; this is distinct from the TYPE-D contradiction because it is the absence of an executable mismatch test for failed-comparison and early-return branches.

## Proposed Changes

Human amendment is required before re-review. Reconcile design.md's PROJECT_CONTEXT_INVALID event-kind mapping, carry AC-026/OQ-004 into Constraint Compliance and Open Questions, and define both unit/mock scope and a concrete mismatch test for failed-comparison and early-return producer branches. Because the relevant spec artifacts are frozen, follow the repository's authorized addendum and provenance re-review rules rather than editing frozen content in place.

## Next Steps

Stop this re-binding attempt. Obtain human authorization for the required amendment, then invoke the documented implementation-policy provenance re-review lane in a fresh attempt.
