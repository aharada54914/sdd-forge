#!/usr/bin/env bash
# capability-summary-schema.tests.sh — regression tests for
# contracts/capability-summary.schema.json + validate-capability-summary.py's
# schema conformance layer (REQ-002/REQ-006, design.md Test Strategy item 3).
#
# Mirrors facet-manifest-schema.tests.sh's ok/fail counter style. Most
# fixtures are pre-canonical JSON under
# tests/fixtures/facet-manifest/capability-summary/ so this suite exercises
# validate_document() directly (via the CLI's --summary <path>.json branch)
# without needing Epic A1's canonicalizer (tasks.md External Checkout
# Constraints). One fixture, canonicalizer-roundtrip-valid.yaml (part of
# TEST-029's own scope: this validator's YAML parse contract), is real YAML
# and is deliberately routed through the --summary <path>.yaml branch to
# exercise the actual canonicalize-sdd-yaml subprocess end-to-end, since
# Epic A1's canonicalizer is present in this checkout (re-verified at this
# task's implementation-start time, tasks.md External Checkout Constraints).
#
# design.md's `validate-capability-summary` contract fixes "No semantic
# check beyond schema conformance is needed for this script" -- unlike
# facet-manifest-semantics.tests.sh, there is no sibling semantics suite for
# this artifact; every REQ-002 invariant is schema-expressible.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-capability-summary.py"
SCHEMA="${REPO_ROOT}/contracts/capability-summary.schema.json"
FIXTURES="${REPO_ROOT}/tests/fixtures/facet-manifest/capability-summary"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

run_validator() {
  python3 "$VALIDATOR" --summary "$1"
}

expect_valid() {
  local fixture="$1" name="$2"
  local out rc
  set +e
  out="$(run_validator "$FIXTURES/$fixture" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    ok "$name: $fixture valid (exit 0, no diagnostics)"
  else
    fail "$name: $fixture expected valid, got exit=$rc output=[$out]"
  fi
}

expect_invalid() {
  local fixture="$1" name="$2" needle="$3"
  local out rc
  set +e
  out="$(run_validator "$FIXTURES/$fixture" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF -- "$needle"; then
    ok "$name: $fixture invalid as expected (contains '$needle')"
  else
    fail "$name: $fixture expected invalid containing '$needle', got exit=$rc output=[$out]"
  fi
}

# --- schema existence -------------------------------------------------------
if [ -f "$SCHEMA" ]; then
  ok "contracts/capability-summary.schema.json exists"
else
  fail "contracts/capability-summary.schema.json is missing"
fi
schema_dollar_schema="$(python3 -c "import json;print(json.load(open('$SCHEMA')).get('\$schema',''))")"
if [ "$schema_dollar_schema" = "http://json-schema.org/draft-07/schema#" ]; then
  ok "\$schema is draft-07"
else
  fail "\$schema expected draft-07, got '$schema_dollar_schema'"
fi
schema_id="$(python3 -c "import json;print(json.load(open('$SCHEMA')).get('\$id',''))")"
expected_schema_id="https://github.com/aharada54914/sdd-forge/contracts/capability-summary.schema.json"
if [ "$schema_id" = "$expected_schema_id" ]; then
  ok "\$id exact match ($schema_id)"
else
  fail "\$id expected '$expected_schema_id', got '$schema_id'"
fi

# --- TEST-012: Lite-only required-field set (AC-012) ------------------------
required_json="$(python3 -c "import json;print(json.dumps(json.load(open('$SCHEMA')).get('required',[])))")"
expected_required='["schema", "feature", "track", "capabilities", "required_lite_checks", "full_upgrade_required"]'
expected_required_json="$(python3 -c "import json;print(json.dumps(json.loads('$expected_required')))")"
if [ "$required_json" = "$expected_required_json" ]; then
  ok "TEST-012: top-level 'required' is exactly the six-field Lite-only set"
else
  fail "TEST-012: top-level 'required' expected $expected_required_json, got $required_json"
fi
track_const="$(python3 -c "import json;print(json.load(open('$SCHEMA'))['properties']['track'].get('const',''))")"
if [ "$track_const" = "lite" ]; then
  ok "TEST-012: 'track' is const 'lite' -- no full-track branch in this schema"
else
  fail "TEST-012: 'track' expected const 'lite', got '$track_const'"
fi

# Field-specific needles (not the generic "missing required property"
# substring): each fixture below is verified (ad hoc, at suite-authoring
# time) to omit exactly ONE top-level required field, matching
# facet-manifest-schema.tests.sh's own Field Requirement Matrix convention.
declare -a req_field_json=(schema feature track capabilities required_lite_checks full_upgrade_required)
declare -a req_field_slug=(schema feature track capabilities required-lite-checks full-upgrade-required)
for i in "${!req_field_json[@]}"; do
  field_json="${req_field_json[$i]}"
  field_slug="${req_field_slug[$i]}"
  expect_invalid "required-missing-${field_slug}.json" "TEST-012" "missing required property '${field_json}'"
done

# --- TEST-013: decision document v2 section 6's own Lite worked example,
# extended with schema/feature/track (AC-013) --------------------------------
expect_valid "decision-doc-v2-section6-worked-example.json" "TEST-013"

# TEST-013 / TEST-029 YAML round-trip: REQ-006 YAML parse contract,
# exercised through the REAL canonicalize-sdd-yaml subprocess (not a
# pre-canonical JSON fixture, unlike every other fixture in this suite).
expect_valid "canonicalizer-roundtrip-valid.yaml" "TEST-013 YAML round-trip (real canonicalizer subprocess)"

# --- TEST-014: additionalProperties: false rejects an extra field (AC-014) --
expect_invalid "extra-property-facet-manifest-ref-invalid.json" "TEST-014" "/facet_manifest_ref: additional property not allowed"

# --- Regression lock: 'track' const rejects any non-'lite' value, including
# the retired full-track discriminator value itself ("M full Summary") ------
expect_invalid "track-invalid-value.json" "TEST-012 regression" "/track: expected const 'lite', got 'full'"

# --- Regression lock: 'feature' pattern is enforced. design.md's own
# keyword-audit paragraph (API / Contract Plan, "keywords each committed
# schema instance actually uses") omits 'pattern' from
# capability-summary.schema.json's list, but the schema's own committed
# JSON block (same section) declares feature.pattern -- this fixture proves
# the shipped hand-rolled engine actually enforces it rather than silently
# treating it as unconstrained (the same failure class an earlier revision
# of the 'items' keyword coverage list already caused elsewhere in this
# feature, per design.md's own adversarial-review history). See this task's
# Specification Differences note. -------------------------------------------
expect_invalid "feature-invalid-pattern.json" "feature pattern regression" "/feature: does not match pattern"

# --- ECMA pattern semantics: trailing-newline feature value rejected -------
# Draft-07 pattern follows ECMA-262 semantics: a non-multiline $ asserts
# end-of-string only. Python's bare $ also matches immediately before a
# trailing "\n", so a value like "epic-192-a4-facet-manifest\n" must not be
# silently accepted. Regression lock for this validator's own
# _ecma_anchor/_compile_pattern pair (copied from validate-facet-manifest.py
# per this task's Goal, "Include the ECMA-262 $->\Z pattern fix from the
# start").
expect_invalid "feature-trailing-newline.json" "ECMA pattern semantics: trailing-newline feature rejected" "/feature: does not match pattern"

# --- Diagnostic determinism: multi-diagnostic ordering (check-id, pointer) -
# Two simultaneous violations (feature pattern + track const) must appear as
# two exact lines, ordered ascending by JSON Pointer (both share the same
# check-id, 'schema-invalid').
expected_line1="capability-summary: schema-invalid: /feature: does not match pattern '^[a-z0-9][a-z0-9-]*\$'"
expected_line2="capability-summary: schema-invalid: /track: expected const 'lite', got 'full'"
set +e
multi_out="$(run_validator "$FIXTURES/multi-diagnostic-ordering.json" 2>&1)"
multi_rc=$?
set -e
expected_multi="$(printf '%s\n%s' "$expected_line1" "$expected_line2")"
if [ "$multi_rc" -ne 0 ] && [ "$multi_out" = "$expected_multi" ]; then
  ok "diagnostic determinism: multi-diagnostic-ordering.json emits exactly 2 lines in (check-id, pointer) order"
else
  fail "diagnostic determinism: expected exit!=0 and exact 2-line output [$expected_multi], got exit=$multi_rc output=[$multi_out]"
fi

# --- TEST-029: validate-capability-summary.py exit-0/non-zero contract
# (AC-029) --------------------------------------------------------------
set +e
exit0_out="$(run_validator "$FIXTURES/decision-doc-v2-section6-worked-example.json" 2>&1)"
exit0_rc=$?
set -e
if [ "$exit0_rc" -eq 0 ] && [ -z "$exit0_out" ]; then
  ok "TEST-029: validate-capability-summary.py exits 0 on AC-013's own worked-example fixture"
else
  fail "TEST-029: expected exit 0 with no output on the worked example, got exit=$exit0_rc output=[$exit0_out]"
fi
set +e
nonzero_out="$(run_validator "$FIXTURES/extra-property-facet-manifest-ref-invalid.json" 2>&1)"
nonzero_rc=$?
set -e
if [ "$nonzero_rc" -ne 0 ] && printf '%s' "$nonzero_out" | grep -qF "capability-summary: schema-invalid:"; then
  ok "TEST-029: validate-capability-summary.py exits non-zero with 'capability-summary: schema-invalid:' on AC-014's fixture"
else
  fail "TEST-029: expected exit!=0 with 'capability-summary: schema-invalid:', got exit=$nonzero_rc output=[$nonzero_out]"
fi

# --- canonicalizer-invocation-failed regression lock -------------------------
# Deterministic: a nonexistent .yaml path must surface the validator's own
# canonicalizer-invocation-failed diagnostic (fail-closed YAML parse
# contract), not a Python traceback or a silent pass. No fixture file
# needed -- the path is intentionally absent.
missing_yaml="$FIXTURES/does-not-exist.yaml"
set +e
canon_out="$(run_validator "$missing_yaml" 2>&1)"
canon_rc=$?
set -e
if [ "$canon_rc" -ne 0 ] && printf '%s' "$canon_out" | grep -qF "capability-summary: canonicalizer-invocation-failed:"; then
  ok "canonicalizer-invocation-failed: nonexistent .yaml path fails closed (exit=$canon_rc, contains diagnostic)"
else
  fail "canonicalizer-invocation-failed: expected exit!=0 and diagnostic, got exit=$canon_rc output=[$canon_out]"
fi

# --- Suite/CI registration self-check ---------------------------------------
if grep -qF "tests/capability-summary-schema.tests.sh" "${REPO_ROOT}/tests/run-all.sh"; then
  ok "self-registration: tests/run-all.sh lists this suite"
else
  fail "self-registration: tests/run-all.sh does not list tests/capability-summary-schema.tests.sh"
fi

echo
echo "capability-summary-schema: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
