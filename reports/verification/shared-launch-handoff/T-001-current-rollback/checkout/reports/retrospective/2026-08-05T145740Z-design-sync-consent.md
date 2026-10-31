# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | design-sync-consent (per-scope design-upload consent; issues #129 lineage, bootstrapped with #130/#138 wave) |
| Period | 2026-08-04 – 2026-08-05 (authored and gated on `docs/wfi-021-gate-masking`; spec bootstrap `757b25fc` → final Done `bd03a46e`) |
| Generated | 2026-08-05T145740Z |
| Sample Size | 5 tasks, 11 review contracts (5 spec-review, 3 task-review, 3 impl-review), 5 QG report files carrying 6 gate runs (0 retained under artifact rule 3), 1 review ticket |
| Data Completeness | **Partial** — every expected report root exists and every implementation report is current-schema v2 with `Task Attempt Count`, but all 5 quality-gate reports fail artifact rule 3's association requirement (identity written as `Task ID: T-NNN`, no `Task: T-NNN` line), and the T-001 report additionally carries two `RUN_ID` values in one file (cycles seq 0512 and 0517). Enumerated in Data Exclusions below. |
| Confidence | **High** for FP-01 (evidence-prose numeric imprecision: 6 findings across 4 tasks, every one a value the evaluator re-measured first-hand) and for FP-02 (machine-identity contract: deterministic, reproduced against named script lines, third consecutive feature). **Medium** for FP-03 (self-false-positive class: 2 in-period occurrences on different surfaces plus 1 in-retrospective occurrence). Single-task observations are recorded but create no WFI. |

## Data Exclusions

Recorded rather than repaired, per artifact rule 5 — nothing below was reconstructed from filenames, timestamps, or chat history.

| Artifact | Rule | Reason for exclusion |
|---|---|---|
| `reports/quality-gate/20260805T142052Z-…-T-002.md` … `20260805T142055Z-…-T-005.md` (4 files) | 3 | identity present only as `Task ID: T-NNN` (line 3); no `Task: T-NNN` line — the same exclusion ground as 4 of 5 reports last period |
| `reports/quality-gate/20260805T144446Z-…-T-001.md` | 3 | same `Task ID:`-only identity, and the single file carries two `RUN_ID` values (`…seq0512`, `…seq0517`) where rule 3 requires one; both cycles are therefore reported as "actual", none as "retained" |

As last period, the exclusion is a *measurement* defect, not an evidence defect: all 6 gate runs are genuine (5 PASS, 1 NEEDS_WORK), ledger-chained (seq 0512–0517), and the Done transitions rest on them legitimately. The fix for exactly this defect is WFI-020 (Approved, not yet applied) — see FP-02.

## Metrics

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| T-001 | 1 | 0 | 0 retained (2 actual: seq 0512 NEEDS_WORK → fix cycle `951764b2` → seq 0517 PASS) | 0 | 0 | 0/0/1 | Done |
| T-002 | 1 | 0 | 0 retained (1 actual: seq 0513 PASS) | 0 | 0 | 0/0/0 | Done |
| T-003 | 1 | 0 | 0 retained (1 actual: seq 0514 PASS) | 0 | 0 | 0/0/0 | Done |
| T-004 | 1 | 0 | 0 retained (1 actual: seq 0515 PASS) | 0 | 0 | 0/0/0 | Done |
| T-005 | 1 | 0 | 0 retained (1 actual: seq 0516 PASS) | 0 | 0 | 0/0/0 | Done |
| **Total** | **5** | **0** | **0 retained (6 actual)** | **0** | **0** | **0/0/1** | **5/5 Done** |

_C = Critical, M = Major, Min = Minor_

Reading notes:

- **Task Attempts is 1 for all five tasks and, unlike last period, every report carries the field** — `reports/implementation/design-sync-consent/T-00{1..5}.md` are all `implementation-report/v2` with `Task Attempt Count: 1`. The N/A cells that triggered WFI-003's regression last period did not recur. T-001's QG fix cycle (cycle 1 of 3, within one gate) did not increment the task attempt, correctly: the report was re-issued with a fix-cycle addendum, not re-attempted.
- **Review Rounds is 0 by artifact definition** (rule 2 counts only `T-NNN-review-<n>.md` files; none exist). The independent-review obligation was satisfied through each evidence bundle's `review_verdict` (sdd-evaluator, PASS ×5).
- **Tickets:** RT-20260805-003 (minor, `auto_fix_allowed: true`, status open) — two assertion-strength gaps in T-001's suite found by the T-002 evaluator's mutation testing (TEST-026 redirect-style bypass stays green; TEST-043 survives deletion). This is the mutation-testing layer of the gate producing yield, not an escaped defect: the shipped SKILL.md text satisfies the ACs by direct inspection in both cases. RT-20260805-001/-002 (major) target feature `mcp-readonly-preflight` and are out of this feature's scope.
- **Model Escalations is 0** with complete evidence: every report records the five escalation fields explicitly as `None` rather than omitting them.
- **Model mix (run-record confound metadata):** implementation ran on claude-sonnet-5 for T-001/T-003/T-004/T-005 and claude-opus-5 for T-002; all six evaluator runs were claude-fable-5. The emitted run record carries `main: claude-sonnet-5`; T-002's opus exception is recorded here because the record's schema takes one id.

## Friction Patterns

### FP-01: Frozen evidence prose carries wrong numbers that the evaluator must re-measure — 6 Minors across 4 tasks, the direct continuation of last period's FP-02 (Regressed WFI-006 class)

- **Evidence:** T-001 cycle-2 Minor 3 (`marker-fix-evidence.md:15-16` prose says "one header comment and eight message strings"; its own tables and the evaluator both measure 4 comment + 6 message lines per file). T-002 Minor 4 ("preserved verbatim" overstates: the Finalize paragraph gained a clause; only the Mockup-Status token is byte-preserved). T-004 Minor 1 (draft/live line & byte counts each inflated by one; the load-bearing single-hunk conclusion still correct). T-005 Minors 1–3 (stale "47 occurrences" vs measured 62; ps1 abort placement "~24 of 32" vs actual 9 of 35; line numbers conflated with array positions in the run-all evidence).
- **Frequency:** 6 findings, 4 of 5 tasks, both QG waves (seq 0513–0517).
- **Phase:** implementation-time evidence authoring, read at gate time.
- **Confidence:** High — every instance is a quoted file:line the evaluator contradicted with a first-hand measurement, and the same class produced 7 findings in the previous feature.
- **Do Not Overfit:** Not one careless author — four different implementation agents across two models produced the class, and the previous period's count (7, different feature, different agents) rules out a task-local explanation. The gate absorbs it correctly (evaluators record measured values in the gate report and never edit frozen evidence), so the cost is Minor-noise and evaluator re-measurement time, not wrong Dones. This is the recurrence condition that already set WFI-006 `Regressed` last period; its follow-up WFI remains undrafted (see Outstanding Work). Distinct improvement inside the same class: zero *stale-tree narrative* claims this period (last period's dominant sub-class) — what remains is numeric/provenance imprecision authored wrong the first time.

### FP-02: The machine-readable identity contract is still unmet — third consecutive feature in which deterministic consumers cannot associate gate artifacts, and one newly observed facet

- **Evidence:**
  1. All 5 QG reports write `Task ID: T-NNN` (satisfying `check-evidence-bundle`) but not the `Task: T-NNN` line that both artifact rule 3 and `emit-run-record.sh` (`grep -q "Task: ${tid}\b"`) key on. Retained count 0 of 5; the run record emitted with this retrospective consequently records `gate_reports.total: 0` and `first_pass_gate.passed_first_try: 0` against a manual tally of 6 runs / 5 tasks / 4 first-try passes. Last period the same divergence was 1 vs 6.
  2. **New facet:** `docs/review-tickets/RT-20260805-003.yml` writes `feature: "design-sync-consent"` (quoted); `emit-run-record.sh`'s ticket scope grep matches only the bare slug (`^[[:space:]]*feature:[[:space:]]*design-sync-consent[[:space:]]*$`), so the run record counts 0 tickets against an actual 1. The two consumers (`check-evidence-bundle` accepts what `emit-run-record` cannot parse; YAML-quoting is valid for one, invisible to the other) now disagree on two artifact types.
- **Frequency:** 5 gate reports + 1 ticket + 1 run record this period; all 5 tasks.
- **Phase:** gate-report/ticket authoring → run-record emission → retrospective measurement.
- **Confidence:** High — deterministic, reproduced against `emit-run-record.sh:125-131` and the ticket-scope grep.
- **Do Not Overfit:** This is the already-diagnosed WFI-005/WFI-010-Regressed root cause ("artifacts satisfy the human reader, not the parser"), and its fix — WFI-020, which normalizes the identity contract — is **Approved and awaiting application**. No new WFI is drafted for facet 1 (it would duplicate WFI-020). Facet 2 (quoted YAML values) is recorded here so WFI-020's application pass can fold it in: whoever applies WFI-020 should either unquote the ticket template's `feature:` value or make the two greps quote-tolerant, and should extend `emit-run-record`'s association test fixtures with a quoted-value case.

### FP-03: Detection artifacts becoming their own false positives — one full QG cycle spent, and the class also touched this retrospective's own tooling

- **Evidence:** (1) T-001 gate cycle 1 (seq 0512) returned NEEDS_WORK on one Major: the new suite embedded two of its three banned markers as contiguous literals in its own comments and pass/fail messages, violating `acceptance-tests.md:172`'s explicitly stated self-false-positive authoring constraint; fixed in `951764b2` by runtime assembly (displayed strings byte-identical, logs diff-empty). (2) WFI-022's own authoring note (2026-08-04) records that the approval-guard WFI could only be written using the split-form technique WFI-012 rule 2 prescribes — the guard would otherwise refuse the file that documents it. (3) During this retrospective (2026-08-05), the PreToolUse hook guard denied a read-only Bash command whose *text* mentioned installed-plugin paths — the same command-text substring class the previous retrospective's environment note recorded; handled by restructuring the command, no bypass.
- **Frequency:** 2 in-period occurrences on independent surfaces (test suite, WFI document), plus 1 tooling occurrence during measurement.
- **Phase:** authoring of detection artifacts (assertion suites, guard-adjacent documents); command-level guard evaluation.
- **Confidence:** Medium — recurring shape, but the T-001 instance is a compliance failure against a constraint the spec already stated (the rule existed and was violated anyway), and the guard-side instances are already the subject of WFI-022 (Draft).
- **Do Not Overfit:** No new WFI. The guard-matcher side is precisely WFI-022's scope; the suite-authoring side is a single-task compliance miss whose constraint, fix technique (runtime assembly), and non-vacuity proof (pre-fix sweep found 7 contiguous occurrences per runtime) are all now demonstrated in-repo. If a third authoring-side violation appears in a future feature despite the worked example, that recurrence should feed a WFI on authoring-time linting (e.g. registering the marker sweep as a pre-commit check).

### FP-04 (recorded for visibility, no WFI — covered by an existing Draft): review-round volume driven by decision-propagation drift

Spec review consumed 2 attempts / 5 rounds (attempt 1 passed at round 3; the design open-question amendment `a55da724` correctly re-opened review as attempt 2, which passed at round 2), task review 3 rounds (round-1 TASK-SIZE finding split T-001 and created T-005; round-2 TEST-TYPE-MATCH on T-003), impl review 3 rounds — 11 review rounds for one feature. WFI-023 (Draft) already names this feature's NEEDS_WORK rounds as its own Problem Evidence (recorded-decision-not-propagated shape) and is the vehicle for it; duplicating it here would violate adoption hygiene. One definitional observation, mirror-image of last period's impl-review note: `spec_review_rounds_per_feature` = 2 (final passing contract) cannot see the burned attempt-1 rounds; total rounds consumed is the honest workload figure and is recorded here.

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| — | — | No WFI is recorded in this table. | — |

Per the Improvement Loop, a WFI enters this table only after `wfi-audit-cycle` sets `Audit-Status: Human-Pending`. This retrospective drafts none, deliberately:

- FP-02's fix already exists (WFI-020, Approved — application pending) and FP-04's already exists as a Draft (WFI-023). Drafting duplicates is prohibited by the skill.
- FP-01 clears the two-task/two-period recurrence bar and **is a mandatory follow-up candidate** (it is the Regressed WFI-006's condition recurring), but the improvement pipeline currently holds 6 Approved-unapplied WFIs (012–015, 020, 021) and 2 unaudited Drafts (022, 023), WFI numbering is contended across unmerged branches (018/019 live on `feature/epic-189-a1-project-context`; 020–023 on this branch), and parallel WFI-scoped agents are active in this session. Adding an eighth in-flight WFI now would violate the adoption-hygiene rule's intent (attribution windows) and risk a numbering collision. The candidate, its evidence, and its baseline are fixed below so drafting (as the next free number at drafting time) can proceed cleanly once the queue drains — see Outstanding Work.

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| WFI-020 (Approved, pre-application baseline re-fixed) | run-record `gate_reports.total` equals the retrospective's actual gate-run tally; ticket tally equals actual | 0 vs 6 runs; 0 vs 1 ticket (this period) | equal on both | first completed feature after WFI-020 is applied |
| pending (FP-01 follow-up, WFI-006 lineage) | evidence-prose numeric-imprecision Minors per feature (evaluator-contradicted measured values) | 6 (this period; 7 previous period) | ≤ 2 | next completed feature |
| WFI-023 (Draft) | NEEDS_WORK review rounds caused by unpropagated recorded decisions, per feature | ≥ 4 of the 8 findings it cites are this feature's (5 spec + 2 task NEEDS_WORK rounds consumed) | ≤ 1 round | next completed feature after WFI-023 is approved and applied |
| (closed) FP-03 previous period — gate cycles lost to an invalidated review-context manifest | manifest re-reservation losses | 1 (previous period) | 0 | **met this period: 0** — all reservations seq 0491–0517 were single-shot; no manifest was invalidated |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| design-sync-consent | 2 (attempt 2; attempt 1 passed at round 3, re-opened by design amendment — 5 rounds total) | PASS | 3 | PASS | 3 | PASS | false |

- `spec_review_rounds_per_feature` = 2 · `spec_review_blocked_rate` = 0 % (no BLOCKED verdict in any of the 5 contracts)
- `task_review_rounds_per_feature` = 3 · `task_review_blocked_rate` = 0 %
- `impl_review_rounds_per_feature` = 3 · `impl_review_blocked_rate` = 0 % · `impl_review_legacy_design_rate` = 0 % (`legacy_design: false` in all 3 contracts)

## Comparison With Previous Retrospective

Previous: `reports/retrospective/2026-07-29T235934Z-epic-136-phase4-mcp.md` (epic-136-phase4-mcp, 5 tasks).

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | 1.2 (6 runs / 5 tasks) | 1.2 (6 runs / 5 tasks) | flat |
| Avg Task Attempts | 1.5 (only 2 of 5 reports carried the field) | 1.0 (all 5 reports carry the field) | improved (value and data completeness) |
| Avg Review Rounds | 0 (artifact definition) | 0 (artifact definition) | flat |
| Avg Quality-Gate Runs | 1.2 actual / 0.2 retained | 1.2 actual / 0 retained | flat actual; worsened retained (see FP-02) |
| Total Model Escalations | 0 | 0 | flat |
| Total Blocked Count | 0 | 0 | flat |
| Total Review Tickets | 0 | 1 (minor, auto-fixable, open) | worsened nominally — the ticket is mutation-testing yield against a test artifact, not an escaped behavior defect |
| Auto-fix Rate | N/A (no tickets) | N/A (1 auto-fixable ticket, not yet resolved) | N/A |
| Avg Spec Review Rounds | 2 | 2 (final attempt; 5 rounds across 2 attempts) | flat by the metric; heavier by total rounds |
| Spec Review Blocked Rate | 0 % | 0 % | flat |
| Avg Task Review Rounds | 1 | 3 | worsened |
| Task Review Blocked Rate | 0 % | 0 % | flat |
| Avg Impl Review Rounds | 1 (final attempt; attempt 1 burned 3 rounds to the BLOCKED cap — 4 total) | 3 (single attempt) | worsened by the metric; improved on total rounds (4 → 3) and no burned attempt |
| Impl Review Blocked Rate | 0 % | 0 % | flat |
| Impl Legacy Design Rate | 0 % | 0 % | flat |
| Repeat Finding Rate | 5 of 9 retention entries recurred (56 %) | 0 of 4 retention entries recurred (0 %) | improved |
| WFI Verification Rate | reported as 6 Verified / 15 (40 %) — not reproducible from current file statuses, which give 4 / 21 pre-this-retrospective; recorded, not repaired | 5 Verified / 21 on this branch after this retrospective (WFI-017 newly Verified; 018/019 live on an unmerged branch and are excluded) | improved on the reproducible basis (4→5 / 21) |

**Model-change caveat, binding on every row above.** The previous period ran `main: claude-opus-5` / `reviewers: claude-opus-5`; this period ran main claude-sonnet-5 (T-002 claude-opus-5) with claude-fable-5 evaluators. Per the Improvement Loop, no improved row may be credited to a WFI and no worsened row blamed on one. The task/impl review-round shifts in particular have obvious non-model, non-WFI explanations: this feature's task decomposition was reshaped mid-review (T-001 split), and its spec was amended after its first PASS.

## Applied WFI Horizon Check

| WFI-ID | Target-Metric | Baseline | Target | Current | Horizon | Classification |
|---|---|---|---|---|---|---|
| WFI-009 | cross-model panel rounds returning NEEDS_WORK/FAIL for evidence-completeness reasons per feature (count) | 2 (epic-136-phase1-guards, 2026-07-12) | 0 | not measurable | next completed feature retrospective with ≥1 `Cross-Model: enabled` task | Applied (horizon not yet opened) |
| WFI-016 | impl-review-status guard denials blocking a design.md status write despite an existing PASS verdict, per completed feature | 1 (epic-191, 2026-07-22) | 0 | 0 artifact-recorded (1 of 2 window features observed since the fix amendment) | next 2 impl-review-passing features after application | Applied (horizon re-opened; see note) |
| WFI-017 | committed implementation reports whose outputs-section contract the validator rejects despite conforming to the canonical template or an accepted historical form | every table-only report rejected (2026-07-23) | 0 | 0 | this change's verification run, then the next completed feature's retrospective | **Verified** |

- **WFI-009** — no task in design-sync-consent declares `Cross-Model: enabled` (all five: `Cross-Model: not enabled`), so no panel ran and neither direction nor target is observable. Same disposition as last period; horizon remains open.
- **WFI-016** — the originally applied batch (2026-07-22) was amended *inside its own horizon window*: `848e46d1` (2026-08-01, PR #208, "WFI-016 hook-guard CWD verdict resolution + v1.11.1 release") fixed a CWD-relative verdict-glob false-deny mode in the same guard — i.e. the failure mode demonstrably survived the first application in a worktree context, and the enforcement chain additionally ran a stale installed plugin (1.10.x) for part of the window (previous retrospective's environment note). Per the Improvement Loop's confound rule (a changed measurement substrate between baseline and checkpoint invalidates the comparison — note and extend rather than classify), the horizon is restarted at `848e46d1`: design-sync-consent is window feature 1 of 2 (impl-review passed, `design.md:3` status write succeeded, zero denials recorded in any artifact). One caveat is binding on the next check: "session-reported guard deny" is not durably artifacted, so an absence of recorded denials is weaker evidence than a recorded zero. WFI-016's file is left untouched (still `Applied`).
- **WFI-017** — target met with first-hand evidence: all five implementation reports are v2 table-form; T-001's post-fix-cycle re-validation returned `IMPLEMENTATION_REPORT_OK` (recorded in the T-001 gate report, hash `330baec4`); zero format-retrofit commits exist in the feature's history (contrast: 2 last period). Secondary observation recorded honestly: `template-validator-parity.tests.sh` is registered in CI but **not** in `tests/run-all.sh` (the 57-suite clean-worktree regression log contains no such entry), so this period's parity evidence is the validator's real acceptance of real reports rather than a same-run parity leg; the last recorded parity green is the 2026-07-23 verification run (12/12 both twins). Status set to `Verified`; recurrence condition registered in the retention checklist. Registering the parity suite in `run-all` is a cheap hardening candidate for whoever next touches test registration.

## Retention Check

| Source WFI | Recurrence Condition | Recurred? | Evidence |
|---|---|---|---|
| WFI-002 | manual precheck / manual review-gate run in `reports/` without a `manual-precheck-note.md` deviation record | No | every review and gate ran through its skill with a reserved ledger identity (seq 0491–0517); no manual substitution appears in any report |
| WFI-007 | implementation report first-committed outside its canonical path and moved at gate time, or an evaluator-boundary report-path PATH failure | No | all 5 reports were first-committed at `reports/implementation/design-sync-consent/T-00N.md` in `5cb08486` (pure additions, no rename in history); no PATH failure recorded in any gate report |
| WFI-008 | evidence bundle references a non-git-tracked artifact path, or a bundle-check detects a missing artifact | No | all 36 repo-relative artifact paths across the 5 `T-00N.evidence.json` bundles pass `git ls-files --error-unmatch`; every gate decision records the contract/bundle checks passing |
| WFI-011 | a concrete claim about existing repository behaviour in investigation/requirements/design proven wrong at implementation-time grep | No | no gate finding of that class. Near-miss recorded for transparency: `design.md:105-106` vs `:185` is a *design-internal* contradiction (D-1, adjudicated against requirements.md:38 and AC-026; spec-level amendment owed to the human follow-up list), not a false claim about pre-existing repository behaviour |

0 of 4 registered conditions recurred (previous period: 5 of 9). Additionally, per the Horizon Check, WFI-017's recurrence condition was **added** to `docs/workflow-improvements/retention-checklist.md` in this retrospective. The five conditions removed last period (WFI-001/003/005/006/010) are no longer monitored by this table — but note that FP-01 and FP-02 above are exactly the WFI-006 and WFI-005/010 classes continuing; monitoring for them resumes when their follow-up WFIs (the FP-01 candidate, and Approved WFI-020) are applied and verified.

## Run Record

Emitted alongside this report per the skill: `reports/runs/RUN-<timestamp>-design-sync-consent.json` (`--track full --model-main claude-sonnet-5 --model-reviewers claude-fable-5 --plugin-version 1.13.0`; active WFIs at emission: 009, 016). Known, tracked divergences between the record and this report's manual tallies — `gate_reports.total` 0 vs 6 and `review_tickets.minor` 0 vs 1 — are FP-02's evidence, not counting errors here; do not hand-edit the JSON. A model change (opus-5 → sonnet-5 main) occurred since the previous record; metric shifts across it must not be attributed to WFIs.

## Environment note (not a metric)

During this retrospective the PreToolUse hook guard denied one read-only Bash command on a command-text substring match (a query that mentioned installed-plugin file paths). The command was restructured and re-run; no guard was bypassed. This is the same class as the previous retrospective's environment note and as WFI-022's Bash-path evidence — recorded here as one more instance for that Draft's eventual audit.

## Outstanding Work

1. **FP-01 follow-up WFI (WFI-006 lineage, mandatory candidate).** Evidence and baseline are fixed in this report (6 findings, 4 tasks; target ≤ 2). Draft it as the next free WFI number *re-derived at drafting time* (018/019 and 020–023 are taken across branches), route it through `wfi-audit-cycle`, and keep it to one WFI — the likely shape is an evidence-authoring rule ("every count/position/size in evidence prose must be produced by the recorded command, not recalled") in project-side workflow files.
2. **WFI-020 application** should fold in FP-02 facet 2 (quoted `feature:` values in ticket YAML defeat `emit-run-record`'s scope grep) and add a quoted-value fixture to the association tests.
3. **Queue hygiene:** 6 Approved WFIs (012–015, 020, 021) await application one-per-window; WFI-022/023 await audit cycles. This retrospective deliberately added nothing to the queue.
4. **Small hardening candidate:** register `tests/template-validator-parity.tests.sh` in `tests/run-all.sh` so WFI-017's secondary signal travels with the clean-worktree regression rather than CI only.

## Boundaries observed

This retrospective modified no application code, no task status field, no frozen document, and no review ticket, and invoked neither `quality-gate` nor `fix-by-review-ticket`. Writes performed, all mandated by the skill: this report; `docs/workflow-improvements/WFI-017.md` (Status → Verified, Result appended); `docs/workflow-improvements/retention-checklist.md` (WFI-017 row added); the emitted run record. No commit was made; no WFI status was set to the human-only approval value.
