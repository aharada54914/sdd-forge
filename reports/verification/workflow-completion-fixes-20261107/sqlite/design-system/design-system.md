# Design System: SQLite Task Board

Version: 0.1.0
Profile: custom
Status: Approved

## Tokens
design-tokens.json is authoritative. White background, blue primary, dark text, Japanese sans fallback, 16px base, 4/8/16/24/40px spacing and standard radii. Use its DTCG values to generate local CSS variables in design-system/build/tokens.css. Raw values belong in token source or generated output.

## Components
New TaskForm, TaskList and TaskRow support the single page. Native labels/inputs/checkboxes and visible Japanese text buttons keep keyboard and assistive technology behavior predictable. Exactly one primary action, 追加. Separate destructive 削除 with Japanese confirmation. No decorative sidebar/filters from the supplied reference.

## Review Checklist
- Tokens consumed consistently; no external font/network assets.
- White/blue Japanese page reflows without overflow at mobile/desktop widths.
- Named controls, visible focus, readable contrast and 44px action targets.
- Empty/loading/error/success and focus recovery verified in real browser.

## Approval and Changes
Approved by parent as an explicit disposable-test fixture under the user’s prior test authorization; not normal human production approval. Reviewed token/rule changes bump both document and meta.version. ImageGen reference is illustrative; requirements remain canonical.
