#!/usr/bin/env bash
# Quality-loop prompt and template calibration must stay synchronized.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_REF="plugins/sdd-quality-loop/references/quality-gate-calibration.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

[[ -f "$ROOT/$QUALITY_REF" ]] || fail "missing quality gate calibration reference"

grep -Fq "$QUALITY_REF" "$ROOT/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md" || \
  fail "quality-gate skill must require quality-gate calibration"
grep -Fq "$QUALITY_REF" "$ROOT/plugins/sdd-quality-loop/agents/evaluator.md" || \
  fail "evaluator must read quality-gate calibration"
grep -Fq "$QUALITY_REF" "$ROOT/plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md" || \
  fail "copilot evaluator must read quality-gate calibration"

grep -Fq 'Evidence Ladder' "$ROOT/$QUALITY_REF" || fail "calibration must define evidence ladder"
grep -Fq 'Cannot-Verify Handling' "$ROOT/$QUALITY_REF" || fail "calibration must define cannot-verify handling"
grep -Fq 'Differential Verification' "$ROOT/$QUALITY_REF" || fail "calibration must define differential verification"
grep -Fq 'Loop Stop Conditions' "$ROOT/$QUALITY_REF" || fail "calibration must define loop stop conditions"

quality_report="$ROOT/plugins/sdd-quality-loop/templates/quality-report.template.md"
grep -Fq '## Evidence Matrix' "$quality_report" || fail "quality report must include evidence matrix"
grep -Fq '## Cannot-Verify Items' "$quality_report" || fail "quality report must include cannot-verify section"
grep -Fq 'Implementation-report statements are claims, not evidence' "$quality_report" || \
  fail "quality report must distinguish claims from evidence"

grep -Fq 'Cannot-verify is not PASS' "$ROOT/plugins/sdd-quality-loop/agents/evaluator.md" || \
  fail "evaluator must reject cannot-verify pass"
grep -Fq 'Cannot-verify is not PASS' "$ROOT/plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md" || \
  fail "copilot evaluator must reject cannot-verify pass"
grep -Fq 'baseline or differential comparison' "$ROOT/plugins/sdd-quality-loop/agents/evaluator.md" || \
  fail "evaluator must require baseline/differential check for refactor or bugfix"
grep -Fq 'baseline or differential comparison' "$ROOT/plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md" || \
  fail "copilot evaluator must require baseline/differential check for refactor or bugfix"
if grep -Fq 'blocked_ticket_or_waiver' "$quality_report"; then
  fail "quality report must not imply waivers can unblock in-scope cannot-verify items"
fi

printf 'ok: quality loop calibration is synchronized\n'
