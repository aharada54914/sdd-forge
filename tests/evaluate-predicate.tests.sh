#!/usr/bin/env bash
# TDD suite for the Predicate DSL evaluator (T-002, REQ-002, ADR-0020).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
EVAL_SH="$ROOT/plugins/sdd-quality-loop/scripts/evaluate-predicate.sh"
FIXTURES="$ROOT/tests/fixtures/capability-registry"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok: %s\n' "$1" >&2; }

# --- Evidence JSON Schema conformance (design.md API/Contract Plan) -------
EVIDENCE_JQ_LIB='
def keys_within($allowed): (keys - $allowed) | length == 0;
def is_valid_evidence:
  type == "object" and
  keys_within(["operator","path","outcome","reason","children"]) and
  has("operator") and has("path") and has("outcome") and
  (.operator as $o | ["all","any","not","equals","not_equals","contains","in","exists"] | index($o) != null) and
  ((.path == null) or (.path | type == "string")) and
  (.outcome as $out | ["match","no-match","warn"] | index($out) != null) and
  (if .outcome == "warn" then (has("reason") and (.reason | type == "string")) else true end) and
  (if has("children") then (.children | type == "array" and all(.[]; is_valid_evidence)) else true end);
'

evidence_conforms() {
  # $1 = full CLI stdout JSON ({"result":bool,"evidence":[...]})
  printf '%s' "$1" | jq -e "$EVIDENCE_JQ_LIB"' (.evidence | type == "array" and all(.[]; is_valid_evidence))' >/dev/null 2>&1
}

# --- CLI invocation helper -------------------------------------------------
run_predicate() {
  # $1 = fixture basename (no .json). Sets OUT, RC, ERRTEXT.
  local fixture="$FIXTURES/$1.json"
  local pred="$TMP/pred.json"
  local props="$TMP/props.json"
  jq '.predicate' "$fixture" > "$pred"
  jq '.properties' "$fixture" > "$props"
  OUT="$(bash "$EVAL_SH" --predicate "$pred" --component-properties "$props" 2>"$TMP/stderr.log")"
  RC=$?
  ERRTEXT="$(cat "$TMP/stderr.log")"
}

assert_schema_error() {
  local name="$1"
  [[ "$RC" -ne 0 ]] || { fail "$name: expected non-zero exit for PREDICATE_SCHEMA_ERROR, got $RC"; return; }
  [[ "$ERRTEXT" == PREDICATE_SCHEMA_ERROR:* ]] || { fail "$name: expected stderr to start with PREDICATE_SCHEMA_ERROR:, got: $ERRTEXT"; return; }
  ok "$name"
}

assert_jq() {
  # $1 = case name, $2 = jq boolean expression against $OUT
  local name="$1" expr="$2"
  if [[ "$RC" -ne 0 ]]; then
    fail "$name: expected exit 0, got $RC (stderr: $ERRTEXT)"
    return
  fi
  if printf '%s' "$OUT" | jq -e "$expr" >/dev/null 2>&1; then
    ok "$name"
  else
    fail "$name: jq assertion failed: $expr -- actual: $OUT"
  fi
}

# =====================================================================
# TEST-007: fail-closed general rule x4 operators x3 cases (12 cases)
# =====================================================================
for case in equals not-equals contains in; do
  for cond in missing null; do
    fixture="predicate-fail-closed-${case}-${cond}"
    run_predicate "$fixture"
    assert_jq "TEST-007 $fixture: result=false" '.result == false'
    assert_jq "TEST-007 $fixture: evidence[0].outcome=warn" '.evidence[0].outcome == "warn"'
    assert_jq "TEST-007 $fixture: evidence[0].reason populated" '(.evidence[0].reason | type) == "string" and (.evidence[0].reason | length) > 0'
    evidence_conforms "$OUT" && ok "TEST-013 $fixture: evidence conforms" || fail "TEST-013 $fixture: evidence conforms"
  done
done
run_predicate "predicate-fail-closed-equals-type-mismatch"
assert_jq "TEST-007 equals-type-mismatch: warn/type-mismatch" '.result == false and .evidence[0].outcome == "warn" and .evidence[0].reason == "type-mismatch"'
run_predicate "predicate-fail-closed-not-equals-type-mismatch"
assert_jq "TEST-007 not-equals-type-mismatch: warn (never a true match on type mismatch)" '.result == false and .evidence[0].outcome == "warn" and .evidence[0].reason == "type-mismatch"'
run_predicate "predicate-fail-closed-contains-nonarray"
assert_jq "TEST-007 contains-nonarray: warn" '.result == false and .evidence[0].outcome == "warn"'
run_predicate "predicate-fail-closed-in-malformed-value"
assert_jq "TEST-007 in-malformed-value: warn/malformed-value-array" '.result == false and .evidence[0].outcome == "warn" and .evidence[0].reason == "malformed-value-array"'

# =====================================================================
# TEST-008: exists x3
# =====================================================================
run_predicate "predicate-exists-present-null"
assert_jq "TEST-008 exists present-with-null: match (true), no type inspection" '.result == true and .evidence[0].outcome == "match"'
run_predicate "predicate-exists-present-value"
assert_jq "TEST-008 exists present-with-value: match (true)" '.result == true and .evidence[0].outcome == "match"'
run_predicate "predicate-exists-absent"
assert_jq "TEST-008 exists absent: false + WARN" '.result == false and .evidence[0].outcome == "warn" and .evidence[0].reason == "missing-path"'

# =====================================================================
# TEST-009: all/any empty/true/false/mixed, no short-circuit
# =====================================================================
run_predicate "predicate-all-empty"
assert_jq "TEST-009 all-empty: true (vacuous)" '.result == true and .evidence[0].outcome == "match" and (.evidence[0].children | length) == 0'
run_predicate "predicate-all-true"
assert_jq "TEST-009 all-true: true, 2 children recorded" '.result == true and (.evidence[0].children | length) == 2 and (.evidence[0].children | all(.[]; .outcome == "match"))'
run_predicate "predicate-all-false"
assert_jq "TEST-009 all-false: false, both children recorded (no short-circuit)" '.result == false and (.evidence[0].children | length) == 2'
run_predicate "predicate-any-empty"
assert_jq "TEST-009 any-empty: false (vacuous)" '.result == false and .evidence[0].outcome == "no-match" and (.evidence[0].children | length) == 0'
run_predicate "predicate-any-mixed-no-shortcircuit"
assert_jq "TEST-009 any-mixed: true, all 3 children recorded despite match on child 2" '.result == true and (.evidence[0].children | length) == 3'
run_predicate "predicate-any-false"
assert_jq "TEST-009 any-false: false, both children recorded" '.result == false and (.evidence[0].children | length) == 2'

# =====================================================================
# TEST-010: trigger vs conditional_facets[].when share one evaluator
# =====================================================================
run_predicate "predicate-trigger-context"
TRIGGER_OUT="$OUT"
run_predicate "predicate-when-context"
WHEN_OUT="$OUT"
if [[ "$TRIGGER_OUT" == "$WHEN_OUT" ]]; then
  ok "TEST-010: trigger-context and when-context produce byte-identical evidence (single shared evaluator)"
else
  fail "TEST-010: trigger-context and when-context evidence diverged"
fi

# =====================================================================
# TEST-011: field-allowlist PREDICATE_SCHEMA_ERROR + drift-check fixture
# =====================================================================
run_predicate "predicate-bad-field"
assert_schema_error "TEST-011: field outside allowlist rejected as PREDICATE_SCHEMA_ERROR"

bash "$EVAL_SH" --check-field-allowlist "$FIXTURES/project-context-fixture-match.json" >/dev/null 2>"$TMP/drift-match.log"
if [[ $? -eq 0 ]]; then ok "TEST-011: drift-check passes against a matching Project Context fixture"; else fail "TEST-011: drift-check unexpectedly failed against a matching fixture: $(cat "$TMP/drift-match.log")"; fi

bash "$EVAL_SH" --check-field-allowlist "$FIXTURES/project-context-fixture-drift.json" >/dev/null 2>"$TMP/drift-mismatch.log"
if [[ $? -ne 0 ]]; then ok "TEST-011: drift-check fails against a diverging Project Context fixture"; else fail "TEST-011: drift-check wrongly passed against a diverging fixture"; fi

# =====================================================================
# TEST-012: not arity + truth table
# =====================================================================
run_predicate "predicate-not-zero-children"
assert_schema_error "TEST-012: not with zero children is PREDICATE_SCHEMA_ERROR"
run_predicate "predicate-not-two-children"
assert_schema_error "TEST-012: not with two children is PREDICATE_SCHEMA_ERROR"
run_predicate "predicate-not-child-true"
assert_jq "TEST-012: not(child=true) -> false" '.result == false and .evidence[0].outcome == "no-match" and (.evidence[0].children[0].outcome == "match")'
run_predicate "predicate-not-child-false"
assert_jq "TEST-012: not(child=false) -> true" '.result == true and .evidence[0].outcome == "match" and (.evidence[0].children[0].outcome == "no-match")'
run_predicate "predicate-not-child-warn"
assert_jq "TEST-012: not(child=warn) -> false (not naive negation), child WARN preserved" '.result == false and .evidence[0].outcome == "no-match" and (.evidence[0].children[0].outcome == "warn") and (.evidence[0].children[0].reason | length) > 0'

# =====================================================================
# TEST-013: Evidence-JSON-Schema conformance (all non-error fixtures) +
# nested depth-first stable ordering
# =====================================================================
ALL_OK_FIXTURES=(
  predicate-fail-closed-equals-missing predicate-fail-closed-equals-null predicate-fail-closed-equals-type-mismatch
  predicate-fail-closed-not-equals-missing predicate-fail-closed-not-equals-null predicate-fail-closed-not-equals-type-mismatch
  predicate-fail-closed-contains-missing predicate-fail-closed-contains-null predicate-fail-closed-contains-nonarray
  predicate-fail-closed-in-missing predicate-fail-closed-in-null predicate-fail-closed-in-malformed-value
  predicate-exists-present-null predicate-exists-present-value predicate-exists-absent
  predicate-all-empty predicate-all-true predicate-all-false predicate-any-empty predicate-any-mixed-no-shortcircuit predicate-any-false
  predicate-trigger-context predicate-when-context
  predicate-not-child-true predicate-not-child-false predicate-not-child-warn
  predicate-nested-depth-first
)
conform_failures=0
for f in "${ALL_OK_FIXTURES[@]}"; do
  run_predicate "$f"
  if [[ "$RC" -ne 0 ]]; then fail "TEST-013 $f: expected exit 0 for evidence-conformance sweep"; conform_failures=$((conform_failures + 1)); continue; fi
  if evidence_conforms "$OUT"; then :; else fail "TEST-013 $f: evidence does not conform to the Evidence JSON Schema"; conform_failures=$((conform_failures + 1)); fi
done
[[ "$conform_failures" -eq 0 ]] && ok "TEST-013: every non-error fixture's evidence conforms to the Evidence JSON Schema"

run_predicate "predicate-nested-depth-first"
FIRST_RUN="$OUT"
run_predicate "predicate-nested-depth-first"
SECOND_RUN="$OUT"
if [[ "$FIRST_RUN" == "$SECOND_RUN" ]]; then
  ok "TEST-013: nested all/any/not tree produces byte-identical, stably-ordered evidence across repeated runs"
else
  fail "TEST-013: nested tree evidence ordering is not stable across repeated runs"
fi
assert_jq "TEST-013: nested tree depth-first order (all[0]=any, all[1]=not)" \
  '.evidence[0].operator == "all" and (.evidence[0].children | length) == 2 and .evidence[0].children[0].operator == "any" and .evidence[0].children[1].operator == "not"'

# =====================================================================
# TEST-040: forbidden operator token, independent of TEST-011
# =====================================================================
run_predicate "predicate-bad-operator-regex"
assert_schema_error "TEST-040: 'regex' operator token rejected as PREDICATE_SCHEMA_ERROR"
run_predicate "predicate-bad-operator-jsonpath"
assert_schema_error "TEST-040: 'jsonpath' operator token rejected as PREDICATE_SCHEMA_ERROR"

# =====================================================================
# Suite/CI registration self-checks
# =====================================================================
if grep -q 'tests/evaluate-predicate.tests.sh' "$ROOT/tests/run-all.sh"; then
  ok "self-registration: evaluate-predicate.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: evaluate-predicate.tests.sh NOT registered in tests/run-all.sh"
fi
if grep -q 'tests/evaluate-predicate.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  ok "self-registration: evaluate-predicate.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: evaluate-predicate.tests.ps1 NOT registered in tests/run-all.ps1"
fi

HUMAN_COPY_DIR="$ROOT/specs/epic-190-a2-capability-registry/human-copy"
STAGED_WORKFLOW="$HUMAN_COPY_DIR/.github/workflows/test.yml"
STAGED_MANIFEST="$HUMAN_COPY_DIR/MANIFEST.sha256"
if [[ -f "$STAGED_WORKFLOW" ]] && grep -q 'tests/evaluate-predicate.tests.sh' "$STAGED_WORKFLOW" && grep -q 'tests/evaluate-predicate.tests.ps1' "$STAGED_WORKFLOW"; then
  ok "human-copy: staged workflow candidate registers this suite's CI steps"
else
  fail "human-copy: staged workflow candidate missing this suite's CI steps"
fi
if [[ -f "$STAGED_MANIFEST" ]]; then
  staged_hash="$(shasum -a 256 "$STAGED_WORKFLOW" | awk '{print $1}')"
  manifest_hash="$(grep -F 'workflows/test.yml' "$STAGED_MANIFEST" | awk '{print $1}')"
  if [[ -n "$manifest_hash" && "$staged_hash" == "$manifest_hash" ]]; then
    ok "human-copy: staged workflow candidate sha256 matches MANIFEST.sha256"
  else
    fail "human-copy: staged workflow candidate sha256 does not match MANIFEST.sha256"
  fi
else
  fail "human-copy: MANIFEST.sha256 missing"
fi

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  printf 'evaluate-predicate suite passed (%d checks)\n' "$PASS"
  exit 0
else
  printf 'evaluate-predicate suite FAILED (%d passed, %d failed)\n' "$PASS" "$FAIL"
  exit 1
fi
