#!/usr/bin/env bash
# WFI-058 designed-red regression: this suite MUST fail until the staged
# protected-script patch is applied, then pass unchanged.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PPI_SH="${WFI_058_PPI_SH:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0
FAIL=0

ok() { echo "ok: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi
}

init_fixture() {
  local root="$1" declared_hash="$2"
  mkdir -p "$root/input" "$root/reports/implementation/wfi-058"
  git -C "$root" init -q
  git -C "$root" config user.email wfi-058@example.invalid
  git -C "$root" config user.name WFI-058
  printf 'shared v1\n' >"$root/shared.txt"
  if [[ "$declared_hash" == auto ]]; then declared_hash="$(sha256_file "$root/shared.txt")"; fi
  printf '# Tasks\n\n## T-001 Fixture\n\nStatus: Planned\nRisk: high\nCross-Model: enabled\n' >"$root/tasks.md"
  printf '# Implementation Report\n\n## Outputs\n\n| Path | SHA-256 |\n|---|---|\n| `shared.txt` | `%s` |\n\n## Evidence\nfixture\n' "$declared_hash" >"$root/reports/implementation/wfi-058/T-001.md"
  git -C "$root" add shared.txt tasks.md reports/implementation/wfi-058/T-001.md
  git -C "$root" commit -q -m C1-outputs-declared
  FIXTURE_C1="$(git -C "$root" rev-parse HEAD)"
  printf 'shared v2 drift\n' >"$root/shared.txt"
  git -C "$root" add shared.txt
  git -C "$root" commit -q -m C2-output-drift
  printf '\nTask ID: T-001\n' >>"$root/reports/implementation/wfi-058/T-001.md"
  git -C "$root" add reports/implementation/wfi-058/T-001.md
  git -C "$root" commit -q -m C3-header-only-report-edit
  FIXTURE_C3="$(git -C "$root" rev-parse HEAD)"
}

run_prepare() {
  local root="$1"
  PREPARE_EXIT=0
  PREPARE_OUTPUT="$(bash "$PPI_SH" --task T-001 --feature wfi-058 --input "$root/input" --tasks-file "$root/tasks.md" --project-root "$root" --out "$root/bundle.txt" 2>&1)" || PREPARE_EXIT=$?
}

GOOD="$WORK/good"
init_fixture "$GOOD" auto
GOOD_C1="$FIXTURE_C1"
GOOD_C3="$FIXTURE_C3"
run_prepare "$GOOD"
echo "WFI-058 fixture anchors: Outputs-section C1=$GOOD_C1 header-only C3=$GOOD_C3"
if [[ "$PREPARE_EXIT" -eq 0 ]]; then ok "C3 succeeds after output drift"; else fail "C3 must resolve drift at C1; exit=$PREPARE_EXIT output=$PREPARE_OUTPUT"; fi
if grep -Fq "declaration commit ${GOOD_C1:0:7}" <<<"$PREPARE_OUTPUT"; then ok "notice names the Outputs-section anchor C1"; else fail "notice must name C1 ${GOOD_C1:0:7}; output=$PREPARE_OUTPUT"; fi

BAD="$WORK/control"
init_fixture "$BAD" "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
run_prepare "$BAD"
if [[ "$PREPARE_EXIT" -ne 0 ]] && grep -Fq 'declared output hash mismatch: shared.txt' <<<"$PREPARE_OUTPUT"; then ok "control mismatched at worktree and C1 fails closed"; else fail "control must fail closed; exit=$PREPARE_EXIT output=$PREPARE_OUTPUT"; fi

echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
