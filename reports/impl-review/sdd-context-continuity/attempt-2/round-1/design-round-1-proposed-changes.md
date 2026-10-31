# Attempt 2 / round 1: NEEDS_WORK

Actual independent findings: Critical 0 / Major 2 / Minor 0. Reviewer A API-COVERAGE and reviewer B NO-REQ-CONTRADICTION identify the same adapter/core ObservationV1 contract collision.

Keep the core ObservationV1 and OutcomeV1 fields authoritative in design.md. Rename frontend native inputs to NativeObservation, explicitly derive validated owner and coverage before producing the closed core request, and never pass native/transcript locator fields to core. Correct the incomplete outcome enumeration to include existing cleanup outcomes. Sweep sibling references and re-review unchanged requirements/acceptance with updated design/layer hashes.

Standing user authorization permits agent-owned design corrections; no human terminal operation is required for these ordinary documents. Do not waive the findings or set Passed. Past launch deficiency and previous BLOCKED results remain intact.
