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
#   TEST-008 — optional capability-applicability contract and legacy-copy
#     compatibility.
#   TEST-009 — event-trace collector/comparator API, trace lifecycle, and
#     byte-stable legacy assertion bodies.
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
LOOP_DRIVER="${REPO_ROOT}/tests/lib/loop-driver.sh"

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

validate_capability_applicability() {
  local inv="$1"
  jq -e '
    (.loops | length) == 8 and
    ([.loops[] | select(has("capability_applicability"))] | length) == 1 and
    (.loops[] | select(.id == "quality-gate") | .capability_applicability) == {
      "disabled-legacy": "not-applicable (disabled-legacy)",
      "advisory": "advisory",
      "required": "required"
    }
  ' "$inv" >/dev/null 2>&1
}

function_body_sha256() {
  local file="$1" function_name="$2"
  awk -v signature="^${function_name}\\(\\)" '
    $0 ~ signature { capture=1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$file" | shasum -a 256 | awk '{print $1}'
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
# TEST-008 (AC-008/AC-009): capability applicability + legacy compatibility
# ---------------------------------------------------------------------------
echo "=== TEST-008: quality-gate capability applicability ==="

LEGACY_INVENTORY="${WORK}/loop-inventory.pre-epic-195.json"
jq 'del(.loops[].capability_applicability)' "$INVENTORY_PATH" > "$LEGACY_INVENTORY"
if validate_registration "$LEGACY_INVENTORY"; then
  ok "TEST-008.1: a pre-epic-195 copy without capability_applicability remains base-valid"
else
  fail "TEST-008.1: a pre-epic-195 copy without capability_applicability is not base-valid"
fi

if validate_capability_applicability "$INVENTORY_PATH"; then
  ok "TEST-008.2: only quality-gate carries the exact three-state applicability mapping"
else
  fail "TEST-008.2: quality-gate does not carry the exact three-state applicability mapping"
fi

BAD_CAPABILITY_INVENTORY="${WORK}/loop-inventory.bad-capability.json"
jq '(.loops[] | select(.id == "quality-gate") | .capability_applicability) = {
      "disabled-legacy": "disabled",
      "advisory": "advisory",
      "required": "required"
    }' "$INVENTORY_PATH" > "$BAD_CAPABILITY_INVENTORY"
if validate_capability_applicability "$BAD_CAPABILITY_INVENTORY"; then
  fail "TEST-008.3 (negative self-check): an incorrect applicability value passed validation"
else
  ok "TEST-008.3 (negative self-check): an incorrect applicability value is rejected"
fi

# ---------------------------------------------------------------------------
# TEST-009 (AC-009): trace API, normalization, purity, and non-regression
# ---------------------------------------------------------------------------
echo "=== TEST-009: event trace API + legacy helper non-regression ==="

EXPECTED_ARTIFACTS_SHA="dce6534c9e395bdc04dc558e115b91bad5e9950ce8606783512bb2a4bd85e65e"
EXPECTED_TERMINAL_SHA="f325a4df4a276cf4a4bc7a4051032693cceb6bff6db99fce27eb4b13b18473df"

if [[ "$(function_body_sha256 "$LOOP_DRIVER" assert_artifacts_schema)" == "$EXPECTED_ARTIFACTS_SHA" ]]; then
  ok "TEST-009.1: assert_artifacts_schema remains byte-identical"
else
  fail "TEST-009.1: assert_artifacts_schema changed"
fi
if [[ "$(function_body_sha256 "$LOOP_DRIVER" assert_terminal)" == "$EXPECTED_TERMINAL_SHA" ]]; then
  ok "TEST-009.2: assert_terminal remains byte-identical"
else
  fail "TEST-009.2: assert_terminal changed"
fi

MUTATED_DRIVER="${WORK}/loop-driver.mutated.sh"
sed 's/local loop_id="\$1" observed=/local loop_identifier="\$1" observed=/' "$LOOP_DRIVER" > "$MUTATED_DRIVER"
if [[ "$(function_body_sha256 "$MUTATED_DRIVER" assert_terminal)" == "$EXPECTED_TERMINAL_SHA" ]]; then
  fail "TEST-009.3 (negative self-check): a deliberately changed legacy function was accepted"
else
  ok "TEST-009.3 (negative self-check): a deliberately changed legacy function is rejected"
fi

# shellcheck source=tests/lib/loop-driver.sh
source "$LOOP_DRIVER"
TRACE_API_READY=true
for function_name in _loop_trace_emit assert_capability_applicability assert_event_trace; do
  if declare -F "$function_name" >/dev/null 2>&1; then
    ok "TEST-009.4: ${function_name} is available"
  else
    fail "TEST-009.4: ${function_name} is unavailable"
    TRACE_API_READY=false
  fi
done

if [[ "$TRACE_API_READY" == true ]]; then
  _LOOP_EVENT_TRACE='[{"kind":"stale","producer":"stale","seq":99,"value":"stale"}]'
  _LOOP_EVENT_SEQ=99
  if loop_fixture_init greenfield trace-reset >/dev/null 2>&1 && \
     [[ "$_LOOP_EVENT_TRACE" == '[]' && "$_LOOP_EVENT_SEQ" == 0 ]]; then
    ok "TEST-009.5: loop_fixture_init resets the trace and sequence per fixture"
  else
    fail "TEST-009.5: loop_fixture_init did not reset the trace and sequence"
  fi
  rm -rf "${LOOP_FIXTURE_ROOT:-}"

  if assert_capability_applicability quality-gate advisory advisory && \
     jq -e 'length == 1 and .[0].kind == "quality-gate-outcome" and
       .[0].producer == "quality-gate-outcome:capability-applicability" and
       .[0].seq == 1 and .[0].value == {"applicability":"advisory"}' \
       <<< "$_LOOP_EVENT_TRACE" >/dev/null; then
    ok "TEST-009.6: capability applicability compares exactly and emits one canonical event"
  else
    fail "TEST-009.6: capability applicability comparison/event emission is incorrect"
  fi
  if assert_capability_applicability quality-gate unknown unknown >/dev/null 2>&1; then
    fail "TEST-009.7: an unknown fixture state was accepted"
  else
    ok "TEST-009.7: an unknown fixture state is rejected"
  fi
  if assert_capability_applicability quality-gate advisory Advisory >/dev/null 2>&1; then
    fail "TEST-009.7: a mis-cased observed applicability was accepted"
  else
    ok "TEST-009.7: applicability comparison is case-sensitive"
  fi

  _LOOP_EVENT_TRACE='[]'
  _LOOP_EVENT_SEQ=0
  SKILL_PATH_JSON="$(jq -cn --arg value "${SDD_LOOP_REPO_ROOT}/plugins/sdd-review-loop/SKILL.md" '$value')"
  _loop_trace_emit skill-order skill-order:invocation "$SKILL_PATH_JSON"
  _loop_trace_emit review-loop-presence review-loop-presence:stage-dispatch '"spec"'
  _loop_trace_emit approval-checkpoint approval-checkpoint:reserve \
    '{"stage":"quality","role":"sdd-evaluator","run_id":"ignored"}'
  _loop_trace_emit quality-gate-outcome quality-gate-outcome:escalation \
    '{"next_tier":"human","wall_clock":"ignored"}'
  _loop_trace_emit quality-gate-outcome quality-gate-outcome:capability-applicability \
    '{"applicability":"required","wall_clock":"ignored"}'
  _loop_trace_emit skip-stop-message skip-stop-message:skip '"SKIP: cited upstream issue"'
  _loop_trace_emit skip-stop-message skip-stop-message:stop '"PROJECT_CONTEXT_INVALID"'
  _loop_trace_emit done-transition done-transition:assert-terminal '"Done"'
  if jq -e '[.[].seq] == [1,2,3,4,5,6,7,8]' <<< "$_LOOP_EVENT_TRACE" >/dev/null; then
    ok "TEST-009.8: the collector assigns one trace-wide monotonic sequence"
  else
    fail "TEST-009.8: collector sequence is not trace-wide and monotonic"
  fi
  TRACE_BEFORE_BAD_JSON="$_LOOP_EVENT_TRACE"
  SEQ_BEFORE_BAD_JSON="$_LOOP_EVENT_SEQ"
  if _loop_trace_emit done-transition done-transition:assert-terminal '{bad-json' >/dev/null 2>&1; then
    fail "TEST-009.9: invalid event value JSON was accepted"
  elif [[ "$_LOOP_EVENT_TRACE" == "$TRACE_BEFORE_BAD_JSON" && "$_LOOP_EVENT_SEQ" == "$SEQ_BEFORE_BAD_JSON" ]]; then
    ok "TEST-009.9: invalid event JSON is rejected without consuming sequence state"
  else
    fail "TEST-009.9: invalid event JSON changed trace or sequence state"
  fi

  GOLDEN_TRACE="${WORK}/golden-trace.json"
  jq -n '[
    {kind:"skill-order", producer:"skill-order:invocation", seq:1,
      value:"plugins/sdd-review-loop/SKILL.md"},
    {kind:"review-loop-presence", producer:"review-loop-presence:stage-dispatch", seq:2, value:"spec"},
    {kind:"approval-checkpoint", producer:"approval-checkpoint:reserve", seq:3,
      value:{stage:"quality", role:"sdd-evaluator"}},
    {kind:"quality-gate-outcome", producer:"quality-gate-outcome:escalation", seq:4,
      value:{next_tier:"human"}},
    {kind:"quality-gate-outcome", producer:"quality-gate-outcome:capability-applicability", seq:5,
      value:{applicability:"required"}},
    {kind:"skip-stop-message", producer:"skip-stop-message:skip", seq:6,
      value:"SKIP: cited upstream issue"},
    {kind:"skip-stop-message", producer:"skip-stop-message:stop", seq:7,
      value:"PROJECT_CONTEXT_INVALID"},
    {kind:"done-transition", producer:"done-transition:assert-terminal", seq:8, value:"Done"}
  ]' > "$GOLDEN_TRACE"
  TRACE_SNAPSHOT="$_LOOP_EVENT_TRACE"
  SEQ_SNAPSHOT="$_LOOP_EVENT_SEQ"
  if assert_event_trace "$GOLDEN_TRACE" && \
     [[ "$_LOOP_EVENT_TRACE" == "$TRACE_SNAPSHOT" && "$_LOOP_EVENT_SEQ" == "$SEQ_SNAPSHOT" ]]; then
    ok "TEST-009.10: comparator normalizes values, matches the golden trace, and is pure"
  else
    fail "TEST-009.10: comparator failed normalization, identity, or purity"
  fi

  for mutation in kind producer value count; do
    MUTATED_TRACE="${WORK}/golden-trace.${mutation}.json"
    case "$mutation" in
      kind) jq '.[0].kind = "review-loop-presence"' "$GOLDEN_TRACE" > "$MUTATED_TRACE" ;;
      producer) jq '.[4].producer = "quality-gate-outcome:escalation"' "$GOLDEN_TRACE" > "$MUTATED_TRACE" ;;
      value) jq '.[7].value = "Implementation Complete"' "$GOLDEN_TRACE" > "$MUTATED_TRACE" ;;
      count) jq 'del(.[7])' "$GOLDEN_TRACE" > "$MUTATED_TRACE" ;;
    esac
    if assert_event_trace "$MUTATED_TRACE" >/dev/null 2>&1; then
      fail "TEST-009.11: ${mutation} mismatch was accepted"
    else
      ok "TEST-009.11: ${mutation} mismatch is rejected"
    fi
  done

  if function_body_sha256 "$LOOP_DRIVER" assert_event_trace >/dev/null && \
     ! awk '/^assert_event_trace\(\)/,/^}/' "$LOOP_DRIVER" | grep -q '_loop_trace_emit'; then
    ok "TEST-009.12: assert_event_trace is a pure reader and never calls the appender"
  else
    fail "TEST-009.12: assert_event_trace calls the trace appender"
  fi

  MISCASED_REPO_ROOT="$(printf '%s' "$SDD_LOOP_REPO_ROOT" | tr '[:lower:]' '[:upper:]')"
  _LOOP_EVENT_TRACE="$(jq -cn --arg value "${MISCASED_REPO_ROOT}/plugins/sdd-review-loop/SKILL.md" \
    '[{kind:"skill-order", producer:"skill-order:invocation", seq:1, value:$value}]')"
  MISCASED_PATH_GOLDEN="${WORK}/golden-trace.mis-cased-path.json"
  jq -n '[{kind:"skill-order", producer:"skill-order:invocation", seq:1,
    value:"plugins/sdd-review-loop/SKILL.md"}]' > "$MISCASED_PATH_GOLDEN"
  if assert_event_trace "$MISCASED_PATH_GOLDEN" >/dev/null 2>&1; then
    fail "TEST-009.13: a mis-cased repository path was canonicalized as a match"
  else
    ok "TEST-009.13: path canonicalization is case-sensitive"
  fi
fi

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
