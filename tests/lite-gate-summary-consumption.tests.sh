#!/usr/bin/env bash
# lite-gate-summary-consumption.tests.sh (epic-194-a6-lite-integration,
# T-004, design.md Test Strategy item 7, TEST-015/016, AC-015/AC-016,
# Blocker [B7], NEW-01).
#
# A well-formed capability-summary.yaml naming required_lite_checks:
# no-ops on a baseline-name duplicate; runs/records a resolvable
# Registry-sourced check via command-discovery (npm scripts and
# scripts/<id>.{sh,ps1} pair); VERDICT: FAIL (never N/A) if unresolvable.
# Paired grammar/symlink/single-runtime-member negative fixtures for the
# command-discovery contract's own safety rules (NEW-01).
#
# lite-gate/SKILL.md is agent-facing prose, so this suite exercises
# tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.sh, a
# reference simulator of the documented Step 2a/2b algorithm -- see that
# file's own header for the full rationale.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=fixtures/epic-194-lite-gate/simulate-lite-gate-step2.sh
source "${REPO_ROOT}/tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.sh"
SKILL="${REPO_ROOT}/plugins/sdd-lite/skills/lite-gate/SKILL.md"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "${WORK}/scripts"

write_summary() {
  # write_summary <path> <required_lite_checks-json-array> <full_upgrade_required>
  cat > "$1" <<EOF
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":${2},"full_upgrade_required":${3}}
EOF
}

# ---------------------------------------------------------------------------
# TEST-015a: baseline-name duplicate is a no-op (does not attempt discovery).
# ---------------------------------------------------------------------------
echo "=== TEST-015a: baseline-name duplicate is a no-op ==="
write_summary "${WORK}/baseline-only.json" '["build","test"]' false
simulate_lite_gate_step2 "${WORK}/baseline-only.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "PASS" ]; then ok "TEST-015a: baseline-only required_lite_checks is a no-op, VERDICT: PASS"; else fail "TEST-015a: expected PASS, got ${SIM_VERDICT} (${SIM_REASON})"; fi
if [ -z "${SIM_RAN_CHECKS}" ]; then ok "TEST-015a: no command-discovery attempted for baseline names"; else fail "TEST-015a: unexpected discovery ran: ${SIM_RAN_CHECKS}"; fi

# ---------------------------------------------------------------------------
# TEST-015b: resolvable via npm (package.json scripts[<id>]).
# ---------------------------------------------------------------------------
echo "=== TEST-015b: Registry-sourced check resolved via npm scripts ==="
cat > "${WORK}/package.json" <<'EOF'
{"scripts": {"custom-lint": "echo custom-lint"}}
EOF
write_summary "${WORK}/via-npm.json" '["build","custom-lint"]' false
simulate_lite_gate_step2 "${WORK}/via-npm.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "PASS" ]; then ok "TEST-015b: npm-resolvable check runs, VERDICT: PASS"; else fail "TEST-015b: expected PASS, got ${SIM_VERDICT} (${SIM_REASON})"; fi
if [[ "${SIM_RAN_CHECKS}" == *"npm:custom-lint"* ]]; then ok "TEST-015b: recorded as run via npm"; else fail "TEST-015b: expected npm:custom-lint in ran checks, got [${SIM_RAN_CHECKS}]"; fi

# ---------------------------------------------------------------------------
# TEST-015c: resolvable via scripts/<id>.{sh,ps1} pair.
# ---------------------------------------------------------------------------
echo "=== TEST-015c: Registry-sourced check resolved via scripts/<id> pair ==="
printf '#!/bin/sh\necho ok\n' > "${WORK}/scripts/installer-dry-run.sh"
printf 'Write-Host ok\n' > "${WORK}/scripts/installer-dry-run.ps1"
write_summary "${WORK}/via-scripts.json" '["installer-dry-run"]' false
simulate_lite_gate_step2 "${WORK}/via-scripts.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "PASS" ]; then ok "TEST-015c: scripts-pair-resolvable check runs, VERDICT: PASS"; else fail "TEST-015c: expected PASS, got ${SIM_VERDICT} (${SIM_REASON})"; fi
if [[ "${SIM_RAN_CHECKS}" == *"scripts:installer-dry-run"* ]]; then ok "TEST-015c: recorded as run via scripts pair"; else fail "TEST-015c: expected scripts:installer-dry-run in ran checks, got [${SIM_RAN_CHECKS}]"; fi

# ---------------------------------------------------------------------------
# TEST-016a (Blocker B7, reversed): an unmapped id is VERDICT: FAIL, never N/A.
# ---------------------------------------------------------------------------
echo "=== TEST-016a: unmapped Registry-sourced id is VERDICT: FAIL, never N/A ==="
write_summary "${WORK}/unmapped.json" '["totally-unmapped-check"]' false
simulate_lite_gate_step2 "${WORK}/unmapped.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ]; then ok "TEST-016a: unmapped id is VERDICT: FAIL"; else fail "TEST-016a: expected FAIL, got ${SIM_VERDICT}"; fi
if [[ "${SIM_REASON}" == *"no discoverable command"* ]]; then ok "TEST-016a: reason names the missing discoverable command (never N/A)"; else fail "TEST-016a: unexpected reason: ${SIM_REASON}"; fi

# ---------------------------------------------------------------------------
# TEST-016b (NEW-01): a grammar-failing id is blocked before discovery.
# ---------------------------------------------------------------------------
echo "=== TEST-016b: grammar-failing check-id blocked before discovery (NEW-01) ==="
write_summary "${WORK}/bad-grammar.json" '["Bad_ID"]' false
simulate_lite_gate_step2 "${WORK}/bad-grammar.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ] && [[ "${SIM_REASON}" == *"does not match the required"*"grammar"* ]]; then
  ok "TEST-016b: grammar-failing id rejected before discovery is attempted"
else
  fail "TEST-016b: expected grammar-rejection FAIL, got ${SIM_VERDICT} (${SIM_REASON})"
fi

# ---------------------------------------------------------------------------
# TEST-016c (NEW-01): a symlink-escaping scripts/<id> candidate is rejected,
# never executed, treated as unmapped.
# ---------------------------------------------------------------------------
echo "=== TEST-016c: symlink-escaping scripts/<id> candidate rejected (NEW-01) ==="
printf 'outside content\n' > "${WORK}/outside.sh"
printf 'outside content\n' > "${WORK}/outside.ps1"
ln -sf "${WORK}/outside.sh" "${WORK}/scripts/evil-check.sh"
ln -sf "${WORK}/outside.ps1" "${WORK}/scripts/evil-check.ps1"
write_summary "${WORK}/symlink.json" '["evil-check"]' false
simulate_lite_gate_step2 "${WORK}/symlink.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ] && [[ "${SIM_REASON}" == *"no discoverable command"* ]]; then
  ok "TEST-016c: symlinked scripts/<id> pair treated as unmapped, never executed"
else
  fail "TEST-016c: expected unmapped FAIL for symlinked pair, got ${SIM_VERDICT} (${SIM_REASON})"
fi

# ---------------------------------------------------------------------------
# TEST-016d (NEW-01): a single-runtime-member pair (only .sh, no .ps1) is
# unmapped -- "pair" means both members.
# ---------------------------------------------------------------------------
echo "=== TEST-016d: single-runtime-member pair is unmapped (NEW-01) ==="
printf '#!/bin/sh\necho ok\n' > "${WORK}/scripts/onlysh-check.sh"
write_summary "${WORK}/single-runtime.json" '["onlysh-check"]' false
simulate_lite_gate_step2 "${WORK}/single-runtime.json" "required" "${WORK}"
if [ "${SIM_VERDICT}" = "FAIL" ] && [[ "${SIM_REASON}" == *"no discoverable command"* ]]; then
  ok "TEST-016d: a check-id with only one runtime member present is treated as unmapped"
else
  fail "TEST-016d: expected unmapped FAIL for single-runtime-member pair, got ${SIM_VERDICT} (${SIM_REASON})"
fi

# ---------------------------------------------------------------------------
# Companion: Step 2's own pre-existing, non-Registry-sourced convention
# (missing local lint/typecheck/build/test command reported as N/A) is
# unchanged by this extension -- confirmed by static review that the
# extended SKILL.md text still names N/A only for Step 2's own convention.
# ---------------------------------------------------------------------------
echo "=== TEST-016e: N/A stays reserved for Step 2's own pre-existing convention ==="
if grep -q 'N/A.*は Step 2 既存の' "${SKILL}" || grep -q 'Step 2 既存の.*N/A' "${SKILL}"; then
  ok "TEST-016e: SKILL.md text still reserves N/A for Step 2's own convention only"
else
  fail "TEST-016e: expected SKILL.md to state N/A stays reserved for Step 2's own convention"
fi

# ---------------------------------------------------------------------------
# TEST-018 (AC-018, static-review): Step 2b introduces no evidence-bundle
# generator, cross-model-verification call, second-approval check, or
# risk-hierarchy classification of its own (ADR-0022 item 4's own
# "never grows into a second quality-gate" boundary).
# ---------------------------------------------------------------------------
echo "=== TEST-018: static review -- no evidence-bundle/cross-model/second-approval/risk-hierarchy machinery introduced ==="
# Scoped to the NEW Step 2a/2b + command-discovery-contract text only (not
# the whole file, which legitimately still carries its OWN pre-existing
# Boundaries disclaimer naming evidence-bundle/cross-model-verify as things
# lite-gate does NOT do -- that disclaimer is unchanged by this task and is
# not itself new machinery).
NEW_STEP_TEXT="$(sed -n '/^2a\. \*\*`full_upgrade_required`/,/^3\. `reports\/quality-gate/p' "${SKILL}")"
if printf '%s' "${NEW_STEP_TEXT}" | grep -Eqi 'generate-evidence-bundle|cross-model-verify\.[a-z]|second[- ]approval check|risk[_-]hierarchy classification|risk-classification-policy'; then
  fail "TEST-018: the NEW Step 2a/2b text must not introduce evidence-bundle/cross-model/second-approval/risk-hierarchy machinery"
elif printf '%s' "${NEW_STEP_TEXT}" | grep -q '一切追加しない'; then
  ok "TEST-018: the new Step 2a/2b text explicitly disclaims adding evidence-bundle/cross-model/second-approval machinery, and introduces none"
else
  fail "TEST-018: expected the new Step 2a/2b text to explicitly disclaim this machinery"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
