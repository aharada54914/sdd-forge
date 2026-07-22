#!/usr/bin/env bash
# facet-manifest-schema.tests.sh — regression tests for
# contracts/facet-manifest.schema.json + validate-facet-manifest.py's schema
# conformance layer (REQ-001, design.md Test Strategy item 1).
#
# Mirrors apply-branch-protection.tests.sh's ok/fail counter style. Fixtures
# are pre-canonical JSON under tests/fixtures/facet-manifest/schema/ so this
# suite exercises validate_document() directly (via the CLI's --manifest
# <path>.json branch) without needing Epic A1's canonicalizer, which this
# worktree does not contain (tasks.md External Checkout Constraints).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-facet-manifest.py"
SCHEMA="${REPO_ROOT}/contracts/facet-manifest.schema.json"
FIXTURES="${REPO_ROOT}/tests/fixtures/facet-manifest/schema"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

run_validator() {
  python3 "$VALIDATOR" --manifest "$1"
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

# --- TEST-001: $id / draft-07 existence -------------------------------------
schema_id="$(python3 -c "import json;print(json.load(open('$SCHEMA')).get('\$id',''))")"
schema_dollar_schema="$(python3 -c "import json;print(json.load(open('$SCHEMA')).get('\$schema',''))")"
if [ "$schema_dollar_schema" = "http://json-schema.org/draft-07/schema#" ]; then
  ok "TEST-001: \$schema is draft-07"
else
  fail "TEST-001: \$schema expected draft-07, got '$schema_dollar_schema'"
fi
if [ -n "$schema_id" ]; then
  ok "TEST-001: \$id present ($schema_id)"
else
  fail "TEST-001: \$id missing"
fi

# --- TEST-002: required-field matrix (AC-002) -------------------------------
expect_valid "valid-base.json" "TEST-002 positive baseline"
for field in schema feature affected-components required-facets \
  conditional-facets resolved-gates capabilities lite-eligibility \
  context-binding resolver; do
  expect_invalid "required-missing-${field}.json" "TEST-002" "missing required property"
done

# --- TEST-003: uniqueItems + empty-array acceptance (AC-003) ----------------
expect_valid "empty-arrays-valid.json" "TEST-003"
expect_invalid "duplicate-affected-components.json" "TEST-003" "uniqueItems violated"
expect_invalid "duplicate-required-facets.json" "TEST-003" "uniqueItems violated"
expect_invalid "duplicate-capabilities.json" "TEST-003" "uniqueItems violated"

# --- TEST-004: applied/reason if/then/else (AC-004) -------------------------
expect_invalid "conditional-facet-applied-false-missing-reason.json" "TEST-004" "missing required property 'reason'"
expect_invalid "conditional-facet-applied-true-with-reason.json" "TEST-004" "matched a schema under 'not'"
expect_valid "conditional-facet-applied-true-valid.json" "TEST-004"

# --- TEST-005: Evidence-array-shape + out-of-enum operator (AC-005) --------
expect_invalid "evidence-invalid-operator.json" "TEST-005" "expected one of"
expect_invalid "evidence-warn-missing-reason.json" "TEST-005" "missing required property 'reason'"
expect_valid "evidence-warn-with-reason-valid.json" "TEST-005"

# --- TEST-006: resolved_gates[] shape + stage enum (AC-006) -----------------
expect_invalid "resolved-gate-invalid-stage.json" "TEST-006" "expected one of"
expect_valid "resolved-gate-valid-multi.json" "TEST-006"

# --- TEST-007: capability_minimum_enforcement const/absent + aggregate -----
expect_invalid "capability-minimum-enforcement-invalid-value.json" "TEST-007" "expected const 'required'"
expect_valid "capability-minimum-enforcement-absent-valid.json" "TEST-007"
expect_valid "capability-minimum-enforcement-aggregate-valid.json" "TEST-007"

# --- TEST-008: lite_eligibility required, upgrade_reasons absent rejected --
expect_invalid "lite-eligibility-missing-upgrade-reasons.json" "TEST-008" "missing required property 'upgrade_reasons'"
expect_valid "lite-eligibility-empty-upgrade-reasons-valid.json" "TEST-008"

# --- TEST-009: digest pattern + minItems ------------------------------------
expect_invalid "context-binding-malformed-digest.json" "TEST-009" "does not match pattern"
expect_invalid "context-binding-empty-dependency-pointers.json" "TEST-009" "< minItems 1"

# --- TEST-010: semver pattern ------------------------------------------------
expect_invalid "resolver-malformed-semver.json" "TEST-010" "does not match pattern"
expect_valid "resolver-valid-semver.json" "TEST-010"

# --- TEST-011: decision document v2 section 16 worked example --------------
expect_valid "decision-doc-v2-section16-worked-example.json" "TEST-011"

# --- TEST-017/018: combined syntax+root dependency_pointers pattern --------
expect_invalid "dependency-pointer-root-not-allowlisted.json" "TEST-017" "does not match pattern"
expect_invalid "dependency-pointer-malformed-rfc6901.json" "TEST-018" "does not match pattern"
expect_valid "dependency-pointer-all-roots-valid.json" "TEST-017/018"

# --- TEST-041: evidenceNode outcome "warn" requires reason ------------------
# (covered above by evidence-warn-missing-reason.json / evidence-warn-with-reason-valid.json)
ok "TEST-041: covered by evidence-warn-{missing-reason,with-reason-valid} above"

# --- TEST-048 (schema half): upgrade_reasons uniqueItems --------------------
expect_invalid "upgrade-reasons-duplicate.json" "TEST-048" "uniqueItems violated"

# --- TEST-034: REQ-007 placement regression (AC-034) ------------------------
STRUCT_CHECK="${REPO_ROOT}/scripts/check-sdd-structure.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FEATURE="facet-manifest-placement-fixture"
mkdir -p "$WORK/specs/$FEATURE" "$WORK/reports/implementation" "$WORK/reports/quality-gate" "$WORK/docs/adr" "$WORK/docs/review-tickets"
: > "$WORK/AGENTS.md"
for name in requirements.md design.md ux-spec.md frontend-spec.md \
  infra-spec.md security-spec.md acceptance-tests.md tasks.md traceability.md; do
  : > "$WORK/specs/$FEATURE/$name"
done
cp "$FIXTURES/valid-base.json" "$WORK/specs/$FEATURE/facet-manifest.yaml"
echo "schema: sdd-capability-summary/v1" > "$WORK/specs/$FEATURE/capability-summary.yaml"

set +e
struct_out="$(sh "$STRUCT_CHECK" "$WORK" "$FEATURE" 2>&1)"
struct_rc=$?
set -e
if [ "$struct_rc" -eq 0 ] && printf '%s' "$struct_out" | grep -qF "check-sdd-structure: OK"; then
  ok "TEST-034: facet-manifest.yaml/capability-summary.yaml alongside specs/<feature>/ files does not break check-sdd-structure.sh"
else
  fail "TEST-034: check-sdd-structure.sh regressed with facet-manifest.yaml present: rc=$struct_rc out=[$struct_out]"
fi

# --- Suite/CI registration self-check ---------------------------------------
if grep -qF "tests/facet-manifest-schema.tests.sh" "${REPO_ROOT}/tests/run-all.sh"; then
  ok "self-registration: tests/run-all.sh lists this suite"
else
  fail "self-registration: tests/run-all.sh does not list tests/facet-manifest-schema.tests.sh"
fi

echo
echo "facet-manifest-schema: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
