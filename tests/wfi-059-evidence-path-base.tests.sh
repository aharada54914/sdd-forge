#!/usr/bin/env bash
# WFI-059 designed-red regression: this suite MUST fail until the staged
# protected-script patch is applied, then pass unchanged.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CHECK_SH="${WFI_059_CHECK_SH:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-contract.sh}"
PPI_SH="${WFI_059_PPI_SH:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0
FAIL=0

ok() { echo "ok: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }

ROOT="$WORK/project"
SPEC="$ROOT/specs/wfi-059"
CONTRACT="$SPEC/verification/T-001.contract.json"
mkdir -p "$SPEC/verification" "$ROOT/input"
git -C "$ROOT" init -q
git -C "$ROOT" config user.email wfi-059@example.invalid
git -C "$ROOT" config user.name WFI-059
printf '# Tasks\n\n## T-001 Fixture\n\nStatus: Planned\nRisk: low\nCross-Model: enabled\n' >"$ROOT/tasks.md"
printf '# Clean input\n' >"$ROOT/input/context.md"
printf 'WFI-059-EVIDENCE-CONTENT\n' >"$SPEC/verification/evidence.log"
git -C "$ROOT" add tasks.md input/context.md specs/wfi-059/verification/evidence.log
git -C "$ROOT" commit -q -m fixture

write_contract() {
  local evidence="$1"
  {
    printf '{\n  "task_id": "T-001",\n  "feature": "wfi-059",\n  "checks": [\n'
    printf '    {"id":"lint","required":true,"passes":true,"evidence":"%s","waiver_reason":""},\n' "$evidence"
    printf '    {"id":"typecheck","required":true,"passes":true,"evidence":"%s","waiver_reason":""},\n' "$evidence"
    printf '    {"id":"unit-tests","required":true,"passes":true,"evidence":"%s","waiver_reason":""},\n' "$evidence"
    printf '    {"id":"build","required":true,"passes":true,"evidence":"%s","waiver_reason":""},\n' "$evidence"
    printf '    {"id":"placeholder-scan","required":true,"passes":true,"evidence":"%s","waiver_reason":""},\n' "$evidence"
    printf '    {"id":"task-state-check","required":true,"passes":true,"evidence":"%s","waiver_reason":""}\n' "$evidence"
    printf '  ]\n}\n'
  } >"$CONTRACT"
}

run_check() {
  local base="$1"
  CHECK_EXIT=0
  CHECK_OUTPUT="$(bash "$CHECK_SH" "$CONTRACT" "$base" 2>&1)" || CHECK_EXIT=$?
}

run_prepare() {
  # --spec-root is deliberately omitted. It is joined against --project-root,
  # so passing an ABSOLUTE "$ROOT/specs" resolves to nothing: the preparer then
  # finds no contract, writes a bundle with only its own header, and exits 0.
  # Measured -- an absolute --spec-root yields a 292-byte bundle whose
  # input_digest is e3b0c442... (the sha256 of the empty string), against 1504
  # bytes with the default. Every assertion about bundle CONTENT below is
  # vacuous under that form, which is how it passed review unnoticed.
  PREPARE_EXIT=0
  PREPARE_OUTPUT="$(bash "$PPI_SH" --task T-001 --feature wfi-059 --input "$ROOT/input" --tasks-file "$ROOT/tasks.md" --project-root "$ROOT" --out "$ROOT/bundle.txt" 2>&1)" || PREPARE_EXIT=$?
}

# Historical ambiguous form: the caller-provided spec directory made this
# pass check-contract, while the preparer resolved it from the project root.
write_contract 'verification/evidence.log'
run_check "$SPEC"
if [[ "$CHECK_EXIT" -ne 0 ]] && grep -Fq "project-root-relative base: $ROOT" <<<"$CHECK_OUTPUT"; then
  ok "spec-relative evidence is rejected with the canonical project-root base"
else
  fail "spec-relative evidence must be rejected from project root; exit=$CHECK_EXIT output=$CHECK_OUTPUT"
fi
run_prepare
# The annotation names the join as "<project-root>/<path>", NOT as an absolute
# path. Measured: the bundle sanitizer redacts every /home, /root, /Users,
# /var, /etc, /usr, /opt, /tmp and /private path before a bundle reaches a
# vendor, so an absolute form always arrives as "no file exists at
# [PATH_REDACTED]" -- strictly less diagnosable than the "there" it replaces.
# The placeholder survives sanitization and still carries both halves of the
# defect: the relative path the contract wrote, and the base it was joined
# against. Owner-approved wording change, 2026-09-04; recorded in WFI-059.
ATTEMPTED='<project-root>/verification/evidence.log'
if [[ "$PREPARE_EXIT" -eq 0 ]] && grep -Fq "[contract names this evidence path but no file exists at $ATTEMPTED]" "$ROOT/bundle.txt"; then
  ok "missing-evidence annotation names the attempted project-root join"
else
  fail "annotation must name $ATTEMPTED; exit=$PREPARE_EXIT output=$PREPARE_OUTPUT"
fi

# Canonical form: unchanged PASS through both consumers, with the evidence
# bytes carried into the sanitized panel bundle.
write_contract 'specs/wfi-059/verification/evidence.log'
run_check "$ROOT"
if [[ "$CHECK_EXIT" -eq 0 ]]; then ok "canonical project-root-relative contract passes"; else fail "canonical contract must pass; output=$CHECK_OUTPUT"; fi
run_prepare
if [[ "$PREPARE_EXIT" -eq 0 ]] && grep -Fq 'WFI-059-EVIDENCE-CONTENT' "$ROOT/bundle.txt"; then
  ok "canonical evidence content reaches the bundle"
else
  fail "canonical evidence must reach bundle; exit=$PREPARE_EXIT output=$PREPARE_OUTPUT"
fi

echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
