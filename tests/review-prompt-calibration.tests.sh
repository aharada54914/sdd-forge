#!/usr/bin/env bash
# Review prompt calibration inventory must stay in sync with reviewer contracts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS="$ROOT/plugins/sdd-review-loop/agents"
CHECKLIST="$ROOT/plugins/sdd-review-loop/references/phase-review-checklist.md"
CALIBRATION="plugins/sdd-review-loop/references/reviewer-calibration.md"
SPEC_CALIBRATION="plugins/sdd-review-loop/references/spec-review-calibration.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

[[ -f "$ROOT/$CALIBRATION" ]] || fail "missing reviewer calibration reference"
[[ -f "$ROOT/$SPEC_CALIBRATION" ]] || fail "missing spec review calibration reference"

for file in \
  "$AGENTS/spec-reviewer-a.md" \
  "$AGENTS/spec-reviewer-b.md"; do
  grep -Fq "$SPEC_CALIBRATION" "$file" || fail "${file##*/} must read spec review calibration"
  grep -Fq '# Finding Calibration' "$file" || fail "${file##*/} must include finding calibration section"
done

for file in \
  "$AGENTS/impl-reviewer-a.md" \
  "$AGENTS/impl-reviewer-b.md" \
  "$AGENTS/task-reviewer-a.md" \
  "$AGENTS/task-reviewer-b.md"; do
  grep -Fq "$CALIBRATION" "$file" || fail "${file##*/} must read reviewer calibration"
  grep -Fq '# Finding Calibration' "$file" || fail "${file##*/} must include finding calibration section"
done

for file in \
  "$ROOT/plugins/sdd-review-loop/templates/spec-review-contract.template.json" \
  "$ROOT/plugins/sdd-review-loop/scripts/spec-review-precheck.sh"; do
  grep -Fq "$SPEC_CALIBRATION" "$file" || fail "${file##*/} must keep spec calibration in contract/precheck path"
done

SPEC_PRECHECK="$ROOT/plugins/sdd-review-loop/scripts/spec-review-precheck.sh"
grep -Fq -- 'calibration_hash="$(jq -r --arg calibration "$calibration"' "$SPEC_PRECHECK" || \
  fail "spec precheck must validate prior rounds against the contract calibration hash"
grep -Fq -- '--arg calibration_hash "$calibration_hash"' "$SPEC_PRECHECK" || \
  fail "spec precheck expected manifest must use the frozen contract calibration hash"
if grep -Fq -- '--arg calibration_hash "$(sha256 "$calibration")"' "$SPEC_PRECHECK"; then
  fail "spec precheck must not recompute live calibration hash for prior-round validation"
fi

for file in \
  "$ROOT/plugins/sdd-review-loop/templates/impl-review-contract.template.json" \
  "$ROOT/plugins/sdd-review-loop/templates/task-review-contract.template.json" \
  "$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.sh" \
  "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.sh" \
  "$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.ps1" \
  "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.ps1"; do
  grep -Fq "$CALIBRATION" "$file" || fail "${file##*/} must keep reviewer calibration in contract/precheck path"
done

grep -Fq 'spec-review-loop`: 14 checks' "$CHECKLIST" || fail "spec checklist count must be 14"
grep -Fq 'spec-reviewer-a (requirements and acceptance coverage, 7' "$CHECKLIST" || fail "spec reviewer-a count must be 7"
grep -Fq 'spec-reviewer-b (ambiguity, contradiction, and downstream readiness,' "$CHECKLIST" || fail "spec reviewer-b count must be 7"
grep -Fq 'impl-review-loop`: 22 checks' "$CHECKLIST" || fail "impl checklist count must be 22"
grep -Fq 'impl-reviewer-b (implementability/risk, 11 checks)' "$CHECKLIST" || fail "impl reviewer-b count must be 11"
grep -Fq '#### DOMAIN-CONFORMANCE' "$CHECKLIST" || fail "DOMAIN-CONFORMANCE must be documented in the checklist"
grep -Fq 'task-review-loop`: 23 checks' "$CHECKLIST" || fail "task checklist count must be 23"
grep -Fq 'task-reviewer-b (quality/risk, 9 checks)' "$CHECKLIST" || fail "task reviewer-b count must be 9"
grep -Fq '#### VERIFICATION-PATH-CONCRETE' "$CHECKLIST" || fail "impl verification path check must be documented"
grep -Fq '#### BUGFIX-DIAGNOSTIC-PATH' "$CHECKLIST" || fail "task bugfix diagnostic check must be documented"

impl_b_checks="$(sed -n '/The `checks` array must contain one entry per check ID in this order:/,/^$/p' "$AGENTS/impl-reviewer-b.md" | tr '\n' ' ')"
task_b_checks="$(sed -n '/The `checks` array must contain one entry per check ID in this order:/,/^$/p' "$AGENTS/task-reviewer-b.md" | tr '\n' ' ')"
spec_a_checks="$(sed -n '/The `checks` array must contain one entry per check ID in this order:/,/^$/p' "$AGENTS/spec-reviewer-a.md" | tr '\n' ' ')"
spec_b_checks="$(sed -n '/The `checks` array must contain one entry per check ID in this order:/,/^$/p' "$AGENTS/spec-reviewer-b.md" | tr '\n' ' ')"

[[ "$impl_b_checks" == *"DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE, DOMAIN-CONFORMANCE."* ]] || fail "impl-reviewer-b ordered checks must end VERIFICATION-PATH-CONCRETE, DOMAIN-CONFORMANCE"
[[ "$task_b_checks" == *"DEPENDENCY-OVERLAP, BUGFIX-DIAGNOSTIC-PATH."* ]] || fail "task-reviewer-b ordered checks must include BUGFIX-DIAGNOSTIC-PATH last"
[[ "$spec_a_checks" == *"REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE, SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE, DOMAIN-CONFORMANCE."* ]] || fail "spec-reviewer-a ordered checks must match the precheck expected_ids"
[[ "$spec_b_checks" == *"AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE, ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS, DOMAIN-CONFORMANCE."* ]] || fail "spec-reviewer-b ordered checks must match the precheck expected_ids"

# The spec roles and spec-review-precheck each hold their own copy of the id
# list, and spec-review-precheck compares them byte-for-byte at every round.
# They drifted apart once: the roles gained DOMAIN-CONFORMANCE while the gate
# kept six ids, which made every spec-review round 2 unreachable. Nothing caught
# it, because this suite was not registered in run-all.sh. Compare the two copies
# directly rather than asserting each against a hand-written literal.
extract_role_ids() {
  sed -n '/The `checks` array must contain one entry per check ID in this order:/,/^$/p' "$1" \
    | tr '\n' ' ' | sed 's/.*order: *//' | tr -d '`' \
    | sed 's/\.[[:space:]]*$//' | sed 's/, */,/g' | sed 's/[[:space:]]*$//'
}
for role in a b; do
  role_ids="$(extract_role_ids "$AGENTS/spec-reviewer-${role}.md")"
  gate_ids="$(grep -A1 "spec-reviewer-${role})" "$SPEC_PRECHECK" | sed -n 's/.*expected_ids="\(.*\)"/\1/p')"
  [[ -n "$gate_ids" ]] || fail "could not read expected_ids for spec-reviewer-${role} from spec-review-precheck.sh"
  [[ "$role_ids" == "$gate_ids" ]] || \
    fail "spec-reviewer-${role} id list drifted from the gate: role=[${role_ids}] gate=[${gate_ids}]"
done

printf 'ok: review prompt calibration inventory is synchronized\n'
