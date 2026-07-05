# Design System Review Checklist

On-demand checklist for the critical reviewer and `quality-gate`. Load it only
when the change touches user-facing UI in a project that carries a
`design-system/` contract; skip it with a note otherwise. Findings map onto
the shared severities in `evaluation-rubric.md`: design-system non-conformance
is `Major` by default, cosmetic-only drift is `Minor`.

## Tokens

- Style values in the diff reference design-tokens.json tokens; no raw color
  codes (#hex / rgb() / hsl()) or magic spacing values outside design-system/
  and generated build/ outputs.
- New tokens were added to design-tokens.json (with a meta.version bump)
  rather than hardcoded locally.

## Components

- Existing components are reused; every new component has its reason recorded
  in design.md's `## Design System Compliance` section.
- Component states follow the layer specs (default, empty, loading, error).

## Responsive and Dark Mode

- Changed views reflow at the breakpoints the feature's specs define.
- Dark-mode rendering is checked only when design-tokens.json defines dark
  variants; otherwise record `N/A — no dark tokens`.

## UI Patterns (ui-patterns.md)

- Exactly one primary action per screen; destructive actions physically
  separated and confirmed.
- Modals only confirm irreversible or destructive operations; notifications
  and progress stay non-modal; dialog buttons carry text labels.
- Icons are paired with text except universally understood ones; the same
  icon means the same concept everywhere.
- Wizard/flow controls keep fixed positions; layout follows the read → input
  → confirm order; post-submit feedback and error recovery paths exist.
- Empty, loading, and error states are defined for every changed view, with
  errors shown near their source and naming the next action.

## Verification

- `scripts/check-design-system.(sh|ps1)` output is captured as evidence.
  Warn-phase: its findings are recorded, non-blocking until error promotion
  (`SDD_DESIGN_SYSTEM_ENFORCE=error`).
