# Implementation Policy

- Implement exactly one approved task at a time.
- Treat `tasks.md` as the source of truth for approval and work status.
- Preserve unrelated user changes.
- Prefer existing repository patterns and dependencies.
- Add tests required by the task and run related regression tests.
- Stop rather than guess when specification or scope is ambiguous.
- Produce an implementation report before handing work to `quality-gate`.
- `Implementation Complete` means ready for independent review, not `Done`.

## Coding Rules In Scope

Use the target project's adopted language rules, configuration and project skills.
For sdd-forge source development, use the [coding standards index](../../../../../docs/contributor/coding-standards.md)
and only the language/boundary notes relevant to the change; do not reload every
rule or repository map. That repository preset is not imposed on installed projects.
Missing/unadopted coding rules and non-code tasks do not create a new blocker.

Before changing code, find the existing infrastructure API and source of truth.
Share logging, connection and resource mechanisms only behind a narrow, stable
contract; keep feature decisions separate unless a shared domain invariant is
established. Similar syntax alone does not justify merging workflows.
Before handoff, check unsafe value interpolation, swallowed failures, unused
prototypes/fallbacks, fixture-specific branches and independent test expectations.
Record the applicable checks, actual results and any unresolved contextual review
in the implementation report; a successful lint subset does not prove every rule.

## UI Implementation Rules

Apply these rules when the task touches UI-layer files and the project
carries a `design-system/` contract (`ds_profile: custom`). When
`design-system/` does not exist, skip them and note the absence in the
implementation report — the absence never blocks the task.

- Style values reference design-tokens.json tokens only. Raw color codes
  (#hex / rgb() / hsl()) and magic spacing values in UI code are defects.
- Reuse existing components first. Create a new component only when the
  feature's design.md `Design System Compliance` section records the reason.
- Accessibility essentials (WCAG 2.2 AA per design-system/design-system.md):
  no icon-only buttons in dialogs, never use placeholder text as a label
  substitute, clickable elements carry text.
- Follow design-system/ui-patterns.md for action placement, dialog usage,
  icons, flow order, and empty/loading/error states.
- When the target language has no lint configuration enforcing these rules,
  raise the gap as a follow-up task in the implementation report — do not
  add lint infrastructure inside an unrelated task's scope.

## Context Management

- Prefer fresh context over accumulated conversation state.
- `tasks.md` and the implementation report are the source of truth for work
  status; do not rely on conversation memory.
- When resuming after a break or session boundary, re-read `tasks.md` and
  `reports/implementation/<feature>/<task-id>.md` before taking any action.
- Record delegation conclusions in the Working Notes section of the report
  immediately after receiving them; do not keep them only in memory.
- If the session has grown long or compaction has occurred, write the current
  state to the Session Handoff section of the report and end the session.
