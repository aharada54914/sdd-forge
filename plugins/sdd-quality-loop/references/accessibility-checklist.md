# Accessibility Review Checklist

On-demand checklist for the critical reviewer and `quality-gate`. Load it only
when the change touches user-facing UI. Target: WCAG 2.1 AA. A change that makes
a core user flow unusable with the keyboard or a screen reader is `Major`
(or `Critical` if it blocks a primary acceptance criterion); cosmetic-only
gaps are `Minor`.

## Perceivable

- Every meaningful image has a text alternative; decorative images are hidden
  from assistive tech (`alt=""` / `aria-hidden`).
- Text contrast meets AA (4.5:1 normal, 3:1 large); information is never
  conveyed by color alone.
- Content reflows without loss at 200% zoom and on small viewports.

## Operable

- All interactive elements are reachable and usable by keyboard alone.
- Focus order is logical and a visible focus indicator is present.
- No keyboard traps; modals trap focus intentionally and restore it on close.
- Targets are adequately sized; motion respects `prefers-reduced-motion`.

## Understandable

- Form inputs have associated, programmatic labels; errors are announced and
  describe how to fix the problem.
- The page has a sensible heading hierarchy and a document language.
- Navigation and naming are consistent across the changed surface.

## Robust

- Semantic HTML first; ARIA only to fill genuine gaps (no redundant or
  conflicting roles).
- Custom controls expose correct name, role, and state to assistive tech.
- Dynamic updates use live regions or focus management so they are announced.

## Verification

- Keyboard-only walkthrough of the changed flow succeeds, captured as evidence.
- An automated a11y check (e.g. axe) reports no new violations on the changed
  views, or remaining items are recorded with a reason.

## Source

Adapted for SDD from the open-source `addyosmani/agent-skills`
`frontend-ui-engineering` skill and `accessibility-checklist` reference.
