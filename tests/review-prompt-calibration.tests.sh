#!/usr/bin/env bash
# Review prompt calibration inventory must stay in sync with reviewer contracts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS="$ROOT/plugins/sdd-review-loop/agents"
CHECKLIST="$ROOT/plugins/sdd-review-loop/references/phase-review-checklist.md"
CALIBRATION="plugins/sdd-review-loop/references/reviewer-calibration.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

[[ -f "$ROOT/$CALIBRATION" ]] || fail "missing reviewer calibration reference"

for file in \
  "$AGENTS/impl-reviewer-a.md" \
  "$AGENTS/impl-reviewer-b.md" \
  "$AGENTS/task-reviewer-a.md" \
  "$AGENTS/task-reviewer-b.md"; do
  grep -Fq "$CALIBRATION" "$file" || fail "${file##*/} must read reviewer calibration"
  grep -Fq '# Finding Calibration' "$file" || fail "${file##*/} must include finding calibration section"
done

for file in \
  "$ROOT/plugins/sdd-review-loop/templates/impl-review-contract.template.json" \
  "$ROOT/plugins/sdd-review-loop/templates/task-review-contract.template.json" \
  "$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.sh" \
  "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.sh" \
  "$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.ps1" \
  "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.ps1"; do
  grep -Fq "$CALIBRATION" "$file" || fail "${file##*/} must keep reviewer calibration in contract/precheck path"
done

grep -Fq 'impl-review-loop`: 19 checks' "$CHECKLIST" || fail "impl checklist count must be 19"
grep -Fq 'impl-reviewer-b (implementability/risk, 10 checks)' "$CHECKLIST" || fail "impl reviewer-b count must be 10"
grep -Fq 'task-review-loop`: 23 checks' "$CHECKLIST" || fail "task checklist count must be 23"
grep -Fq 'task-reviewer-b (quality/risk, 9 checks)' "$CHECKLIST" || fail "task reviewer-b count must be 9"
grep -Fq '#### VERIFICATION-PATH-CONCRETE' "$CHECKLIST" || fail "impl verification path check must be documented"
grep -Fq '#### BUGFIX-DIAGNOSTIC-PATH' "$CHECKLIST" || fail "task bugfix diagnostic check must be documented"

impl_b_checks="$(sed -n '/The `checks` array must contain one entry per check ID in this order:/,/^$/p' "$AGENTS/impl-reviewer-b.md" | tr '\n' ' ')"
task_b_checks="$(sed -n '/The `checks` array must contain one entry per check ID in this order:/,/^$/p' "$AGENTS/task-reviewer-b.md" | tr '\n' ' ')"

[[ "$impl_b_checks" == *"DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE."* ]] || fail "impl-reviewer-b ordered checks must include VERIFICATION-PATH-CONCRETE last"
[[ "$task_b_checks" == *"DEPENDENCY-OVERLAP, BUGFIX-DIAGNOSTIC-PATH."* ]] || fail "task-reviewer-b ordered checks must include BUGFIX-DIAGNOSTIC-PATH last"

printf 'ok: review prompt calibration inventory is synchronized\n'
