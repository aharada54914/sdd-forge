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
- `reports/task-review/` — task-review-contract.json files for each feature
- `reports/impl-review/` — impl-review-contract.json files for each feature

For each task derive:

- **QG Cycles** — count of quality-gate reports for that task
- **Blocked Count** — count of `Blocked` decisions across those reports
- **Tickets** — count of review tickets by severity (`critical`, `major`, `minor`)
- **Auto-fixed** — count of tickets where `auto_fix_allowed: true` and
  `status: resolved`
- **Outcome** — final task status (`Done` or still open)

For task-review and impl-review metrics, scan the contract files and derive:

- **task_review_rounds_per_feature** — for each feature, the round number of the
  final passing task-review-contract.json (rounds consumed to reach PASS).
  If no PASS contract exists, record the maximum round reached.
- **task_review_blocked_rate** — percentage of features where the task-review-loop
  reached BLOCKED state (verdict == BLOCKED in the final attempt's last round).
- **impl_review_rounds_per_feature** — for each feature, the round number of the
  final passing impl-review-contract.json.
- **impl_review_blocked_rate** — percentage of features where the impl-review-loop
  reached BLOCKED state.
- **impl_review_legacy_design_rate** — percentage of features where
  `legacy_design: true` in at least one impl-review-contract.json.

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

## Spec Review Gate Metrics

| Feature | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|
| {{feature}} | {{task_review_rounds}} | {{task_review_verdict}} | {{impl_review_rounds}} | {{impl_review_verdict}} | {{legacy_design}} |

## Comparison With Previous Retrospective

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | {{prev_avg_qg}} | {{curr_avg_qg}} | {{trend}} |
| Total Blocked Count | {{prev_blocked}} | {{curr_blocked}} | {{trend}} |
| Total Review Tickets | {{prev_tickets}} | {{curr_tickets}} | {{trend}} |
| Auto-fix Rate | {{prev_autofix_pct}} | {{curr_autofix_pct}} | {{trend}} |
| Avg Task Review Rounds | {{prev_task_review_rounds}} | {{curr_task_review_rounds}} | {{trend}} |
| Task Review Blocked Rate | {{prev_task_review_blocked}} | {{curr_task_review_blocked}} | {{trend}} |
| Avg Impl Review Rounds | {{prev_impl_review_rounds}} | {{curr_impl_review_rounds}} | {{trend}} |
| Impl Review Blocked Rate | {{prev_impl_review_blocked}} | {{curr_impl_review_blocked}} | {{trend}} |
| Impl Legacy Design Rate | {{prev_legacy_design_rate}} | {{curr_legacy_design_rate}} | {{trend}} |

_If no previous retrospective exists, mark all "Previous" cells as N/A._
```

## Improvement Loop

1. **Identify friction.** Flag patterns that recur across at least two tasks:
   - Same `type` of review ticket appears repeatedly.
   - A phase produces `Blocked` more than once.
   - Auto-fix rate drops below 50 % for a ticket type.

1.5. **Classify the WFI.** Before drafting, determine the WFI category by reading
   `plugins/sdd-quality-loop/references/wfi-category-guide.md`:

   - **`plugin-improvement`**: friction evidence comes from the "Spec Review Gate
     Metrics" table (`impl_review_rounds`, `task_review_blocked_rate`,
     `impl_review_blocked_rate`, `impl_review_legacy_design_rate`) or involves
     cross-plugin handoff transitions (design review → task decomposition →
     implementation flow). These WFIs are expressed in generic workflow terms
     (see Section 2 of the category guide) and will be tracked as GitHub Issues.
   - **`app-dev-efficiency`**: all other friction patterns (task sizing, test
     coverage gaps, spec quality, project-specific recurring ticket types). These
     WFIs use project-specific concrete language (feature slugs, task IDs, RT-IDs).

   For `plugin-improvement` WFIs: read Section 2 of `wfi-category-guide.md` and
   apply all term substitutions to Root Cause Hypothesis, Proposed Change, and
   Expected Effect. Problem Evidence may cite raw metric names from the retrospective.

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

   ## Category

   Category: {{plugin-improvement|app-dev-efficiency}}

   <!-- plugin-improvement: use generic workflow terms (wfi-category-guide.md §2). -->
   <!-- app-dev-efficiency: use project-specific detail (feature slug, task IDs).   -->

   ## GitHub-Issue

   GitHub-Issue: {{N/A for app-dev-efficiency | Pending for plugin-improvement}}

   <!-- Populated by wfi-audit-cycle after gh issue create (plugin-improvement only). -->

   ## Audit-Status

   Audit-Status: Not-Started

   <!-- wfi-audit-cycle advances this through Cycle-1-In-Progress →              -->
   <!-- Cycle-2-In-Progress → Human-Pending before human review.                  -->

   ## Problem Evidence

   {{metrics_and_ticket_references}}

   <!-- Quote specific BL-IDs, RT-IDs, or retrospective table rows that show the friction. -->
   <!-- For plugin-improvement: raw metric field names are acceptable here.        -->

   ## Root Cause Hypothesis

   {{root_cause}}

   <!-- plugin-improvement: use generic workflow terms only (wfi-category-guide.md §2). -->
   <!-- app-dev-efficiency: name the specific feature/task/ticket driving the issue. -->

   ## Proposed Change

   | Target File | Change Description |
   |---|---|
   | {{file_path}} | {{change_description}} |

   <!-- Target files must be project-side workflow files only (AGENTS.md, CLAUDE.md,    -->
   <!-- specs/ templates, task-splitting guidelines). Plugin files must not be listed.  -->

   ## Expected Effect

   {{expected_effect}}

   <!-- State the metric(s) expected to improve and by how much.                       -->
   <!-- plugin-improvement: use generic metric names from wfi-category-guide.md §2.   -->
   <!-- app-dev-efficiency: use project-specific metric names with concrete targets.   -->

   ## Verification Plan

   {{verification_plan}}

   <!-- Describe how the next task cycle will confirm the improvement. -->
   <!-- Reference the specific metric rows from the retrospective template. -->

   ## Result

   Pending

   <!-- Fill after the next task cycle completes. Append a comparison table. -->
   ```

2.5. **Trigger audit cycle.** Immediately after creating the WFI Draft, invoke
   the `wfi-audit-cycle` skill for every new WFI regardless of category:

   Claude Code:
   ```
   /sdd-quality-loop:wfi-audit-cycle WFI-NNN
   ```
   Codex:
   ```
   Use the wfi-audit-cycle skill for WFI-NNN
   ```

   The audit cycle runs 2 independent review cycles (Cycle 1: proposal quality;
   Cycle 2: impact and risk), revises the WFI between cycles, and sets
   `Audit-Status: Human-Pending` when complete.

   For `plugin-improvement` WFIs, `wfi-audit-cycle` also creates a GitHub Issue
   after both cycles complete.

   Record the WFI in the retrospective report under "Proposed Improvements" only
   after the audit cycle completes (i.e., after `Audit-Status: Human-Pending` is
   set). Use these status labels in the table:

   | Category | Status label in table |
   |---|---|
   | `plugin-improvement` | `Human-Pending (audited, issue created)` |
   | `app-dev-efficiency` | `Human-Pending (audited)` |

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
