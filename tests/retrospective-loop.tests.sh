#!/usr/bin/env bash
# The v2 workflow retrospective, the WFI template, the WFI auditors and the
# audit cycle must stay aligned.
#
# 2026-11-28 owner decision (T-010, ADR-0051 decision 2): v2 rewrote the
# retrospective skill around deterministic logs (sdd-doctor, factory-metrics,
# drift events). The checks on the v1 skill's English wording, its metric
# derivation rules for review-loop reports (Task Attempts, Review Rounds,
# Quality-Gate Runs, Model Escalations) with their fixture re-implementation,
# and the report template's v1 review-loop comparison rows retired with the
# three-loop review; factory-metrics.mjs has its own executable tests
# (tests/v2-software-factory.test.mjs). What remains is the contract the v2
# skill still relies on: the fields it tells the drafter to fill exist in the
# template, the auditors check those fields, and the audit cycle consumes the
# auditors' structured output.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md"
REPORT_TEMPLATE="$ROOT/plugins/sdd-quality-loop/templates/retrospective-report.template.md"
WFI_TEMPLATE="$ROOT/plugins/sdd-quality-loop/templates/workflow-improvement.template.md"
AUDITOR_A="$ROOT/plugins/sdd-quality-loop/agents/wfi-auditor-a.md"
AUDITOR_B="$ROOT/plugins/sdd-quality-loop/agents/wfi-auditor-b.md"
AUDIT_CYCLE="$ROOT/plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
for file in "$SKILL" "$REPORT_TEMPLATE" "$WFI_TEMPLATE" "$AUDITOR_A" "$AUDITOR_B" "$AUDIT_CYCLE"; do
  [[ -f "$file" ]] || fail "missing ${file#"$ROOT"/}"
done

# 1. Every field the skill tells the drafter to carry over exists in the WFI
#    template, as a section heading or as a `Name:` field line.
grep -Fq 'plugins/sdd-quality-loop/templates/workflow-improvement.template.md' "$SKILL" ||
  fail 'workflow-retrospective must draft WFIs from the WFI template'
for field in Category Mechanism Meta-Change GitHub-Issue Audit-Status Audit-Attempt Audit-Content-Hash \
  'Problem Evidence' 'Why-Why Analysis' 'Root Cause Hypothesis' 'Proposed Change' 'Expected Effect' \
  'Verification Metric' 'Verification Plan' 'Rollback-Plan'; do
  grep -Fq "\`$field" "$SKILL" || fail "workflow-retrospective no longer names the WFI field: $field"
  grep -Eq "^(## $field|$field:)( |$)" "$WFI_TEMPLATE" || fail "WFI template lacks the field the skill names: $field"
done

# 2. Verification outcomes the skill records have a place in the template.
for outcome in 'Status: Verified' 'Needs-Followup' 'Status: Rejected'; do
  grep -Fq "$outcome" "$SKILL" || fail "workflow-retrospective must record the verification outcome: $outcome"
done
grep -Fxq '## Result' "$WFI_TEMPLATE" || fail 'WFI template must have a Result section for verification outcomes'
grep -Fq '`Needs-Followup` は Status 値ではない' "$SKILL" ||
  fail 'workflow-retrospective must keep Needs-Followup out of the Status values'

# 3. One-off observations never become rules (the v2 recurrence guard).
grep -Fq '2 回再発ルール' "$SKILL" || fail 'workflow-retrospective lost the two-recurrence rule'
grep -Fq '単発の例外ではルールやスキルを増やさない' "$SKILL" ||
  fail 'workflow-retrospective must not add rules or skills for a one-off exception'
grep -Fq '「今回候補なし（0 件）」を正常終了とする' "$SKILL" ||
  fail 'workflow-retrospective must treat zero candidates as a normal outcome'

# 4. The template's sections are what the auditors check.
grep -Fq '### Regression connection' "$WFI_TEMPLATE" || fail 'WFI template lost the regression connection'
grep -Fq 'existing-check/new-check/design-elimination/judgment' "$WFI_TEMPLATE" ||
  fail 'WFI template lost the regression dispositions'
grep -Fq 'Extra prose instructions alone are not prevention evidence' "$AUDITOR_B" ||
  fail 'auditor B must require executable prevention evidence'
grep -Fq 'VERIFICATION-METRIC-DEFINED' "$AUDITOR_A" || fail 'auditor A must check the verification metric'
grep -Fq 'Current baseline and target' "$AUDITOR_B" || fail 'auditor B must check the baseline and target'
grep -Fq 'WHY-CHAIN-VALID' "$AUDITOR_A" || fail 'auditor A must validate the why-why chain'
grep -Fq 'process/mechanism cause' "$AUDITOR_A" ||
  fail 'auditor A why-chain check must require a controllable process/mechanism terminal cause'

# 5. The audit cycle consumes both auditors' structured output.
grep -Fq 'proposed_revisions' "$AUDITOR_A" || fail 'auditor A must return structured proposed revisions'
grep -Fq 'proposed_revisions' "$AUDITOR_B" || fail 'auditor B must return structured proposed revisions'
grep -Fq 'proposed_revisions' "$AUDIT_CYCLE" || fail 'the audit cycle must apply structured proposed revisions'
for key in auditor_a_verdict auditor_a_pass_count auditor_a_fail_count; do
  grep -Fq "\`$key\`" "$AUDIT_CYCLE" || fail "the audit cycle integrated summary lost $key"
  grep -Fq "\"$key\"" "$AUDITOR_B" || fail "auditor B no longer reads $key from the integrated summary"
done
grep -Fq 'wfi-auditor-a' "$AUDIT_CYCLE" && grep -Fq 'wfi-auditor-b' "$AUDIT_CYCLE" ||
  fail 'the audit cycle must launch both WFI auditors'

# 6. The domain-drift rows the skill fills are in the report template.
grep -Fq 'retrospective-report.template.md#domain-drift-metrics' "$SKILL" ||
  fail 'workflow-retrospective must point at the domain-drift rows'
grep -Fxq '## Domain Drift Metrics' "$REPORT_TEMPLATE" || fail 'report template lost the Domain Drift Metrics section'

printf 'ok: retrospective, WFI template, auditors and audit cycle are aligned\n'
