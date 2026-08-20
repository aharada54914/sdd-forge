#!/usr/bin/env bash
# facet-manifest-semantics.tests.sh — regression tests for
# validate-facet-manifest.py's REQ-006 diagnostic-id table (design.md Test
# Strategy item 2): schema-invalid, resolved-gate-id-duplicate,
# facet-classification-conflict, conditional-facet-duplicate,
# array-not-stable-sorted, plus one fully-clean fixture proving a negative.
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
expect_invalid "schema-invalid.json" "TEST-028" "facet-manifest: schema-invalid:"
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
# Hardened: assert the EXACT expected single line, not just a line count of
# 1 -- a line count alone cannot distinguish "one correct diagnostic" from
# "one line of empty-string noise" (wc -l on an empty string is 0, but a
# stray blank/malformed line would also satisfy a bare count-only check in
# some shells; pinning the full expected line closes that gap).
single_out="$(run_validator "$FIXTURES/resolved-gate-id-duplicate.json" 2>&1 || true)"
single_expected="facet-manifest: resolved-gate-id-duplicate: /resolved_gates/1/id: duplicate resolved_gates id 'task-review' (first seen at /resolved_gates/0/id)"
if [ -n "$single_out" ] && [ "$(printf '%s\n' "$single_out" | wc -l | tr -d ' ')" = "1" ] && [ "$single_out" = "$single_expected" ]; then
  ok "determinism: single-diagnostic fixture emits exactly one line, matching expected text exactly"
else
  fail "determinism: unexpected output for resolved-gate-id-duplicate.json: [$single_out]"
fi

# --- Diagnostic determinism contract: multi-diagnostic ordering (Minor) ----
# multi-diagnostic-ordering.json triggers 4 diagnostics across 3 distinct
# check-ids and 4 distinct pointers: array-not-stable-sorted (x2),
# facet-classification-conflict, resolved-gate-id-duplicate. Assert exact
# line count AND exact (check-id, pointer) ascending order via a
# byte-for-byte expected-output comparison.
multi_out="$(run_validator "$FIXTURES/multi-diagnostic-ordering.json" 2>&1 || true)"
multi_expected="$(cat <<'EXPECTED'
facet-manifest: array-not-stable-sorted: /affected_components: affected_components is not sorted lexicographically ascending
facet-manifest: array-not-stable-sorted: /capabilities: capabilities is not sorted lexicographically ascending
facet-manifest: facet-classification-conflict: /conditional_facets/0/facet: facet 'backend-patterns' present in both required_facets and conditional_facets
facet-manifest: resolved-gate-id-duplicate: /resolved_gates/1/id: duplicate resolved_gates id 'task-review' (first seen at /resolved_gates/0/id)
EXPECTED
)"
multi_line_count="$(printf '%s\n' "$multi_out" | wc -l | tr -d ' ')"
if [ "$multi_line_count" = "4" ] && [ "$multi_out" = "$multi_expected" ]; then
  ok "determinism: multi-diagnostic fixture emits 4 lines in exact (check-id, pointer) ascending order"
else
  fail "determinism: unexpected multi-diagnostic output (want 4 lines in the pinned order): [$multi_out]"
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
