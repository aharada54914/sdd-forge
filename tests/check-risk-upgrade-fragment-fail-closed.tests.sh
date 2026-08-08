#!/usr/bin/env bash
# check-risk-upgrade-fragment-fail-closed.tests.sh
# (epic-194-a6-lite-integration, T-002, design.md Test Strategy item 13,
# TEST-013, AC-027, Blocker [B3]).
#
# An unreadable/malformed/shape-invalid --capability-reasons fragment exits
# 2 with the dedicated "fragment invalid" diagnostic and no trigger
# reporting -- distinct from the omitted-argument case (exit 0/10) and from
# the primary-source-unavailable case (same exit 2 but a different
# message).
#
# NOTE (interim, pending human-copy staging unlock -- see tasks.md T-001
# Blockers): SUT is the .PROPOSED staging path; see
# check-risk-upgrade-byte-identical.tests.sh for the same note.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SUT="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/PROPOSED/check-risk-upgrade.sh.PROPOSED"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

printf 'clean source, no keyword match at all.\n' > "${WORK}/clean.txt"

assert_fragment_invalid() {
  local label="$1" fragment_path="$2"
  local out exit_code
  out="$(bash "$SUT" "${WORK}/clean.txt" --capability-reasons "$fragment_path" 2>&1)" && exit_code=0 || exit_code=$?
  if [ "${exit_code}" -eq 2 ]; then
    ok "${label}: exits 2"
  else
    fail "${label}: expected exit 2, got ${exit_code}. Output: ${out}"
  fi
  if [ "${out}" = "risk-upgrade: capability-reasons fragment invalid" ]; then
    ok "${label}: prints the dedicated fragment-invalid diagnostic (not the input-unavailable one)"
  else
    fail "${label}: unexpected output: ${out}"
  fi
}

echo "=== TEST-013a: unreadable (missing) fragment path ==="
assert_fragment_invalid "TEST-013a" "${WORK}/does-not-exist.json"

echo "=== TEST-013b: malformed (not valid JSON) fragment ==="
printf 'not valid json {{{ at all' > "${WORK}/malformed.json"
assert_fragment_invalid "TEST-013b" "${WORK}/malformed.json"

echo "=== TEST-013c: shape-invalid -- missing 'capabilities' key ==="
printf '{"not_capabilities": []}' > "${WORK}/no-capabilities-key.json"
assert_fragment_invalid "TEST-013c" "${WORK}/no-capabilities-key.json"

echo "=== TEST-013d: shape-invalid -- 'capabilities' is not an array ==="
printf '{"capabilities": "not-an-array"}' > "${WORK}/not-array.json"
assert_fragment_invalid "TEST-013d" "${WORK}/not-array.json"

echo "=== TEST-013e: shape-invalid -- entry missing 'id' ==="
printf '{"capabilities": [{"eligible": false}]}' > "${WORK}/missing-id.json"
assert_fragment_invalid "TEST-013e" "${WORK}/missing-id.json"

echo "=== TEST-013f: shape-invalid -- entry missing 'eligible' ==="
printf '{"capabilities": [{"id": "x"}]}' > "${WORK}/missing-eligible.json"
assert_fragment_invalid "TEST-013f" "${WORK}/missing-eligible.json"

echo "=== TEST-013g: distinct from the omitted-argument case ==="
OMIT_OUT="$(bash "$SUT" "${WORK}/clean.txt" 2>&1)"
OMIT_EXIT=0
bash "$SUT" "${WORK}/clean.txt" >/dev/null 2>&1 || OMIT_EXIT=$?
if [ "${OMIT_EXIT}" -eq 0 ] && [ "${OMIT_OUT}" = "lite-eligible" ]; then
  ok "TEST-013g: omitted-argument case is unaffected (exit 0, lite-eligible) -- fail-closed is scoped to SUPPLIED-invalid only"
else
  fail "TEST-013g: omitted-argument case regressed. exit=${OMIT_EXIT} output=${OMIT_OUT}"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
