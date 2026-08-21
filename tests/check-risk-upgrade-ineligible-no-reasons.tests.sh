#!/usr/bin/env bash
# check-risk-upgrade-ineligible-no-reasons.tests.sh
# (epic-194-a6-lite-integration, T-002, design.md Test Strategy item 14,
# TEST-014, AC-028, Blocker [B4]).
#
# An eligible:false entry with empty/absent upgrade_reasons must still
# produce a non-empty trigger (the synthetic "ineligible:<id>" token) and
# exit 10 -- it must never silently contribute nothing.
#
# NOTE: SUT is the canonical staged human-copy path; see
# check-risk-upgrade-byte-identical.tests.sh for the same note.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SUT="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.sh"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

printf 'a clean source with no keyword trigger.\n' > "${WORK}/clean.txt"

run_sut() {
  SUT_OUTPUT=""
  SUT_EXIT=0
  SUT_OUTPUT="$(bash "$SUT" "$@" 2>&1)" || SUT_EXIT=$?
}

# ---------------------------------------------------------------------------
# TEST-014a: upgrade_reasons key entirely ABSENT (not just empty array).
# ---------------------------------------------------------------------------
echo "=== TEST-014a: eligible:false, upgrade_reasons key absent ==="
printf '{"capabilities": [{"id": "no-reasons-key-cap", "eligible": false}]}' > "${WORK}/absent.json"
run_sut "${WORK}/clean.txt" --capability-reasons "${WORK}/absent.json"
if [ "${SUT_EXIT}" -eq 10 ]; then ok "TEST-014a: exits 10"; else fail "TEST-014a: expected exit 10, got ${SUT_EXIT}. Output: ${SUT_OUTPUT}"; fi
if [ "${SUT_OUTPUT}" = "full-required: ineligible:no-reasons-key-cap; triggers=ineligible:no-reasons-key-cap" ]; then
  ok "TEST-014a: synthetic ineligible:<id> token produced (never silently empty)"
else
  fail "TEST-014a: unexpected output: ${SUT_OUTPUT}"
fi

# ---------------------------------------------------------------------------
# TEST-014b: upgrade_reasons PRESENT but an empty array.
# ---------------------------------------------------------------------------
echo "=== TEST-014b: eligible:false, upgrade_reasons is an empty array ==="
printf '{"capabilities": [{"id": "empty-reasons-cap", "eligible": false, "upgrade_reasons": []}]}' > "${WORK}/empty-array.json"
run_sut "${WORK}/clean.txt" --capability-reasons "${WORK}/empty-array.json"
if [ "${SUT_EXIT}" -eq 10 ]; then ok "TEST-014b: exits 10"; else fail "TEST-014b: expected exit 10, got ${SUT_EXIT}. Output: ${SUT_OUTPUT}"; fi
if [ "${SUT_OUTPUT}" = "full-required: ineligible:empty-reasons-cap; triggers=ineligible:empty-reasons-cap" ]; then
  ok "TEST-014b: synthetic ineligible:<id> token produced for an explicit empty array too"
else
  fail "TEST-014b: unexpected output: ${SUT_OUTPUT}"
fi

# ---------------------------------------------------------------------------
# TEST-014c: mixed -- one no-reasons ineligible entry plus one
# non-empty-reasons ineligible entry; the no-reasons one still contributes
# its synthetic token, in array order.
# ---------------------------------------------------------------------------
echo "=== TEST-014c: mixed no-reasons + has-reasons entries, both contribute ==="
printf '{"capabilities": [{"id": "no-reasons-cap", "eligible": false}, {"id": "has-reasons-cap", "eligible": false, "upgrade_reasons": ["explicit_reason"]}]}' > "${WORK}/mixed.json"
run_sut "${WORK}/clean.txt" --capability-reasons "${WORK}/mixed.json"
if [ "${SUT_EXIT}" -eq 10 ]; then ok "TEST-014c: exits 10"; else fail "TEST-014c: expected exit 10, got ${SUT_EXIT}. Output: ${SUT_OUTPUT}"; fi
if [ "${SUT_OUTPUT}" = "full-required: ineligible:no-reasons-cap; triggers=ineligible:no-reasons-cap,explicit_reason" ]; then
  ok "TEST-014c: no-reasons entry's synthetic token appears in its own array position, not dropped"
else
  fail "TEST-014c: unexpected output: ${SUT_OUTPUT}"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
