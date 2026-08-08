# WFI Audit Report — Cycle 1

| Field | Value |
|---|---|
| WFI-ID | WFI-020 |
| Cycle | 1 (proposal quality) |
| Auditor slot | a (`wfi-auditor-a`) |
| Category at audit time | measurement |
| Verdict | **NEEDS_REVISION** |
| Findings | 0 Critical / 2 Major / 0 Minor |
| Generated | 2026-07-30T00:47:00Z |

Raw auditor output: `docs/workflow-improvements/WFI-020-auditor-a.json`.
Cycle 2 bridge: `docs/workflow-improvements/WFI-020-integrated-summary.json`
(check IDs and counts only — this report and the raw JSON are both on
`wfi-auditor-b`'s disallowed-paths list).

## Check results

| Check | Result |
|---|---|
| EVIDENCE-CITED | PASS |
| ROOT-CAUSE-PLAUSIBLE | **FAIL** (Major) |
| CATEGORY-LANGUAGE-MATCH | PASS |
| CHANGE-CONCRETE | **FAIL** (Major) |
| EFFECT-MEASURABLE | PASS |
| VERIFICATION-METRIC-DEFINED | PASS |
| VERIFICATION-PLAN-SPECIFIC | PASS |
| NO-PLUGIN-SCOPE-CREEP | PASS |

## Findings

### ROOT-CAUSE-PLAUSIBLE — FAIL (Major)

The draft's central claim, that the parsing contract for quality-gate reports
"was never written down", is contradicted by an existing rule. `AGENTS.md`
§ Rules → "Evidence report identity fields" already requires every
`reports/quality-gate/` report to carry a `Task: T-NNN` line and a `Run ID:`
line — the exact line `emit-run-record.sh:129` greps for. That rule was added by
WFI-003 and predates this feature, and the same retrospective that motivated this
WFI records WFI-003 as `Status: Regressed` precisely because 4 of 5 reports
violated it.

This matters beyond citation hygiene: the draft as written would have converted a
compliance failure into a documentation gap, which is a strictly more flattering
story for the session that produced the failure. The auditor's narrower reading —
that the rule exists but is not cross-referenced from the authoring instruction
the evaluator actually follows, and is therefore invisible at write time — was
verified against `AGENTS.md` and the quality-gate skill's step 15 text.

**Independently re-verified by the orchestrator before applying**:
`grep -n -A4 "Evidence report identity fields" AGENTS.md` returns the rule at
lines 124-129. The finding holds.

### CHANGE-CONCRETE — FAIL (Major)

The draft's second Proposed Change row targeted `CLAUDE.md`, described as "the
file the orchestrator loads by default". That file does not exist in this
repository.

**Independently re-verified by the orchestrator before applying**:
`git ls-files | grep -i '^CLAUDE.md$'` returns nothing and `ls CLAUDE.md` reports
no such file. `AGENTS.md` fills that role here. The row would have been
unexecutable at apply time. The finding holds.

### Non-failing observations the auditor recorded

- **EFFECT-MEASURABLE (PASS, with a citation error).** Expected Effect said gate
  reports were "excluded under artifact rule 5"; the retrospective's own Data
  Exclusions table assigns rule 3 to all 4 excluded gate reports and rule 5 only
  to the unrelated absent impl-review round-2 contract. The WFI's own Problem
  Evidence had already cited rule 3 correctly, so the two sections disagreed.
- **CATEGORY-LANGUAGE-MATCH (PASS, with a precedent conflict).** WFI-003,
  WFI-005, WFI-010 and WFI-017 — all structurally identical report-format-versus-
  parser fixes — unanimously used `Category: plugin-improvement`, all drafted
  after `measurement` was available. WFI-020 is the only WFI in the repository
  using `measurement`.
- **VERIFICATION-METRIC-DEFINED (PASS).** The orchestrator had specifically asked
  whether a Target phrased as "equal to that retrospective's retained
  Quality-Gate Runs total" is falsifiable. The auditor confirmed it is a
  mechanical equality test between two independently derived counts, matches the
  retrospective's own pre-registered row, and matches WFI-010's accepted
  precedent — and noted a fixed number would be *weaker*, since the correct count
  depends on the next feature's task count.

## Revisions applied

All four `proposed_revisions` were applied to `docs/workflow-improvements/WFI-020.md`.

| # | Section | Applied |
|---|---|---|
| 1 | `## Root Cause Hypothesis` | Rewritten. Opens with an explicit correction naming the false claim, quotes the existing `AGENTS.md` rule, and splits the defect into two distinct problems: a **visibility gap** for the fields WFI-003 already specifies, and a **genuine absence** for `Task ID:`, `Feature:`, `VERDICT:` and the three count lines. |
| 2 | `## Proposed Change` | `CLAUDE.md` row removed, with the reason recorded in place rather than silently deleted. The `AGENTS.md` row was additionally rewritten from "add a new rule" to "**extend** the existing § Rules entry", since creating a second competing rule would reproduce this WFI's own root cause. |
| 3 | `## Expected Effect` | rule 5 → rule 3, with the correction noted inline. |
| 4 | `## Category` | Precedent conflict recorded in full. `measurement` **kept**, with the reason stated: reclassifying to `plugin-improvement` would loosen the audit lane (`Meta-Change: true` and the strict lane follow from `measurement`), and a proposal authored by the same session that produced the metric it fixes should not pick the looser lane for itself. Flagged as the human's call, with the instruction to keep `Meta-Change: true` if they do reclassify. |

## Orchestrator note

`wfi-auditor-a` is read-only by charter and holds no write tool, so it returned
its JSON body and this session persisted it verbatim to
`WFI-020-auditor-a.json`. No check result, severity, finding, or proposed
revision was altered. The two Major findings were independently re-verified
against the repository before their revisions were applied, because this session
authored the WFI under audit and an auditor's report about that session's own
work is exactly the input least safe to accept on trust.
