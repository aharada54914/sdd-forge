# WFI Audit Report — Cycle {{cycle_number}}

## Header

| Field | Value |
|---|---|
| WFI-ID | {{wfi_id}} |
| Category | {{category}} |
| Cycle | {{cycle_number}} of 2 |
| Auditor Agent | wfi-auditor-{{auditor_slot}} |
| Verdict | {{verdict}} |
| Critical Findings | {{findings_critical}} |
| Major Findings | {{findings_major}} |
| Minor Findings (Advisory) | {{findings_minor}} |
| Generated | {{generated_timestamp}} |

<!-- Allowed verdicts: PASS | NEEDS_REVISION | BLOCKED -->
<!-- PASS: 0 Critical, 0 Major. WFI is ready to advance to the next cycle or Human-Pending. -->
<!-- NEEDS_REVISION: 1+ Major findings. Orchestrator applies "Proposed Revisions" to WFI. -->
<!-- BLOCKED: 1+ Critical findings. Orchestrator resets Audit-Status: Not-Started. -->

## Verdict: {{verdict}}

{{verdict_summary}}

<!-- Auditor: write 1–3 sentences explaining the overall verdict. -->
<!-- Focus on the most significant finding or why the WFI cleared all checks. -->

---

## Findings

### Critical Findings

{{critical_findings_list}}

<!-- Format: - [CRITICAL] <check-id> — <description> -->
<!-- Quote the exact WFI text that triggered the finding. -->
<!-- If none: write "None." -->

### Major Findings

{{major_findings_list}}

<!-- Format: - [MAJOR] <check-id> — <description> -->
<!-- If none: write "None." -->

### Minor Findings (Advisory)

{{minor_findings_list}}

<!-- Format: - [MINOR] <check-id> — <description> -->
<!-- Minor findings do not block progression but should inform WFI quality. -->
<!-- If none: write "None." -->

---

## Auditor Reasoning

{{auditor_reasoning}}

<!-- For each finding above, explain the evidence observed in the WFI. -->
<!-- Quote specific text from the WFI that triggered the finding. -->
<!-- For PASS checks, one line of confirmation is sufficient. -->
<!-- Format:
  ### <check-id>
  Result: PASS | FAIL | SKIP
  Evidence: "<quoted WFI text or observation>"
-->

---

## Proposed Revisions

{{proposed_revisions}}

<!-- For each CRITICAL or MAJOR finding, specify the exact revision to apply to WFI-NNN.md. -->
<!-- The orchestrator (wfi-audit-cycle) reads this section to update the WFI file. -->
<!-- Be precise: name the section to change and the replacement text. -->
<!--
  Format:
  ### <check-id> → Revision
  **Section:** ## Root Cause Hypothesis (or ## Proposed Change, etc.)
  **Change:** Replace "<current text>" with "<revised text>"
-->
<!-- If verdict is PASS (no Major or Critical findings): write "No revisions required." -->
