#!/usr/bin/env bash
# check-risk-upgrade-byte-identical.tests.sh (epic-194-a6-lite-integration,
# T-002, design.md Test Strategy item 4, TEST-007/AC-007).
#
# Proves the extended script, invoked with NO second argument, is
# byte-identical (stdout + exit code) to today's live, unextended script,
# across the existing six-row keyword-scan fixture set reused as a
# regression baseline, plus a clean (no-match) fixture.
#
# NOTE (interim, pending human-copy staging unlock — see tasks.md T-001
# Blockers): the extended script under test lives at the .PROPOSED staging
# path below, not yet at the live plugins/sdd-lite/scripts/ path, because
# the R-10 guard currently denies staging it there (or applying it to the
# live path) with no human-copy exception. Once a human applies T-001's
# runner against this task's real staged payload, SUT below becomes the
# live path; this suite's assertions do not change, since they already
# require byte-for-byte parity with the live script.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
LIVE="${REPO_ROOT}/plugins/sdd-lite/scripts/check-risk-upgrade.sh"
SUT="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/PROPOSED/check-risk-upgrade.sh.PROPOSED"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

assert_identical() {
  local label="$1" fixture="$2"
  local live_out live_exit sut_out sut_exit
  live_out="$(bash "$LIVE" "$fixture" 2>&1)" && live_exit=0 || live_exit=$?
  sut_out="$(bash "$SUT" "$fixture" 2>&1)" && sut_exit=0 || sut_exit=$?
  if [ "$live_exit" -eq "$sut_exit" ]; then
    ok "${label}: exit code identical (${live_exit})"
  else
    fail "${label}: exit code differs (live=${live_exit}, sut=${sut_exit})"
  fi
  if [ "$live_out" = "$sut_out" ]; then
    ok "${label}: stdout byte-identical"
  else
    fail "${label}: stdout differs. live=[${live_out}] sut=[${sut_out}]"
  fi
}

printf 'just an ordinary sentence with nothing notable in it.\n' > "${WORK}/clean.txt"
assert_identical "TEST-007-clean" "${WORK}/clean.txt"

printf 'this endpoint needs oauth for authentication.\n' > "${WORK}/auth.txt"
assert_identical "TEST-007-auth" "${WORK}/auth.txt"

printf 'store the credential as a token, never a password.\n' > "${WORK}/token.txt"
assert_identical "TEST-007-token" "${WORK}/token.txt"

printf 'this integrates with an mcp server.\n' > "${WORK}/mcp.txt"
assert_identical "TEST-007-mcp" "${WORK}/mcp.txt"

printf 'calls a third-party API for external data.\n' > "${WORK}/api.txt"
assert_identical "TEST-007-api" "${WORK}/api.txt"

printf 'never log a secret value.\n' > "${WORK}/secret.txt"
assert_identical "TEST-007-secret" "${WORK}/secret.txt"

printf 'runs entirely inside github actions.\n' > "${WORK}/gha.txt"
assert_identical "TEST-007-github-actions" "${WORK}/gha.txt"

# Missing/unreadable input: byte-identical exit-2 unavailable path too.
assert_identical "TEST-007-unavailable" "${WORK}/does-not-exist.txt"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
