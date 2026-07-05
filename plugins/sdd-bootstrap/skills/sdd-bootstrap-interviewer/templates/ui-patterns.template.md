# UI Patterns: <project>

Universal, stack-independent interaction conventions. They apply to web,
desktop, and embedded UI alike, and are referenced at generation time by the
implementation policy and at verification time by the design-system checklist.
Mermaid diagrams remain canonical for flows; this document constrains layout
and interaction decisions. Defaults below may be edited per project — keep
every rule phrased with its reason.

## Actions

- Keep primary/secondary button order and position consistent on every screen,
  following the platform convention.
- Exactly one primary action per screen.
- Physically separate destructive actions from routine ones; defend them with
  color plus a confirmation step.

## Dialogs

- Use a modal dialog only to confirm an irreversible or destructive operation.
- Notifications and progress never use modals — use toast or inline display.
  Do not stack or chain dialogs.
- Dialog buttons carry text labels; icon-only buttons are prohibited inside
  dialogs.

## Icons

- Icon-only usage is limited to universally understood meanings (search,
  close); otherwise pair the icon with text.
- One icon per element. Use the same icon for the same concept on every screen.

## Flow

- Fix the position of "next/back" in wizards and screen transitions.
- Arrange content top-to-bottom / left-to-right along the user's work order
  (read → input → confirm).
- Always design the post-submit feedback and the recovery path on error.

## States

- Define empty, loading, and error states for every view.
- Show an error message near where it occurred and state the next action.

## Cognitive Load

- One purpose per screen.
- Group choices to roughly 7±2 items and provide sensible defaults.
