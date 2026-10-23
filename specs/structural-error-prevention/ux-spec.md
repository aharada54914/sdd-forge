# UX Specification: Structural Error Prevention

Draft; implementation and review pending.

## Scope and User Journeys

REQ-001/004/007: a contributor reads the existing three-class map, follows source and runtime evidence, sees the enforcing mechanism or retained human decision, then finds negative/control results and the #600 handoff. Distinguish existing implementation, proposed changes, observed test results, unknown cause and unmeasured retention in plain text. Reuse the contributor document; no new product entry point or interaction.

## Component States

No new UI or persisted workflow states. Existing WFI/task states retain their meanings. “Unknown” and “Not evaluated” describe evidence, not approval or task lifecycle transitions. An incomplete audit may still contain valid findings; zero findings requires a completed, evidenced audit. Pending human-copy ambiguity remains visible and does not imply permission to overwrite.

## Verification

TEST-001/005/008/009 inspect source-backed interpretation and readable evidence boundaries. Accessibility/UI interaction tests are N/A because no UI is added.
