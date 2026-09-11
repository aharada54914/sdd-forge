#!/usr/bin/env bash
# lite-gate-summary-absent-active-enforcement.tests.sh
# (epic-194-a6-lite-integration, T-004, design.md Test Strategy item 15,
# TEST-030, AC-030, Blocker [B6]).
#
# Active capability_enforcement with NO Summary at all is VERDICT: FAIL,
# distinct from the disabled-legacy case (lite-gate-summary-absent.tests.sh);
# paired with a present-but-empty-Summary pass-through fixture.
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
# TEST-030a: active enforcement (advisory or required), Summary absent ->
# VERDICT: FAIL, distinct from disabled-legacy.
# ---------------------------------------------------------------------------
echo "=== TEST-030a: active capability_enforcement, no Summary at all -> VERDICT: FAIL ==="
simulate_lite_gate_step2 "${WORK}/does-not-exist.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ]; then ok "TEST-030a: required enforcement + absent Summary is VERDICT: FAIL"; else fail "TEST-030a: expected FAIL, got ${SIM_VERDICT}"; fi
if [ "${SIM_REASON}" = "capability-summary.yaml missing under active capability_enforcement" ]; then
  ok "TEST-030a: reason names active capability_enforcement specifically"
else
  fail "TEST-030a: unexpected reason: ${SIM_REASON}"
fi

echo "=== TEST-030b: advisory enforcement, no Summary at all -> also VERDICT: FAIL ==="
simulate_lite_gate_step2 "${WORK}/still-does-not-exist.json" "advisory" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ]; then ok "TEST-030b: advisory enforcement + absent Summary is also VERDICT: FAIL"; else fail "TEST-030b: expected FAIL, got ${SIM_VERDICT}"; fi

echo "=== TEST-030c: disabled-legacy (distinct case) is NOT a failure ==="
simulate_lite_gate_step2 "" "none" "${WORK}"
if [ "${SIM_VERDICT}" = "PASS" ]; then
  ok "TEST-030c: disabled-legacy (no Project Context at all) is legitimate, VERDICT: PASS -- distinct from TEST-030a/b"
else
  fail "TEST-030c: disabled-legacy should be PASS, got ${SIM_VERDICT} (${SIM_REASON})"
fi

# ---------------------------------------------------------------------------
# TEST-030d (companion): present-but-empty-Summary is a pass-through, not a
# failure -- active enforcement only fails on a MISSING Summary, not an
# empty required_lite_checks list within a present one.
# ---------------------------------------------------------------------------
echo "=== TEST-030d: present-but-empty Summary is a pass-through ==="
cat > "${WORK}/present-empty.json" <<'EOF'
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":[],"required_lite_checks":[],"full_upgrade_required":false}
EOF
simulate_lite_gate_step2 "${WORK}/present-empty.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "PASS" ]; then
  ok "TEST-030d: present-but-empty Summary passes through, VERDICT: PASS"
else
  fail "TEST-030d: expected PASS for a present-but-empty Summary, got ${SIM_VERDICT} (${SIM_REASON})"
fi

# ---------------------------------------------------------------------------
# TEST-030e (deliverable-drift lock, quality-gate NEEDS_WORK cycle 1 Major
# finding 5): lite-gate/SKILL.md's own missing-Summary-under-active-
# enforcement clause must still read VERDICT: FAIL, not a silent PASS
# (Blocker [B6]). TEST-030a/b above already prove the simulator's reference
# algorithm behaves correctly; this locks the shipped prose text itself,
# since the simulator is a separate implementation that would not notice a
# SKILL.md-only mutation.
# ---------------------------------------------------------------------------
echo "=== TEST-030e: SKILL.md text -- missing-Summary-under-active-enforcement stays VERDICT: FAIL ==="
if grep -Eq 'VERDICT: FAIL.*capability-summary\.yaml missing under active capability_enforcement' "${SKILL}"; then
  ok "TEST-030e: SKILL.md's own missing-Summary branch still reads VERDICT: FAIL"
else
  fail "TEST-030e: SKILL.md's missing-Summary branch no longer reads VERDICT: FAIL (Blocker [B6] regression)"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
