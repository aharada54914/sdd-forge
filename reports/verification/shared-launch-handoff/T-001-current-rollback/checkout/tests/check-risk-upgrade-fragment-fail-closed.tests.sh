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
# SUT repointed 2026-08-28 (post-apply hardening): the shipped live script
# is the SUT; staged==live is held by human-copy-mirror-freshness.
SUT="${REPO_ROOT}/plugins/sdd-lite/scripts/check-risk-upgrade.sh"
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

# ---------------------------------------------------------------------------
# TEST-013s-u: cross-model panel, T-002 OpenAI slot -- "the supplied negative
# tests cover only missing keys and a non-array top-level capabilities value.
# They do not demonstrate fail-closed handling for empty/non-string ids,
# non-boolean eligible values, non-array upgrade_reasons, or non-string
# reason elements."
#
# Empty id (013q), non-boolean eligible (013j/k/l) and non-array
# upgrade_reasons (013i) were closed in an earlier round -- the panel reviewed
# a bundle that predates them. The one the slot names that genuinely had no
# assertion is a NON-STRING id; requirements.md Field Definitions fixes the
# field as `"id": <capability-id, non-empty string>`, so a JSON number,
# object or array in that position is shape-invalid, not a value to coerce.
# ---------------------------------------------------------------------------
echo "=== TEST-013s: shape-invalid -- id is a NUMBER, not a non-empty string ==="
printf '{"capabilities": [{"id": 7, "eligible": false, "upgrade_reasons": ["x"]}]}' > "${WORK}/id-number.json"
assert_fragment_invalid "TEST-013s" "${WORK}/id-number.json"

echo "=== TEST-013t: shape-invalid -- id is an object, not a non-empty string ==="
printf '{"capabilities": [{"id": {"nested": "x"}, "eligible": false}]}' > "${WORK}/id-object.json"
assert_fragment_invalid "TEST-013t" "${WORK}/id-object.json"

echo "=== TEST-013u: shape-invalid -- id is an array, not a non-empty string ==="
printf '{"capabilities": [{"id": ["x"], "eligible": false}]}' > "${WORK}/id-array.json"
assert_fragment_invalid "TEST-013u" "${WORK}/id-array.json"

# ---------------------------------------------------------------------------
# TEST-013v-af: upgrade_reasons ELEMENT validation (cross-model panel, T-002
# OpenAI slot: "non-string reason elements", plus the sibling sweep that
# finding prompted).
#
# The container was type-checked (TEST-013i) and its elements were not, then
# coerced with str()/[string]. Two consequences, both measured on both
# runtimes before the fix:
#
#  (a) Output-grammar forgery. Reason tokens are emitted into the identical
#      single-line "full-required: {first}; triggers={joined}" record as the
#      id field, whose grammar exists precisely to stop this -- TEST-013m/n/p
#      already prove a ',', ';' or newline in an *id* is rejected. One field
#      over, ["x; triggers=NONE"] produced
#      `full-required: x; triggers=NONE; triggers=x; triggers=NONE`,
#      and an embedded newline produced a multi-line record outright.
#  (b) A silent sh/ps1 divergence no test caught: null (sh "None" / ps1 ""),
#      object (sh "{'k': 'v'}" / ps1 "@{k=v}"), nested array (sh "['x']" /
#      ps1 flattened to "x"). The twins disagreed on three shapes.
#
# Every case below is asserted in BOTH twins with identical labels, so the
# divergence cannot silently return.
# ---------------------------------------------------------------------------
echo "=== TEST-013v: upgrade_reasons element is a number, not a string ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [5]}]}' > "${WORK}/reason-number.json"
assert_fragment_invalid "TEST-013v" "${WORK}/reason-number.json"

echo "=== TEST-013w: upgrade_reasons element is a boolean, not a string ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [true]}]}' > "${WORK}/reason-bool.json"
assert_fragment_invalid "TEST-013w" "${WORK}/reason-bool.json"

echo "=== TEST-013x: upgrade_reasons element is null (runtimes previously disagreed) ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [null]}]}' > "${WORK}/reason-null.json"
assert_fragment_invalid "TEST-013x" "${WORK}/reason-null.json"

echo "=== TEST-013y: upgrade_reasons element is an object (runtimes previously disagreed) ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [{"k": "v"}]}]}' > "${WORK}/reason-object.json"
assert_fragment_invalid "TEST-013y" "${WORK}/reason-object.json"

echo "=== TEST-013z: upgrade_reasons element is a nested array (ps1 flattened it, sh did not) ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [["x"]]}]}' > "${WORK}/reason-nested.json"
assert_fragment_invalid "TEST-013z" "${WORK}/reason-nested.json"

echo "=== TEST-013aa: upgrade_reasons element is the empty string (AC-001: non-empty strings) ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": [""]}]}' > "${WORK}/reason-empty.json"
assert_fragment_invalid "TEST-013aa" "${WORK}/reason-empty.json"

echo "=== TEST-013ab: upgrade_reasons element carries ',' (cannot forge a second trigger entry) ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["evil,forged"]}]}' > "${WORK}/reason-comma.json"
assert_fragment_invalid "TEST-013ab" "${WORK}/reason-comma.json"

echo "=== TEST-013ac: upgrade_reasons element carries ';' (cannot forge a second output field) ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["x; triggers=NONE"]}]}' > "${WORK}/reason-semicolon.json"
assert_fragment_invalid "TEST-013ac" "${WORK}/reason-semicolon.json"

echo "=== TEST-013ad: upgrade_reasons element carries an embedded newline (single-line contract) ==="
# `\\n` (not `\n`) so printf writes the two literal characters backslash-n --
# a valid JSON \n escape decoding to a real newline inside the parsed token.
# See TEST-013p's own note on why a raw newline BYTE would instead be a JSON
# syntax error, a different and less specific failure mode.
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["x\\ntriggers=NONE"]}]}' > "${WORK}/reason-newline.json"
assert_fragment_invalid "TEST-013ad" "${WORK}/reason-newline.json"

echo "=== TEST-013ae: upgrade_reasons element is uppercase (lowercase grammar, like the id grammar) ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["Financial_Settlement"]}]}' > "${WORK}/reason-upper.json"
assert_fragment_invalid "TEST-013ae" "${WORK}/reason-upper.json"

# Positive control. All ten negatives above would STILL PASS if the grammar
# were tightened to reject everything -- the suite would then happily certify
# a checker that never emits a Capability-derived trigger at all, which is the
# exact silent degrade AC-027 forbids. This asserts the legitimate vocabulary
# still gets through: snake_case (requirements.md AC-004's twelve catalog
# tokens are all [a-z0-9_]) AND hyphenated (AC-001's check-id grammar), both
# of which occur in this repository's own fixtures today. It also pins the
# tokens reaching the output VERBATIM, which is what proves the str()/[string]
# coercion is gone rather than merely bypassed.
echo "=== TEST-013af: a legitimate snake_case + hyphenated reason pair still Blocks with its own tokens ==="
printf '{"capabilities": [{"id": "a", "eligible": false, "upgrade_reasons": ["financial_settlement", "should-not-appear"]}]}' > "${WORK}/reason-valid.json"
af_out="$(bash "$SUT" "${WORK}/clean.txt" --capability-reasons "${WORK}/reason-valid.json" 2>&1)" && af_exit=0 || af_exit=$?
if [ "${af_exit}" -eq 10 ] && [ "${af_out}" = "full-required: financial_settlement; triggers=financial_settlement,should-not-appear" ]; then
  ok "TEST-013af: valid snake_case and hyphenated tokens pass the grammar and reach the output verbatim, uncoerced"
else
  fail "TEST-013af: expected exit 10 and the exact two-token record, got exit ${af_exit}. Output: ${af_out}"
fi

# TEST-013ag/ah pin amended design.md 2b (2026-08-28, RT-20260828-001):
# upgrade_reasons shape/grammar is validated for EVERY entry, before
# eligibility is consulted. Before the fix, an eligible:true entry carrying
# a malformed value was SILENTLY ACCEPTED (exit 0, lite-eligible) -- the
# conformance fail-open all three cross-model panelists flagged. The
# assertion here must be exit 2; asserting "no forged tokens appear in the
# record" would be vacuous, because an eligible:true entry emits nothing
# even while defective (RT-20260828-001, fixture note).
echo "=== TEST-013ag: eligible:true entry with a truthy non-array upgrade_reasons (amended 2b) ==="
printf '{"capabilities": [{"id": "a", "eligible": true, "upgrade_reasons": "risk"}]}' > "${WORK}/true-scalar.json"
assert_fragment_invalid "TEST-013ag" "${WORK}/true-scalar.json"

echo "=== TEST-013ah: eligible:true entry with a delimiter-carrying upgrade_reasons element (amended 2b) ==="
printf '{"capabilities": [{"id": "a", "eligible": true, "upgrade_reasons": ["evil,forged"]}]}' > "${WORK}/true-malformed-element.json"
assert_fragment_invalid "TEST-013ah" "${WORK}/true-malformed-element.json"

# TEST-013ai/aj pin the OTHER half of amended 2b: a present-but-falsy
# upgrade_reasons value (false/0/""/[]/null) is treated as absent on both
# runtimes -- ratified live behavior, not an accident.
echo "=== TEST-013ai: eligible:false with present-but-falsy upgrade_reasons is absent, yielding the synthetic token ==="
printf '{"capabilities": [{"id": "x", "eligible": false, "upgrade_reasons": false}]}' > "${WORK}/false-falsy.json"
ai_out="$(bash "$SUT" "${WORK}/clean.txt" --capability-reasons "${WORK}/false-falsy.json" 2>&1)" && ai_exit=0 || ai_exit=$?
if [ "${ai_exit}" -eq 10 ] && [ "${ai_out}" = "full-required: ineligible:x; triggers=ineligible:x" ]; then
  ok "TEST-013ai: present-but-falsy upgrade_reasons on eligible:false is treated as absent (synthetic token, exit 10)"
else
  fail "TEST-013ai: expected exit 10 with the synthetic ineligible:x record, got exit ${ai_exit}. Output: ${ai_out}"
fi

echo "=== TEST-013aj: eligible:true with present-but-falsy upgrade_reasons contributes nothing ==="
printf '{"capabilities": [{"id": "a", "eligible": true, "upgrade_reasons": 0}]}' > "${WORK}/true-falsy.json"
aj_out="$(bash "$SUT" "${WORK}/clean.txt" --capability-reasons "${WORK}/true-falsy.json" 2>&1)" && aj_exit=0 || aj_exit=$?
if [ "${aj_exit}" -eq 0 ] && [ "${aj_out}" = "lite-eligible" ]; then
  ok "TEST-013aj: present-but-falsy upgrade_reasons on eligible:true is treated as absent, contributing nothing (exit 0)"
else
  fail "TEST-013aj: expected exit 0 lite-eligible, got exit ${aj_exit}. Output: ${aj_out}"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
