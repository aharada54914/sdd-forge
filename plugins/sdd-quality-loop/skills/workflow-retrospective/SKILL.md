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

Generate `reports/retrospective/<timestamp>.md` using the structure below.
Fill every section; do not leave placeholders unfilled.

```markdown
# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | {{feature}} |
| Period | {{period_start}} – {{period_end}} |
| Generated | {{generated_timestamp}} |

## Metrics

| Task | QG Cycles | Blocked Count | Tickets (C/M/Min) | Auto-fixed | Outcome |
|---|---|---|---|---|---|
| {{task_id}} | {{qg_cycles}} | {{blocked_count}} | {{critical}}/{{major}}/{{minor}} | {{auto_fixed}} | {{outcome}} |
| **Total** | | | | | |

_C = Critical, M = Major, Min = Minor_

## Friction Patterns

Patterns observed across two or more tasks in this period.

### {{pattern_id}}: {{pattern_title}}

- **Evidence:** {{affected_tasks_and_ticket_ids}}
- **Frequency:** {{occurrence_count}} occurrences
- **Phase:** {{workflow_phase}}

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| {{wfi_id}} | Draft | {{problem_summary}} | {{target_files}} |

## Comparison With Previous Retrospective

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | {{prev_avg_qg}} | {{curr_avg_qg}} | {{trend}} |
| Total Blocked Count | {{prev_blocked}} | {{curr_blocked}} | {{trend}} |
| Total Review Tickets | {{prev_tickets}} | {{curr_tickets}} | {{trend}} |
| Auto-fix Rate | {{prev_autofix_pct}} | {{curr_autofix_pct}} | {{trend}} |

_If no previous retrospective exists, mark all "Previous" cells as N/A._
```

## Improvement Loop

1. **Identify friction.** Flag patterns that recur across at least two tasks:
   - Same `type` of review ticket appears repeatedly.
   - A phase produces `Blocked` more than once.
   - Auto-fix rate drops below 50 % for a ticket type.

2. **Draft a WFI.** For each identified friction, create
   `docs/workflow-improvements/WFI-NNN.md` with `Status: Draft` using the
   structure below. Increment NNN from the highest existing WFI number (start
   at 001 if none exist). If the repository also runs an automated
   self-improvement routine (e.g. it has `.github/self-improvement-prompt.md`),
   check open issues labeled `self-improvement` first; if one covers the same
   theme, reference its issue number in the WFI instead of duplicating the work.

   ```markdown
   # Workflow Improvement

   ## WFI-ID

   {{wfi_id}}

   ## Status

   Status: Draft

   <!-- Allowed values: Draft | Approved | Applied | Verified | Rejected -->
   <!-- Only a human may set status to Approved. The AI sets Draft, Applied, and Verified. -->

   ## Problem Evidence

   {{metrics_and_ticket_references}}

   <!-- Quote specific BL-IDs, RT-IDs, or retrospective table rows that show the friction. -->

   ## Root Cause Hypothesis

   {{root_cause}}

   ## Proposed Change

   | Target File | Change Description |
   |---|---|
   | {{file_path}} | {{change_description}} |

   <!-- Target files must be project-side workflow files only (AGENTS.md, CLAUDE.md,    -->
   <!-- specs/ templates, task-splitting guidelines). Plugin files must not be listed.  -->

   ## Expected Effect

   {{expected_effect}}

   <!-- State the metric(s) expected to improve and by how much. -->

   ## Verification Plan

   {{verification_plan}}

   <!-- Describe how the next task cycle will confirm the improvement. -->
   <!-- Reference the specific metric rows from the retrospective template. -->

   ## Result

   Pending

   <!-- Fill after the next task cycle completes. Append a comparison table. -->
   ```

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
applying any improvement. The WFI records status as an inline `Status: <value>`
field; a hook guard denies any agent edit introducing `Status: Approved` in a
`docs/workflow-improvements/WFI-*.md` file, and is never bypassed by sudo.
Read-only metrics collection runs as normal. See
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`.

## Boundaries

- Do not modify application code.
- Do not change task status fields.
- Do not commit or push unless the human explicitly requests it.
- Do not create, resolve, or modify review tickets.
- Do not invoke `quality-gate` or `fix-by-review-ticket`.
