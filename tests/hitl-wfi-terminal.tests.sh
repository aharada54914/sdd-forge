#!/usr/bin/env bash
# tests/hitl-wfi-terminal.tests.sh -- HITL / WFI-audit terminal-behavior
# suite (T-001 / Issue #145 / epic-159-pillar-a2 REQ-001).
#
# HITL leg (TEST-001, TEST-002): drives a fixture copy of the REAL
#   plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh
#   with a CHECK stub and mocked stdin -- never-reproduces (5 iterations,
#   exit 0, AC-001) and reproduces-on-iteration-3 (exit 1 canary, AC-002).
#   export -f CHECK closes the "CHECK: command not found" (exit 127) false
#   green gap the requirements.md Edge Cases section describes.
# WFI-audit leg (TEST-003): pins the documented one-directional rule --
#   Audit-Attempt >= 3 implies Audit-Status: Human-Blocked -- transcribed
#   from wfi-audit-cycle/SKILL.md precondition 4 (lines 44-50) and STEP 4 /
#   STEP 7 (lines 119-135, 186-203) as a deterministic reference check
#   against fixture-scoped WFI-NNN.md copies. The skill itself is never
#   invoked (AC-003).
# Construction proof (TEST-004): neither new file this feature adds
#   contains an invocation of the remote issue-tracker CLI that SKILL.md
#   STEP 8 would otherwise call, and the WFI-audit fixture's Category
#   field always stays the value that keeps STEP 8 a documented no-op
#   (AC-004).
# Real-document smoke (TEST-005): fixture-scoped, read-only copies of
#   docs/workflow-improvements/WFI-010.md and WFI-011.md satisfy the same
#   invariant; the two real files' SHA-256 is asserted unchanged before vs.
#   after this suite runs (AC-005).
# Self-registration + runtime budget (TEST-006): a grep self-check against
#   tests/run-all.sh / tests/run-all.ps1 / .github/workflows/test.yml, plus
#   the sourced assert_runtime_budget with a threshold-0 negative
#   self-check (AC-006).
#
# CI resilience (AC-018): both mktemp roots below are created directly
# (not via loop_fixture_init) and normalized with `pwd -P` immediately
# after creation (INV-030); every sweep below is a plain loop over literal
# integers, never a possibly-empty array expansion (INV-029); this suite
# reads no jq output (INV-031 non-use declaration); neither leg drives
# validate-review-context-set.sh, so INV-032's capability probe does not
# apply here.
set -euo pipefail

START_EPOCH=$(date +%s)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=tests/lib/loop-driver.sh
source "${REPO_ROOT}/tests/lib/loop-driver.sh"

PASS=0
FAIL=0
ok()   { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# WFI field helpers (plain field extraction/mutation; parser rule: an
# absent Audit-Attempt: field is treated as 0 -- WFI-011.md carries no such
# field at all, see TEST-005).
# ---------------------------------------------------------------------------
_wfi_read_attempt() {
  local file="$1" val
  val="$(grep -m1 '^Audit-Attempt:' "$file" 2>/dev/null | sed 's/^Audit-Attempt:[[:space:]]*//')" || true
  if [[ -n "$val" ]]; then
    printf '%s' "$val"
  else
    printf '0'
  fi
}

_wfi_read_status() {
  local file="$1" val
  val="$(grep -m1 '^Audit-Status:' "$file" 2>/dev/null | sed 's/^Audit-Status:[[:space:]]*//')" || true
  printf '%s' "$val"
}

_wfi_set_field() {
  local file="$1" field="$2" value="$3" tmp
  tmp="$(mktemp "${file}.XXXXXX")"
  if grep -q "^${field}:" "$file"; then
    sed "s/^${field}:.*/${field}: ${value}/" "$file" > "$tmp"
  else
    cp "$file" "$tmp"
    printf '%s: %s\n' "$field" "$value" >> "$tmp"
  fi
  mv "$tmp" "$file"
}

# assert_wfi_audit_transition <file> <audit-attempt-before> <verdict>
#   <expected-audit-attempt-after> <expected-audit-status> [<threshold>]
# Writes <file> with a synthetic pre-mutation state whose parsed
# Audit-Attempt equals <audit-attempt-before> (empty string == field
# absent, parsed as 0), applies the wfi-audit-cycle STEP 4 / STEP 7
# BLOCKED-verdict field mutation (increment Audit-Attempt by 1; set
# Audit-Status to Human-Blocked once the incremented value meets
# <threshold>, default 3, else Not-Started -- the specific below-threshold
# state STEP 4/7 literally prescribe), writes the mutated fields back to
# <file>, and returns 0 only when the re-parsed Audit-Attempt/Audit-Status
# pair matches the two expected arguments.
assert_wfi_audit_transition() {
  local file="$1" before="$2" verdict="$3" expected_after="$4" expected_status="$5" threshold="${6:-3}"
  if [[ "$verdict" != "BLOCKED" ]]; then
    echo "assert_wfi_audit_transition: only the BLOCKED verdict is modeled (SKILL.md STEP 4/7)" >&2
    return 1
  fi

  {
    printf '# WFI fixture (T-001, synthetic)\n'
    printf 'Category: process\n'
    printf 'Audit-Status: Not-Started\n'
    if [[ -n "$before" ]]; then
      printf 'Audit-Attempt: %s\n' "$before"
    fi
  } > "$file"

  local parsed_before after status
  parsed_before="$(_wfi_read_attempt "$file")"
  after=$((parsed_before + 1))
  if [[ "$after" -ge "$threshold" ]]; then
    status="Human-Blocked"
  else
    status="Not-Started"
  fi
  _wfi_set_field "$file" "Audit-Attempt" "$after"
  _wfi_set_field "$file" "Audit-Status" "$status"

  local actual_after actual_status
  actual_after="$(_wfi_read_attempt "$file")"
  actual_status="$(_wfi_read_status "$file")"
  [[ "$actual_after" == "$expected_after" && "$actual_status" == "$expected_status" ]]
}

# ---------------------------------------------------------------------------
# TEST-001 / TEST-002 (AC-001 / AC-002): HITL cap-5 terminal behavior
# ---------------------------------------------------------------------------
echo "=== TEST-001/TEST-002: HITL cap-5 terminal behavior (real template, fixture copy) ==="

HITL_TEMPLATE_REAL="${REPO_ROOT}/plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh"
if [[ ! -f "$HITL_TEMPLATE_REAL" ]]; then
  fail "TEST-001 (AC-001): hitl-loop.template.sh not found at ${HITL_TEMPLATE_REAL}"
  fail "TEST-002 (AC-002): hitl-loop.template.sh not found at ${HITL_TEMPLATE_REAL}"
else
  HITL_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hitl-wfi-terminal-hitl.XXXXXX")"
  HITL_ROOT="$(cd "$HITL_ROOT" && pwd -P)"
  CLEANUP_ROOTS+=("$HITL_ROOT")
  HITL_COPY="${HITL_ROOT}/hitl-loop.template.sh"
  cp "$HITL_TEMPLATE_REAL" "$HITL_COPY"

  HITL_STDIN_5="$(printf '\n%.0s' 1 2 3 4 5)"

  # TEST-001 (AC-001): CHECK never returns true -> 5 iterations, exit 0.
  CHECK() { return 1; }
  export -f CHECK
  if HITL_OUT_1="$(printf '%s' "$HITL_STDIN_5" | bash "$HITL_COPY" 5 2>&1)"; then
    HITL_RC_1=0
  else
    HITL_RC_1=$?
  fi
  HITL_ITER_COUNT_1="$(printf '%s\n' "$HITL_OUT_1" | grep -c '^\[HITL loop\] iteration ')" || true
  if [[ "$HITL_RC_1" -eq 0 && "$HITL_ITER_COUNT_1" -eq 5 ]] \
     && printf '%s\n' "$HITL_OUT_1" | grep -qF 'loop finished without reproducing (5 iterations)'; then
    ok "TEST-001 (AC-001): never-reproducing CHECK completes exactly 5 iterations, exits 0, prints the terminal string"
  else
    fail "TEST-001 (AC-001): expected 5 iterations/exit 0/terminal string, got rc=${HITL_RC_1} iterations=${HITL_ITER_COUNT_1}"
  fi

  # TEST-002 (AC-002): CHECK returns true on iteration 3 -> immediate exit 1.
  HITL_COUNTER_FILE="$(mktemp "${HITL_ROOT}/hitl-check-counter.XXXXXX")"
  printf '0' > "$HITL_COUNTER_FILE"
  export HITL_COUNTER_FILE
  CHECK() {
    local n
    n="$(cat "$HITL_COUNTER_FILE")"
    n=$((n + 1))
    printf '%s' "$n" > "$HITL_COUNTER_FILE"
    [ "$n" -eq 3 ]
  }
  export -f CHECK
  if HITL_OUT_2="$(printf '%s' "$HITL_STDIN_5" | bash "$HITL_COPY" 5 2>&1)"; then
    HITL_RC_2=0
  else
    HITL_RC_2=$?
  fi
  HITL_ITER_COUNT_2="$(printf '%s\n' "$HITL_OUT_2" | grep -c '^\[HITL loop\] iteration ')" || true
  if [[ "$HITL_RC_2" -eq 1 && "$HITL_ITER_COUNT_2" -eq 3 ]] \
     && printf '%s\n' "$HITL_OUT_2" | grep -qF 'RED: symptom reproduced on iteration 3'; then
    ok "TEST-002 (AC-002): CHECK returning true on iteration 3 exits 1 immediately with the RED canary message"
  else
    fail "TEST-002 (AC-002): expected an immediate exit 1 at iteration 3 with the RED canary message, got rc=${HITL_RC_2} iterations=${HITL_ITER_COUNT_2}"
  fi
fi

# ---------------------------------------------------------------------------
# TEST-003 (AC-003): WFI-audit one-directional sweep, 0 -> 1 -> 2 -> 3
# ---------------------------------------------------------------------------
echo "=== TEST-003: WFI-audit one-directional sweep (Audit-Attempt 0 -> 1 -> 2 -> 3) ==="

WFI_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hitl-wfi-terminal-audit.XXXXXX")"
WFI_ROOT="$(cd "$WFI_ROOT" && pwd -P)"
CLEANUP_ROOTS+=("$WFI_ROOT")
WFI_FIXTURE="${WFI_ROOT}/WFI-900.md"

if assert_wfi_audit_transition "$WFI_FIXTURE" "" BLOCKED 1 "Not-Started"; then
  ok "TEST-003.1 (AC-003): Audit-Attempt absent (=0), BLOCKED -> Audit-Attempt 1, Audit-Status Not-Started"
else
  fail "TEST-003.1 (AC-003): Audit-Attempt absent (=0), BLOCKED transition mismatch"
fi

if assert_wfi_audit_transition "$WFI_FIXTURE" 1 BLOCKED 2 "Not-Started"; then
  ok "TEST-003.2 (AC-003): Audit-Attempt 1, BLOCKED -> Audit-Attempt 2, Audit-Status Not-Started"
else
  fail "TEST-003.2 (AC-003): Audit-Attempt 1, BLOCKED transition mismatch"
fi

if assert_wfi_audit_transition "$WFI_FIXTURE" 2 BLOCKED 3 "Human-Blocked"; then
  ok "TEST-003.3 (AC-003): Audit-Attempt 2, BLOCKED -> Audit-Attempt 3, Audit-Status Human-Blocked (convergence guard)"
else
  fail "TEST-003.3 (AC-003): Audit-Attempt 2, BLOCKED transition mismatch"
fi

# Negative self-check: mutate the threshold from 3 to 4 while still
# demanding the SAME correct Human-Blocked outcome for Audit-Attempt 2 -> 3.
# The real (unmutated) rule sets Human-Blocked; the mutated threshold
# instead produces Not-Started, so the assertion must turn red.
if assert_wfi_audit_transition "$WFI_FIXTURE" 2 BLOCKED 3 "Human-Blocked" 4; then
  fail "TEST-003.4 (AC-003, negative self-check): mutating the threshold to 4 did NOT turn the attempt-3 assertion red"
else
  ok "TEST-003.4 (AC-003, negative self-check): mutating the threshold to 4 turns the attempt-3 assertion red, proving the check is live"
fi

# ---------------------------------------------------------------------------
# TEST-004 (AC-004): construction proof
# ---------------------------------------------------------------------------
echo "=== TEST-004: no remote-CLI invocation + Category construction proof ==="

SELF_SH="${REPO_ROOT}/tests/hitl-wfi-terminal.tests.sh"
SELF_PS1="${REPO_ROOT}/tests/hitl-wfi-terminal.tests.ps1"

# Built at runtime (not embedded literally) so this very check line does
# not match its own pattern.
_no_cli_token="$(printf '%s' "g" "h" " ")"
_CLI_MATCH=0
for f in "$SELF_SH" "$SELF_PS1"; do
  [[ -f "$f" ]] || continue
  if grep -n -- "$_no_cli_token" "$f" >/dev/null 2>&1; then
    _CLI_MATCH=1
  fi
done
if [[ "$_CLI_MATCH" -eq 0 ]]; then
  ok "TEST-004.1 (AC-004): neither new file in this feature invokes the remote issue-tracker CLI"
else
  fail "TEST-004.1 (AC-004): a remote issue-tracker CLI invocation was found in a new file"
fi

WFI_FIXTURE_CATEGORY="$(grep -m1 '^Category:' "$WFI_FIXTURE" 2>/dev/null | sed 's/^Category:[[:space:]]*//')" || true
if [[ "$WFI_FIXTURE_CATEGORY" == "process" ]]; then
  ok "TEST-004.2 (AC-004): WFI-audit fixture Category is process, keeping SKILL.md STEP 8 a documented no-op by construction"
else
  fail "TEST-004.2 (AC-004): WFI-audit fixture Category is ${WFI_FIXTURE_CATEGORY}, not the expected process value"
fi

# ---------------------------------------------------------------------------
# TEST-005 (AC-005): real-document read-only smoke
# ---------------------------------------------------------------------------
echo "=== TEST-005: WFI-010.md / WFI-011.md read-only smoke ==="

REAL_WFI_010="${REPO_ROOT}/docs/workflow-improvements/WFI-010.md"
REAL_WFI_011="${REPO_ROOT}/docs/workflow-improvements/WFI-011.md"

check_real_doc_invariant() {
  local file="$1" label="$2" attempt status
  attempt="$(_wfi_read_attempt "$file")"
  status="$(_wfi_read_status "$file")"
  if [[ "$attempt" -ge 3 ]]; then
    if [[ "$status" == "Human-Blocked" ]]; then
      ok "TEST-005 (AC-005): ${label} Audit-Attempt=${attempt} (>=3) and Audit-Status=Human-Blocked -- invariant holds"
    else
      fail "TEST-005 (AC-005): ${label} Audit-Attempt=${attempt} (>=3) but Audit-Status=${status} -- invariant violated"
    fi
  else
    if [[ "$status" != "Human-Blocked" ]]; then
      ok "TEST-005 (AC-005): ${label} Audit-Attempt=${attempt} (<3) and Audit-Status=${status} -- invariant holds"
    else
      fail "TEST-005 (AC-005): ${label} Audit-Attempt=${attempt} (<3) but Audit-Status=Human-Blocked -- invariant violated"
    fi
  fi
}

if [[ -f "$REAL_WFI_010" && -f "$REAL_WFI_011" ]]; then
  SHA_010_BEFORE="$(_loop_sha256 "$REAL_WFI_010")"
  SHA_011_BEFORE="$(_loop_sha256 "$REAL_WFI_011")"

  SMOKE_010="${WFI_ROOT}/WFI-010.md"
  SMOKE_011="${WFI_ROOT}/WFI-011.md"
  cp "$REAL_WFI_010" "$SMOKE_010"
  cp "$REAL_WFI_011" "$SMOKE_011"

  check_real_doc_invariant "$SMOKE_010" "WFI-010.md"
  check_real_doc_invariant "$SMOKE_011" "WFI-011.md"

  SHA_010_AFTER="$(_loop_sha256 "$REAL_WFI_010")"
  SHA_011_AFTER="$(_loop_sha256 "$REAL_WFI_011")"
  if [[ "$SHA_010_BEFORE" == "$SHA_010_AFTER" ]]; then
    ok "TEST-005 (AC-005): WFI-010.md SHA-256 unchanged before vs. after this suite run"
  else
    fail "TEST-005 (AC-005): WFI-010.md SHA-256 changed during this suite run"
  fi
  if [[ "$SHA_011_BEFORE" == "$SHA_011_AFTER" ]]; then
    ok "TEST-005 (AC-005): WFI-011.md SHA-256 unchanged before vs. after this suite run"
  else
    fail "TEST-005 (AC-005): WFI-011.md SHA-256 changed during this suite run"
  fi
else
  fail "TEST-005 (AC-005): docs/workflow-improvements/WFI-010.md and/or WFI-011.md not found"
fi

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): self-registration + runtime budget
# ---------------------------------------------------------------------------
echo "=== TEST-006: self-registration + runtime budget (LOOP_SUITE_BUDGET_SECONDS=${LOOP_SUITE_BUDGET_SECONDS}) ==="

RUN_ALL_SH="${REPO_ROOT}/tests/run-all.sh"
RUN_ALL_PS1="${REPO_ROOT}/tests/run-all.ps1"
TEST_YML="${REPO_ROOT}/.github/workflows/test.yml"

if grep -q 'tests/hitl-wfi-terminal\.tests\.sh' "$RUN_ALL_SH" 2>/dev/null \
   && grep -q 'hitl-wfi-terminal\.tests\.sh' "$TEST_YML" 2>/dev/null; then
  ok "TEST-006.1 (AC-006): hitl-wfi-terminal.tests.sh is registered in run-all.sh and test.yml"
else
  fail "TEST-006.1 (AC-006): hitl-wfi-terminal.tests.sh is NOT registered in run-all.sh and/or test.yml"
fi

if grep -q 'tests/hitl-wfi-terminal\.tests\.ps1' "$RUN_ALL_PS1" 2>/dev/null \
   && grep -q 'hitl-wfi-terminal\.tests\.ps1' "$TEST_YML" 2>/dev/null; then
  ok "TEST-006.2 (AC-006): hitl-wfi-terminal.tests.ps1 is registered in run-all.ps1 and test.yml"
else
  fail "TEST-006.2 (AC-006): hitl-wfi-terminal.tests.ps1 is NOT registered in run-all.ps1 and/or test.yml"
fi

SYNTHETIC_PAST_EPOCH=$(( START_EPOCH - 1 ))
if assert_runtime_budget "$SYNTHETIC_PAST_EPOCH" 0; then
  fail "TEST-006.3 (AC-006, negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
else
  ok "TEST-006.3 (AC-006, negative self-check): forcing the runtime budget to 0 turns the assertion red"
fi

ELAPSED_SECONDS=$(( $(date +%s) - START_EPOCH ))
if assert_runtime_budget "$START_EPOCH"; then
  ok "TEST-006.4 (AC-006): suite completed within the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
else
  fail "TEST-006.4 (AC-006): suite exceeded the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf 'hitl-wfi-terminal.tests.sh: %d passed, %d failed, %ds elapsed\n' "$PASS" "$FAIL" "$ELAPSED_SECONDS"
[[ "$FAIL" -eq 0 ]]
