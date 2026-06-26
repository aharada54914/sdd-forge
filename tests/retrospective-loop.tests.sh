#!/usr/bin/env bash
# Workflow retrospective prompt, templates, and WFI audit checks must stay aligned.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md"
REPORT_TEMPLATE="$ROOT/plugins/sdd-quality-loop/templates/retrospective-report.template.md"
WFI_TEMPLATE="$ROOT/plugins/sdd-quality-loop/templates/workflow-improvement.template.md"
AUDITOR_A="$ROOT/plugins/sdd-quality-loop/agents/wfi-auditor-a.md"
AUDITOR_B="$ROOT/plugins/sdd-quality-loop/agents/wfi-auditor-b.md"
AUDIT_CYCLE="$ROOT/plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

for section in \
  'Sample Size' \
  'Data Completeness' \
  'Confidence' \
  '## Improvement Verification Plan' \
  '## Review Gate Metrics' \
  'Repeat Finding Rate' \
  'WFI Verification Rate'; do
  grep -Fq "$section" "$SKILL" || fail "workflow-retrospective skill missing ${section}"
  grep -Fq "$section" "$REPORT_TEMPLATE" || fail "retrospective template missing ${section}"
done

grep -Fq 'Do not draft a WFI from a single-task observation' "$SKILL" || \
  fail "retrospective must guard against one-off overfitting"
grep -Fq 'Verified`: target met' "$SKILL" || fail "retrospective must classify WFI verification result"
grep -Fq 'Needs-Followup' "$SKILL" || fail "retrospective must support follow-up result"
grep -Fq 'Rejected' "$SKILL" || fail "retrospective must support rejected result"

grep -Fq '## Verification Metric' "$WFI_TEMPLATE" || fail "WFI template must include verification metric"
grep -Fq '## Verification Metric' "$SKILL" || fail "workflow-retrospective WFI draft must include verification metric"
grep -Fq '{{review_contract_count}} review contracts' "$REPORT_TEMPLATE" || fail "retrospective template must report review contract sample size"
grep -Fq 'Spec Review Rounds' "$REPORT_TEMPLATE" || fail "retrospective template must include spec review rounds"
grep -Fq 'Spec Review Blocked Rate' "$REPORT_TEMPLATE" || fail "retrospective template must compare spec review blocked rate"
grep -Fq 'VERIFICATION-METRIC-DEFINED' "$AUDITOR_A" || fail "auditor A must check verification metric"
grep -Fq 'Current baseline and target' "$AUDITOR_B" || fail "auditor B must check baseline and target"
grep -Fq 'proposed_revisions' "$AUDITOR_A" || fail "auditor A must return structured proposed revisions"
grep -Fq 'proposed_revisions' "$AUDITOR_B" || fail "auditor B must return structured proposed revisions"
grep -Fq 'proposed_revisions' "$AUDIT_CYCLE" || fail "audit cycle must consume structured proposed revisions"
grep -Fq '"auditor_a_pass_count": 8' "$AUDITOR_B" || fail "auditor B schema example must match auditor A check count"
grep -Fq 'VERIFICATION-METRIC-DEFINED' "$AUDIT_CYCLE" || fail "audit cycle summary must include new auditor A check"
grep -Fq '"auditor_a_pass_count": 8' "$AUDIT_CYCLE" || fail "audit cycle example pass count must match auditor A check count"

printf 'ok: retrospective loop prompts and templates are synchronized\n'
