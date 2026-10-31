# UX Specification: shared-review-launch-repair

## Scope and user journeys

No interactive UI is added. The operator-facing journey is existing command-line review: precheck, one-role invocation and native permission proof, one reservation, independent output validation, and status transition only after the corresponding gate. A rejection must name the failed boundary without implying a reviewer verdict. This follows `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:22-110` and `plugins/sdd-review-loop/scripts/preflight-host-review.py:142`.

## Target views and states

Command output has three distinct states: preflight refused (no reservation), native delivery/proof complete (not a verdict), and validated review outcome. The existing messages and evidence locations remain the interface; no new status token is introduced. Historical failures remain visible and are not rewritten.

## Accessibility, responsive behavior, and design tokens

Not applicable: no screen, wireframe, component, styling, or responsive layout changes. Plain-text errors must remain legible and unambiguous. No new design tokens.

## Open questions

None for the bounded repair. Actual host availability is a verification condition, not a design choice.
