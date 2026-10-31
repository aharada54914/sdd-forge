# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | epic-136-phase1-guards |
| Period | 2026-07-12 – 2026-07-12 |
| Generated | 2026-07-12T15:30:00Z |
| Sample Size | 6 tasks, 8 review contracts (spec 4, task 2, impl 2), 6 QG reports, 3 tickets |
| Data Completeness | Complete — all report roots exist with current-schema artifacts. Task-scoped independent-review files (`T-NNN-review-N.md`) are not produced by this repository's flow (reviews run at feature level via the three review-loop gates); Review Rounds is therefore a true 0, not a missing-evidence N/A. |
| Confidence | Medium-High — the headline pattern (FP-01) recurs across 2 tasks with 2 independent evidence types (aggregate verdict JSONs + review ticket); the 6-task sample and committed provenance support the horizon classifications. |

## Metrics

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| T-001 | 2 | 0 | 1 | 0 | 0 | 0/2/0 | Done |
| T-002 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-003 | 1 | 0 | 1 | 0 | 0 | 0/1/0 | Done |
| T-004 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-005 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-006 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| **Total** | 7 | 0 | 6 | 0 | 0 | 0/3/0 | 6 Done |

_C = Critical, M = Major, Min = Minor._

Counting notes (deterministic rules):

- Quality-gate association: each of the 6 gate reports carries exactly one
  `Task ID:` header and exactly one evaluator run id
  (`RUN-epic136guards-qg-T-NNN-seqNNNN`, ledger sequences 164–167, 169, 185)
  in its Critical Review Cycles section; there is no separate `Run ID:` header
  line, so the evaluator run id serves as the report's run identity. One
  retained report per task; no duplicates.
- T-001 shows Task Attempts 2 but Quality-Gate Runs 1: the attempt-1 blind
  cross-model panel returned consensus FAIL *before* the gate (cross-model
  precedes quality-gate in the critical flow), so no gate report was produced
  for attempt 1. The remediation is ticketed as RT-20260712-002 (resolved,
  auto-fixed).
- Tickets by task: RT-20260712-002 (T-001, major, resolved, auto_fix), RT-20260712-003
  (T-001, major, resolved via the dedicated feature specs/second-approval-mask —
  not auto-fixable), RT-20260712-001 (T-003, major, open/Deferred — upstream
  plugin spec change).
- Model Escalations: no complete escalation transition records exist in any
  retained artifact → 0 (not N/A; the fields are present and empty of
  transitions).

## Friction Patterns

### FP-01: Blind-panel first runs fail on evidence completeness, not behavior

- **Evidence:** T-006 (panel round 1: 3× NEEDS_WORK — sanitized bundle lacked
  the implementation artifacts; non-recursive collector; re-staged bundle then
  3× PASS) and T-001 (attempt-1 panel: 3× NEEDS_WORK, digest 29c7ab73… —
  parity corpus exercised ~7 of 30+3 protected-table entries vs the spec's
  "every protected suffix class" bar, suites unwired from the aggregate
  runner; RT-20260712-002; attempt-2 rebundle then 3× PASS). In both cases the
  isolated evaluator had PASSed the implementation itself.
- **Frequency:** 2 occurrences across 2 of the period's 3 cross-model-enabled
  tasks (T-001, T-002, T-006 per tasks.md) — T-002's first panel round passed
  cleanly, so the first-run failure rate is 2 of 3, not 100% (correction
  applied by the WFI-009 Cycle-1 audit, EVIDENCE-CITED finding).
- **Phase:** cross-model-verify (panel input assembly / pre-panel readiness).
- **Confidence:** Medium (2 tasks, 2 independent evidence types).
- **Do Not Overfit:** the two failures have different proximate causes (bundle
  assembly vs corpus coverage) on different tasks; what recurs is the
  detection point — deterministically checkable completeness properties are
  first checked by the most expensive verification step. → WFI-009.

### FP-02: Legitimate post-freeze state changes read as provenance drift

- **Evidence:** RT-20260712-003 — recording the critical-tier
  `Second Approval:` line (human-only, required by check-task-state) after the
  task-review freeze tripped `stage-provenance: task plan hash is stale`
  repository-wide, structurally blocking the two-person critical flow for
  T-001/T-002. Related same-period instance: editing tasks.md Done-When
  checkboxes after task review tripped the same freeze and required a revert
  (recorded in the T-003..T-006 gate pass).
- **Frequency:** 2 tasks (T-001, T-002) + 1 adjacent instance.
- **Phase:** workflow-state provenance (post-task-review).
- **Confidence:** Medium-High.
- **Do Not Overfit:** the mask gap was structural (the line class did not
  exist when the freeze semantics were authored), not a one-task accident.
- **Disposition:** remedied in-period by the dedicated full-track feature
  `specs/second-approval-mask/` (Done 2026-07-12; live twins human-applied;
  39-check suite registered in tests/run-all.sh; production-verified by the
  repository's first two critical two-person Done flows). Via the retention
  check this recurrence sets WFI-004 → Regressed; no new WFI is drafted
  because the durable fix and its deterministic recurrence net already
  shipped.

### FP-03: Cycle-limit cross-feature task-id collision (standing false positive)

- **Evidence:** RT-20260712-001 (open, Deferred). Both critical gates' ship
  Step 4.5 prechecks this period hit the naive `grep -l T-NNN` count (26
  files for T-001, similar for T-002) against reports from unrelated features
  reusing the same task ids; feature-scoped counts were 0 at both gates
  (qg/T-001/cycle-limit.log, T-002 gate report §Cycle-Limit).
- **Frequency:** 2 gates this period; affects every future feature.
- **Phase:** ship Step 4.5.
- **Confidence:** High (deterministic, reproducible).
- **Do Not Overfit:** n/a — mechanical collision, already fully analyzed in
  RT-20260712-001 which awaits an upstream plugin spec change; drafting a WFI
  would duplicate that tracking, so this pattern is recorded without one.

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| WFI-009 | Human-Pending (audited, issue created: [#166](https://github.com/aharada54914/sdd-forge/issues/166)) | Blind-panel first runs fail on deterministically checkable evidence-completeness gaps (FP-01; audit corrected the rate to 2 of 3 first runs — T-002 passed cleanly) | GitHub-Issue lane: plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh (+ .ps1) + cross-model-verify SKILL pre-panel readiness; no project-side target |

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| WFI-009 | cross-model panel rounds returning NEEDS_WORK/FAIL for evidence-completeness reasons per feature (count) | 2 (this period) | 0 | next completed feature retrospective with a Cross-Model: enabled task |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| epic-136-phase1-guards | 1 (attempt 2) | PASS | 2 | PASS | 2 | PASS | false |

Spec review consumed two attempts: attempt 1 reached BLOCKED at round 3;
attempt 2 passed on round 1 (4 spec-review contracts total). Under the metric
definition (round number of the final passing contract; blocked-rate judged on
the final attempt's last round) this records as 1 round / not blocked; the
attempt-1 BLOCKED is preserved here for honesty. Task review passed at
attempt-1 round-2 by the recorded artifacts (an orchestrator manifest defect
in the first execution was corrected via the sanctioned
`--provenance-rereview` path with attempt increment; see the feature's review
records). Impl review passed at round 2.

## Comparison With Previous Retrospective

Previous = epic-136-phase1-rce (2026-07-11, 1 task; run under a different
model — see Data Notes).

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | 1.0 | 1.0 | flat |
| Avg Task Attempts | N/A (legacy report) | 1.17 (7/6) | n/a baseline |
| Avg Review Rounds | N/A | 0 (feature-level review flow) | n/a |
| Avg Quality-Gate Runs | 1.0 | 1.0 | flat |
| Total Model Escalations | N/A | 0 | n/a |
| Total Blocked Count | 0 | 0 | flat |
| Total Review Tickets | 0 | 3 | ↑ (first critical-tier feature; 2 of 3 resolved in-period) |
| Auto-fix Rate | N/A (no tickets) | 1/3 | n/a |
| Avg Spec Review Rounds | 2.0 | 1 (final attempt; +3 in blocked attempt 1) | see note |
| Spec Review Blocked Rate | 0/1 | 0/1 (final-attempt definition; attempt-1 BLOCKED occurred) | flat by definition |
| Avg Task Review Rounds | 1.0 | 2.0 | ↑ |
| Task Review Blocked Rate | 0/1 | 0/1 | flat |
| Avg Impl Review Rounds | 2.0 | 2.0 | flat |
| Impl Review Blocked Rate | 0/1 | 0/1 | flat |
| Impl Legacy Design Rate | 0/1 | 0/1 | flat |
| Repeat Finding Rate | N/A (single task) | 1 repeated class (evidence-completeness, 2 tasks) | n/a |
| WFI Verification Rate | 0/3 conclusively measured | 3/3 Applied WFIs conclusively classified (all Verified) + 1 retention outcome (WFI-004 Regressed) | ↑ |

## Applied WFI Horizon Check

| WFI-ID | Target-Metric | Baseline | Target | Current | Horizon | Classification |
|---|---|---|---|---|---|---|
| WFI-005 | Gate artifacts manually retrofitted for a deterministic consumer (count/feature) | 23 + 1 unusable-waiver blocker | 0 | 0 (6 impl reports + 6 gate reports accepted at first write; parity twins green 10/0 this run; no placeholder-scan waiver attempted) | next completed feature (extended once from rce) | Verified |
| WFI-006 | Stale-narrative-vs-current-state Minor findings in gate reports (count/feature) | 2 (prior periods 4/6/3) | <=1 | 1 (T-001 Accepted Minor #1; all 6 reports carry the Snapshot Notice from first write; reconciliation recorded in the gate report per the new instruction) | next completed feature (extended once) | Verified |
| WFI-007 | Implementation reports needing a gate-phase path move before evaluator-boundary acceptance (count/feature) | 9 | 0 | 0 (all 6 reports canonical from first commit; no PATH failures for report paths; flat-path grep of plugin files = 0) | next completed feature (extended once) | Verified |

All three classifications carry a model-mix confound note (see Data Notes):
they are accepted because each metric is a deterministic artifact-format/path
count controlled by the plugin-side fix, not a model-judgment metric.
Recurrence conditions registered in retention-checklist.md.

## Retention Check

| Source WFI | Recurrence Condition | Recurred? | Evidence |
|---|---|---|---|
| WFI-001 | High-risk QG persisted-evidence/traceability *inconsistency* ticket, or 2nd-cycle evidence correction of that class | No | RT-20260712-002 was a 2nd-cycle remediation on a critical task, but its class is spec-mandated coverage breadth (corpus under-coverage found by the panel), not persisted-evidence/traceability inconsistency — the qualifier scopes both arms of the condition. Persisted evidence and traceability stayed consistent (check-traceability require-evidence PASS at both critical gates). Judgment recorded for transparency. |
| WFI-002 | Manual precheck/review-gate execution without a deviation record | No | The one non-default review execution (task-review re-run) used the sanctioned `--provenance-rereview` mode with attempt increment — an automated path, not an unrecorded manual bypass. |
| WFI-003 | Metrics-table N/A cells caused by missing Run ID / Task Attempt Count | No | All 6 implementation reports carry Task Attempt Count; all 6 gate reports carry their evaluator run id. No N/A cells of this class in this report's Metrics table. |
| WFI-004 | check-workflow-state stage-provenance contradiction (frozen-artifact drift class) blocking via ticket/gate on an implemented-state feature | **Yes** | RT-20260712-003: post-freeze `Second Approval:` line tripped "task plan hash is stale" repository-wide. WFI-004 set to **Regressed** (its own Issue-#86 fixes remain in place; this is a new instance of the same failure-mode class). Checklist row removed. Durable fix already shipped in-period: specs/second-approval-mask (Done; 39-check run-all suite is the recurrence net). |

## Data Notes

- **Model mix (confound record):** implementation ran on fresh-agent
  subagents (claude-opus-4-8); the attempt-2 test-only fix, the attempt-2
  panel/evaluator (seq 185), and orchestration late in the period ran on
  claude-fable-5; evaluator sequences 164–167/169 ran earlier in the session.
  The previous feature's run record (epic-136-phase1-rce) records gpt-5.
  Metric shifts across these model changes are NOT attributed to WFIs; the
  three Verified classifications rest on deterministic artifact counts, and
  this caveat is recorded in each WFI's Result.
- **T-001 attempt-2 evaluator-boundary rejections** (review-ticket path and
  run-manifest path not role-listed; `## Outputs` table updated to declare
  attempt-2 artifacts) are input-scoping events of the launch boundary
  working as designed, not WFI-005/007-class format retrofits or path moves;
  they are documented in the T-001 gate report ("Note on report-hash drift").
- **rollback-1.5.0.tests.sh** fails identically with and without this
  feature's changes (clean-HEAD differential in
  specs/epic-136-phase1-guards/verification/T-001/regression-attempt2.log);
  known pre-existing TEST-006 defect, fix pending on branch
  claude/jovial-matsumoto-0ef83b. Not counted against any task or WFI.
- The run record emitted after this report
  (reports/runs/RUN-20260712T224147Z-epic-136-phase1-guards.json) preserves
  the countable task/ticket metrics (tasks 6/6 done, tickets 0/3/0) and the
  active-WFI set (empty — WFI-005/006/007 moved to Verified in this
  retrospective; WFI-009 is Draft). Caveat for future attribution: its
  `gate_reports.total` is 0 because the deterministic counter associates gate
  reports by `Task:`/`Run ID:` header lines while this feature's reports use
  a `Task ID:` header with the evaluator run id in the body; the true count
  is 6 (one per task, listed in this report's Metrics). Single-instrument
  observation, low confidence, recorded without a WFI; if it recurs next
  feature it becomes a friction-pattern candidate (format alignment between
  the gate-report template and the run-record counter).
