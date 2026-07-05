---
name: visual-verify-loop
description: Implementation-phase visual verification loop for UI tasks. Launches the app (Claude Preview MCP for web, wpf-visual-verify for WPF desktop), compares the rendered UI against approved mockups, ux-spec states, and — when the project carries one — the design-system contract (tokens and ui-patterns), iterates fixes up to five times, and saves final screenshots as evidence under reports/visual-evidence/. Non-blocking; verdicts stay with quality-gate and human review.
disable-model-invocation: true
user-invocable: false
---

# Visual Verify Loop

Implementation-phase visual verification for UI tasks. Invoked by
`implement-task` after the scoped self-review and before the implementation
report is written. Advisory only: it accelerates design-conformance
iteration and records evidence; it never decides task completion.

## Trigger Condition

Run only when both hold; otherwise record the skip reason in the
implementation report and return:

- the task's feature has `specs/<feature>/ux-spec.md` or
  `specs/<feature>/mockups/`, and
- the task's scope includes UI-layer files (views, components, styles, or
  templates).

## App-Type Detection

- **Web**: a dev server can be started (`.claude/launch.json`, or a dev
  script in `package.json`) — use the Claude Preview MCP tools
  (`preview_start`, `preview_screenshot`, `preview_snapshot`,
  `preview_inspect`, `preview_resize`).
- **WPF desktop**: a WPF project is present — use the `wpf-visual-verify`
  skill (off-screen RenderTargetBitmap rendering to PNG).
- **Neither, or the tools are unavailable in this environment**: record
  `visual verification unavailable — skipped: <reason>` in the
  implementation report and return.

## Loop (max 5 iterations)

1. Build and launch (or re-render) the affected view.
2. Capture a screenshot. For web, also capture an accessibility snapshot
   and inspect computed styles for the properties under review (colors,
   fonts, spacing) instead of judging them from pixels.
3. Compare against the approved mockups in `specs/<feature>/mockups/`, the
   states defined in the feature's layer specs (default, empty, loading,
   error; responsive breakpoints), and — when the project carries a
   `design-system/` contract — token conformance against
   `design-system/design-tokens.json` (no raw style values in the rendered
   output's sources) and the conventions in `design-system/ui-patterns.md`
   (actions, dialogs, icons, flow, states).
4. If a mismatch is within the task's approved scope, fix the code and
   repeat. If it is out of scope, record it as a finding and continue.
5. Stop when the rendered UI matches, or after 5 iterations.

## Evidence

- Save the final screenshots to `reports/visual-evidence/<task-id>/`
  (one file per view and state, e.g. `login-default.png`).
- Add a `Visual Evidence` section to `reports/implementation/<task-id>.md`
  listing each screenshot, the mockup or spec state it was compared
  against, and any remaining mismatches as findings.

## Boundaries

- Non-blocking: findings never change the task state; PASS/NEEDS_WORK
  remains the job of quality-gate and human review.
- No pixel-diff regression tooling; comparison is model-inspected and
  recorded as findings.
- Never modify files outside the task's approved scope to chase a visual
  match; record the mismatch as a finding instead.
- A preview-server or build failure is recorded and skipped, never fixed by
  expanding scope and never a blocker.
- Design-system conformance findings here are advisory; the deterministic
  `check-design-system` gate (sdd-quality-loop) owns warn/error enforcement.
