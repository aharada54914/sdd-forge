#!/usr/bin/env bash
# lite-gate-summary-absent.tests.sh (epic-194-a6-lite-integration, T-004,
# design.md Test Strategy item 8, TEST-011, AC-011).
#
# No Project Context and no capability-summary.yaml at all (disabled-legacy)
# runs exactly the five baseline checks unchanged -- Step 2a produces an
# empty required_lite_checks list without treating the absent Summary as a
# failure, and no command-discovery is attempted for the five baseline
# names.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
source "${REPO_ROOT}/tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.sh"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

echo "=== TEST-011: disabled-legacy (no Project Context, no Summary) runs unchanged ==="
simulate_lite_gate_step2 "" "none" "${WORK}"
if [ "${SIM_VERDICT}" = "PASS" ]; then
  ok "TEST-011a: disabled-legacy VERDICT: PASS (no Summary is legitimate, not a failure)"
else
  fail "TEST-011a: expected PASS, got ${SIM_VERDICT} (${SIM_REASON})"
fi
if [ -z "${SIM_RAN_CHECKS}" ]; then
  ok "TEST-011b: no Registry-sourced command-discovery attempted (required_lite_checks is empty)"
else
  fail "TEST-011b: expected no discovery, got [${SIM_RAN_CHECKS}]"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
