#!/usr/bin/env bash
# TEST-010 / TEST-011 / TEST-014 (REQ-005; AC-010, AC-011, AC-014;
# security-spec.md B2): the weekly self-improvement workflow minimizes its
# GitHub permissions and runs a deterministic post-session enforcement-chain
# guard between its automated session and the pull requests it creates.
#
#   TARGET_YML  workflow file under test   (default: live .github workflow)
#   GUARD_SH    guard script under test    (default: live .github script)
#
# Run with defaults to exercise the current live files (RED); run against the
# staging outputs to exercise the corrected files (GREEN):
#   TARGET_YML=specs/epic-136-phase1-guards/staging/self-improvement.yml \
#   GUARD_SH=specs/epic-136-phase1-guards/staging/self-improvement-pr-guard.sh \
#   bash tests/self-improvement-guard.tests.sh
#
# `set -e` is intentionally omitted so every assertion runs in one pass and RED
# evidence records all failures at once.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

TARGET_YML="${TARGET_YML:-.github/workflows/self-improvement.yml}"
GUARD_SH="${GUARD_SH:-.github/scripts/self-improvement-pr-guard.sh}"
case "$TARGET_YML" in /*) ;; *) TARGET_YML="$ROOT/$TARGET_YML" ;; esac
case "$GUARD_SH" in /*) ;; *) GUARD_SH="$ROOT/$GUARD_SH" ;; esac

PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok()   { printf 'ok: %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }

printf 'TARGET_YML=%s\n' "$TARGET_YML"
printf 'GUARD_SH=%s\n\n' "$GUARD_SH"

GUARD_OUT=""
GUARD_CODE=0
run_guard() {
  # $1 = changed-paths file (may be absent). Sets GUARD_OUT and GUARD_CODE.
  GUARD_OUT="$(bash "$GUARD_SH" "$1" 2>&1)"
  GUARD_CODE=$?
}

# ---- (a) TEST-010: permissions block -- id-token: write removed (AC-010) ----
# Verdict: the pinned anthropics/claude-code-action@558b1d6 (v1.0.165) only
# needs id-token: write for anthropic_federation_rule_id workload-identity
# federation. This workflow authenticates with claude_code_oauth_token and
# sets no federation inputs, so no OIDC exchange happens: id-token: write must
# be absent from the permissions block.
if [ -f "$TARGET_YML" ] && grep -Eq '^[[:space:]]*id-token:[[:space:]]*write' "$TARGET_YML"; then
  fail "TEST-010: id-token: write is present but unused (claude_code_oauth_token auth, no federation) -- AC-010"
else
  ok "TEST-010: id-token: write absent from permissions (OIDC not used by the pinned action) -- AC-010"
fi

# Permissions the run demonstrably uses must remain present.
for perm in contents pull-requests issues; do
  if [ -f "$TARGET_YML" ] && grep -Eq "^[[:space:]]*${perm}:[[:space:]]*write" "$TARGET_YML"; then
    ok "TEST-010: retains used permission '${perm}: write'"
  else
    fail "TEST-010: missing used permission '${perm}: write'"
  fi
done

# ---- (b) TEST-011: the workflow invokes the deterministic guard script ------
if [ -f "$TARGET_YML" ] && grep -Fq 'self-improvement-pr-guard.sh' "$TARGET_YML"; then
  ok "TEST-011: workflow runs self-improvement-pr-guard.sh after the session -- AC-011"
else
  fail "TEST-011: workflow has no self-improvement-pr-guard.sh guard step -- AC-011"
fi

# ---- (c) TEST-011: a violating diff fails (exit 1) and lists every path -----
viol="$WORK/violating.txt"
printf '%s\n' \
  'reports/quality-gate/T-005.md' \
  'plugins/sdd-quality-loop/hooks/claude-hooks.json' \
  'docs/getting-started.md' \
  >"$viol"
run_guard "$viol"
if [ "$GUARD_CODE" = "1" ]; then
  ok "TEST-011: violating diff fails the guard (exit 1) -- AC-011"
else
  fail "TEST-011: violating diff should exit 1, got $GUARD_CODE -- AC-011"
fi
if printf '%s' "$GUARD_OUT" | grep -Fq 'reports/quality-gate/T-005.md' \
  && printf '%s' "$GUARD_OUT" | grep -Fq 'plugins/sdd-quality-loop/hooks/claude-hooks.json'; then
  ok "TEST-011: guard lists both violating paths"
else
  fail "TEST-011: guard did not list both violating paths (output: $GUARD_OUT)"
fi

# ---- (d) TEST-011: a compliant diff passes (exit 0) ------------------------
comp="$WORK/compliant.txt"
printf '%s\n' \
  'docs/guides/getting-started.md' \
  'README.md' \
  'plugins/sdd-forge/README.md' \
  >"$comp"
run_guard "$comp"
if [ "$GUARD_CODE" = "0" ]; then
  ok "TEST-011: compliant diff passes the guard (exit 0) -- AC-011"
else
  fail "TEST-011: compliant diff should exit 0, got $GUARD_CODE (output: $GUARD_OUT) -- AC-011"
fi

# ---- (e) TEST-014: empty / absent changed-paths file -> vacuous pass -------
empty="$WORK/empty.txt"
: >"$empty"
run_guard "$empty"
if [ "$GUARD_CODE" = "0" ]; then
  ok "TEST-014: empty changed-paths file passes vacuously (exit 0) -- AC-014"
else
  fail "TEST-014: empty file should exit 0, got $GUARD_CODE (output: $GUARD_OUT) -- AC-014"
fi
absent="$WORK/does-not-exist.txt"
rm -f "$absent"
run_guard "$absent"
if [ "$GUARD_CODE" = "0" ]; then
  ok "TEST-014: absent changed-paths file passes vacuously (exit 0) -- AC-014"
else
  fail "TEST-014: absent file should exit 0, got $GUARD_CODE (output: $GUARD_OUT) -- AC-014"
fi

printf '\nTEST-010/011/014 results: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
