#!/usr/bin/env bash
# check-risk-upgrade-capability-merge.tests.sh (epic-194-a6-lite-integration,
# T-002, design.md Test Strategy item 5, TEST-008/TEST-009, AC-008/AC-009).
#
# TEST-008: a clean (no-keyword-match) source + a valid capability-reasons
# fragment merges correctly; keyword-first ordering when both fire; an
# eligible:true entry contributes nothing; multiple eligible:false entries
# flatten in fragment array order.
# TEST-009 (static-review-by-grep, per design.md's own framing of this as a
# call-graph check): the extension adds no new keyword-table row and the
# staged script calls no Predicate-DSL/Registry-matching function of its
# own -- confirmed by grep, not behavioral execution.
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

run_sut() {
  SUT_OUTPUT=""
  SUT_EXIT=0
  SUT_OUTPUT="$(bash "$SUT" "$@" 2>&1)" || SUT_EXIT=$?
}

# ---------------------------------------------------------------------------
# TEST-008a: clean source + fragment with one non-empty-reasons ineligible
# entry, one empty-reasons ineligible entry, one eligible:true entry ->
# only the two ineligible entries contribute, eligible:true contributes
# nothing, fragment array order preserved.
# ---------------------------------------------------------------------------
echo "=== TEST-008a: clean source + mixed fragment merges correctly ==="
printf 'an entirely unremarkable sentence.\n' > "${WORK}/clean.txt"
cat > "${WORK}/fragment-mixed.json" <<'JSON'
{"capabilities": [
  {"id": "durable-workflow-svc", "eligible": false, "upgrade_reasons": ["durable_workflow"]},
  {"id": "internal-tool-only", "eligible": false, "upgrade_reasons": []},
  {"id": "fine-capability", "eligible": true, "upgrade_reasons": ["should-not-appear"]}
]}
JSON
run_sut "${WORK}/clean.txt" --capability-reasons "${WORK}/fragment-mixed.json"
if [ "${SUT_EXIT}" -eq 10 ]; then
  ok "TEST-008a: exits 10 (a Capability-derived trigger fired)"
else
  fail "TEST-008a: expected exit 10, got ${SUT_EXIT}. Output: ${SUT_OUTPUT}"
fi
if [ "${SUT_OUTPUT}" = "full-required: durable_workflow; triggers=durable_workflow,ineligible:internal-tool-only" ]; then
  ok "TEST-008a: output matches exact expected merge (array order, synthetic token, eligible:true excluded)"
else
  fail "TEST-008a: unexpected output: ${SUT_OUTPUT}"
fi

# ---------------------------------------------------------------------------
# TEST-008b: keyword-first ordering when BOTH keyword and capability
# triggers fire.
# ---------------------------------------------------------------------------
echo "=== TEST-008b: keyword-derived tokens precede capability-derived tokens ==="
printf 'we need an oauth token for this.\n' > "${WORK}/trig.txt"
run_sut "${WORK}/trig.txt" --capability-reasons "${WORK}/fragment-mixed.json"
if [ "${SUT_EXIT}" -eq 10 ]; then
  ok "TEST-008b: exits 10"
else
  fail "TEST-008b: expected exit 10, got ${SUT_EXIT}. Output: ${SUT_OUTPUT}"
fi
if [ "${SUT_OUTPUT}" = "full-required: AUTH_BOUNDARY; triggers=AUTH_BOUNDARY,TOKEN_CREDENTIAL,durable_workflow,ineligible:internal-tool-only" ]; then
  ok "TEST-008b: keyword tokens (AUTH_BOUNDARY,TOKEN_CREDENTIAL) precede capability tokens; primary id unchanged"
else
  fail "TEST-008b: unexpected output: ${SUT_OUTPUT}"
fi

# ---------------------------------------------------------------------------
# TEST-008c: every entry eligible:true -> no capability trigger at all;
# clean source stays lite-eligible.
# ---------------------------------------------------------------------------
echo "=== TEST-008c: all-eligible fragment contributes nothing ==="
cat > "${WORK}/fragment-all-eligible.json" <<'JSON'
{"capabilities": [
  {"id": "cap-a", "eligible": true},
  {"id": "cap-b", "eligible": true, "upgrade_reasons": []}
]}
JSON
run_sut "${WORK}/clean.txt" --capability-reasons "${WORK}/fragment-all-eligible.json"
if [ "${SUT_EXIT}" -eq 0 ] && [ "${SUT_OUTPUT}" = "lite-eligible" ]; then
  ok "TEST-008c: all-eligible fragment + clean source stays lite-eligible"
else
  fail "TEST-008c: expected exit 0 / lite-eligible, got exit ${SUT_EXIT}. Output: ${SUT_OUTPUT}"
fi

# ---------------------------------------------------------------------------
# TEST-009: static-review -- no new keyword-table row added, no
# Predicate-DSL/Registry-matching call introduced by the extension
# (AC-009). Confirmed by grep against the staged script content, not by
# execution.
# ---------------------------------------------------------------------------
echo "=== TEST-009: static review -- no new keyword row, no DSL/Registry call ==="
KEYWORD_ROW_COUNT="$(grep -c '^rules = (' "${SUT}" || true)"
if [ "${KEYWORD_ROW_COUNT}" -eq 1 ]; then
  ok "TEST-009a: exactly one rules-tuple definition (no duplicated/added keyword table)"
else
  fail "TEST-009a: expected exactly one 'rules = (' definition, found ${KEYWORD_ROW_COUNT}"
fi
RULE_ID_COUNT="$(grep -oE '\("(AUTH_BOUNDARY|TOKEN_CREDENTIAL|MCP|EXTERNAL_API|SECRET|GITHUB_ACTIONS)"' "${SUT}" | sort -u | wc -l | tr -d ' ')"
if [ "${RULE_ID_COUNT}" -eq 6 ]; then
  ok "TEST-009b: still exactly the original six keyword-rule IDs (no new row added)"
else
  fail "TEST-009b: expected exactly 6 distinct keyword-rule IDs, found ${RULE_ID_COUNT}"
fi
if grep -qiE 'evaluate-predicate|predicate-dsl|registry[_-]match' "${SUT}"; then
  fail "TEST-009c: staged script must not call Predicate-DSL/Registry-matching logic of its own"
else
  ok "TEST-009c: no Predicate-DSL/Registry-matching call found in the staged script"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
