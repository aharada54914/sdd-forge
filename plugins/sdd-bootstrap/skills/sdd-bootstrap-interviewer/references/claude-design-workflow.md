# Optional Claude Design Workflow

This is a manual documentation aid for full-profile work, and the fallback
procedure the internal `design-sync-loop` skill uses when the DesignSync tool
is unavailable. Mermaid is the primary and canonical diagram format. PNG
mockups and HTML previews are optional attachments; their absence never blocks
specification review.

## Boundaries

- This workflow does not call a Figma API or provide bidirectional Figma sync.
- It does not automatically inspect, upload, or retain images.
- It does not replace accessibility review, acceptance tests, or review gates.
- Treat attached mockups as potentially confidential and follow repository
  data-handling rules.
- Never overwrite an existing layer specification. Review proposed changes as
  a normal specification edit.

When no visual input is supplied, record:
`No mockup provided — optional visualization skipped`.

## Manual Steps

1. Finish the applicable UX answers and create `ux-spec.md`.
2. Keep Mermaid navigation and interaction diagrams as the source of truth.
3. Optionally attach a local mockup path and describe its provenance.
4. Use one prompt below to produce suggestions, not automatic edits.
5. Reconcile suggestions with REQ-NNN, AC-NNN, design tokens, breakpoints, and
   WCAG 2.2 AA.
6. If an HTML preview is useful, keep it disposable and outside canonical
   contracts; the Markdown layer specs remain authoritative.
7. Record accepted decisions and rejected suggestions in the relevant layer
   section.

## Copy-Ready Prompts

### Prompt 1

```text
Review this local UI mockup description against the supplied ux-spec.md.
Return a table of view/state mismatches, accessibility risks, responsive gaps,
and the affected REQ-NNN/AC-NNN identifiers. Do not invent requirements or edit
files. Mermaid source is canonical.
```

### Prompt 2

```text
Using the supplied ux-spec.md and frontend-spec.md, propose a component tree
and typed state shape. Preserve route, auth, error, performance, and bundle
budgets. Return Mermaid plus TypeScript suggestions and list every assumption
as an open question.
```

### Prompt 3

```text
Draft a disposable semantic HTML preview from the supplied layer specs.
Include keyboard/focus behavior, empty/loading/error states, responsive notes,
and no external assets. Identify any preview choice not traceable to REQ-NNN or
AC-NNN; do not treat the preview as a canonical artifact.
```

## Review Checklist

- Mermaid remains present and current.
- No new product decision was inferred from the mockup.
- Accessibility and responsive behavior have acceptance evidence.
- Existing files and hashes were preserved unless a reviewed edit was approved.
- Sensitive visual content was not copied to external systems without explicit
  human authorization.
