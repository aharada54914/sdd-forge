# UX Specification: epic-136-phase4-mcp

N/A — no change: this feature adds 3 new response fields
(`unreadableContracts`, `hostRequiredChecks`, `undeterminable`) to 3
existing read-only MCP tools (`evidence_compare_to_traceability`,
`evidence_deep_verify`, `evidence_find_missing`) and 1 new internal function
(`listGuardedFilesWithDiagnostics`) to `path-guard.ts`. There is no GUI,
view, dialog, menu item, or human interactive shell surface — the consumer
of every affected tool is an MCP client (an AI agent session), never a
human operating a rendered interface directly. The only human-observable
effect is indirect: a maintainer reading a quality-gate report or an
implementation report produced by an agent session that called one of these
3 tools may now see a more precise statement (e.g. "task T-005's
verification contract is unreadable" instead of silence, or "the
quality-gate report for T-006 could not be determined" instead of a
potentially misleading "missing") — governed entirely by
acceptance-tests.md's AC-NNN criteria, not by any UX artifact.

## Scope and User Journeys

- Primary user: MCP clients (AI agent sessions) calling
  `evidence_compare_to_traceability`, `evidence_deep_verify`, or
  `evidence_find_missing` during a quality-gate, task-review, or Done-
  transition check.
- Entry points: the 3 existing MCP tool names, invoked exactly as today
  (`{ feature }` or `{ feature, taskId }` input, unchanged) — no new tool
  name, no new input field.
- Success outcome: the calling agent session's own downstream
  reasoning/report can distinguish "unreadable/undeterminable" from
  "genuinely clean/empty" for the 3 conditions this feature addresses
  (requirements.md Acceptance Criteria).
- Excluded journey: any rendered UI, navigation, or MCP Inspector visual
  interaction — this feature's own verification is via `node:test` +
  `MCP Inspector CLI`'s `tools/list`/`tools/call`, not a GUI walkthrough.

## Target Views

N/A — no change: no rendered views or navigation paths exist.

## Component States

N/A — no change: response field presence/values are specified by
acceptance-tests.md and design.md's API/Contract Plan, not a visual
component state.

## Wireframe Attachments

None — manual visual refinement skipped. No mockup provided — optional
visualization skipped.

## Accessibility

N/A — no change: no browser or desktop accessibility surface is introduced.
All output is structured JSON (MCP tool-call response), consumed
programmatically; no field discloses secrets or credentials
(security-spec.md Trust Boundaries).

## Responsive Behavior

N/A — no change: no layout is rendered.

## Design Tokens

ds_profile: none. N/A — no change: no design tokens apply.

## Open Questions

None. Owner: maintainers; non-blocking.
