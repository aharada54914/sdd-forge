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

# ---------------------------------------------------------------------------
# TEST-013h-n: cross-model panelist findings (T-002 remediation) --
# supplied-but-empty is SUPPLIED not omitted; a scalar upgrade_reasons;
# eligible:null/0/"false" are all shape-invalid, never a silent degrade or
# a fail-open/fail-closed runtime divergence; an id carrying a grammar
# delimiter cannot forge a second trigger entry.
# ---------------------------------------------------------------------------
echo "=== TEST-013h: supplied-but-empty --capability-reasons '' (SUPPLIED, not omitted) ==="
h_out="$(bash "$SUT" "${WORK}/clean.txt" --capability-reasons '' 2>&1)" && h_exit=0 || h_exit=$?
if [ "${h_exit}" -eq 2 ]; then
  ok "TEST-013h: exits 2 (empty value is SUPPLIED, matching bash's own argc-based detection)"
else
  fail "TEST-013h: expected exit 2, got ${h_exit}. Output: ${h_out}"
fi
if [ "${h_out}" = "risk-upgrade: capability-reasons fragment invalid" ]; then
  ok "TEST-013h: prints the dedicated fragment-invalid diagnostic, no silent degrade"
else
  fail "TEST-013h: unexpected output: ${h_out}"
fi

echo "=== TEST-013i: shape-invalid -- 'upgrade_reasons' is a scalar, not an array ==="
printf '{"capabilities": [{"id": "x", "eligible": false, "upgrade_reasons": "scalar-not-array"}]}' > "${WORK}/scalar-reasons.json"
assert_fragment_invalid "TEST-013i" "${WORK}/scalar-reasons.json"

echo "=== TEST-013j: shape-invalid -- 'eligible' is null (not a boolean) ==="
printf '{"capabilities": [{"id": "x", "eligible": null}]}' > "${WORK}/eligible-null.json"
assert_fragment_invalid "TEST-013j" "${WORK}/eligible-null.json"

echo "=== TEST-013k: shape-invalid -- 'eligible' is 0 (numeric, not boolean) ==="
printf '{"capabilities": [{"id": "x", "eligible": 0}]}' > "${WORK}/eligible-zero.json"
assert_fragment_invalid "TEST-013k" "${WORK}/eligible-zero.json"

echo "=== TEST-013l: shape-invalid -- 'eligible' is the string \"false\" (not boolean) ==="
printf '{"capabilities": [{"id": "x", "eligible": "false"}]}' > "${WORK}/eligible-string-false.json"
assert_fragment_invalid "TEST-013l" "${WORK}/eligible-string-false.json"

echo "=== TEST-013m: shape-invalid -- id carries a ',' delimiter (cannot forge a second trigger entry) ==="
printf '{"capabilities": [{"id": "evil,forged-trigger", "eligible": false}]}' > "${WORK}/id-comma.json"
assert_fragment_invalid "TEST-013m" "${WORK}/id-comma.json"

echo "=== TEST-013n: shape-invalid -- id carries a ';' delimiter (cannot forge a second trigger entry) ==="
printf '{"capabilities": [{"id": "evil;forged-trigger", "eligible": false}]}' > "${WORK}/id-semicolon.json"
assert_fragment_invalid "TEST-013n" "${WORK}/id-semicolon.json"

# ---------------------------------------------------------------------------
# TEST-013o-r: cross-model panelist re-run (T-002 remediation, Critical) --
# a bare object for "capabilities" (not wrapped in an array) must not be
# silently treated as a one-element array; an id carrying an embedded
# newline must not slip through the grammar via the trailing-newline `$`
# quirk; an explicitly empty id must not produce a degenerate "ineligible:"
# token; a bare 2-positional-argument invocation (no --capability-reasons
# flag) must not be treated as SUPPLIED.
# ---------------------------------------------------------------------------
echo "=== TEST-013o: shape-invalid -- 'capabilities' is a bare object, not an array ==="
printf '{"capabilities": {"id": "x", "eligible": false}}' > "${WORK}/capabilities-object.json"
assert_fragment_invalid "TEST-013o" "${WORK}/capabilities-object.json"

echo "=== TEST-013p: shape-invalid -- id carries an embedded newline (single-line contract) ==="
# NOTE: `\\n` (not `\n`) so printf writes the two literal characters
# backslash-n -- a valid JSON \n escape that decodes to an actual newline
# character inside the parsed "id" string. A raw unescaped newline BYTE
# embedded in the JSON text would instead be a JSON syntax error, catching
# a different (less specific) failure mode than the one under test here.
printf '{"capabilities": [{"id": "x\\ntriggers=NONE", "eligible": false}]}' > "${WORK}/id-newline.json"
assert_fragment_invalid "TEST-013p" "${WORK}/id-newline.json"

echo "=== TEST-013q: shape-invalid -- id is an explicit empty string (no degenerate 'ineligible:' token) ==="
printf '{"capabilities": [{"id": "", "eligible": false, "upgrade_reasons": []}]}' > "${WORK}/id-empty.json"
assert_fragment_invalid "TEST-013q" "${WORK}/id-empty.json"

echo "=== TEST-013r: a bare 2-positional-argument invocation (no --capability-reasons flag) is NOT treated as supplied ==="
printf '{"capabilities": [{"id": "would-be-merged", "eligible": false}]}' > "${WORK}/would-be-merged.json"
r_out="$(bash "$SUT" "${WORK}/clean.txt" "${WORK}/would-be-merged.json" 2>&1)" && r_exit=0 || r_exit=$?
if [ "${r_exit}" -eq 2 ] && [ "${r_out}" = "risk-upgrade: input unavailable" ]; then
  ok "TEST-013r: 2-positional-arg call hits the primary-source-unavailable arm (exit 2), never silently merges the second path as a capability fragment"
else
  fail "TEST-013r: expected exit 2 / 'risk-upgrade: input unavailable', got exit ${r_exit}. Output: ${r_out}"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
