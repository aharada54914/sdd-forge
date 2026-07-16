#!/usr/bin/env bash
# loop-inventory.tests.sh — registration-forcing suite for the loop-inventory/v1
# registry (T-001 / Issue #141 / epic-159-pillar-a REQ-001).
#
# Derives loop surfaces from the repository and cross-checks
# tests/loops/loop-inventory.json in both directions:
#   TEST-001 — schema validation, driver-script registration (every
#     plugins/**/scripts/*-review-precheck.sh appears in some entry's
#     driver_scripts), every validate-review-context-set.sh stage:role pair
#     maps to an entry, every cross_gates path exists on disk, and a
#     negative self-check (one entry removed from a mktemp copy) turns red.
#   TEST-002 — bidirectional numeric cap-drift lock for every
#     cap_source:script + cap_kind:numeric entry (cap value greps to its
#     driver source's limit); terminal-tier (the sole cap_kind:state entry)
#     is excluded; a negative self-check (mutated cap in a temp copy) turns
#     red.
#   TEST-003 — cap_source:skill-instruction entries produce no false red
#     (cap_kind absent, exempt from the numeric grep); wfi-audit and
#     hitl-diagnosis specifically carry driver_scripts: []; every
#     fixture_profiles value is drawn from the closed greenfield/brownfield
#     vocabulary (ADR-0010).
#   TEST-004 — self-registration forcing: greps tests/run-all.sh,
#     tests/run-all.ps1, and .github/workflows/test.yml for the four
#     canonical Pillar-A suite registrations (conditional on the suite file
#     existing on disk; this suite's own registration is always required).
#   TEST-017 — runtime budget: measures this suite's own wall-clock, prints
#     it in the final summary line, self-fails above
#     LOOP_SUITE_BUDGET_SECONDS, and proves the assertion is live via a
#     threshold-0 negative self-check.
#
# Deviations from the investigation.md/requirements.md cap-source
# assumption for impl-review and task-review are recorded in this task's
# implementation report (grep evidence: neither
# plugins/sdd-review-loop/scripts/impl-review-precheck.sh nor
# task-review-precheck.sh enforces a numeric round ceiling; the round<=3
# policy is skill-instruction text in impl-review-loop/SKILL.md and
# task-review-loop/SKILL.md).
set -euo pipefail

START_EPOCH=$(date +%s)
LOOP_SUITE_BUDGET_SECONDS=300

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
INVENTORY_PATH="${LOOP_INVENTORY_PATH:-${REPO_ROOT}/tests/loops/loop-inventory.json}"
VALIDATOR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
RUN_ALL_SH="${REPO_ROOT}/tests/run-all.sh"
RUN_ALL_PS1="${REPO_ROOT}/tests/run-all.ps1"
TEST_YML="${REPO_ROOT}/.github/workflows/test.yml"

PASS=0
FAIL=0
ok()   { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/loop-inventory-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

discover_precheck_scripts() {
  find "${REPO_ROOT}/plugins" -path '*/scripts/*-review-precheck.sh' -print | \
    sed "s#^${REPO_ROOT}/##" | sort
}

# validate_registration <inventory-path>
# Silent predicate (no ok/fail side effects); returns 0 when the inventory
# satisfies AC-001's structural + registration requirements, 1 otherwise.
validate_registration() {
  local inv="$1"
  [[ -f "$inv" ]] || return 1
  jq -e '.schema == "loop-inventory/v1"' "$inv" >/dev/null 2>&1 || return 1
  jq -e '(.loops | type) == "array" and (.loops | length) == 8' "$inv" >/dev/null 2>&1 || return 1
  jq -e '(.loops | map(.id) | unique | length) == 8' "$inv" >/dev/null 2>&1 || return 1

  local script
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    jq -e --arg s "$script" '[.loops[].driver_scripts[]?] | index($s) != null' "$inv" >/dev/null 2>&1 || return 1
  done < <(discover_precheck_scripts)

  local pairs_line stage entry_id pair
  pairs_line="$(grep -m1 -F 'quality:sdd-evaluator|domain:domain-reviewer-a' "$VALIDATOR" | sed 's/)[[:space:]]*;;.*//')"
  [[ -n "$pairs_line" ]] || return 1
  IFS='|' read -ra PAIRS <<< "$pairs_line"
  for pair in "${PAIRS[@]}"; do
    pair="$(printf '%s' "$pair" | xargs)"
    stage="${pair%%:*}"
    case "$stage" in
      spec) entry_id=spec-review ;;
      impl) entry_id=impl-review ;;
      task) entry_id=task-review ;;
      domain) entry_id=domain-review ;;
      quality) entry_id=quality-gate ;;
      *) return 1 ;;
    esac
    jq -e --arg id "$entry_id" '[.loops[].id] | index($id) != null' "$inv" >/dev/null 2>&1 || return 1
  done

  local gate
  while IFS= read -r gate; do
    [[ -n "$gate" ]] || continue
    [[ -f "${REPO_ROOT}/${gate}" ]] || return 1
  done < <(jq -r '.loops[].cross_gates[]?' "$inv" | tr -d '\r')

  return 0
}

# ---------------------------------------------------------------------------
# TEST-001 (AC-001): schema, registration, cross_gates existence, negative self-check
# ---------------------------------------------------------------------------
echo "=== TEST-001: inventory schema + registration forcing ==="

if [[ -f "$INVENTORY_PATH" ]]; then
  ok "TEST-001.0: loop-inventory.json exists at ${INVENTORY_PATH}"
else
  fail "TEST-001.0: loop-inventory.json missing at ${INVENTORY_PATH}"
fi

if jq -e '.schema == "loop-inventory/v1"' "$INVENTORY_PATH" >/dev/null 2>&1; then
  ok "TEST-001.1: schema field is loop-inventory/v1"
else
  fail "TEST-001.1: schema field is not loop-inventory/v1"
fi

if jq -e '(.loops | type) == "array" and (.loops | length) == 8' "$INVENTORY_PATH" >/dev/null 2>&1; then
  ok "TEST-001.2: inventory carries exactly eight loop entries"
else
  fail "TEST-001.2: inventory does not carry exactly eight loop entries"
fi

precheck_gap=0
while IFS= read -r script; do
  [[ -n "$script" ]] || continue
  if jq -e --arg s "$script" '[.loops[].driver_scripts[]?] | index($s) != null' "$INVENTORY_PATH" >/dev/null 2>&1; then
    ok "TEST-001.3: ${script} is registered in some entry's driver_scripts"
  else
    fail "TEST-001.3: ${script} is NOT registered in any entry's driver_scripts"
    precheck_gap=1
  fi
done < <(discover_precheck_scripts)

pairs_line="$(grep -m1 -F 'quality:sdd-evaluator|domain:domain-reviewer-a' "$VALIDATOR" | sed 's/)[[:space:]]*;;.*//')"
if [[ -n "$pairs_line" ]]; then
  IFS='|' read -ra PAIRS <<< "$pairs_line"
  for pair in "${PAIRS[@]}"; do
    pair="$(printf '%s' "$pair" | xargs)"
    stage="${pair%%:*}"
    case "$stage" in
      spec) entry_id=spec-review ;;
      impl) entry_id=impl-review ;;
      task) entry_id=task-review ;;
      domain) entry_id=domain-review ;;
      quality) entry_id=quality-gate ;;
      *) entry_id="" ;;
    esac
    if [[ -n "$entry_id" ]] && jq -e --arg id "$entry_id" '[.loops[].id] | index($id) != null' "$INVENTORY_PATH" >/dev/null 2>&1; then
      ok "TEST-001.4: stage:role pair ${pair} maps to inventory entry ${entry_id}"
    else
      fail "TEST-001.4: stage:role pair ${pair} does not map to an inventory entry"
    fi
  done
else
  fail "TEST-001.4: could not derive stage:role pairs from ${VALIDATOR}"
fi

gate_gap=0
while IFS= read -r gate; do
  [[ -n "$gate" ]] || continue
  if [[ -f "${REPO_ROOT}/${gate}" ]]; then
    ok "TEST-001.5: cross_gates path exists: ${gate}"
  else
    fail "TEST-001.5: cross_gates path does not exist: ${gate}"
    gate_gap=1
  fi
done < <(jq -r '.loops[].cross_gates[]?' "$INVENTORY_PATH" 2>/dev/null | tr -d '\r')

# Negative self-check: remove one registered entry from a mktemp copy and
# assert validate_registration turns red.
NEG_MISSING_ENTRY="${WORK}/missing-entry.json"
if jq 'del(.loops[0])' "$INVENTORY_PATH" > "$NEG_MISSING_ENTRY" 2>/dev/null; then
  if validate_registration "$NEG_MISSING_ENTRY"; then
    fail "TEST-001.6 (negative self-check): removing a registered entry did NOT turn registration validation red"
  else
    ok "TEST-001.6 (negative self-check): removing a registered entry turns registration validation red"
  fi
else
  fail "TEST-001.6 (negative self-check): could not build the mutated mktemp copy"
fi

# ---------------------------------------------------------------------------
# TEST-002 (AC-002): bidirectional numeric cap-drift lock
# ---------------------------------------------------------------------------
echo "=== TEST-002: numeric cap-drift lock (cap_source:script + cap_kind:numeric) ==="

extract_source_cap() {
  local id="$1"
  case "$id" in
    spec-review)
      grep -oE '"\$round" -le [0-9]+' "${REPO_ROOT}/plugins/sdd-review-loop/scripts/spec-review-precheck.sh" 2>/dev/null | \
        head -1 | grep -oE '[0-9]+$'
      ;;
    domain-review)
      grep -oE '"\$round" -le [0-9]+' "${REPO_ROOT}/plugins/sdd-domain/scripts/domain-review-precheck.sh" 2>/dev/null | \
        head -1 | grep -oE '[0-9]+$'
      ;;
    quality-gate)
      grep -oE '"\$count" -ge [0-9]+' "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh" 2>/dev/null | \
        head -1 | grep -oE '[0-9]+$'
      ;;
    *)
      echo ""
      ;;
  esac
}

cap_drift_check() {
  local id="$1" inv="$2" source_val inv_val
  source_val="$(extract_source_cap "$id")"
  inv_val="$(jq -r --arg id "$id" '.loops[] | select(.id == $id) | .cap.value' "$inv" 2>/dev/null | tr -d '\r')"
  [[ -n "$source_val" && "$source_val" == "$inv_val" ]]
}

numeric_ids="$(jq -r '.loops[] | select(.cap_source == "script" and .cap_kind == "numeric") | .id' "$INVENTORY_PATH" 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$numeric_ids" ]]; then
  fail "TEST-002.0: no cap_source:script + cap_kind:numeric entries found to drift-lock"
fi
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  if cap_drift_check "$id" "$INVENTORY_PATH"; then
    ok "TEST-002.1: ${id} cap value greps to its driver source's limit"
  else
    fail "TEST-002.1: ${id} cap value does NOT match its driver source's limit"
  fi
done <<< "$numeric_ids"

if jq -e '[.loops[] | select(.id == "terminal-tier")] | length == 1 and .[0].cap_kind == "state"' "$INVENTORY_PATH" >/dev/null 2>&1; then
  ok "TEST-002.2: terminal-tier is cap_kind:state and excluded from the numeric grep"
else
  fail "TEST-002.2: terminal-tier is not registered as the sole cap_kind:state entry"
fi
if jq -e '[.loops[] | select(.cap_kind == "state")] | length == 1' "$INVENTORY_PATH" >/dev/null 2>&1; then
  ok "TEST-002.3: exactly one cap_kind:state entry exists in the inventory"
else
  fail "TEST-002.3: more than one (or zero) cap_kind:state entries exist"
fi

# Negative self-check: mutate a numeric cap value in a temp copy and assert
# cap_drift_check turns red.
NEG_MUTATED_CAP="${WORK}/mutated-cap.json"
if jq '(.loops[] | select(.id == "spec-review") | .cap.value) = 999' "$INVENTORY_PATH" > "$NEG_MUTATED_CAP" 2>/dev/null; then
  if cap_drift_check "spec-review" "$NEG_MUTATED_CAP"; then
    fail "TEST-002.4 (negative self-check): a mutated cap value did NOT turn the drift lock red"
  else
    ok "TEST-002.4 (negative self-check): a mutated cap value turns the drift lock red"
  fi
else
  fail "TEST-002.4 (negative self-check): could not build the mutated mktemp copy"
fi

# ---------------------------------------------------------------------------
# TEST-003 (AC-003): skill-instruction exemption + fixture_profiles vocabulary lock
# ---------------------------------------------------------------------------
echo "=== TEST-003: skill-instruction exemption + fixture_profiles vocabulary lock ==="

skill_ids="$(jq -r '.loops[] | select(.cap_source == "skill-instruction") | .id' "$INVENTORY_PATH" 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$skill_ids" ]]; then
  fail "TEST-003.0: no cap_source:skill-instruction entries found"
fi
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  if jq -e --arg id "$id" '(.loops[] | select(.id == $id) | has("cap_kind")) | not' "$INVENTORY_PATH" >/dev/null 2>&1; then
    ok "TEST-003.1: ${id} carries no cap_kind field (skill-instruction is exempt from the numeric grep)"
  else
    fail "TEST-003.1: ${id} unexpectedly carries a cap_kind field"
  fi
done <<< "$skill_ids"

for id in wfi-audit hitl-diagnosis; do
  if jq -e --arg id "$id" '.loops[] | select(.id == $id) | .cap_source == "skill-instruction" and (.driver_scripts | length) == 0' "$INVENTORY_PATH" >/dev/null 2>&1; then
    ok "TEST-003.2: ${id} carries cap_source:skill-instruction and driver_scripts: []"
  else
    fail "TEST-003.2: ${id} does not carry cap_source:skill-instruction with driver_scripts: []"
  fi
done

if jq -e '[.loops[].fixture_profiles[]?] | all(. == "greenfield" or . == "brownfield")' "$INVENTORY_PATH" >/dev/null 2>&1; then
  ok "TEST-003.3: every fixture_profiles value is greenfield or brownfield"
else
  fail "TEST-003.3: a fixture_profiles value outside the closed vocabulary was found"
fi
if jq -e '[.loops[] | select((.fixture_profiles | length) == 0)] | length == 0' "$INVENTORY_PATH" >/dev/null 2>&1; then
  ok "TEST-003.4: every entry declares a non-empty fixture_profiles list"
else
  fail "TEST-003.4: an entry declares an empty fixture_profiles list"
fi

# ---------------------------------------------------------------------------
# TEST-004 (AC-004): self-registration forcing across run-all.sh / run-all.ps1 / test.yml
# ---------------------------------------------------------------------------
echo "=== TEST-004: registration forcing (run-all.sh / run-all.ps1 / test.yml) ==="

CANONICAL_BASENAMES=(loop-inventory.tests loop-driver.tests loop-consistency.tests loop-escalation.tests)

assert_registered_sh() {
  local basename="$1"
  grep -q "tests/${basename}\.sh" "$RUN_ALL_SH" 2>/dev/null && \
    grep -q "${basename}\.sh" "$TEST_YML" 2>/dev/null
}
assert_registered_ps1() {
  local basename="$1"
  grep -q "tests/${basename}\.ps1" "$RUN_ALL_PS1" 2>/dev/null && \
    grep -q "${basename}\.ps1" "$TEST_YML" 2>/dev/null
}

for basename in "${CANONICAL_BASENAMES[@]}"; do
  sh_path="${REPO_ROOT}/tests/${basename}.sh"
  ps1_path="${REPO_ROOT}/tests/${basename}.ps1"

  if [[ "$basename" == "loop-inventory.tests" || -f "$sh_path" ]]; then
    if assert_registered_sh "$basename"; then
      ok "TEST-004.1: ${basename}.sh is registered in run-all.sh and test.yml"
    else
      fail "TEST-004.1: ${basename}.sh exists but is NOT registered in run-all.sh and/or test.yml"
    fi
  else
    echo "SKIP: TEST-004.1 ${basename}.sh not yet on disk (later Pillar-A task)"
  fi

  if [[ "$basename" == "loop-inventory.tests" || -f "$ps1_path" ]]; then
    if assert_registered_ps1 "$basename"; then
      ok "TEST-004.2: ${basename}.ps1 is registered in run-all.ps1 and test.yml"
    else
      fail "TEST-004.2: ${basename}.ps1 exists but is NOT registered in run-all.ps1 and/or test.yml"
    fi
  else
    echo "SKIP: TEST-004.2 ${basename}.ps1 not yet on disk (later Pillar-A task)"
  fi
done

# ---------------------------------------------------------------------------
# TEST-017 (AC-017): runtime budget, live negative self-check
# ---------------------------------------------------------------------------
echo "=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=${LOOP_SUITE_BUDGET_SECONDS}) ==="

assert_runtime_budget() {
  local start="$1" budget="$2" now elapsed
  now=$(date +%s)
  elapsed=$(( now - start ))
  [[ "$elapsed" -le "$budget" ]]
}

# Use a synthetic start time strictly in the past (not the suite's real
# START_EPOCH) so the negative self-check is deterministic regardless of how
# fast this suite happens to execute: elapsed is guaranteed >= 1s, and a
# forced threshold of 0 must therefore turn red every time.
SYNTHETIC_PAST_EPOCH=$(( START_EPOCH - 1 ))
if assert_runtime_budget "$SYNTHETIC_PAST_EPOCH" 0; then
  fail "TEST-017.1 (negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
else
  ok "TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red"
fi

ELAPSED_SECONDS=$(( $(date +%s) - START_EPOCH ))
if [[ "$ELAPSED_SECONDS" -le "$LOOP_SUITE_BUDGET_SECONDS" ]]; then
  ok "TEST-017.2: suite completed within the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
else
  fail "TEST-017.2: suite exceeded the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf 'loop-inventory.tests.sh: %d passed, %d failed, %ds elapsed\n' "$PASS" "$FAIL" "$ELAPSED_SECONDS"
[[ "$FAIL" -eq 0 ]]
