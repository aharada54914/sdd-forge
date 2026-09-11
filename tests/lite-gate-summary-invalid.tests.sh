#!/usr/bin/env bash
# lite-gate-summary-invalid.tests.sh (epic-194-a6-lite-integration, T-004,
# design.md Test Strategy item 9, TEST-012/TEST-013, AC-012/AC-013).
#
# A schema-invalid capability-summary.yaml is VERDICT: FAIL via a call to
# A4/A5's own validator (never a reimplementation, static-review checked);
# no per-Capability re-aggregation logic of lite-gate's own exists
# (AC-013).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
source "${REPO_ROOT}/tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.sh"
SKILL="${REPO_ROOT}/plugins/sdd-lite/skills/lite-gate/SKILL.md"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# TEST-012: schema-invalid Summary -> VERDICT: FAIL.
# ---------------------------------------------------------------------------
echo "=== TEST-012a: wrong schema constant is VERDICT: FAIL ==="
cat > "${WORK}/wrong-schema.json" <<'EOF'
{"schema":"not-the-right-schema","feature":"demo","track":"lite","capabilities":[],"required_lite_checks":[],"full_upgrade_required":false}
EOF
simulate_lite_gate_step2 "${WORK}/wrong-schema.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ]; then ok "TEST-012a: wrong schema constant is VERDICT: FAIL"; else fail "TEST-012a: expected FAIL, got ${SIM_VERDICT}"; fi

echo "=== TEST-012b: missing a required key is VERDICT: FAIL ==="
cat > "${WORK}/missing-key.json" <<'EOF'
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":[]}
EOF
simulate_lite_gate_step2 "${WORK}/missing-key.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ]; then ok "TEST-012b: missing required_lite_checks/full_upgrade_required is VERDICT: FAIL"; else fail "TEST-012b: expected FAIL, got ${SIM_VERDICT}"; fi

echo "=== TEST-012c: wrong-type field (full_upgrade_required not boolean) is VERDICT: FAIL ==="
cat > "${WORK}/wrong-type.json" <<'EOF'
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":[],"required_lite_checks":[],"full_upgrade_required":"true"}
EOF
simulate_lite_gate_step2 "${WORK}/wrong-type.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ]; then ok "TEST-012c: non-boolean full_upgrade_required is VERDICT: FAIL"; else fail "TEST-012c: expected FAIL, got ${SIM_VERDICT}"; fi

# ---------------------------------------------------------------------------
# TEST-013: static-review -- no per-Capability re-aggregation logic exists.
# The extended SKILL.md must read the single already-aggregated field, not
# recompute it from individual Capabilities.
# ---------------------------------------------------------------------------
echo "=== TEST-013: static review -- no per-Capability re-aggregation logic ==="
if grep -q '横断で再集約しない' "${SKILL}"; then
  ok "TEST-013a: Boundaries explicitly disclaims re-aggregating across Capabilities"
else
  fail "TEST-013a: expected Boundaries to disclaim cross-Capability re-aggregation"
fi
if grep -q 'A5 の Resolver が既に書いた' "${SKILL}"; then
  ok "TEST-013b: text confirms the field is read as already-aggregated, not recomputed"
else
  fail "TEST-013b: expected text confirming the already-aggregated-field read"
fi
# lite-gate never CALLS evaluate-predicate or Registry-matching (unlike
# lite-spec/T-003, which does) -- it only disclaims implementing that logic
# itself. Check for an active call/invocation instruction, not the mere
# presence of the term (which the disclaiming Boundaries bullet itself
# necessarily contains, e.g. "Predicate-DSL ... 実装しない").
if grep -Eqi '(実行する|呼び出す|呼ぶ)[^。]*(evaluate-predicate|registry[_-]match)' "${SKILL}"; then
  fail "TEST-013c: lite-gate/SKILL.md must not itself invoke Predicate-DSL/Registry-matching logic"
else
  ok "TEST-013c: no Predicate-DSL/Registry-matching invocation found in lite-gate/SKILL.md (disclaimed, not called)"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
