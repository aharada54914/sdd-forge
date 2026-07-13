#!/usr/bin/env bash
# quality-gate-cycle-limit.tests.sh - TDD tests for check-quality-gate-cycle-limit.sh/.ps1
# (issue #112, REQ-003, AC-006). The quality-gate cycle limit must be a
# deterministic script pair, not prose: count gate reports under reports-dir
# whose CONTENT references a task id with WORD-BOUNDARY matching, print
# `continue` (exit 0) for 0/1/2 and `Escalate-Human` (exit 1) for 3+.
# Prefix collision (T-001 must not match T-0010), absent directory = 0,
# invalid task-id = usage error exit 2, and sh/ps1 parity are covered.
# Style: mirrors tests/check-placeholders.tests.sh (ok/fail counters, mktemp
# fixtures, trap cleanup, exit 1 on failure).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH_SCRIPT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh"
PS_SCRIPT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Locate a PowerShell interpreter, if any. Absent -> ps1 execution is skipped
# (noted), but the ASCII/BOM byte checks still run against the file.
PWSH=""
if command -v pwsh >/dev/null 2>&1; then
    PWSH="pwsh"
elif command -v powershell >/dev/null 2>&1; then
    PWSH="powershell"
fi

# run_sh <args...> -> sets $SH_OUTPUT (stdout+stderr) and $SH_EXIT
run_sh() {
    SH_EXIT=0
    SH_OUTPUT="$(bash "$SH_SCRIPT" "$@" 2>&1)" || SH_EXIT=$?
}

# run_ps <args...> -> sets $PS_OUTPUT (CR-stripped) and $PS_EXIT
run_ps() {
    PS_EXIT=0
    PS_OUTPUT="$("$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "$@" 2>&1)" || PS_EXIT=$?
    PS_OUTPUT="$(printf '%s' "$PS_OUTPUT" | tr -d '\r')"
}

# make_reports <dir> <count> <content-id> [template]
# Creates <count> report files under <dir> whose CONTENT references <content-id>.
# The filenames never contain the id, proving CONTENT-based matching.
make_reports() {
    local dir="$1" n="$2" id="$3" i
    local tmpl="${4:-Quality Gate Report\nTask ID: %s\nVERDICT: NEEDS_WORK\n}"
    mkdir -p "$dir"
    for i in $(seq 1 "$n"); do
        # shellcheck disable=SC2059
        printf "$tmpl" "$id" > "${dir}/report-${i}.md"
    done
}

# expect_continue <label> <task-id> <reports-dir>
expect_continue() {
    local label="$1" id="$2" dir="$3"
    run_sh "$id" "$dir"
    if [ "${SH_EXIT}" -eq 0 ] && echo "${SH_OUTPUT}" | grep -q '^continue$'; then
        ok "${label} (sh): continue / exit 0"
    else
        fail "${label} (sh): want continue/exit0, got exit=${SH_EXIT} out=[${SH_OUTPUT}]"
    fi
    if [ -n "${PWSH}" ]; then
        run_ps "$id" "$dir"
        if [ "${PS_EXIT}" -eq 0 ] && echo "${PS_OUTPUT}" | grep -q '^continue$'; then
            ok "${label} (ps1): continue / exit 0"
        else
            fail "${label} (ps1): want continue/exit0, got exit=${PS_EXIT} out=[${PS_OUTPUT}]"
        fi
    else
        ok "${label} (ps1): SKIPPED (no pwsh/powershell)"
    fi
}

# expect_escalate <label> <task-id> <reports-dir>
expect_escalate() {
    local label="$1" id="$2" dir="$3"
    run_sh "$id" "$dir"
    if [ "${SH_EXIT}" -eq 1 ] && echo "${SH_OUTPUT}" | grep -q '^Escalate-Human$'; then
        ok "${label} (sh): Escalate-Human / exit 1"
    else
        fail "${label} (sh): want Escalate-Human/exit1, got exit=${SH_EXIT} out=[${SH_OUTPUT}]"
    fi
    if [ -n "${PWSH}" ]; then
        run_ps "$id" "$dir"
        if [ "${PS_EXIT}" -eq 1 ] && echo "${PS_OUTPUT}" | grep -q '^Escalate-Human$'; then
            ok "${label} (ps1): Escalate-Human / exit 1"
        else
            fail "${label} (ps1): want Escalate-Human/exit1, got exit=${PS_EXIT} out=[${PS_OUTPUT}]"
        fi
    else
        ok "${label} (ps1): SKIPPED (no pwsh/powershell)"
    fi
}

# expect_usage_error <label> <task-id>
expect_usage_error() {
    local label="$1" id="$2"
    run_sh "$id" "${WORK}/any"
    if [ "${SH_EXIT}" -eq 2 ]; then
        ok "${label} (sh): usage error exit 2"
    else
        fail "${label} (sh): want exit 2, got exit=${SH_EXIT} out=[${SH_OUTPUT}]"
    fi
    if [ -n "${PWSH}" ]; then
        run_ps "$id" "${WORK}/any"
        if [ "${PS_EXIT}" -eq 2 ]; then
            ok "${label} (ps1): usage error exit 2"
        else
            fail "${label} (ps1): want exit 2, got exit=${PS_EXIT} out=[${PS_OUTPUT}]"
        fi
    else
        ok "${label} (ps1): SKIPPED (no pwsh/powershell)"
    fi
}

# ============================================================================
# QGCL-001..003: 0/1/2 reports -> continue (exit 0)
# ============================================================================
echo "=== QGCL-001: 0 reports (empty dir) -> continue ==="
mkdir -p "${WORK}/r0"
expect_continue "QGCL-001" "T-001" "${WORK}/r0"

echo "=== QGCL-002: 1 report -> continue ==="
make_reports "${WORK}/r1" 1 "T-001"
expect_continue "QGCL-002" "T-001" "${WORK}/r1"

echo "=== QGCL-003: 2 reports -> continue ==="
make_reports "${WORK}/r2" 2 "T-001"
expect_continue "QGCL-003" "T-001" "${WORK}/r2"

# ============================================================================
# QGCL-004: 3 reports -> Escalate-Human (exit 1)  [boundary]
# ============================================================================
echo "=== QGCL-004: 3 reports -> Escalate-Human ==="
make_reports "${WORK}/r3" 3 "T-001"
expect_escalate "QGCL-004" "T-001" "${WORK}/r3"

# ============================================================================
# QGCL-005: 4 reports -> Escalate-Human (exit 1)
# ============================================================================
echo "=== QGCL-005: 4 reports -> Escalate-Human ==="
make_reports "${WORK}/r4" 4 "T-001"
expect_escalate "QGCL-005" "T-001" "${WORK}/r4"

# ============================================================================
# QGCL-006: prefix collision - 3 reports referencing ONLY T-0010 must NOT
#           count for T-001 (word-boundary matching, mirroring issue #111).
# ============================================================================
echo "=== QGCL-006: prefix collision T-0010 does not count for T-001 ==="
make_reports "${WORK}/rc" 3 "T-0010"
expect_continue "QGCL-006" "T-001" "${WORK}/rc"

# ============================================================================
# QGCL-007: absent directory -> count 0 -> continue
# ============================================================================
echo "=== QGCL-007: absent reports dir -> continue ==="
expect_continue "QGCL-007" "T-001" "${WORK}/does-not-exist"

# ============================================================================
# QGCL-008: invalid task-id -> usage error exit 2
# ============================================================================
echo "=== QGCL-008: invalid task-id -> exit 2 ==="
expect_usage_error "QGCL-008a (too few digits)" "T-1"
expect_usage_error "QGCL-008b (four digits)"    "T-0010"
expect_usage_error "QGCL-008c (lowercase)"      "t-001"
expect_usage_error "QGCL-008d (non-task)"       "foo"
expect_usage_error "QGCL-008e (empty)"          ""

# ============================================================================
# QGCL-009: word-boundary robustness - id adjacent to punctuation counts,
#           id embedded in a longer word does NOT.
# ============================================================================
echo "=== QGCL-009: punctuation-adjacent counts, embedded does not ==="
make_reports "${WORK}/rp" 3 "T-001" 'gate for [T-001]: NEEDS_WORK\n'
expect_escalate "QGCL-009a (bracket/colon adjacent)" "T-001" "${WORK}/rp"
make_reports "${WORK}/re" 3 "xT-001x" 'token xT-001x appears\n'
expect_continue "QGCL-009b (embedded in word)" "T-001" "${WORK}/re"

# ============================================================================
# QGCL-010: default reports-dir argument (reports/quality-gate, cwd-relative)
# ============================================================================
echo "=== QGCL-010: default reports-dir = reports/quality-gate ==="
make_reports "${WORK}/cwd/reports/quality-gate" 3 "T-002"
DEF_SH_EXIT=0
DEF_SH_OUT="$(cd "${WORK}/cwd" && bash "$SH_SCRIPT" "T-002" 2>&1)" || DEF_SH_EXIT=$?
if [ "${DEF_SH_EXIT}" -eq 1 ] && echo "${DEF_SH_OUT}" | grep -q '^Escalate-Human$'; then
    ok "QGCL-010 (sh): default dir counts 3 -> Escalate-Human"
else
    fail "QGCL-010 (sh): want Escalate-Human/exit1, got exit=${DEF_SH_EXIT} out=[${DEF_SH_OUT}]"
fi
if [ -n "${PWSH}" ]; then
    DEF_PS_EXIT=0
    DEF_PS_OUT="$(cd "${WORK}/cwd" && "$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "T-002" 2>&1)" || DEF_PS_EXIT=$?
    DEF_PS_OUT="$(printf '%s' "$DEF_PS_OUT" | tr -d '\r')"
    if [ "${DEF_PS_EXIT}" -eq 1 ] && echo "${DEF_PS_OUT}" | grep -q '^Escalate-Human$'; then
        ok "QGCL-010 (ps1): default dir counts 3 -> Escalate-Human"
    else
        fail "QGCL-010 (ps1): want Escalate-Human/exit1, got exit=${DEF_PS_EXIT} out=[${DEF_PS_OUT}]"
    fi
else
    ok "QGCL-010 (ps1): SKIPPED (no pwsh/powershell)"
fi

# ============================================================================
# QGCL-011: explicit sh/ps1 output+exit parity on a shared fixture
# ============================================================================
echo "=== QGCL-011: sh/ps1 output+exit parity ==="
if [ -n "${PWSH}" ]; then
    for pair in "T-001:${WORK}/r0" "T-001:${WORK}/r2" "T-001:${WORK}/r3" "T-001:${WORK}/rc"; do
        pid="${pair%%:*}"; pdir="${pair#*:}"
        run_sh "$pid" "$pdir"
        run_ps "$pid" "$pdir"
        if [ "${SH_EXIT}" -eq "${PS_EXIT}" ] && [ "${SH_OUTPUT}" = "${PS_OUTPUT}" ]; then
            ok "QGCL-011: parity for ${pid} in ${pdir##*/} (exit=${SH_EXIT}, out=[${SH_OUTPUT}])"
        else
            fail "QGCL-011: mismatch for ${pid} in ${pdir##*/}: sh(exit=${SH_EXIT},[${SH_OUTPUT}]) vs ps(exit=${PS_EXIT},[${PS_OUTPUT}])"
        fi
    done
else
    ok "QGCL-011: parity SKIPPED (no pwsh/powershell)"
fi

# ============================================================================
# QGCL-012: .ps1 is ASCII-only (no byte > 0x7F) and has no BOM.
#           Byte-count method is the portable equivalent of
#           `LC_ALL=C grep -P '[^\x00-\x7F]'`.
# ============================================================================
echo "=== QGCL-012: .ps1 ASCII-only and no BOM ==="
if [ ! -f "$PS_SCRIPT" ]; then
    fail "QGCL-012: .ps1 script does not exist: ${PS_SCRIPT}"
else
    if command -v grep >/dev/null 2>&1 && printf 'a' | grep -qP 'a' 2>/dev/null; then
        if LC_ALL=C grep -qP '[^\x00-\x7F]' "$PS_SCRIPT"; then
            fail "QGCL-012a: .ps1 contains a non-ASCII byte (grep -P)"
        else
            ok "QGCL-012a: .ps1 is ASCII-only (grep -P)"
        fi
    else
        total="$(LC_ALL=C wc -c < "$PS_SCRIPT" | tr -d '[:space:]')"
        ascii="$(LC_ALL=C tr -cd '\000-\177' < "$PS_SCRIPT" | wc -c | tr -d '[:space:]')"
        if [ "$total" = "$ascii" ]; then
            ok "QGCL-012a: .ps1 is ASCII-only (byte count ${ascii}/${total})"
        else
            fail "QGCL-012a: .ps1 has non-ASCII bytes (ascii ${ascii} of ${total})"
        fi
    fi
    bom="$(LC_ALL=C head -c 3 "$PS_SCRIPT" | od -An -tx1 | tr -d ' \n')"
    if [ "$bom" = "efbbbf" ]; then
        fail "QGCL-012b: .ps1 starts with a UTF-8 BOM"
    else
        ok "QGCL-012b: .ps1 has no UTF-8 BOM"
    fi
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
