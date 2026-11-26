#!/usr/bin/env bash
# Run the current release gate against copies of the shipped manifests.
# TEST-004, TEST-006 and TEST-007 retain their independent legacy checks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BUMP_VERSION_SH="${ROOT}/scripts/bump-version.sh"
SELF_SH="${ROOT}/tests/bump-version-gate.tests.sh"
RUN_ALL_SH="${ROOT}/tests/run-all.sh"
TEST_YML="${ROOT}/.github/workflows/test.yml"
VERSION="9.9.9"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

SHARED_FIXTURE_BASE_COMMIT=""

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# Only TEST-007 needs the tracked checkout and its real repository validator.
build_fixture() {
  local label="$1"
  local temp_root fixture_root archive
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/bump-version-gate.${label}.XXXXXX")"
  fixture_root="${temp_root}/repository"
  archive="${temp_root}/repository.tar"
  mkdir -p "$fixture_root"
  git -C "$ROOT" archive --format=tar --output="$archive" HEAD
  [[ -s "$archive" ]] || {
    printf 'fixture archive is empty: %s\n' "$archive" >&2
    return 1
  }
  tar -xf "$archive" -C "$fixture_root"
  # Exercise the working-tree gate/validator while the remaining fixture stays
  # pinned to the tracked snapshot; never invoke the real repository's bump.
  cp "$ROOT/scripts/bump-version.sh" "$fixture_root/scripts/bump-version.sh"
  cp "$ROOT/tests/validate-repository.ps1" "$fixture_root/tests/validate-repository.ps1"
  fixture_root="$(cd "$fixture_root" && pwd -P)"
  git -C "$fixture_root" init -q
  printf '%s' "$fixture_root"
}

# stub_suite <fixture_root> <relative_suite_path> <exit_code>
stub_suite() {
  local fixture_root="$1" relpath="$2" code="$3"
  printf '#!/usr/bin/env bash\nexit %s\n' "$code" > "${fixture_root}/${relpath}"
  chmod +x "${fixture_root}/${relpath}"
}

pass_suite_with_marker() {
  local fixture_root="$1" relpath="$2"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'marker_file="$(cd "$(dirname "$0")/.." && pwd)/.bump-gate-loop-consistency-pass"' \
    ': > "$marker_file"' \
    'exit 0' > "${fixture_root}/${relpath}"
  chmod +x "${fixture_root}/${relpath}"
}

# rename_changelog_heading <fixture_root> <version> — satisfies
# bump-version.sh's own pre-existing CHANGELOG-heading precondition
# (scripts/bump-version.sh:38-42) so each case isolates the NEW loop-gate
# precondition specifically (design.md API/Contract Plan step 3).
#
# Renames the fixture's "## Unreleased" heading when there is one. Between a
# release and the next entry landing, the real CHANGELOG legitimately has no
# such heading (scripts/bump-version.sh has just renamed it), and the plain
# rename would then no-op silently and leave every case failing on the
# CHANGELOG precondition instead of exercising the loop gate -- so the
# heading is inserted after the "# Changelog" title in that state. Either
# way the postcondition is asserted, never assumed: no heading, no fixture.
rename_changelog_heading() {
  local fixture_root="$1" version="$2"
  local changelog="${fixture_root}/CHANGELOG.md"
  if grep -q '^## Unreleased$' "$changelog"; then
    sed -i.bak "s/^## Unreleased\$/## v${version}/" "$changelog"
    rm -f "${changelog}.bak"
  else
    awk -v heading="## v${version}" '
      !done && /^# Changelog$/ { print; print ""; print heading; done = 1; next }
      { print }
      END { if (!done) { print ""; print heading } }
    ' "$changelog" > "${changelog}.new"
    mv "${changelog}.new" "$changelog"
  fi
  if ! grep -Eq "^## v${version//./\\.}( |\$)" "$changelog"; then
    printf 'fixture setup failed: no "## v%s" heading in %s\n' "$version" "$changelog" >&2
    exit 1
  fi
}

# commit_fixture_baseline <fixture_root> — commits the one shared source
# snapshot as the reset baseline. Case-specific setup is committed by
# commit_fixture_case with explicit paths, so the expensive full index walk
# happens once.
commit_fixture_baseline() {
  local fixture_root="$1"
  git -C "$fixture_root" \
    -c user.email="bump-version-gate-tests@sdd-forge.invalid" \
    -c user.name="bump-version-gate-tests" add -A
  git -C "$fixture_root" \
    -c user.email="bump-version-gate-tests@sdd-forge.invalid" \
    -c user.name="bump-version-gate-tests" commit -q -m "fixture baseline"
  SHARED_FIXTURE_BASE_COMMIT="$(git -C "$fixture_root" rev-parse HEAD)"
}

reset_fixture_case() {
  local fixture_root="$1"
  git -C "$fixture_root" reset --hard -q "$SHARED_FIXTURE_BASE_COMMIT"
  git -C "$fixture_root" clean -fdx -q
}

commit_fixture_case() {
  local fixture_root="$1"
  shift
  git -C "$fixture_root" \
    -c user.email="bump-version-gate-tests@sdd-forge.invalid" \
    -c user.name="bump-version-gate-tests" add -- "$@"
  git -C "$fixture_root" \
    -c user.email="bump-version-gate-tests@sdd-forge.invalid" \
    -c user.name="bump-version-gate-tests" commit -q -m "fixture case"
}

# run_bump_version <fixture_root> <version> <output_file> — invokes the
# FIXTURE's own copy of bump-version.sh (never the real one). Meant to be
# called as an `if` condition so `set -e` never aborts this suite on the
# expected-red cases.
run_bump_version() {
  local fixture_root="$1" version="$2" output_file="$3"
  bash "${fixture_root}/scripts/bump-version.sh" "$version" >"$output_file" 2>&1
}

# ---------------------------------------------------------------------------
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

run_test_007() {
  local fixture_root scenario relative output porcelain
  if ! command -v pwsh >/dev/null 2>&1; then
    echo "SKIP: release-source bump prerequisite requires pwsh"
    return
  fi
  fixture_root="$(build_fixture source-prerequisite)"
  CLEANUP_ROOTS+=("$(dirname "$fixture_root")")
  commit_fixture_baseline "$fixture_root"
  for scenario in missing-managed-entry stale-current-readme; do
    reset_fixture_case "$fixture_root"
    pass_suite_with_marker "$fixture_root" "tests/loop-consistency.tests.sh"
    stub_suite "$fixture_root" "tests/loop-inventory.tests.sh" 0
    rename_changelog_heading "$fixture_root" "$VERSION"
    if [[ "$scenario" == missing-managed-entry ]]; then
      relative="plugins/sdd-implementation/scripts/managed-model-entry.py"
      rm "$fixture_root/$relative"
    else
      relative="README.md"
      sed -i.bak 's/^v[0-9][0-9.]* /v0.0.0 /' "$fixture_root/$relative"
      rm "$fixture_root/$relative.bak"
    fi
    commit_fixture_case "$fixture_root" "$relative" \
      tests/loop-consistency.tests.sh tests/loop-inventory.tests.sh CHANGELOG.md
    output="$(mktemp)"
    if run_bump_version "$fixture_root" "$VERSION" "$output"; then
      fail "TEST-007: ${scenario} passed the release-source prerequisite"
    elif grep -Fq 'repository validation failed; no release surface was modified.' "$output"; then
      ok "TEST-007: ${scenario} stopped at the real repository validator"
    else
      fail "TEST-007: ${scenario} failed for an unrelated reason: $(cat "$output")"
    fi
    porcelain="$(git -C "$fixture_root" status --porcelain)"
    if [[ -z "$porcelain" && ! -e "$fixture_root/.bump-gate-loop-consistency-pass" ]]; then
      ok "TEST-007: ${scenario} left release surfaces unchanged and did not run loops"
    else
      fail "TEST-007: ${scenario} changed the fixture or ran loops: ${porcelain}"
    fi
    rm -f "$output"
  done
}

# ---------------------------------------------------------------------------
# TEST-004 (AC-004): no-bypass grep self-check over the REAL
# scripts/bump-version.sh source
# ---------------------------------------------------------------------------
run_test_004() {
  echo "=== TEST-004 (AC-004): no-bypass self-check (real scripts/bump-version.sh) ==="
  local src="$BUMP_VERSION_SH"
  local start_line end_line block

  start_line=$(awk '/^# Loop-suite prerequisite \(issue #148\)/ { print NR; exit }' "$src")
  if [[ -z "$start_line" ]]; then
    fail "TEST-004 (AC-004): loop-gate marker comment not found in scripts/bump-version.sh"
    return
  fi

  end_line=$(awk -v s="$start_line" 'NR > s && /^done$/ { print NR; exit }' "$src")
  if [[ -z "$end_line" ]]; then
    fail "TEST-004 (AC-004): loop-gate block's closing 'done' not found after line ${start_line}"
    return
  fi

  block="$(sed -n "${start_line},${end_line}p" "$src")"

  local for_line
  for_line=$(printf '%s\n' "$block" | awk '/^for suite in tests\/loop-consistency\.tests\.sh tests\/loop-inventory\.tests\.sh; do$/ { print NR; exit }')
  if [[ -z "$for_line" ]]; then
    fail "TEST-004 (AC-004): the loop-gate 'for' statement is missing or indented (possibly nested inside a bypass conditional)"
    return
  fi
  ok "TEST-004 (AC-004): the loop-gate 'for' statement is unindented (top-level, not nested inside a conditional)"

  # Keyword sweep over the CODE only (the 'for' line through 'done'),
  # excluding the two leading comment lines -- the comment above the block
  # legitimately documents "no bypass" in prose, which would otherwise
  # false-trip a whole-block sweep.
  local code_block
  code_block="$(printf '%s\n' "$block" | sed -n "${for_line},\$p")"
  if printf '%s\n' "$code_block" | grep -Eiq 'SKIP|BYPASS|OVERRIDE|CONTINUE-ON-ERROR'; then
    fail "TEST-004 (AC-004): a bypass-suggestive token (SKIP/BYPASS/OVERRIDE) was found inside the loop-gate block's code"
  else
    ok "TEST-004 (AC-004): no bypass-suggestive token (SKIP/BYPASS/OVERRIDE) inside the loop-gate block's code"
  fi

  local pre_for
  if [[ "$for_line" -gt 1 ]]; then
    pre_for="$(printf '%s\n' "$block" | sed -n "1,$(( for_line - 1 ))p" | grep -Ev '^[[:space:]]*(#.*)?$' || true)"
  else
    pre_for=""
  fi
  if [[ -z "$pre_for" ]]; then
    ok "TEST-004 (AC-004): no statement (conditional or otherwise) precedes the loop-gate 'for' entry"
  else
    fail "TEST-004 (AC-004): a statement precedes the loop-gate 'for' entry, possibly gating it: ${pre_for}"
  fi
}

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): CI-resilience + self-registration conformance
# ---------------------------------------------------------------------------
assert_self_registered() {
  local registered_suites
  # Membership comes from the executable inventory, not runner source text.
  registered_suites="$(bash "$RUN_ALL_SH" --list)" || return 1
  grep -Fx -- 'tests/bump-version-gate.tests.sh' <<< "$registered_suites" >/dev/null &&
    grep -qF 'bump-version-gate.tests.sh' "$TEST_YML" 2>/dev/null
}

check_registration_controls() {
  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/bump-registration.XXXXXX")" || return 1
  CLEANUP_ROOTS+=("$work")
  local RUN_ALL_SH="${work}/runner.sh" TEST_YML="${work}/workflow.yml"
  local REGISTRATION_LIST REGISTRATION_EXIT=0
  export REGISTRATION_LIST REGISTRATION_EXIT
  printf '%s\n' '[[ "$1" == "--list" ]] || exit 9' \
    'printf "%s\n" "$REGISTRATION_LIST"' 'exit "$REGISTRATION_EXIT"' > "$RUN_ALL_SH"
  printf '%s\n' 'run: bash tests/bump-version-gate.tests.sh' > "$TEST_YML"
  REGISTRATION_LIST='tests/bump-version-gate.tests.sh'
  if assert_self_registered; then
    ok "TEST-006: dynamic exact registration accepted"
  else
    fail "TEST-006: dynamic exact registration rejected"
  fi
  # A comment is deliberately present: source text must not imply membership.
  printf '%s\n' '# bump-version-gate.tests.sh' >> "$RUN_ALL_SH"
  local control
  for control in missing near-match failed-list missing-ci; do
    REGISTRATION_LIST='tests/bump-version-gate.tests.sh'
    REGISTRATION_EXIT=0
    case "$control" in
      missing) REGISTRATION_LIST='' ;;
      near-match) REGISTRATION_LIST='tests/bump-version-gate.tests.sh.bak' ;;
      failed-list) REGISTRATION_EXIT=7 ;;
      missing-ci) printf '%s\n' 'run: echo no suite' > "$TEST_YML" ;;
    esac
    if assert_self_registered; then
      fail "TEST-006: ${control} registration accepted"
    else
      ok "TEST-006: ${control} registration rejected"
    fi
  done
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

  if assert_self_registered; then
    ok "TEST-006 (AC-006): bump-version-gate.tests.sh is registered in tests/run-all.sh and .github/workflows/test.yml"
  else
    fail "TEST-006 (AC-006): bump-version-gate.tests.sh is NOT registered in tests/run-all.sh and/or .github/workflows/test.yml"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
run_bump_case TEST-001 check_bump_green
run_bump_case TEST-002 check_bump_first_suite_failure
run_bump_case TEST-003 check_bump_last_suite_failure
run_test_004
run_bump_case TEST-005 check_bump_doctor_failure
run_test_006
run_test_007
check_registration_controls

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'not ok: bump-version-gate suite FAILED (%d failures)\n' "$FAIL" >&2
  exit 1
fi
printf 'ok: bump-version-gate suite passed (%d checks)\n' "$PASS"
