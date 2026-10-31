# CLAUDE.md

Treat `AGENTS.md` as the canonical shared instructions.

Use these skills in order for this lite project:

- `/sdd-lite:lite-spec`
- `/sdd-implementation:implement-task` after human approval
- `/sdd-lite:lite-gate`
- `/sdd-quality-loop:fix-by-review-ticket` for approved fixes

Read the target requirements, design, and tasks before changing code. Read
additional contracts, ADRs, and review tickets when present. Preserve unrelated
changes and do not perform external Git operations unless explicitly requested.
