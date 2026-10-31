---
paths:
  - "docs/review-tickets/**"
  - "docs/specs/**/verification/**"
  - "specs/**/verification/**"
  - "reports/**"
---

# Review Ticket Conventions

Repository review-ticket YAML is the source of truth for unresolved quality findings.

Required fields: `ticket_id`, `status` (open/resolved/rejected), `type`,
`severity` (critical/major/minor), `target.feature`, `target.task`,
`target.files`, `summary`, `problem`, `expected_fix`, `references`,
`auto_fix_allowed`, `requires_human_decision`, `review_cycles`.

`fix-by-review-ticket` may fix only the requested scope. A resolved ticket
returns its task to `Implementation Complete`; only a subsequent `quality-gate`
may set the task to `Done`.
