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
TARGET_PROMPT="${TARGET_PROMPT:-.github/self-improvement-prompt.md}"
GUARD_SH="${GUARD_SH:-.github/scripts/self-improvement-pr-guard.sh}"
case "$TARGET_YML" in /*) ;; *) TARGET_YML="$ROOT/$TARGET_YML" ;; esac
case "$TARGET_PROMPT" in /*) ;; *) TARGET_PROMPT="$ROOT/$TARGET_PROMPT" ;; esac
case "$GUARD_SH" in /*) ;; *) GUARD_SH="$ROOT/$GUARD_SH" ;; esac

PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok()   { printf 'ok: %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }

printf 'TARGET_YML=%s\n' "$TARGET_YML"
printf 'TARGET_PROMPT=%s\n' "$TARGET_PROMPT"
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

# ---- (f) ISSUE-478-RECOVERY: defer closure until full workflow success -----
if [ -f "$TARGET_PROMPT" ] \
  && ! grep -Fq '今この手順が動いていること自体がワークフロー復旧の証拠' "$TARGET_PROMPT" \
  && grep -Fq 'ワークフロー全体が成功した後' "$TARGET_PROMPT"; then
  ok "ISSUE-478-RECOVERY: prompt defers issue closing until full workflow success"
else
  fail "ISSUE-478-RECOVERY: prompt must defer failure-issue closing until full workflow success"
fi

if [ -f "$TARGET_YML" ] \
  && awk '
      /^  finalize-recovery:$/ { job=1 }
      job && /^    needs: improve$/ { needs=1 }
      job && /^    if:.*success\(\).*needs\.improve\.result == .success./ { success=1 }
      job && /^      - name: Close recovered workflow failure issue$/ { step=1; next }
      step && /^        shell: bash$/ { shell=1 }
      step && /^        run: \|$/ { run=1 }
      END { exit !(needs && success && shell && run) }
    ' "$TARGET_YML"; then
  ok "ISSUE-478-RECOVERY: finalizer depends on successful improve job and uses bash"
else
  fail "ISSUE-478-RECOVERY: finalizer must run only after improve succeeds"
fi

# Execute the exact close-step body extracted from the workflow against a fake
# gh CLI. This tests success and unrelated issues without contacting GitHub.
close_script="$WORK/close-recovered-issue.sh"
awk '
  /^  finalize-recovery:$/ { job=1 }
  job && /^      - name: Close recovered workflow failure issue$/ { step=1; next }
  step && /^        run: \|$/ { body=1; next }
  body && /^          / { sub(/^          /, ""); print; next }
  body && /^[[:space:]]*$/ { print; next }
  body { exit }
' "$TARGET_YML" > "$close_script"
if [ -s "$close_script" ]; then
  ok "ISSUE-478-RECOVERY: extracted close-step command for isolated execution"
else
  fail "ISSUE-478-RECOVERY: could not extract workflow close-step command"
fi

mock_bin="$WORK/mock-bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -eu
case "$1 $2" in
  "issue list") [ "${MOCK_LIST_FAIL:-0}" = 0 ] || exit 9; printf '%s\n' "${MOCK_ISSUES:-[]}" ;;
  "issue comment") printf 'comment %s\n' "$*" >> "$MOCK_GH_LOG"; [ "${MOCK_COMMENT_FAIL:-0}" = 0 ] ;;
  "issue close") printf 'close %s\n' "$*" >> "$MOCK_GH_LOG"; [ "${MOCK_CLOSE_FAIL:-0}" = 0 ] ;;
  *) printf 'unexpected gh invocation: %s\n' "$*" >&2; exit 2 ;;
esac
MOCK_GH
chmod +x "$mock_bin/gh"

run_close_step() {
  : > "$WORK/gh.log"
  PATH="$mock_bin:$PATH" MOCK_GH_LOG="$WORK/gh.log" \
    GITHUB_SERVER_URL="https://github.example" GITHUB_REPOSITORY="owner/repo" \
    GITHUB_RUN_ID=987654 MOCK_ISSUES="$1" \
    MOCK_LIST_FAIL="${2:-0}" MOCK_COMMENT_FAIL="${3:-0}" \
    bash -e -o pipefail "$close_script" >"$WORK/close.out" 2>&1
  CLOSE_RC=$?
}

run_close_step '[{"number":421,"title":"Weekly self-improvement run failed (2026-09-20)","body":"- 実行日時: 2026-09-20T00:00:00Z\n- 推定原因: failure\n- 実行ログ: https://github.example/owner/repo/actions/runs/12345"}]'
if [ "$CLOSE_RC" -eq 0 ] && grep -Fq 'issue comment 421' "$WORK/gh.log" \
  && grep -Fq 'https://github.example/owner/repo/actions/runs/987654' "$WORK/gh.log" \
  && grep -Fq 'issue close 421' "$WORK/gh.log"; then
  ok "ISSUE-478-RECOVERY: success comments current run URL and closes exact reporter issue"
else
  fail "ISSUE-478-RECOVERY: success did not close eligible reporter issue with current run URL"
fi

run_close_step '[{"number":422,"title":"Unrelated CI failure","body":"- 実行ログ: https://github.example/owner/repo/actions/runs/12345"},{"number":423,"title":"Weekly self-improvement run failed (2026-09-20)","body":"no repository Actions run link"},{"number":424,"title":"Weekly self-improvement run failed (not-a-date)","body":"- 実行ログ: https://github.example/owner/repo/actions/runs/12345"},{"number":425,"title":"Weekly self-improvement run failed (2026-09-20)","body":"- 実行ログ: https://elsewhere.example/owner/repo/actions/runs/12345"},{"number":426,"title":"Weekly self-improvement run failed (2026-09-20)","body":"- 実行ログ: https://github.example/owner/repo/actions/runs/987654"}]'
if [ "$CLOSE_RC" -eq 0 ] && [ ! -s "$WORK/gh.log" ]; then
  ok "ISSUE-478-RECOVERY: unrelated or non-reporter issue is left open"
else
  fail "ISSUE-478-RECOVERY: unrelated or non-reporter issue was modified"
fi

run_close_step '[{"number":421,"title":"Weekly self-improvement run failed (2026-09-20)","body":"- 実行日時: date\n- 推定原因: failure\n- 実行ログ: https://github.example/owner/repo/actions/runs/12345"}]' 1 0
if [ "$CLOSE_RC" -ne 0 ] && ! grep -Fq 'issue close' "$WORK/gh.log"; then
  ok "ISSUE-478-RECOVERY: issue-list failure is nonzero and cannot close issue"
else
  fail "ISSUE-478-RECOVERY: issue-list failure must prevent closure"
fi

run_close_step '[{"number":421,"title":"Weekly self-improvement run failed (2026-09-20)","body":"- 実行日時: date\n- 推定原因: failure\n- 実行ログ: https://github.example/owner/repo/actions/runs/12345"}]' 0 1
if [ "$CLOSE_RC" -ne 0 ] && ! grep -Fq 'issue close' "$WORK/gh.log"; then
  ok "ISSUE-478-RECOVERY: comment failure is nonzero and cannot close issue"
else
  fail "ISSUE-478-RECOVERY: comment failure must prevent closure"
fi

printf '\nTEST-010/011/014 + ISSUE-478-RECOVERY results: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
