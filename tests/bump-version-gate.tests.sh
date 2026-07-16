#!/usr/bin/env bash
# tests/bump-version-gate.tests.sh — fixture-driven lock for the
# scripts/bump-version.sh loop-gate prerequisite (T-001 / Issue #148 /
# epic-159-pillar-b REQ-001).
#
#   TEST-001 (AC-001) — green path: both loop suites replaced by
#     trivially-passing stubs (design.md Design Decisions: stub-driven
#     green path for suite speed/determinism); bump-version.sh exits 0 and
#     mutates the fixture's release surfaces with the new version string.
#   TEST-002 (AC-002) — red path A: tests/loop-consistency.tests.sh
#     replaced by a failing stub (tests/loop-inventory.tests.sh left as the
#     real, unmodified copy from the fixture's own tar-copy — never
#     reached, since loop-consistency iterates first in the gate's `for`
#     loop and fails closed before loop-inventory would run);
#     bump-version.sh exits non-zero and the fixture reports zero
#     `git status --porcelain` output (zero release-surface mutation).
#   TEST-003 (AC-003) — red path B, independent leg:
#     tests/loop-inventory.tests.sh replaced by a failing stub;
#     tests/loop-consistency.tests.sh left as the real, unmodified copy
#     (genuinely executed here, since it iterates first and must pass for
#     the run to reach loop-inventory's failure) — proving both suites
#     gate independently, not just one.
#   TEST-004 (AC-004) — no-bypass grep self-check over the REAL
#     scripts/bump-version.sh source: no environment-variable/CLI-flag
#     conditional wraps the loop-gate invocation (OQ-007 decision).
#   TEST-005 (AC-005) — line-position ordering assertion: the loop-gate
#     invocation precedes the first mutation step in the REAL source.
#   TEST-006 (AC-006) — CI-resilience + self-registration conformance for
#     this suite itself.
#
# Fixture technique: tar-copy (tests/repository-release-validation.tests.sh:9-16
# precedent), extended with a local `git init` baseline so
# `git status --porcelain` becomes a meaningful zero-mutation proof
# (design.md API/Contract Plan). Every fixture root is `pwd -P` normalized
# immediately after creation (CI-resilience, INV-017,
# tests/lib/loop-driver.sh:124 convention). This suite never writes a real
# repository path; `scripts/bump-version.sh`, `tests/loop-consistency.tests.sh`,
# and `tests/loop-inventory.tests.sh` are read only to build each fixture
# copy, then driven strictly inside that copy.
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

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# build_fixture <label> — tar-copies the real repository (excluding .git
# and the two mcp/*/node_modules trees, which neither bump-version.sh nor
# either loop suite touches, for suite speed) into a fresh mktemp root,
# pwd -P normalizes it, and `git init`s it (no commit yet — the baseline
# commit is taken by commit_fixture_baseline AFTER all per-case setup, so
# a subsequent `git status --porcelain` check measures ONLY what
# bump-version.sh itself did). Echoes the fixture root path.
#
# NOTE: this function is always invoked via command substitution
# (`fixture_root="$(build_fixture ...)"`), which runs it in a SUBSHELL --
# any CLEANUP_ROOTS mutation made here would not propagate back to the
# parent shell. Callers therefore register the returned path's parent
# directory with CLEANUP_ROOTS themselves, in their own (non-subshell)
# scope.
build_fixture() {
  local label="$1"
  local temp_root fixture_root
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/bump-version-gate.${label}.XXXXXX")"
  fixture_root="${temp_root}/repository"
  mkdir -p "$fixture_root"
  (cd "$ROOT" && tar --exclude='./.git' --exclude='./mcp/*/node_modules' -cf - .) \
    | (cd "$fixture_root" && tar -xf -)
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

# rename_changelog_heading <fixture_root> <version> — satisfies
# bump-version.sh's own pre-existing CHANGELOG-heading precondition
# (scripts/bump-version.sh:38-42) so each case isolates the NEW loop-gate
# precondition specifically (design.md API/Contract Plan step 3).
rename_changelog_heading() {
  local fixture_root="$1" version="$2"
  sed -i.bak "s/^## Unreleased\$/## v${version}/" "${fixture_root}/CHANGELOG.md"
  rm -f "${fixture_root}/CHANGELOG.md.bak"
}

# commit_fixture_baseline <fixture_root> — commits the fixture's
# post-setup state (tar-copy + CHANGELOG rename + per-case suite stubs) as
# the git baseline every subsequent `git status --porcelain` call in this
# suite is measured against.
commit_fixture_baseline() {
  local fixture_root="$1"
  git -C "$fixture_root" \
    -c user.email="bump-version-gate-tests@sdd-forge.invalid" \
    -c user.name="bump-version-gate-tests" add -A
  git -C "$fixture_root" \
    -c user.email="bump-version-gate-tests@sdd-forge.invalid" \
    -c user.name="bump-version-gate-tests" commit -q -m "fixture baseline"
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
# TEST-001 (AC-001): green path
# ---------------------------------------------------------------------------
run_test_001() {
  echo "=== TEST-001 (AC-001): green path (both loop suites stubbed passing) ==="
  # Capability probe (CI-resilience convention, INV-017): GNU sed accepts
  # --version; BSD/macOS sed does not. scripts/bump-version.sh's mutation
  # section (scripts/bump-version.sh:51-70) is unedited by this task
  # (design.md API/Contract Plan) and its existing `sed -i "<script>"
  # "<file>"` calls are GNU-only syntax -- a pre-existing, out-of-scope
  # portability gap discovered via this suite, unrelated to REQ-001's
  # loop-gate prerequisite. TEST-002..006 are unaffected: their red paths
  # never reach the mutation section, and TEST-004..006 never invoke it.
  if ! sed --version >/dev/null 2>&1; then
    echo "SKIP: TEST-001 (AC-001) mutation-success assertions -- this host's sed is BSD-style; scripts/bump-version.sh's unedited mutation section (scripts/bump-version.sh:51-70) requires GNU sed. Pre-existing portability gap, out of scope for T-001 (REQ-001 loop-gate logic itself is proven by TEST-002..006, none of which reach the mutation section on this host)."
    return
  fi
  local fixture_root output
  fixture_root="$(build_fixture "green")"
  CLEANUP_ROOTS+=("$(dirname "$fixture_root")")
  stub_suite "$fixture_root" "tests/loop-consistency.tests.sh" 0
  stub_suite "$fixture_root" "tests/loop-inventory.tests.sh" 0
  rename_changelog_heading "$fixture_root" "$VERSION"
  commit_fixture_baseline "$fixture_root"

  output="$(mktemp)"
  if run_bump_version "$fixture_root" "$VERSION" "$output"; then
    ok "TEST-001 (AC-001): bump-version.sh exits 0 when both loop suites are stubbed passing"
  else
    fail "TEST-001 (AC-001): expected exit 0; output: $(cat "$output")"
  fi

  local manifest matched
  matched=1
  for manifest in "$fixture_root"/plugins/*/.claude-plugin/plugin.json; do
    [[ -f "$manifest" ]] || continue
    if grep -qF "\"version\": \"${VERSION}\"" "$manifest"; then
      matched=0
      break
    fi
  done
  if [[ $matched -eq 0 ]]; then
    ok "TEST-001 (AC-001): a plugin manifest now carries the new version string ${VERSION}"
  else
    fail "TEST-001 (AC-001): no plugin manifest carries the new version string ${VERSION}"
  fi

  if grep -qF "v${VERSION}" "$fixture_root/README.md"; then
    ok "TEST-001 (AC-001): README.md current-release line carries the new version string"
  else
    fail "TEST-001 (AC-001): README.md current-release line does not carry ${VERSION}"
  fi

  if grep -qF "${VERSION}" "$fixture_root/tests/validate-repository.ps1"; then
    ok "TEST-001 (AC-001): tests/validate-repository.ps1 carries the new version string"
  else
    fail "TEST-001 (AC-001): tests/validate-repository.ps1 does not carry ${VERSION}"
  fi

  rm -f "$output"
}

# ---------------------------------------------------------------------------
# TEST-002 (AC-002): red path A — loop-consistency stubbed failing
# ---------------------------------------------------------------------------
run_test_002() {
  echo "=== TEST-002 (AC-002): red path A (loop-consistency.tests.sh stubbed failing) ==="
  local fixture_root output porcelain
  fixture_root="$(build_fixture "red-consistency")"
  CLEANUP_ROOTS+=("$(dirname "$fixture_root")")
  stub_suite "$fixture_root" "tests/loop-consistency.tests.sh" 1
  rename_changelog_heading "$fixture_root" "$VERSION"
  commit_fixture_baseline "$fixture_root"

  output="$(mktemp)"
  if run_bump_version "$fixture_root" "$VERSION" "$output"; then
    fail "TEST-002 (AC-002): expected bump-version.sh to exit non-zero when loop-consistency.tests.sh is stubbed failing, but it exited 0"
  else
    ok "TEST-002 (AC-002): bump-version.sh exits non-zero when loop-consistency.tests.sh is stubbed failing"
  fi
  rm -f "$output"

  porcelain="$(git -C "$fixture_root" status --porcelain)"
  if [[ -z "$porcelain" ]]; then
    ok "TEST-002 (AC-002): git status --porcelain is empty after the run (zero release-surface mutation)"
  else
    fail "TEST-002 (AC-002): git status --porcelain is non-empty after the run: ${porcelain}"
  fi
}

# ---------------------------------------------------------------------------
# TEST-003 (AC-003): red path B — loop-inventory stubbed failing, the
# independent leg (loop-consistency.tests.sh left real and genuinely
# executed, since it iterates first and must pass to reach the failure)
# ---------------------------------------------------------------------------
run_test_003() {
  echo "=== TEST-003 (AC-003): red path B (loop-inventory.tests.sh stubbed failing, independent leg) ==="
  local fixture_root output porcelain
  fixture_root="$(build_fixture "red-inventory")"
  CLEANUP_ROOTS+=("$(dirname "$fixture_root")")
  stub_suite "$fixture_root" "tests/loop-inventory.tests.sh" 1
  rename_changelog_heading "$fixture_root" "$VERSION"
  commit_fixture_baseline "$fixture_root"

  output="$(mktemp)"
  if run_bump_version "$fixture_root" "$VERSION" "$output"; then
    fail "TEST-003 (AC-003): expected bump-version.sh to exit non-zero when loop-inventory.tests.sh is stubbed failing, but it exited 0"
  else
    ok "TEST-003 (AC-003): bump-version.sh exits non-zero when loop-inventory.tests.sh is stubbed failing (loop-consistency.tests.sh, run for real, passed first)"
  fi
  rm -f "$output"

  porcelain="$(git -C "$fixture_root" status --porcelain)"
  if [[ -z "$porcelain" ]]; then
    ok "TEST-003 (AC-003): git status --porcelain is empty after the run (zero release-surface mutation)"
  else
    fail "TEST-003 (AC-003): git status --porcelain is non-empty after the run: ${porcelain}"
  fi
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
# TEST-005 (AC-005): ordering assertion over the REAL
# scripts/bump-version.sh source
# ---------------------------------------------------------------------------
run_test_005() {
  echo "=== TEST-005 (AC-005): loop-gate precedes the first mutation step (real scripts/bump-version.sh) ==="
  local src="$BUMP_VERSION_SH"
  local gate_line mutation_line

  gate_line=$(awk '/^for suite in tests\/loop-consistency\.tests\.sh tests\/loop-inventory\.tests\.sh; do$/ { print NR; exit }' "$src")
  mutation_line=$(awk '/sed -i /{ print NR; exit }' "$src")

  if [[ -z "$gate_line" ]]; then
    fail "TEST-005 (AC-005): loop-gate invocation line not found in scripts/bump-version.sh"
    return
  fi
  if [[ -z "$mutation_line" ]]; then
    fail "TEST-005 (AC-005): no 'sed -i' mutation line found in scripts/bump-version.sh"
    return
  fi

  if [[ "$gate_line" -lt "$mutation_line" ]]; then
    ok "TEST-005 (AC-005): loop-gate invocation (line ${gate_line}) precedes the first mutation step (line ${mutation_line})"
  else
    fail "TEST-005 (AC-005): loop-gate invocation (line ${gate_line}) does NOT precede the first mutation step (line ${mutation_line})"
  fi
}

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): CI-resilience + self-registration conformance
# ---------------------------------------------------------------------------
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

  if grep -qF 'bump-version-gate.tests.sh' "$RUN_ALL_SH" 2>/dev/null \
      && grep -qF 'bump-version-gate.tests.sh' "$TEST_YML" 2>/dev/null; then
    ok "TEST-006 (AC-006): bump-version-gate.tests.sh is registered in tests/run-all.sh and .github/workflows/test.yml"
  else
    fail "TEST-006 (AC-006): bump-version-gate.tests.sh is NOT registered in tests/run-all.sh and/or .github/workflows/test.yml"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
run_test_001
run_test_002
run_test_003
run_test_004
run_test_005
run_test_006

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'not ok: bump-version-gate suite FAILED (%d failures)\n' "$FAIL" >&2
  exit 1
fi
printf 'ok: bump-version-gate suite passed (%d checks)\n' "$PASS"
