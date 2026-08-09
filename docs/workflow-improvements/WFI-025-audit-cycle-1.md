# WFI Audit Report — Cycle 1

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-025 |
| Category | plugin-improvement |
| Cycle | 1 of 2 |
| Auditor Agent | wfi-auditor-a |
| Verdict | **NEEDS_REVISION** |
| Critical Findings | 0 |
| Major Findings | 4 |
| Minor Findings (Advisory) | 0 |
| Generated | 2026-08-10T00:00:00Z |
| Audit-Attempt | 2 |

Raw auditor output: `docs/workflow-improvements/WFI-025-auditor-a.json`.
Attempt 1's artifacts are preserved verbatim under `WFI-025-attempt-1-*`.

## Verdict: NEEDS_REVISION

Four of eight checks failed, all Major, none Critical. The two Criticals that
BLOCKED attempt 1 — `CATEGORY-LANGUAGE-MATCH` in Cycle 1 and
`FEASIBILITY-WITHOUT-PLUGINS` in Cycle 2 — were the reason attempt 2 exists, and
`CATEGORY-LANGUAGE-MATCH` now **PASSES** against the revision that resolved it.
That was the specific gap this attempt was opened to close, and it is closed.

The run halted at Cycle 1 without applying revisions and without invoking
`wfi-auditor-b`, on the operator's explicit instruction that a NEEDS_REVISION or
BLOCKED verdict stops the attempt. This is stricter than the process: STEP 4's
NEEDS_REVISION path would apply the proposed revisions and continue to Cycle 2.
The deviation is toward caution and is recorded rather than hidden.

Two of the four Major findings are **artifacts of a stale installed plugin, not
defects in WFI-025**. See "Orchestrator verification" below. Two are sound and
stand on their own.

---

## Findings

### Critical Findings

None.

### Major Findings

- [MAJOR] EVIDENCE-CITED — `## Problem Evidence` cites commit hashes and
  `reports/task-review/.../precheck-result.json` artifacts, not "a real row in the
  retrospective report or a real file in `docs/review-tickets/`" as the check
  enumerates. The auditor independently verified every citation is factually
  accurate before failing the check on its source requirement alone.
- [MAJOR] CHANGE-CONCRETE — all four Target File rows name paths inside
  `plugins/`. **Contaminated finding — see below.**
- [MAJOR] VERIFICATION-METRIC-DEFINED — the baseline is not sourced from the
  retrospective report, as check item 1 requires. The WFI states this outright,
  and the auditor confirmed no such row exists in
  `reports/retrospective/2026-08-05T145740Z-design-sync-consent.md`.
- [MAJOR] NO-PLUGIN-SCOPE-CREEP — every Target File is inside `plugins/`.
  **Contaminated finding — see below.**

### Minor Findings (Advisory)

None. `VERIFICATION-PLAN-SPECIFIC` passed on item 5 of the Verification Plan.

---

## Auditor Reasoning

### EVIDENCE-CITED
Result: FAIL (Major)
Evidence: The auditor resolved all three cited commits (`340f0149`, `b836a11e`,
`726a5a0c`) through `git ls-tree` / `git show`, confirmed the artifacts exist in
them, and corroborated two independent details — that `726a5a0c`'s precheck
`tasks_sha256` (`7bf1a5cd…`) matches the WFI's own scratch-copy pre-flip digest,
and that `b836a11e`'s `task-review-contract.json` `human_edit_summary` verbatim
records both reviewers flagging the replacement binding as mixed. It then failed
the check purely on the enumerated-source clause.

### ROOT-CAUSE-PLAUSIBLE
Result: PASS
Evidence: Verified against the live code, not just the prose —
`task-review-precheck.sh:494` is `tasks_sha256=$(sha256 "${TASKS_MD}")`, and
`check-workflow-state.sh`'s `reviewed_hash_accepted()` (lines 234-241) admits all
four forms. The producer/acceptor asymmetry is real.

### CATEGORY-LANGUAGE-MATCH
Result: PASS (Critical check, cleared)
Evidence: `plugin-improvement` is a valid category. The auditor grepped the whole
document for every Section 2 forbidden term and found five occurrences, all
outside the scanned scope: four in the Target File column and one in prose below
the table (`"The task plan is manifested only by \`task-review-loop\`"`, line 197).
Section 2 scopes the rule to `## Root Cause Hypothesis`, the `## Proposed Change`
**Change Description column**, and `## Expected Effect`; those three contain zero
forbidden terms.

This is the finding attempt 2 was opened to obtain. The `workflow-correctness` →
`plugin-improvement` reclassification, made by attempt 1's orchestrator rather
than by any auditor, has now been examined by an auditor with no knowledge of
attempt 1 and cleared.

### CHANGE-CONCRETE
Result: FAIL (Major) — **contaminated**
Evidence: The auditor found the Change Description text "concrete and non-vague in
every row" and failed the check solely on the `plugins/` paths.

### EFFECT-MEASURABLE
Result: PASS
Evidence: "attempts 5, 3 and 5 … Average task-stage attempts per feature falls
from 4.3 to 1.0" — generic metric name plus a quantitative target.

### VERIFICATION-METRIC-DEFINED
Result: FAIL (Major)
Evidence: One primary metric, target `0`, checkpoint "the next 3 features" are all
present. Only item 1 (baseline from the retrospective report) fails, and the WFI
concedes it: "not from a retrospective table row: no retrospective covers this
session".

### VERIFICATION-PLAN-SPECIFIC
Result: PASS
Evidence: Item 5 names the exact retrospective row to be added and the baseline
and target it will be compared against.

### NO-PLUGIN-SCOPE-CREEP
Result: FAIL (Major) — **contaminated**
Evidence: The auditor reported, unprompted and correctly, that its role definition
"contains no carve-out clause of any kind".

---

## Orchestrator verification of the audit

The auditor was checked before being acted on. It was right about something the
task instructions told it was false, and that inverts two of its four findings.

**The carve-out does not exist in the agent definition that actually ran.** The
task prompt told the auditor that `wfi-auditor-a.md:129-154` carries a
three-condition carve-out for `plugins/` paths and that it must either apply it or
say which condition failed. The auditor replied that no such text is in its role
definition, and declined to invent one — refusing, in its words, to soften a
finding "based on an unverified claim in a task message rather than my actual role
text". That was the correct call, and the claim in the prompt was the unreliable
input.

The executed agent definition is the **installed** plugin, not this repository's
copy:

```
installed: ~/.claude/plugins/cache/sdd-plugins/sdd-quality-loop/1.10.0/agents/wfi-auditor-a.md
repo:      plugins/sdd-quality-loop/agents/wfi-auditor-a.md   (plugin.json version 1.14.0)
```

`diff` between them returns exactly two hunks and nothing else: the CHANGE-CONCRETE
cross-reference sentence, and the entire `**Carve-out — the plugin's own source
repository.**` block with its three conditions and its provenance note. The
installed file is dated 2026-08-02; the carve-out's own provenance line records it
was "added by human decision on 2026-08-03". The installed copy predates the
decision by one day.

`wfi-auditor-b.md` and `wfi-category-guide.md` are byte-identical between installed
and repo, so Cycle 2 and every language rule would have run against current text.
The contamination is confined to `wfi-auditor-a`'s two `plugins/`-path checks.

**Consequences, stated precisely:**

1. `CHANGE-CONCRETE` and `NO-PLUGIN-SCOPE-CREEP` are *correct* against the text the
   auditor was given and *wrong* against the authoritative definition in this
   repository. Under the current text the carve-out applies. All three conditions
   were verified independently by the orchestrator against `WFI-025.md`:
   - condition 1 — `Category: plugin-improvement` (line 20);
   - condition 2 — the `## Category` section states in its own words that "This
     repository is the source of truth for the plugins named in `## Proposed
     Change`, not a consuming project holding a vendored copy of them. The change
     is delivered as an ordinary commit to this repository" (lines 32-35);
   - condition 3 — `## GitHub-Issue` is present carrying an explicit statement of
     when the issue is filed: "Pending — filed against this repository on human
     approval" (line 57).
2. The auditor's third proposed revision escalates the `plugins/` tension to a
   human for a policy ruling. That ruling was already made on 2026-08-03. The stale
   definition is re-litigating a settled decision, which is the specific harm the
   carve-out was written to end.
3. **Attempt 1's cycle-1 report needs a correction.** It recorded that "The
   auditor never mentioned the carve-out" and treated that as a missed check. The
   observation was right; the attributed cause was wrong. That auditor could not
   have mentioned the carve-out — it was not in its instructions either. The defect
   is environmental, not a lapse of auditor judgement, and it has now recurred
   identically across two independent attempts, which is what a stale-input defect
   looks like and what an auditor-quality defect does not.

**The other two findings are not contaminated.** `EVIDENCE-CITED` and
`VERIFICATION-METRIC-DEFINED` have byte-identical check text in 1.10.0 and 1.14.0.
Both were applied to the letter, both were backed by verification work rather than
assertion, and both identify a real mismatch between what the WFI cites and what
the check enumerates as an admissible source. They are arguable — the WFI argues
the point itself, and no retrospective row it could cite exists — but they are the
auditor's to make, and they are enough to hold the verdict at NEEDS_REVISION
independently of the carve-out question.

## Revisions applied

**None.** The attempt halted at Cycle 1 per the operator's instruction. Applying
findings and continuing is precisely the deviation attempt 2 exists to correct, and
two of the four findings should not be applied at all.

For a future attempt 3, the live questions are:
- whether to update the installed `sdd-quality-loop` plugin from 1.10.0 to 1.14.0
  before auditing again, so `wfi-auditor-a` runs with the carve-out it is supposed
  to have (this is the root fix — without it, attempt 3's Cycle 1 will return the
  same two spurious Majors);
- whether to file a review ticket carrying the three rebind observations, which
  would resolve `EVIDENCE-CITED` and `VERIFICATION-METRIC-DEFINED` together, as the
  auditor proposed;
- or whether the human approver rules that a WFI documenting first-hand primary
  artifacts, in a session no retrospective covers, satisfies those two checks as
  written.

## State after this cycle

`Audit-Status` is returned to `Not-Started` with `Audit-Attempt: 2` unchanged. The
counter was **not** incremented: STEP 4 increments on BLOCKED, and this cycle was
NEEDS_REVISION halted by operator instruction, not by the process's BLOCKED path.
Attempt 3 therefore remains available before the convergence guard trips.

`Audit-Content-Hash` remains deliberately absent. Writing it now would arm the
Precondition no-change guard against a document that may correctly need no
revision at all — if the stale-plugin root cause is fixed and the human rules on
the two sourcing checks, attempt 3 could legitimately re-audit an unchanged body.
An absent field fails safe.

`Status:` was not touched and remains `Draft`. No GitHub issue was created: that is
a human-authorized action and no authorization was given for this run.

## Orchestrator note

`wfi-auditor-a` is read-only by charter and holds no write tool, so it returned its
JSON body and this session persisted it verbatim to `WFI-025-auditor-a.json`. No
check result, severity, finding, or proposed revision was altered — including the
two the orchestrator believes are wrong. The disagreement is argued here, not
edited into the auditor's record.
