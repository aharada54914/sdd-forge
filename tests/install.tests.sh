#!/usr/bin/env bash
# install.tests.sh — bash port of install.tests.ps1
# Run from any directory. Uses --source-directory so no network is needed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${REPO_ROOT}/install.sh"
ALL_PLUGINS="sdd-bootstrap sdd-implementation sdd-quality-loop"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
ok() { echo "ok: $*"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# Create fake codex / claude / copilot shims in a temp bin dir.
# Args: bin_dir log_path [fail_pattern]
make_fake_commands() {
    local bin_dir="$1"
    local log_path="$2"
    local fail_pattern="${3:-}"
    mkdir -p "$bin_dir"
    for cmd in codex claude copilot; do
        local shim="${bin_dir}/${cmd}"
        if [[ -n "$fail_pattern" ]]; then
            cat > "$shim" <<SHIM
#!/bin/sh
echo "${cmd} \$*" >> "${log_path}"
echo "\$*" | grep -qF "${fail_pattern}" && exit 9
exit 0
SHIM
        else
            cat > "$shim" <<SHIM
#!/bin/sh
echo "${cmd} \$*" >> "${log_path}"
exit 0
SHIM
        fi
        chmod +x "$shim"
    done
}

# Run a scenario. Args handled by variables set before calling.
# Returns 0 if installer exited 0, 1 otherwise. Stdout/stderr captured.
run_installer() {
    bash "$INSTALLER" "$@"
}

# ---------------------------------------------------------------------------
# Scenario runner (mirrors Invoke-InstallerScenario)
# ---------------------------------------------------------------------------
invoke_installer_scenario() {
    local plugins_arg=""
    local fail_pattern=""
    local seed_existing=0

    # Parse named keyword args: plugins=..., fail_pattern=..., seed_existing=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            plugins=*)      plugins_arg="${1#plugins=}"; shift ;;
            fail_pattern=*) fail_pattern="${1#fail_pattern=}"; shift ;;
            seed_existing=*)seed_existing="${1#seed_existing=}"; shift ;;
            *) echo "invoke_installer_scenario: unknown arg $1" >&2; return 1 ;;
        esac
    done

    local test_root
    test_root="$(mktemp -d)"
    local install_root="${test_root}/installed"
    local fake_bin="${test_root}/bin"
    local command_log="${test_root}/commands.log"
    local original_path="$PATH"

    make_fake_commands "$fake_bin" "$command_log" "$fail_pattern"
    export PATH="${fake_bin}:${original_path}"

    if [[ $seed_existing -eq 1 ]]; then
        mkdir -p "$install_root"
        echo "keep" > "${install_root}/existing.marker"
    fi

    local installer_failed=0
    local out
    out="$(run_installer \
        --source-directory "$REPO_ROOT" \
        --install-root "$install_root" \
        --target All \
        ${plugins_arg:+--plugins "$plugins_arg"} \
        2>&1)" || installer_failed=1

    export PATH="$original_path"

    # Error path
    if [[ -n "$fail_pattern" ]]; then
        local scenario_ok=1
        if [[ $installer_failed -eq 0 ]]; then
            fail "installer should have failed for pattern '${fail_pattern}'"
            scenario_ok=0
        fi
        if [[ $seed_existing -eq 1 ]]; then
            if [[ ! -f "${install_root}/existing.marker" ]]; then
                fail "installer did not restore previous installation (seed_existing, pattern '${fail_pattern}')"
                scenario_ok=0
            fi
        else
            if [[ -d "$install_root" ]]; then
                fail "installer left incomplete initial installation (pattern '${fail_pattern}')"
                scenario_ok=0
            fi
        fi
        rm -rf "$test_root"
        return 0
    fi

    # Success path
    if [[ $installer_failed -ne 0 ]]; then
        echo "  installer output: $out" >&2
        rm -rf "$test_root"
        return 1
    fi

    local all_ok=1

    # All plugin files must be present
    for p in $ALL_PLUGINS; do
        if [[ ! -f "${install_root}/plugins/${p}/.codex-plugin/plugin.json" ]]; then
            fail "plugin not copied: $p"
            all_ok=0
        fi
    done

    # Determine which plugins were requested
    local requested_plugins
    if [[ -n "$plugins_arg" ]]; then
        IFS=',' read -ra requested_plugins <<< "$plugins_arg"
    else
        read -ra requested_plugins <<< "$ALL_PLUGINS"
    fi

    local log=""
    [[ -f "$command_log" ]] && log="$(cat "$command_log")"

    # Registered expected commands
    for p in "${requested_plugins[@]}"; do
        if ! echo "$log" | grep -qF "codex plugin add ${p}@sdd-plugins"; then
            fail "expected command not found: codex plugin add ${p}@sdd-plugins"
            all_ok=0
        fi
        if ! echo "$log" | grep -qF "claude plugin install ${p}@sdd-plugins"; then
            fail "expected command not found: claude plugin install ${p}@sdd-plugins"
            all_ok=0
        fi
        if ! echo "$log" | grep -qF "copilot plugin install ${p}@sdd-plugins"; then
            fail "expected command not found: copilot plugin install ${p}@sdd-plugins"
            all_ok=0
        fi
    done
    # Copilot marketplace command
    if ! echo "$log" | grep -qF "copilot plugin marketplace add"; then
        fail "expected command not found: copilot plugin marketplace add"
        all_ok=0
    fi

    # Did NOT register unselected plugins
    for p in $ALL_PLUGINS; do
        local selected=0
        for r in "${requested_plugins[@]}"; do
            [[ "$p" == "$r" ]] && selected=1 && break
        done
        if [[ $selected -eq 0 ]]; then
            if echo "$log" | grep -qF "plugin add ${p}@sdd-plugins" || \
               echo "$log" | grep -qF "plugin install ${p}@sdd-plugins"; then
                fail "installer registered unselected plugin: $p"
                all_ok=0
            fi
        fi
    done

    rm -rf "$test_root"
    [[ $all_ok -eq 1 ]]
}

# ---------------------------------------------------------------------------
# Scenario (a): full install — all plugins registered
# ---------------------------------------------------------------------------
if invoke_installer_scenario; then
    ok "full install registers all plugins"
else
    fail "full install registers all plugins"
fi

# ---------------------------------------------------------------------------
# Scenario (b): subset --plugins
# ---------------------------------------------------------------------------
if invoke_installer_scenario plugins="sdd-bootstrap,sdd-implementation"; then
    ok "subset --plugins only registers chosen plugins"
else
    fail "subset --plugins only registers chosen plugins"
fi

# ---------------------------------------------------------------------------
# Scenario (c): failure during registration → no half-installed root (fresh)
# ---------------------------------------------------------------------------
invoke_installer_scenario fail_pattern="sdd-implementation@sdd-plugins"
ok "failure on registration removes incomplete fresh install"

# ---------------------------------------------------------------------------
# Scenario (d): failure during registration → existing install restored
# ---------------------------------------------------------------------------
invoke_installer_scenario fail_pattern="sdd-implementation@sdd-plugins" seed_existing=1
ok "failure on registration restores pre-existing install"

# ---------------------------------------------------------------------------
# Scenario (e): invalid source directory rejected before touching existing install
# ---------------------------------------------------------------------------
_e_root="$(mktemp -d)"
_e_install="${_e_root}/installed"
_e_badsrc="${_e_root}/bad-source"
mkdir -p "$_e_install" "$_e_badsrc"
echo "keep" > "${_e_install}/existing.marker"
_e_failed=0
bash "$INSTALLER" --source-directory "$_e_badsrc" --install-root "$_e_install" --target FilesOnly 2>/dev/null || _e_failed=1
_e_ok=1
if [[ $_e_failed -eq 0 ]]; then
    fail "invalid source directory was accepted"
    _e_ok=0
fi
if [[ ! -f "${_e_install}/existing.marker" ]]; then
    fail "existing install was removed by pre-deployment check"
    _e_ok=0
fi
rm -rf "$_e_root"
[[ $_e_ok -eq 1 ]] && ok "invalid source directory rejected before touching existing install"

# ---------------------------------------------------------------------------
# Scenario (f): invalid plugin name rejected
# ---------------------------------------------------------------------------
_f_root="$(mktemp -d)"
_f_failed=0
bash "$INSTALLER" \
    --source-directory "$REPO_ROOT" \
    --install-root "${_f_root}/installed" \
    --target FilesOnly \
    --plugins "not-a-plugin" 2>/dev/null || _f_failed=1
rm -rf "$_f_root"
if [[ $_f_failed -eq 1 ]]; then
    ok "invalid plugin name rejected"
else
    fail "invalid plugin name was accepted"
fi

# ---------------------------------------------------------------------------
# Scenario (g): idempotency — second successful install into same root exits 0
# and state is consistent
# ---------------------------------------------------------------------------
_g_root="$(mktemp -d)"
_g_install="${_g_root}/installed"
_g_bin="${_g_root}/bin"
_g_log="${_g_root}/commands.log"
_g_orig_path="$PATH"
make_fake_commands "$_g_bin" "$_g_log"
export PATH="${_g_bin}:${_g_orig_path}"
# First run
_g_failed=0
bash "$INSTALLER" --source-directory "$REPO_ROOT" --install-root "$_g_install" --target All 2>/dev/null || _g_failed=1
# Second run (idempotent)
bash "$INSTALLER" --source-directory "$REPO_ROOT" --install-root "$_g_install" --target All 2>/dev/null || _g_failed=1
export PATH="$_g_orig_path"
_g_ok=1
if [[ $_g_failed -ne 0 ]]; then
    fail "idempotency: second install failed"
    _g_ok=0
fi
for p in $ALL_PLUGINS; do
    if [[ ! -f "${_g_install}/plugins/${p}/.codex-plugin/plugin.json" ]]; then
        fail "idempotency: plugin not present after second install: $p"
        _g_ok=0
    fi
done
rm -rf "$_g_root"
[[ $_g_ok -eq 1 ]] && ok "idempotency: second install exits 0, state consistent"

# ---------------------------------------------------------------------------
# Scenario (h): no-nesting assertion after install
# ---------------------------------------------------------------------------
_h_root="$(mktemp -d)"
_h_install="${_h_root}/installed"
_h_bin="${_h_root}/bin"
_h_log="${_h_root}/commands.log"
_h_orig_path="$PATH"
make_fake_commands "$_h_bin" "$_h_log"
export PATH="${_h_bin}:${_h_orig_path}"
bash "$INSTALLER" --source-directory "$REPO_ROOT" --install-root "$_h_install" --target All 2>/dev/null
export PATH="$_h_orig_path"
_h_ok=1
# Must NOT have nested dirs
for nested in ".agents/.agents" ".codex/.codex" ".claude-plugin/.claude-plugin"; do
    if [[ -d "${_h_install}/${nested}" ]]; then
        fail "no-nesting: found unexpected nested directory: ${nested}"
        _h_ok=0
    fi
done
# Must have both TOML files
for toml in ".codex/agents/sdd-investigator.toml" ".codex/agents/sdd-evaluator.toml"; do
    if [[ ! -f "${_h_install}/${toml}" ]]; then
        fail "no-nesting: expected file missing after install: ${toml}"
        _h_ok=0
    fi
done
rm -rf "$_h_root"
[[ $_h_ok -eq 1 ]] && ok "no-nesting: layout correct after install"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[[ $FAIL -eq 0 ]]
