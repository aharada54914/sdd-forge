# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | **Session-scoped, WFI-application window** — the approved-WFI application batch (PR #336: WFI-022/025/037/039/042 to Applied) and its review/CI drive, plus PR #328 as the first half of the measurement window for WFI-039 |
| Period | 2026-08-22 – 2026-08-23 |
| Generated | 2026-08-23T125111Z |
| Sample Size | 0 feature tasks (no feature spec advanced this period), 0 new review contracts, 0 QG reports, 0 review tickets; 2 merged PRs (#336, #328's tail), 6 external review findings (2 Codex reviews), 5 WFIs advanced to Applied |
| Data Completeness | **Partial by design** — this is a horizon-check-focused session retrospective (operator-directed); no feature workflow ran, so the per-task metric machinery has nothing to measure. All horizon evidence below is drawn from PR CI history, the deterministic suites landed with the batch, and this session's own operations. |
| Confidence | **High** for every deterministic measurement (suite counts, corpus sweeps, CI round counts — each is a re-runnable command or a linked CI run). **Medium** for the organic-use legs (Edit-path refusal counts), where hook interception in the remote container could not be independently proven. |

## Scope Note (read this before citing the document)

This is a **session retrospective** in the mold of
`2026-08-14T034801Z-pillar-a-wave-session.md`, not a per-feature
`workflow-retrospective` run: the operator directed a verification-horizon
measurement for the WFIs applied on 2026-08-22/23. Its authoritative content
is the Applied WFI Horizon Check, the Retention Check, and the Improvement
Verification Plan rows the applied WFIs' plans require; the per-task metric
tables are structurally empty because no feature tasks ran in the period.

**Horizon-check scope.** The repository carries 24 WFIs at `Status: Applied`.
This check measures the six with period-relevant evidence: the five applied
in this window (022/025/037/039/042) and WFI-012, whose failure class
produced direct observational evidence this period. The remaining 18
Applied WFIs predate this window, accrued no new evidence in it (no feature
workflow ran), and remain owed to the next per-feature retrospective — the
same deferral the pillar-a-wave session retrospective recorded for its
out-of-scope features.

Note for the next WFI audit: `skills/wfi-audit-cycle/SKILL.md` resolves
`retrospective_path` to the newest file in `reports/retrospective/`, so this
document will be that input until a newer one lands; the scope caveat above
applies there too.

## Metrics

No feature tasks ran in this period; the table is intentionally empty.

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| **Total** | 0 | 0 | 0 | 0 | 0 | 0/0/0 | — |

_C = Critical, M = Major, Min = Minor_

## Friction Patterns

Patterns observed across two or more independent occurrences in this period
(single occurrences are listed under Observations, not as patterns).

### FP-01: sync-human-copy-mirrors misclassifies branch-updated applied mirrors as pending

- **Evidence:** (1) 2026-08-22 (PR #328 session): the epic-189-a1
  `apply-human-copy` mirror pair, already applied and then re-updated on the
  working branch, classified `pending` (staged ≠ origin/main-live) and the
  tool refused to re-sync — manual `cp` + `MANIFEST.sha256` row rewrite
  required. (2) 2026-08-23 (PR #336 review round): the same shape for the
  guard-twin mirrors in `specs/epic-136-phase2-gates/human-copy` and
  `specs/epic-189-a1-project-context/human-copy` after the WFI-022 amendment
  — `--check` reported "no stale mirrors" while
  `phase2-guard-invariants.tests.sh` failed byte-identity, and the sync was
  again performed manually (commit 918c6831 records it).
- **Frequency:** 2 occurrences, two different bundles, one day apart
- **Phase:** shared-file editing on a feature branch after a first sync
- **Confidence:** High (both occurrences reproduced deterministically; the
  classifier's staged==origin/main-live test is the mechanism)
- **Do Not Overfit:** the tool's pending-classification is CORRECT for
  un-applied human work; the gap is only the branch-iteration case where the
  same file is edited again after an earlier on-branch sync. A fix must
  preserve the pending-bundle data-loss protection WFI-039 was built around.

### FP-02: case-parity defects in newly authored `.ps1` code, caught only by external review

- **Evidence:** one Codex review (PR #336, 2026-08-22) found three
  case-parity defects in code newly written this window: (1)
  `check-task-state.ps1` annotated-approval `-match` (case-insensitive) vs
  the awk twin (fixed cf1deb88); (2) `task-review-precheck.ps1`
  `Sort-Object -Unique` case folding vs `LC_ALL=C sort -u` (fixed 4d43dae0);
  and (3) the authoring decision that produced (1) — aligning to the lite
  twin's pre-existing `-match` instead of the sh semantics, i.e. the
  AGENTS.md WFI-012 sweep rule existed but was not self-applied during
  authoring.
- **Frequency:** 3 findings, 2 distinct cmdlet/operator layers (exactly the
  two layers the WFI-012 rule enumerates), 1 review
- **Phase:** `.sh`→`.ps1` twin authoring inside plugin-improvement work
- **Confidence:** High (each finding reproduced and fixed with a mis-cased
  negative fixture)
- **Do Not Overfit:** the WFI-012 rule's scope trigger is "full-parity
  translation port tasks"; this window's ps1 edits were amendments inside a
  WFI application, so the rule's checklist was never structurally invoked.
  The gap is the trigger's scope, not the rule's content.

## Observations (single occurrences — recorded, not patterns)

- **Shallow-clone git-pin dependence in test fixtures:** the new
  `task-plan-binding-durability.tests.sh` P3 fixture initially relied on
  `check-workflow-state.sh`'s git pin-commit fallback, which needs full
  history; the loops-routing job's shallow checkout broke it (fixed
  hermetically in 33e90f16). Any future fixture that copies committed
  review evidence carrying stale `plugins/*` pins inherits this trap.
- **Committed MCP dist bundle drift:** editing
  `mcp/sdd-forge-mcp/src/parsers/task-validation.ts` without re-running
  `npm run build` tripped the mcp-tests `git diff --exit-code -- dist/`
  gate (fixed 19b89a7b). Nothing on the editing side points at the
  committed-bundle requirement.
- **Guard read-only short-circuit `$()` blindness (pre-existing, out of
  WFI-022's applied scope):** the WFI-022 amendment (918c6831) closed the
  command-substitution hole in the WFI-approval exemption, but the older
  read-only short-circuit in `_shell_targets_protected_gate_file`
  (`sdd-hook-guard.py:1429` area) uses the same compound/read-only/write
  triple without the executing-syntax disqualifier. Same class, different
  gate; follow-up candidate.

## Proposed Improvements

No new WFI is drafted in this document (drafting requires the full
retrospective 5-Whys flow; this is a horizon-check run). Candidates carried
to the next drafting session, in priority order:

| Candidate | Source | Problem |
|---|---|---|
| sync-tool branch-iteration classification | FP-01 (2 occurrences) | applied mirrors re-edited on a branch require manual sync, silently, while `--check` reports clean |
| WFI-012 trigger scope | FP-02 (3 findings) | the case-sensitivity sweep binds port TASKS; ps1 edits made outside a port task never invoke it |
| fixture-staging class | 2026-08-22 audit session (8 sites, CHANGELOG record) | suites copying wrappers into fixture dirs must also stage `lib/`; 8 sites fixed one-by-one |
| protected-gate read-only short-circuit `$()` | Observation 3 | same executing-syntax blindness the WFI-022 amendment closed, in the neighboring gate |

## Improvement Verification Plan

Rows required by the applied WFIs' own verification plans (WFI-042 plan item
4 and WFI-025 plan item 5 create their rows here), plus the carried rows for
the rest of the batch:

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| WFI-022 | guard refusals of non-approval-granting WFI operations (excl. write-capable shell) | 3 (2026-08-04 reproductions) | 0 | next completed feature whose work applies or advances a WFI |
| WFI-025 | task-stage rebinds attributable solely to a `Status:` transition, per feature | 1.0/feature (3 rebinds / 3 features, pillar-a-wave) | 0 | next 3 features completing the task decomposition review gate |
| WFI-037 | `metrics.reviewer_identity_boundary_blocks` | 2 (seq 402, seq 795) | 0 of 10 | next 10 reviewer/evaluator launches |
| WFI-039 | CI rounds to land a repo-shared-file change (first push → first green), mirror-attributable | 3 (PR #305) | 1 | next 1 more shared-file change (2 of 3 window elapsed) |
| WFI-042 | committed approval lines on which full checker, lite checker, and approver-extraction disagree | 8 + structural split | 0, parity suite green | next 2 features completing the task gate (count already 0 at application) |

## Review Gate Metrics

No review gates ran in this period.

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| — | 0 | — | 0 | — | 0 | — | — |

## Comparison With Previous Retrospective

Not comparable: the previous retrospective
(`2026-08-20T000000Z-sdd-domain-concept-contract.md`) is a per-feature run
with task metrics; this period ran no feature tasks. All comparison cells
are N/A by structure, not by data loss.

## Applied WFI Horizon Check

| WFI-ID | Target-Metric | Baseline | Target | Current | Horizon | Classification |
|---|---|---|---|---|---|---|
| WFI-022 | refusals of non-granting WFI ops (excl. write-capable shell) | 3 | 0 | **0 on the verification-run leg** — the three 2026-08-04 reproductions replayed exit 2 pre-fix / exit 0 post-fix (`guard-parity` `wfi-022:` cases, 71/71); organic leg: 5 WFI status advances + Result edits this window with 0 refusals (hook-interception in the remote container not independently proven, hence Medium confidence on this leg only) | verification run ✓; "next completed feature that applies/advances a WFI" leg open | **Needs-Followup** (metric at target on every measured leg; organic leg awaits a hook-verified cycle) |
| WFI-025 | status-transition rebinds per feature | 1.0/feature | 0 | no data — 0 of 3 window features have completed the task gate; deterministic support: `task-plan-binding-durability` 17/17 incl. the normalized-survives/raw-breaks pair on the unchanged checker | 0/3 elapsed | **Needs-Followup** (window not begun) |
| WFI-037 | reviewer identity-boundary blocks | 2 | 0 of 10 | no data — 0 of 10 launches have occurred; deterministic support: `boundary-reference-authorization-parity` 19/19 | 0/10 elapsed | **Needs-Followup** (window not begun) |
| WFI-039 | CI rounds to land a shared-file change | 3 | 1 | **mirror-attributable rounds: 0 in both window changes.** PR #328 (4 pushes to green) and PR #336 (5 pushes to green) both touched mirrored shared files; NO round in either was a mirror-staleness failure — every push had mirrors synced pre-push by the WFI-039 tooling (`human-copy-mirror-freshness` green on each). The literal first-push→green counts (4, 5) are confounded entirely by non-mirror classes (review fixes, shallow-clone fixture, dist drift, case parity) and are recorded here so the next check does not misread them. Secondary completeness (5 stale locations named at once) and safety (pending bundles untouched) were met at application. | 2/3 window elapsed | **Needs-Followup** (targeted failure class at 0; one more window change for the literal metric on a clean sample) |
| WFI-042 | approval-grammar disagreement lines | 8 + structural split | 0 | **0** — post-migration corpus sweep reads zero non-conforming lines; `task-state-grammar-parity` 12/12 (incl. the mis-cased negative fixture added by amendment); structural split closed in sh+ps1+MCP | verification run ✓ (count 0); "next 2 task-gate features" persistence leg 0/2 | **Needs-Followup** (target met at measurement; persistence leg open — the row exists to keep it 0) |
| WFI-012 | QG cycles lost to ps1 case-sensitivity weakened-port findings, per port task | (per WFI) | decrease | horizon condition unmet (no feature with a `.sh`→`.ps1` port TASK completed this period), **but the failure class recurred outside the trigger's scope**: FP-02's three case-parity findings in newly authored ps1 code, caught by external review rather than the sweep. Recorded as evidence for the FP-02 candidate (widen the trigger), not as a horizon failure of WFI-012 itself. | port-task-feature leg still open | **Needs-Followup** (horizon unmet; class-recurrence evidence attached) |

The 18 other Applied WFIs accrued no evidence this period and are deferred
to the next per-feature retrospective (see Scope Note).

## Retention Check

`docs/workflow-improvements/retention-checklist.md` walked in full (4 active
rows). No recurrence conditions matched this period's evidence:

| Source WFI | Condition class | This period | Verdict |
|---|---|---|---|
| WFI-002 | manual precheck without deviation record | no manual precheck ran | no recurrence |
| WFI-007 | implementation report first-committed off canonical path | no implementation reports created | no recurrence |
| WFI-008 | evidence bundle referencing untracked artifacts | no new feature bundles | no recurrence |
| WFI-011 | spec factual claim falsified at implementation time | no spec→implementation cycle ran | no recurrence |

No WFI transitions to `Regressed`; no checklist rows removed.
