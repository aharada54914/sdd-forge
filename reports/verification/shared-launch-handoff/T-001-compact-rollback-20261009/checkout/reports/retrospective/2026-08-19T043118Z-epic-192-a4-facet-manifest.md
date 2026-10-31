# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | `epic-192-a4-facet-manifest` (Pillar A / A4), merged to `main` as PR #301 |
| Period | 2026-08-16 – 2026-08-18 |
| Generated | 2026-08-19T04:31:18Z |
| Sample Size | 5 tasks, 5 review contracts (1 spec + 3 task + 1 impl), 5 quality-gate reports (**5 of 5 retained under artifact rule 3**), 6 review tickets |
| Data Completeness | **Partial** — every required report root exists and every one of the 5 implementation reports is current-schema with a `Task Attempt Count`. All 5 quality-gate reports satisfy rule 3's association requirement. The one gap is optional: no rule-2 independent-review artifact (`reports/implementation/<feature>/T-NNN-review-<n>.md`) exists for any task, so Review Rounds is structurally 0 rather than measured. See FP-03. |
| Confidence | **High** for FP-01 (4 of 5 tasks, deterministic in-file counts), FP-02 (6 of 6 tickets, and the same pattern in the previous period's 7 of 7), and FP-03 (0 of 5 tasks, plus the previous period recording the same metric as N/A). No single-task observation was promoted to a WFI. |

## Metrics

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| T-001 | 2 | 0 | 1 | 0 | 0 | 0/0/1 | Done |
| T-002 | 1 | 0 | 1 | 0 | 0 | 0/0/1 | Done |
| T-003 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-004 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-005 | 1 | 0 | 1 | 0 | 0 | 0/1/3 | Done |
| **Total** | **6** | **0** | **5** | **0** | **0** | **0/1/5** | **5 Done** |

_C = Critical, M = Major, Min = Minor_

Task Attempts come from each report's `Task Attempt Count` (rule 1); only T-001 exceeded one.
Model Escalations are 0 because every implementation report records `Escalation Prior Tier: none`
through `Escalation Reason: none` — a complete "no escalation" record, not missing data.
Blocked Count is 0: no gate report carries a Blocked decision, and all five decisions read
`VERDICT PASS with 0 Critical / 0 Major`.

**Quality-Gate Runs understates the work by roughly a factor of two.** Rule 3 counts *files*,
and this feature writes one file per task at a fixed path. The re-gate cycles live *inside*
those files as enumerated `- Cycle N — RUN-...` lines with distinct Run IDs:

| Task | Enumerated in-file cycles | Counted under rule 3 |
|---|---|---|
| T-001 | 3 | 1 |
| T-002 | 0 (passed first pass) | 1 |
| T-003 | 3 | 1 |
| T-004 | 2 | 1 |
| T-005 | 2 | 1 |
| **Total** | **10 enumerated + 1 first-pass** | **5** |

See FP-01.

## Friction Patterns

Patterns observed across two or more tasks in this period.

### FP-01: Re-gate cycles are recorded inside one file, so the metric that counts files cannot see them

- **Evidence:** T-001 (3 cycles), T-003 (3), T-004 (2), T-005 (2) — each collapsed to a single
  counted Quality-Gate Run. The distinct Run IDs exist (`...qg-T-001-seq0754`, `-seq0755`,
  `-seq0756`) but live as list items inside `reports/quality-gate/<feature>/T-NNN.md`, while
  rule 3 requires one file to carry exactly one `Task:` and one `Run ID`.
- **Corroboration, machine-generated and independent of this report:** the run record
  `reports/runs/RUN-20260819T043725Z-epic-192-a4-facet-manifest.json`, emitted by
  `emit-run-record.sh` — a script whose counts the skill forbids me to compute or edit —
  records `"first_pass_gate": {"passed_first_try": 5, "total": 5}` and
  `"gate_reports": {"total": 5, "max_runs_single_task": 1}`. Four of those five tasks needed
  two or three cycles. The deterministic instrument reports a perfect first-pass rate for a
  feature that had a 20 % first-pass rate.
- **Frequency:** 10 enumerated cycles across 4 tasks, reported as 4 runs.
- **Phase:** quality-gate / measurement.
- **Confidence:** High.
- **Do Not Overfit:** This is not a one-task filing accident. It affects every task that needed
  more than one cycle, and it compounds a defect the previous period already recorded from the
  other direction ("QG reports retained under rule 3: 0 of 21 — unchanged, 4th consecutive
  period"). The same metric has now lost signal in two independent ways. The consequence is not
  cosmetic: `ship`'s Step 4 cycle limit is documented as disk-based and computed by counting
  this task's gate report files, so a task that has burned three cycles inside one file still
  counts as one and never trips the Escalate-Human stop.

### FP-02: Review tickets are never closed after the feature ships

- **Evidence:** RT-20260817-001 … -006, all six `status: open`, on a feature whose five tasks
  are all `Done` and whose PR #301 merged on 2026-08-18. Five of the six carry
  `auto_fix_allowed: true`; none is `resolved`. Attribution: T-001 ×1, T-002 ×1, T-005 ×4.
- **Frequency:** 6 of 6 this period; 7 of 7 in the previous period (auto-fix rate 0 %).
  Two consecutive periods at 0 %.
- **Phase:** post-gate follow-through.
- **Confidence:** High.
- **Do Not Overfit:** The tickets are spread across three tasks and two periods, and the
  auto-fix rate the Improvement Loop names as a friction trigger ("Auto-fix rate drops below
  50 % for a ticket type") has been 0 % for every ticket type in both periods. A gate that
  emits tickets nothing subsequently closes is emitting advisory text, not work items.

### FP-03: The artifact the Review Rounds metric reads is never produced

- **Evidence:** rule 2 reads `reports/implementation/<feature>/T-NNN-review-<n>.md`. No such
  file exists for any of the 5 tasks; the directory holds exactly `T-001.md` … `T-005.md`.
  The previous period likewise reported Review Rounds as N/A.
- **Frequency:** 0 of 5 tasks this period, and no measured value in the previous period either.
- **Phase:** measurement.
- **Confidence:** High.
- **Do Not Overfit:** This is a whole-column outcome, not a task-level omission — no task in
  either period produced the artifact, which points at the workflow never emitting it rather
  than at authors forgetting. A metric that is structurally always 0 cannot detect the friction
  it was added to detect, and reports it as a healthy zero.

### FP-04 (recorded, Low confidence — no WFI): T-005 concentration

- **Evidence:** T-005 carries 4 of the feature's 6 tickets, including its only Major
  (RT-20260817-004, a cross-cutting `UnicodeDecodeError` across three validators).
- **Frequency:** 1 task.
- **Phase:** implementation.
- **Confidence:** Low — single-task observation.
- **Do Not Overfit:** Recorded only in case a later period shows "the last task of an epic
  absorbs the cross-cutting findings" recurring. Per the Improvement Loop, a single-task
  observation must not create a WFI, and this one does not.

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| WFI-031 | Draft | Re-gate cycles recorded inside one gate report are invisible to both the retrospective's rule-3 count and `ship`'s disk-based cycle limit, so the Escalate-Human stop never fires (FP-01) | `plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md`, `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.{sh,ps1}`, `plugins/sdd-ship/skills/ship/SKILL.md` |
| WFI-032 | Draft | Review tickets are never transitioned out of `open`; auto-fix rate has been 0 % for two consecutive periods across 13 tickets (FP-02) | `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`, `plugins/sdd-ship/skills/ship/SKILL.md` |
| WFI-033 | Draft | The Review Rounds metric reads an artifact no workflow step emits, so it reports a structural 0 as a healthy value (FP-03) | `plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md`, `plugins/sdd-implementation/skills/implement-task/SKILL.md` |

Numbering starts at 031 because 026, 027, 029 and 030 are already taken on unmerged branches
(`wfi/026-mixed-task-status-provenance` carries 026 and 027 via PR #303); `main` itself stops
at 025. Reusing 026–030 would collide at merge.

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| WFI-031 | Ratio of counted Quality-Gate Runs to enumerated re-gate cycles, per feature | 5 counted / 11 actual (epic-192, this period) | 1:1 — every cycle with a distinct Run ID is counted exactly once | Next completed feature with at least one task needing more than one gate cycle |
| WFI-032 | Count of review tickets still `status: open` at the moment the feature's last task reaches Done | 6 of 6 (this period); 7 of 7 (previous period) | 0 open, or each remaining open ticket explicitly deferred with a recorded reason | Next two completed features that emit at least one review ticket |
| WFI-033 | Number of tasks per feature for which Review Rounds is a measured value rather than a structural 0 | 0 of 5 (this period); 0 measured (previous period) | Every task that underwent an independent review round reports a non-zero measured count | Next completed feature that runs any independent review round |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| `epic-192-a4-facet-manifest` | 1 | PASS | 3 | PASS | 1 | PASS | false |

Task review consumed three rounds (a1r1 NEEDS_WORK → a1r2 NEEDS_WORK → a1r3 PASS); spec and
impl review each passed in one. No gate reached BLOCKED, and `legacy_design` is `false` in the
impl-review contract.

## Comparison With Previous Retrospective

Previous: `reports/retrospective/2026-08-14T034801Z-pillar-a-wave-session.md`
(session-scoped across six feature specs, 2026-08-10 – 2026-08-14). That report was
multi-feature and this one is single-feature, so rate-style rows compare cleanly while
absolute totals do not; rows where the scope difference dominates are marked.

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| QG reports retained under rule 3 | 0 of 21 | **5 of 5** | **↑ — a four-period streak of zero is broken** |
| Avg QG Cycles per Task | not reported | 1.0 counted / 2.2 enumerated | new measurement (see FP-01) |
| Avg Task Attempts | 1.5 (6 measurable tasks) | 1.2 (6 attempts / 5 tasks) | ↓ improved |
| Avg Review Rounds | N/A | 0 (structural — see FP-03) | unchanged, still unmeasurable |
| Avg Quality-Gate Runs | N/A (0 retained) | 1.0 | first period with a value |
| Total Model Escalations | 0 | 0 | flat |
| Total Blocked Count | 5 | 0 | ↓ improved (previous period's 5 were 4 external-dependency + 1 cycle cap) |
| Total Review Tickets | 7 | 6 | ≈ flat (scope differs) |
| Auto-fix Rate | 0 % (0 of 7) | 0 % (0 of 6 resolved; 5 of 6 permit auto-fix) | **unchanged — second consecutive period at zero** |
| Avg Spec Review Rounds | N/A | 1 | first period with a value |
| Spec Review Blocked Rate | N/A | 0 % | first period with a value |
| Avg Task Review Rounds | N/A | 3 | first period with a value |
| Task Review Blocked Rate | N/A | 0 % | first period with a value |
| Avg Impl Review Rounds | N/A | 1 | first period with a value |
| Impl Review Blocked Rate | N/A | 0 % | first period with a value |
| Impl Legacy Design Rate | N/A | 0 % | first period with a value |
| Repeat Finding Rate | FP-02 repeated the prior period's FP-02 | 1 retention condition recurred (WFI-017) | ↑ |
| WFI Verification Rate | N/A (none reached Verified) | 0 Verified, 1 Regressed, 5 Needs-Followup, 2 deferred | ↓ |

The single most important row is the first. The previous three retrospectives all recorded zero
quality-gate reports surviving rule 3's association requirement, because the reports carried
`Task ID:` where the rule reads `Task:`. Every one of this feature's five reports carries **both**
keys, so all five are retained. That is the first period in four with any usable gate evidence.
No Applied WFI targets this metric, so the improvement is unattributed — it should not be
credited to the self-improvement loop without evidence that some landed change caused it.

## Applied WFI Horizon Check

| WFI-ID | Target-Metric | Baseline | Target | Current | Horizon | Classification |
|---|---|---|---|---|---|---|
| WFI-009 | Cross-model panel rounds returning NEEDS_WORK/FAIL for evidence-completeness reasons, per feature | 2 | 0 | **not scored** | Next completed feature retrospective with ≥1 `Cross-Model: enabled` task | **Deferred** — every task in this feature reads `Cross-Model: not enabled`, so the horizon's precondition is unmet |
| WFI-012 | Quality-gate cycles beyond cycle 1 attributable to a PowerShell case-sensitivity weakened-port finding, per `.sh`→`.ps1` port task | 4 (primary) / 1 (secondary) | 0 both | 0 (primary, literal) | Next 1 completed feature containing such a task | **Needs-Followup** — see note below |
| WFI-013 | Review findings caused by a claim about shared repo-wide state invalidated by a concurrently-merging sibling branch | 2 | 0 | 0 | Next 2 features developed alongside another active branch | **Needs-Followup** — 1 of 2 qualifying features observed; epic-192 ran concurrently with epics 193–196 and produced no finding of this class |
| WFI-014 | Spec-review `EDGE-CASE-COVERAGE` Major findings, per feature with a multi-round spec-review loop | 2 | 0 | **not scored** | Next 2 features whose spec-review reaches ≥2 rounds | **Deferred** — this feature's spec review passed in one round, so the precondition is unmet |
| WFI-016 | Impl-review-status guard denials blocking a design.md status write despite an existing PASS verdict | 1 | 0 | 0 | Next 2 features passing through impl-review-loop after the staged batch is applied | **Needs-Followup** — 1 of 2 qualifying features observed; no denial occurred |
| WFI-021 | Independently broken features whose diagnostics are reported in a single validator run | 1 | all broken features in one run | **not measured** | This change's verification run, then the next completed feature's retrospective | **Needs-Followup** — no multi-feature validator failure occurred in this period, so the metric had no occasion to be exercised; this is absence of opportunity, not evidence of effect |
| WFI-023 | Review findings whose root cause is a sibling artifact asserting a superseded recorded fact | 3 and 5 (two features) | 0 | 0 | Next 2 features completing both spec and impl review | **Needs-Followup** — 1 of 2 qualifying features observed; epic-192 completed both reviews with none of this class |

**WFI-012 note.** T-005 ("Vendored-copy drift gate and the cross-script parity suite") is the
closest thing this feature has to the horizon's `.sh`→`.ps1` port task, and under the metric as
literally written the count is 0: no cycle was spent on a PowerShell case-sensitivity finding.
But T-005 did burn a cycle on an adjacent defect of the same shape — the `.ps1` twin's
`Start-Process` normalising line endings, leaving the PowerShell side blind to a CR the `.sh`
twin caught. Scoring this Verified on the literal metric while the class of defect it exists to
catch recurred in a neighbouring form would be exactly the artifact-grading the skill warns
against. Left Applied and classified Needs-Followup; the next genuine `.sh`→`.ps1` port task
should settle it.

No Applied WFI reached Verified this period. Two were deferred for unmet horizon preconditions
rather than for lack of data — recorded here so the deferrals do not silently become evidence
of success.

## Retention Check

| Source WFI | Recurrence Condition | Recurred? | Evidence |
|---|---|---|---|
| WFI-002 | Manual precheck / manual review-gate execution appearing in `reports/` without a `manual-precheck-note.md` deviation record | No | This feature's review evidence contains no manual-precheck path; all five gate runs are scripted |
| WFI-007 | Implementation report first-committed outside `reports/implementation/<feature>/<task-id>.md`, or an evaluator boundary returning a report-path PATH failure | No | All five reports sit at the canonical path; no move/rename appears in the feature's git history |
| WFI-008 | An evidence bundle referencing an artifact path that is not git-tracked, or a missing artifact detected by `check-evidence-bundle` | No | All five `specs/<feature>/verification/T-NNN.evidence.json` bundles resolve every referenced artifact path to a git-tracked file (0 untracked of 15 checked) |
| WFI-011 | A specific, checkable factual claim in investigation/requirements/design proving wrong at implementation time | No | No gate report records a "spec-premise factual inaccuracy discovered at implementation time" finding |
| WFI-017 | A canonical-template implementation report rejected by `validate-implementation-report`'s Outputs contract, **or a report needing a format-retrofit commit to be accepted** | **Yes** | Commit `8fd365c7` — `gate(epic-192-a4-facet-manifest): fix T-003 Outputs binding, reserve seq0760` — is exactly a format-retrofit commit against an already-committed implementation report's Outputs contract. The root cause was footnote markers in the Outputs table breaking the strict matcher, which silently dropped five remediation files from the manifest and cost T-003 an additional cycle |

WFI-017 is therefore set to `Status: Regressed`, its evidence recorded in its `## Result`, and
its row removed from `docs/workflow-improvements/retention-checklist.md`. The recurrence is
treated as a friction-pattern candidate: the failure mode is not "authors write bad tables" but
"a strict matcher and a human-readable table format disagree, and the disagreement is silent" —
silence being the part worth fixing, since the dropped rows produced no diagnostic at all.

Four of five retention conditions held. One did not, in a form the original WFI's own condition
text anticipated precisely enough to catch without interpretation.
