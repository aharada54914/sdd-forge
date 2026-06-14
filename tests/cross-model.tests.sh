#!/usr/bin/env bash
# cross-model.tests.sh — tests for check-cross-model.sh (AC-002..004)
# Style: mirrors gates.tests.sh (ok/fail counters, mktemp fixtures, exits 1 on failure)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
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
# Summary
# ============================================================================

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
