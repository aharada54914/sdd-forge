#!/usr/bin/env bash
# installer-idempotency.tests.sh — WFI-041 regression suite.
#
# Covers the three behaviours WFI-041 introduced, and the one it deliberately
# preserved:
#
#   1. Registration is idempotent. An external CLI reporting "already
#      registered" / "already exists" is the desired end state, not a failure.
#   2. `claude plugin install` reporting an existing installation triggers an
#      upgrade path, and the version transition is reported.
#   3. A registration failure no longer reverts the install root.
#   4. A *placement*-phase failure still does.
#
# Cases 2 and 4 each carry their own negative control, because both are easy to
# satisfy vacuously: an upgrade check passes on a tool that always updates, and
# a "rollback did not fire" check passes on an installer that never rolls back.
#
# Run from any directory. Uses --source-directory so no network is needed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${REPO_ROOT}/install.sh"
PASS=0
FAIL=0

ok() { echo "ok: $*"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# Source fixture (mirrors install.tests.sh, trimmed to what this suite needs)
# ---------------------------------------------------------------------------
SOURCE_FIXTURE_ROOT="$(mktemp -d)"
SOURCE_FIXTURE="${SOURCE_FIXTURE_ROOT}/source"
trap 'rm -rf "$SOURCE_FIXTURE_ROOT"' EXIT

mkdir -p "$SOURCE_FIXTURE"
git -C "$REPO_ROOT" archive --format=tar HEAD -- ':(exclude)specs' ':(exclude)reports' \
    | tar -xf - -C "$SOURCE_FIXTURE"
git -C "$SOURCE_FIXTURE" init -q
# Commits here can spawn detached background maintenance that races teardown.
git -C "$SOURCE_FIXTURE" config gc.auto 0
git -C "$SOURCE_FIXTURE" config gc.autoDetach false
git -C "$SOURCE_FIXTURE" config maintenance.auto false
# Overlay the working tree's installer so the suite exercises this checkout
# rather than HEAD.
cp -p "${REPO_ROOT}/install.sh" "${SOURCE_FIXTURE}/install.sh"
cp -p "${REPO_ROOT}/install.ps1" "${SOURCE_FIXTURE}/install.ps1"
git -C "$SOURCE_FIXTURE" add -A
git -C "$SOURCE_FIXTURE" -c user.name="Installer Test" \
    -c user.email="installer-test@example.invalid" commit -qm "Fixture baseline"

# Minimal MCP payload. place_mcp_servers copies this during the *placement*
# phase, which is what the placement-failure case injects into.
mkdir -p "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/dist"
printf '%s\n' '#!/usr/bin/env node' 'console.log("stub");' \
    > "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/dist/index.js"
printf '%s\n' '{ "name": "sdd-forge-mcp", "version": "0.1.0", "private": true }' \
    > "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/package.json"

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------
# The messages below are the ones the real CLIs emitted on 2026-08-22 while
# upgrading a developer machine from 1.15.0 to 1.16.0 (WFI-041 "Problem
# Evidence"). They are the contract this suite pins: if a CLI changes its
# wording, the tolerance must be revisited, and this suite is where that shows
# up first.
MSG_MARKETPLACE_EXISTS='Failed to add marketplace: Error: Marketplace "sdd-plugins" already registered'
MSG_MCP_EXISTS='MCP server sdd-forge-mcp already exists in user config'
MSG_PLUGIN_INSTALLED='Plugin is already installed (scope: user)'
# The two CLI families disagree about which outcome an existing plugin is.
# Codex and Copilot report it the way they report an existing marketplace — as
# a non-zero error — which is why the plugin-add loops need the same tolerance
# as the marketplace-add calls. The real 2026-08-22 upgrade never reached these
# calls (marketplace-add failed first), so this half of the contract is
# inferred from the marketplace behaviour rather than observed.
# Deliberately does not name a plugin: the stub is shared across the whole
# dependency closure, and a hardcoded name would read as if only that plugin
# were affected. Batch-safe (no quotes, no & | > characters) so the pwsh twin
# can emit the identical string from a .cmd shim.
MSG_PLUGIN_ADDED='Error: this plugin is already added'
MSG_PLUGIN_UPGRADED='Plugin updated from 1.15.0 to 1.16.0'
MSG_PLUGIN_CURRENT='Plugin is up to date at 1.16.0'
MSG_UNRELATED='Error: could not write to disk'

# make_stubs <bin_dir> <log_path> <mode>
#
# Modes:
#   fresh              every registration succeeds silently (clean machine)
#   installed          marketplace-add and mcp-add fail with the real
#                      "already ..." messages; plugin install reports an
#                      existing installation; plugin update reports a
#                      version transition
#   current            like `installed`, but plugin update reports no
#                      transition (the machine is already at the new version)
#   unrelated-failure  marketplace-add fails with a message that is not an
#                      idempotency message
make_stubs() {
    local bin_dir="$1"
    local log_path="$2"
    local mode="$3"
    mkdir -p "$bin_dir"

    local marketplace_add_body="exit 0"
    local mcp_add_body="exit 0"
    local claude_install_body="exit 0"
    local other_install_body="exit 0"
    local plugin_update_body="exit 0"
    case "$mode" in
        fresh) ;;
        installed)
            marketplace_add_body="echo '${MSG_MARKETPLACE_EXISTS}' >&2; exit 1"
            mcp_add_body="echo '${MSG_MCP_EXISTS}' >&2; exit 1"
            claude_install_body="echo '${MSG_PLUGIN_INSTALLED}'; exit 0"
            other_install_body="echo '${MSG_PLUGIN_ADDED}' >&2; exit 1"
            plugin_update_body="echo '${MSG_PLUGIN_UPGRADED}'; exit 0"
            ;;
        current)
            marketplace_add_body="echo '${MSG_MARKETPLACE_EXISTS}' >&2; exit 1"
            mcp_add_body="echo '${MSG_MCP_EXISTS}' >&2; exit 1"
            claude_install_body="echo '${MSG_PLUGIN_INSTALLED}'; exit 0"
            other_install_body="echo '${MSG_PLUGIN_ADDED}' >&2; exit 1"
            plugin_update_body="echo '${MSG_PLUGIN_CURRENT}'; exit 0"
            ;;
        unrelated-failure)
            marketplace_add_body="echo '${MSG_UNRELATED}' >&2; exit 1"
            ;;
        *) echo "make_stubs: unknown mode '$mode'" >&2; return 1 ;;
    esac

    local cmd plugin_install_body
    for cmd in codex claude copilot; do
        if [[ "$cmd" == "claude" ]]; then
            plugin_install_body="$claude_install_body"
        else
            plugin_install_body="$other_install_body"
        fi
        {
            printf '%s\n' '#!/bin/sh'
            printf 'echo "%s $*" >> "%s"\n' "$cmd" "$log_path"
            printf '%s\n' 'case "$*" in'
            printf '  "plugin marketplace update"*) exit 0 ;;\n'
            printf '  "plugin marketplace add"*) %s ;;\n' "$marketplace_add_body"
            printf '  "plugin update"*) %s ;;\n' "$plugin_update_body"
            printf '  "plugin install"*|"plugin add"*) %s ;;\n' "$plugin_install_body"
            printf '  "mcp add"*) %s ;;\n' "$mcp_add_body"
            printf '%s\n' 'esac'
            printf '%s\n' 'exit 0'
        } > "${bin_dir}/${cmd}"
        chmod +x "${bin_dir}/${cmd}"
    done

    # Report a Node version that clears the >= 22.19.0 gate, so MCP placement
    # runs on every host regardless of the real toolchain.
    printf '%s\n%s\n' '#!/bin/sh' 'echo v22.19.0' > "${bin_dir}/node"
    chmod +x "${bin_dir}/node"
}

# Shadow `cp` with a failing stub. install.sh reaches `cp` first inside
# place_mcp_servers, which runs before REGISTRATION_STARTED flips — so this is
# a genuine placement-phase failure, not a simulated one.
make_failing_cp() {
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'echo "cp: simulated placement failure" >&2' 'exit 1' \
        > "${1}/cp"
    chmod +x "${1}/cp"
}

# run_case <mode> <seed_existing:0|1>
# Populates: RC, OUT, LOG, INSTALL_ROOT_PATH, TEST_ROOT
run_case() {
    local mode="$1"
    local seed_existing="$2"

    TEST_ROOT="$(mktemp -d)"
    INSTALL_ROOT_PATH="${TEST_ROOT}/installed"
    local bin_dir="${TEST_ROOT}/bin"
    local log_path="${TEST_ROOT}/commands.log"
    : > "$log_path"

    make_stubs "$bin_dir" "$log_path" "$mode"
    if [[ "${FAILING_CP:-0}" -eq 1 ]]; then
        make_failing_cp "$bin_dir"
    fi

    if [[ $seed_existing -eq 1 ]]; then
        mkdir -p "$INSTALL_ROOT_PATH"
        echo "keep" > "${INSTALL_ROOT_PATH}/existing.marker"
    fi

    local original_path="$PATH"
    local original_codex_home="${SDD_CODEX_HOME:-}"
    export PATH="${bin_dir}:${original_path}"
    export SDD_CODEX_HOME="${TEST_ROOT}/codex-home"

    RC=0
    OUT="$(bash "$INSTALLER" \
        --source-directory "$SOURCE_FIXTURE" \
        --install-root "$INSTALL_ROOT_PATH" \
        --target All \
        --plugins sdd-bootstrap \
        --mcp sdd-forge-mcp \
        2>&1)" || RC=$?

    export PATH="$original_path"
    if [[ -z "$original_codex_home" ]]; then
        unset SDD_CODEX_HOME
    else
        export SDD_CODEX_HOME="$original_codex_home"
    fi
    LOG="$(cat "$log_path")"
}

installed_tree_present() {
    [[ -f "${INSTALL_ROOT_PATH}/plugins/sdd-bootstrap/.codex-plugin/plugin.json" ]]
}

no_backup_left() {
    ! compgen -G "${TEST_ROOT}/sdd-plugins-backup-*" > /dev/null
}

# ---------------------------------------------------------------------------
# Case 1: re-running against already-registered CLIs succeeds
# ---------------------------------------------------------------------------
_c1_ok=1
run_case installed 1
if [[ $RC -ne 0 ]]; then
    echo "  installer output: $OUT" >&2
    fail "re-run against already-registered CLIs should exit 0 (exit ${RC})"
    _c1_ok=0
fi
installed_tree_present || { fail "re-run did not leave the new tree in the install root"; _c1_ok=0; }
no_backup_left || { fail "re-run left a backup directory behind"; _c1_ok=0; }
echo "$OUT" | grep -q "is already registered; keeping the existing registration" \
    || { fail "re-run did not report the tolerated registrations"; _c1_ok=0; }
# The marketplace, the MCP server and the per-plugin registrations must all be
# tolerated. Asserting only one of them would pass on a fix that covered the
# marketplace and left the plugin loops fatal — which is what run 2 of a real
# upgrade would hit first.
for _c1_label in "the Codex sdd-plugins marketplace" "MCP server 'sdd-forge-mcp'" "Codex plugin 'sdd-bootstrap'" "Copilot plugin 'sdd-bootstrap'"; do
    echo "$OUT" | grep -qF "Note: ${_c1_label} is already registered" \
        || { fail "re-run did not tolerate: ${_c1_label}"; _c1_ok=0; }
done
rm -rf "$TEST_ROOT"
[[ $_c1_ok -eq 1 ]] && ok "already-registered marketplaces and MCP servers are tolerated"

# ---------------------------------------------------------------------------
# Case 2 (negative control for case 1): an unrelated failure is still fatal
# ---------------------------------------------------------------------------
_c2_ok=1
run_case unrelated-failure 0
if [[ $RC -eq 0 ]]; then
    fail "a registration failure with an unrelated message must stay fatal"
    _c2_ok=0
fi
echo "$OUT" | grep -q "failed with exit code" \
    || { fail "unrelated registration failure did not name the failing command"; _c2_ok=0; }
if echo "$OUT" | grep -q "is already registered; keeping"; then
    fail "unrelated registration failure was wrongly tolerated as idempotent"
    _c2_ok=0
fi
rm -rf "$TEST_ROOT"
[[ $_c2_ok -eq 1 ]] && ok "a non-idempotency registration failure is still fatal"

# ---------------------------------------------------------------------------
# Case 3: an existing Claude installation is upgraded, and the transition is
#         reported
# ---------------------------------------------------------------------------
_c3_ok=1
run_case installed 0
[[ $RC -eq 0 ]] || { fail "upgrade run should exit 0 (exit ${RC})"; _c3_ok=0; }
echo "$LOG" | grep -qF "claude plugin marketplace update sdd-plugins" \
    || { fail "upgrade path did not refresh the marketplace"; _c3_ok=0; }
echo "$LOG" | grep -qF "claude plugin update sdd-bootstrap@sdd-plugins" \
    || { fail "upgrade path did not update the already-installed plugin"; _c3_ok=0; }
echo "$OUT" | grep -qF "sdd-forge: upgraded sdd-bootstrap (updated from 1.15.0 to 1.16.0)" \
    || { fail "upgrade run did not report the version transition"; _c3_ok=0; }
# The summary count must equal the number of per-plugin transition lines.
# Comparing the two rather than hardcoding a number keeps this independent of
# the dependency closure --plugins expands to (sdd-bootstrap pulls in
# sdd-review-loop), while still catching a summary that reports a fixed count.
_c3_lines="$(echo "$OUT" | grep -cE '^sdd-forge: upgraded [a-z-]+ \(updated from ' || true)"
_c3_summary="$(echo "$OUT" | sed -n 's/^sdd-forge: upgraded \([0-9][0-9]*\) Claude plugin(s)\.$/\1/p')"
if [[ "$_c3_summary" != "$_c3_lines" || -z "$_c3_summary" ]]; then
    fail "upgrade summary count ('${_c3_summary}') does not match the ${_c3_lines} reported transitions"
    _c3_ok=0
fi
rm -rf "$TEST_ROOT"
[[ $_c3_ok -eq 1 ]] && ok "an already-installed Claude plugin is upgraded and the transition reported"

# ---------------------------------------------------------------------------
# Case 4 (negative control for case 3): a machine already at the new version
#         reports no change
# ---------------------------------------------------------------------------
_c4_ok=1
run_case current 0
[[ $RC -eq 0 ]] || { fail "no-change run should exit 0 (exit ${RC})"; _c4_ok=0; }
echo "$OUT" | grep -qF "sdd-forge: sdd-bootstrap was already up to date" \
    || { fail "no-change run did not report that nothing moved"; _c4_ok=0; }
echo "$OUT" | grep -qF "sdd-forge: no Claude plugin needed an upgrade." \
    || { fail "no-change run did not summarise zero upgrades"; _c4_ok=0; }
if echo "$OUT" | grep -qF "sdd-forge: upgraded sdd-bootstrap"; then
    fail "no-change run reported an upgrade that did not happen"
    _c4_ok=0
fi
rm -rf "$TEST_ROOT"
[[ $_c4_ok -eq 1 ]] && ok "a machine already at the new version reports no upgrade"

# ---------------------------------------------------------------------------
# Case 5 (second control for case 3): a clean machine never enters the upgrade
#         path
# ---------------------------------------------------------------------------
_c5_ok=1
run_case fresh 0
[[ $RC -eq 0 ]] || { fail "clean install should exit 0 (exit ${RC})"; _c5_ok=0; }
if echo "$LOG" | grep -qF "claude plugin update"; then
    fail "clean install invoked the upgrade path it had no reason to enter"
    _c5_ok=0
fi
if echo "$OUT" | grep -qF "sdd-forge: upgraded"; then
    fail "clean install reported an upgrade"
    _c5_ok=0
fi
rm -rf "$TEST_ROOT"
[[ $_c5_ok -eq 1 ]] && ok "a clean install does not enter the upgrade path"

# ---------------------------------------------------------------------------
# Case 6: a placement-phase failure still reverts the install root
# ---------------------------------------------------------------------------
_c6_ok=1
FAILING_CP=1 run_case fresh 1
if [[ $RC -eq 0 ]]; then
    fail "a placement-phase failure must be fatal"
    _c6_ok=0
fi
if [[ ! -f "${INSTALL_ROOT_PATH}/existing.marker" ]]; then
    fail "a placement-phase failure did not restore the previous installation"
    _c6_ok=0
fi
if installed_tree_present; then
    fail "a placement-phase failure left the half-written tree in place"
    _c6_ok=0
fi
rm -rf "$TEST_ROOT"
[[ $_c6_ok -eq 1 ]] && ok "a placement-phase failure still reverts the install root"

# ---------------------------------------------------------------------------
# Case 7: a registration-phase failure does not revert, and names what failed
# ---------------------------------------------------------------------------
_c7_ok=1
run_case unrelated-failure 1
if [[ $RC -eq 0 ]]; then
    fail "a registration-phase failure must still be fatal"
    _c7_ok=0
fi
if [[ -f "${INSTALL_ROOT_PATH}/existing.marker" ]]; then
    fail "a registration-phase failure reverted the install root"
    _c7_ok=0
fi
installed_tree_present \
    || { fail "a registration-phase failure discarded the newly placed tree"; _c7_ok=0; }
no_backup_left || { fail "a registration-phase failure left a backup directory behind"; _c7_ok=0; }
echo "$OUT" | grep -qF "was left at the newly installed version" \
    || { fail "a registration-phase failure did not say the install root was kept"; _c7_ok=0; }
echo "$OUT" | grep -qF "plugin marketplace add" \
    || { fail "a registration-phase failure did not name the failing registration"; _c7_ok=0; }
rm -rf "$TEST_ROOT"
[[ $_c7_ok -eq 1 ]] && ok "a registration-phase failure keeps the new version and names what failed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[[ $FAIL -eq 0 ]]
