# Review Ticket Rules

Repository review-ticket YAML is the source of truth for unresolved quality findings.

Required fields:

- `ticket_id`
- `status`: `open`, `resolved`, or `rejected`
- `type`
- `severity`: `critical`, `major`, or `minor`
- `target.feature`, `target.task`, and `target.files`
- `summary`
- `problem`
- `expected_fix`
- `references`
- `auto_fix_allowed`
- `requires_human_decision`
- `review_cycles`

`fix-by-review-ticket` may fix only the requested scope. A resolved ticket
returns its task to `Implementation Complete`; only a subsequent `quality-gate`
may set the task to `Done`.
