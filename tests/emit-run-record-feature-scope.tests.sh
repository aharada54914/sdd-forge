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

# ============================================================================
# quality-loop-fixes T-002 (#176 / WFI-010): anchored VERDICT: blocked-count
# read (AC-008..012, TEST-008..012). This is a NET NEW fixture (feature
# feat-t002), added specifically to close the INV-010 coverage gap -- the
# feat-a/feat-b fixture above never exercises a same-feature,
# non-BLOCKED-verdict report whose BODY prose independently contains the
# literal substring "BLOCKED". Neither the feat-a/feat-b fixture above nor
# its assertions are modified for this (AC-011).
# ============================================================================
mkdir -p "$WORK/specs/feat-t002"
cat > "$WORK/specs/feat-t002/tasks.md" <<'EOF'
## T-001 dummy task
Status: Done
EOF

# t002-blocked: anchored VERDICT: BLOCKED on its own header line -- TRUE
# POSITIVE, same-feature, must be counted (AC-008 positive).
cat > "$WORK/reports/quality-gate/t002-blocked.md" <<'EOF'
Task: T-001
Feature: feat-t002
VERDICT: BLOCKED
EOF

# t002-pass / t002-needswork: ordinary non-blocked verdicts, no "BLOCKED"
# substring anywhere -- must never be counted (AC-008 negative).
cat > "$WORK/reports/quality-gate/t002-pass.md" <<'EOF'
Task: T-002
Feature: feat-t002
VERDICT: PASS
EOF

cat > "$WORK/reports/quality-gate/t002-needswork.md" <<'EOF'
Task: T-003
Feature: feat-t002
VERDICT: NEEDS_WORK
EOF

# t002-noverdict: legacy report shape, no VERDICT: line at all -- must not
# be counted as blocked (AC-009, fail-open per OQ-4).
cat > "$WORK/reports/quality-gate/t002-noverdict.md" <<'EOF'
Task: T-004
Feature: feat-t002
This is a legacy report predating the VERDICT: convention. It has no
verdict header line at all.
EOF

# t002-bodyblocked: the AC-010/AC-011 coverage-gap-closing fixture, mirroring
# reports/quality-gate/T-008.md's real shape (INV-009) -- VERDICT: PASS on
# its own header line, but BODY prose independently contains the literal
# substring "BLOCKED" twice. Proven RED against the pre-fix unanchored
# `grep -q 'BLOCKED'` scan (specs/quality-loop-fixes/verification/qg/T-002/red.log:
# gate_reports.blocked wrongly read 2, not 1) before this fix landed; this
# assertion below runs against the fixed, anchored-read script (GREEN).
cat > "$WORK/reports/quality-gate/t002-bodyblocked.md" <<'EOF'
Task: T-005
Feature: feat-t002
VERDICT: PASS

> Note: per this repository's policy, a BLOCKED verdict must stop the
> pipeline immediately and no further tasks should proceed while any task
> remains BLOCKED. This task's own verdict above is PASS, not BLOCKED.
EOF

( cd "$WORK" && sh "$SCRIPT" feat-t002 --track lite >/dev/null )
OUT="$(find "$WORK/reports/runs" -name 'RUN-*-feat-t002.json' | head -n 1)"
if [ -z "$OUT" ]; then
  fail "emit-run-record produced no run record for feat-t002"
else
  assert_eq '.metrics.gate_reports.total'   1 'feat-t002 gate_reports.total counts only the tasks.md-listed T-001 report'
  assert_eq '.metrics.gate_reports.blocked' 1 'feat-t002 gate_reports.blocked counts ONLY the anchored VERDICT: BLOCKED report -- the VERDICT: PASS report with body-text "BLOCKED" (AC-010), the VERDICT: NEEDS_WORK report (AC-008 negative), and the no-VERDICT-line report (AC-009) are all correctly excluded'
fi

# ============================================================================
# T-004 (#153): sdd-run-record/v2 effort attribution + degradation lock
# (REQ-004; AC-021..026, AC-051; security-spec.md B4). Each scenario below
# uses its own uniquely-named feature slug so RUN-<UTC-second>-<feature>.json
# filenames never collide across scenarios invoked within the same second
# (no sleep-based serialization needed).
# ============================================================================

jqr() { # <jq-filter> <file> -- CRLF-tolerant jq consumption (CI resilience)
  jq -r "$1" "$2" | tr -d '\r'
}

emit_fixture() { # <feature-slug>
  mkdir -p "$WORK/specs/$1"
  printf '## T-001 only task\nStatus: Done\n' > "$WORK/specs/$1/tasks.md"
}

run_emit() { # <feature-slug> <extra-args...> -- sets RUN_EXIT, RUN_OUT, RUN_STDERR
  feature_slug="$1"; shift
  emit_fixture "$feature_slug"
  # Several scenarios below deliberately provoke a non-zero exit (rejection
  # paths); `set -e` would otherwise abort the whole suite on a standalone
  # `VAR=$(...)` assignment whose command substitution fails, so errexit is
  # suspended for exactly this one capture and restored immediately after.
  set +e
  RUN_STDERR="$(cd "$WORK" && sh "$SCRIPT" "$feature_slug" --track lite "$@" 2>&1 1>/dev/null)"
  RUN_EXIT=$?
  set -e
  RUN_OUT="$(find "$WORK/reports/runs" -name "RUN-*-${feature_slug}.json" | head -n 1)"
}

assert_run_out_eq() { # <jq-filter> <expected> <label> -- asserts against $RUN_OUT
  got="$(jqr "$1" "$RUN_OUT")"
  if [ "$got" = "$2" ]; then ok "$3 ($1 = $2)"; else fail "$3: $1 = $got, expected $2"; fi
}

# --- AC-021 (TEST-021): schema bump + additive fields, v1 fields unchanged -
run_emit feat-e021 --effort-main high --effort-control-main flag --effort-applied-main high
if [ "$RUN_EXIT" -eq 0 ] && [ -n "$RUN_OUT" ]; then
  assert_run_out_eq '.schema' 'sdd-run-record/v2' 'AC-021: schema bumps to v2 when any --effort-* flag supplied'
  assert_run_out_eq '.feature' 'feat-e021' 'AC-021: v1 field feature unchanged in v2 shape'
  assert_run_out_eq '.track' 'lite' 'AC-021: v1 field track unchanged in v2 shape'
  assert_run_out_eq '.model_ids.main' 'unknown' 'AC-021: v1 field model_ids.main unchanged in v2 shape'
  assert_run_out_eq '(.effort.main | keys | sort) == (["effort_applied","effort_degraded_reason","effort_requested"] | sort)' 'true' 'AC-021: effort.main has exactly the three subfields'
  assert_run_out_eq '(.effort.reviewers | keys | sort) == (["effort_applied","effort_degraded_reason","effort_requested"] | sort)' 'true' 'AC-021: effort.reviewers has exactly the three subfields'
  assert_run_out_eq '.metrics.tasks.total' '1' 'AC-021: v1 metrics object unchanged in v2 shape'
else
  fail "AC-021 setup: emit-run-record did not produce a run record (exit=$RUN_EXIT, stderr=$RUN_STDERR)"
fi

# --- AC-022 (TEST-022): effort_requested recorded whenever its flag is
#     supplied, regardless of host/outcome (both a confirmed-applied case
#     and a degraded case must both carry effort_requested). -----------------
run_emit feat-e022 --effort-main high --effort-control-main flag --effort-applied-main high
[ "$RUN_EXIT" -eq 0 ] && [ -n "$RUN_OUT" ] && [ "$(jqr '.effort.main.effort_requested' "$RUN_OUT")" = "high" ] \
  && ok "AC-022: effort_requested recorded on confirmed-applied outcome" \
  || fail "AC-022: effort_requested missing on confirmed-applied outcome"

run_emit feat-e022b --effort-main high --effort-control-main frontmatter
[ "$RUN_EXIT" -eq 0 ] && [ -n "$RUN_OUT" ] && [ "$(jqr '.effort.main.effort_requested' "$RUN_OUT")" = "high" ] \
  && ok "AC-022: effort_requested recorded on degraded (frontmatter) outcome" \
  || fail "AC-022: effort_requested missing on degraded (frontmatter) outcome"

# --- AC-023 (TEST-023): effort_applied non-null iff effort_control resolved
#     to flag AND application was confirmed; null in every other case. ------
run_emit feat-e023 --effort-main high --effort-control-main flag --effort-applied-main high
[ "$RUN_EXIT" -eq 0 ] && [ "$(jqr '.effort.main.effort_applied' "$RUN_OUT")" = "high" ] \
  && ok "AC-023 positive: effort_applied carries the confirmed value under flag control" \
  || fail "AC-023 positive: effort_applied did not carry the confirmed value"

for control in frontmatter none; do
  run_emit "feat-e023-$control" --effort-main high --effort-control-main "$control"
  [ "$RUN_EXIT" -eq 0 ] && [ "$(jqr '.effort.main.effort_applied' "$RUN_OUT")" = "null" ] \
    && ok "AC-023 negative: effort_applied is null under $control control" \
    || fail "AC-023 negative: effort_applied is not null under $control control"
done

run_emit feat-e023-declined --effort-main high --effort-control-main flag --effort-applied-main none
[ "$RUN_EXIT" -eq 0 ] && [ "$(jqr '.effort.main.effort_applied' "$RUN_OUT")" = "null" ] \
  && ok "AC-023 negative: effort_applied is null when flag control declines application (none sentinel)" \
  || fail "AC-023 negative: effort_applied is not null on explicit decline"

# Structural enforcement (security-spec.md B4): a caller cannot report a
# confirmed-applied value unless the paired control resolved to flag.
run_emit feat-e023-reject --effort-main high --effort-control-main frontmatter --effort-applied-main high
case "$RUN_EXIT" in
  0) fail "AC-023 structural: --effort-applied-main with non-flag control was accepted instead of rejected" ;;
  *) case "$RUN_STDERR" in
       *'requires the paired --effort-control-* to resolve to "flag"'*)
         ok "AC-023 structural: --effort-applied-main with non-flag control is rejected fail-closed" ;;
       *) fail "AC-023 structural: rejection diagnostic missing/unexpected: $RUN_STDERR" ;;
     esac ;;
esac

# --- AC-024 (TEST-024): effort_degraded_reason populated iff effort_applied
#     is null AND its role slot's --effort-* flag was supplied (both
#     directions locked; the vacuous case -- flag not supplied at all --
#     must NOT populate a reason). -------------------------------------------
run_emit feat-e024-applied --effort-main high --effort-control-main flag --effort-applied-main high
[ "$(jqr '.effort.main.effort_degraded_reason' "$RUN_OUT")" = "null" ] \
  && ok "AC-024 direction 1: effort_degraded_reason is null when effort_applied carries a value" \
  || fail "AC-024 direction 1: effort_degraded_reason unexpectedly populated alongside a real effort_applied"

run_emit feat-e024-degraded --effort-main high --effort-control-main frontmatter
reason="$(jqr '.effort.main.effort_degraded_reason' "$RUN_OUT")"
if [ "$reason" != "null" ] && [ -n "$reason" ]; then
  ok "AC-024 direction 2: effort_degraded_reason is non-empty when effort_applied is null and a flag was supplied ($reason)"
else
  fail "AC-024 direction 2: effort_degraded_reason is empty/null despite a supplied --effort-main flag"
fi

run_emit feat-e024-vacuous --effort-control-main flag
[ "$(jqr '.effort.main.effort_requested' "$RUN_OUT")" = "null" ] && [ "$(jqr '.effort.main.effort_degraded_reason' "$RUN_OUT")" = "null" ] \
  && ok "AC-024 vacuity: no reason recorded when --effort-main itself was never supplied for that slot" \
  || fail "AC-024 vacuity: a reason was recorded despite --effort-main never being supplied"

# --- AC-051 (TEST-051): host-independent degradation lock -- emit-run-record
#     has no host concept at all; a "Codex host selecting a non-flag-control
#     model" scenario and a "Claude Code" scenario both resolve through the
#     identical --effort-control-* value, proving the null+reason shape is
#     keyed on the resolved effort_control value, never on host identity. --
run_emit feat-e051-claude --effort-main high --effort-control-main frontmatter
claude_shape="$(jqr '.effort.main | {effort_applied, effort_degraded_reason}' "$RUN_OUT")"
run_emit feat-e051-codex --effort-main high --effort-control-main frontmatter
codex_shape="$(jqr '.effort.main | {effort_applied, effort_degraded_reason}' "$RUN_OUT")"
[ "$claude_shape" = "$codex_shape" ] && [ "$(jqr '.effort.main.effort_applied' "$RUN_OUT")" = "null" ] \
  && ok "AC-051: a Codex-host scenario with a non-flag effort_control degrades identically in shape to Claude Code ($codex_shape)" \
  || fail "AC-051: Codex-host non-flag-control shape ($codex_shape) diverged from Claude Code shape ($claude_shape)"

run_emit feat-e051-codex-none --effort-main high --effort-control-main none
[ "$(jqr '.effort.main.effort_applied' "$RUN_OUT")" = "null" ] && [ "$(jqr '.effort.main.effort_degraded_reason' "$RUN_OUT")" = "effort-control-none" ] \
  && ok "AC-051: Codex-host model with effort_control none also degrades (reason keyed on the resolved control value)" \
  || fail "AC-051: Codex-host model with effort_control none did not degrade as expected"

# PowerShell case-sensitivity twin discipline (2-layer): the .sh side's
# `case` pattern match is inherently case-sensitive (no glob wildcards);
# this asserts that discipline explicitly with a mis-cased negative fixture,
# mirroring the .ps1 twin's ordinal HashSet + -ceq layers.
run_emit feat-e-miscased --effort-control-main Flag
case "$RUN_EXIT" in
  0) fail "case-sensitivity: --effort-control-main Flag (mis-cased) was accepted instead of rejected" ;;
  *) case "$RUN_STDERR" in
       *'must be one of flag|frontmatter|none'*) ok "case-sensitivity: mis-cased --effort-control-main value is rejected fail-closed" ;;
       *) fail "case-sensitivity: unexpected diagnostic for mis-cased value: $RUN_STDERR" ;;
     esac ;;
esac

# --- AC-025 (TEST-025): backward compatibility -- the no-flags code path
#     stays byte-identical to every pre-feature invocation (v1 shape, no
#     "effort" key), and an EXISTING, already-committed pre-feature v1
#     record (never rewritten by this task) still carries schema v1. -------
run_emit feat-e025
assert_run_out_eq '.schema' 'sdd-run-record/v1' 'AC-025: no --effort-* flag supplied emits v1 schema, unchanged'
assert_run_out_eq 'has("effort")' 'false' 'AC-025: v1 shape has no effort key at all'

PRE_FEATURE_V1_RECORD="$REPO_ROOT/reports/runs/RUN-20260705T023011Z-sdd-forge-mcp.json"
if [ -f "$PRE_FEATURE_V1_RECORD" ]; then
  [ "$(jqr '.schema' "$PRE_FEATURE_V1_RECORD")" = "sdd-run-record/v1" ] && [ "$(jqr 'has("effort")' "$PRE_FEATURE_V1_RECORD")" = "false" ] \
    && ok "AC-025: a real, already-committed pre-feature v1 record still validates as schema v1 (untouched by this task)" \
    || fail "AC-025: the pre-feature v1 record fixture no longer reads as schema v1"
else
  fail "AC-025 setup: expected pre-feature v1 record fixture not found: $PRE_FEATURE_V1_RECORD"
fi

# --- AC-026 (TEST-026): document conformance -- report template, validator,
#     and quality-gate SKILL.md all carry the Model/Effort requirement. ----
TEMPLATE="$REPO_ROOT/plugins/sdd-implementation/templates/implementation-report.template.md"
VALIDATOR="$REPO_ROOT/plugins/sdd-implementation/scripts/validate-implementation-report.sh"
GATE_SKILL="$REPO_ROOT/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"

grep -Fq -e '- Model: {{model}}' "$TEMPLATE" && grep -Fq -e '- Effort: {{effort}}' "$TEMPLATE" \
  && ok "AC-026: implementation-report.template.md carries the Model/Effort lines" \
  || fail "AC-026: implementation-report.template.md is missing the Model/Effort lines"

grep -Fq 'top_level_label in ("Model", "Effort")' "$VALIDATOR" \
  && ok "AC-026: validate-implementation-report.sh checks the Model/Effort lines" \
  || fail "AC-026: validate-implementation-report.sh does not check the Model/Effort lines"

grep -Fq '`- Model:` / `- Effort:`' "$GATE_SKILL" \
  && ok "AC-026: quality-gate SKILL.md documents the Model/Effort Process instruction" \
  || fail "AC-026: quality-gate SKILL.md is missing the Model/Effort Process instruction"

VALIDATOR_FIXTURE_DIR="$WORK/validator-fixtures"
mkdir -p "$VALIDATOR_FIXTURE_DIR"
cat > "$VALIDATOR_FIXTURE_DIR/valid.md" <<'FIXEOF'
# Implementation Report: T-999

- Model: anthropic/opus
- Effort: high

Report Schema: implementation-report/v2

## Output Paths And Hashes

- **Path**: `plugins/example.md`; **SHA-256**: `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`

## Test Evidence

- **Test Command**: `bash tests/example.tests.sh`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/example/verification/T-999/green.log`

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: run-999
- **Session ID**: session-999
- **Agent Instance ID**: agent-999
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Unresolved Items

None.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality review
- **Unresolved Items**: None
FIXEOF

bash "$VALIDATOR" "$VALIDATOR_FIXTURE_DIR/valid.md" >/dev/null 2>&1 \
  && ok "AC-026: validator accepts a report carrying well-formed Model/Effort lines" \
  || fail "AC-026: validator rejected a report with well-formed Model/Effort lines"

sed '/^- Model: anthropic\/opus$/d' "$VALIDATOR_FIXTURE_DIR/valid.md" > "$VALIDATOR_FIXTURE_DIR/missing-model.md"
missing_model_output="$(bash "$VALIDATOR" "$VALIDATOR_FIXTURE_DIR/missing-model.md" 2>&1)" && \
  fail "AC-026: validator accepted a report missing the Model line" || \
  case "$missing_model_output" in
    *'missing or invalid Model'*) ok "AC-026: validator rejects a report missing the Model line" ;;
    *) fail "AC-026: unexpected diagnostic for missing Model line: $missing_model_output" ;;
  esac

sed '/^- Effort: high$/d' "$VALIDATOR_FIXTURE_DIR/valid.md" > "$VALIDATOR_FIXTURE_DIR/missing-effort.md"
missing_effort_output="$(bash "$VALIDATOR" "$VALIDATOR_FIXTURE_DIR/missing-effort.md" 2>&1)" && \
  fail "AC-026: validator accepted a report missing the Effort line" || \
  case "$missing_effort_output" in
    *'missing or invalid Effort'*) ok "AC-026: validator rejects a report missing the Effort line" ;;
    *) fail "AC-026: unexpected diagnostic for missing Effort line: $missing_effort_output" ;;
  esac

printf '\nemit-run-record-feature-scope.tests.sh: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
