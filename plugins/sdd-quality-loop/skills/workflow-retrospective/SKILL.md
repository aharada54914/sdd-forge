---
name: workflow-retrospective
description: Measure how the SDD workflow itself performed (rework cycles, blocked tasks, review tickets, quality-gate failures) and propose human-approved improvements to project workflow files.
disable-model-invocation: true
---

# Workflow Retrospective

Observe and improve the SDD workflow process itself, not the application code.

## Invocation

Codex:
```
Use the workflow-retrospective skill for specs/<feature>
```

Claude Code:
```
/sdd-quality-loop:workflow-retrospective specs/<feature>
```

## Metrics Collection (read-only)

Read the following sources; do not modify them:

- `reports/implementation/` — one report per task cycle
- `reports/quality-gate/` — one report per quality-gate run
- `docs/review-tickets/` — all YAML tickets for the feature
- `git log --oneline` — commit history scoped to the feature path

For each task derive:

- **QG Cycles** — count of quality-gate reports for that task
- **Blocked Count** — count of `Blocked` decisions across those reports
- **Tickets** — count of review tickets by severity (`critical`, `major`, `minor`)
- **Auto-fixed** — count of tickets where `auto_fix_allowed: true` and
  `status: resolved`
- **Outcome** — final task status (`Done` or still open)

## Output

Generate `reports/retrospective/<timestamp>.md` from
`templates/retrospective-report.template.md`.  Fill every section; do not
leave template placeholders unfilled.

## Improvement Loop

1. **Identify friction.** Flag patterns that recur across at least two tasks:
   - Same `type` of review ticket appears repeatedly.
   - A phase produces `Blocked` more than once.
   - Auto-fix rate drops below 50 % for a ticket type.

2. **Draft a WFI.** For each identified friction, create
   `docs/workflow-improvements/WFI-NNN.md` from
   `templates/workflow-improvement.template.md` with `status: Draft`.
   Increment NNN from the highest existing WFI number (start at 001 if none
   exist).  If the repository also runs an automated self-improvement routine
   (e.g. it has `.github/self-improvement-prompt.md`), check open issues
   labeled `self-improvement` first; if one covers the same theme, reference
   its issue number in the WFI instead of duplicating the work.

3. **Await human Approved.** Do not apply any improvement until a human sets
   the WFI `status` to `Approved`.  Record the pending WFI references in the
   retrospective report under "Proposed Improvements".

4. **Apply approved improvements.** Modify only project-side workflow files:
   - `AGENTS.md` or `CLAUDE.md` in the project root
   - `specs/` template files or task-splitting guidelines
   - Task granularity guidance documents

   Do not modify installed plugin files (skills, references, templates inside
   `plugins/`).

   Always include the WFI ID (`WFI-NNN`) in the commit message and any PR that
   applies an approved improvement.  Automated maintenance routines treat
   `WFI-`-referenced changes as protected and will not revert them; changes
   without the marker lose that protection.

5. **Verify effect.** After the next task cycle completes, re-run metrics
   collection and append a `Result` section to the WFI document.  Compare with
   the previous retrospective to confirm the friction decreased.

## Sudo Mode

A valid `SDD_SUDO` flag does **not** bypass WFI approval. Setting a WFI `status`
to `Approved` changes the SDD workflow itself (governance), so it remains a
human-only action even under sudo: continue to await human `Approved` before
applying any improvement. Read-only metrics collection runs as normal. See
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`.

## Boundaries

- Do not modify application code.
- Do not change task status fields.
- Do not commit or push unless the human explicitly requests it.
- Do not create, resolve, or modify review tickets.
- Do not invoke `quality-gate` or `fix-by-review-ticket`.
