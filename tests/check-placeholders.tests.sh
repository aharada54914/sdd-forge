#!/usr/bin/env bash
# check-placeholders.tests.sh - TDD tests for check-placeholders.sh (issue #127)
# Focus: grep must distinguish a REAL error (exit >=2) from a clean "no match"
# (exit 1). A swallowed grep error previously reported a fail-open "passed".
# Style: mirrors prepare-panelist.tests.sh (ok/fail counters, mktemp fixtures,
# exits 1 on failure).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SC="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-placeholders.sh"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Run check-placeholders.sh capturing stdout+stderr and exit code.
# Usage: run_cp [args...]  ->  sets $CP_OUTPUT and $CP_EXIT
run_cp() {
    CP_EXIT=0
    CP_OUTPUT="$(bash "$SC" "$@" 2>&1)" || CP_EXIT=$?
}

# ============================================================================
# CP-001: a changed file WITH a placeholder marker is detected (exit 1)
# ============================================================================

echo "=== CP-001: dirty file is flagged ==="
printf 'def f():\n    pass  # TODO implement this\n' > "${WORK}/dirty.py"
run_cp "${WORK}/dirty.py"
if [ "${CP_EXIT}" -eq 1 ]; then
    ok "CP-001a: dirty file exits 1"
else
    fail "CP-001a: dirty file should exit 1, got ${CP_EXIT}. Output: ${CP_OUTPUT}"
fi
if echo "${CP_OUTPUT}" | grep -q "Placeholder scan FAILED"; then
    ok "CP-001b: dirty file reports FAILED"
else
    fail "CP-001b: dirty file should report FAILED. Output: ${CP_OUTPUT}"
fi

# ============================================================================
# CP-002: a clean file passes (exit 0)
# ============================================================================

echo "=== CP-002: clean file passes ==="
printf 'x = 1\n' > "${WORK}/clean.py"
run_cp "${WORK}/clean.py"
if [ "${CP_EXIT}" -eq 0 ]; then
    ok "CP-002a: clean file exits 0"
else
    fail "CP-002a: clean file should exit 0, got ${CP_EXIT}. Output: ${CP_OUTPUT}"
fi
if echo "${CP_OUTPUT}" | grep -q "Placeholder scan passed"; then
    ok "CP-002b: clean file reports passed"
else
    fail "CP-002b: clean file should report passed. Output: ${CP_OUTPUT}"
fi

# ============================================================================
# CP-003: a REAL grep error (nonexistent path -> grep exit 2) must fail
#         closed, NOT be swallowed and reported as a false "passed" pass.
#         This is the issue #127 regression: exit >=2 is a hard error.
# ============================================================================

echo "=== CP-003: real grep error fails closed (issue #127) ==="
run_cp "${WORK}/does-not-exist.py"
if [ "${CP_EXIT}" -ge 2 ]; then
    ok "CP-003a: missing path exits >=2 (got ${CP_EXIT})"
else
    fail "CP-003a: missing path must exit >=2 (real grep error), got ${CP_EXIT}. Output: ${CP_OUTPUT}"
fi
if echo "${CP_OUTPUT}" | grep -q "FATAL"; then
    ok "CP-003b: missing path prints a FATAL diagnostic"
else
    fail "CP-003b: missing path should print a FATAL diagnostic. Output: ${CP_OUTPUT}"
fi
if echo "${CP_OUTPUT}" | grep -q "Placeholder scan passed"; then
    fail "CP-003c: missing path must NOT report a false 'passed'. Output: ${CP_OUTPUT}"
else
    ok "CP-003c: missing path does not report a false 'passed'"
fi

# ============================================================================
# CP-004: recursive scan of a directory still detects a nested marker (exit 1)
# ============================================================================

echo "=== CP-004: recursive directory scan still works ==="
mkdir -p "${WORK}/tree/sub"
printf 'ok = 1\n' > "${WORK}/tree/clean.py"
printf 'raise NotImplementedError\n' > "${WORK}/tree/sub/stub.py"
run_cp "${WORK}/tree"
if [ "${CP_EXIT}" -eq 1 ]; then
    ok "CP-004: directory with a nested marker exits 1"
else
    fail "CP-004: recursive scan should exit 1, got ${CP_EXIT}. Output: ${CP_OUTPUT}"
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
