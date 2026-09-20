#!/usr/bin/env bash
# lite-gate-full-upgrade-backstop.tests.sh (epic-194-a6-lite-integration,
# T-004, design.md Test Strategy item 12, TEST-026, AC-026, Blocker [B2]).
#
# Step 2a Blocks on full_upgrade_required: true BEFORE Step 2b (command
# discovery) ever runs; continues on false.
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
# TEST-026a: full_upgrade_required: true Blocks even when required_lite_
# checks names an id that would otherwise be unmapped -- Step 2b must never
# run at all once Step 2a Blocks.
# ---------------------------------------------------------------------------
echo "=== TEST-026a: full_upgrade_required: true Blocks before Step 2b runs ==="
cat > "${WORK}/full-upgrade.json" <<'EOF'
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":["totally-unmapped-check"],"full_upgrade_required":true}
EOF
simulate_lite_gate_step2 "${WORK}/full-upgrade.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ]; then ok "TEST-026a: VERDICT: FAIL"; else fail "TEST-026a: expected FAIL, got ${SIM_VERDICT}"; fi
if [ "${SIM_REASON}" = "full_upgrade_required: true" ]; then
  ok "TEST-026a: reason names full_upgrade_required specifically (not the unmapped check-id -- proves Step 2b never ran)"
else
  fail "TEST-026a: expected the full_upgrade_required reason (Step 2b must not have run), got: ${SIM_REASON}"
fi
if [ -z "${SIM_RAN_CHECKS}" ]; then
  ok "TEST-026a: no check-discovery was attempted (Step 2b never reached)"
else
  fail "TEST-026a: Step 2b should never have run, but discovery was attempted: ${SIM_RAN_CHECKS}"
fi

# ---------------------------------------------------------------------------
# TEST-026b: full_upgrade_required: false continues to Step 2b normally.
# ---------------------------------------------------------------------------
echo "=== TEST-026b: full_upgrade_required: false continues normally ==="
cat > "${WORK}/no-full-upgrade.json" <<'EOF'
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":["build"],"full_upgrade_required":false}
EOF
simulate_lite_gate_step2 "${WORK}/no-full-upgrade.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "PASS" ]; then ok "TEST-026b: full_upgrade_required: false continues, VERDICT: PASS"; else fail "TEST-026b: expected PASS, got ${SIM_VERDICT} (${SIM_REASON})"; fi

# ---------------------------------------------------------------------------
# TEST-026c (deliverable-drift lock, quality-gate NEEDS_WORK cycle 1 Major
# finding 5): lite-gate/SKILL.md's own Step 2a backstop clause must still
# read VERDICT: FAIL on full_upgrade_required == true, not a silent
# pass-through ("続行"). TEST-026a above already proves the simulator's
# reference algorithm behaves correctly; this locks the shipped prose text
# itself, since the simulator is a separate implementation that would not
# notice a SKILL.md-only mutation.
# ---------------------------------------------------------------------------
echo "=== TEST-026c: SKILL.md text -- full_upgrade_required: true backstop stays VERDICT: FAIL ==="
if grep -Eq 'full_upgrade_required == true.*VERDICT: FAIL' "${SKILL}"; then
  ok "TEST-026c: SKILL.md's own Step 2a backstop clause still reads VERDICT: FAIL on full_upgrade_required == true"
else
  fail "TEST-026c: SKILL.md's Step 2a backstop clause no longer FAILs on full_upgrade_required == true (Blocker [B2] regression)"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
