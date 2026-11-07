# UX Specification: SQLite Task Board

## Scope and User Journeys
Local user opens root, adds a task, completes or deletes a row and later returns to durable state (REQ-001–005, AC-001–005). Accounts and other pages are excluded.

## Target Views
| View | User | Purpose | Entry | Exit | REQ | AC |
|---|---|---|---|---|---|---|
| Task board | local user | manage tasks | root URL | close/reload browser | REQ-001–005 | AC-001–005 |

## Component States
| Component | State | Trigger | Visible Feedback | Recovery | REQ | AC |
|---|---|---|---|---|---|---|
| List | Empty | zero rows | No tasks yet | add title | REQ-005 | AC-005 |
| List | Loading | initial fetch | Loading tasks | timeout then Retry | REQ-005 | AC-005 |
| Form/row | Pending | request started | Saving; relevant controls disabled | await result | REQ-005 | AC-005 |
| Status | Error | request failure | plain error, no false success | retain title, Retry list | REQ-005 | AC-005 |
| Row | Success | committed response | task visible/completed/removed; live announcement | next action | REQ-001–003 | AC-001–003 |

## Interaction Sequence
User intent -> client validation -> API -> committed SQLite transaction -> list refresh -> visible feedback. Disable duplicate submission while pending; no optimistic durable state.

## Wireframe Attachments
No mockup provided — optional visualization skipped

## Navigation Map
Root is the only route. Browser reload discards unsaved input and reloads server state; no deep links or guarded routes.

## Accessibility
Target WCAG 2.2 AA: main landmark, one h1, associated input label and error description, native buttons, visible focus, logical tab order, polite live region and alert for failure. Return focus to title after add; after delete move to next row action or title. Completed status has text in addition to styling. Minimum text contrast 4.5:1, control contrast 3:1, targets >=24px with spacing. Reflow at 320px and 200% zoom; no animation required (AC-005, TEST-005).

## Responsive Behavior
320–639px: single-column form and wrapping row actions. 640–1023px: inline form, flexible rows. >=1024px: centered max-width board. No fixed-height clipping or horizontal overflow; keyboard/touch/pointer all supported.

## Design Tokens
ds_profile: none

Use local CSS values without a design-system integration: white background, dark text, clear blue focus, 8px spacing baseline; validate contrast rather than assume it.

## Open Questions
Human reviewer owns explicit confirmation of proposed shell/safety and ds_profile defaults. Blocks implementation until confirmed.
