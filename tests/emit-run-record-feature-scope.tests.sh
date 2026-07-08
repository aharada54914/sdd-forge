#!/usr/bin/env bash
# Regression: emit-run-record.sh must scope gate_reports and review_tickets to
# the target feature. Task IDs (T-NNN) collide across features, so a repo-wide
# grep over reports/quality-gate/ or docs/review-tickets/ misattributes other
# features' gate reports, BLOCKED verdicts, and ticket severities to the run
# record -- the exact defect seen in
# reports/runs/RUN-20260705T171721Z-local-env-mcp.json (blocked:3, major:2)
# versus that feature's own retrospective (blocked:0, one ticket).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRIPT="$REPO_ROOT/plugins/sdd-quality-loop/scripts/emit-run-record.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/emit-run-record-scope.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ok()   { printf 'ok: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# --- Fixture repo: feat-a (target) interleaved with feat-b (must be excluded)
mkdir -p "$WORK/specs/feat-a" "$WORK/reports/quality-gate" "$WORK/docs/review-tickets"

cat > "$WORK/specs/feat-a/tasks.md" <<'EOF'
## T-001 first task
Status: Done

## T-002 second task
Status: Done
EOF

# feat-a: T-001 gated twice (max_runs_single_task = 2), both PASS.
cat > "$WORK/reports/quality-gate/a-t001-run1.md" <<'EOF'
Task: T-001
Feature: feat-a
VERDICT: PASS
EOF
cat > "$WORK/reports/quality-gate/a-t001-run2.md" <<'EOF'
Task: T-001
Feature: feat-a
VERDICT: PASS
EOF

# feat-a: T-002 gated once. CRLF line endings guard the Feature-line grep's
# trailing-whitespace tolerance -- a CR must not drop this from the scope.
printf 'Task: T-002\r\nFeature: feat-a\r\nVERDICT: PASS\r\n' \
  > "$WORK/reports/quality-gate/a-t002-run1.md"

# feat-b: same bare task id T-002, and a BLOCKED verdict. Repo-wide greps would
# fold this into feat-a's total, max_runs, and blocked counts -- it must not.
cat > "$WORK/reports/quality-gate/b-t002-run1.md" <<'EOF'
Task: T-002
Feature: feat-b
VERDICT: BLOCKED
BLOCKED
EOF

# feat-a: exactly one review ticket, severity major.
cat > "$WORK/docs/review-tickets/RT-a.yml" <<'EOF'
ticket_id: RT-a
status: open
severity: major
target:
  feature: feat-a
  task: T-002
EOF

# feat-b: a critical ticket that must not be attributed to feat-a.
cat > "$WORK/docs/review-tickets/RT-b.yml" <<'EOF'
ticket_id: RT-b
status: open
severity: critical
target:
  feature: feat-b
  task: T-002
EOF

# feat-a: CRLF ticket -- severity must still be counted despite \r\n endings.
printf 'ticket_id: RT-c\r\nstatus: open\r\nseverity: minor\r\ntarget:\r\n  feature: feat-a\r\n  task: T-001\r\n' \
  > "$WORK/docs/review-tickets/RT-c.yml"

# --- Run the emitter from the fixture repo root ----------------------------
( cd "$WORK" && sh "$SCRIPT" feat-a --track lite >/dev/null )
OUT="$(find "$WORK/reports/runs" -name 'RUN-*-feat-a.json' | head -n 1)"
if [ -z "$OUT" ]; then
  fail "emit-run-record produced no run record for feat-a"
  printf '\nemit-run-record-feature-scope.tests.sh: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  exit 1
fi

assert_eq() { # <jq-path> <expected> <label>
  local got
  got="$(jq -r "$1" "$OUT")"
  if [ "$got" = "$2" ]; then
    ok "$3 ($1 = $2)"
  else
    fail "$3: $1 = $got, expected $2"
  fi
}

assert_eq '.metrics.gate_reports.total'                3 'gate_reports.total counts only feat-a reports'
assert_eq '.metrics.gate_reports.blocked'              0 "feat-b's BLOCKED report is not counted for feat-a"
assert_eq '.metrics.gate_reports.max_runs_single_task' 2 'max_runs_single_task reflects feat-a T-001 gated twice'
assert_eq '.metrics.first_pass_gate.passed_first_try'  1 'only feat-a T-002 passed on a single gate run'
assert_eq '.metrics.review_tickets.major'              1 'review_tickets.major counts only feat-a tickets'
assert_eq '.metrics.review_tickets.critical'           0 "feat-b's critical ticket is not counted for feat-a"
assert_eq '.metrics.review_tickets.minor'              1 'CRLF feat-a ticket severity is counted'

printf '\nemit-run-record-feature-scope.tests.sh: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
