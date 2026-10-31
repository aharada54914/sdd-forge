#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
REPORT=${1:-"$ROOT/reports/verification/pr403-t007-waiver-differential.candidate.md"}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$(dirname "$REPORT")"

printf '# PR #403 T-007 candidate red/green verification\n\n' > "$REPORT"
printf 'Candidate-only rerun; this does not rewrite or retroactively validate historical waiver evidence.\n\n' >> "$REPORT"
printf '## Red probes: protected Second Approval writes must be denied\n\n' >> "$REPORT"

run_suite() {
  label=$1; log=$2; shift 2
  if "$@" >"$log" 2>&1; then
    printf '%s: PASS\n' "$label" >> "$REPORT"
    return 0
  else
    code=$?
  fi
  printf '%s: FAIL (exit %s)\n' "$label" "$code" >> "$REPORT"
  sed -n '1,100p' "$log" >&2
  return "$code"
}

run_suite 'POSIX hook guard suite' "$TMP/guards.log" bash "$ROOT/tests/guards.tests.sh"
grep -F 'Second Approval denied even with valid sudo' "$TMP/guards.log" >> "$REPORT"
grep -F 'edit adds Second Approval to tasks.md -> deny' "$TMP/guards.log" | head -1 >> "$REPORT"

run_suite 'PowerShell hook suite' "$TMP/hooks.log" pwsh -NoProfile -File "$ROOT/tests/hooks.tests.ps1"
grep -F 'Second Approval denied even with valid sudo' "$TMP/hooks.log" | head -1 >> "$REPORT"
grep -F 'edit adds Second Approval -> deny' "$TMP/hooks.log" | head -1 >> "$REPORT"

printf '\n## Green probes: approved/independent paths and T-007 candidate checks\n\n' >> "$REPORT"
grep -F 'primary Approval WITH valid sudo -> allow' "$TMP/guards.log" | head -1 >> "$REPORT"
grep -F 'outside CWD + CLAUDE_PROJECT_DIR + PASS verdict -> allow' "$TMP/hooks.log" | head -1 >> "$REPORT"
run_suite 'T-007 focused candidate regressions' "$TMP/candidate.log" bash "$ROOT/tests/pr403-rootfix.candidate.tests.sh"
tail -1 "$TMP/candidate.log" >> "$REPORT"

printf '\n## Scope and limitation\n\n' >> "$REPORT"
printf '%s\n' \
  '- Both platform suites exercise Second Approval write-deny probes; the paired allowed primary-approval/control probes are recorded above.' \
  '- The focused candidate suite exercises risk-source binding, sh/PowerShell approval parity, signature algorithm/tamper rejection, and cross-runtime canonicalization including supplementary Unicode and non-boolean dirty values.' \
  '- This is a reproducible current-state red/green scenario rerun, not a before/after execution of historical T-007 artifacts. Historical waiver logs remain unchanged and must not be represented as containing these added hook-suite runs.' >> "$REPORT"
printf 'report: %s\n' "$REPORT"
