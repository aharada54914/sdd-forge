#!/usr/bin/env bash
# cross-model.tests.sh — tests for check-cross-model.sh (AC-002..004)
# Style: mirrors gates.tests.sh (ok/fail counters, mktemp fixtures, exits 1 on failure)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
POLICY_FILE="${REPO_ROOT}/plugins/sdd-quality-loop/references/cross-model-verification-policy.md"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ============================================================================
# Helpers
# ============================================================================

# Run check-cross-model.sh capturing both stdout+stderr and exit code.
# Usage: run_cross_model [args...]  →  sets $CM_OUTPUT and $CM_EXIT
run_cross_model() {
    CM_OUTPUT=$(bash "${SCRIPTS_DIR}/check-cross-model.sh" "$@" 2>&1) || CM_EXIT=$?
    CM_EXIT=${CM_EXIT:-0}
}

# Write a valid verdict JSON to a file.
# Args: path vendor verdict [critical_finding=0]
write_verdict() {
    local path="$1"
    local vendor="$2"
    local verdict_val="$3"
    local critical="${4:-0}"
    local digest="a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"

    local findings="[]"
    if [ "$critical" = "1" ]; then
        findings='[{"severity":"Critical","ref":"file:1","note":"critical issue"}]'
    fi

    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
{
  "schema": "cross-model-verdict/v1",
  "task_id": "T-002",
  "feature": "cross-model-verification",
  "vendor": "${vendor}",
  "model": "${vendor}-model-1",
  "verdict": "${verdict_val}",
  "findings": ${findings},
  "blind": true,
  "input_digest": "${digest}",
  "consent": { "kind": "human-flag", "ref": "tasks.md T-002 Cross-Model: enabled" }
}
EOF
}

# Write a verdict with custom digest
write_verdict_digest() {
    local path="$1"
    local vendor="$2"
    local verdict_val="$3"
    local digest="$4"

    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
{
  "schema": "cross-model-verdict/v1",
  "task_id": "T-002",
  "feature": "cross-model-verification",
  "vendor": "${vendor}",
  "model": "${vendor}-model-1",
  "verdict": "${verdict_val}",
  "findings": [],
  "blind": true,
  "input_digest": "${digest}",
  "consent": { "kind": "human-flag", "ref": "tasks.md T-002 Cross-Model: enabled" }
}
EOF
}

# Write a malformed verdict (blind=false)
write_verdict_no_blind() {
    local path="$1"
    local vendor="$2"

    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
{
  "schema": "cross-model-verdict/v1",
  "task_id": "T-002",
  "feature": "cross-model-verification",
  "vendor": "${vendor}",
  "model": "${vendor}-model-1",
  "verdict": "PASS",
  "findings": [],
  "blind": false,
  "input_digest": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
  "consent": { "kind": "human-flag", "ref": "tasks.md T-002 Cross-Model: enabled" }
}
EOF
}

# Write a verdict with bad input_digest (not 64 hex chars)
write_verdict_bad_digest() {
    local path="$1"
    local vendor="$2"

    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
{
  "schema": "cross-model-verdict/v1",
  "task_id": "T-002",
  "feature": "cross-model-verification",
  "vendor": "${vendor}",
  "model": "${vendor}-model-1",
  "verdict": "PASS",
  "findings": [],
  "blind": true,
  "input_digest": "not-a-hex-digest",
  "consent": { "kind": "human-flag", "ref": "tasks.md T-002 Cross-Model: enabled" }
}
EOF
}

# Write a verdict with missing consent.kind
write_verdict_no_consent() {
    local path="$1"
    local vendor="$2"

    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
{
  "schema": "cross-model-verdict/v1",
  "task_id": "T-002",
  "feature": "cross-model-verification",
  "vendor": "${vendor}",
  "model": "${vendor}-model-1",
  "verdict": "PASS",
  "findings": [],
  "blind": true,
  "input_digest": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
  "consent": {}
}
EOF
}

# ============================================================================
# AC-002: Diversity checks
# ============================================================================

echo "=== AC-002: Diversity checks ==="

# CM-001: Anthropic-only panel → fail (diversity)
mkdir -p "${WORK}/cm001/specs/f1/verification"
write_verdict "${WORK}/cm001/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm001/specs"
if [ "${CM_EXIT}" = "1" ]; then
    ok "CM-001: anthropic-only panel → exit 1 (diversity fail)"
else
    fail "CM-001: anthropic-only panel should exit 1, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# Verify aggregate written with FAIL
if [ -f "${WORK}/cm001/specs/f1/verification/T-002.cross-model.json" ]; then
    result=$(python3 -c "import json; d=json.load(open('${WORK}/cm001/specs/f1/verification/T-002.cross-model.json')); print(d['result'])")
    if [ "$result" = "FAIL" ]; then
        ok "CM-001b: aggregate result=FAIL written"
    else
        fail "CM-001b: aggregate result should be FAIL, got $result"
    fi
else
    fail "CM-001b: aggregate JSON should be written even on diversity fail"
fi

# CM-002: mixed panel (anthropic + openai) → pass (diversity satisfied)
mkdir -p "${WORK}/cm002/specs/f1/verification"
write_verdict "${WORK}/cm002/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
write_verdict "${WORK}/cm002/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm002/specs"
if [ "${CM_EXIT}" = "0" ]; then
    ok "CM-002: anthropic+openai panel → exit 0 (diversity satisfied)"
else
    fail "CM-002: anthropic+openai panel should pass diversity, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-003: no verdicts found → exit 2 (tool error)
mkdir -p "${WORK}/cm003/specs/f1/verification"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm003/specs"
if [ "${CM_EXIT}" = "2" ]; then
    ok "CM-003: no verdicts → exit 2 (tool error)"
else
    fail "CM-003: no verdicts should exit 2, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-004: two non-anthropic vendors → pass (distinct≥2, non_anthropic≥1)
mkdir -p "${WORK}/cm004/specs/f1/verification"
write_verdict "${WORK}/cm004/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS"
write_verdict "${WORK}/cm004/specs/f1/verification/T-002.panelist-google.verdict.json" "google" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm004/specs"
if [ "${CM_EXIT}" = "0" ]; then
    ok "CM-004: openai+google panel → pass (non_anthropic≥1, distinct≥2)"
else
    fail "CM-004: openai+google panel should pass, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# ============================================================================
# AC-003: Schema validation
# ============================================================================

echo "=== AC-003: Schema validation ==="

# CM-005: blind=false → exit 2 (malformed)
mkdir -p "${WORK}/cm005/specs/f1/verification"
write_verdict_no_blind "${WORK}/cm005/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai"
write_verdict "${WORK}/cm005/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm005/specs"
if [ "${CM_EXIT}" = "2" ]; then
    ok "CM-005: blind=false → exit 2 (schema error)"
else
    fail "CM-005: blind=false should exit 2, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-006: bad input_digest (not 64 hex) → exit 2
mkdir -p "${WORK}/cm006/specs/f1/verification"
write_verdict_bad_digest "${WORK}/cm006/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai"
write_verdict "${WORK}/cm006/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm006/specs"
if [ "${CM_EXIT}" = "2" ]; then
    ok "CM-006: bad input_digest → exit 2 (schema error)"
else
    fail "CM-006: bad input_digest should exit 2, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-007: missing consent.kind → exit 2
mkdir -p "${WORK}/cm007/specs/f1/verification"
write_verdict_no_consent "${WORK}/cm007/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai"
write_verdict "${WORK}/cm007/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm007/specs"
if [ "${CM_EXIT}" = "2" ]; then
    ok "CM-007: missing consent.kind → exit 2 (schema error)"
else
    fail "CM-007: missing consent.kind should exit 2, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# ============================================================================
# AC-004: Consensus checks
# ============================================================================

echo "=== AC-004: Consensus checks ==="

# CM-008: one NEEDS_WORK verdict → exit 1 (consensus fail)
mkdir -p "${WORK}/cm008/specs/f1/verification"
write_verdict "${WORK}/cm008/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
write_verdict "${WORK}/cm008/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "NEEDS_WORK"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm008/specs"
if [ "${CM_EXIT}" = "1" ]; then
    ok "CM-008: NEEDS_WORK verdict → exit 1 (consensus fail)"
else
    fail "CM-008: NEEDS_WORK verdict should exit 1, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-009: Critical finding → exit 1 even with all PASS
mkdir -p "${WORK}/cm009/specs/f1/verification"
write_verdict "${WORK}/cm009/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
write_verdict "${WORK}/cm009/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS" "1"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm009/specs"
if [ "${CM_EXIT}" = "1" ]; then
    ok "CM-009: Critical finding → exit 1 (consensus fail)"
else
    fail "CM-009: Critical finding should exit 1, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-010: all PASS, no critical → exit 0
mkdir -p "${WORK}/cm010/specs/f1/verification"
write_verdict "${WORK}/cm010/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
write_verdict "${WORK}/cm010/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm010/specs"
if [ "${CM_EXIT}" = "0" ]; then
    ok "CM-010: all PASS, no critical → exit 0"
else
    fail "CM-010: all PASS no critical should exit 0, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# Verify aggregate PASS result written
if [ -f "${WORK}/cm010/specs/f1/verification/T-002.cross-model.json" ]; then
    result=$(python3 -c "import json; d=json.load(open('${WORK}/cm010/specs/f1/verification/T-002.cross-model.json')); print(d['result'])")
    if [ "$result" = "PASS" ]; then
        ok "CM-010b: aggregate result=PASS written"
    else
        fail "CM-010b: aggregate should be PASS, got $result"
    fi
else
    fail "CM-010b: aggregate JSON should be written on pass"
fi

# CM-011: --evaluator PASS matches panel PASS → exit 0
mkdir -p "${WORK}/cm011/specs/f1/verification"
write_verdict "${WORK}/cm011/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
write_verdict "${WORK}/cm011/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --evaluator PASS --spec-root "${WORK}/cm011/specs"
if [ "${CM_EXIT}" = "0" ]; then
    ok "CM-011: --evaluator PASS matches panel PASS → exit 0"
else
    fail "CM-011: evaluator agrees with panel → should exit 0, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-012: --evaluator NEEDS_WORK diverges from panel PASS → exit 1, NEEDS_HUMAN
mkdir -p "${WORK}/cm012/specs/f1/verification"
write_verdict "${WORK}/cm012/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
write_verdict "${WORK}/cm012/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --evaluator NEEDS_WORK --spec-root "${WORK}/cm012/specs"
if [ "${CM_EXIT}" = "1" ]; then
    ok "CM-012: evaluator diverges → exit 1"
else
    fail "CM-012: evaluator diverge should exit 1, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi
if [ -f "${WORK}/cm012/specs/f1/verification/T-002.cross-model.json" ]; then
    rh=$(python3 -c "import json; d=json.load(open('${WORK}/cm012/specs/f1/verification/T-002.cross-model.json')); print(d.get('requires_human_decision',''))")
    res=$(python3 -c "import json; d=json.load(open('${WORK}/cm012/specs/f1/verification/T-002.cross-model.json')); print(d.get('result',''))")
    if [ "$rh" = "True" ] && [ "$res" = "NEEDS_HUMAN" ]; then
        ok "CM-012b: aggregate result=NEEDS_HUMAN, requires_human_decision=true"
    else
        fail "CM-012b: expected NEEDS_HUMAN/true, got result=$res requires_human_decision=$rh"
    fi
else
    fail "CM-012b: aggregate JSON should be written on divergence"
fi

# CM-013: --expect-digest matches all → exit 0
DIGEST="a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
mkdir -p "${WORK}/cm013/specs/f1/verification"
write_verdict_digest "${WORK}/cm013/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS" "$DIGEST"
write_verdict_digest "${WORK}/cm013/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS" "$DIGEST"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --expect-digest "$DIGEST" --spec-root "${WORK}/cm013/specs"
if [ "${CM_EXIT}" = "0" ]; then
    ok "CM-013: --expect-digest matches all → exit 0"
else
    fail "CM-013: digest match should exit 0, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-014: --expect-digest mismatch → exit 1
DIGEST2="b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3"
mkdir -p "${WORK}/cm014/specs/f1/verification"
write_verdict_digest "${WORK}/cm014/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS" "$DIGEST"
write_verdict_digest "${WORK}/cm014/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS" "$DIGEST"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --expect-digest "$DIGEST2" --spec-root "${WORK}/cm014/specs"
if [ "${CM_EXIT}" = "1" ]; then
    ok "CM-014: --expect-digest mismatch → exit 1"
else
    fail "CM-014: digest mismatch should exit 1, got ${CM_EXIT}. Output: ${CM_OUTPUT}"
fi

# CM-015: aggregate JSON has correct schema fields
mkdir -p "${WORK}/cm015/specs/f1/verification"
write_verdict "${WORK}/cm015/specs/f1/verification/T-002.panelist-anthropic.verdict.json" "anthropic" "PASS"
write_verdict "${WORK}/cm015/specs/f1/verification/T-002.panelist-openai.verdict.json" "openai" "PASS"
CM_EXIT=0
run_cross_model --task T-002 --feature f1 --spec-root "${WORK}/cm015/specs"
agg="${WORK}/cm015/specs/f1/verification/T-002.cross-model.json"
if [ -f "$agg" ]; then
    valid=$(python3 - <<PYEOF
import json, sys
d = json.load(open('${agg}'))
required = ['schema','task_id','feature','panelists','vendors_distinct','non_anthropic_count','all_pass','any_critical','evaluator_verdict','divergence','requires_human_decision','result']
missing = [k for k in required if k not in d]
if missing:
    print('MISSING:' + ','.join(missing))
    sys.exit(1)
if d['schema'] != 'cross-model-aggregate/v1':
    print('WRONG_SCHEMA:' + d['schema'])
    sys.exit(1)
print('OK')
PYEOF
)
    if [ "$valid" = "OK" ]; then
        ok "CM-015: aggregate JSON has all required fields"
    else
        fail "CM-015: aggregate JSON missing fields: $valid"
    fi
else
    fail "CM-015: aggregate JSON not created"
fi

# ============================================================================
# epic-136-phase4-docs T-001: POSIX runner timeout contract (AC-003..006,012)
# ============================================================================

echo "=== T-001: POSIX panelist runner timeout contract ==="

PANELIST_STUBS="${WORK}/panelist-stubs"
PANELIST_INPUT="${WORK}/panelist-input.txt"
mkdir -p "$PANELIST_STUBS"
printf '# sanitized test bundle\n' > "$PANELIST_INPUT"

write_panelist_stub() {
    local path="$1"
    local vendor="$2"
    cat > "$path" <<EOF
#!/bin/sh
printf 'called\n' >> "\${STUB_CALLED_FILE}"
case "\${STUB_MODE:-success}" in
    success)
        sleep "\${STUB_DELAY:-0}"
        ;;
    hang | ignore-term)
        printf '%s\n' "\$\$" > "\${STUB_PID_FILE}"
        (
            trap '' TERM
            _stub_child_end=\$(( \$(date +%s) + 30 ))
            while [ "\$(date +%s)" -lt "\$_stub_child_end" ]; do sleep 1; done
        ) &
        printf '%s\n' "\$!" > "\${STUB_CHILD_PID_FILE}"
        if [ "\${STUB_MODE}" = "ignore-term" ]; then
            trap '' TERM
        fi
        _stub_end=\$(( \$(date +%s) + 30 ))
        while [ "\$(date +%s)" -lt "\$_stub_end" ]; do sleep 1; done
        ;;
esac
cat <<JSON
{"schema":"cross-model-verdict/v1","task_id":"T-901","feature":"timeout-test","vendor":"${vendor}","model":"stub-model","verdict":"PASS","findings":[],"blind":true,"input_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","consent":{"kind":"human-flag","ref":"test"}}
JSON
EOF
    chmod +x "$path"
}

write_panelist_stub "${PANELIST_STUBS}/codex" "openai"
write_panelist_stub "${PANELIST_STUBS}/gemini" "google"

runner_path() {
    case "$1" in
        gpt) printf '%s\n' "${SCRIPTS_DIR}/run-panelist-gpt.sh" ;;
        gemini) printf '%s\n' "${SCRIPTS_DIR}/run-panelist-gemini.sh" ;;
    esac
}

runner_verdict_name() {
    case "$1" in
        gpt) printf '%s\n' 'T-901.panelist-openai.verdict.json' ;;
        gemini) printf '%s\n' 'T-901.panelist-google.verdict.json' ;;
    esac
}

run_panelist() {
    local runner="$1"
    local timeout_mode="$2"
    local timeout_value="${3:-}"
    local spec_root="$4"
    shift 4
    PANELIST_OUTPUT=""
    PANELIST_EXIT=0
    if [ "$timeout_mode" = "unset" ]; then
        PANELIST_OUTPUT=$(env -u SDD_PANELIST_TIMEOUT PATH="${PANELIST_STUBS}:$PATH" "$@" \
            sh "$runner" --task T-901 --feature timeout-test --input "$PANELIST_INPUT" \
            --spec-root "$spec_root" 2>&1) || PANELIST_EXIT=$?
    else
        PANELIST_OUTPUT=$(env SDD_PANELIST_TIMEOUT="$timeout_value" \
            PATH="${PANELIST_STUBS}:$PATH" "$@" \
            sh "$runner" --task T-901 --feature timeout-test --input "$PANELIST_INPUT" \
            --spec-root "$spec_root" 2>&1) || PANELIST_EXIT=$?
    fi
}

process_is_dead() {
    local pid="$1"
    local attempts=0
    while kill -0 "$pid" 2>/dev/null && [ "$attempts" -lt 20 ]; do
        sleep 0.1
        attempts=$((attempts+1))
    done
    ! kill -0 "$pid" 2>/dev/null
}

monotonic_ms() {
    python3 -c 'import time; print(time.monotonic_ns() // 1_000_000)'
}

# TEST-003 / AC-003: four valid values invoke the CLI; three invalid values do not.
for runner_kind in gpt gemini; do
    runner=$(runner_path "$runner_kind")
    case_dir="${WORK}/config-${runner_kind}"
    marker="${case_dir}/called"
    mkdir -p "$case_dir"

    for config_case in unset empty explicit-default one; do
        rm -f "$marker"
        default_from_source=$(sed -n 's/.*${SDD_PANELIST_TIMEOUT:-\([0-9][0-9]*\)}.*/\1/p' "$runner" | head -n 1)
        case "$config_case" in
            unset) run_panelist "$runner" unset "" "$case_dir" STUB_CALLED_FILE="$marker" ;;
            empty) run_panelist "$runner" set "" "$case_dir" STUB_CALLED_FILE="$marker" ;;
            explicit-default) run_panelist "$runner" set "$default_from_source" "$case_dir" STUB_CALLED_FILE="$marker" ;;
            one) run_panelist "$runner" set 1 "$case_dir" STUB_CALLED_FILE="$marker" ;;
        esac
        if [ "$PANELIST_EXIT" = "0" ] && [ -s "$marker" ]; then
            ok "TEST-003 ${runner_kind}/${config_case}: valid timeout invokes CLI"
        else
            fail "TEST-003 ${runner_kind}/${config_case}: expected CLI invocation and exit 0; exit=${PANELIST_EXIT}, output=${PANELIST_OUTPUT}"
        fi
    done

    for invalid_timeout in 0 -5 abc; do
        rm -f "$marker"
        run_panelist "$runner" set "$invalid_timeout" "$case_dir" STUB_CALLED_FILE="$marker"
        if [ "$PANELIST_EXIT" = "2" ] && [ ! -e "$marker" ]; then
            ok "TEST-003 ${runner_kind}/${invalid_timeout}: exit 2 without CLI invocation"
        else
            fail "TEST-003 ${runner_kind}/${invalid_timeout}: expected exit 2/no invocation; exit=${PANELIST_EXIT}, marker=$([ -e "$marker" ] && echo present || echo absent), output=${PANELIST_OUTPUT}"
        fi
    done
done

# TEST-012 / AC-012: derive, then compare, the defaults from runner source.
gpt_default=$(sed -n 's/.*${SDD_PANELIST_TIMEOUT:-\([0-9][0-9]*\)}.*/\1/p' "$(runner_path gpt)" | head -n 1)
gemini_default=$(sed -n 's/.*${SDD_PANELIST_TIMEOUT:-\([0-9][0-9]*\)}.*/\1/p' "$(runner_path gemini)" | head -n 1)
if [ -n "$gpt_default" ] && [ "$gpt_default" = "$gemini_default" ]; then
    ok "TEST-012: POSIX timeout defaults are derived from source and match (${gpt_default}s)"
else
    fail "TEST-012: runner-source defaults missing or unequal (gpt=${gpt_default:-missing}, gemini=${gemini_default:-missing})"
fi

run_timeout_case() {
    local runner_kind="$1"
    local stub_mode="$2"
    local label="$3"
    local runner
    runner=$(runner_path "$runner_kind")
    local case_dir="${WORK}/timeout-${runner_kind}-${label}"
    local marker="${case_dir}/called"
    local stub_pid_file="${case_dir}/stub.pid"
    local child_pid_file="${case_dir}/child.pid"
    local verdict="${case_dir}/timeout-test/verification/$(runner_verdict_name "$runner_kind")"
    mkdir -p "$case_dir"

    local started finished elapsed
    started=$(monotonic_ms)
    run_panelist "$runner" set 1 "$case_dir" \
        STUB_CALLED_FILE="$marker" STUB_MODE="$stub_mode" \
        STUB_PID_FILE="$stub_pid_file" STUB_CHILD_PID_FILE="$child_pid_file"
    finished=$(monotonic_ms)
    elapsed=$((finished-started))

    local stub_pid="" child_pid=""
    [ -s "$stub_pid_file" ] && stub_pid=$(cat "$stub_pid_file")
    [ -s "$child_pid_file" ] && child_pid=$(cat "$child_pid_file")
    local stub_dead=0 child_dead=0
    [ -n "$stub_pid" ] && process_is_dead "$stub_pid" && stub_dead=1
    [ -n "$child_pid" ] && process_is_dead "$child_pid" && child_dead=1

    echo "measurement: TEST-004(${label}) runner=${runner_kind} elapsed_ms=${elapsed} deadline_ms=1000 margin_ms=10000 stub_pid=${stub_pid:-missing} stub_alive=$((1-stub_dead)) child_pid=${child_pid:-missing} child_alive=$((1-child_dead))"
    if [ "$elapsed" -le 10000 ] && [ "$stub_dead" = "1" ] && [ "$child_dead" = "1" ]; then
        ok "TEST-004(${label}) ${runner_kind}: deadline enforced and process group is dead"
    else
        fail "TEST-004(${label}) ${runner_kind}: elapsed=${elapsed}ms stub_dead=${stub_dead} child_dead=${child_dead}"
    fi
    if [ "$PANELIST_EXIT" = "1" ] && [ ! -e "$verdict" ]; then
        ok "TEST-005 ${runner_kind}/${label}: timeout exits 1 with no verdict JSON"
    else
        fail "TEST-005 ${runner_kind}/${label}: expected exit 1/no verdict; exit=${PANELIST_EXIT}, verdict=$([ -e "$verdict" ] && echo present || echo absent)"
    fi
}

# TEST-004(a)/(b) and TEST-005 for both POSIX runners.
for runner_kind in gpt gemini; do
    run_timeout_case "$runner_kind" hang a
    run_timeout_case "$runner_kind" ignore-term b
done

# TEST-004(c): repeat the polling-boundary success case five times per runner.
for runner_kind in gpt gemini; do
    runner=$(runner_path "$runner_kind")
    for iteration in 1 2 3 4 5; do
        case_dir="${WORK}/boundary-${runner_kind}-${iteration}"
        marker="${case_dir}/called"
        verdict="${case_dir}/timeout-test/verification/$(runner_verdict_name "$runner_kind")"
        mkdir -p "$case_dir"
        started=$(monotonic_ms)
        run_panelist "$runner" set 2 "$case_dir" \
            STUB_CALLED_FILE="$marker" STUB_MODE=success STUB_DELAY=1.5
        finished=$(monotonic_ms)
        elapsed=$((finished-started))
        echo "measurement: TEST-004(c) runner=${runner_kind} iteration=${iteration} elapsed_ms=${elapsed} deadline_ms=2000 exit=${PANELIST_EXIT} verdict=$([ -f "$verdict" ] && echo present || echo absent)"
        if [ "$PANELIST_EXIT" = "0" ] && [ -f "$verdict" ]; then
            ok "TEST-004(c) ${runner_kind}/${iteration}: near-boundary completion stays successful"
        else
            fail "TEST-004(c) ${runner_kind}/${iteration}: exit=${PANELIST_EXIT}, output=${PANELIST_OUTPUT}"
        fi
    done
done

# TEST-006 / AC-006: a timed-out sole non-Anthropic panelist cannot yield PASS.
gate_root="${WORK}/timeout-gpt-a"
gate_verification="${gate_root}/timeout-test/verification"
mkdir -p "$gate_verification"
write_verdict "${gate_verification}/T-901.panelist-anthropic.verdict.json" "anthropic" "PASS"
CM_EXIT=0
run_cross_model --task T-901 --feature timeout-test --spec-root "$gate_root"
gate_aggregate="${gate_verification}/T-901.cross-model.json"
gate_result=""
[ -f "$gate_aggregate" ] && gate_result=$(python3 -c "import json; print(json.load(open('${gate_aggregate}'))['result'])")
if [ "$CM_EXIT" != "0" ] && [ "$gate_result" != "PASS" ] && ! printf '%s' "$CM_OUTPUT" | grep -q 'consensus PASS'; then
    ok "TEST-006: missing timed-out non-Anthropic verdict fails gate without consensus PASS"
else
    fail "TEST-006: expected non-zero/no PASS; exit=${CM_EXIT}, result=${gate_result:-missing}, output=${CM_OUTPUT}"
fi

# ============================================================================
# TEST-001 / TEST-002: shipped policy taxonomy
# ============================================================================

echo "=== TEST-001/002: panelist failure taxonomy ==="

assert_policy_taxonomy_row() {
    local mode="$1"
    if python3 - "$POLICY_FILE" "$mode" <<'PYEOF'
import pathlib
import re
import sys

policy_path, expected_mode = sys.argv[1:]
text = pathlib.Path(policy_path).read_text(encoding="utf-8")
match = re.search(
    r"^## Panelist Failure Taxonomy\s*$([\s\S]*?)(?=^##\s)",
    text,
    flags=re.MULTILINE,
)
if not match:
    raise SystemExit(1)

for line in match.group(1).splitlines():
    if not line.startswith("|"):
        continue
    cells = [cell.strip() for cell in line.strip("|").split("|")]
    if len(cells) != 4 or cells[0] != expected_mode:
        continue
    exit_code, verdict_file, gate_consequence = cells[1:]
    valid = (
        exit_code.startswith("`1`")
        and "`2`" not in exit_code
        and verdict_file.startswith("No.")
        and "diversity" in gate_consequence.lower()
        and "gate" in gate_consequence.lower()
        and "exit 1" in gate_consequence.lower()
        and "exit 2" in gate_consequence.lower()
    )
    raise SystemExit(0 if valid else 1)
raise SystemExit(1)
PYEOF
    then
        ok "TEST-001: ${mode} states exit, no-verdict, and gate propagation"
    else
        fail "TEST-001: ${mode} must state exit 1, no verdict, and diversity/gate propagation"
    fi
}

for mode in \
    "CLI absent" \
    "CLI exits non-zero" \
    "CLI rate-limited" \
    "CLI hangs / exceeds the time bound" \
    "CLI returns malformed output"; do
    assert_policy_taxonomy_row "$mode"
done

if python3 - "$POLICY_FILE" <<'PYEOF'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(
    r"^## Panelist Failure Taxonomy\s*$([\s\S]*?)(?=^##\s)",
    text,
    flags=re.MULTILINE,
)
section = re.sub(r"\s+", " ", match.group(1)) if match else ""
required = (
    "Rate-limiting is **not separately handled**" in section
    and "exit-non-zero or timeout" in section
)
raise SystemExit(0 if required else 1)
PYEOF
then
    ok "TEST-002: rate limiting is explicitly delegated to exit-non-zero or timeout"
else
    fail "TEST-002: rate limiting must be stated as not separately handled"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
