# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | evidence-deep-verify |
| Period | 2026-07-08 – 2026-07-09 (spec bootstrap `9a15828` through `docs(qg): evidence-deep-verify quality gate PASS — all 8 tasks Done (#68)` `e3c148e`) |
| Generated | 2026-07-09T02:45:00Z |
| Sample Size | 8 tasks, 6 review contracts (2 spec-review + 3 task-review + 1 impl-review), 8 QG reports, 0 tickets |
| Data Completeness | Complete — all expected report roots exist (`reports/implementation/evidence-deep-verify/` 8 task reports + 1 traceability addendum, `reports/quality-gate/` 8 `evidence-deep-verify` reports, `reports/spec-review/evidence-deep-verify/`, `reports/task-review/evidence-deep-verify/`, `reports/impl-review/evidence-deep-verify/`, `docs/review-tickets/` — no evidence-deep-verify tickets, prior retrospectives). **Caveat:** an untracked `reports/runs/RUN-20260708T173253Z-evidence-deep-verify.json` already exists on disk, but its `generated` timestamp (2026-07-08T17:32:53Z) predates every retained QG report (2026-07-09T01:30Z–02:35Z) and the final gate-PASS commit `e3c148e` (2026-07-09T02:32:22+09:00). Its metrics (`first_pass_gate.passed_first_try: 0/8`, `gate_reports.total: 24`, `gate_reports.blocked: 6`, `review_tickets.major: 4`) directly contradict the deterministic evidence collected below (8/8 QG reports, all PASS, all first-cycle, 0 tickets) and were evidently captured mid-flight before the feature's implementation/gate phase completed. This report does **not** use that file as a metrics source — all counts below are derived directly from the retained implementation, quality-gate, and review-contract artifacts per the Deterministic artifact rules. Regenerating `reports/runs/RUN-*.json` is outside this run's single-file-write mandate; see "Run Record" below. |
| Confidence | High — the clean-run pattern (0 model escalations, 0 blocked QG decisions, 0 review tickets, 8/8 tasks first-attempt, first-cycle independent review on every evaluated task) recurs across all 8 tasks and 3 independent evidence types (implementation reports, QG reports, review contracts). The stale-narrative friction pattern recurs across 2 tasks this period and is now the **4th consecutive feature** to show it. |

## Metrics

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| T-001 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-002 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-003 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-004 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-005 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-006 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-007 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| T-008 | 1 | 0 | 1 | 0 | 0 | 0/0/0 | Done |
| **Total** | **8 (avg 1.0)** | **0** | **8 (avg 1.0)** | **0** | **0** | **0/0/0** | **8/8 Done** |

_C = Critical, M = Major, Min = Minor_

Counts use the workflow-retrospective deterministic artifact selection, task-association, ordering, tie-break, and de-duplication rules. Review Rounds is `0` for every task by construction, not schema-drift `N/A`: this feature records independent-evaluator cycles inside each quality-gate report's `## Independent Critical Review` / `## Orchestrator Light-Gate Review` prose, and no standalone `T-NNN-review-<n>.md` artifacts exist — the same convention already established in the `ci-mcp` and `local-env-mcp` retrospectives. All 8 implementation reports carry the current-schema `## Iteration And Escalation` block with `Task Attempt Count: 1` and `Escalation Prior Tier: None`, so no `N/A` cells were required this period (contrast with `sdd-domain`, whose 10/11 legacy reports forced `N/A`).

Supplementary cycle detail recorded inside the retained quality-gate reports:

- 5 of 8 tasks are `Risk: high` and used the independent `sdd-evaluator` (T-001 ledger seq 129, T-002 seq 130, T-003 seq 131, T-004 seq 132, T-007 seq 133); 3 are `Risk: medium/low` (T-005 medium, T-006 low, T-008 medium) and used orchestrator gate-owner light review per the gate-depth policy.
- **8 of 8 gate cycles resolved on the first pass** — no task needed a second evaluator cycle this period (contrast with `ci-mcp`, whose T-006/T-013 each needed a cycle-2 fix-and-reverify).
- Evaluator/orchestrator findings across all 8 final gate reports: **0 Critical / 0 Major / 5 Minor**, all `Accepted`/`Accepted-Deferred`, non-blocking. T-001 (1: `evidence.ts` at 783 lines, exceeds the 500-line style guideline), T-002 (1: the no-exec `child_process` trap patches the module namespace at call time, a pre-destructured import could theoretically evade it), T-003 (1: `stripComments` is not string-literal-aware), T-004 (1: stale worker-snapshot prose, see Friction Patterns), T-007 (1: stale pre-move report path + stale regression count, see Friction Patterns). T-005/T-006/T-008 carry 0 findings.
- 0 review tickets target `evidence-deep-verify` (`docs/review-tickets/*.yml` scanned; no file references the feature). 0 quality-gate reports are BLOCKED. 0 model escalations recorded across the 8 implementation reports' `## Iteration And Escalation` sections (all `Task Attempt Count: 1`, `Escalation Prior Tier: None`).
- **Positive evidence, not friction:** T-002/T-003 each disclose, in their own implementation reports, that T-001's core already satisfied their acceptance criteria before any T-002/T-003-scoped `src` edit (T-002: "Red (before any implementation change): 15/15 pass — T-001 already satisfied"), and prove the claim is not vacuous by including a mutation/compiled-artifact non-vacuity check (8/15 fail when invariants are deliberately broken) rather than merely asserting zero-diff completion. T-004's worker encountered a pre-existing hardcoded MCP tool-count assertion (13→14) outside its writable Scope, correctly stopped instead of silently editing out-of-scope code, and escalated the one-line fix to the orchestrator for an explicit in-scope decision (`reports/quality-gate/2026-07-09T020500Z-evidence-deep-verify-T-004.md`: "orchestrator's out-of-scope accompaniment... git-reviewed and judged the correct minimal change"). T-008's first acceptance-first run genuinely caught a stale-`dist` smoke failure (2/2 FAIL) before the rebuild, proving the check has teeth rather than rubber-stamping.

## Friction Patterns

Patterns observed across two or more tasks in this period.

### FP-01: Implementation-report prose/paths go stale once later tasks touch the same surface or a gate-phase normalization moves the file

- **Evidence:** T-004's QG report: `reports/implementation/evidence-deep-verify/T-004.md:79-86` still records the worker-snapshot's mid-implementation BLOCKED/190-of-191 state, now stale after the orchestrator's tool-count decision made the suite fully green (`reports/quality-gate/2026-07-09T020500Z-evidence-deep-verify-T-004.md`, Minor/Accepted). T-007's QG report: `reports/implementation/evidence-deep-verify/T-007.md:80,166` cites the pre-move flat report path and a stale "197" regression count against the current 205-test suite (`reports/quality-gate/2026-07-09T021500Z-evidence-deep-verify-T-007.md`, Minor/Accepted).
- **Frequency:** 2 tasks this period (T-004, T-007); this is the **4th consecutive feature** to show this exact class — `local-env-mcp`'s retrospective recorded it as FP-002 (3 tasks), `sdd-domain`'s recorded it inside its broader FP-05 (5 tasks), `ci-mcp`'s recorded it as FP-02 (4 tasks) and explicitly proposed an un-drafted `WFI-006 (candidate)` targeting `AGENTS.md` / an implementation-report checklist. That candidate was never drafted, and the pattern has now reproduced a 4th time.
- **Phase:** implementation-report authoring (prose/counts/paths written before a later same-feature event — a subsequent task's edit, or a gate-phase normalization — changes the described state) / quality-gate evidence check.
- **Confidence:** High (2 tasks this period meets the two-task bar on its own; the 4-consecutive-feature history removes any doubt this is a process property rather than incidental).
- **Do Not Overfit:** Every occurrence shares one mechanism — a report is written as an honest snapshot at its own authoring commit, then a later event in the same serial pipeline (another task's edit, or an orchestrator-driven file move) changes the state the report describes. It is not any one author's error; it recurs regardless of which model or risk tier writes the report.

**Disposition:** `ci-mcp`'s retrospective (`reports/retrospective/2026-07-08T033000Z.md`, FP-02 / Proposed Improvements) already proposed this exact candidate as `WFI-006`, not yet drafted, "out of scope, recommend human-authorized follow-up." Per this run's single-file-write mandate (only this report may be written), no WFI file is drafted here either. Given this is now a **4th unaddressed occurrence with an already-specified candidate**, this retrospective escalates the recommendation: the next human-authorized session should draft and audit `WFI-006` against `ci-mcp`'s original candidate (target: `AGENTS.md` / implementation-report checklist — require a final prose/count/path refresh pass immediately before gate submission) rather than re-mine the evidence. Deferring a 5th time would itself become a process failure independent of the underlying pattern.

### FP-02: Installed plugin skill files still document the pre-canonicalization flat implementation-report path

- **Evidence:** All 8 of this feature's implementation reports were first committed at the flat path `reports/implementation/evidence-deep-verify-T-NNN.md` and had to be bulk-moved to the canonical `reports/implementation/evidence-deep-verify/T-NNN.md` layout in a single gate-phase commit (`e3c148e`, 9 files renamed: `T-001`..`T-008` + the `T-006` traceability addendum). This was not a one-off drafting slip: three currently-installed plugin skill/reference files still instruct agents to write to the flat path — `plugins/sdd-implementation/skills/implement-task/SKILL.md:97` ("Create `reports/implementation/<task-id>.md`"), `plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md:38`, and `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md:30` (same wording); `plugins/sdd-implementation/skills/implement-tasks/SKILL.md:191` repeats it for the orchestrator's own delegation instructions. `validate-review-context-set` (the evaluator/reviewer launch-boundary validator) requires the canonical per-feature directory form, and T-007's QG report (Minor/Accepted) independently corroborates that the move was "an orchestrator gate-phase normalization required by validate-review-context-set."
- **Frequency:** 8/8 tasks this feature (single root cause, uniform manifestation across every task report) plus 4 distinct plugin-file locations that all encode the stale convention. First observed occurrence of this specific gap in the retrospective history to date (grep of `reports/retrospective/*.md` for the flat-path pattern found no prior mention).
- **Phase:** implementation-report authoring (worker follows the installed plugin's own documented path) / quality-gate launch-boundary validation (gate-phase bulk normalization).
- **Confidence:** Medium — high within-feature recurrence (8/8) but this is the first cross-feature sighting of this exact gap, and it is one systemic root cause rather than eight independent occurrences.
- **Do Not Overfit:** This is not a task-authoring wording issue fixable by clarifying `tasks.md` — the flat path is hard-coded into four separate plugin skill/reference files that every future feature's implementation workers will read verbatim. It is adjacent to, but distinct from, `WFI-005`'s already-applied fix (which corrected the report *heading*/`Task ID` line/`Outputs` table and the gate report's `Feature:` line, not the report's *file path*). `WFI-005` is already `Status: Applied` and closed to further edits without a new verification cycle, so this gap needs its own WFI rather than a revision.

**Disposition:** Judged strictly per this run's instruction to only propose a WFI where a documentation-wording fix would not suffice: this qualifies, because the wrong path is baked into installed plugin mechanism files (not project-side prose) and will keep recurring on every future feature until those files change. Recorded here as a new candidate — tentatively `WFI-007` pending the actual highest-existing-WFI-number check at draft time (Category: `plugin-improvement`, target: the four `plugins/sdd-implementation/...` files above, via the GitHub Issue lane per `wfi-category-guide.md` — not directly editable by a project-side WFI). Not drafted in this run (single-file-write mandate); a human-authorized follow-up should run `workflow-retrospective`'s WFI drafting step (2) and the `wfi-audit-cycle` (step 2.5) for it.

**Not elevated to a friction pattern (Low confidence, single unverified mention):** the task brief for this retrospective mentions an evaluator nearly conflating a stale `green.txt` count (166, T-001's own accurate snapshot at its own commit) with the current 205-test suite, with no actual harm. A targeted search of all 8 QG reports found no artifact text describing this near-miss directly (T-001's "166 tests, 166 pass" is accurate for T-001's own scope and commit, not a documented confusion). Recorded here only as an aside per the orchestrator's own session observation; not counted as a friction pattern occurrence and not a WFI candidate (single, unverified-by-artifact instance, explicitly "no actual harm" per the brief).

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| WFI-006 (candidate, reinforced) | Not drafted (read-only-except-this-report run) | FP-01: stale implementation-report prose/paths/counts — 4th consecutive feature occurrence (`local-env-mcp` FP-002 → `sdd-domain` FP-02 → `ci-mcp` FP-02 → this report's FP-01), first proposed as `WFI-006` by the `ci-mcp` retrospective and never drafted | `AGENTS.md` / implementation-report checklist (project-side; require a final prose/count/path refresh pass immediately before gate submission) |
| WFI-007 (candidate, new) | Not drafted (read-only-except-this-report run) | FP-02: installed plugin skill files (`implement-task/SKILL.md`, `implementation-policy.md`, `agent-delegation-policy.md`, `implement-tasks/SKILL.md`) still document the pre-canonicalization flat `reports/implementation/<task-id>.md` path, contradicting `validate-review-context-set`'s canonical per-feature directory requirement; caused a bulk 9-file gate-phase git-mv this period | Plugin skill/reference files via GitHub Issue (`plugin-improvement` lane; Category: `plugin-improvement`, likely `Meta-Change: true` — touches the artifact path a launch-boundary validator consumes) |

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| WFI-006 (candidate) | Stale-narrative-vs-current-state Minor findings per feature (count) | 2 this period (evidence-deep-verify); 4 (ci-mcp), ~5–6 (sdd-domain, within FP-05), 3 (local-env-mcp) in prior periods | ≤1 | next completed feature retrospective, contingent on WFI-006 being drafted and Approved |
| WFI-007 (candidate) | Implementation-report artifacts requiring a gate-phase path move/rename before a launch-boundary validator accepts them (count) | 9 (8 task reports + 1 addendum) this period | 0 | next completed feature retrospective, contingent on WFI-007 being drafted and Approved |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| evidence-deep-verify | 2 | PASS (attempt 1, round 2) | 3 | PASS (attempt 1, round 3) | 1 | PASS (attempt 1, round 1) | false |

Rounds follow the skill definition (round number of the final passing contract); all three loops resolved within a **single attempt** this period (contrast with `ci-mcp`'s task-review, which needed 2 attempts and hit a `BLOCKED` verdict). Spec-review: round-1 `NEEDS_WORK` (1 Major) → round-2 both reviewers `PASS`. Task-review: round-1 `NEEDS_WORK` (3 Major — `RISK-APPROPRIATE` on T-004's under-classified public-API-contract surface, `TASK-SIZE` on T-001/T-002's 11-item Done-When lists, `SCOPE-DISJOINT` on T-002 vs T-003 sharing `evidence.ts` with no mutual blocker) → round-2 `NEEDS_WORK` (1 Major — `TASK-SIZE` on T-004's now-6-area Scope after the round-1 risk reclassification, resolved by splitting T-004 into T-004/T-007/T-008) → round-3 `PASS` clean (14/14 reviewer-A checks, 0 findings). Impl-review passed clean on attempt-1 round-1 (reviewer A and B both PASS, 0 findings, `legacy_design: false`). One procedural correction is recorded inline in the task-review round-1 apply commit (`db7aa23`): `design.md`'s `Impl-Review-Status` header had not been transitioned to `Passed` despite the attempt-1 round-1 impl-review PASS verdict already being on record (a missed transition from a prior session) — corrected in the same commit that applied the task-review round-1 fixes, before the quality gate ran. Blocked rates: spec 0%, task 0% (no `BLOCKED` verdict occurred at any round this period — an improvement over `ci-mcp`, whose task-review hit `BLOCKED` at attempt-1 round-3), impl 0%.

## Comparison With Previous Retrospective

Previous: `reports/retrospective/2026-07-08T033000Z.md` (`ci-mcp`) — the most recent completed-feature retrospective and, like this period, a full-track application-code feature with the same evaluator/light-gate-depth policy, making it the strongest adjacent baseline.

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | 1.0 (13/13) | 1.0 (8/8) | Flat |
| Avg Task Attempts | 1.0 | 1.0 | Flat |
| Avg Review Rounds | 0 (recorded in gate evidence instead) | 0 (same convention) | Flat |
| Avg Quality-Gate Runs | 1.0 | 1.0 | Flat |
| Total Model Escalations | 0 | 0 | Flat |
| Total Blocked Count (task/QG level) | 0 | 0 | Flat |
| Total Review Tickets | 0 | 0 | Flat |
| Auto-fix Rate | N/A (0 tickets) | N/A (0 tickets) | Not comparable |
| Avg Spec Review Rounds | 2 | 2 | Flat |
| Spec Review Blocked Rate | 0% | 0% | Flat |
| Avg Task Review Rounds | attempt 1: 3 rounds (`BLOCKED` at round-3) → attempt 2: 1 round (PASS, after 1 schema-invalid relaunch) | attempt 1: 3 rounds, no `BLOCKED`, clean `PASS` at round-3 | Improved — single attempt, no `BLOCKED` verdict, no schema-invalid relaunch |
| Task Review Blocked Rate | 0% (by definition — final attempt's last round was PASS) | 0% | Flat by the strict metric; this period's improvement (no raw `BLOCKED` verdict at all, vs. `ci-mcp`'s attempt-1 round-3 `BLOCKED`) is visible only in the rounds/attempts detail above |
| Avg Impl Review Rounds | 1 | 1 | Flat |
| Impl Review Blocked Rate | 0% | 0% | Flat |
| Impl Legacy Design Rate | 0% | 0% | Flat |
| Repeat Finding Rate | 2 recurring classes carried over (FP-01 schema drift referencing WFI-005; FP-02 stale-narrative, 3rd consecutive feature at that point) | 1 recurring class continues (stale-narrative, now 4th consecutive feature, FP-01 above); the schema-drift class (`ci-mcp`'s FP-01) did **not** recur this period — `WFI-005` was `Applied` on 2026-07-08 and this feature's review-loop launches show no format-retrofit or schema-reject events | Improved on the schema-drift class (see Applied WFI Horizon Check below); unchanged/worse on the stale-narrative class |
| WFI Verification Rate | N/A — 0 WFIs held `Status: Applied` at the start of that retrospective | 1/1 — `WFI-005` was the sole `Status: Applied` WFI at the start of this retrospective; see horizon check below | New data point this period |

Confound note: `WFI-005` was `Applied` on 2026-07-08, i.e. **during** the gap between the `ci-mcp` and this retrospective, and its template changes (implementation-report `## Outputs` table, `- Task ID:` line, quality-gate report `Feature:` line) are present in all 8 of this feature's reports from their first commit — this is the expected, intended effect of `WFI-005`, not a confound to discount. No model-version change is recorded in this period's reports (`Task Attempt Count = 1` for all 8 tasks; implementation by a mix of opus/sonnet/haiku per task risk tier, evaluation by opus, matching the prior period's tiering policy).

## Applied WFI Horizon Check

| WFI-ID | Target-Metric | Baseline | Target | Current | Horizon | Classification |
|---|---|---|---|---|---|---|
| WFI-005 | Gate artifacts requiring manual format retrofit before a deterministic consumer accepts them (count) | 23 retrofits + 1 unusable-waiver blocker (`sdd-domain`, 2026-07-07) | 0 | 0 — all 8 implementation reports carry the `- Task ID: T-NNN` line and `## Outputs` two-column table from their first commit (verified: `grep -m1 "^- Task ID:"` / `"^## Outputs"` present in all 8 files at HEAD); all 8 QG reports carry `Feature: evidence-deep-verify` from first commit; no `placeholder-scan` waiver was attempted or needed on any of the 5 high-risk task contracts; `tests/template-validator-parity.tests.sh` / `.tests.ps1` exist at repo root and are wired into `.github/workflows/test.yml` | next completed feature retrospective (this one) | **Target met** (0 retrofits, parity tests present and CI-wired) |

`WFI-005` (`Status: Applied` since 2026-07-08, `Audit-Status: Human-Pending`) is the only WFI that held `Status: Applied` at the start of this retrospective; `WFI-001`–`WFI-004` were already finalized to `Status: Verified` before this period (see Retention Check). Per the skill's Horizon check, a target-met classification should set `WFI-005`'s `Status: Verified` and register its recurrence condition in `docs/workflow-improvements/retention-checklist.md` — **both of those are write actions outside this run's single-file mandate** (only this retrospective report may be written) and are therefore deferred to a human-authorized follow-up, which should apply exactly the classification determined here rather than re-deriving it. FP-02 above (the flat-path plugin-file drift) is adjacent to but distinct from `WFI-005`'s specific fixed scope (report heading/Task-ID/Outputs-table/Feature-line format, not file path) and does not affect this classification.

## Retention Check

`docs/workflow-improvements/retention-checklist.md` exists with 4 entries (`WFI-001`–`WFI-004`, all `Status: Verified` as of 2026-07-06).

| Source WFI | Recurrence Condition | Recurred? | Evidence |
|---|---|---|---|
| WFI-001 | High-risk-task quality-gate fix ticket or 2nd-cycle-or-later evidence correction caused by persisted-evidence/traceability inconsistency | No | All 5 high-risk tasks (T-001–T-004, T-007) passed the independent evaluator on cycle 1; the only 5 Minor findings recorded (see Metrics) are style/hardening notes and stale prose, none is a persisted-evidence or traceability mismatch. All 8 implementation and QG reports carry consistent `Run ID` / `Task ID` / `Feature` identity with no cross-artifact contradiction. |
| WFI-002 | Manual precheck or manual review-gate execution occurs without a `manual-precheck-note.md` deviation record in `reports/` | No | Spec-review, task-review, and impl-review `invocation-a.json`/`invocation-b.json` for this feature were checked across all rounds/attempts (2 spec + 3 task + 1 impl); no `manual-precheck-note.md` exists for `evidence-deep-verify` because no manual fallback occurred. |
| WFI-003 | Retrospective Metrics table has an `N/A` cell caused by missing Run ID / Task Attempt Count | No | All 8 implementation reports carry `Task Attempt Count: 1` and an `Escalation Prior Tier` field; all 8 quality-gate reports carry `Task:`/`Task ID:` and `Run ID:` lines. Zero `N/A` cells in this report's Metrics table. |
| WFI-004 | `check-workflow-state` returns exit 1 for a post-implementation-stage feature due to stage-provenance contradiction (frozen-artifact drift, reviewer-schema mismatch, or `INITIAL-STATE` rejection) | No | T-006 (the post-task-review documentation/traceability-finalization task) used the addendum path exactly as `WFI-004` prescribes: `specs/evidence-deep-verify/traceability.md` stayed frozen at reviewed bytes and the per-chain Verification Status was recorded in `reports/implementation/evidence-deep-verify/T-006-traceability-addendum.md` instead. No `BLOCKED` gate report or exit-1 evidence found for `evidence-deep-verify`. |

## Run Record

Deferred, with reason: this retrospective ran under an explicit single-file-write mandate (only `reports/retrospective/2026-07-09T0245Z-evidence-deep-verify.md` may be written), so the skill's post-report `emit-run-record.sh evidence-deep-verify --track full ...` step — which would write/overwrite `reports/runs/RUN-*.json` — is out of scope for this run. An untracked `reports/runs/RUN-20260708T173253Z-evidence-deep-verify.json` already exists but, per the Data Completeness caveat above, its metrics predate and contradict the finalized gate evidence; it should not be treated as authoritative. A human-authorized follow-up should re-run (or overwrite) the emit step with the real per-run confound metadata (main model mix opus/sonnet/haiku by task risk tier, reviewer model opus, plugin version) after this report is accepted, so the attribution baseline reflects the feature's actual final state (8/8 first-pass, 0 blocked, 0 tickets) rather than the stale mid-flight snapshot.

## Addendum (orchestrator, 2026-07-09T0250Z)

The stale mid-flight `RUN-20260708T173253Z-evidence-deep-verify.json` was deleted and the
emit step re-run at the all-Done HEAD as `reports/runs/RUN-20260708T174217Z-evidence-deep-verify.json`.
Its `tasks` block (8/8 done, 0 blocked) is correct, but `first_pass_gate` / `gate_reports` /
`review_tickets` remain wrong for a different, already-diagnosed reason: the known
emit-run-record feature-scoping bug (repo-wide aggregation over bare `Task: T-NNN` matches —
task IDs recur across features), whose fix exists on the unmerged branch
`claude/competent-hopper-176ed3`. Until that fix merges and the record is re-emitted, the
deterministic ground truth for this feature remains this report's artifact-derived counts:
first-pass 8/8, gate reports 8 (all PASS), tickets 0.
