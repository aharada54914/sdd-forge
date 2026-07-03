# Design System: <project>

- Version: 0.1.0 (mirrors design-tokens.json meta.version; bump together, semver)
- Profile: custom
- Status: Draft

The single source of truth for UI decisions in this project. design-tokens.json
holds the machine-readable values; this document holds the rules and the
reasons. Written as the fastest reference for an implementer (human or AI) to
find the correct answer — not as a compliance document. Rules state the reason
and the alternative, never a bare prohibition.

## Layer 1 — Tokens (machine-extracted)

- Every style value MUST reference a design-tokens.json token. Raw color codes
  (#hex / rgb() / hsl()) and magic spacing values are prohibited outside
  design-tokens.json and generated build/ outputs.
- Token transformation for this stack (CSS variables, tokens.ts, QSS, headers,
  etc.) is generated under `design-system/build/`; the tool (Terrazzo, Style
  Dictionary, or equivalent) is the project's choice and never authoritative.
- <how tokens are consumed in this project's stack — import path, naming>

## Layer 2 — Do / Don't (component conventions)

- Reuse existing components first. Create a new component only when the
  feature's design.md Design System Compliance section records the reason.
- <component conventions for this project: naming, variants, allowed states>
- <prohibited patterns, each written as "avoid X because Y; do Z instead">

## Layer 3 — Review checklist (human-curated)

- [ ] New or changed UI references tokens only (no raw values in the diff)
- [ ] Existing components reused, or the new-component reason is recorded
- [ ] ui-patterns.md conventions applied (actions, dialogs, icons, flow, states)
- [ ] Accessibility meets WCAG 2.2 AA (touch targets >= 24x24 px, focus not
      obscured, no cognitive-load-heavy authentication)

## Change Process

- Change tokens or rules by a reviewed edit to `design-system/`; never fork
  values locally in feature code. Bump meta.version and record the reason here.
