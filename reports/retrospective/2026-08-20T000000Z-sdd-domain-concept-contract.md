# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | sdd-domain-concept-contract |
| Period | 2026-08-16 (`10a889d6`, spec bootstrap) – 2026-08-20 |
| Generated | 2026-08-20T00:00:00Z |
| Sample Size | 5 tasks, 17 review contracts, 9 QG reports (8 retained), 2 tickets |
| Data Completeness | **Partial** — see explanation below |
| Confidence | **High** for FP-01/02/03 (each spans 3+ tasks or 2 independent evidence types); **Low** for FP-04 (single task, no WFI drafted) |

**Data-completeness explanation.** All expected report roots exist and every task
has a current-schema implementation report. One quality-gate artifact is excluded
under Deterministic artifact rule 5: `reports/quality-gate/20260819T101153Z.md`
(T-003) carries **two** `Run ID` values — `Cycle 1 Run ID:` and `Cycle 2 Run ID:`
on lines 14-15 — and no single bare `Run ID:` line. Rule 3 requires exactly one
non-empty `Run ID`, so the report is ambiguous evidence and is excluded rather
than repaired from filename or timestamp. T-003's Quality-Gate Runs are therefore
`N/A`, not `0`: the task demonstrably had two cycles, and the count is
unmeasurable, which is a different fact from zero.

## Metrics

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| T-001 | 1 | N/A | 1 | 0 | 0 | 0/0/0 | Done |
| T-002 | 1 | N/A | 2 | 0 | 0 | 1/0/0 | Done |
| T-003 | 1 | N/A | N/A (excluded, rule 5) | 0 | 0 | 0/0/0 | Done |
| T-004 | 1 | N/A | 3 | 0 | 1 | 0/1/0 | Done |
| T-005 | 1 | N/A | 2 | 0 | 0 | 0/0/0 | Done |
| **Total** | **5** (avg 1.0) | **N/A** | **8 retained / 9 emitted** | **0** | **1** | **1/1/0** | **5 Done** |

_C = Critical, M = Major, Min = Minor_

**Review Rounds is `N/A` for every task, not zero.** Rule 2 counts
`reports/implementation/<feature>/T-NNN-review-<n>.md`; no such artifact exists
for this feature. The independent review that did occur ran as quality-gate
evaluator cycles, which rule 3 counts separately. Recording `0` would imply the
reviews did not happen.

**Model Escalations is a measured 0**, not an absence of evidence: no escalation
transition records appear in any retained artifact.

**Auto-fix rate is 0 % (0 of 2 tickets carry `auto_fix_allowed: true`) — and that
number understates what happened.** Two Majors were fixed in-gate under
`auto-fix-policy.md` "missing tests for clear requirements" (T-003's `\A…\Z`
anchor regression, T-005's AC-025(a) assertion) without a ticket ever being
written. The ticket-derived auto-fix metric cannot see in-gate fixes, so it
reports 0 % for a period in which auto-fix was used twice and succeeded twice.

## Friction Patterns

### FP-01: A frozen declaration cannot describe what the gate itself changes

- **Evidence:** T-004 (`20260819T110000Z`, `20260819T133416Z`), T-005
  (`20260819T152557Z`); implementation-report `## Outputs` tables for both tasks
  stale on the shared suite file; `RT-20260819-001`, `RT-20260819-002`
- **Frequency:** 4 artifacts across 2 tasks, plus 3 stale hash rows
- **Phase:** quality-gate
- **Confidence:** High (2 tasks, 2 independent evidence types)
- **Do Not Overfit:** this is not "two tasks were unlucky". T-001…T-005 extend one
  shared test file by design (design.md line 13). Every gate fix to that file
  invalidates every *later* task's frozen `## Outputs` table, so the last task in
  a sequential decomposition is guaranteed to hit it on its **first** gate —
  which T-005 did. The more effective the gate, the more artifacts it renders
  unreviewable.

### FP-02: The cycle limit counts prose mentions, not cycles

- **Evidence:** all five tasks returned `Escalate-Human`; honest counts were
  1/2/1/3/2 against a limit of 3. T-005 was barred from its **first** gate with 0
  reports of its own.
- **Frequency:** 5 of 5 tasks
- **Phase:** quality-gate (ship Step 4)
- **Confidence:** High
- **Do Not Overfit:** self-inflicting rather than incidental. The gate report
  template mandates `## Out-Of-Scope Waivers` and `## Traceability And Drift`, and
  filling those in honestly means naming sibling tasks. Better reports trip the
  limit sooner.

### FP-03: Roles are told to verify artifacts their allowlist forbids them to read

- **Evidence:** (a) `review-context-boundary.md` prescribes a four-step record-chain
  check as the correct substitute for re-hashing the ledger; three of the four
  steps need `reports/review-context/identity-ledger.json`, which
  `path_is_authorized` grants to no role — measured across all 5 evaluator
  launches. (b) T-005's evaluator could not verify the four INV-004 consumer paths
  because `investigation.md` is granted to spec- and impl-reviewers but not to
  `quality:sdd-evaluator` — measured: `REVIEW_CONTEXT_PATH … role-unlisted`.
- **Frequency:** 2 distinct mechanisms, 6 occurrences
- **Phase:** review-context boundary (all review loops)
- **Confidence:** High (2 independent evidence types)
- **Do Not Overfit:** the two cases share a shape rather than a cause: guidance
  and allowlist are separate surfaces and nothing compares them. The cost is not
  theoretical — sequence 795 is an orphaned reservation created when the
  orchestrator, following the prescribed check, instructed a verification that
  cannot succeed.

### FP-04: A gate report that merges two cycles becomes unmeasurable

- **Evidence:** `reports/quality-gate/20260819T101153Z.md` (T-003) only.
  Corroborated independently by the deterministic run record
  `reports/runs/RUN-20260820T070339Z-sdd-domain-concept-contract.json`, which
  reports `first_pass_gate.passed_first_try: 2`. T-001 is one of those two; the
  other is T-003, which actually consumed two cycles (NEEDS_WORK then PASS, both
  recorded inside the single merged file). The merged report therefore makes a
  two-cycle task indistinguishable from a first-try pass in the machine-readable
  record as well as in the rule-3 rollup. The run record is emitted by
  `emit-run-record.sh` and is **not** edited to correct this, per the skill.
- **Frequency:** 1 task, surfacing in 2 independent measurement paths
- **Phase:** quality-gate reporting
- **Confidence:** **Low** — one task. The second measurement path is the same
  underlying artifact, so it does not raise confidence to Medium.
- **Do Not Overfit:** single-task observation. Recorded under the Improvement Loop
  rule that low-confidence observations may be reported but **must not create a
  WFI**. No WFI is drafted for it.

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| WFI-034 | Draft | Evaluator scratch isolation is behavioural, not structural | quality-gate skill, evaluator role |
| WFI-035 | Draft | Cycle limit counts prose mentions instead of a report's own `Task ID:` | `check-quality-gate-cycle-limit.{sh,ps1}` + parity tests |
| WFI-036 | **Applied** | A gate cycle that fixes a defect cannot review its own fix | `validate-review-context-set.{sh,ps1}`, quality-gate skill, boundary reference |
| WFI-037 | Draft | Boundary reference prescribes a chain check no role can perform | validator `REVIEW_CONTEXT_OK` output, boundary reference, role definitions, parity test |

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| WFI-034 | evaluator scratch artifacts surviving a cycle | 1 (T-002) | 0 | next feature |
| WFI-035 | `metrics.cycle_limit_false_escalations` | 5 of 5 tasks | 0 of 10 | next 10 gate runs |
| WFI-036 | `metrics.evaluator_unauthorized_artifact_reads` | 3 of 3 cycle-2 evaluations | 0 of 10 | next 10 fix-following cycles |
| WFI-037 | `metrics.reviewer_identity_boundary_blocks` | 2 (seq 402, seq 795) | 0 of 10 | next 10 reviewer/evaluator launches |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| sdd-domain-concept-contract | attempt 4, round 2 | PASS | attempt 1, round 2 | PASS | attempt 3, round 1 | PASS | true |

- `spec_review_rounds_per_feature`: 2 (in the passing attempt); 4 attempts consumed
- `task_review_rounds_per_feature`: 2
- `impl_review_rounds_per_feature`: 1 (in the passing attempt); 3 attempts consumed
- `spec/task/impl_review_blocked_rate`: 4 of 17 contracts recorded a BLOCKED
  verdict in intermediate rounds; the feature reached PASS on all three loops, so
  the per-feature blocked rate is 0 %
- `impl_review_legacy_design_rate`: 100 % (1 of 1 feature)

## Comparison With Previous Retrospective

Baseline: `reports/retrospective/2026-08-14T034801Z-pillar-a-wave-session.md`.
That document measured a 6-feature session; this one measures a single 5-task
feature, so scope-sensitive cells are `N/A`.

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| **QG reports retained under rule 3** | **0 of 21** (4th consecutive period at zero) | **8 of 9** | **↑ first non-zero in five periods** |
| Avg QG Cycles per Task | N/A | 2.0 (8 retained / 4 measurable tasks) | new measurement |
| Avg Task Attempts | 1.5 (6 measurable tasks) | 1.0 (5 tasks) | ↓ improved |
| Avg Review Rounds | N/A | N/A | rule-2 artifact absent both periods |
| Avg Quality-Gate Runs | N/A (0 retained) | 2.0 | newly measurable |
| Total Model Escalations | N/A | 0 | new measurement |
| Total Blocked Count | 5 | 1 | ↓ |
| Total Review Tickets | 7 | 2 | ↓ (smaller scope) |
| Auto-fix Rate | 0 % (0 of 7) | 0 % (0 of 2) | flat — but see caveat below |
| Avg Spec Review Rounds | N/A | 2 | new |
| Spec Review Blocked Rate | N/A | 0 % | new |
| Avg Task Review Rounds | N/A | 2 | new |
| Task Review Blocked Rate | N/A | 0 % | new |
| Avg Impl Review Rounds | N/A | 1 | new |
| Impl Review Blocked Rate | N/A | 0 % | new |
| Impl Legacy Design Rate | N/A | 100 % | new |
| Repeat Finding Rate | FP-02 repeated | **0 repeats** — FP-01/03/04 are all new mechanisms | ↓ |
| WFI Verification Rate | N/A | 0 of 9 Applied WFIs reached Verified | flat |

### The one metric that moved, and why — read before crediting anything

The previous four retrospectives all reported **0 quality-gate reports retained**.
That was not a reporting quirk; it meant every shipped feature was unmeasurable by
this process.

Measured cause: `check-evidence-bundle.sh` requires a `Task ID:` header, while
retrospective rule 3 associates reports by a `Task:` identity. Historical reports
carry only the former — verified on three reports from three different features
(`epic-191-a3-path-ownership`, `design-sync-scan`, `epic-136-phase4-docs`): all show
`Task ID=1 Task=0`. This period's reports carry **both** keys, so 8 of 9 retain.

**This is not evidence that a WFI worked.** No WFI targeted it. It is a side effect
of this period's reports being written to satisfy both consumers at once. The
underlying contract conflict is unchanged and will silently reproduce the moment a
report is authored from the older template. Recording it here so the next
retrospective does not mistake it for a durable fix.

The caveat on Auto-fix Rate is the mirror image: it reads 0 % in a period where
auto-fix ran twice successfully, because in-gate fixes produce no ticket. A metric
that cannot see the mechanism it measures is not measuring it.

## Applied WFI Horizon Check

| WFI-ID | Target-Metric | Baseline | Target | Current | Horizon | Classification |
|---|---|---|---|---|---|---|
| WFI-009 | cross-model panel rounds returning NEEDS_WORK/FAIL for evidence-completeness | (see WFI) | (see WFI) | **N/A — no cross-model run this period** | open | Needs-Followup |
| WFI-012 | (WFI-009 successor metric) | (see WFI) | (see WFI) | **N/A — not exercised** | open | Needs-Followup |
| WFI-013 | spec/impl-review findings (Critical or Major) of the named class | (see WFI) | (see WFI) | **N/A — review loops predate this session** | open | Needs-Followup |
| WFI-014 | spec-review Major findings attributable to the named cause | (see WFI) | (see WFI) | **N/A** | open | Needs-Followup |
| WFI-016 | impl-review-status guard denials blocking a legitimate transition | (see WFI) | (see WFI) | 0 observed this period | open | Needs-Followup |
| WFI-021 | independently broken features whose diagnostics are suppressed | (see WFI) | (see WFI) | **N/A** | open | Needs-Followup |
| WFI-023 | (see WFI) | (see WFI) | (see WFI) | **N/A** | open | Needs-Followup |
| WFI-029 | (see WFI) | (see WFI) | (see WFI) | **N/A** | open | Needs-Followup |
| WFI-036 | `metrics.evaluator_unauthorized_artifact_reads` | 3 of 3 cycle-2 evaluations | 0 of 10 | **2 of 2 fix-following cycles authorized from persisted declarations** (T-004 c3 seq 796, T-005 c2 seq 798) | open (10 cycles) | **Needs-Followup — direction improved, target unmet** |

No Applied WFI is classified `Verified` and none is classified `Rejected`.
WFI-036 was applied *during* this period, so 2 of its 10 required cycles are
observed; crediting it now would be exactly the impressionistic classification the
skill forbids.

**`current` is `N/A` rather than a number for seven of nine WFIs** because their
target metrics are not derivable from a single feature's evidence, and
`reports/runs/` has no record newer than `2026-08-05`. That is a real gap in the
attribution baseline, not a formatting choice.

## Retention Check

| Source WFI | Recurrence Condition | Recurred? | Evidence |
|---|---|---|---|
| WFI-002 | manual precheck / manual review gate run without `manual-precheck-note.md` | **No** | 0 matches across this feature's gate and implementation reports |
| WFI-007 | implementation report first-committed off canonical path, or evaluator PATH failure caused by report path | **No** | all 5 reports first-committed at `reports/implementation/sdd-domain-concept-contract/T-NNN.md` in their task's own commit; the PATH failures this period were role-unlisted **artifact** paths, not report paths |
| WFI-008 | evidence bundle references a non-git-tracked artifact | **No** | 0 untracked artifacts across all 5 bundles (`git ls-files --error-unmatch`) |
| WFI-011 | spec-premise factual inaccuracy discovered only at implementation time | **No** | 0 findings of that class in this period's gate reports |
| WFI-017 | canonical implementation report rejected by the outputs contract, or a format-retrofit commit required | **No** | `git log` on the report directory shows exactly 5 commits, one per task, none a retrofit |

All five retention conditions hold. No WFI is set to `Regressed` this period.
