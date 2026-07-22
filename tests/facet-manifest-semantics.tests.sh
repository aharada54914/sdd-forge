#!/usr/bin/env bash
# facet-manifest-semantics.tests.sh — regression tests for
# validate-facet-manifest.py's REQ-006 semantic checks (design.md Test
# Strategy item 2): resolved-gate-id-duplicate, facet-classification-conflict,
# conditional-facet-duplicate, array-not-stable-sorted, plus one fully-clean
# fixture proving a negative.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-facet-manifest.py"
FIXTURES="${REPO_ROOT}/tests/fixtures/facet-manifest/semantics"

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

# --- TEST-028: one fixture per diagnostic-id table row (AC-028) ------------
expect_invalid "resolved-gate-id-duplicate.json" "TEST-028" "facet-manifest: resolved-gate-id-duplicate:"
expect_invalid "facet-classification-conflict.json" "TEST-028" "facet-manifest: facet-classification-conflict:"
expect_invalid "conditional-facet-duplicate.json" "TEST-028" "facet-manifest: conditional-facet-duplicate:"
expect_invalid "affected-components-not-sorted.json" "TEST-028" "facet-manifest: array-not-stable-sorted:"

# --- plus one fully-clean fixture proving a negative (AC-028) --------------
expect_valid "fully-clean.json" "TEST-028 negative proof"

# --- AC-047: conditional_facets[] same-facet-value rejection ---------------
expect_invalid "conditional-facet-duplicate.json" "AC-047" "duplicate conditional_facets facet"

# --- array-not-stable-sorted: remaining scoped fields (design.md scope) ----
expect_invalid "required-facets-not-sorted.json" "array-not-stable-sorted" "facet-manifest: array-not-stable-sorted: /required_facets:"
expect_invalid "capabilities-not-sorted.json" "array-not-stable-sorted" "facet-manifest: array-not-stable-sorted: /capabilities:"
expect_invalid "upgrade-reasons-not-sorted.json" "array-not-stable-sorted / AC-048 semantic half" "facet-manifest: array-not-stable-sorted: /lite_eligibility/upgrade_reasons:"
expect_invalid "conditional-facets-not-sorted.json" "array-not-stable-sorted" "facet-manifest: array-not-stable-sorted: /conditional_facets:"
expect_invalid "resolved-gates-not-sorted.json" "array-not-stable-sorted" "facet-manifest: array-not-stable-sorted: /resolved_gates:"

# --- Diagnostic determinism contract: (check-id, JSON Pointer) ordering ----
multi_out="$(run_validator "$FIXTURES/resolved-gate-id-duplicate.json" 2>&1 || true)"
if [ "$(printf '%s\n' "$multi_out" | wc -l | tr -d ' ')" = "1" ]; then
  ok "determinism: single-diagnostic fixture emits exactly one line"
else
  fail "determinism: unexpected line count for resolved-gate-id-duplicate.json: [$multi_out]"
fi

# --- Suite/CI registration self-check ---------------------------------------
if grep -qF "tests/facet-manifest-semantics.tests.sh" "${REPO_ROOT}/tests/run-all.sh"; then
  ok "self-registration: tests/run-all.sh lists this suite"
else
  fail "self-registration: tests/run-all.sh does not list tests/facet-manifest-semantics.tests.sh"
fi

echo
echo "facet-manifest-semantics: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
