#!/usr/bin/env bash
# lite-spec-capability-block.tests.sh (epic-194-a6-lite-integration, T-003,
# design.md Test Strategy item 6, TEST-019, AC-019/AC-020/AC-021).
#
# lite-spec's SKILL.md is agent-facing prose, not executable code, so this
# suite tests it two ways:
#  (a) structural/static: the proposed SKILL.md text names every element
#      design.md's own API/Contract Plan "REQ-005" requires (candidate (a)
#      signal source, the trigger-fragment shape, the --capability-reasons
#      call-site addition, the disabled-legacy skip clause, the
#      non-overridable-by---lite statement, and the "layered with, not a
#      substitute for" ship-time recheck statement).
#  (b) functional/integration: a fixture whose Capability-derived signal
#      names one matched, ineligible Capability -- assembled into REQ-002's
#      own trigger-fragment shape exactly as the new Step 2 documents, NOT
#      via a real Epic A2 evaluate-predicate call (which does not exist yet
#      in this repository, requirements.md Assumptions: every fixture is
#      synthetic) -- Blocks via T-002's own extended check-risk-upgrade
#      contract, same exit-code/message-shape as an existing keyword-match
#      fixture (AC-019).
#
# NOTE: the SKILL.md text under test is the canonical staged human-copy
# content, and the check-risk-upgrade SUT is T-002's own canonical staged
# extended script (already covered by its own suite).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SKILL_PROPOSED="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md"
CHECK_RISK_UPGRADE="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.sh"
LIVE_SHIP_SKILL="${REPO_ROOT}/plugins/sdd-ship/skills/ship/SKILL.md"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# (a) Structural checks on the proposed SKILL.md content.
# ---------------------------------------------------------------------------
echo "=== TEST-019-static: proposed SKILL.md names every required element ==="

assert_contains() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" "$SKILL_PROPOSED"; then
    ok "${label}"
  else
    fail "${label}: expected to find [${needle}] in proposed SKILL.md"
  fi
}

assert_contains "TEST-019-static-a: names evaluate-predicate as the signal source" "evaluate-predicate"
assert_contains "TEST-019-static-b: names the Project-Context-declared component match" "Project Context already declares"
assert_contains "TEST-019-static-c: names the trigger-fragment eligible/upgrade_reasons shape" '"eligible": false'
assert_contains "TEST-019-static-d: the checker call site gains the new second argument" "--capability-reasons <fragment-path>"
assert_contains "TEST-019-static-e: the .ps1 call site gains its own new parameter" "-CapabilityReasons <fragment-path>"
assert_contains "TEST-019-static-f: disabled-legacy (no Project Context) skip clause present" "skip this step entirely"
assert_contains "TEST-019-static-g: non-overridable by --lite, regardless of signal source" "regardless of whether the"
assert_contains "TEST-019-static-h: the dedicated fragment-invalid exit-2 diagnostic is documented" "capability-reasons fragment invalid"
assert_contains "TEST-019-static-i: ship-time recheck stays layered, not replaced" "layered with, not a substitute for"
assert_contains "TEST-019-static-j: Boundaries still disclaim reimplementing Predicate-DSL/Registry-matching" "Predicate-DSL/Registry-matching"

# ---------------------------------------------------------------------------
# (a2) "Attempted and failed" producer-side rule (panelist Critical finding,
# cross-model verdict T-003.panelist-anthropic.verdict.json): a Project
# Context that exists but whose Capability evaluation cannot be completed
# must Block, not silently fall through to the one-argument, keyword-only
# call -- the only legitimate degrade is the second argument's own total
# absence (disabled-legacy). Each failure mode this rule names, plus the
# required outcome, gets its own assertion.
# ---------------------------------------------------------------------------
assert_contains "TEST-019-static-k: names evaluate-predicate absence/non-zero exit as a producer failure mode" "absent or exits non-zero"
assert_contains "TEST-019-static-l: names an unreadable/unparseable Registry as a producer failure mode" "Registry is unreadable or fails to parse"
assert_contains "TEST-019-static-m: names a temp-fragment write failure as a producer failure mode" "writing the temp fragment fails"
assert_contains "TEST-019-static-n: the required outcome is an immediate Block, before the checker ever runs" "Block immediately, before"
assert_contains "TEST-019-static-o: an attempted-and-failed signal is never treated as one never attempted" "never a silent degrade"

# ---------------------------------------------------------------------------
# (b) Functional: assemble a synthetic trigger fragment the way the new
# Step 2 documents (a matched, ineligible Capability, from a synthetic
# Registry + Project Context -- NOT a real evaluate-predicate call, which
# does not exist in this repository yet), then confirm check-risk-upgrade
# Blocks on it, same shape as an existing keyword-match fixture.
# ---------------------------------------------------------------------------
echo "=== TEST-019-functional: assembled Capability-derived fragment Blocks ==="

# Synthetic Project Context: one declared component.
cat > "${WORK}/project-context.json" <<'JSON'
{"components": ["payment-service"]}
JSON

# Synthetic Registry: one Capability matched to that component, ineligible.
cat > "${WORK}/registry.json" <<'JSON'
{"capabilities": [
  {"id": "payment-processing-svc", "component": "payment-service",
   "lite_policy": {"eligible": false, "upgrade_reasons": ["financial_settlement"]}}
]}
JSON

# Union-match simulation (standing in for a real evaluate-predicate call,
# which this feature does not reimplement, Non-goals): a component-name
# equality match, assembled into REQ-002's own trigger-fragment shape.
python3 - "${WORK}/project-context.json" "${WORK}/registry.json" "${WORK}/fragment.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    project_context = json.load(f)
with open(sys.argv[2], encoding="utf-8") as f:
    registry = json.load(f)

declared = set(project_context["components"])
matched_ineligible = []
for capability in registry["capabilities"]:
    if capability["component"] in declared and capability["lite_policy"]["eligible"] is False:
        matched_ineligible.append({
            "id": capability["id"],
            "eligible": False,
            "upgrade_reasons": capability["lite_policy"].get("upgrade_reasons", []),
        })

with open(sys.argv[3], "w", encoding="utf-8") as f:
    json.dump({"capabilities": matched_ineligible}, f)
PY

printf 'a clean internal requirement body with no keyword trigger at all.\n' > "${WORK}/source.txt"

OUT=""
EXIT=0
OUT="$(bash "$CHECK_RISK_UPGRADE" "${WORK}/source.txt" --capability-reasons "${WORK}/fragment.json" 2>&1)" || EXIT=$?

if [ "${EXIT}" -eq 10 ]; then
  ok "TEST-019-functional-a: Blocks (exit 10), same exit code as an existing keyword-match fixture"
else
  fail "TEST-019-functional-a: expected exit 10, got ${EXIT}. Output: ${OUT}"
fi
if [[ "${OUT}" == full-required:* ]]; then
  ok "TEST-019-functional-b: message shape is 'full-required: ...', same shape as a keyword-match Block"
else
  fail "TEST-019-functional-b: unexpected message shape: ${OUT}"
fi
if [[ "${OUT}" == *"financial_settlement"* ]]; then
  ok "TEST-019-functional-c: the matched Capability's own upgrade_reasons token is present in the Block message"
else
  fail "TEST-019-functional-c: expected 'financial_settlement' in output: ${OUT}"
fi

# ---------------------------------------------------------------------------
# Companion fixture (defense-in-depth, design.md Test Strategy item 6,
# panelist Major finding): the OLD version of this companion only grepped
# ship/SKILL.md for the string "check-risk-upgrade" -- true whether or not
# T-003 ever existed, so it discriminated nothing. This version *executes*
# both independent gate positions for a component the intake-time
# Capability-derived evaluation did NOT flag, and separately proves the
# fixture is actually coupled to the proposed SKILL.md text (not a
# tautology) by requiring its own precondition to hold.
# ---------------------------------------------------------------------------
echo "=== TEST-019-defense-in-depth: ship-time recheck independently Blocks a component intake's Capability-derived evaluation did not flag ==="

if grep -qF -- '--capability-reasons <fragment-path>' "${SKILL_PROPOSED}"; then
  ok "TEST-019-defense-in-depth-a: proposed SKILL.md documents the intake-time --capability-reasons contract this fixture drives"
else
  fail "TEST-019-defense-in-depth-a: proposed SKILL.md no longer documents --capability-reasons; the property below cannot be exercised"
fi

# Component "payment-service": its matched Capability is eligible:true, so
# per the documented assembly rule ("Assemble every matched Capability whose
# own lite_policy.eligible is false") it is excluded from the fragment
# entirely -- the intake-time Capability-derived evaluation does not flag it.
cat > "${WORK}/di-fragment.json" <<'JSON'
{"capabilities": [
  {"id": "payment-processing-svc", "eligible": true, "upgrade_reasons": []}
]}
JSON
printf 'a clean internal requirement body with no keyword trigger at all.\n' > "${WORK}/di-intake-source.txt"

DI_INTAKE_OUT=""
DI_INTAKE_EXIT=0
DI_INTAKE_OUT="$(bash "$CHECK_RISK_UPGRADE" "${WORK}/di-intake-source.txt" --capability-reasons "${WORK}/di-fragment.json" 2>&1)" || DI_INTAKE_EXIT=$?
if [ "${DI_INTAKE_EXIT}" -eq 0 ]; then
  ok "TEST-019-defense-in-depth-b: intake-time evaluation does not flag the eligible:true component (exit 0, lite-eligible)"
else
  fail "TEST-019-defense-in-depth-b: expected intake to pass with exit 0, got ${DI_INTAKE_EXIT}. Output: ${DI_INTAKE_OUT}"
fi

# Ship-time recheck: independent invocation, single argument only -- exactly
# ship/SKILL.md's own unmodified command (still just check-risk-upgrade with
# no --capability-reasons at all, per its own live text) -- against a
# task-block+requirements body that DOES carry an unrelated keyword trigger
# for the same component.
printf 'the payment-service task rotates a secret used by the settlement worker.\n' > "${WORK}/di-ship-source.txt"
DI_SHIP_OUT=""
DI_SHIP_EXIT=0
DI_SHIP_OUT="$(bash "$CHECK_RISK_UPGRADE" "${WORK}/di-ship-source.txt" 2>&1)" || DI_SHIP_EXIT=$?
if [ "${DI_SHIP_EXIT}" -eq 10 ]; then
  ok "TEST-019-defense-in-depth-c: ship-time recheck independently Blocks (exit 10) even though intake's Capability-derived evaluation did not flag this component"
else
  fail "TEST-019-defense-in-depth-c: expected ship-time recheck to Block with exit 10, got ${DI_SHIP_EXIT}. Output: ${DI_SHIP_OUT}"
fi

if [ -f "${LIVE_SHIP_SKILL}" ]; then
  if grep -q "check-risk-upgrade" "${LIVE_SHIP_SKILL}"; then
    ok "TEST-019-defense-in-depth-d: ship/SKILL.md still independently invokes check-risk-upgrade at ship time"
  else
    fail "TEST-019-defense-in-depth-d: ship/SKILL.md no longer mentions check-risk-upgrade -- the independent second stage may have been lost"
  fi
else
  fail "TEST-019-defense-in-depth-d: ship/SKILL.md not found at expected path"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
