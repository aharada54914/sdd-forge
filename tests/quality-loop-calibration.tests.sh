#!/usr/bin/env bash
# The v2 Done evaluator's evidence rules must be identical on every host.
#
# 2026-11-28 owner decision: the v1 quality-gate calibration reference
# (plugins/sdd-quality-loop/references/quality-gate-calibration.md) is no
# longer read by any v2 role, so the checks that required the retired
# quality-gate skill and the v1 evaluator wording to load it, and the checks
# on that reference's own content, retired with it (ADR-0051 decision 2). The
# guarantees they protected - cannot-verify is not PASS, implementation reports
# are claims, and N/A is not a missing execution - are now asserted directly in
# the Claude, Codex and Copilot evaluators that sdd-gate launches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md"
REPORT="$ROOT/plugins/sdd-quality-loop/templates/sdd-gate-report.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

rules=(
  '- Cannot-verify is not PASS: an in-scope claim you could not observe (no command run, no line inspected) is a `Major` finding.'
  '- Implementation-report statements are claims, not evidence; only observed command output and inspected lines count.'
  '- `N/A (<reason>)` is only for a surface the change does not touch. A missing execution, a skipped required gate, or an N/A without a stated reason is a finding, not N/A.'
)
for role in plugins/sdd-quality-loop/agents/evaluator.md \
  plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md \
  .codex/agents/sdd-evaluator.toml; do
  [[ -f "$ROOT/$role" ]] || fail "missing evaluator definition: $role"
  grep -Fxq '## Evidence Rules' "$ROOT/$role" || fail "$role lacks the Evidence Rules section"
  for rule in "${rules[@]}"; do
    grep -Fxq -- "$rule" "$ROOT/$role" || fail "$role lacks evidence rule: $rule"
  done
  grep -Fq 'G1' "$ROOT/$role" && grep -Fq 'G5' "$ROOT/$role" || fail "$role lost the G1-G5 perspectives"
done

# sdd-gate records the evaluator's actual model and checks the strong floor.
grep -Fq 'plugins/sdd-implementation/scripts/model-tier.py" check --role sdd-evaluator --model' "$GATE" ||
  fail "sdd-gate must check the evaluator's actual model against its floor"
grep -Fq -- '- **Evaluator Model**:' "$REPORT" || fail "sdd-gate report must record the evaluator model"
grep -Fq 'VERDICT: PASS' "$GATE" || fail "sdd-gate must define when VERDICT: PASS is allowed"

printf 'ok: v2 evaluator evidence rules are identical on every host and the model floor is recorded\n'
