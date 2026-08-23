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
IMPL_REPORT_VALIDATOR="$REPO_ROOT/plugins/sdd-implementation/scripts/validate-implementation-report.sh"

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

# Rule 3: the "## Outputs" table must declare outputs in the row shape
# evaluator_output_is_declared parses. The bash replica below tracks the
# validator's parser verbatim.
# WFI-036 parameterised the section heading so a second declaration channel
# (the gate report's `## Post-Fix Artifacts`) could reuse the same row parser.
# The heading arrives as a variable and is matched by prefix-plus-trailing-
# whitespace instead of a baked-in regex.
#
# Row matching tolerates annotation around either backtick-quoted cell value
# (a report is expected to say when a row was added, drifted, or is shared;
# see the validator's own comment on evaluator_output_is_declared for the
# three real annotated shapes and why loosening the match cannot loosen
# authorization). Path and hash are still each captured positionally -- the
# first backtick pair after the row's opening "| " and the first backtick
# pair after the next "| " -- and compared with `==` against the caller's
# exact expected values, never substring-matched.
declared() {
    local expected_path=$1 expected_hash=$2 report=$3
    local heading='## Outputs'
    local row_pattern='^\|[[:space:]]*`([^`]+)`[^|]*\|[[:space:]]*`([0-9a-f]{64})`[^|]*\|[[:space:]]*$'
    local in_outputs=false found=false line remainder
    while IFS= read -r line || [[ -n "$line" ]]; do
        if ! $in_outputs; then
            if [[ "$line" == "$heading"* ]]; then
                remainder=${line#"$heading"}
                [[ "$remainder" =~ ^[[:space:]]*$ ]] && in_outputs=true
            fi
            continue
        fi
        [[ "$line" =~ ^##[[:space:]] ]] && break
        if [[ "$line" =~ $row_pattern ]]; then
            [[ "${BASH_REMATCH[1]}" == "$expected_path" && "${BASH_REMATCH[2]}" == "$expected_hash" ]] &&
                found=true
        fi
    done < "$report"
    $found
}
if declared "$OUT_PATH" "$OUT_HASH" "$IMPL_RENDERED"; then
    ok "impl-report template: Outputs table row parses via the evaluator's declared-output rule"
else
    fail "impl-report template: Outputs table row NOT recognized by the evaluator's declared-output parser"
fi
# Pin both halves of the parameterised form. The heading-match construct alone
# would not catch the boundary being pointed at a different section, and the
# literal '## Outputs' alone would not catch the matcher itself being replaced;
# the template and the boundary can only drift apart if one of these two moves.
if grep -Fq '"$line" == "$heading"*' "$VALIDATOR" &&
    grep -Fq "'## Outputs'" "$VALIDATOR"; then
    ok "validator pin: Outputs-section parser still present in launch boundary"
else
    fail "validator pin: Outputs-section parser changed in launch boundary"
fi

# ---------------------------------------------------------------------------
# WFI-017 leg: implementation report template vs its OWN authoring-time
# validator (validate-implementation-report.sh). `render` above only fills
# the placeholders the other legs care about, leaving every other field as
# inert "fixture-value" text -- not enough to satisfy the full validator
# (Test Result enum, Task Attempt Count, escalation vacuity, Isolation Mode,
# Current Status enum). `render_impl_report_ok` renders straight from the
# template with the superset of substitutions needed to pass every rule,
# proving the template's CURRENT "## Outputs" table form satisfies the
# validator end-to-end, not just the single-row shape Rule 3 already pins.
# ---------------------------------------------------------------------------
render_impl_report_ok() {
    sed \
        -e "s|{{task_id}}|$TASK_ID|g" \
        -e "s|{{output_path}}|$OUT_PATH|g" \
        -e "s|{{output_sha256}}|$OUT_HASH|g" \
        -e "s|{{model}}|anthropic/opus|g" \
        -e "s|{{effort}}|standard|g" \
        -e "s|{{PASS_or_FAIL_or_BLOCKED_or_NOT_RUN}}|PASS|g" \
        -e "s|{{task_attempt_count}}|1|g" \
        -e "s|{{escalation_prior_tier}}|None|g" \
        -e "s|{{escalation_next_tier}}|None|g" \
        -e "s|{{escalation_failure_class}}|None|g" \
        -e "s|{{escalation_attempt_number}}|None|g" \
        -e "s|{{escalation_reason}}|None|g" \
        -e "s|{{isolation_mode}}|fresh-agent|g" \
        -e "s|{{fallback_reason_or_none}}|None|g" \
        -e "s|{{handoff_reload_evidence_hash_or_none}}|None|g" \
        -e "s|{{handoff_status}}|Implementation Complete|g" \
        -e "s|{{[a-zA-Z_|]*}}|fixture-value|g" \
        "$1"
}
IMPL_FULL_RENDERED="$WORK/impl-report-full.md"
render_impl_report_ok "$IMPL_TEMPLATE" > "$IMPL_FULL_RENDERED"

IMPL_VALIDATOR_OUTPUT="$(bash "$IMPL_REPORT_VALIDATOR" "$IMPL_FULL_RENDERED" 2>&1 || true)"
if [[ "$IMPL_VALIDATOR_OUTPUT" == "IMPLEMENTATION_REPORT_OK" ]]; then
    ok "impl-report template: rendered report passes validate-implementation-report.sh"
else
    fail "impl-report template: rendered report rejected by validate-implementation-report.sh (got: $IMPL_VALIDATOR_OUTPUT)"
fi
grep -Fq 'outputs_row_pattern = re.compile(' "$IMPL_REPORT_VALIDATOR" &&
    ok "validator pin: Outputs-table row parser still present in validate-implementation-report.sh" ||
    fail "validator pin: Outputs-table row parser missing from validate-implementation-report.sh"

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
