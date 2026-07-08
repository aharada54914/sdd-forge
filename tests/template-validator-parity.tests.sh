#!/usr/bin/env bash
# Template-validator parity (WFI-005): render each canonical gate-artifact
# template with fixture values and run the SAME parsing rules the enforcing
# validators apply, so a template that stops satisfying its consumers fails
# here at commit time instead of at gate time.
#
# Two-way binding: each parser rule replicated below is also pinned against
# the validator's source with a grep, so a change to the validator's parsing
# breaks this suite too and forces template + validator to move together.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
IMPL_TEMPLATE="$REPO_ROOT/plugins/sdd-implementation/templates/implementation-report.template.md"
QG_TEMPLATE="$REPO_ROOT/plugins/sdd-quality-loop/templates/quality-report.template.md"
VALIDATOR="$REPO_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
BUNDLE_CHECK="$REPO_ROOT/plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-parity.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ok()   { printf 'ok: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

TASK_ID="T-777"
FEATURE="example-feature"
OUT_PATH="plugins/example/skills/example/SKILL.md"
OUT_HASH="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

render() {
    # Substitute every {{placeholder}} the fixtures care about; any leftover
    # {{...}} tokens become inert dummy text so line shapes stay realistic.
    sed \
        -e "s|{{task_id}}|$TASK_ID|g" \
        -e "s|{{feature}}|$FEATURE|g" \
        -e "s|{{output_path}}|$OUT_PATH|g" \
        -e "s|{{output_sha256}}|$OUT_HASH|g" \
        -e "s|{{verdict}}|PASS|g" \
        -e "s|{{[a-zA-Z_|]*}}|fixture-value|g" \
        "$1"
}

# ---------------------------------------------------------------------------
# Implementation report template vs the evaluator launch boundary
# (validate-review-context-set.sh, quality:sdd-evaluator role)
# ---------------------------------------------------------------------------
IMPL_RENDERED="$WORK/impl-report.md"
render "$IMPL_TEMPLATE" > "$IMPL_RENDERED"

# Rule 1: line 1 must be exactly "# Implementation Report: T-NNN".
if [[ "$(sed -n '1p' "$IMPL_RENDERED")" == "# Implementation Report: $TASK_ID" ]]; then
    ok "impl-report template: heading line matches the evaluator boundary"
else
    fail "impl-report template: heading line does not match (got: $(sed -n '1p' "$IMPL_RENDERED"))"
fi
grep -Fq 'Implementation Report: $task_id' "$VALIDATOR" &&
    ok "validator pin: heading rule still present in launch boundary" ||
    fail "validator pin: heading rule text changed in launch boundary -- update this suite and the template together"

# Rule 2: a full-line "- Task ID: T-NNN" must exist.
if grep -Fxq -- "- Task ID: $TASK_ID" "$IMPL_RENDERED"; then
    ok "impl-report template: '- Task ID:' line present"
else
    fail "impl-report template: '- Task ID:' full-line match missing"
fi
grep -Fq -- '- Task ID: $task_id' "$VALIDATOR" &&
    ok "validator pin: Task ID rule still present in launch boundary" ||
    fail "validator pin: Task ID rule text changed in launch boundary"

# Rule 3: the "## Outputs" table must declare outputs in the exact row shape
# evaluator_output_is_declared parses. The awk program below replicates the
# validator's parser verbatim.
declared() {
    awk -v expected_path="$1" -v expected_hash="$2" '
        /^## Outputs[[:space:]]*$/ { in_outputs = 1; next }
        in_outputs && /^##[[:space:]]/ { exit }
        in_outputs {
            expected_line = "| `" expected_path "` | `" expected_hash "` |"
            if ($0 == expected_line) found = 1
        }
        END { exit(found ? 0 : 1) }
    ' "$3"
}
if declared "$OUT_PATH" "$OUT_HASH" "$IMPL_RENDERED"; then
    ok "impl-report template: Outputs table row parses via the evaluator's declared-output rule"
else
    fail "impl-report template: Outputs table row NOT recognized by the evaluator's declared-output parser"
fi
grep -Fq '/^## Outputs[[:space:]]*$/' "$VALIDATOR" &&
    ok "validator pin: Outputs-section parser still present in launch boundary" ||
    fail "validator pin: Outputs-section parser changed in launch boundary"

# ---------------------------------------------------------------------------
# Quality gate report template vs the evidence-bundle validator
# (check-evidence-bundle.sh) and the task-state gate
# ---------------------------------------------------------------------------
QG_RENDERED="$WORK/quality-report.md"
render "$QG_TEMPLATE" > "$QG_RENDERED"

# Rule 4: exactly one "Feature:" line whose value equals the contract feature.
FEATURE_LINES=$(grep -c '^Feature:' "$QG_RENDERED" || true)
FEATURE_VALUE=$(sed -n 's/^Feature:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' "$QG_RENDERED" | head -1)
if [[ "$FEATURE_LINES" -eq 1 && "$FEATURE_VALUE" == "$FEATURE" ]]; then
    ok "quality-report template: single Feature: line with the contract feature value"
else
    fail "quality-report template: Feature: line count=$FEATURE_LINES value='$FEATURE_VALUE' (expected 1/'$FEATURE')"
fi
grep -Eq 'Feature:' "$BUNDLE_CHECK" &&
    ok "validator pin: Feature rule still present in evidence-bundle validator" ||
    fail "validator pin: Feature rule missing from evidence-bundle validator"

# Rule 5: "Task ID: T-NNN" line (check-evidence-bundle + check-task-state Done path).
if grep -Eq "^Task ID:[[:space:]]*$TASK_ID[[:space:]]*$" "$QG_RENDERED"; then
    ok "quality-report template: Task ID line present"
else
    fail "quality-report template: Task ID line missing"
fi

# Rule 6: "VERDICT:" line (check-task-state Done requires VERDICT: PASS).
if grep -Eq "^VERDICT:[[:space:]]*PASS[[:space:]]*$" "$QG_RENDERED"; then
    ok "quality-report template: VERDICT line present"
else
    fail "quality-report template: VERDICT line missing"
fi

printf '\ntemplate-validator-parity.tests.sh: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
