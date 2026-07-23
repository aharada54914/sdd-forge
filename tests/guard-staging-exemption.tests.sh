#!/usr/bin/env bash
# guard-staging-exemption.tests.sh — R-10 regression tests for two guard
# false-positive classes discovered while implementing epic-189-a1 T-001:
#
#   (bug 1) specs/<feature>/human-copy/ staging candidates were denied by the
#           bare path-suffix match exactly like the live enforcement-chain
#           files they stage, making the repository's own sanctioned staging
#           convention unusable for protected-suffix candidates.
#   (bug 2) the Bash-command pre-filter matched protected paths as raw
#           substrings of the WHOLE command text, so a git commit whose
#           message merely mentions a protected filename in prose was denied
#           even though the command writes no protected path.
#
# The fixes live in sdd-hook-guard.{py,js,ps1}. Those files are themselves
# R-10-protected, so the fix cannot be self-applied by an agent; it lands via
# human application (patch recorded in
# reports/implementation/epic-189-a1-project-context/HUMAN-APPLY-STEPS.md).
#
# Structure:
#   - INVARIANT block: always runs. Live protected paths must stay denied,
#     before and after the fix. A regression here is a security failure.
#   - FIX block: asserts the corrected behavior. Until the fix is applied to
#     the live guard, this block SKIPs (suite stays green pre-apply) after
#     verifying the probe result is the known-defect signature.
#
# GUARD_SCRIPTS_DIR overrides the guard directory under test — used to verify
# a patched copy BEFORE human application (see HUMAN-APPLY-STEPS.md).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${GUARD_SCRIPTS_DIR:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts}"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

RUNTIMES="py"
if command -v node >/dev/null 2>&1; then RUNTIMES="$RUNTIMES js"; fi
if command -v pwsh >/dev/null 2>&1; then RUNTIMES="$RUNTIMES ps1"; fi

run_guard() {
    # $1 = runtime (py|js|ps1), $2 = payload JSON; echoes the exit code.
    local code=0
    case "$1" in
        py)
            printf '%s' "$2" | CLAUDE_PROJECT_DIR="$WORK" \
                python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" --emit exit >/dev/null 2>&1 || code=$?
            ;;
        js)
            printf '%s' "$2" | CLAUDE_PROJECT_DIR="$WORK" \
                node "${SCRIPTS_DIR}/sdd-hook-guard.js" --emit exit >/dev/null 2>&1 || code=$?
            ;;
        ps1)
            printf '%s' "$2" | CLAUDE_PROJECT_DIR="$WORK" \
                pwsh -NoProfile -File "${SCRIPTS_DIR}/sdd-hook-guard.ps1" --emit exit >/dev/null 2>&1 || code=$?
            ;;
    esac
    echo "$code"
}

expect_code() {
    # $1 = scenario name, $2 = expected exit code, $3 = payload JSON
    local rt got
    for rt in $RUNTIMES; do
        got="$(run_guard "$rt" "$3")"
        if [ "$got" = "$2" ]; then
            ok "[$rt] $1 (exit $got)"
        else
            fail "[$rt] $1: exit $got (expected $2)"
        fi
    done
}

# --- Payloads -------------------------------------------------------------
# Protected-path literals below are payload DATA passed to the guard on
# stdin; this test file itself is not a protected file.

STAGING_TESTYML='specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml'
LIVE_TESTYML='.github/workflows/test.yml'
LIVE_GUARD_PY='plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
STAGING_GUARD_PY="specs/guard-fix/human-copy/${LIVE_GUARD_PY}"
PHASE2_PUBLISHER='specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
TRAVERSAL='specs/x/human-copy/../../../.github/workflows/test.yml'

write_payload() {
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$1"
}
bash_payload() {
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"
}

# Bug-2 reproduction shapes (verbatim class of the live incident): a commit
# whose MESSAGE mentions a protected path in prose, plus a write-verb word
# and unmodeled characters that made the old analysis fail closed.
HEREDOC_COMMIT_CMD="git commit -F - <<'MSG'\ndocs: record staging blocker\n\nThe guard denies cp into ${STAGING_TESTYML} (R-10).\nMSG"
BACKTICK_COMMIT_CMD="git commit -m 'docs: note that cp toward \`${LIVE_TESTYML}\` is denied'"

# --- INVARIANT block: live enforcement chain stays denied ------------------

expect_code "invariant: Write live workflow file denied" 2 "$(write_payload "$LIVE_TESTYML")"
expect_code "invariant: Write live guard script denied" 2 "$(write_payload "$LIVE_GUARD_PY")"
expect_code "invariant: Write registered human-copy publisher denied" 2 "$(write_payload "$PHASE2_PUBLISHER")"
expect_code "invariant: dot-dot traversal out of human-copy denied" 2 "$(write_payload "$TRAVERSAL")"
expect_code "invariant: bash rm of live guard denied" 2 "$(bash_payload "rm ${LIVE_GUARD_PY}")"
expect_code "invariant: bash redirect into live workflow denied" 2 "$(bash_payload "echo x > ${LIVE_TESTYML}")"

# --- FIX block: staging exemption + token-based pre-filter -----------------
# Probe: does the guard under test already carry the fix?

probe="$(run_guard py "$(write_payload "$STAGING_TESTYML")")"
if [ "$probe" != "0" ]; then
    if [ "$probe" = "2" ]; then
        echo "SKIP: guard under test still denies human-copy staging (known defect signature, exit 2);"
        echo "SKIP: fix-dependent assertions skipped until the human-applied guard patch lands"
        echo "SKIP: (see reports/implementation/epic-189-a1-project-context/HUMAN-APPLY-STEPS.md)."
    else
        fail "fix probe returned unexpected exit $probe (want 0 fixed / 2 known defect)"
    fi
else
    expect_code "fix: Write human-copy staging candidate allowed" 0 "$(write_payload "$STAGING_TESTYML")"
    expect_code "fix: Write human-copy staged guard candidate allowed" 0 "$(write_payload "$STAGING_GUARD_PY")"
    expect_code "fix: bash cp into human-copy staging allowed" 0 "$(bash_payload "cp tests/new-suite.tests.sh ${STAGING_TESTYML}")"
    expect_code "fix: commit message prose mention (heredoc) allowed" 0 "$(bash_payload "$HEREDOC_COMMIT_CMD")"
    expect_code "fix: commit message prose mention (backtick) allowed" 0 "$(bash_payload "$BACKTICK_COMMIT_CMD")"
fi

# --- Result ---------------------------------------------------------------

echo ""
echo "guard-staging-exemption.tests.sh: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
