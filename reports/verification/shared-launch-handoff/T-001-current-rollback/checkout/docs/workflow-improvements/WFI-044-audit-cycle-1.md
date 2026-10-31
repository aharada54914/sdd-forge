# WFI Audit Report — Cycle 1

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-044 |
| Category | app-dev-efficiency |
| Cycle | 1 of 2 |
| Auditor Agent | wfi-auditor-a |
| Verdict | NEEDS_REVISION |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings (Advisory) | 1 |
| Generated | 2026-08-23T14:05:00Z |

## Verdict: NEEDS_REVISION

The analysis is right and the proposal is well-scoped, but three evidence claims do
not survive checking: two line numbers are off by two, the operator inventory is
overcounted by two, and the opening sentence attributes all three defects to the
2026-08-22/23 window when one of them dates to June. Separately, the verification
plan's discriminating step pins two commits that the squash-merge made unreachable,
so it cannot run on CI at all. The defect-2 correction is not merely bookkeeping: it
exposes a second gap the proposal does not close, which the WFI should state.

---

## Check Results

| Check | Result | Severity |
|---|---|---|
| EVIDENCE-CITED | **FAIL** | Major |
| ROOT-CAUSE-PLAUSIBLE | PASS | Major |
| WHY-CHAIN-VALID | PASS | Major |
| CATEGORY-LANGUAGE-MATCH | PASS | Critical |
| CHANGE-CONCRETE | PASS | Major |
| EFFECT-MEASURABLE | PASS | Major |
| VERIFICATION-METRIC-DEFINED | PASS | Major |
| VERIFICATION-PLAN-SPECIFIC | **FAIL** | Major |
| NO-PLUGIN-SCOPE-CREEP | PASS | Critical |

## Findings

### EVIDENCE-CITED — Major

Three evidence defects, all verified against the tree. (1) LINE NUMBERS WRONG. Defect 1 is cited at check-task-state.ps1:113,119. Neither the pre-fix nor the post-fix tree has the sites there: `git show cf1deb88^:plugins/sdd-quality-loop/scripts/check-task-state.ps1 | grep -n isValidApproval` puts $isValidApproval at :115 and $isApproved at :121; on HEAD they are :116 and :122 (now -cmatch). The cited :113,119 match neither tree. Defect 2's cite (check-task-state-lite.ps1:89,94) is correct against cf1deb88^ and is not charged. (2) INVENTORY OVERCOUNTED. The WFI states 1,079 operator sites including 79 -match. A word-boundary token scan over the 51 in-scope files yields 1,077 with 77 -match; the two extra come from prose hyphenations, of which resolve-component-paths.ps1:5 ('excluded-match evidence') is one. The figure appears four times and each must agree. (3) WINDOW CLAIM FALSE FOR DEFECT 2. The WFI opens 'On 2026-08-22/23 three case-parity defects were written into .ps1 files'. Defect 2's -match was NOT written in that window: `git log -S'-match' --reverse -- plugins/sdd-lite/scripts/check-task-state-lite.ps1` returns 708a6362, 2026-06-15, subject 'feat(sdd-lite): add check-task-state-lite.ps1 mirroring sh + ps1 tests'. The in-window edit changed the pattern the operator matched against, not the operator. This matters beyond bookkeeping: 708a6362 WAS a port task, so the rule was applicable and unenforced there -- a second gap the WFI's scope-rebinding does not close, currently unstated.

### VERIFICATION-PLAN-SPECIFIC — Major

Steps 1 and 2 are unrunnable as written. Step 1 requires checking out commit 146debb2 and step 2 requires 4d43dae0. Both are unreachable from main: PR #336 was squash-merged as 409449f0, and `git merge-base --is-ancestor` reports 146debb2, 4d43dae0 and cf1deb88 as NOT ancestors of HEAD. They survive only in a clone that still holds the pre-merge branch, and CI clones fresh -- so the plan's discriminating step, the one the check's whole value rests on, cannot execute on the machine that would run it. Replace the commit pins with a committed fixture derived from cf1deb88^ while that history is still reachable locally, and record the derivation in the fixture header. The remaining steps 3-6 are specific and runnable.

## Proposed Revisions

Applied verbatim by the orchestrator, which is the only entity that writes WFI
content during an audit cycle.

**1. [Major] ## Problem Evidence (defect table)**

Correct defect 1's cite from check-task-state.ps1:113,119 to :115,121, and label the column as pre-fix-tree line numbers relative to cf1deb88^.

**2. [Major] ## Problem Evidence (window claim, Why-2)**

Correct the claim that all three defects were written in-window. Defect 2's -match dates to 708a6362 (2026-06-15). Add a 'when the -match was written' column, state the two-in-window / one-pre-existing split, and note that 708a6362 was itself a port task where the rule applied and no sweep was produced. Mark Why-2 as a fork and say which branch levels 3-4 follow.

**3. [Major] ## Verification Plan (steps 1-2)**

Replace the commit pins 146debb2 and 4d43dae0 with a committed fixture reproducing the three pre-fix sites, and state why: those commits are unreachable from main after the squash-merge, so a plan that checks them out cannot run on CI.

**4. [Minor] ## Problem Evidence (inventory)**

Correct 1,079 to 1,077 and 79 -match to 77 at all four occurrences, name the measurement method, and note the figure is an upper bound because the textual scan also counts operator names inside comments.

**5. [Minor] throughout**

Add a commit-provenance note recording that cf1deb88 / 4d43dae0 / 146debb2 are unreachable from main, collapsed into 409449f0, and that a later reader should diff 409449f0 against its first parent.

**6. [Minor] ## Expected Effect**

Align the baseline denominator with the Verification Metric (3 findings in 1 such change).

**7. [Minor] ## Expected Effect**

Add an explicit out-of-scope paragraph for the branch-2b gap: rebinding the scope does not enforce the rule where it already applied, and diff-scoping means a pre-existing untouched operator is still not caught.

---

## Bridge to Cycle 2

`WFI-044-integrated-summary.json` carries counts and check IDs only. The Cycle-2
auditor (`wfi-auditor-b`) is a fresh isolated agent and does not read this report
or the raw Cycle-1 output.
