# Accessibility Review Checklist

On-demand checklist for the critical reviewer and `quality-gate`. Load it only
when the change touches user-facing UI. Target: WCAG 2.2 AA. A change that makes
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
- Targets are at least 24×24 CSS px or have equivalent spacing (2.5.8 Target
  Size minimum); motion respects `prefers-reduced-motion`.
- Focus is not fully obscured by sticky headers, banners, or overlays when an
  element receives keyboard focus (2.4.11 Focus Not Obscured).
- Any dragging interaction offers a single-pointer alternative (2.5.7
  Dragging Movements).

## Understandable

- Form inputs have associated, programmatic labels; errors are announced and
  describe how to fix the problem.
- The page has a sensible heading hierarchy and a document language.
- Navigation and naming are consistent across the changed surface.
- Help mechanisms appear in a consistent location across pages (3.2.6
  Consistent Help).
- Information already entered in the same flow is auto-populated or
  selectable rather than demanded again (3.3.7 Redundant Entry).
- Authentication requires no cognitive function test (memorization,
  transcription, or puzzles); paste and password managers are allowed
  (3.3.8 Accessible Authentication minimum).

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
