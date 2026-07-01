---
name: wfi-audit-cycle
description: "Orchestrator for the WFI proposal audit. Runs 2 sequential independent audit cycles on a WFI-NNN.md Draft before presenting it to a human for Approved. Cycle 1 (wfi-auditor-a) audits proposal quality. Cycle 2 (wfi-auditor-b) audits impact and risk. Each auditor runs as a fresh isolated agent. The orchestrator applies audit findings to revise the WFI between cycles, creates a GitHub Issue for plugin-improvement WFIs, and sets Audit-Status: Human-Pending when complete."
disable-model-invocation: true
---

# WFI Audit Cycle

Run two sequential independent audit cycles on a WFI Draft to improve proposal quality
before human review. This skill orchestrates wfi-auditor-a (Cycle 1) and wfi-auditor-b
(Cycle 2), applies their findings to revise the WFI, and manages the Audit-Status field.

## Invocation

Codex:
```
Use the wfi-audit-cycle skill for WFI-NNN
```

Claude Code:
```
/sdd-quality-loop:wfi-audit-cycle WFI-NNN
```

Replace `WFI-NNN` with the specific WFI identifier (e.g., `WFI-001`).

## Preconditions

Before running:
1. `docs/workflow-improvements/WFI-NNN.md` must exist.
2. The WFI must have `Status: Draft`. Do not run on Approved, Applied, Verified,
   or Rejected WFIs.
3. `Audit-Status` must be `Not-Started`, `Cycle-1-In-Progress`, or
   `Cycle-2-In-Progress` (the last two allow resumption after interruption).
   If `Audit-Status: Human-Pending`, print:
   "wfi-audit-cycle: WFI-NNN is already at Human-Pending. No action taken."
   and halt.
   If `Audit-Status: Human-Blocked`, print:
   "wfi-audit-cycle: WFI-NNN is Human-Blocked after repeated audit failures. A
   human must resolve the root cause and reset Audit-Attempt to 0 (and set
   Audit-Status: Not-Started) before re-running."
   and halt.
4. **Convergence guard (attempt limit).** Read `Audit-Attempt:` from the WFI
   (absent ⇒ treat as 0). If `Audit-Attempt >= 3`, do not start another cycle:
   set `Audit-Status: Human-Blocked`, print the Human-Blocked message above, and
   halt. `Audit-Attempt` is a plain counter, not an approval field, so the hook
   guard does not block the orchestrator from incrementing it; only a human may
   reset it downward. This mirrors the review loops' `round == 3 → BLOCKED`
   upper bound.
5. **No-change guard.** When resuming from `Not-Started` after a prior BLOCKED,
   compute the SHA-256 of the WFI body (all content sections, excluding the
   `Audit-Status:`, `Audit-Attempt:`, and `Audit-Content-Hash:` control fields).
   If it equals the stored `Audit-Content-Hash:` from the last BLOCKED, the WFI
   was not revised: print
   "wfi-audit-cycle: WFI-NNN unchanged since last BLOCKED. Revise the WFI before
   re-running." and halt. This mirrors the review-loop precheck sha256 stop.

## Process (State Machine)

Determine the current state by reading `Audit-Status` from the WFI and checking
for existing audit artifacts:
- `docs/workflow-improvements/WFI-NNN-auditor-a.json` present → Cycle 1 complete
- `docs/workflow-improvements/WFI-NNN-auditor-b.json` present → Cycle 2 complete

### STEP 1 — Set Audit-Status: Cycle-1-In-Progress

Update the `Audit-Status:` field in `docs/workflow-improvements/WFI-NNN.md`
from `Not-Started` to `Cycle-1-In-Progress`.

This is the only field `wfi-audit-cycle` may write to the WFI during active auditing.
Do not touch `Status:`, `Category:`, `GitHub-Issue:`, or any content section.

### STEP 2 — Invoke wfi-auditor-a (Cycle 1)

Spawn `wfi-auditor-a` as a fresh agent (no shared context with this orchestrator) with:
- `wfi_path`: `docs/workflow-improvements/WFI-NNN.md`
- `retrospective_path`: the most recent file in `reports/retrospective/` (newest by
  filename timestamp; if none exists, pass an empty string and let the auditor SKIP
  EVIDENCE-CITED per its instructions)
- `category_guide_path`: `plugins/sdd-quality-loop/references/wfi-category-guide.md`
- `output_path`: `docs/workflow-improvements/WFI-NNN-auditor-a.json`

wfi-auditor-a is read-only. It must not modify any file. Wait for it to complete and
read `WFI-NNN-auditor-a.json`.

If wfi-auditor-a does not produce output or exits with an error, halt and print:
"wfi-audit-cycle: Cycle 1 auditor failed to produce output. Check agent logs."

### STEP 3 — Generate integrated-summary.json

Deterministically produce `docs/workflow-improvements/WFI-NNN-integrated-summary.json`
from `wfi-auditor-a.json`. This file contains check IDs and counts only — no
qualitative content, no finding descriptions, no quoted WFI text. It is the only
Cycle 1 information passed to wfi-auditor-b.

Schema:
```json
{
  "schema": "wfi-integrated-summary/v1",
  "wfi_id": "WFI-NNN",
  "cycle": 1,
  "auditor_a_check_ids": ["EVIDENCE-CITED", "ROOT-CAUSE-PLAUSIBLE", "CATEGORY-LANGUAGE-MATCH", "CHANGE-CONCRETE", "EFFECT-MEASURABLE", "VERIFICATION-METRIC-DEFINED", "VERIFICATION-PLAN-SPECIFIC", "NO-PLUGIN-SCOPE-CREEP"],
  "auditor_a_fail_ids": ["<IDs of FAIL checks>"],
  "auditor_a_fail_count": 0,
  "auditor_a_pass_count": 8,
  "auditor_a_skip_count": 0,
  "auditor_a_verdict": "PASS|NEEDS_REVISION|BLOCKED",
  "generated_at": "<ISO8601>"
}
```

Write to: `docs/workflow-improvements/WFI-NNN-integrated-summary.json`

### STEP 4 — Apply Cycle 1 Findings to WFI

Read `wfi-auditor-a.json`. Check the `verdict` field.

#### Cycle 1 BLOCKED

1. Increment `Audit-Attempt:` in WFI-NNN.md by 1 (absent ⇒ set to `1`).
2. Store the current WFI body SHA-256 (excluding `Audit-*` control fields) in
   `Audit-Content-Hash:` — the Precondition no-change guard reads it next run.
3. If `Audit-Attempt >= 3` after incrementing: set `Audit-Status: Human-Blocked`,
   print the Human-Blocked message (see Preconditions), and halt. Do not reset to
   Not-Started; a human must intervene.
4. Otherwise set `Audit-Status: Not-Started` and print:
```
wfi-audit-cycle BLOCKED at Cycle 1 — <N> Critical finding(s) in WFI-NNN (attempt <Audit-Attempt>/3).

The WFI has fundamental quality issues that must be resolved before audit can
continue. Review WFI-NNN-auditor-a.json for details, revise WFI-NNN.md, then
re-invoke /sdd-quality-loop:wfi-audit-cycle WFI-NNN.
```
Halt. Do not proceed to Cycle 2.

#### Cycle 1 NEEDS_REVISION or PASS

Read the `proposed_revisions` array from `wfi-auditor-a.json`. For PASS, the
array may be empty. For NEEDS_REVISION, halt if the array is empty unless every
Major finding explicitly requires human clarification. Apply each revision to
`docs/workflow-improvements/WFI-NNN.md` by editing the named sections. The
orchestrator is the only entity that writes content to WFI-NNN.md during audit.

After applying revisions, write the Cycle 1 audit report to
`docs/workflow-improvements/WFI-NNN-audit-cycle-1.md` using the structure from
`plugins/sdd-quality-loop/templates/wfi-audit-report.template.md`. Fill in:
- `{{cycle_number}}`: 1
- `{{wfi_id}}`: WFI-NNN
- `{{category}}`: read from WFI
- `{{auditor_slot}}`: a
- `{{verdict}}`, `{{findings_critical}}`, `{{findings_major}}`, `{{findings_minor}}`:
  from auditor-a.json
- `{{generated_timestamp}}`: current ISO8601 timestamp
- Fill findings and proposed revisions from auditor-a.json content

### STEP 5 — Set Audit-Status: Cycle-2-In-Progress

Update the `Audit-Status:` field in `docs/workflow-improvements/WFI-NNN.md`
from `Cycle-1-In-Progress` to `Cycle-2-In-Progress`.

### STEP 6 — Invoke wfi-auditor-b (Cycle 2)

Spawn `wfi-auditor-b` as a fresh agent (no shared context with this orchestrator) with:
- `wfi_path`: `docs/workflow-improvements/WFI-NNN.md` (already revised after Cycle 1)
- `retrospective_path`: same path as used in STEP 2
- `category_guide_path`: `plugins/sdd-quality-loop/references/wfi-category-guide.md`
- `integrated_summary_path`: `docs/workflow-improvements/WFI-NNN-integrated-summary.json`
- `output_path`: `docs/workflow-improvements/WFI-NNN-auditor-b.json`

wfi-auditor-b has `disallowedPaths` covering `WFI-NNN-audit-cycle-1.md` and
`WFI-NNN-auditor-a.json`. It cannot read Cycle 1 raw output — only the revised
WFI and the integrated-summary bridge.

Wait for wfi-auditor-b to complete and read `WFI-NNN-auditor-b.json`.

If wfi-auditor-b does not produce output or exits with an error, halt and print:
"wfi-audit-cycle: Cycle 2 auditor failed to produce output. Check agent logs."

### STEP 7 — Apply Cycle 2 Findings to WFI

Read `wfi-auditor-b.json`. Check the `verdict` field.

#### Cycle 2 BLOCKED

1. Increment `Audit-Attempt:` in WFI-NNN.md by 1 (absent ⇒ set to `1`).
2. Store the current WFI body SHA-256 (excluding `Audit-*` control fields) in
   `Audit-Content-Hash:`.
3. If `Audit-Attempt >= 3` after incrementing: set `Audit-Status: Human-Blocked`,
   print the Human-Blocked message (see Preconditions), and halt.
4. Otherwise set `Audit-Status: Not-Started` and print:
```
wfi-audit-cycle BLOCKED at Cycle 2 — <N> Critical finding(s) in WFI-NNN (attempt <Audit-Attempt>/3).

The revised WFI has a fundamental feasibility or scope issue. Review
WFI-NNN-auditor-b.json for details, revise WFI-NNN.md, then re-invoke
/sdd-quality-loop:wfi-audit-cycle WFI-NNN.
```
Halt.

#### Cycle 2 NEEDS_REVISION or PASS

Read the `proposed_revisions` array from `wfi-auditor-b.json`. For PASS, the
array may be empty. For NEEDS_REVISION, halt if the array is empty unless every
Major finding explicitly requires human clarification. Apply each Cycle 2
revision to WFI-NNN.md. Write the Cycle 2 audit report to
`docs/workflow-improvements/WFI-NNN-audit-cycle-2.md` using the same template
(set `{{cycle_number}}` to 2 and `{{auditor_slot}}` to b).

### STEP 8 — GitHub Issue Creation (plugin-improvement only)

Read `Category:` from WFI-NNN.md.

**If `Category: plugin-improvement`:**

Construct the issue body using the template from `wfi-category-guide.md` Section 4.
Populate it with the final (post-audit) content of the WFI.

Run:
```bash
gh issue create \
  --title "WFI-NNN: <problem summary from ## Problem Evidence, in generic terms>" \
  --body "<filled issue body>" \
  --label "workflow-improvement,plugin-improvement"
```

Capture the issue URL from stdout (format: `https://github.com/<owner>/<repo>/issues/<N>`).

- Success: Write `GitHub-Issue: <url>` to the WFI file.
- Failure (gh not authenticated, no remote, network error): Print a warning and write
  `GitHub-Issue: CREATION-FAILED — <error message>`. Do not halt — the WFI proceeds
  to Human-Pending regardless of issue creation outcome.

**If `Category: app-dev-efficiency`:**
Skip issue creation. `GitHub-Issue: N/A` remains unchanged.

### STEP 9 — Set Audit-Status: Human-Pending and Present to Human

Update `Audit-Status: Human-Pending` in WFI-NNN.md.

Print the completion summary:
```
wfi-audit-cycle COMPLETE — WFI-NNN (Category: <category>) has passed 2 audit cycles.

  Cycle 1 (Proposal Quality — wfi-auditor-a):
    Verdict: <verdict>
    Major findings applied: <N>
    Minor advisories: <N>

  Cycle 2 (Impact/Risk — wfi-auditor-b):
    Verdict: <verdict>
    Major findings applied: <N>
    Minor advisories: <N>

  GitHub Issue: <url | N/A | CREATION-FAILED>

WFI-NNN is now ready for human review (Audit-Status: Human-Pending).

To approve: edit docs/workflow-improvements/WFI-NNN.md and set:
  Status: Approved
The hook guard blocks any agent attempt to set Status: Approved.

Audit reports:
  docs/workflow-improvements/WFI-NNN-audit-cycle-1.md
  docs/workflow-improvements/WFI-NNN-audit-cycle-2.md
```

## Resumption After Interruption

If the skill is re-invoked after an interruption:
- `Audit-Status: Cycle-1-In-Progress` and `WFI-NNN-auditor-a.json` exists:
  skip STEP 2, proceed from STEP 3.
- `Audit-Status: Cycle-2-In-Progress` and `WFI-NNN-auditor-b.json` exists:
  skip STEPs 2–6, proceed from STEP 7.
- `Audit-Status: Human-Blocked`: do not resume automatically. A human must
  address the root cause and reset `Audit-Attempt` to 0 (and set
  `Audit-Status: Not-Started`) before re-running.
- `Audit-Status: Not-Started` (reset after BLOCKED): first apply the Precondition
  no-change guard — compare the WFI body SHA-256 against the stored
  `Audit-Content-Hash:`; if unchanged, halt. Otherwise start from STEP 1.

## Audit Artifact Layout

All audit artifacts for WFI-NNN live in `docs/workflow-improvements/`:

```
docs/workflow-improvements/
├── WFI-NNN.md                        ← WFI document (orchestrator updates Audit-Status, revises content)
├── WFI-NNN-auditor-a.json            ← Cycle 1 auditor raw output (internal)
├── WFI-NNN-integrated-summary.json   ← Bridge: counts and IDs only (internal)
├── WFI-NNN-auditor-b.json            ← Cycle 2 auditor raw output (internal)
├── WFI-NNN-audit-cycle-1.md          ← Cycle 1 audit report (human-readable)
└── WFI-NNN-audit-cycle-2.md          ← Cycle 2 audit report (human-readable)
```

Do not create subdirectories under `reports/` for audit artifacts.

## Boundaries

- Never write `Status: Approved` to any WFI file (hook guard enforces this).
- Never invoke wfi-auditor-a and wfi-auditor-b in the same agent context.
- Never pass wfi-auditor-a output (json or report) directly to wfi-auditor-b.
  Use `integrated-summary.json` (counts and IDs only) as the only bridge.
- Do not modify `reports/`, `specs/`, or any plugin files.
- Do not resolve or create review tickets.
- Do not invoke `quality-gate` or `fix-by-review-ticket`.

## Sudo Mode

`SDD_SUDO` does not apply to this skill. Both audit cycles run unconditionally
regardless of sudo state. The integrity of the audit process depends on this invariant.
