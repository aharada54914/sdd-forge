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

# Amendment Re-Review Context, impl/task stages: the recognition lives in the
# shared reviewer-calibration.md ONLY, because all four impl/task role files
# are guard-protected (PROTECTED_GATE_SUFFIXES) and cannot carry it. The
# load-bearing link is therefore each role file's existing directive to apply
# reviewer-calibration.md -- if that directive disappears from any role file,
# the lane silently dies for that role, so it is pinned here per file.

SHARED_CALIBRATION="plugins/sdd-review-loop/references/reviewer-calibration.md"
grep -Fq '## Amendment Re-Review Context (impl and task stages)' "$ROOT/$SHARED_CALIBRATION" || \
  fail "shared reviewer calibration missing the impl/task Amendment Re-Review Context section"
grep -Fq 'This is the amendment-supersession class only.' "$ROOT/$SHARED_CALIBRATION" || \
  fail "shared calibration must scope suppression to the amendment-supersession class only"
grep -Fq 'is judged exactly as it would be' "$ROOT/$SHARED_CALIBRATION" || \
  fail "shared calibration must state every other class is judged unaffected"
grep -Fq "full evidence bar" "$ROOT/$SHARED_CALIBRATION" && grep -Fq "spec-review-calibration.md" "$ROOT/$SHARED_CALIBRATION" || \
  fail "shared calibration must delegate the evidence bar to the spec calibration definition"
for role in impl-reviewer-a impl-reviewer-b task-reviewer-a task-reviewer-b; do
  grep -Fq 'reviewer-calibration.md' "$AGENTS/$role.md" || \
    fail "$role.md no longer references reviewer-calibration.md -- the amendment lane's load-bearing link is gone"
  grep -Eq 'reviewer-calibration\.md.*and apply it|apply it before' "$AGENTS/$role.md" || \
    fail "$role.md no longer directs the reviewer to APPLY reviewer-calibration.md"
done

printf 'ok: review prompt calibration inventory is synchronized\n'
