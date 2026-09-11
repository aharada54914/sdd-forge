#!/usr/bin/env bash
# check-risk-upgrade-byte-identical.tests.sh (epic-194-a6-lite-integration,
# T-002, design.md Test Strategy item 4, TEST-007/AC-007).
#
# Proves the extended script, invoked with NO second argument, is
# byte-identical (stdout + exit code) to the FROZEN pre-extension baseline,
# across the existing six-row keyword-scan fixture set reused as a
# regression baseline, plus a clean (no-match) fixture.
#
# BASELINE PINNING (2026-08-28, quality-gate cycle 2). Until the human apply
# (80694f62) this suite compared the live unextended script against the
# staged extended candidate. Once the apply published the candidate, both
# paths named the same blob (43513b8a) and every assertion became a
# comparison of a program with itself -- the seq-0912 evaluator recorded
# this as AC-007's only Major. Per the owner's remedy selection (option a),
# the pre-extension bytes are now pinned as a frozen fixture: blob 3bec203b
# (the live script at 80694f62^), sha256
# 192fc9887883e30e4ab8ff2f512ca7169ce7dea3149ab7cd60efb36312d8ba45,
# stored at tests/fixtures/epic-194-risk-upgrade-baseline/. The comparison
# below is live-vs-frozen-baseline, which discriminates again: any change
# to the legacy single-argument behaviour of the live script goes red.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
LIVE="${REPO_ROOT}/plugins/sdd-lite/scripts/check-risk-upgrade.sh"
BASELINE="${REPO_ROOT}/tests/fixtures/epic-194-risk-upgrade-baseline/check-risk-upgrade-baseline.sh"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# Fail closed with a visible FAIL (not an opaque set -e abort) if the frozen
# baseline fixture is missing; the tally and exit 1 still reach run-all.
if [ ! -f "$BASELINE" ]; then
  fail "TEST-007-baseline-present: frozen baseline fixture missing at ${BASELINE}"
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"
  exit 1
fi

# Runtime pin of the frozen baseline bytes (2026-08-28 hardening): a silently
# rewritten fixture would re-tautologize AC-007 without any test going red, so
# the pinned sha256 is asserted here, not only documented in the header.
BASELINE_EXPECTED_SHA="192fc9887883e30e4ab8ff2f512ca7169ce7dea3149ab7cd60efb36312d8ba45"
BASELINE_ACTUAL_SHA="$(shasum -a 256 "$BASELINE" | cut -d' ' -f1)"
if [ "$BASELINE_ACTUAL_SHA" = "$BASELINE_EXPECTED_SHA" ]; then
  ok "TEST-007-baseline-hash: frozen baseline sha256 matches the pinned value"
else
  fail "TEST-007-baseline-hash: frozen baseline sha256 drifted (expected ${BASELINE_EXPECTED_SHA}, got ${BASELINE_ACTUAL_SHA})"
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"
  exit 1
fi

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

# Strict byte comparison (2026-08-28 hardening): outputs are captured to
# files and compared with cmp, so trailing-newline differences that command
# substitution would normalize away are detected too.
assert_identical() {
  local label="$1" fixture="$2"
  local live_exit base_exit
  bash "$LIVE" "$fixture" > "${WORK}/live.out" 2>&1 && live_exit=0 || live_exit=$?
  bash "$BASELINE" "$fixture" > "${WORK}/base.out" 2>&1 && base_exit=0 || base_exit=$?
  if [ "$live_exit" -eq "$base_exit" ]; then
    ok "${label}: exit code identical (${live_exit})"
  else
    fail "${label}: exit code differs (live=${live_exit}, baseline=${base_exit})"
  fi
  if cmp -s "${WORK}/live.out" "${WORK}/base.out"; then
    ok "${label}: output byte-identical"
  else
    fail "${label}: output differs. live=[$(cat "${WORK}/live.out")] baseline=[$(cat "${WORK}/base.out")]"
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
