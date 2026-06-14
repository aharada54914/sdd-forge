#!/usr/bin/env bash
# apply-branch-protection.tests.sh — regression tests for scripts/apply-branch-protection.sh
#
# Mirrors install.tests.sh / gates.tests.sh style: ok/fail counters, exits 1 on
# any failure. Runs on Linux and macOS without pwsh. Uses a fake `gh` shim so no
# network or real GitHub access is needed.
#
# Primary regression guarded here: when the rulesets LIST API returns an error
# OBJECT (e.g. {"message":"Upgrade ...","status":"403"} on a Free-tier private
# repo) the script must NOT treat that payload as an existing ruleset id and must
# NOT attempt a PUT with a malformed URL. It must fall through to create/POST and
# then the MANUAL FALLBACK steps, exiting 0 (fail-soft).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/apply-branch-protection.sh"
RULESET_SRC="${REPO_ROOT}/.github/rulesets/main.json"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Fixture: a workdir holding .github/rulesets/main.json (the script reads it via
# a CWD-relative path) plus a fake `gh` shim whose behavior is driven by env.
# ---------------------------------------------------------------------------
BIN_DIR="${WORK}/bin"
RUN_DIR="${WORK}/repo"
mkdir -p "$BIN_DIR" "${RUN_DIR}/.github/rulesets"
cp "$RULESET_SRC" "${RUN_DIR}/.github/rulesets/main.json"

# Fake gh: logs every invocation, then answers based on env-provided fixtures.
#   FAKE_GH_LOG         — file to append "gh <args>" lines to
#   FAKE_GH_LIST_BODY   — file whose contents are emitted for the GET list call
#   FAKE_GH_LIST_EXIT   — exit code for the GET list call (default 0)
#   FAKE_GH_WRITE_EXIT  — exit code for POST/PUT calls (default 0)
# A write is detected by a POST/PUT token in the args (gh api -X POST|PUT).
cat > "${BIN_DIR}/gh" <<'SHIM'
#!/bin/sh
echo "gh $*" >> "${FAKE_GH_LOG}"
is_write=0
for a in "$@"; do
  case "$a" in
    POST|PUT) is_write=1 ;;
  esac
done
if [ "$is_write" = 1 ]; then
  exit "${FAKE_GH_WRITE_EXIT:-0}"
fi
# GET list call: emit the fixture body (if any), then exit with the list code.
if [ -n "${FAKE_GH_LIST_BODY:-}" ] && [ -f "${FAKE_GH_LIST_BODY}" ]; then
  cat "${FAKE_GH_LIST_BODY}"
fi
exit "${FAKE_GH_LIST_EXIT:-0}"
SHIM
chmod +x "${BIN_DIR}/gh"

# Run the script under the fixture environment. Captures combined stdout+stderr
# in RUN_OUT and the exit code in RUN_RC. Resets the gh invocation log each run.
#   args: <list_body_file> <list_exit> <write_exit>
GH_LOG="${WORK}/gh.log"
run_script() {
  : > "$GH_LOG"
  set +e
  RUN_OUT=$(
    cd "$RUN_DIR" \
      && PATH="${BIN_DIR}:${PATH}" \
         GITHUB_REPOSITORY="aharada54914/sdd-forge" \
         FAKE_GH_LOG="$GH_LOG" \
         FAKE_GH_LIST_BODY="${1:-}" \
         FAKE_GH_LIST_EXIT="${2:-0}" \
         FAKE_GH_WRITE_EXIT="${3:-0}" \
         sh "$SCRIPT" 2>&1
  )
  RUN_RC=$?
  set -e
}

# ===========================================================================
# Case 1 (regression): LIST returns a 403 error OBJECT, gh exits non-zero.
#   - Must NOT issue any PUT (no malformed-URL update).
#   - POST is also blocked (403) -> MANUAL FALLBACK printed, exit 0.
# ===========================================================================
LIST_403="${WORK}/list-403.json"
cat > "$LIST_403" <<'JSON'
{"message":"Upgrade to GitHub Pro or make this repository public to enable this feature.","documentation_url":"https://docs.github.com/","status":"403"}
JSON

run_script "$LIST_403" 1 1
if [ "$RUN_RC" -eq 0 ]; then
  ok "403-list: exits 0 (fail-soft)"
else
  fail "403-list: expected exit 0, got $RUN_RC"
fi
if ! grep -q "PUT" "$GH_LOG"; then
  ok "403-list: no PUT attempted (regression guard)"
else
  fail "403-list: a PUT was attempted (malformed-URL regression). gh log: $(cat "$GH_LOG")"
fi
case "$RUN_OUT" in
  *"%7B"*|*"unsupported protocol"*|*"rulesets/{"*)
    fail "403-list: output shows a malformed ruleset URL: $RUN_OUT" ;;
  *)
    ok "403-list: no malformed ruleset URL in output" ;;
esac
case "$RUN_OUT" in
  *"MANUAL FALLBACK STEPS"*) ok "403-list: manual fallback steps printed" ;;
  *) fail "403-list: manual fallback steps missing. output: $RUN_OUT" ;;
esac

# ===========================================================================
# Case 2: LIST returns an empty JSON ARRAY -> create path (POST) succeeds.
# ===========================================================================
LIST_EMPTY="${WORK}/list-empty.json"
printf '[]\n' > "$LIST_EMPTY"

run_script "$LIST_EMPTY" 0 0
if [ "$RUN_RC" -eq 0 ]; then
  ok "empty-list: exits 0"
else
  fail "empty-list: expected exit 0, got $RUN_RC"
fi
if grep -q "X POST" "$GH_LOG" && ! grep -q "PUT" "$GH_LOG"; then
  ok "empty-list: POST (create) attempted, no PUT"
else
  fail "empty-list: expected a POST and no PUT. gh log: $(cat "$GH_LOG")"
fi
case "$RUN_OUT" in
  *"Successfully created"*) ok "empty-list: reports created" ;;
  *) fail "empty-list: missing 'Successfully created'. output: $RUN_OUT" ;;
esac

# ===========================================================================
# Case 3: LIST returns an ARRAY containing the named ruleset -> update (PUT).
# ===========================================================================
LIST_MATCH="${WORK}/list-match.json"
cat > "$LIST_MATCH" <<'JSON'
[{"id":12345,"name":"Protect main branch","target":"branch"}]
JSON

run_script "$LIST_MATCH" 0 0
if [ "$RUN_RC" -eq 0 ]; then
  ok "match-list: exits 0"
else
  fail "match-list: expected exit 0, got $RUN_RC"
fi
if grep -q "rulesets/12345" "$GH_LOG" && grep -q "PUT" "$GH_LOG"; then
  ok "match-list: PUT to rulesets/12345 (update)"
else
  fail "match-list: expected PUT to rulesets/12345. gh log: $(cat "$GH_LOG")"
fi
case "$RUN_OUT" in
  *"Found existing ruleset ID 12345"*) ok "match-list: reports found id 12345" ;;
  *) fail "match-list: missing 'Found existing ruleset ID 12345'. output: $RUN_OUT" ;;
esac
case "$RUN_OUT" in
  *"Successfully updated"*) ok "match-list: reports updated" ;;
  *) fail "match-list: missing 'Successfully updated'. output: $RUN_OUT" ;;
esac

# ===========================================================================
# Case 4: LIST succeeds (exit 0) but body is an error OBJECT (defensive: some
# gh/proxy paths may return 200 with a non-array payload). Must not mine an id.
# ===========================================================================
run_script "$LIST_403" 0 1
if grep -q "PUT" "$GH_LOG"; then
  fail "obj-body-200: a PUT was attempted from an error object. gh log: $(cat "$GH_LOG")"
else
  ok "obj-body-200: no PUT from non-array body"
fi
case "$RUN_OUT" in
  *"MANUAL FALLBACK STEPS"*) ok "obj-body-200: falls through to manual fallback" ;;
  *) fail "obj-body-200: expected manual fallback. output: $RUN_OUT" ;;
esac

# ---------------------------------------------------------------------------
echo ""
echo "apply-branch-protection.tests.sh: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
