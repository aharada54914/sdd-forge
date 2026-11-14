# CLAUDE.md

Treat `AGENTS.md` as the canonical shared instructions.

Use these skills in order:

- `/sdd-bootstrap:sdd-bootstrap-interviewer`
- `/sdd-implementation:implement-task`
- `/sdd-quality-loop:quality-gate`
- `/sdd-quality-loop:fix-by-review-ticket`

Read the target feature requirements, design, tasks, acceptance tests,
traceability, contracts, and ADRs before changing code. Preserve unrelated
changes and do not perform external Git operations unless explicitly requested.
