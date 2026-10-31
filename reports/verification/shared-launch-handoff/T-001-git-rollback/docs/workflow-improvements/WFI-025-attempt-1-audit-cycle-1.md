# WFI Audit Report — Cycle 1

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-025 |
| Category | `workflow-correctness` at audit time (reclassified to `plugin-improvement` by the revisions below) |
| Cycle | 1 of 2 |
| Auditor Agent | wfi-auditor-a |
| Verdict | **BLOCKED** |
| Critical Findings | 1 |
| Major Findings | 4 |
| Minor Findings (Advisory) | 1 |
| Generated | 2026-08-10T00:00:00Z |

Raw auditor output: `docs/workflow-improvements/WFI-025-auditor-a.json`.

## Verdict: BLOCKED

The WFI declared `Category: workflow-correctness`, which is not one of the four
categories the classification flowchart defines. Because every language rule and
every scope rule keys off the category, nothing downstream of that field could be
certified, and the auditor correctly refused to pass it.

Six of eight checks failed. Two passed — and notably `ROOT-CAUSE-PLAUSIBLE`
passed even after the auditor was asked to test the root cause against a known
imprecision in the document's narration.

## Findings

### Critical Findings

- [CRITICAL] CATEGORY-LANGUAGE-MATCH — `Category: workflow-correctness` is not a
  recognized value. WFI-025 is the only WFI in the repository using it; the
  flowchart admits only `measurement`, `human-process`, `plugin-improvement` and
  `app-dev-efficiency`. The auditor additionally flagged `Mechanism: script`,
  which is not on the mechanism axis (`instructions | memory | tools |
  architecture | model-routing`).

### Major Findings

- [MAJOR] EVIDENCE-CITED — the three-feature rebind narrative cited no commit,
  path, or ID a reader could check.
- [MAJOR] CHANGE-CONCRETE — `## Proposed Change` was a prose list, not a Target
  File / Change Description table.
- [MAJOR] NO-PLUGIN-SCOPE-CREEP — every target resolves to a path inside
  `plugins/`.
- [MAJOR] VERIFICATION-METRIC-DEFINED — baseline not traceable to a
  retrospective row; "the next full epic run" is not a quantified checkpoint.

### Minor Findings (Advisory)

- [MINOR] VERIFICATION-PLAN-SPECIFIC — all four plan items were code tests; none
  named the retrospective metric row that would carry the measurement forward.

## Orchestrator verification of the audit

Two of the auditor's findings were checked against the repository before being
acted on, and one of its proposed revisions was rejected as unsound.

**The `plugins/` carve-out was missed.** `wfi-auditor-a.md:129-154` carries an
explicit carve-out: a `plugins/` path is *not* a finding when the WFI declares
`Category: plugin-improvement`, states in its `## Category` section that this
repository is the plugin's source of truth and that the change travels as a
repository commit, and carries a `## GitHub-Issue` section. The check text
requires an auditor applying it to say so and name the conditions verified — and,
by the same logic, a silent non-application is indistinguishable from a missed
check. The auditor never mentioned the carve-out.

That matters because the carve-out's own provenance note records it was added by
human decision on 2026-08-03 to resolve exactly this failure, which WFI-020 hit
twice. WFI-020's attempt-2 was BLOCKED at Cycle 1 with the identical triple —
Critical CATEGORY-LANGUAGE-MATCH plus Major CHANGE-CONCRETE and
NO-PLUGIN-SCOPE-CREEP for naming `plugins/` paths.

**The proposed category was wrong.** The auditor recommended `measurement`,
reasoning from the WFI's own self-description ("changes what a deterministic gate
accepts as a valid binding") rather than from the flowchart's actual test, which
is *anything that MEASURES the workflow* — graders, thresholds, retrospective or
audit logic, run-record definitions. A provenance digest binds document identity;
it grades nothing and feeds no metric. Q1 is NO. Q2 (approval policy, escalation,
what humans review) is NO. Q3 is YES on its second clause: this is a cross-plugin
handoff, the producing side living in the review gate plugin and the accepting
side in the quality verification gate plugin, and the defect *is* their
disagreement. The correct category is `plugin-improvement`.

Taking the auditor's recommendation would have been actively harmful. Under
`measurement` the carve-out is unavailable by its own terms ("For every other
Category — `app-dev-efficiency`, `human-process`, `measurement` — a `plugins/`
path remains a Major finding with no exception"), so its third proposed revision
followed: strip the real targets out of the WFI and route them elsewhere. For a
change that is *only* a plugin script change, in the repository that is the
plugin's source of truth, that produces a WFI which cannot name what it does —
the precise unsatisfiability the carve-out exists to prevent.

**Two evidence citations were wrong.** The auditor's `## Problem Evidence`
revision paired commit `39065c9b` with
`.../epic-190-a2-capability-registry/attempt-5/round-1/precheck-result.json`.
Both commits it named are real (`git cat-file -t` confirms; the messages match
its quotations), but `git ls-tree` at `39065c9b` shows only `attempt-1` and
`attempt-4` — the attempt-5 artifact first appears at `340f0149`, whose message
("pass T-007, escalate T-005 and T-006, re-bind the plan") is the rebind the WFI
actually describes. The `epic-191-a3` citation was given with no commit at all;
`726a5a0c` is the one. Only the `epic-194-a6` pairing was correct as written.
The corrected triple was written into the WFI; the auditor's was not.

## Revisions applied

| # | Section | Applied |
|---|---|---|
| 1 | `## Category` | `plugin-improvement` (not the auditor's `measurement`), with the flowchart walk recorded as a comment and the carve-out's source-of-truth statement written in prose. `Meta-Change: true` retained, per the WFI-020 precedent, so the classification buys the tracking-issue lane without buying a weaker audit. |
| 2 | `## Mechanism` | `script` → `tools`, as the auditor found. |
| 3 | `## GitHub-Issue` | `N/A` → `Pending — filed against this repository on human approval`, satisfying carve-out condition 3. The session did not open the issue: creating public content is a human-authorized action and no authorization was given. |
| 4 | `## Problem Evidence` | Corrected citations added (commits `340f0149`, `b836a11e`, `726a5a0c` with their artifact paths), plus an explicit note that these are primary artifacts rather than retrospective rows and why. The auditor's suggestion to file an RT ticket was not taken — item 5 of the Verification Plan addresses the same gap structurally. |
| 5 | `## Problem Evidence` | **Orchestrator-initiated.** The claim that forms 1/3/4 "all require the file's statuses to be uniform" was mechanically wrong — those forms are well-defined on any file. Rewritten around the real mechanism: a raw digest survives a flip only when normalization was already a no-op when it was taken. The reproduction paragraph now carries the actual digests and the `reviewed_hash_accepted` replay result. |
| 6 | `## Root Cause Hypothesis` | Rewritten to survive that correction. The durable forms are not dead code — they are load-bearing on the re-review path, where a uniform plan makes raw coincide with form 3 or 4. The defect is narrower and truer: their invariance is a property of the file's state when the digest was taken, never something the producer can choose. |
| 7 | `## Proposed Change` | Reformatted as a Target File / Change Description table, keeping the real `plugins/` paths under the carve-out. Added the `Meta-Change` non-decreasing guard and an explicit anti-Goodhart paragraph. |
| 8 | `## Expected Effect` | Feature slugs replaced with generic terms per Section 2, retaining the numbers: attempts 5, 3 and 5 → 1, average 4.3 → 1.0. |
| 9 | `## Verification Metric` | Baseline sourcing stated honestly (direct observation, not a retrospective row, with the reason no such row exists); checkpoint quantified to the next 3 features. |
| 10 | `## Verification Plan` | Item 4 extended with a negative case that binds the new cross-check itself. Item 5 added for the retrospective metric row. |
| 11 | `## Rollback-Plan` | Extended to state that the accepting side was never modified, so nothing needs un-widening, and that `tasks_sha256_form` becomes inert. |

## State after this cycle

Cycle 1 returned BLOCKED. `wfi-audit-cycle` STEP 4's BLOCKED path would halt here
and require a fresh attempt starting again at Cycle 1. This session instead
applied the revisions and continued to Cycle 2, on the operator's explicit
instruction to run both cycles. The deviation is recorded rather than hidden:
`Audit-Attempt: 1` is set on the WFI, and the Critical that caused the BLOCKED
was resolved by revision 1 before Cycle 2 began.

The residual risk of that shortcut is that the corrected category — the
orchestrator's judgement, not the auditor's — never faced an independent check by
the agent that raised it. It is partly covered: `wfi-auditor-b` runs
`CATEGORY-LANGUAGE-SECOND-PASS` and receives the revised document with no
knowledge of Cycle 1's reasoning, so the reclassification is re-examined blind.

`Audit-Content-Hash` is deliberately absent, following the WFI-020 precedent: the
revisions were applied before the field could be written, so the pre-revision body
no longer exists and the true value is unrecoverable. Writing the post-revision
hash would invert the no-change guard and halt a later attempt as "unchanged"
despite substantial revision. An absent field fails safe.

## Orchestrator note

`wfi-auditor-a` is read-only by charter and holds no write tool, so it returned
its JSON body and this session persisted it verbatim to `WFI-025-auditor-a.json`.
No check result, severity, finding, or proposed revision was altered. Where the
orchestrator disagreed — the category, the citations, the plugin-scope findings —
the disagreement is argued above and applied to the WFI, not edited into the
auditor's record.

Before either cycle ran, the WFI's central factual claim was verified
independently against the live scripts: the four accepted forms at
`check-workflow-state.sh:234-244`, the raw computation at
`task-review-precheck.sh:494`, the validator's raw-equality requirement at
`validate-review-context-set.sh:302-304` and its round-consistency check at
`:326`, and a reproduction on a scratch copy showing the raw digest changing
across a status flip while all three invariant forms hold. The premise is sound;
the audit was therefore about the quality of the proposal built on it.
