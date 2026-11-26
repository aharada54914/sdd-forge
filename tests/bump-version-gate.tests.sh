#!/usr/bin/env bash
# Run the current release gate against copies of the shipped manifests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SELF_SH="${ROOT}/tests/bump-version-gate.tests.sh"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

run_bump_case() {
  local id="$1" method="$2" python=python3
  local SDD_TEST_BASH="${SDD_TEST_BASH:-}"
  if [[ -n "${MSYSTEM:-}" ]]; then
    python=python
    export SDD_TEST_BASH
    SDD_TEST_BASH="$(cygpath -am "${BASH%.exe}.exe")"
  fi
  if "$python" -B "$ROOT/tests/release-readiness.tests.py" "ReleaseReadiness.$method"; then
    ok "$id $method"
  else
    fail "$id $method"
  fi
}

run_test_006() {
  echo "=== TEST-006 (AC-006): CI-resilience + self-registration ==="

  if grep -qF 'pwd -P' "$SELF_SH"; then
    ok "TEST-006 (AC-006, CI-resilience): fixture-root normalization uses pwd -P"
  else
    fail "TEST-006 (AC-006, CI-resilience): pwd -P normalization not found in this suite's own source"
  fi

  # Forbidden-substring tokens are built at runtime -- with names/messages
  # that also avoid the literal substring -- so these self-checks do not
  # trip on their own construction lines.
  local query_tool_char_1 query_tool_char_2 query_tool_token
  query_tool_char_1="j"
  query_tool_char_2="q"
  query_tool_token="${query_tool_char_1}${query_tool_char_2}"
  if grep -qF "$query_tool_token" "$SELF_SH"; then
    fail "TEST-006 (AC-006, CI-resilience): this suite unexpectedly consumes JSON-query-tool output (non-use declaration violated)"
  else
    ok "TEST-006 (AC-006, CI-resilience): this suite consumes no JSON-query-tool output (non-use declaration)"
  fi

  local validator_part_a validator_part_b validator_token
  validator_part_a="validate-review"
  validator_part_b="-context-set"
  validator_token="${validator_part_a}${validator_part_b}"
  if grep -qF "$validator_token" "$SELF_SH"; then
    fail "TEST-006 (AC-006, CI-resilience): this suite unexpectedly drives the real validator (non-use declaration violated)"
  else
    ok "TEST-006 (AC-006, CI-resilience): this suite drives no real validator (non-use declaration)"
  fi

  local arr_part_a arr_part_b arr_pattern
  arr_part_a='[@]'
  arr_part_b='}"'
  arr_pattern="${arr_part_a}${arr_part_b}"
  if grep -qF "$arr_pattern" "$SELF_SH"; then
    fail "TEST-006 (AC-006, CI-resilience): an unguarded (no ':-' default) bash array expansion was found"
  else
    ok "TEST-006 (AC-006, CI-resilience): no unguarded bash array expansion found (set -u empty-array safety)"
  fi

  run_bump_case TEST-006 check_bump_bash_registration
}

# Run
# ---------------------------------------------------------------------------
run_bump_case TEST-001 check_bump_green
run_bump_case TEST-002 check_bump_first_suite_failure
run_bump_case TEST-003 check_bump_last_suite_failure
run_bump_case TEST-004 check_bump_gate_source
run_bump_case TEST-005 check_bump_doctor_failure
run_test_006
run_bump_case TEST-007 check_bump_stale_readme
run_bump_case TEST-007 check_bump_missing_helper

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'not ok: bump-version-gate suite FAILED (%d failures)\n' "$FAIL" >&2
  exit 1
fi
printf 'ok: bump-version-gate suite passed (%d checks)\n' "$PASS"
