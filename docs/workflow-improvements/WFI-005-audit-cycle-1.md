# WFI Audit Report — Cycle 1

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-005 |
| Category | plugin-improvement |
| Cycle | 1 of 2 |
| Auditor Agent | wfi-auditor-a |
| Verdict | NEEDS_REVISION |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings (Advisory) | 0 |
| Generated | 2026-07-07T10:35:00Z |

## Verdict: NEEDS_REVISION

Six of eight checks pass, including full independent verification of all four
Problem Evidence items against the real repository. The two Major findings
are both routing defects in the Proposed Change table (direct plugins/ file
targets in a plugin-improvement WFI, and a directory-level test target),
not content defects; the drafted content itself was judged sound and
carryable into the GitHub Issue verbatim.

---

## Findings

### Critical Findings

None.

### Major Findings

- [MAJOR] CHANGE-CONCRETE — Row 4 names a directory, not a specific file path, in the Target File column: tests/ (new template-validator parity test, both a .sh and a .ps1 twin following the existing twin-test convention). The parenthetical describes intent but does not commit to a specific file name (e.g. tests/template-validator-parity.tests.sh); CHANGE-CONCRETE requires a specific file path, not a directory or vague reference. Separately, rows 1-3 name paths inside plugins/ (plugins/sdd-implementation/templates/implementation-report.template.md, plugins/sdd-quality-loop/templates/quality-report.template.md, plugins/sdd-quality-loop/references/deterministic-check-policy.md), which CHANGE-CONCRETE flags as Major regardless of description because plugin files are out of scope for WFI changes (overlaps with NO-PLUGIN-SCOPE-CREEP below).
- [MAJOR] NO-PLUGIN-SCOPE-CREEP — Three of four Proposed Change rows name Target Files inside plugins/, out of scope for a WFI direct Proposed Change table: Row 1 -- plugins/sdd-implementation/templates/implementation-report.template.md (add a Task-ID line and an Outputs section); Row 2 -- plugins/sdd-quality-loop/templates/quality-report.template.md (add a Feature line); Row 3 -- plugins/sdd-quality-loop/references/deterministic-check-policy.md (rewrite the Scope and Waivers passage). Per the wfi-category-guide classification flow (Section 1) and Section 4, a plugin-improvement WFI application mechanism is a GitHub Issue against the plugin, not a Proposed Change table that edits plugins/ files directly. The source retrospective itself anticipated this: it filed this exact friction cluster (FP-05 gaps 1-3) as its own WFI-002 candidate with Target File(s) stated as plugin gate scripts/templates via GitHub Issue (plugin-improvement lane; project-side files only if approved) (reports/retrospective/2026-07-07T0633Z-sdd-domain.md, Proposed Improvements table) -- i.e. the retrospective own authors expected this content to route through the GitHub-Issue lane, not direct Target File edits inside plugins/.

### Minor Findings (Advisory)

None.

---

## Auditor Reasoning

### EVIDENCE-CITED
Result: PASS
Evidence: "No issues found. All four Problem Evidence items are independently verified: (1) implementation-report.template.md line 1 heading and absence of a Task-ID line / Outputs table confirmed against the template file and validate-review-context-set.sh (evaluator_output_is_declared function and the Task-ID grep near the quality:sdd-evaluator launch-boundary block); (2) quality-report.template.md has no Feature line, confirmed against the template and check-evidence-bundle.sh (Feature regex requirement, quality_report must contain exactly one Feature line); (3) deterministic-check-policy.md waiver escape vs check-contract.py _pass4_risk_tier/BASELINE_IDS confirmed -- placeholder-scan is in BASELINE_IDS at every tier including high/critical with no non-code-stack exemption, matching T-005 and T-011 contract JSON citations (both risk:high, both blocked exactly as described in their contract comment fields); (4) commit 2c8af66 exists with the exact described fix (basename-derived root replaced by content-derived root) dated 2026-07-07, matching tests/repository-release-validation.tests.sh copy-into-repository-directory scenario. All citations trace to real rows and files in the repository."

### ROOT-CAUSE-PLAUSIBLE
Result: PASS
Evidence: "No issues found. The hypothesis names a specific mechanism: deterministic enforcement tools for the quality verification gate and the independent evaluator launch boundary were hardened in separate changes without updating the artifact templates and policy documents that produce or describe the artifacts they consume, and no deterministic check binds template output to validator expectations. It further notes an existing parity-test precedent that does not extend to template/validator pairs, so drift is only discovered at gate time. This is not a restatement of a symptom (e.g. gate artifacts need retrofitting) -- it explains why the drift occurs."

### CATEGORY-LANGUAGE-MATCH
Result: PASS
Evidence: "No issues found. Root Cause Hypothesis uses only generic terms (quality verification gate, independent evaluator launch boundary, deterministic check) with no forbidden terms from Section 2. Expected Effect uses only generic/derived metric language (gate artifacts requiring manual format retrofit, deterministic checks in the repository) with no forbidden terms. The Proposed Change Change-Description column also uses only generic terms (the gate report, the evidence-bundle validator, the enforcement tool, the check). The string sdd-quality-loop appears twice in the Proposed Change section but only inside the Target File column as a literal repository path (plugins/sdd-quality-loop/templates/... and plugins/sdd-quality-loop/references/...), not as prose describing the gate concept in the Change Description column -- this is a path citation, not a forbidden-term violation of Section 2 rule, which targets prose usage when describing the gate concept."

### CHANGE-CONCRETE
Result: FAIL
Evidence: "Row 4 names a directory, not a specific file path, in the Target File column: tests/ (new template-validator parity test, both a .sh and a .ps1 twin following the existing twin-test convention). The parenthetical describes intent but does not commit to a specific file name (e.g. tests/template-validator-parity.tests.sh); CHANGE-CONCRETE requires a specific file path, not a directory or vague reference. Separately, rows 1-3 name paths inside plugins/ (plugins/sdd-implementation/templates/implementation-report.template.md, plugins/sdd-quality-loop/templates/quality-report.template.md, plugins/sdd-quality-loop/references/deterministic-check-policy.md), which CHANGE-CONCRETE flags as Major regardless of description because plugin files are out of scope for WFI changes (overlaps with NO-PLUGIN-SCOPE-CREEP below)."

### EFFECT-MEASURABLE
Result: PASS
Evidence: "No issues found. Expected Effect names a specific metric (Gate artifacts requiring manual format retrofit before a deterministic consumer accepts them) and a quantitative target (drop from 23 artifact retrofits plus 1 unusable-waiver blocker this period to 0 in the next completed feature), plus a secondary quantitative claim (deterministic-check count increases by exactly one parity suite, with the non-decreasing guard explicitly addressed given Meta-Change: true)."

### VERIFICATION-METRIC-DEFINED
Result: PASS
Evidence: "No issues found. Exactly one primary Target-Metric is named (gate artifacts manually retrofitted to satisfy a deterministic consumer, per feature, count), with Baseline (23 retrofits plus 1 unusable-waiver blocker, 2026-07-07 sdd-domain retrospective), Target (0), and Horizon/checkpoint (next completed feature retrospective). A baseline-reconciliation paragraph explains the 23-count derivation (11 impl reports plus 11 quality reports plus 1 heading-normalization batch) against the retrospective own FP-05/WFI-002-candidate phrasing of 11 reports compensated plus 1 unusable-waiver blocker, and explicitly states both counts stem from the same four contract gaps -- so the divergence is disclosed, not silently substituted."

### VERIFICATION-PLAN-SPECIFIC
Result: PASS
Evidence: "No issues found. The Verification Plan specifies the exact mechanism for counting the primary metric next cycle (fix-up edits observable in git history between an artifact first write and gate acceptance, or compensation notes in gate reports), names the specific deterministic consumers to check against (check-evidence-bundle, check-task-state, the independent evaluator launch boundary), states a pass/fail threshold (count equals 0 and new parity twin tests present and green), and adds a secondary specific check (no attempted-but-rejected placeholder-scan waiver in the next feature). This is not a generic we will check if things improved plan."

### NO-PLUGIN-SCOPE-CREEP
Result: FAIL
Evidence: "Three of four Proposed Change rows name Target Files inside plugins/, out of scope for a WFI direct Proposed Change table: Row 1 -- plugins/sdd-implementation/templates/implementation-report.template.md (add a Task-ID line and an Outputs section); Row 2 -- plugins/sdd-quality-loop/templates/quality-report.template.md (add a Feature line); Row 3 -- plugins/sdd-quality-loop/references/deterministic-check-policy.md (rewrite the Scope and Waivers passage). Per the wfi-category-guide classification flow (Section 1) and Section 4, a plugin-improvement WFI application mechanism is a GitHub Issue against the plugin, not a Proposed Change table that edits plugins/ files directly. The source retrospective itself anticipated this: it filed this exact friction cluster (FP-05 gaps 1-3) as its own WFI-002 candidate with Target File(s) stated as plugin gate scripts/templates via GitHub Issue (plugin-improvement lane; project-side files only if approved) (reports/retrospective/2026-07-07T0633Z-sdd-domain.md, Proposed Improvements table) -- i.e. the retrospective own authors expected this content to route through the GitHub-Issue lane, not direct Target File edits inside plugins/."

---

## Proposed Revisions

### CHANGE-CONCRETE → Revision
**Section:** ## Proposed Change
**Change:** Remove the direct plugins/ file edits from the Proposed Change table (rows 1-3). Replace them with a single row whose Target File is the GitHub Issue that wfi-audit-cycle will create per wfi-category-guide.md Section 4, and whose Change Description restates the three template/policy fixes in the generic language already drafted (the content is otherwise sound and can be carried into the Issue body verbatim). If a project-side companion change is warranted (e.g. an AGENTS.md checklist item reminding authors to check template/validator parity before submission), add that as a separate row with a concrete project-root Target File -- but the plugins/ edits themselves belong in the Issue, not the WFI direct Proposed Change table.

### NO-PLUGIN-SCOPE-CREEP → Revision
**Section:** ## Proposed Change
**Change:** Replace the Target File value for the new test row (currently the directory tests/ with a parenthetical description) with two concrete file paths, e.g. tests/template-validator-parity.tests.sh and tests/template-validator-parity.tests.ps1, or a single row naming both explicitly.

