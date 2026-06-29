# UX Specification: Bootstrap Interviewer Enhancement

## Scope and Journeys

This is a CLI/document workflow, not a product GUI. The maintainer journey is:
interview → seven Phase 1 artifacts → three review gates → approved task →
implementation → quality gate. Existing artifacts are never silently replaced.

## States and Feedback

| State | Feedback | Recovery | Acceptance |
|---|---|---|---|
| Missing layer answer | Layer-local unknown is recorded | Resolve before review | AC-009 |
| Invalid feature slug | `invalid feature: <value>` and exit 1 | Correct slug | AC-011 |
| Missing feature artifact | Named missing artifact and exit 1 | Generate artifact | AC-012 |
| Draft task | Implementation is rejected | Human/sudo approval | AC-016 |

## Accessibility and Responsive Behavior

Diagnostics are plain text, do not rely on color, and identify the failing
value or file. Markdown tables remain understandable as source text. Product
navigation, breakpoints, touch targets, and visual tokens are not applicable
because no runtime UI is introduced.

## Visual Inputs

Mockups are optional local inputs. Their absence skips visual refinement without
blocking Phase 1. Mermaid source remains canonical.
