#!/usr/bin/env bash
# Acceptance driver for REQ-006/REQ-007 (TEST-025, TEST-029, TEST-030).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$ROOT/plugins/sdd-quality-loop/scripts"
FEATURE="$ROOT/specs/epic-196-a8-integration"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/a8-process-integrity.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

passed=0
failed=0

run_checker() {
  "$@"
}

expect_pass() {
  local label="$1"
  shift
  local output status
  set +e
  output="$(run_checker "$@" 2>&1)"
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    printf 'PASS: %s\n' "$label"
    passed=$((passed + 1))
  else
    printf 'FAIL: %s (exit %d)\n%s\n' "$label" "$status" "$output"
    failed=$((failed + 1))
  fi
}

expect_reject() {
  local label="$1"
  shift
  local output status
  set +e
  output="$(run_checker "$@" 2>&1)"
  status=$?
  set -e
  if [[ $status -ne 0 ]] && grep -q '^missing: ' <<<"$output"; then
    printf 'PASS: %s\n' "$label"
    passed=$((passed + 1))
  else
    printf 'FAIL: %s (mutated fixture was not rejected with a missing: diagnostic)\n%s\n' "$label" "$output"
    failed=$((failed + 1))
  fi
}

cp "$FEATURE/design.md" "$TMP_DIR/design-missing.md"
cp "$FEATURE/design.md" "$TMP_DIR/design-ambiguous.md"
cp "$FEATURE/design.md" "$TMP_DIR/design-duplicate.md"
cp "$FEATURE/design.md" "$TMP_DIR/design-malformed.md"
cp "$FEATURE/requirements.md" "$TMP_DIR/requirements-scope.md"
cp "$FEATURE/design.md" "$TMP_DIR/design-uncited.md"

python3 - "$TMP_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

missing = root / "design-missing.md"
missing.write_text(
    "\n".join(
        line for line in missing.read_text(encoding="utf-8").splitlines()
        if "Fixture Contract table definition (AC-001)" not in line
    ) + "\n",
    encoding="utf-8",
)

ambiguous = root / "design-ambiguous.md"
text = ambiguous.read_text(encoding="utf-8")
text = text.replace("| automated |", "| automated / manual-required |", 1)
ambiguous.write_text(text, encoding="utf-8")

duplicate = root / "design-duplicate.md"
text = duplicate.read_text(encoding="utf-8")
text = text.replace(
    "\n## Path/Line-Ending Regression Matrix",
    "\n## Automated / Manual Classification Table (REQ-006; AC-025)\n"
    "\n## Path/Line-Ending Regression Matrix",
    1,
)
duplicate.write_text(text, encoding="utf-8")

malformed = root / "design-malformed.md"
text = malformed.read_text(encoding="utf-8")
text = text.replace(
    "| Fixture Contract table definition (AC-001) | automated | — |",
    "| Fixture Contract table definition (AC-001) | automated — |",
    1,
)
malformed.write_text(text, encoding="utf-8")

scope = root / "requirements-scope.md"
text = scope.read_text(encoding="utf-8")
needle = "\n- AC-029:"
mutation = (
    "\n  Epic A8 will build for `epic-195-a7-compatibility` the new "
    "`check-a7-owned-surface.sh` / `check-a7-owned-surface.ps1` pair, "
    "plugin hook config `plugins/a7/windows-hooks.json`, and "
    "environment-specific test `tests/a7-windows.tests.ps1`.\n"
)
scope.write_text(text.replace(needle, mutation + needle, 1), encoding="utf-8")

uncited = root / "design-uncited.md"
text = uncited.read_text(encoding="utf-8")
needle = "\n## Automated / Manual Classification Table"
mutation = (
    "\ninstall.sh currently accepts six targets.\n"
)
uncited.write_text(text.replace(needle, mutation + needle, 1), encoding="utf-8")
PY

if [[ "${A8_PROCESS_CHECK_MODE:-strict}" == "red" ]]; then
  red_invalid=0
  observe_red() {
    local label="$1"
    shift
    local output status
    set +e
    output="$(run_checker "$@" 2>&1)"
    status=$?
    set -e
    if [[ $status -ne 0 ]] && grep -q '^missing: ' <<<"$output"; then
      printf 'RED: %s rejected (exit %d)\n%s\n' "$label" "$status" "$output"
    else
      printf 'INVALID RED: %s was not rejected with a missing: diagnostic\n%s\n' "$label" "$output"
      red_invalid=$((red_invalid + 1))
    fi
  }
  observe_red "TEST-025 missing row" "$SCRIPTS/check-a8-classification-table.sh" "$TMP_DIR/design-missing.md"
  observe_red "TEST-025 ambiguous row" "$SCRIPTS/check-a8-classification-table.sh" "$TMP_DIR/design-ambiguous.md"
  observe_red "TEST-029 foreign-Epic artifact" "$SCRIPTS/check-a8-scope-boundary.sh" "$TMP_DIR/requirements-scope.md"
  observe_red "TEST-030 uncited claim" "$SCRIPTS/check-a8-citation-compliance.sh" \
    "$FEATURE/investigation.md" "$FEATURE/requirements.md" "$TMP_DIR/design-uncited.md"
  [[ $red_invalid -eq 0 ]] || exit 2
  printf 'RED: all required mutated fixtures were rejected; exiting non-zero by design\n'
  exit 1
fi

expect_pass "TEST-025 real classification table" \
  "$SCRIPTS/check-a8-classification-table.sh" "$FEATURE/design.md"
expect_reject "TEST-025 missing classification row" \
  "$SCRIPTS/check-a8-classification-table.sh" "$TMP_DIR/design-missing.md"
expect_reject "TEST-025 ambiguous classification row" \
  "$SCRIPTS/check-a8-classification-table.sh" "$TMP_DIR/design-ambiguous.md"
expect_reject "TEST-025 duplicate classification table" \
  "$SCRIPTS/check-a8-classification-table.sh" "$TMP_DIR/design-duplicate.md"
expect_reject "TEST-025 malformed classification row" \
  "$SCRIPTS/check-a8-classification-table.sh" "$TMP_DIR/design-malformed.md"
expect_pass "TEST-029 real scope boundary" \
  "$SCRIPTS/check-a8-scope-boundary.sh" "$FEATURE/requirements.md"
expect_reject "TEST-029 foreign-Epic artifact mutation" \
  "$SCRIPTS/check-a8-scope-boundary.sh" "$TMP_DIR/requirements-scope.md"
expect_pass "TEST-030 real citation compliance" \
  "$SCRIPTS/check-a8-citation-compliance.sh" \
  "$FEATURE/investigation.md" "$FEATURE/requirements.md" "$FEATURE/design.md"
expect_reject "TEST-030 uncited factual-claim mutation" \
  "$SCRIPTS/check-a8-citation-compliance.sh" \
  "$FEATURE/investigation.md" "$FEATURE/requirements.md" "$TMP_DIR/design-uncited.md"

if true; then
  expected_sh=(
    cross-runtime-handoff check-installed-plugin-drift install-uninstall-matrix
    validate-live-host-proof path-lineending-regression check-a8-process-integrity
  )
  expected_ps1=(
    cross-runtime-handoff check-installed-plugin-drift install-uninstall-matrix
    validate-live-host-proof path-lineending-regression check-a8-process-integrity
    cli-hook-enforcement
  )
  for suite in "${expected_sh[@]}"; do
    count="$(grep -c "tests/${suite}\.tests\.sh" "$ROOT/tests/run-all.sh" || true)"
    [[ "$count" == 1 ]] || { printf 'FAIL: registration tests/%s.tests.sh count=%s\n' "$suite" "$count"; failed=$((failed + 1)); }
  done
  for suite in "${expected_ps1[@]}"; do
    if [[ "$suite" == cli-hook-enforcement ]]; then
      pattern="tests/${suite}\.ps1"
    else
      pattern="tests/${suite}\.tests\.ps1"
    fi
    count="$(grep -c "$pattern" "$ROOT/tests/run-all.ps1" || true)"
    [[ "$count" == 1 ]] || { printf 'FAIL: PowerShell registration %s count=%s\n' "$suite" "$count"; failed=$((failed + 1)); }
  done
  count="$(grep -c 'tests/cli-hook-enforcement\.ps1' "$ROOT/tests/run-all.sh" || true)"
  [[ "$count" == 1 ]] || { printf 'FAIL: POSIX aggregate registration cli-hook-enforcement count=%s\n' "$count"; failed=$((failed + 1)); }
  workflow="$FEATURE/human-copy/.github/workflows/test.yml"
  for suite in "${expected_sh[@]}"; do
    grep -q "tests/${suite}.tests.sh" "$workflow" || { printf 'FAIL: staged CI missing %s bash step\n' "$suite"; failed=$((failed + 1)); }
    grep -q "tests/${suite}.tests.ps1" "$workflow" || { printf 'FAIL: staged CI missing %s pwsh step\n' "$suite"; failed=$((failed + 1)); }
  done
  grep -q 'tests/cli-hook-enforcement.ps1' "$workflow" || { printf 'FAIL: staged CI missing cli-hook-enforcement\n'; failed=$((failed + 1)); }
  manifest_hash="$(awk '$2 == ".github/workflows/test.yml" {print $1}' "$FEATURE/human-copy/MANIFEST.sha256")"
  actual_hash="$(shasum -a 256 "$workflow" | awk '{print $1}')"
  [[ -n "$manifest_hash" && "$manifest_hash" == "$actual_hash" ]] || { printf 'FAIL: staged workflow manifest mismatch\n'; failed=$((failed + 1)); }
  if git -C "$ROOT" diff HEAD -- . ':!scripts/bump-version.sh' | grep -E '^\+[^+].*(VERSION|version)[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' >/dev/null; then
    printf 'FAIL: version string changed outside scripts/bump-version.sh\n'
    failed=$((failed + 1))
  fi
fi

printf 'check-a8-process-integrity: %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
