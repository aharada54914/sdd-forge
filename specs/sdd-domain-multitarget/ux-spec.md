# UX Specification: sdd-domain-multitarget

## Scope

**N/A — this slice has no rendered or interactive UI.** It changes the SDD
bootstrap/verification contracts and their terminal or agent-facing reports,
not a browser, desktop view, route, or component.

The human-visible contract is the existing workflow output: target selection,
applicable facets, required/conditional checks, and fail-closed diagnostics.
Those outputs must remain deterministic and must not expose provider
credentials, binding values, or unrelated project content. A legacy consumer
continues to receive the existing seven layer documents; target applicability
is additive metadata, not an omission signal (see `design.md`, Consumer
Disposition).

## Accessibility and interaction

No new interaction, keyboard path, visual state, or accessibility surface is
introduced. Existing CLI/agent error messages remain actionable and preserve
the current fallback when no valid Project Context is present.

## Open questions

None for this phase. UI-provider operations are explicitly deferred.
