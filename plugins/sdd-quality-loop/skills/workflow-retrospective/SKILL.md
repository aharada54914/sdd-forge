---
name: workflow-retrospective
description: Measure how the SDD workflow itself performed (rework cycles, blocked tasks, review tickets, quality-gate failures) and propose human-approved improvements to project workflow files.
disable-model-invocation: true
user-invocable: false
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
- `reports/spec-review/` — spec-review-contract.json files for each feature
- `reports/task-review/` — task-review-contract.json files for each feature
- `reports/impl-review/` — impl-review-contract.json files for each feature
- previous `reports/retrospective/*.md` — comparison baseline and prior WFI
  verification results
- `reports/runs/RUN-*.json` — machine-readable run records from prior runs
  (attribution baseline for WFI verification)
- `docs/workflow-improvements/WFI-*.md` — Applied WFIs with open verification
  horizons
- `docs/workflow-improvements/retention-checklist.md` — recurrence conditions
  for previously Verified WFIs

For each task derive:

- **QG Cycles** — count of quality-gate reports for that task
- **Task Attempts — read `Task Attempt Count`** from the latest
  current-schema implementation report for the task.
- **Review Rounds — count independent review rounds** recorded for the task
  across its implementation and review evidence.
- **Quality-Gate Runs — count quality-gate reports** for the task, including
  failed and blocked runs rather than only the final passing run.
- **Model Escalations — count complete escalation transitions** whose prior
  tier, next tier, failure class, attempt number, and reason are all recorded.
- **Blocked Count** — count of `Blocked` decisions across those reports
- **Tickets** — count of review tickets by severity (`critical`, `major`, `minor`)
- **Auto-fixed** — count of tickets where `auto_fix_allowed: true` and
  `status: resolved`
- **Outcome** — final task status (`Done` or still open)

Legacy implementation reports without these additive fields contribute `N/A`;
do not infer or fabricate missing attempt, review-round, or escalation values.

### Deterministic artifact rules

Apply these rules before calculating the table. All paths below are canonical
repository-relative paths, and `<feature>` and `T-NNN` must exactly match the
requested feature and task:

1. **Implementation attempts.** The authoritative candidates are
   `reports/implementation/<feature>/T-NNN.md` and
   `reports/implementation/<feature>/T-NNN-attempt-<positive integer>.md`.
   The report heading task ID and its `Run ID` must agree with the path and be
   non-empty. De-duplicate candidates with the same `(task ID, Run ID)` by
   retaining the lexicographically smallest canonical path. Select the current
   task report by the greatest numeric `Task Attempt Count`; break a tie by the
   lexicographically greatest `Run ID`, then the lexicographically smallest
   canonical path. The selected report supplies the cumulative Task Attempts
   value. Schema-less legacy candidates sort below current-schema candidates
   and contribute `N/A` only when no current-schema candidate remains.
2. **Independent review rounds.** The authoritative artifacts are
   `reports/implementation/<feature>/T-NNN-review-<positive integer>.md`.
   Associate by the path task ID and require the report's `Task` identity to
   match. The suffix is the round number. De-duplicate on
   `(task ID, round number)` by retaining the lexicographically smallest
   canonical path, then count the retained rounds in numeric round order.
3. **Quality-gate runs.** The authoritative artifacts are Markdown files under
   `reports/quality-gate/` with exactly one `Task: T-NNN` identity and one
   non-empty `Run ID`. Associate only by that exact task identity.
   De-duplicate on `(task ID, Run ID)` by retaining the lexicographically
   smallest canonical path. Count retained reports, including PASS, FAIL, and
   BLOCKED, ordered by `Run ID` and then canonical path.
4. **Model escalations.** Read complete transition records from the retained
   implementation, independent-review, and quality-gate artifacts. Associate
   each record with the artifact's validated task identity. De-duplicate the
   same transition across evidence sources on
   `(task ID, escalation attempt number, prior tier, next tier, failure class)`.
   Retain the record from the lexicographically smallest canonical path and
   order by numeric escalation attempt, prior tier, next tier, failure class,
   then path. Conflicting reasons for one de-duplication key make Data
   Completeness `Blocked`; do not choose or count either conflicting record.
5. **Invalid or ambiguous evidence.** A candidate with a mismatched identity,
   malformed positive integer, duplicate identity with conflicting metric
   values, or missing required association field is excluded and recorded in
   the report's data-completeness explanation. Such evidence must never be
   repaired from filenames, timestamps, chat history, or filesystem iteration
   order.

Also derive dataset quality indicators:

- **Sample Size** — number of tasks, review contracts, quality-gate reports, and
  review tickets used.
- **Data Completeness** — Complete when all expected report roots exist for the
  feature; Partial when an optional source is missing; Blocked when required task
  or quality-gate evidence is absent.
- **Confidence** — High for recurring patterns across at least three tasks or
  two independent evidence types; Medium for recurring patterns across two
  tasks; Low for single-task observations. Low-confidence observations may be
  reported but must not create a WFI.

### Domain-drift metrics (when `domain/` exists)

When the project carries a `domain/` directory, extend the metric roll-up
with domain-drift counts sourced only from `check-domain-conformance`
findings already recorded in `reports/quality-gate/*.md` (the retained
reports selected by rule 3 above). Do not re-run `check-domain-conformance`
and do not read `domain/` artifacts directly — this is a read-only rollup
over already-recorded quality-gate text, not a new evidence-collection path.
When `domain/` is absent, skip this subsection entirely and omit the Domain
Drift Metrics table from the report (do not emit a zero-filled table).

1. Within each retained quality-gate report's text, locate every
   `check-domain-conformance WARN (<n> finding(s)):` or
   `check-domain-conformance FAILED (<n> finding(s)):` block (the exact
   output format produced by
   `plugins/sdd-quality-loop/scripts/check-domain-conformance.{sh,ps1}`) and
   collect its `- <finding text>` lines.
2. Classify each finding line by matching its text against the fixed set of
   messages the script can produce:
   - **Term deviation** — lines matching `unrecognized term '...'`, or
     `aggregate reference '...' not found in domain-contract.json
     aggregates`, or `aggregate reference '...' has no domain/aggregates/
     ....md card`. These all report a name/vocabulary the domain contract
     does not recognize.
   - **Boundary violation** — lines matching `Bounded-Context '...' not
     found in domain-contract.json`, or `Bounded-Context lists two contexts
     (...) with no declared relation in context map`. These report an
     undeclared context or an undeclared cross-context relation (AC-015).
   - A line matching neither pattern (e.g. a `requirements.md not found: ...`
     / `design.md not found: ...` input error) is not a drift finding; do not
     count it in either bucket.
3. **Term-Deviation Count** — total term-deviation finding lines across all
   retained quality-gate reports for the feature in this period.
4. **Boundary-Violation Count** — total boundary-violation finding lines
   across the same reports.
5. **Domain-Drift Trend** — compare this period's combined
   (Term-Deviation Count + Boundary-Violation Count) against the previous
   retrospective's combined total (from its Domain Drift Metrics table, when
   one exists). Report `N/A` when no previous retrospective recorded this
   metric. A sustained increase across two or more consecutive retrospectives
   is a friction pattern candidate under the Improvement Loop (Section 1),
   subject to the same two-task recurrence and confidence rules as any other
   friction pattern — never draft a WFI from a single period's counts alone.

De-duplicate on the same `(task ID, Run ID)` quality-gate report selection
already established in rule 3 of the Deterministic artifact rules above; a
report excluded there (e.g. a duplicate `Run ID`) does not contribute
domain-drift findings either.

For spec-review, task-review, and impl-review metrics, scan the contract files
and derive:

- **spec_review_rounds_per_feature** — for each feature, the round number of the
  final passing spec-review-contract.json (rounds consumed to reach PASS).
  If no PASS contract exists, record the maximum round reached.
- **spec_review_blocked_rate** — percentage of features where the
  spec-review-loop reached BLOCKED state (verdict == BLOCKED in the final
  attempt's last round).

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

## Applied-WFI Verification (horizon and retention)

Run these two checks on every retrospective, before drafting any new WFI.
They are what makes self-improvement measurable instead of impressionistic:
never classify a WFI from the feeling that "the run went smoother" — only from
run records and report counts.

**Horizon check.** For every WFI with `Status: Applied`:

1. Read its `Verification Metric` block (`Target-Metric`, `Expected-Direction`,
   `Horizon`, `Baseline`, `Target`).
2. Compare the baseline against the current run records (`reports/runs/`) and
   this retrospective's metrics. Report counts, not percentages, when fewer
   than 20 runs exist.
3. Classify:
   - Target met → set `Status: Verified`, append the comparison to `## Result`,
     and add the WFI's recurrence condition to
     `docs/workflow-improvements/retention-checklist.md`.
   - Direction improved, target unmet, horizon still open → leave Applied and
     record `Needs-Followup` in `## Result`.
   - Horizon expired without the target being met, or the metric worsened →
     set `Status: Rejected`, append the evidence to `## Result`, and present
     the WFI's `Rollback-Plan` to the human for approval. Do not execute the
     rollback without human approval.

**Retention check.** Read `docs/workflow-improvements/retention-checklist.md`
(if absent, skip and note that in the report). For each entry, check whether the
recurrence condition matches any evidence in this period. On recurrence:
set the source WFI's `Status: Regressed`, record the evidence in its
`## Result`, remove the checklist entry, and treat the recurrence as a friction
pattern candidate for a follow-up WFI. Retention answers the question most
loops forget: do previously fixed failure modes stay fixed?

Before crediting or blaming any WFI, read the transcripts or reports behind the
changed metric: grading artifacts can masquerade as effects.

## Output

Generate `reports/retrospective/<timestamp>.md` using the structure below.
Fill every section; do not leave any `{{}}` field blank.

```markdown
# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | {{feature}} |
| Period | {{period_start}} – {{period_end}} |
| Generated | {{generated_timestamp}} |
| Sample Size | {{task_count}} tasks, {{review_contract_count}} review contracts, {{qg_report_count}} QG reports, {{ticket_count}} tickets |
| Data Completeness | {{complete_partial_blocked}} |
| Confidence | {{high_medium_low_with_reason}} |

## Metrics

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| {{task_id}} | {{task_attempts}} | {{review_rounds}} | {{quality_gate_runs}} | {{model_escalations}} | {{blocked_count}} | {{critical}}/{{major}}/{{minor}} | {{outcome}} |
| **Total** | | | | | | | |

_C = Critical, M = Major, Min = Minor_

## Domain Drift Metrics

_Include this section only when `domain/` exists; omit entirely otherwise._

| Metric | This Period | Previous Period | Trend |
|---|---|---|---|
| Term-Deviation Count | {{term_deviation_count}} | {{prev_term_deviation_count}} | {{trend}} |
| Boundary-Violation Count | {{boundary_violation_count}} | {{prev_boundary_violation_count}} | {{trend}} |
| Combined Domain-Drift Count | {{combined_drift_count}} | {{prev_combined_drift_count}} | {{trend}} |

Counts are sourced only from `check-domain-conformance` findings already
recorded in the retained `reports/quality-gate/*.md` reports for this
feature; see the Domain-drift metrics rules above. A sustained increase
across two or more consecutive retrospectives is a friction-pattern
candidate (see Friction Patterns / Improvement Loop below), not an automatic
WFI trigger.

## Friction Patterns

Patterns observed across two or more tasks in this period.

### {{pattern_id}}: {{pattern_title}}

- **Evidence:** {{affected_tasks_and_ticket_ids}}
- **Frequency:** {{occurrence_count}} occurrences
- **Phase:** {{workflow_phase}}
- **Confidence:** {{high_medium_low}}
- **Do Not Overfit:** {{why_this_is_not_a_single_task_exception}}

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| {{wfi_id}} | Draft | {{problem_summary}} | {{target_files}} |

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| {{wfi_id}} | {{metric}} | {{baseline}} | {{target}} | {{next_feature_or_date}} |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| {{feature}} | {{spec_review_rounds}} | {{spec_review_verdict}} | {{task_review_rounds}} | {{task_review_verdict}} | {{impl_review_rounds}} | {{impl_review_verdict}} | {{legacy_design}} |

## Comparison With Previous Retrospective

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | {{prev_avg_qg}} | {{curr_avg_qg}} | {{trend}} |
| Avg Task Attempts | {{prev_task_attempts}} | {{curr_task_attempts}} | {{trend}} |
| Avg Review Rounds | {{prev_review_rounds}} | {{curr_review_rounds}} | {{trend}} |
| Avg Quality-Gate Runs | {{prev_quality_gate_runs}} | {{curr_quality_gate_runs}} | {{trend}} |
| Total Model Escalations | {{prev_model_escalations}} | {{curr_model_escalations}} | {{trend}} |
| Total Blocked Count | {{prev_blocked}} | {{curr_blocked}} | {{trend}} |
| Total Review Tickets | {{prev_tickets}} | {{curr_tickets}} | {{trend}} |
| Auto-fix Rate | {{prev_autofix_pct}} | {{curr_autofix_pct}} | {{trend}} |
| Avg Spec Review Rounds | {{prev_spec_review_rounds}} | {{curr_spec_review_rounds}} | {{trend}} |
| Spec Review Blocked Rate | {{prev_spec_review_blocked}} | {{curr_spec_review_blocked}} | {{trend}} |
| Avg Task Review Rounds | {{prev_task_review_rounds}} | {{curr_task_review_rounds}} | {{trend}} |
| Task Review Blocked Rate | {{prev_task_review_blocked}} | {{curr_task_review_blocked}} | {{trend}} |
| Avg Impl Review Rounds | {{prev_impl_review_rounds}} | {{curr_impl_review_rounds}} | {{trend}} |
| Impl Review Blocked Rate | {{prev_impl_review_blocked}} | {{curr_impl_review_blocked}} | {{trend}} |
| Impl Legacy Design Rate | {{prev_legacy_design_rate}} | {{curr_legacy_design_rate}} | {{trend}} |
| Repeat Finding Rate | {{prev_repeat_finding_rate}} | {{curr_repeat_finding_rate}} | {{trend}} |
| WFI Verification Rate | {{prev_wfi_verification_rate}} | {{curr_wfi_verification_rate}} | {{trend}} |

_If no previous retrospective exists, mark all "Previous" cells as N/A._

## Applied WFI Horizon Check

| WFI-ID | Target-Metric | Baseline | Target | Current | Horizon | Classification |
|---|---|---|---|---|---|---|
| {{wfi_id}} | {{target_metric}} | {{baseline}} | {{target}} | {{current}} | {{horizon}} | {{verified_needs_followup_rejected}} |

_List every WFI that was `Status: Applied` at the start of this retrospective.
If none, state "No applied WFIs with open horizons."_

## Retention Check

| Source WFI | Recurrence Condition | Recurred? | Evidence |
|---|---|---|---|
| {{wfi_id}} | {{condition}} | {{yes_no}} | {{evidence_or_dash}} |

_One row per entry in retention-checklist.md. If the checklist is absent or
empty, state that explicitly._
```

## Run Record (machine-readable)

After writing the retrospective report, emit the machine-readable run record:

```
scripts/emit-run-record.sh <feature> --track <full|lite> \
  --model-main <model id used for implementation> \
  --model-reviewers <model id used for review agents> \
  --plugin-version <installed sdd plugin version>
```

(or `emit-run-record.ps1` with the equivalent named parameters; if the project
has no `scripts/` copy, run it from the installed sdd-quality-loop plugin's
`scripts/` directory).

The script deterministically counts tasks, first-try gate passes, gate reports,
blocked reports, and review tickets, and records the currently Applied WFIs —
do not compute these numbers yourself and do not edit the emitted JSON. Pass
the model ids and track as arguments; they are per-run confound metadata that
future attribution analysis cannot recover after the fact. If a model version
changed since the previous run record, note that in the retrospective report:
metric shifts across a model change must not be attributed to WFIs.

## Improvement Loop

1. **Identify friction.** Flag patterns that recur across at least two tasks:
   - Same `type` of review ticket appears repeatedly.
   - A phase produces `Blocked` more than once.
   - Auto-fix rate drops below 50 % for a ticket type.
   - A prior WFI's expected-effect metric does not improve by its next
     checkpoint.

   Do not draft a WFI from a single-task observation. Record it under Friction
   Patterns with Low confidence only when it may become relevant later.

1.5. **Classify the WFI.** Before drafting, walk the Section 1 flowchart of
   `plugins/sdd-quality-loop/references/wfi-category-guide.md` to set the
   scope axis (`Category`), then set the mechanism axis (`Mechanism`) from
   Section 5:

   - **`measurement`** (checked first): the change touches graders, gate
     thresholds, retrospective/audit logic, or run-record definitions. Forces
     `Meta-Change: true` and the strict audit lane (category guide Section 5).
   - **`human-process`**: the change alters approval policy, escalation rules,
     or what humans review.
   - **`plugin-improvement`**: friction evidence comes from the "Review Gate
     Metrics" table (`spec_review_rounds`, `spec_review_blocked_rate`,
     `impl_review_rounds`, `task_review_blocked_rate`,
     `impl_review_blocked_rate`, `impl_review_legacy_design_rate`) or involves
     cross-plugin handoff transitions (design review → task decomposition →
     implementation flow). These WFIs are expressed in generic workflow terms
     (see Section 2 of the category guide) and will be tracked as GitHub Issues.
   - **`app-dev-efficiency`**: all other friction patterns (task sizing, test
     coverage gaps, spec quality, project-specific recurring ticket types). These
     WFIs use project-specific concrete language (feature slugs, task IDs, RT-IDs).

   `Mechanism` is one of `instructions | memory | tools | architecture |
   model-routing`. Set `Meta-Change: true` whenever the proposed change touches
   anything that measures the workflow, regardless of Category.

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

   <!-- Allowed values: Draft | Approved | Applied | Verified | Rejected | Regressed -->
   <!-- Only a human may set status to Approved. The AI sets Draft, Applied,        -->
   <!-- Verified, Rejected, and Regressed.                                           -->

   ## Category

   Category: {{plugin-improvement|app-dev-efficiency|human-process|measurement}}

   <!-- Scope axis — walk wfi-category-guide.md §1 flowchart.                        -->
   <!-- plugin-improvement: use generic workflow terms (wfi-category-guide.md §2). -->
   <!-- app-dev-efficiency: use project-specific detail (feature slug, task IDs).   -->
   <!-- measurement: forces Meta-Change: true (strict audit lane, guide §5).        -->

   ## Mechanism

   Mechanism: {{instructions|memory|tools|architecture|model-routing}}

   <!-- Mechanism axis — what kind of thing changes (wfi-category-guide.md §5). -->

   ## Meta-Change

   Meta-Change: {{true|false}}

   <!-- true when the change touches graders, thresholds, retrospective/audit     -->
   <!-- logic, or run-record definitions (wfi-category-guide.md §5).              -->

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

   ## Verification Metric

   Target-Metric: {{run_record_metric_key}}
   Expected-Direction: {{increase|decrease}}
   Horizon: {{within_next_N_runs_or_date}}
   Baseline: {{baseline_count}}
   Target: {{target_count}}

   <!-- Target-Metric names one run-record key (reports/runs/RUN-*.json) or a       -->
   <!-- retrospective table column. Horizon is binding: expiry without the target    -->
   <!-- met → Status: Rejected + rollback proposal. Use counts, not percentages.     -->

   ## Verification Plan

   {{verification_plan}}

   <!-- Describe how the next task cycle will confirm the improvement. -->
   <!-- Reference the specific metric rows from the retrospective template. -->

   ## Rollback-Plan

   {{rollback_plan}}

   <!-- Exact files/sections changed and how to revert (normally: git revert of  -->
   <!-- the commit whose message contains this WFI-ID). Required before Approved. -->

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
   without the marker lose that protection. The WFI-ID-in-commit rule is also
   what makes the `Rollback-Plan` executable: reverting the WFI is reverting
   that commit.

   **Adoption hygiene (attribution discipline):** apply at most one WFI (or one
   explicitly labeled batch) per verification window, and never mid-run.
   Simultaneous unlabeled adoptions make it impossible to attribute a metric
   shift to any single change.

5. **Verify effect.** After the next task cycle completes, re-run metrics
   collection (the Applied-WFI Verification section above) and append a
   `Result` section to the WFI document. Compare the `Verification Metric`
   baseline and target with the current run records. Classify the result as:
   - `Verified`: target met without introducing a worse repeated friction.
     Register the recurrence condition in
     `docs/workflow-improvements/retention-checklist.md`.
   - `Needs-Followup`: direction improved but target was not met and the
     horizon is still open.
   - `Rejected`: metric worsened, the horizon expired without the target, or
     the proposal caused a new repeated failure. Present the `Rollback-Plan`
     to the human.
   - `Regressed` (set by the retention check, possibly many cycles later): a
     previously Verified WFI's failure mode recurred.

   This mirrors continuous eval practice: keep the successful regression signal,
   promote recurring misses into new WFI candidates, and avoid reactive changes
   from one-off failures. A model-version change between baseline and
   checkpoint invalidates the comparison — note it and extend the horizon
   instead of classifying.

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
