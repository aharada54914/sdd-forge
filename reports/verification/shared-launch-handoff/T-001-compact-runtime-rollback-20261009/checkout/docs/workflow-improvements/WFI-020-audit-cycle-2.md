# WFI Audit Report — Cycle 2

| Field | Value |
|---|---|
| WFI-ID | WFI-020 |
| Cycle | 2 (impact and risk) |
| Auditor slot | b (`wfi-auditor-b`) |
| Category at audit time | measurement (reclassified to `plugin-improvement` by the revision below) |
| Verdict | **BLOCKED** |
| Findings | **1 Critical** / 1 Major / 1 Minor (+1 SKIP) |
| Audit attempt | 1 of 3 |
| Generated | 2026-07-30T01:10:00Z |

Raw auditor output: `docs/workflow-improvements/WFI-020-auditor-b.json`.
Cycle 1 inputs were withheld from this auditor by charter; it received only
`WFI-020-integrated-summary.json` (check IDs and counts).

## Check results

| Check | Result |
|---|---|
| VERIFICATION-COMPLETE | PASS |
| SCOPE-PROPORTIONAL | PASS |
| UNINTENDED-CONSEQUENCES | **FAIL** (Major) |
| FEASIBILITY-WITHOUT-PLUGINS | **FAIL (Critical)** |
| CATEGORY-LANGUAGE-SECOND-PASS | PASS |
| EFFECT-CONSISTENT-WITH-EVIDENCE | **FAIL** (Minor) |
| ISSUE-BODY-QUALITY | SKIP |
| META-CHANGE-ANTI-GOODHART | PASS |

## The Critical finding

**FEASIBILITY-WITHOUT-PLUGINS.** The WFI could not achieve its own Expected
Effect, because it proposed extending the weaker of two mechanisms while the
stronger one already existed, unused, a few directories away.

`plugins/sdd-quality-loop/templates/quality-report.template.md` exists. Its first
three lines are `Task ID: {{task_id}}`, `Feature: {{feature}}`,
`VERDICT: {{verdict}}` — exactly the fields commit `7b7faa23` retrofitted by hand
in this feature. WFI-005 extended it (`c3a7a16d`) and its parity test still
passes (10/10 at audit time). But nothing references it: `grep -rl
"quality-report.template" plugins/` returns zero hits, and `quality-gate/SKILL.md`
step 15 tells the authoring agent the opposite — "no separate template file
exists for this report" — text added in `825d6c66` on 2026-07-19, eleven days
after the template was extended and seven days after WFI-005 had verified 100%
compliance using it.

The auditor's census over all 135 `reports/quality-gate/*.md` files quantifies
what that disconnection cost:

| Fields | Backed by | Compliance |
|---|---|---|
| `Task ID:` / `Feature:` / `VERDICT:` | the orphaned template | 134/135, 133/135, 134/135 |
| `Task:` / `Run ID:` | AGENTS.md prose only | 69/135, 74/135 |
| `Critical:` / `Major:` / `Minor:` | nothing | 80/135 each |

The draft proposed adding five more fields to the ~50% column. It also planned to
defer the plugin-side fix to "the GitHub Issue this WFI produces" — which
`wfi-audit-cycle` STEP 8 would never have produced, because it branches only on
`plugin-improvement` and has no branch for `measurement`.

**Independently re-verified by the orchestrator before revising**: the template
exists with those exact three header lines; `grep -rl "quality-report.template"
plugins/` returns nothing; `quality-gate/SKILL.md:201-202` carries the false
claim verbatim. The finding holds in full.

## The Major and Minor findings

- **UNINTENDED-CONSEQUENCES (Major).** The proposed rule was not scoped to
  future reports. 66 of 135 existing gate reports lack a `Task:` line under the
  *current* narrower rule, so an unscoped "must carry" reads as licence to
  retrofit frozen evidence — which WFI-008 (`Status: Verified`) and
  `docs/THREAT-MODEL.md:136` both prohibit, and which WFI-010's Result records as
  already decided against.
- **EFFECT-CONSISTENT-WITH-EVIDENCE (Minor).** A single-feature horizon is
  fragile for a mechanism that has already oscillated twice (WFI-003 compliant
  then regressed; WFI-010's remedy held three features then regressed this
  period). Wave 8b's issues #133/#134 are both `documentation`-labelled, so the
  sample is likely small.
- **ISSUE-BODY-QUALITY (SKIP).** Not a content defect — a process gap. The check
  has branches for `plugin-improvement` and `app-dev-efficiency` only, so
  `measurement` fell through it, mirroring the STEP 8 gap above.

## Revisions applied

All five `proposed_revisions` were applied.

| # | Section | Applied |
|---|---|---|
| 1 | `## Category` | Reclassified `measurement` → `plugin-improvement`, with the earlier reasoning kept visible rather than deleted. `Meta-Change: true` **retained**, so the reclassification buys the GitHub-Issue lane without buying a weaker audit. |
| 2 | `## Category` | Precedent claim corrected: WFI-003 was *forcibly* reclassified (the category did not exist on its branch), so there are **three** genuine precedents, not four. The draft had overstated the convention. |
| 3 | `## Root Cause Hypothesis` | Rewritten around the orphaned template, including the compliance census table and the `Task:` / `Task ID:` field-name split between `emit-run-record.sh:129` and `check-evidence-bundle.sh:201`. |
| 4 | `## Proposed Change` | Retargeted at the plugin: delete the false SKILL.md claim and point step 15 at the template; extend the template and its parity test to the five uncovered fields; reconcile the two scripts onto one canonical field name. Added an explicit **forward-only** scoping paragraph naming WFI-008 and the threat model. |
| 5 | `## Verification Metric` / `## Verification Plan` / `## Rollback-Plan` | Horizon extended to two consecutive features. Rollback-Plan rewritten for the new target set (the old text still said "only AGENTS.md and CLAUDE.md", stale on both counts) and now states the revert's real consequences instead of claiming it is free. |

## State after this cycle

Per the Cycle 2 BLOCKED procedure: `Audit-Attempt: 1`, `Audit-Status: Not-Started`.
Attempt 2 may be started by re-invoking `/sdd-quality-loop:wfi-audit-cycle WFI-020`;
the limit is 3 attempts. **The WFI is not at `Human-Pending` and does not appear in
the retrospective's Proposed Improvements table** — that table admits a WFI only
after the audit completes.

`Audit-Content-Hash` is deliberately absent, and the reason is recorded in the WFI
itself: this orchestrator applied the revisions *before* writing the field, so the
pre-revision body no longer exists and the true value is unrecoverable. Writing
the post-revision hash would invert the no-change guard and halt attempt 2 with
"unchanged since last BLOCKED" despite a substantial revision. An absent field
fails safe.

## Orchestrator note

`wfi-auditor-b` is read-only by charter and holds no write tool, so it returned
its JSON body and this session persisted it verbatim to `WFI-020-auditor-b.json`.
No check result, severity, finding, or proposed revision was altered.

Worth recording plainly: this session authored WFI-020, and the Critical finding
is that the session's own diagnosis was wrong in a way that would have produced a
fix incapable of working. The audit earned its cost here. The three load-bearing
facts — the template's existence, its orphan status, and the false SKILL.md
claim — were each re-verified against the repository before the revision was
written, because an auditor's report about this session's own work is exactly the
input least safe to accept on trust.
