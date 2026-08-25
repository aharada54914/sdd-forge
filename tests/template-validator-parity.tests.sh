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
        -e "s|{{run_id}}|RUN-20260822T000000Z-fixture|g" \
        -e "s|{{critical_count}}|0|g" \
        -e "s|{{major_count}}|1|g" \
        -e "s|{{minor_count}}|2|g" \
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
# WFI-036 parameterised the section heading so a second declaration channel
# (the gate report's `## Post-Fix Artifacts`) could reuse the same row parser.
# The replica below tracks that change: the heading arrives as a variable and is
# matched by prefix-plus-trailing-whitespace instead of a baked-in regex. Row
# matching is unchanged -- still exact equality on the two-column backtick row.
declared() {
    awk -v expected_path="$1" -v expected_hash="$2" -v heading='## Outputs' '
        index($0, heading) == 1 && substr($0, length(heading) + 1) ~ /^[[:space:]]*$/ {
            in_outputs = 1
            next
        }
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
# Pin both halves of the parameterised form. The heading-match construct alone
# would not catch the boundary being pointed at a different section, and the
# literal '## Outputs' alone would not catch the matcher itself being replaced;
# the template and the boundary can only drift apart if one of these two moves.
# The heading matcher was tightened from a prefix test to an EXACT match at
# gate seq 851: the prefix form accepted `## Outputs ` while the report
# validator keyed that padded heading as a different section, and the
# disagreement smuggled arbitrary paths into an authorized input set. Pin the
# exact-match construct now, keeping both halves of the parameterised form.
if grep -Fq '$0 == heading' "$VALIDATOR" &&
    grep -Fq "'## Outputs'" "$VALIDATOR"; then
    ok "validator pin: Outputs-section parser still present in launch boundary"
else
    fail "validator pin: Outputs-section parser changed in launch boundary"
fi

# gate seq 853: tightening only the table heading left the LEGACY heading on a
# prefix test, so `## Output Paths And Hashes ` was still honoured here while
# the report validator skipped the section -- the same one-byte bypass moved to
# the other heading. Both matchers must stay exact, and neither may return to
# the prefix form.
if grep -Fq '$0 == "## Output Paths And Hashes"' "$VALIDATOR" &&
    ! grep -Fq 'index($0, "## Output Paths And Hashes") == 1' "$VALIDATOR" &&
    ! grep -Fq 'index($0, heading) == 1' "$VALIDATOR"; then
    ok "validator pin: both heading matchers in the launch boundary are exact"
else
    fail "validator pin: a launch-boundary heading matcher returned to a prefix test"
fi

# gate seq 856: awk DROPS a NUL as it reads a line, so no matcher written in
# awk can see one -- `$0 == heading` matched `## Outputs<NUL>` and this
# boundary authorized a section the report validator had rejected. Because
# report validity is not a precondition of authorization (WFI-050), that
# rejection carried no weight.
#
# The property under test is therefore the BOUNDARY ALONE: given a report, does
# it authorize a path it must not? The earlier suite tested the conjunction
# (report valid AND boundary authorizes), which is satisfied whenever either
# side refuses and so never measured this. Exercise the real functions, lifted
# out of the live script, rather than grepping for a construct.
boundary_harness="$WORK/boundary-alone.sh"
# Lift the three functions out of the live script. Done in python3 rather than
# `awk ... | awk` with an early exit: the downstream exit closes the pipe, the
# upstream awk takes SIGPIPE, and under `set -o pipefail` the suite dies with
# 141 -- nondeterministically, depending on which side finishes first.
python3 - "$VALIDATOR" "$boundary_harness" <<'PYHARNESS'
import sys

source, destination = sys.argv[1:]
text = open(source, encoding="utf-8").read()
start = text.index("report_bytes_are_clean() {")
end = start
for _ in range(3):
    end = text.index("\n}\n", end) + len("\n}\n")
open(destination, "w", encoding="utf-8").write(
    "#!/usr/bin/env bash\n"
    + text[start:end]
    + "if evaluator_output_is_declared \"$2\" \"$3\" \"$1\" '## Outputs'; then\n"
    "  echo AUTHORIZED\n"
    "elif implementation_report_legacy_declares \"$2\" \"$3\" \"$1\"; then\n"
    "  echo AUTHORIZED\n"
    "else\n"
    "  echo REFUSED\n"
    "fi\n"
)
PYHARNESS

smuggled_path='plugins/SMUGGLED-SECRET.md'
smuggled_hash="$(printf 'd%.0s' $(seq 64))"
boundary_bypasses=0
for boundary_pad in nul vt ff space tab nbsp zwsp; do
    boundary_report="$WORK/boundary-$boundary_pad.md"
    python3 - "$boundary_report" "$boundary_pad" "$smuggled_path" "$smuggled_hash" <<'PYBOUNDARY'
import sys
destination, pad_label, path, digest = sys.argv[1:]
pads = {"nul": "\x00", "vt": "\x0b", "ff": "\x0c", "space": " ",
        "tab": "\t", "nbsp": " ", "zwsp": "​"}
body = (
    "# Implementation Report\n\n## Outputs\n\n| Path | SHA-256 |\n| --- | --- |\n\n"
    "## Outputs" + pads[pad_label] + "\n\n"
    "| `" + path + "` | `" + digest + "` |\n"
)
open(destination, "wb").write(body.encode("utf-8"))
PYBOUNDARY
    if [ "$(bash "$boundary_harness" "$boundary_report" "$smuggled_path" "$smuggled_hash")" = AUTHORIZED ]; then
        boundary_bypasses=$((boundary_bypasses + 1))
        printf '    padded with %s: AUTHORIZED\n' "$boundary_pad" >&2
    fi
done

if [ "$boundary_bypasses" -eq 0 ]; then
    ok "boundary alone refuses every padded ## Outputs heading (7 pad forms)"
else
    fail "boundary alone authorized a smuggled path from $boundary_bypasses padded heading(s)"
fi

# Non-vacuity: the clean, unpadded declaration MUST still authorize, or the
# assertion above would pass on a boundary that authorizes nothing at all.
boundary_clean="$WORK/boundary-clean.md"
printf '# Implementation Report\n\n## Outputs\n\n| Path | SHA-256 |\n| --- | --- |\n| `%s` | `%s` |\n' \
    "$smuggled_path" "$smuggled_hash" > "$boundary_clean"
if [ "$(bash "$boundary_harness" "$boundary_clean" "$smuggled_path" "$smuggled_hash")" = AUTHORIZED ]; then
    ok "boundary alone still authorizes a clean, unpadded declaration"
else
    fail "boundary alone refuses a clean declaration -- the pad assertion is vacuous"
fi

# The byte screen is only load-bearing if BOTH declaration functions call it.
if [ "$(grep -c 'report_bytes_are_clean "\$report" || return 1' "$VALIDATOR")" -eq 2 ]; then
    ok "validator pin: both declaration functions screen report bytes before matching"
else
    fail "validator pin: a declaration function no longer screens report bytes"
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

# Rule 7 (WFI-020): the extended identity header — Run ID plus the
# Critical/Major/Minor lines generate-evidence-bundle parses (it records
# zeros when they are absent), rendered as bare numeric lines.
if grep -Eq "^Run ID:[[:space:]]*RUN-20260822T000000Z-fixture[[:space:]]*$" "$QG_RENDERED"; then
    ok "quality-report template: Run ID line present"
else
    fail "quality-report template: Run ID line missing"
fi
for sev_pair in "Critical=0" "Major=1" "Minor=2"; do
    sev_name="${sev_pair%%=*}"
    sev_val="${sev_pair##*=}"
    if grep -Eq "^${sev_name}:[[:space:]]*${sev_val}[[:space:]]*$" "$QG_RENDERED"; then
        ok "quality-report template: ${sev_name} count line present"
    else
        fail "quality-report template: ${sev_name} count line missing"
    fi
done

# Rule 8 (WFI-020): the run-record counter accepts the template's canonical
# `Task ID:` identity (the field-name split it used to have with
# check-evidence-bundle under-counted 219 of 220 committed reports).
EMIT_RUN_RECORD="$REPO_ROOT/plugins/sdd-quality-loop/scripts/emit-run-record.sh"
if grep -Fq '(Task ID|Task):' "$EMIT_RUN_RECORD"; then
    ok "consumer pin: run-record counter accepts the canonical Task ID identity"
else
    fail "consumer pin: run-record counter lacks the canonical Task ID identity"
fi
GEN_BUNDLE="$REPO_ROOT/plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh"
if grep -Fq 'Critical:' "$GEN_BUNDLE"; then
    ok "consumer pin: severity-count parser still present in generate-evidence-bundle"
else
    fail "consumer pin: severity-count parser missing from generate-evidence-bundle"
fi

printf '\ntemplate-validator-parity.tests.sh: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
