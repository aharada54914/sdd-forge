# Design System: タスクボード

Version: 0.1.0
Profile: custom
Status: user-authorized test scope; no protected approval record issued

## Layer 1 — Tokens
design-tokens.json is authoritative. Generate CSS custom properties in design-system/build/ and import them in app CSS. White surfaces, navy text, teal actions, system Japanese-capable fonts, 4px spacing grid. All visual values derive from tokens.

## Layer 2 — Component conventions
Single main view: AddForm, TaskList, TaskRow, StatusMessage. Exactly one primary action, 追加. Use semantic checkbox and labeled 削除 button. No sidebar, counters, filters or hamburger. These are illustrative reference elements outside the request.

## Layer 3 — Review checklist
- Tokens only; changes require a reviewed contract edit and version bump.
- Keyboard focus visible, Japanese accessible names, 44px controls, reflow at 320px.
- Saving disables all mutations; errors retain input and explain recovery.

## Change Process
Review edits against requirements before regenerating CSS; never fork token values in a component.
