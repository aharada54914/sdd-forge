---
name: fix-by-review-ticket
description: Apply only a human-approved repository review-ticket YAML fix, run scoped checks, and return the task to Implementation Complete for another quality gate.
disable-model-invocation: true
---

# Fix By Review Ticket

Use this skill for one review ticket under `docs/review-tickets/`.

## Process

1. Read the ticket and its referenced task, specification, code, and tests.
2. Stop when `requires_human_decision: true`, the target is unclear, or the
   requested change exceeds the ticket.
3. Apply the smallest fix described by the ticket.
4. Add or update required tests and run scoped checks.
5. Mark the ticket `resolved` only when the requested fix and tests succeed.
6. Return the task to `Implementation Complete`.
7. Run `quality-gate` again before the task can become `Done`.

Do not make unrelated improvements, silently change requirements, or perform
breaking changes. Do not commit, push, or create a PR/MR unless explicitly requested.
