# UX Specification: A1 RT002 bounded repair

## Scope and User Journeys

N/A — no change: no graphical user interface or navigation. Existing caller emits a challenge, records the actual result and reads the typed CLI verdict. REQ-001–REQ-005 / AC-001–AC-006 preserve refusal and recovery semantics; they do not add a bypass control.

## Component States

Verification succeeds only as `HOOK_ACTIVE`; refusal is `CAPABILITY_RUNTIME_UNAVAILABLE` with its reason and nonzero exit. Cleanup confirmed/unconfirmed never changes the capability result. Detailed output assertions: TEST-001–TEST-080.

## Accessibility and Visual Artifacts

N/A — no change to CLI interaction or visual controls. None — manual visual refinement skipped. No design upload, tokens, responsive layout or new views are introduced.

## Open Questions

None.
