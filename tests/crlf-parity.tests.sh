#!/usr/bin/env bash
# crlf-parity.tests.sh — CRLF robustness regression for bash gate scripts.
# Proves that tasks.md files with CRLF line endings produce the same verdict
# as LF-only files. Mirrors the style of tests/gates.tests.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

check_risk_passes() {
    bash "${SCRIPTS_DIR}/check-risk.sh" "$1" "${2:-}" >/dev/null 2>&1
}
run_check_risk() {
    bash "${SCRIPTS_DIR}/check-risk.sh" "$1" "${2:-}" 2>&1 || true
}

check_task_state_passes() {
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$1" "$2" "$3" "$4" >/dev/null 2>&1
}
run_check_task_state() {
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$1" "$2" "$3" "$4" 2>&1 || true
}

# ============================================================================
# CRLF-1: check-risk — high task with CRLF line endings PASSES
# ============================================================================
echo "=== CRLF-1: check-risk with CRLF tasks.md ==="

# Build a tasks.md with CRLF line endings via printf \r\n
CRLF_RISK_DIR="${WORK}/crlf_risk"
mkdir -p "${CRLF_RISK_DIR}"
printf '# Tasks\r\n\r\n## T-001\r\n\r\nRisk: high\r\nRisk Rationale: payment path requires tight coverage\r\nRequired Workflow: tdd\r\nStatus: Planned\r\n' \
    > "${CRLF_RISK_DIR}/tasks_crlf.md"

if check_risk_passes "${CRLF_RISK_DIR}/tasks_crlf.md"; then
    ok "CRLF-1.1: high task with CRLF endings passes check-risk (exit 0)"
else
    fail "CRLF-1.1: high task with CRLF endings should pass check-risk: $(run_check_risk "${CRLF_RISK_DIR}/tasks_crlf.md")"
fi

# Verify the CRLF file actually contains \r (sanity-check the fixture itself)
# Use od (POSIX) to detect 0x0d bytes; avoid GNU-only cat -A.
if od -c "${CRLF_RISK_DIR}/tasks_crlf.md" | grep -q '\\r'; then
    ok "CRLF-1.2: fixture file confirmed to contain CR bytes (not already stripped)"
else
    fail "CRLF-1.2: fixture file must contain CR bytes — printf \\\\r\\\\n may have been swallowed"
fi

# ============================================================================
# CRLF-2: check-risk — LF control (same content, LF only) also PASSES
# ============================================================================
echo "=== CRLF-2: check-risk with LF tasks.md (control) ==="

LF_RISK_DIR="${WORK}/lf_risk"
mkdir -p "${LF_RISK_DIR}"
printf '# Tasks\n\n## T-001\n\nRisk: high\nRisk Rationale: payment path requires tight coverage\nRequired Workflow: tdd\nStatus: Planned\n' \
    > "${LF_RISK_DIR}/tasks_lf.md"

if check_risk_passes "${LF_RISK_DIR}/tasks_lf.md"; then
    ok "CRLF-2.1: high task with LF endings passes check-risk (control)"
else
    fail "CRLF-2.1: LF control should also pass check-risk"
fi

# ============================================================================
# CRLF-3: check-risk — critical task with CRLF endings PASSES
# ============================================================================
echo "=== CRLF-3: check-risk critical+CRLF ==="

CRLF_CRIT_DIR="${WORK}/crlf_critical"
mkdir -p "${CRLF_CRIT_DIR}"
printf '# Tasks\r\n\r\n## T-002\r\n\r\nRisk: critical\r\nRisk Rationale: settlement path\r\nRequired Workflow: tdd\r\nStatus: Planned\r\n' \
    > "${CRLF_CRIT_DIR}/tasks_crlf.md"

if check_risk_passes "${CRLF_CRIT_DIR}/tasks_crlf.md"; then
    ok "CRLF-3.1: critical task with CRLF endings passes check-risk"
else
    fail "CRLF-3.1: critical task with CRLF should pass check-risk: $(run_check_risk "${CRLF_CRIT_DIR}/tasks_crlf.md")"
fi

# ============================================================================
# CRLF-4: check-risk — CRLF file with bad risk value still FAILS (gate not neutered)
# ============================================================================
echo "=== CRLF-4: check-risk CRLF bad-value still fails ==="

CRLF_BAD_DIR="${WORK}/crlf_bad"
mkdir -p "${CRLF_BAD_DIR}"
printf '# Tasks\r\n\r\n## T-001\r\n\r\nRisk: extreme\r\nRisk Rationale: something\r\nStatus: Planned\r\n' \
    > "${CRLF_BAD_DIR}/tasks_crlf.md"

out=$(run_check_risk "${CRLF_BAD_DIR}/tasks_crlf.md")
if echo "$out" | grep -q "has invalid Risk:"; then
    ok "CRLF-4.1: CRLF file with invalid Risk value still fails correctly (gate not neutered)"
else
    fail "CRLF-4.1: CRLF file with bad Risk value must still fail: $out"
fi

# ============================================================================
# CRLF-5: check-task-state — task with CRLF line endings PASSES
# ============================================================================
echo "=== CRLF-5: check-task-state with CRLF tasks.md ==="

CRLF_TS_DIR="${WORK}/crlf_taskstate"
mkdir -p "${CRLF_TS_DIR}/reports/quality-gate"
mkdir -p "${CRLF_TS_DIR}/reports/implementation"
printf '# Tasks\r\n\r\n## T-001\r\n\r\nApproval: Approved\r\nStatus: In Progress\r\nRisk: high\r\n' \
    > "${CRLF_TS_DIR}/tasks_crlf.md"

if check_task_state_passes "${CRLF_TS_DIR}/tasks_crlf.md" \
    "${CRLF_TS_DIR}/reports/quality-gate" \
    "${CRLF_TS_DIR}/reports/implementation" \
    "${CRLF_TS_DIR}"; then
    ok "CRLF-5.1: Approved In-Progress task with CRLF endings passes check-task-state"
else
    fail "CRLF-5.1: CRLF task-state should pass: $(run_check_task_state \
        "${CRLF_TS_DIR}/tasks_crlf.md" \
        "${CRLF_TS_DIR}/reports/quality-gate" \
        "${CRLF_TS_DIR}/reports/implementation" \
        "${CRLF_TS_DIR}")"
fi

# ============================================================================
# CRLF-6: check-task-state — LF control also PASSES
# ============================================================================
echo "=== CRLF-6: check-task-state with LF tasks.md (control) ==="

LF_TS_DIR="${WORK}/lf_taskstate"
mkdir -p "${LF_TS_DIR}/reports/quality-gate"
mkdir -p "${LF_TS_DIR}/reports/implementation"
printf '# Tasks\n\n## T-001\n\nApproval: Approved\nStatus: In Progress\nRisk: high\n' \
    > "${LF_TS_DIR}/tasks_lf.md"

if check_task_state_passes "${LF_TS_DIR}/tasks_lf.md" \
    "${LF_TS_DIR}/reports/quality-gate" \
    "${LF_TS_DIR}/reports/implementation" \
    "${LF_TS_DIR}"; then
    ok "CRLF-6.1: LF tasks.md passes check-task-state (control)"
else
    fail "CRLF-6.1: LF control should pass check-task-state: $(run_check_task_state \
        "${LF_TS_DIR}/tasks_lf.md" \
        "${LF_TS_DIR}/reports/quality-gate" \
        "${LF_TS_DIR}/reports/implementation" \
        "${LF_TS_DIR}")"
fi

# ============================================================================
# CRLF-7: check-task-state — CRLF file requiring Approval still enforced
# ============================================================================
echo "=== CRLF-7: check-task-state CRLF Draft+InProgress still fails ==="

CRLF_TS_BAD_DIR="${WORK}/crlf_taskstate_bad"
mkdir -p "${CRLF_TS_BAD_DIR}/reports/quality-gate"
mkdir -p "${CRLF_TS_BAD_DIR}/reports/implementation"
printf '# Tasks\r\n\r\n## T-001\r\n\r\nApproval: Draft\r\nStatus: In Progress\r\n' \
    > "${CRLF_TS_BAD_DIR}/tasks_crlf.md"

out=$(run_check_task_state "${CRLF_TS_BAD_DIR}/tasks_crlf.md" \
    "${CRLF_TS_BAD_DIR}/reports/quality-gate" \
    "${CRLF_TS_BAD_DIR}/reports/implementation" \
    "${CRLF_TS_BAD_DIR}")
if echo "$out" | grep -q "without Approval: Approved"; then
    ok "CRLF-7.1: CRLF Draft+InProgress still fails check-task-state (gate not neutered)"
else
    fail "CRLF-7.1: CRLF Draft+InProgress must still fail: $out"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[[ $FAIL -eq 0 ]]
