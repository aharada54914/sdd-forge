#!/usr/bin/env bash
# install.tests.sh — bash port of install.tests.ps1
# Run from any directory. Uses --source-directory so no network is needed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${REPO_ROOT}/install.sh"
ALL_PLUGINS="sdd-bootstrap sdd-ship sdd-implementation sdd-quality-loop sdd-lite sdd-review-loop"
PASS=0
FAIL=0

clone_fixture() {
    local source_root="$1"
    local destination="$2"
    # `git clone` may invoke a host credential/helper while copying local
    # objects. Export the committed tree instead, then initialise a disposable
    # repository because later fixtures intentionally create commits.
    mkdir -p "$destination"
    git -C "$source_root" archive --format=tar HEAD | tar -xf - -C "$destination"
    git -C "$destination" init -q
    git -C "$destination" add -A
    git -C "$destination" -c user.name="Installer Test" -c user.email="installer-test@example.invalid" commit -qm "Fixture baseline"
}

# Local installs intentionally copy Git-tracked files only. Overlay the
# installer and Claude manifests under test so the fixture exercises this
# working tree without including unrelated untracked files.
SOURCE_FIXTURE_ROOT="$(mktemp -d)"
SOURCE_FIXTURE="${SOURCE_FIXTURE_ROOT}/source"
clone_fixture "$REPO_ROOT" "$SOURCE_FIXTURE"
for relative_path in \
    ".claude-plugin/marketplace.json" \
    ".agents/plugins/marketplace.json" \
    "install.sh" \
    "install.ps1" \
    "plugins/sdd-bootstrap/.claude-plugin/plugin.json" \
    "plugins/sdd-quality-loop/.claude-plugin/plugin.json" \
    "plugins/sdd-review-loop/.claude-plugin/plugin.json" \
    "plugins/sdd-review-loop/.codex-plugin/plugin.json" \
    "plugins/sdd-review-loop/.plugin/plugin.json"; do
    mkdir -p "${SOURCE_FIXTURE}/$(dirname "$relative_path")"
    cp -p "${REPO_ROOT}/${relative_path}" "${SOURCE_FIXTURE}/${relative_path}"
done
git -C "$SOURCE_FIXTURE" add \
    .claude-plugin/marketplace.json \
    .agents/plugins/marketplace.json \
    install.sh \
    install.ps1 \
    plugins/sdd-bootstrap/.claude-plugin/plugin.json \
    plugins/sdd-quality-loop/.claude-plugin/plugin.json \
    plugins/sdd-review-loop
git -C "$SOURCE_FIXTURE" diff --cached --quiet || git -C "$SOURCE_FIXTURE" -c user.name="Installer Test" -c user.email="installer-test@example.invalid" commit -qm "Add review-loop fixture"

# The MCP server payload (mcp/sdd-forge-mcp/dist + package.json) is not yet
# Git-tracked in this repository (dist/ is committed by a later task). The
# installer must copy it from the filesystem regardless of Git tracking
# state, so seed a minimal MCP payload directly on disk (untracked is fine —
# this mirrors the real source tree today).
mkdir -p "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/dist"
cat > "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/dist/index.js" <<'MCPJS'
#!/usr/bin/env node
console.log("sdd-forge-mcp fixture stub");
MCPJS
cat > "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/package.json" <<'MCPPKG'
{
  "name": "sdd-forge-mcp",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=20" }
}
MCPPKG
# Files that must NOT be copied into the install root (node_modules/src/tests).
mkdir -p "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/node_modules/should-not-copy" \
    "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/src" \
    "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/tests"
echo "noise" > "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/node_modules/should-not-copy/index.js"
echo "noise" > "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/src/index.ts"
echo "noise" > "${SOURCE_FIXTURE}/mcp/sdd-forge-mcp/tests/index.test.ts"

# local-env-mcp (T-006): a second first-class MCP that ships by default. Seed a
# minimal payload the same way as sdd-forge-mcp so the installer's generic
# MCP_SELECTION machinery is exercised for BOTH servers.
mkdir -p "${SOURCE_FIXTURE}/mcp/local-env-mcp/dist"
cat > "${SOURCE_FIXTURE}/mcp/local-env-mcp/dist/index.js" <<'MCPJS2'
#!/usr/bin/env node
console.log("local-env-mcp fixture stub");
MCPJS2
cat > "${SOURCE_FIXTURE}/mcp/local-env-mcp/package.json" <<'MCPPKG2'
{
  "name": "local-env-mcp",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=20" }
}
MCPPKG2
# Files that must NOT be copied into the install root (node_modules/src/tests).
mkdir -p "${SOURCE_FIXTURE}/mcp/local-env-mcp/node_modules/should-not-copy" \
    "${SOURCE_FIXTURE}/mcp/local-env-mcp/src" \
    "${SOURCE_FIXTURE}/mcp/local-env-mcp/tests"
echo "noise" > "${SOURCE_FIXTURE}/mcp/local-env-mcp/node_modules/should-not-copy/index.js"
echo "noise" > "${SOURCE_FIXTURE}/mcp/local-env-mcp/src/index.ts"
echo "noise" > "${SOURCE_FIXTURE}/mcp/local-env-mcp/tests/index.test.ts"

# ci-mcp (T-009): a third first-class MCP that ships by default. Seed a
# minimal payload the same way as sdd-forge-mcp/local-env-mcp so the
# installer's generic MCP_SELECTION machinery is exercised for all three.
mkdir -p "${SOURCE_FIXTURE}/mcp/ci-mcp/dist"
cat > "${SOURCE_FIXTURE}/mcp/ci-mcp/dist/index.js" <<'MCPJS3'
#!/usr/bin/env node
console.log("ci-mcp fixture stub");
MCPJS3
cat > "${SOURCE_FIXTURE}/mcp/ci-mcp/package.json" <<'MCPPKG3'
{
  "name": "ci-mcp",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=20" }
}
MCPPKG3
# Files that must NOT be copied into the install root (node_modules/src/tests).
mkdir -p "${SOURCE_FIXTURE}/mcp/ci-mcp/node_modules/should-not-copy" \
    "${SOURCE_FIXTURE}/mcp/ci-mcp/src" \
    "${SOURCE_FIXTURE}/mcp/ci-mcp/tests"
echo "noise" > "${SOURCE_FIXTURE}/mcp/ci-mcp/node_modules/should-not-copy/index.js"
echo "noise" > "${SOURCE_FIXTURE}/mcp/ci-mcp/src/index.ts"
echo "noise" > "${SOURCE_FIXTURE}/mcp/ci-mcp/tests/index.test.ts"

# T-007 (AC-010/011/015): install.sh registers MCP servers with Cursor and
# VS Code via SDD_CURSOR_DIR / SDD_VSCODE_USER_DIR-overridable config paths.
# Tests must NEVER touch the real user's client configs, so point both at
# non-existent directories inside an isolated root by default (an absent
# client directory means "client not installed" and registration skips).
# Scenarios that exercise the upsert override these per-scenario and restore
# them to these defaults afterwards.
GLOBAL_IDE_ROOT="$(mktemp -d)"
export SDD_CURSOR_DIR="${GLOBAL_IDE_ROOT}/cursor-not-installed"
export SDD_VSCODE_USER_DIR="${GLOBAL_IDE_ROOT}/vscode-not-installed"

trap 'rm -rf "$SOURCE_FIXTURE_ROOT" "$GLOBAL_IDE_ROOT"' EXIT

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
    for cmd in codex claude copilot gh; do
        local shim="${bin_dir}/${cmd}"
        if [[ "$cmd" == "gh" ]]; then
            cat > "$shim" <<SHIM
#!/bin/sh
echo "gh \$*" >> "${log_path}"
if [ "\$1" = "auth" ] && [ "\$2" = "token" ]; then
    printf '%s\n' "fake-gh-token"
    exit 0
fi
exit 0
SHIM
        elif [[ -n "$fail_pattern" ]]; then
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

make_archive_fixture() {
    local source_root="$1"
    local archive_root
    archive_root="$(mktemp -d)"
    local archive_source="${archive_root}/repo"
    local archive_path="${archive_root}/source.tar.gz"
    mkdir -p "$archive_source"
    while IFS= read -r -d '' relative_path; do
        mkdir -p "${archive_source}/$(dirname "$relative_path")"
        cp -p "${source_root}/${relative_path}" "${archive_source}/${relative_path}"
    done < <(git -C "$source_root" ls-files -z)
    tar -czf "$archive_path" -C "$archive_root" "repo"
    printf '%s\n' "$archive_path"
}

resolve_registered_plugins() {
    local -a resolved=("$@")
    local changed=1
    local plugin dependency

    while [[ $changed -eq 1 ]]; do
        changed=0
        for plugin in "${resolved[@]}"; do
            local -a dependencies=()
            case "$plugin" in
                sdd-bootstrap) dependencies=(sdd-review-loop) ;;
                sdd-lite) dependencies=(sdd-bootstrap sdd-implementation sdd-quality-loop) ;;
                sdd-ship) dependencies=(sdd-bootstrap sdd-review-loop sdd-implementation sdd-quality-loop sdd-lite) ;;
            esac
            # Guard the expansion: bash 3.2 treats a zero-element array as unset,
            # so "${dependencies[@]}" would raise "unbound variable" under -u
            # whenever $plugin has no case match above.
            [[ ${#dependencies[@]} -eq 0 ]] && continue
            for dependency in "${dependencies[@]}"; do
                if [[ " ${resolved[*]} " != *" ${dependency} "* ]]; then
                    resolved+=("$dependency")
                    changed=1
                fi
            done
        done
    done
    printf '%s\n' "${resolved[@]}"
}

make_fake_remote_fetcher() {
    local bin_dir="$1"
    local log_path="$2"
    local archive_path="$3"
    mkdir -p "$bin_dir"

    cat > "${bin_dir}/gh" <<SHIM
#!/bin/sh
echo "gh \$*" >> "${log_path}"
if [ "\$1" = "auth" ] && [ "\$2" = "token" ]; then
    printf '%s\n' "fake-gh-token"
    exit 0
fi
exit 0
SHIM
    chmod +x "${bin_dir}/gh"

    cat > "${bin_dir}/curl" <<SHIM
#!/bin/sh
echo "curl \$*" >> "${log_path}"
config=""
case "\$*" in
    *"--config -"*) config="\$(cat)" ;;
esac
case "\$config" in
    *"Authorization: Bearer fake-gh-token"*) ;;
    *) echo "missing GitHub auth header" >&2; exit 9 ;;
esac
case "\$*" in
    *"fake-gh-token"*) echo "GitHub token leaked through curl arguments" >&2; exit 9 ;;
esac
case "\$*" in
    *"https://api.github.com/repos/"*) ;;
    *) echo "unexpected remote download URL" >&2; exit 9 ;;
esac
output=""
    while [ "\$#" -gt 0 ]; do
    case "\$1" in
        -o)
            output="\$2"
            shift 2
            ;;
        -H)
            shift 2
            ;;
        -fsSL)
            shift
            ;;
        *)
            shift
            ;;
    esac
done
cp "${archive_path}" "\$output"
exit 0
SHIM
    chmod +x "${bin_dir}/curl"
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
    local _orig_codex_home="${SDD_CODEX_HOME:-}"

    make_fake_commands "$fake_bin" "$command_log" "$fail_pattern"
    export PATH="${fake_bin}:${original_path}"
    export SDD_CODEX_HOME="${test_root}/codex-home"

    if [[ $seed_existing -eq 1 ]]; then
        mkdir -p "$install_root"
        echo "keep" > "${install_root}/existing.marker"
    fi

    local installer_failed=0
    local out
    out="$(run_installer \
        --source-directory "$SOURCE_FIXTURE" \
        --install-root "$install_root" \
        --target All \
        ${plugins_arg:+--plugins "$plugins_arg"} \
        2>&1)" || installer_failed=1

    export PATH="$original_path"
    if [[ -z "$_orig_codex_home" ]]; then
        unset SDD_CODEX_HOME
    else
        export SDD_CODEX_HOME="$_orig_codex_home"
    fi

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

    # Determine the dependency-closed plugin set that must be registered.
    local -a requested_plugins
    if [[ -n "$plugins_arg" ]]; then
        IFS=',' read -ra requested_plugins <<< "$plugins_arg"
    else
        requested_plugins=(sdd-bootstrap sdd-ship)
    fi
    local -a initial_plugins=("${requested_plugins[@]}")
    requested_plugins=()
    while IFS= read -r plugin; do
        requested_plugins+=("$plugin")
    done < <(resolve_registered_plugins "${initial_plugins[@]}")

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
    if ! echo "$log" | grep -qF "codex plugin marketplace add"; then
        fail "expected command not found: codex plugin marketplace add"
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

invoke_remote_installer_scenario() {
    local test_root
    test_root="$(mktemp -d)"
    local install_root="${test_root}/installed"
    local fake_bin="${test_root}/bin"
    local command_log="${test_root}/commands.log"
    local original_path="$PATH"
    local original_codex_home="${SDD_CODEX_HOME:-}"
    local archive_path
    archive_path="$(make_archive_fixture "$SOURCE_FIXTURE")"

    make_fake_commands "$fake_bin" "$command_log"
    make_fake_remote_fetcher "$fake_bin" "$command_log" "$archive_path"
    export PATH="${fake_bin}:${original_path}"
    export SDD_CODEX_HOME="${test_root}/codex-home"

    local installer_failed=0
    local out
    out="$(run_installer \
        --install-root "$install_root" \
        --target All \
        2>&1)" || installer_failed=1

    export PATH="$original_path"
    if [[ -z "$original_codex_home" ]]; then
        unset SDD_CODEX_HOME
    else
        export SDD_CODEX_HOME="$original_codex_home"
    fi

    local remote_ok=1
    if [[ $installer_failed -ne 0 ]]; then
        echo "  installer output: $out" >&2
        fail "authenticated remote install failed"
        remote_ok=0
    fi
    for p in $ALL_PLUGINS; do
        if [[ ! -f "${install_root}/plugins/${p}/.codex-plugin/plugin.json" ]]; then
            fail "authenticated remote install did not copy plugin: $p"
            remote_ok=0
        fi
    done
    if ! grep -qF "gh auth token" "$command_log"; then
        fail "authenticated remote install did not request a GitHub token"
        remote_ok=0
    fi
    if ! grep -qF "curl -fsSL" "$command_log"; then
        fail "authenticated remote install did not use curl"
        remote_ok=0
    fi
    if ! grep -qF "https://api.github.com/repos/aharada54914/sdd-forge/tarball/main" "$command_log"; then
        fail "authenticated remote install did not use the GitHub API archive URL"
        remote_ok=0
    fi
    if grep -qF "raw.githubusercontent.com" "$command_log" || grep -qF "codeload.github.com" "$command_log"; then
        fail "authenticated remote install still referenced raw/codeload hosts"
        remote_ok=0
    fi

    if [[ -d "$test_root" ]]; then
        rm -rf "$test_root"
    fi
    if [[ -d "$(dirname "$archive_path")" ]]; then
        rm -rf "$(dirname "$archive_path")"
    fi

    [[ $remote_ok -eq 1 ]]
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
# Scenario (b2): lite reaches bootstrap's review-loop at the fixed point
# ---------------------------------------------------------------------------
if invoke_installer_scenario plugins="sdd-lite"; then
    ok "lite selection resolves the full dependency closure"
else
    fail "lite selection resolves the full dependency closure"
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
_e_output="$(bash "$INSTALLER" --source-directory "$_e_badsrc" --install-root "$_e_install" --target FilesOnly 2>&1)" || _e_failed=1
_e_ok=1
if [[ $_e_failed -eq 0 ]]; then
    fail "invalid source directory was accepted"
    _e_ok=0
fi
if [[ ! -f "${_e_install}/existing.marker" ]]; then
    fail "existing install was removed by pre-deployment check"
    _e_ok=0
fi
if ! echo "$_e_output" | grep -qi "Git worktree"; then
    fail "non-Git source directory did not report the Git worktree requirement"
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
    --source-directory "$SOURCE_FIXTURE" \
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
_g_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_g_bin" "$_g_log"
export PATH="${_g_bin}:${_g_orig_path}"
export SDD_CODEX_HOME="${_g_root}/codex-home"
# First run
_g_failed=0
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_g_install" --target All 2>/dev/null || _g_failed=1
# Second run (idempotent)
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_g_install" --target All 2>/dev/null || _g_failed=1
export PATH="$_g_orig_path"
if [[ -z "$_g_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_g_orig_codex_home"
fi
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
if [[ -d "${_g_install}/.git" ]]; then
    fail "idempotency: .git repository history was installed"
    _g_ok=0
fi
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
_h_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_h_bin" "$_h_log"
export PATH="${_h_bin}:${_h_orig_path}"
export SDD_CODEX_HOME="${_h_root}/codex-home"
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_h_install" --target All 2>/dev/null
export PATH="$_h_orig_path"
if [[ -z "$_h_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_h_orig_codex_home"
fi
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
# Scenario (i): codex agent install + malformed-role diagnostic
# ---------------------------------------------------------------------------
_i_root="$(mktemp -d)"
_i_install="${_i_root}/installed"
_i_codex_home="${_i_root}/codex-home"
_i_codex_agents="${_i_codex_home}/agents"
_i_bin="${_i_root}/bin"
_i_log="${_i_root}/commands.log"
_i_orig_path="$PATH"
_i_orig_codex_home="${SDD_CODEX_HOME:-}"
mkdir -p "$_i_codex_agents"
echo 'name = "auditor"' > "${_i_codex_agents}/auditor.toml"
make_fake_commands "$_i_bin" "$_i_log"
export PATH="${_i_bin}:${_i_orig_path}"
export SDD_CODEX_HOME="$_i_codex_home"
_i_output="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_i_install" --target All 2>&1)" || true
export PATH="$_i_orig_path"
if [[ -z "$_i_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_i_orig_codex_home"
fi
_i_ok=1
# Verify agents installed with developer_instructions
if [[ ! -f "${_i_codex_agents}/sdd-investigator.toml" ]]; then
    fail "codex agent scenario (i): sdd-investigator.toml not installed"
    _i_ok=0
elif ! grep -Eq '^developer_instructions\s*=' "${_i_codex_agents}/sdd-investigator.toml"; then
    fail "codex agent scenario (i): sdd-investigator.toml missing developer_instructions"
    _i_ok=0
fi
if [[ ! -f "${_i_codex_agents}/sdd-evaluator.toml" ]]; then
    fail "codex agent scenario (i): sdd-evaluator.toml not installed"
    _i_ok=0
elif ! grep -Eq '^developer_instructions\s*=' "${_i_codex_agents}/sdd-evaluator.toml"; then
    fail "codex agent scenario (i): sdd-evaluator.toml missing developer_instructions"
    _i_ok=0
fi
# Verify warning output
if ! echo "$_i_output" | grep -q "Ignoring malformed agent role definition"; then
    fail "codex agent scenario (i): expected warning not in output"
    _i_ok=0
fi
if ! echo "$_i_output" | grep -q "auditor.toml"; then
    fail "codex agent scenario (i): auditor.toml path not in output"
    _i_ok=0
fi
# Verify auditor.toml unchanged
if [[ "$(cat "${_i_codex_agents}/auditor.toml")" != 'name = "auditor"' ]]; then
    fail "codex agent scenario (i): auditor.toml was modified"
    _i_ok=0
fi
rm -rf "$_i_root"
[[ $_i_ok -eq 1 ]] && ok "codex agent install + malformed-role diagnostic"

# ---------------------------------------------------------------------------
# Scenario (j): malformed source agent TOML rejected before deployment
# ---------------------------------------------------------------------------
_j_root="$(mktemp -d)"
_j_src="${_j_root}/bad-src"
_j_install="${_j_root}/installed"
clone_fixture "$SOURCE_FIXTURE" "$_j_src"
mkdir -p "$_j_install"
# Make the malformed TOML tracked so the installer reaches its validation.
echo 'name = "sdd-investigator"' > "$_j_src/.codex/agents/sdd-investigator.toml"
git -C "$_j_src" add .codex/agents/sdd-investigator.toml
git -C "$_j_src" -c user.name="Installer Test" -c user.email="installer-test@example.invalid" commit -qm "Malformed agent fixture"
# Pre-create install root with existing.marker
echo "keep" > "${_j_install}/existing.marker"
_j_failed=0
bash "$INSTALLER" --source-directory "$_j_src" --install-root "$_j_install" --target FilesOnly 2>/dev/null || _j_failed=1
_j_ok=1
if [[ $_j_failed -eq 0 ]]; then
    fail "malformed source rejected scenario (j): installer accepted bad source"
    _j_ok=0
fi
if [[ ! -f "${_j_install}/existing.marker" ]]; then
    fail "malformed source rejected scenario (j): existing.marker was removed"
    _j_ok=0
fi
rm -rf "$_j_root"
[[ $_j_ok -eq 1 ]] && ok "malformed source agent TOML rejected before deployment"

# ---------------------------------------------------------------------------
# Scenario (k): authenticated remote install uses GitHub CLI token flow
# ---------------------------------------------------------------------------
if invoke_remote_installer_scenario; then
    ok "authenticated remote install uses GitHub CLI token flow"
else
    fail "authenticated remote install uses GitHub CLI token flow"
fi

# ---------------------------------------------------------------------------
# Scenario (k2): a local source distributes tracked files only
# ---------------------------------------------------------------------------
_k2_root="$(mktemp -d)"
_k2_source="${_k2_root}/source"
_k2_install="${_k2_root}/installed"
clone_fixture "$SOURCE_FIXTURE" "$_k2_source"
mkdir -p "${_k2_source}/.private" "${_k2_source}/plugins/sdd-bootstrap/.private"
echo "root-secret" > "${_k2_source}/.private/secret.txt"
echo "nested-secret" > "${_k2_source}/plugins/sdd-bootstrap/.private/secret.txt"
_k2_failed=0
bash "$INSTALLER" --source-directory "$_k2_source" --install-root "$_k2_install" --target FilesOnly --skip-plugin-install --skip-agent-install 2>/dev/null || _k2_failed=1
_k2_ok=1
if [[ $_k2_failed -ne 0 ]]; then
    fail "tracked-only source scenario: installer failed"
    _k2_ok=0
fi
for leaked_path in ".private/secret.txt" "plugins/sdd-bootstrap/.private/secret.txt"; do
    if [[ -e "${_k2_install}/${leaked_path}" ]]; then
        fail "tracked-only source scenario: untracked file leaked: ${leaked_path}"
        _k2_ok=0
    fi
done
rm -rf "$_k2_root"
[[ $_k2_ok -eq 1 ]] && ok "local source installs Git-tracked files only"

# ---------------------------------------------------------------------------
# Scenario (k3): untracked required release files fail before deployment
# ---------------------------------------------------------------------------
_k3_root="$(mktemp -d)"
_k3_source="${_k3_root}/source"
_k3_install="${_k3_root}/installed"
clone_fixture "$SOURCE_FIXTURE" "$_k3_source"
git -C "$_k3_source" rm --cached -q plugins/sdd-review-loop/.codex-plugin/plugin.json
mkdir -p "$_k3_install"
echo "keep" > "${_k3_install}/existing.marker"
_k3_failed=0
_k3_output="$(bash "$INSTALLER" --source-directory "$_k3_source" --install-root "$_k3_install" --target FilesOnly 2>&1)" || _k3_failed=1
_k3_ok=1
if [[ $_k3_failed -eq 0 ]]; then
    fail "untracked required-file scenario: installer accepted an untracked manifest"
    _k3_ok=0
fi
if [[ ! -f "${_k3_install}/existing.marker" ]]; then
    fail "untracked required-file scenario: existing install was modified"
    _k3_ok=0
fi
if ! echo "$_k3_output" | grep -q "not Git-tracked"; then
    fail "untracked required-file scenario: expected tracking error not found"
    _k3_ok=0
fi
rm -rf "$_k3_root"
[[ $_k3_ok -eq 1 ]] && ok "untracked required release file is rejected before deployment"

# ---------------------------------------------------------------------------
# Scenario (l): concurrent-lock — pre-created lock with live pid blocks install
# ---------------------------------------------------------------------------
_l_root="$(mktemp -d)"
_l_install="${_l_root}/installed"
_l_bin="${_l_root}/bin"
_l_log="${_l_root}/commands.log"
_l_lock_dir="${_l_install}.sdd-install.lock"
_l_orig_path="$PATH"
_l_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_l_bin" "$_l_log"
# Simulate a live lock holder: create lock dir with the current process pid as holder
mkdir -p "$_l_lock_dir"
echo "$$" > "${_l_lock_dir}/pid"
export PATH="${_l_bin}:${_l_orig_path}"
export SDD_CODEX_HOME="${_l_root}/codex-home"
_l_failed=0
_l_out="$(SDD_INSTALL_LOCK_TIMEOUT=1 bash "$INSTALLER" \
    --source-directory "$SOURCE_FIXTURE" \
    --install-root "$_l_install" \
    --target FilesOnly \
    --skip-plugin-install \
    --skip-agent-install \
    2>&1)" || _l_failed=1
export PATH="$_l_orig_path"
if [[ -z "$_l_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_l_orig_codex_home"
fi
_l_ok=1
if [[ $_l_failed -eq 0 ]]; then
    fail "lock scenario (l): installer should have failed when lock held"
    _l_ok=0
fi
if ! echo "$_l_out" | grep -q "in progress"; then
    fail "lock scenario (l): expected 'in progress' message not found in output"
    _l_ok=0
fi
if [[ -d "$_l_install" ]]; then
    fail "lock scenario (l): INSTALL_ROOT was modified while lock was held"
    _l_ok=0
fi
# Now remove the lock and assert a normal install succeeds
rm -rf "$_l_lock_dir"
_l_bin2="${_l_root}/bin2"
_l_log2="${_l_root}/commands2.log"
make_fake_commands "$_l_bin2" "$_l_log2"
export PATH="${_l_bin2}:${_l_orig_path}"
export SDD_CODEX_HOME="${_l_root}/codex-home"
_l_failed2=0
bash "$INSTALLER" \
    --source-directory "$SOURCE_FIXTURE" \
    --install-root "$_l_install" \
    --target FilesOnly \
    --skip-plugin-install \
    --skip-agent-install \
    2>/dev/null || _l_failed2=1
export PATH="$_l_orig_path"
if [[ -z "$_l_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_l_orig_codex_home"
fi
if [[ $_l_failed2 -ne 0 ]]; then
    fail "lock scenario (l): install after lock release failed"
    _l_ok=0
fi
rm -rf "$_l_root"
[[ $_l_ok -eq 1 ]] && ok "lock: concurrent install blocked, succeeds after lock released"

# ---------------------------------------------------------------------------
# Scenario (m): lock released on success — lock dir must not exist after install
# ---------------------------------------------------------------------------
_m_root="$(mktemp -d)"
_m_install="${_m_root}/installed"
_m_bin="${_m_root}/bin"
_m_log="${_m_root}/commands.log"
_m_lock_dir="${_m_install}.sdd-install.lock"
_m_orig_path="$PATH"
_m_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_m_bin" "$_m_log"
export PATH="${_m_bin}:${_m_orig_path}"
export SDD_CODEX_HOME="${_m_root}/codex-home"
_m_failed=0
bash "$INSTALLER" \
    --source-directory "$SOURCE_FIXTURE" \
    --install-root "$_m_install" \
    --target FilesOnly \
    --skip-plugin-install \
    --skip-agent-install \
    2>/dev/null || _m_failed=1
export PATH="$_m_orig_path"
if [[ -z "$_m_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_m_orig_codex_home"
fi
_m_ok=1
if [[ $_m_failed -ne 0 ]]; then
    fail "lock scenario (m): successful install failed unexpectedly"
    _m_ok=0
fi
if [[ -d "$_m_lock_dir" ]]; then
    fail "lock scenario (m): lock dir was not cleaned up after successful install"
    _m_ok=0
fi
rm -rf "$_m_root"
[[ $_m_ok -eq 1 ]] && ok "lock: released on success — lock dir absent after install"

# ---------------------------------------------------------------------------
# Scenario (n): stale lock reclaimed — install succeeds when lock has dead pid
# ---------------------------------------------------------------------------
_n_root="$(mktemp -d)"
_n_install="${_n_root}/installed"
_n_bin="${_n_root}/bin"
_n_log="${_n_root}/commands.log"
_n_lock_dir="${_n_install}.sdd-install.lock"
_n_orig_path="$PATH"
_n_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_n_bin" "$_n_log"
# Pre-create the lock with an invalid owner identifier. Numeric PIDs can be
# recycled immediately in containerized CI, so no numeric value reliably means
# "dead" between writing the lock and starting the installer. The installer
# treats an unreadable owner as stale, which is the recovery path under test.
mkdir -p "$_n_lock_dir"
echo "not-a-live-pid" > "${_n_lock_dir}/pid"
export PATH="${_n_bin}:${_n_orig_path}"
export SDD_CODEX_HOME="${_n_root}/codex-home"
_n_failed=0
bash "$INSTALLER" \
    --source-directory "$SOURCE_FIXTURE" \
    --install-root "$_n_install" \
    --target FilesOnly \
    --skip-plugin-install \
    --skip-agent-install \
    2>/dev/null || _n_failed=1
export PATH="$_n_orig_path"
if [[ -z "$_n_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_n_orig_codex_home"
fi
_n_ok=1
if [[ $_n_failed -ne 0 ]]; then
    fail "lock scenario (n): install with stale dead-pid lock failed"
    _n_ok=0
fi
if [[ -d "$_n_lock_dir" ]]; then
    fail "lock scenario (n): lock dir was not cleaned up after stale-lock reclaim"
    _n_ok=0
fi
rm -rf "$_n_root"
[[ $_n_ok -eq 1 ]] && ok "lock: stale lock with dead pid reclaimed — install succeeds"

# ---------------------------------------------------------------------------
# Scenario (D): post-install functional smoke — run installed check-risk gate
# ---------------------------------------------------------------------------
_d_root="$(mktemp -d)"
_d_install="${_d_root}/installed"
_d_bin="${_d_root}/bin"
_d_log="${_d_root}/commands.log"
_d_orig_path="$PATH"
_d_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_d_bin" "$_d_log"
export PATH="${_d_bin}:${_d_orig_path}"
export SDD_CODEX_HOME="${_d_root}/codex-home"
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_d_install" --target FilesOnly --skip-plugin-install --skip-agent-install 2>/dev/null
export PATH="$_d_orig_path"
if [[ -z "$_d_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_d_orig_codex_home"
fi

_d_gate="${_d_install}/plugins/sdd-quality-loop/scripts/check-risk.sh"
_d_fixtures="${_d_root}/fixtures"
mkdir -p "$_d_fixtures"

# Pass fixture: high-risk task with Required Workflow: tdd
cat > "${_d_fixtures}/pass.md" <<'TASKS'
## T-001
Risk: high
Risk Rationale: affects critical auth path
Required Workflow: tdd
TASKS

# Fail fixture: high-risk task missing Required Workflow: tdd
cat > "${_d_fixtures}/fail.md" <<'TASKS'
## T-001
Risk: high
Risk Rationale: affects critical auth path
TASKS

_d_ok=1

# Assert gate is present and executable
if [[ ! -x "$_d_gate" ]]; then
    fail "smoke (D): installed check-risk.sh not found or not executable at: $_d_gate"
    _d_ok=0
fi

if [[ $_d_ok -eq 1 ]]; then
    # Pass path must exit 0
    if bash "$_d_gate" "${_d_fixtures}/pass.md" 2>/dev/null; then
        ok "smoke (D): installed gate exits 0 for well-formed high+tdd task"
    else
        fail "smoke (D): installed gate unexpectedly failed on well-formed task"
        _d_ok=0
    fi

    # Fail path must exit non-zero
    _d_fail_rc=0
    bash "$_d_gate" "${_d_fixtures}/fail.md" 2>/dev/null || _d_fail_rc=$?
    if [[ $_d_fail_rc -ne 0 ]]; then
        ok "smoke (D): installed gate exits non-zero for high task missing Required Workflow: tdd"
    else
        fail "smoke (D): installed gate incorrectly passed on task missing Required Workflow: tdd"
        _d_ok=0
    fi
fi

rm -rf "$_d_root"

# ---------------------------------------------------------------------------
# Scenario (o): sdd-ship auto-expansion — selecting only sdd-ship triggers
# auto-inclusion of its companions (sdd-bootstrap, sdd-review-loop,
# sdd-implementation, sdd-quality-loop, sdd-lite)
# ---------------------------------------------------------------------------
_o_root="$(mktemp -d)"
_o_install="${_o_root}/installed"
_o_bin="${_o_root}/bin"
_o_log="${_o_root}/commands.log"
_o_orig_path="$PATH"
_o_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_o_bin" "$_o_log"
export PATH="${_o_bin}:${_o_orig_path}"
export SDD_CODEX_HOME="${_o_root}/codex-home"
_o_out="$(bash "$INSTALLER" \
    --source-directory "$SOURCE_FIXTURE" \
    --install-root "$_o_install" \
    --target All \
    --plugins "sdd-ship" \
    2>&1)" || true
export PATH="$_o_orig_path"
if [[ -z "$_o_orig_codex_home" ]]; then
    unset SDD_CODEX_HOME
else
    export SDD_CODEX_HOME="$_o_orig_codex_home"
fi
_o_ok=1
# All companion plugins must be present in install root
for p in sdd-bootstrap sdd-ship sdd-implementation sdd-quality-loop sdd-lite sdd-review-loop; do
    if [[ ! -f "${_o_install}/plugins/${p}/.codex-plugin/plugin.json" ]]; then
        fail "sdd-ship expansion (o): companion plugin not installed: $p"
        _o_ok=0
    fi
done
# Warning message should mention auto-included companions
if ! echo "$_o_out" | grep -qi "auto-included"; then
    fail "sdd-ship expansion (o): expected 'auto-included' warning not found"
    _o_ok=0
fi
rm -rf "$_o_root"
[[ $_o_ok -eq 1 ]] && ok "sdd-ship expansion: auto-includes all companion plugins"

# ---------------------------------------------------------------------------
# Scenario (p): marketplace.json contains sdd-ship entry
# ---------------------------------------------------------------------------
_p_ok=1
if ! python3 -c "
import json
with open('${REPO_ROOT}/.claude-plugin/marketplace.json') as f:
    m = json.load(f)
names = [p['name'] for p in m['plugins']]
assert 'sdd-ship' in names, 'sdd-ship not found in marketplace plugins'
assert 'sdd-bootstrap' in names, 'sdd-bootstrap not found in marketplace plugins'
assert 'sdd-review-loop' in names, 'sdd-review-loop not found in marketplace plugins'
" 2>/dev/null; then
    fail "marketplace (p): sdd-ship not present in .claude-plugin/marketplace.json"
    _p_ok=0
fi
if ! python3 -c "
import json
with open('${REPO_ROOT}/.agents/plugins/marketplace.json') as f:
    m = json.load(f)
names = [p['name'] for p in m['plugins']]
assert 'sdd-ship' in names, 'sdd-ship not found in agents marketplace plugins'
assert 'sdd-review-loop' in names, 'sdd-review-loop not found in agents marketplace plugins'
" 2>/dev/null; then
    fail "marketplace (p): sdd-ship not present in .agents/plugins/marketplace.json"
    _p_ok=0
fi
[[ $_p_ok -eq 1 ]] && ok "marketplace: sdd-ship entry present in both marketplace files"

# ---------------------------------------------------------------------------
# Scenario (q): sdd-ship required paths exist in source
# ---------------------------------------------------------------------------
_q_ok=1
for path in \
    "plugins/sdd-ship/.claude-plugin/plugin.json" \
    "plugins/sdd-ship/.codex-plugin/plugin.json" \
    "plugins/sdd-ship/.plugin/plugin.json" \
    "plugins/sdd-ship/skills/ship/SKILL.md"; do
    if [[ ! -f "${REPO_ROOT}/${path}" ]]; then
        fail "sdd-ship required paths (q): missing: $path"
        _q_ok=0
    fi
done
[[ $_q_ok -eq 1 ]] && ok "sdd-ship required paths: all plugin files present"

# ---------------------------------------------------------------------------
# Scenario (r): sdd-review-loop has distributable manifests and both skills
# ---------------------------------------------------------------------------
_r_ok=1
for path in \
    "plugins/sdd-review-loop/.claude-plugin/plugin.json" \
    "plugins/sdd-review-loop/.codex-plugin/plugin.json" \
    "plugins/sdd-review-loop/.plugin/plugin.json" \
    "plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md" \
    "plugins/sdd-review-loop/skills/task-review-loop/SKILL.md"; do
    if [[ ! -f "${REPO_ROOT}/${path}" ]]; then
        fail "sdd-review-loop required paths (r): missing: $path"
        _r_ok=0
    fi
done
[[ $_r_ok -eq 1 ]] && ok "sdd-review-loop required paths: manifests and skills present"

# ---------------------------------------------------------------------------
# Scenario (s): Claude manifest validation must fail before marketplace add.
# ---------------------------------------------------------------------------
_s_root="$(mktemp -d)"
_s_install="${_s_root}/installed"
_s_bin="${_s_root}/bin"
_s_log="${_s_root}/commands.log"
_s_orig_path="$PATH"
make_fake_commands "$_s_bin" "$_s_log" "plugin validate"
export PATH="${_s_bin}:${_s_orig_path}"
_s_failed=0
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_s_install" --target Claude --plugins "sdd-bootstrap" 2>/dev/null || _s_failed=1
export PATH="$_s_orig_path"
_s_ok=1
if [[ $_s_failed -eq 0 ]]; then
    fail "Claude validation (s): installer succeeded after manifest validation failure"
    _s_ok=0
fi
if ! grep -qF "claude plugin validate" "$_s_log"; then
    fail "Claude validation (s): validation command was not invoked"
    _s_ok=0
fi
if grep -qF "claude plugin marketplace add" "$_s_log"; then
    fail "Claude validation (s): marketplace was registered before validation passed"
    _s_ok=0
fi
rm -rf "$_s_root"
[[ $_s_ok -eq 1 ]] && ok "Claude manifest validation fails before marketplace registration"

# ---------------------------------------------------------------------------
# MCP scenarios (T-006): AC-007 / AC-008
# ---------------------------------------------------------------------------

# Scenario (t): default install places the MCP payload and registers it with
# Claude/Codex (best-effort via fake shims), excluding node_modules/src/tests.
_t_root="$(mktemp -d)"
_t_install="${_t_root}/installed"
_t_bin="${_t_root}/bin"
_t_log="${_t_root}/commands.log"
_t_orig_path="$PATH"
_t_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_t_bin" "$_t_log"
export PATH="${_t_bin}:${_t_orig_path}"
export SDD_CODEX_HOME="${_t_root}/codex-home"
mkdir -p "$SDD_CODEX_HOME"
touch "${SDD_CODEX_HOME}/config.toml"
_t_failed=0
_t_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_t_install" --target All --skip-agent-install 2>&1)" || _t_failed=1
export PATH="$_t_orig_path"
if [[ -z "$_t_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_t_orig_codex_home"; fi
_t_ok=1
[[ $_t_failed -eq 0 ]] || { fail "default MCP install (t): installer exited non-zero"; _t_ok=0; }
[[ -f "${_t_install}/mcp/sdd-forge-mcp/dist/index.js" ]] || { fail "default MCP install (t): dist/index.js not placed"; _t_ok=0; }
[[ -f "${_t_install}/mcp/sdd-forge-mcp/package.json" ]] || { fail "default MCP install (t): package.json not placed"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/sdd-forge-mcp/node_modules" ]] || { fail "default MCP install (t): node_modules was copied"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/sdd-forge-mcp/src" ]] || { fail "default MCP install (t): src/ was copied"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/sdd-forge-mcp/tests" ]] || { fail "default MCP install (t): tests/ was copied"; _t_ok=0; }
# AC-009 behavior (1): default install ALSO places the local-env-mcp payload.
[[ -f "${_t_install}/mcp/local-env-mcp/dist/index.js" ]] || { fail "default MCP install (t): local-env-mcp dist/index.js not placed"; _t_ok=0; }
[[ -f "${_t_install}/mcp/local-env-mcp/package.json" ]] || { fail "default MCP install (t): local-env-mcp package.json not placed"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/local-env-mcp/node_modules" ]] || { fail "default MCP install (t): local-env-mcp node_modules was copied"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/local-env-mcp/src" ]] || { fail "default MCP install (t): local-env-mcp src/ was copied"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/local-env-mcp/tests" ]] || { fail "default MCP install (t): local-env-mcp tests/ was copied"; _t_ok=0; }
# AC-016 behavior: default install ALSO places the ci-mcp payload (default
# bundled per T-009).
[[ -f "${_t_install}/mcp/ci-mcp/dist/index.js" ]] || { fail "default MCP install (t): ci-mcp dist/index.js not placed"; _t_ok=0; }
[[ -f "${_t_install}/mcp/ci-mcp/package.json" ]] || { fail "default MCP install (t): ci-mcp package.json not placed"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/ci-mcp/node_modules" ]] || { fail "default MCP install (t): ci-mcp node_modules was copied"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/ci-mcp/src" ]] || { fail "default MCP install (t): ci-mcp src/ was copied"; _t_ok=0; }
[[ ! -e "${_t_install}/mcp/ci-mcp/tests" ]] || { fail "default MCP install (t): ci-mcp tests/ was copied"; _t_ok=0; }
if [[ -f "$_t_log" ]]; then
    grep -qF "claude mcp add sdd-forge-mcp" "$_t_log" || { fail "default MCP install (t): claude mcp add not invoked for sdd-forge-mcp"; _t_ok=0; }
    grep -qF "claude mcp add local-env-mcp" "$_t_log" || { fail "default MCP install (t): claude mcp add not invoked for local-env-mcp"; _t_ok=0; }
    grep -qF "claude mcp add ci-mcp" "$_t_log" || { fail "default MCP install (t): claude mcp add not invoked for ci-mcp"; _t_ok=0; }
fi
_t_toml="${SDD_CODEX_HOME:-}"
if grep -q "sdd-forge-mcp" "${_t_root}/codex-home/config.toml" 2>/dev/null; then
    :
else
    fail "default MCP install (t): Codex config.toml missing sdd-forge-mcp entry"
    _t_ok=0
fi
if grep -q "local-env-mcp" "${_t_root}/codex-home/config.toml" 2>/dev/null; then
    :
else
    fail "default MCP install (t): Codex config.toml missing local-env-mcp entry"
    _t_ok=0
fi
if grep -q "ci-mcp" "${_t_root}/codex-home/config.toml" 2>/dev/null; then
    :
else
    fail "default MCP install (t): Codex config.toml missing ci-mcp entry"
    _t_ok=0
fi
# AC-016: the installer must guide the user to the read-only PAT env vars
# ci-mcp needs, without ever writing a token value anywhere.
if ! echo "$_t_out" | grep -qF "CI_MCP_GITHUB_TOKEN"; then
    fail "default MCP install (t): missing ci-mcp token env var guidance (CI_MCP_GITHUB_TOKEN)"
    _t_ok=0
fi
if ! echo "$_t_out" | grep -qF "GH_READONLY_TOKEN"; then
    fail "default MCP install (t): missing ci-mcp token env var guidance (GH_READONLY_TOKEN)"
    _t_ok=0
fi
if ! echo "$_t_out" | grep -qF "GITHUB_TOKEN"; then
    fail "default MCP install (t): missing ci-mcp token env var guidance (GITHUB_TOKEN)"
    _t_ok=0
fi
rm -rf "$_t_root"
[[ $_t_ok -eq 1 ]] && ok "default install places and registers ALL THREE MCP servers, with ci-mcp token guidance"

# Scenario (u): --skip-mcp skips both placement and registration.
_u_root="$(mktemp -d)"
_u_install="${_u_root}/installed"
_u_bin="${_u_root}/bin"
_u_log="${_u_root}/commands.log"
_u_orig_path="$PATH"
_u_orig_codex_home="${SDD_CODEX_HOME:-}"
_u_orig_cursor_dir="${SDD_CURSOR_DIR:-}"
_u_orig_vscode_dir="${SDD_VSCODE_USER_DIR:-}"
make_fake_commands "$_u_bin" "$_u_log"
export PATH="${_u_bin}:${_u_orig_path}"
export SDD_CODEX_HOME="${_u_root}/codex-home"
mkdir -p "$SDD_CODEX_HOME"
touch "${SDD_CODEX_HOME}/config.toml"
# T-007 gating: seeded Cursor / VS Code configs must be untouched by --skip-mcp.
export SDD_CURSOR_DIR="${_u_root}/cursor"
export SDD_VSCODE_USER_DIR="${_u_root}/vscode-user"
mkdir -p "$SDD_CURSOR_DIR" "$SDD_VSCODE_USER_DIR"
printf '{\n  "mcpServers": {}\n}\n' > "${_u_root}/cursor/mcp.json"
printf '{\n  "servers": {}\n}\n' > "${_u_root}/vscode-user/mcp.json"
cp "${_u_root}/cursor/mcp.json" "${_u_root}/cursor-before.json"
cp "${_u_root}/vscode-user/mcp.json" "${_u_root}/vscode-before.json"
_u_failed=0
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_u_install" --target All --skip-agent-install --skip-mcp 2>/dev/null || _u_failed=1
export PATH="$_u_orig_path"
if [[ -z "$_u_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_u_orig_codex_home"; fi
if [[ -z "$_u_orig_cursor_dir" ]]; then unset SDD_CURSOR_DIR; else export SDD_CURSOR_DIR="$_u_orig_cursor_dir"; fi
if [[ -z "$_u_orig_vscode_dir" ]]; then unset SDD_VSCODE_USER_DIR; else export SDD_VSCODE_USER_DIR="$_u_orig_vscode_dir"; fi
_u_ok=1
[[ $_u_failed -eq 0 ]] || { fail "--skip-mcp (u): installer exited non-zero"; _u_ok=0; }
[[ ! -e "${_u_install}/mcp" ]] || { fail "--skip-mcp (u): mcp/ was placed despite --skip-mcp"; _u_ok=0; }
if [[ -f "$_u_log" ]] && grep -qF "claude mcp add" "$_u_log"; then
    fail "--skip-mcp (u): claude mcp add was invoked despite --skip-mcp"
    _u_ok=0
fi
if grep -q "sdd-forge-mcp" "${_u_root}/codex-home/config.toml" 2>/dev/null; then
    fail "--skip-mcp (u): Codex config.toml was modified despite --skip-mcp"
    _u_ok=0
fi
cmp -s "${_u_root}/cursor-before.json" "${_u_root}/cursor/mcp.json" || { fail "--skip-mcp (u): Cursor mcp.json was modified despite --skip-mcp"; _u_ok=0; }
cmp -s "${_u_root}/vscode-before.json" "${_u_root}/vscode-user/mcp.json" || { fail "--skip-mcp (u): VS Code mcp.json was modified despite --skip-mcp"; _u_ok=0; }
rm -rf "$_u_root"
[[ $_u_ok -eq 1 ]] && ok "--skip-mcp skips both MCP placement and registration"

# Scenario (v): --mcp sdd-forge-mcp installs; --mcp bogus is rejected with usage.
_v_root="$(mktemp -d)"
_v_install="${_v_root}/installed"
_v_bin="${_v_root}/bin"
_v_log="${_v_root}/commands.log"
_v_orig_path="$PATH"
make_fake_commands "$_v_bin" "$_v_log"
export PATH="${_v_bin}:${_v_orig_path}"
_v_failed=0
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_v_install" --target FilesOnly --mcp "sdd-forge-mcp" 2>/dev/null || _v_failed=1
export PATH="$_v_orig_path"
_v_ok=1
[[ $_v_failed -eq 0 ]] || { fail "--mcp sdd-forge-mcp (v): installer exited non-zero"; _v_ok=0; }
[[ -f "${_v_install}/mcp/sdd-forge-mcp/dist/index.js" ]] || { fail "--mcp sdd-forge-mcp (v): dist/index.js not placed"; _v_ok=0; }
# AC-009 behavior (2): selecting only sdd-forge-mcp must NOT place local-env-mcp.
[[ ! -e "${_v_install}/mcp/local-env-mcp" ]] || { fail "--mcp sdd-forge-mcp (v): local-env-mcp was placed despite not being selected"; _v_ok=0; }
# AC-016 behavior: selecting only sdd-forge-mcp must NOT place ci-mcp either.
[[ ! -e "${_v_install}/mcp/ci-mcp" ]] || { fail "--mcp sdd-forge-mcp (v): ci-mcp was placed despite not being selected"; _v_ok=0; }
rm -rf "$_v_root"

# Scenario (v-le): --mcp local-env-mcp is a valid selection that places ONLY
# local-env-mcp (sdd-forge-mcp absent). Confirms local-env-mcp is in VALID_MCPS
# and the machinery honours per-name selection in both directions.
_vle_root="$(mktemp -d)"
_vle_install="${_vle_root}/installed"
_vle_bin="${_vle_root}/bin"
_vle_log="${_vle_root}/commands.log"
_vle_orig_path="$PATH"
make_fake_commands "$_vle_bin" "$_vle_log"
export PATH="${_vle_bin}:${_vle_orig_path}"
_vle_failed=0
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_vle_install" --target FilesOnly --mcp "local-env-mcp" 2>/dev/null || _vle_failed=1
export PATH="$_vle_orig_path"
[[ $_vle_failed -eq 0 ]] || { fail "--mcp local-env-mcp (v-le): installer exited non-zero"; _v_ok=0; }
[[ -f "${_vle_install}/mcp/local-env-mcp/dist/index.js" ]] || { fail "--mcp local-env-mcp (v-le): local-env-mcp dist/index.js not placed"; _v_ok=0; }
[[ ! -e "${_vle_install}/mcp/sdd-forge-mcp" ]] || { fail "--mcp local-env-mcp (v-le): sdd-forge-mcp was placed despite not being selected"; _v_ok=0; }
rm -rf "$_vle_root"

# Scenario (v-ci): --mcp ci-mcp is a valid selection that places ONLY ci-mcp
# (sdd-forge-mcp / local-env-mcp absent). Confirms ci-mcp is in VALID_MCPS and
# the machinery honours per-name selection in both directions (AC-016). The
# token guidance notice must also appear (placement happens regardless of
# --target=FilesOnly).
_vci_root="$(mktemp -d)"
_vci_install="${_vci_root}/installed"
_vci_bin="${_vci_root}/bin"
_vci_log="${_vci_root}/commands.log"
_vci_orig_path="$PATH"
make_fake_commands "$_vci_bin" "$_vci_log"
export PATH="${_vci_bin}:${_vci_orig_path}"
_vci_failed=0
_vci_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_vci_install" --target FilesOnly --mcp "ci-mcp" 2>&1)" || _vci_failed=1
export PATH="$_vci_orig_path"
[[ $_vci_failed -eq 0 ]] || { fail "--mcp ci-mcp (v-ci): installer exited non-zero"; _v_ok=0; }
[[ -f "${_vci_install}/mcp/ci-mcp/dist/index.js" ]] || { fail "--mcp ci-mcp (v-ci): ci-mcp dist/index.js not placed"; _v_ok=0; }
[[ ! -e "${_vci_install}/mcp/sdd-forge-mcp" ]] || { fail "--mcp ci-mcp (v-ci): sdd-forge-mcp was placed despite not being selected"; _v_ok=0; }
[[ ! -e "${_vci_install}/mcp/local-env-mcp" ]] || { fail "--mcp ci-mcp (v-ci): local-env-mcp was placed despite not being selected"; _v_ok=0; }
if ! echo "$_vci_out" | grep -qF "CI_MCP_GITHUB_TOKEN"; then
    fail "--mcp ci-mcp (v-ci): missing token env var guidance even with --target=FilesOnly"
    _v_ok=0
fi
rm -rf "$_vci_root"

_v2_root="$(mktemp -d)"
_v2_failed=0
_v2_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "${_v2_root}/installed" --target FilesOnly --mcp "bogus-mcp" 2>&1)" || _v2_failed=1
rm -rf "$_v2_root"
if [[ $_v2_failed -eq 0 ]]; then
    fail "--mcp bogus-mcp (v2): installer accepted an invalid MCP name"
    _v_ok=0
fi
if ! echo "$_v2_out" | grep -qi "mcp"; then
    fail "--mcp bogus-mcp (v2): usage/error output did not mention mcp"
    _v_ok=0
fi

# Scenario (v3): --mcp "" (empty value) is rejected cleanly rather than
# crashing with an "unbound variable" error under bash 3.2's set -u, where a
# zero-element array produced by `read -ra` on empty input is treated as unset.
_v3_root="$(mktemp -d)"
_v3_failed=0
_v3_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "${_v3_root}/installed" --target FilesOnly --mcp "" 2>&1)" || _v3_failed=1
rm -rf "$_v3_root"
if [[ $_v3_failed -eq 0 ]]; then
    fail "--mcp \"\" (v3): installer accepted an empty MCP list"
    _v_ok=0
fi
if echo "$_v3_out" | grep -qi "unbound variable"; then
    fail "--mcp \"\" (v3): installer crashed with an unbound variable error"
    _v_ok=0
fi
if ! echo "$_v3_out" | grep -qi "mcp"; then
    fail "--mcp \"\" (v3): usage/error output did not mention mcp"
    _v_ok=0
fi
[[ $_v_ok -eq 1 ]] && ok "--mcp <list> installs valid names and rejects invalid/empty ones"

# Scenario (v4): --plugins "" (empty value) is rejected cleanly rather than
# crashing with an "unbound variable" error under bash 3.2's set -u, where a
# zero-element array produced by `read -ra` on empty input is treated as unset.
_v4_root="$(mktemp -d)"
_v4_failed=0
_v4_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "${_v4_root}/installed" --target FilesOnly --plugins "" 2>&1)" || _v4_failed=1
rm -rf "$_v4_root"
_v4_ok=1
if [[ $_v4_failed -eq 0 ]]; then
    fail "--plugins \"\" (v4): installer accepted an empty plugin list"
    _v4_ok=0
fi
if echo "$_v4_out" | grep -qi "unbound variable"; then
    fail "--plugins \"\" (v4): installer crashed with an unbound variable error"
    _v4_ok=0
fi
if ! echo "$_v4_out" | grep -qi "plugin"; then
    fail "--plugins \"\" (v4): error output did not mention plugin"
    _v4_ok=0
fi
[[ $_v4_ok -eq 1 ]] && ok "--plugins \"\" is rejected cleanly without an unbound variable crash"

# Scenario (w): missing Node >= 20 warns and skips MCP only; plugins still install.
_w_root="$(mktemp -d)"
_w_install="${_w_root}/installed"
_w_bin="${_w_root}/bin"
_w_log="${_w_root}/commands.log"
_w_orig_path="$PATH"
make_fake_commands "$_w_bin" "$_w_log"
# Shadow `node` with a fake old-version binary ahead of the real one on PATH.
cat > "${_w_bin}/node" <<'NODESHIM'
#!/bin/sh
if [ "$1" = "--version" ]; then
    echo "v14.21.0"
    exit 0
fi
exit 0
NODESHIM
chmod +x "${_w_bin}/node"
export PATH="${_w_bin}:${_w_orig_path}"
_w_failed=0
_w_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_w_install" --target FilesOnly 2>&1)" || _w_failed=1
export PATH="$_w_orig_path"
_w_ok=1
[[ $_w_failed -eq 0 ]] || { fail "old Node (w): installer exited non-zero despite MCP-only skip"; _w_ok=0; }
[[ ! -e "${_w_install}/mcp" ]] || { fail "old Node (w): MCP was placed despite Node < 20"; _w_ok=0; }
for p in $ALL_PLUGINS; do
    [[ -f "${_w_install}/plugins/${p}/.codex-plugin/plugin.json" ]] || { fail "old Node (w): plugin not copied despite MCP-only skip: $p"; _w_ok=0; }
done
if ! echo "$_w_out" | grep -qi "node"; then
    fail "old Node (w): expected warning mentioning Node was not printed"
    _w_ok=0
fi
rm -rf "$_w_root"
[[ $_w_ok -eq 1 ]] && ok "Node < 20 warns and skips MCP only, plugin install continues"

# Scenario (w2): Node < 20 edge at the boundary (v18.x) for the DEFAULT
# multi-MCP install. requirements.md Edge Cases: "Node < 20 → 既存の MCP 配置
# ゲート(MCP_NODE_OK)により配置・登録とも行わない". A v18.x shim ahead of the
# real node on PATH must cause NO placement of EITHER MCP and NO Claude/Codex
# registration, while a warning mentioning Node is printed. --target All +
# fake claude/codex shims + a present config.toml would otherwise register.
_w2_root="$(mktemp -d)"
_w2_install="${_w2_root}/installed"
_w2_bin="${_w2_root}/bin"
_w2_log="${_w2_root}/commands.log"
_w2_orig_path="$PATH"
_w2_orig_codex_home="${SDD_CODEX_HOME:-}"
_w2_orig_cursor_dir="${SDD_CURSOR_DIR:-}"
_w2_orig_vscode_dir="${SDD_VSCODE_USER_DIR:-}"
make_fake_commands "$_w2_bin" "$_w2_log"
# Shadow `node` with a fake v18.x binary ahead of the real one on PATH.
cat > "${_w2_bin}/node" <<'NODESHIM2'
#!/bin/sh
if [ "$1" = "--version" ]; then
    echo "v18.19.0"
    exit 0
fi
exit 0
NODESHIM2
chmod +x "${_w2_bin}/node"
export PATH="${_w2_bin}:${_w2_orig_path}"
export SDD_CODEX_HOME="${_w2_root}/codex-home"
mkdir -p "$SDD_CODEX_HOME"
touch "${SDD_CODEX_HOME}/config.toml"
# T-007 gating: seeded Cursor / VS Code configs must be untouched when Node < 20.
export SDD_CURSOR_DIR="${_w2_root}/cursor"
export SDD_VSCODE_USER_DIR="${_w2_root}/vscode-user"
mkdir -p "$SDD_CURSOR_DIR" "$SDD_VSCODE_USER_DIR"
printf '{\n  "mcpServers": {}\n}\n' > "${_w2_root}/cursor/mcp.json"
printf '{\n  "servers": {}\n}\n' > "${_w2_root}/vscode-user/mcp.json"
cp "${_w2_root}/cursor/mcp.json" "${_w2_root}/cursor-before.json"
cp "${_w2_root}/vscode-user/mcp.json" "${_w2_root}/vscode-before.json"
_w2_failed=0
_w2_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_w2_install" --target All --skip-agent-install 2>&1)" || _w2_failed=1
export PATH="$_w2_orig_path"
if [[ -z "$_w2_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_w2_orig_codex_home"; fi
if [[ -z "$_w2_orig_cursor_dir" ]]; then unset SDD_CURSOR_DIR; else export SDD_CURSOR_DIR="$_w2_orig_cursor_dir"; fi
if [[ -z "$_w2_orig_vscode_dir" ]]; then unset SDD_VSCODE_USER_DIR; else export SDD_VSCODE_USER_DIR="$_w2_orig_vscode_dir"; fi
_w2_ok=1
[[ $_w2_failed -eq 0 ]] || { fail "old Node v18 (w2): installer exited non-zero despite MCP-only skip"; _w2_ok=0; }
[[ ! -e "${_w2_install}/mcp" ]] || { fail "old Node v18 (w2): MCP was placed despite Node < 20"; _w2_ok=0; }
if [[ -f "$_w2_log" ]] && grep -qF "claude mcp add" "$_w2_log"; then
    fail "old Node v18 (w2): claude mcp add was invoked despite Node < 20"
    _w2_ok=0
fi
if grep -qE "sdd-forge-mcp|local-env-mcp|ci-mcp" "${_w2_root}/codex-home/config.toml" 2>/dev/null; then
    fail "old Node v18 (w2): Codex config.toml was modified despite Node < 20"
    _w2_ok=0
fi
cmp -s "${_w2_root}/cursor-before.json" "${_w2_root}/cursor/mcp.json" || { fail "old Node v18 (w2): Cursor mcp.json was modified despite Node < 20"; _w2_ok=0; }
cmp -s "${_w2_root}/vscode-before.json" "${_w2_root}/vscode-user/mcp.json" || { fail "old Node v18 (w2): VS Code mcp.json was modified despite Node < 20"; _w2_ok=0; }
if ! echo "$_w2_out" | grep -qi "node"; then
    fail "old Node v18 (w2): expected warning mentioning Node was not printed"
    _w2_ok=0
fi
rm -rf "$_w2_root"
[[ $_w2_ok -eq 1 ]] && ok "Node v18.x skips MCP placement and registration for both MCPs, with a warning"

# Scenario (x): Codex config.toml absent — MCP registration for Codex is
# skipped with a warning rather than creating a new config.toml.
_x_root="$(mktemp -d)"
_x_install="${_x_root}/installed"
_x_bin="${_x_root}/bin"
_x_log="${_x_root}/commands.log"
_x_orig_path="$PATH"
_x_orig_codex_home="${SDD_CODEX_HOME:-}"
make_fake_commands "$_x_bin" "$_x_log"
export PATH="${_x_bin}:${_x_orig_path}"
export SDD_CODEX_HOME="${_x_root}/codex-home-missing"
_x_failed=0
_x_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_x_install" --target All --skip-agent-install 2>&1)" || _x_failed=1
export PATH="$_x_orig_path"
if [[ -z "$_x_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_x_orig_codex_home"; fi
_x_ok=1
[[ $_x_failed -eq 0 ]] || { fail "missing config.toml (x): installer exited non-zero"; _x_ok=0; }
[[ ! -f "${_x_root}/codex-home-missing/config.toml" ]] || { fail "missing config.toml (x): installer created a new config.toml"; _x_ok=0; }
if ! echo "$_x_out" | grep -qi "config.toml"; then
    fail "missing config.toml (x): expected warning about missing config.toml not printed"
    _x_ok=0
fi
rm -rf "$_x_root"
[[ $_x_ok -eq 1 ]] && ok "missing Codex config.toml skips Codex MCP registration with a warning"

# ---------------------------------------------------------------------------
# MCP scenarios (T-007): AC-010 / AC-011 / AC-015 — Cursor / VS Code upsert
# ---------------------------------------------------------------------------

# Scenario (y): AC-010 Cursor registration. A pre-existing ~/.cursor/mcp.json
# containing a foreign entry and an unknown top-level key keeps both; the two
# selected MCPs are upserted under mcpServers.<name> as
# { command: "node", args: [<install-root>/mcp/<name>/dist/index.js] }; a
# second run is byte-identical (idempotent). The VS Code user dir is absent in
# this scenario, so VS Code registration is skipped with a notice and the
# directory is never created.
_y_root="$(mktemp -d)"
_y_install="${_y_root}/installed"
_y_bin="${_y_root}/bin"
_y_log="${_y_root}/commands.log"
_y_orig_path="$PATH"
_y_orig_codex_home="${SDD_CODEX_HOME:-}"
_y_orig_cursor_dir="${SDD_CURSOR_DIR:-}"
_y_orig_vscode_dir="${SDD_VSCODE_USER_DIR:-}"
make_fake_commands "$_y_bin" "$_y_log"
export PATH="${_y_bin}:${_y_orig_path}"
export SDD_CODEX_HOME="${_y_root}/codex-home"
mkdir -p "$SDD_CODEX_HOME"
touch "${SDD_CODEX_HOME}/config.toml"
export SDD_CURSOR_DIR="${_y_root}/cursor"
export SDD_VSCODE_USER_DIR="${_y_root}/vscode-user-missing"
mkdir -p "$SDD_CURSOR_DIR"
cat > "${_y_root}/cursor/mcp.json" <<'CURSORSEED'
{
  "mcpServers": {
    "user-defined-mcp": {
      "command": "python3",
      "args": ["/opt/user/mcp.py"]
    }
  },
  "unknownTopLevelKey": { "keep": true }
}
CURSORSEED
_y_failed=0
_y_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_y_install" --target All --skip-agent-install 2>&1)" || _y_failed=1
cp "${_y_root}/cursor/mcp.json" "${_y_root}/cursor-after-first.json" 2>/dev/null || true
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_y_install" --target All --skip-agent-install >/dev/null 2>&1 || _y_failed=1
export PATH="$_y_orig_path"
if [[ -z "$_y_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_y_orig_codex_home"; fi
if [[ -z "$_y_orig_cursor_dir" ]]; then unset SDD_CURSOR_DIR; else export SDD_CURSOR_DIR="$_y_orig_cursor_dir"; fi
if [[ -z "$_y_orig_vscode_dir" ]]; then unset SDD_VSCODE_USER_DIR; else export SDD_VSCODE_USER_DIR="$_y_orig_vscode_dir"; fi
_y_ok=1
[[ $_y_failed -eq 0 ]] || { fail "cursor upsert (y): installer exited non-zero"; _y_ok=0; }
node -e '
const c = require(process.argv[1]);
const s = c.mcpServers || {};
const f = s["user-defined-mcp"];
if (!f || f.command !== "python3" || !Array.isArray(f.args) || f.args[0] !== "/opt/user/mcp.py") process.exit(1);
for (const n of ["sdd-forge-mcp", "local-env-mcp", "ci-mcp"]) {
  const e = s[n];
  if (!e || e.command !== "node" || !Array.isArray(e.args) || e.args.length !== 1) process.exit(1);
  if (!e.args[0].endsWith("/mcp/" + n + "/dist/index.js")) process.exit(1);
}
if (!c.unknownTopLevelKey || c.unknownTopLevelKey.keep !== true) process.exit(1);
' "${_y_root}/cursor/mcp.json" 2>/dev/null || { fail "cursor upsert (y): mcp.json missing managed entries, foreign entry, or unknown top-level key"; _y_ok=0; }
cmp -s "${_y_root}/cursor-after-first.json" "${_y_root}/cursor/mcp.json" || { fail "cursor upsert (y): second run is not byte-identical (not idempotent)"; _y_ok=0; }
[[ ! -e "${_y_root}/vscode-user-missing" ]] || { fail "cursor upsert (y): absent VS Code user dir was created"; _y_ok=0; }
if ! echo "$_y_out" | grep -qi "vs code"; then
    fail "cursor upsert (y): expected VS Code skip notice for absent user dir not printed"
    _y_ok=0
fi
rm -rf "$_y_root"
[[ $_y_ok -eq 1 ]] && ok "Cursor mcp.json upsert preserves foreign entries, is idempotent, and absent VS Code dir is skipped with a notice"

# Scenario (z): AC-011 VS Code registration. A pre-existing user-profile
# mcp.json (via SDD_VSCODE_USER_DIR) containing a foreign entry and an unknown
# top-level key keeps both; the two selected MCPs are upserted under
# servers.<name> as { type: "stdio", command: "node", args: [...] }; a second
# run is byte-identical. The Cursor dir is absent in this scenario, so Cursor
# registration is skipped with a notice and the directory is never created.
_z_root="$(mktemp -d)"
_z_install="${_z_root}/installed"
_z_bin="${_z_root}/bin"
_z_log="${_z_root}/commands.log"
_z_orig_path="$PATH"
_z_orig_codex_home="${SDD_CODEX_HOME:-}"
_z_orig_cursor_dir="${SDD_CURSOR_DIR:-}"
_z_orig_vscode_dir="${SDD_VSCODE_USER_DIR:-}"
make_fake_commands "$_z_bin" "$_z_log"
export PATH="${_z_bin}:${_z_orig_path}"
export SDD_CODEX_HOME="${_z_root}/codex-home"
mkdir -p "$SDD_CODEX_HOME"
touch "${SDD_CODEX_HOME}/config.toml"
export SDD_CURSOR_DIR="${_z_root}/cursor-missing"
export SDD_VSCODE_USER_DIR="${_z_root}/vscode-user"
mkdir -p "$SDD_VSCODE_USER_DIR"
cat > "${_z_root}/vscode-user/mcp.json" <<'VSCODESEED'
{
  "servers": {
    "user-defined-mcp": {
      "type": "stdio",
      "command": "python3",
      "args": ["/opt/user/mcp.py"]
    }
  },
  "inputs": [{ "id": "keep-me", "type": "promptString" }]
}
VSCODESEED
_z_failed=0
_z_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_z_install" --target All --skip-agent-install 2>&1)" || _z_failed=1
cp "${_z_root}/vscode-user/mcp.json" "${_z_root}/vscode-after-first.json" 2>/dev/null || true
bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_z_install" --target All --skip-agent-install >/dev/null 2>&1 || _z_failed=1
export PATH="$_z_orig_path"
if [[ -z "$_z_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_z_orig_codex_home"; fi
if [[ -z "$_z_orig_cursor_dir" ]]; then unset SDD_CURSOR_DIR; else export SDD_CURSOR_DIR="$_z_orig_cursor_dir"; fi
if [[ -z "$_z_orig_vscode_dir" ]]; then unset SDD_VSCODE_USER_DIR; else export SDD_VSCODE_USER_DIR="$_z_orig_vscode_dir"; fi
_z_ok=1
[[ $_z_failed -eq 0 ]] || { fail "vscode upsert (z): installer exited non-zero"; _z_ok=0; }
node -e '
const c = require(process.argv[1]);
const s = c.servers || {};
const f = s["user-defined-mcp"];
if (!f || f.command !== "python3" || !Array.isArray(f.args) || f.args[0] !== "/opt/user/mcp.py") process.exit(1);
for (const n of ["sdd-forge-mcp", "local-env-mcp", "ci-mcp"]) {
  const e = s[n];
  if (!e || e.type !== "stdio" || e.command !== "node" || !Array.isArray(e.args) || e.args.length !== 1) process.exit(1);
  if (!e.args[0].endsWith("/mcp/" + n + "/dist/index.js")) process.exit(1);
}
if (!Array.isArray(c.inputs) || c.inputs.length !== 1 || c.inputs[0].id !== "keep-me") process.exit(1);
' "${_z_root}/vscode-user/mcp.json" 2>/dev/null || { fail "vscode upsert (z): mcp.json missing managed entries, foreign entry, or unknown top-level key"; _z_ok=0; }
cmp -s "${_z_root}/vscode-after-first.json" "${_z_root}/vscode-user/mcp.json" || { fail "vscode upsert (z): second run is not byte-identical (not idempotent)"; _z_ok=0; }
[[ ! -e "${_z_root}/cursor-missing" ]] || { fail "vscode upsert (z): absent Cursor dir was created"; _z_ok=0; }
if ! echo "$_z_out" | grep -qi "cursor"; then
    fail "vscode upsert (z): expected Cursor skip notice for absent dir not printed"
    _z_ok=0
fi
rm -rf "$_z_root"
[[ $_z_ok -eq 1 ]] && ok "VS Code mcp.json upsert preserves foreign entries, is idempotent, and absent Cursor dir is skipped with a notice"

# Scenario (aa): AC-015 corrupted Cursor mcp.json. The installer must not
# modify the corrupt file (byte-identical), must print an error notice, must
# still register the OTHER client (VS Code), and must exit zero.
_aa_root="$(mktemp -d)"
_aa_install="${_aa_root}/installed"
_aa_bin="${_aa_root}/bin"
_aa_log="${_aa_root}/commands.log"
_aa_orig_path="$PATH"
_aa_orig_codex_home="${SDD_CODEX_HOME:-}"
_aa_orig_cursor_dir="${SDD_CURSOR_DIR:-}"
_aa_orig_vscode_dir="${SDD_VSCODE_USER_DIR:-}"
make_fake_commands "$_aa_bin" "$_aa_log"
export PATH="${_aa_bin}:${_aa_orig_path}"
export SDD_CODEX_HOME="${_aa_root}/codex-home"
mkdir -p "$SDD_CODEX_HOME"
touch "${SDD_CODEX_HOME}/config.toml"
export SDD_CURSOR_DIR="${_aa_root}/cursor"
export SDD_VSCODE_USER_DIR="${_aa_root}/vscode-user"
mkdir -p "$SDD_CURSOR_DIR" "$SDD_VSCODE_USER_DIR"
printf '{ "mcpServers": { "broken"\n' > "${_aa_root}/cursor/mcp.json"
cp "${_aa_root}/cursor/mcp.json" "${_aa_root}/cursor-before.json"
_aa_failed=0
_aa_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_aa_install" --target All --skip-agent-install 2>&1)" || _aa_failed=1
export PATH="$_aa_orig_path"
if [[ -z "$_aa_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_aa_orig_codex_home"; fi
if [[ -z "$_aa_orig_cursor_dir" ]]; then unset SDD_CURSOR_DIR; else export SDD_CURSOR_DIR="$_aa_orig_cursor_dir"; fi
if [[ -z "$_aa_orig_vscode_dir" ]]; then unset SDD_VSCODE_USER_DIR; else export SDD_VSCODE_USER_DIR="$_aa_orig_vscode_dir"; fi
_aa_ok=1
[[ $_aa_failed -eq 0 ]] || { fail "corrupt cursor JSON (aa): installer exited non-zero"; _aa_ok=0; }
cmp -s "${_aa_root}/cursor-before.json" "${_aa_root}/cursor/mcp.json" || { fail "corrupt cursor JSON (aa): corrupt mcp.json was modified"; _aa_ok=0; }
if ! echo "$_aa_out" | grep -qi "invalid"; then
    fail "corrupt cursor JSON (aa): expected invalid-JSON error notice not printed"
    _aa_ok=0
fi
node -e '
const c = require(process.argv[1]);
const s = c.servers || {};
for (const n of ["sdd-forge-mcp", "local-env-mcp", "ci-mcp"]) {
  const e = s[n];
  if (!e || e.type !== "stdio" || e.command !== "node") process.exit(1);
}
' "${_aa_root}/vscode-user/mcp.json" 2>/dev/null || { fail "corrupt cursor JSON (aa): VS Code registration did not continue"; _aa_ok=0; }
rm -rf "$_aa_root"
[[ $_aa_ok -eq 1 ]] && ok "corrupt Cursor mcp.json is left unmodified with an error notice and VS Code registration continues"

# Scenario (ab): AC-015 corrupted VS Code mcp.json — symmetric to (aa): the
# corrupt file is untouched, an error notice is printed, Cursor registration
# continues, and the installer exits zero.
_ab_root="$(mktemp -d)"
_ab_install="${_ab_root}/installed"
_ab_bin="${_ab_root}/bin"
_ab_log="${_ab_root}/commands.log"
_ab_orig_path="$PATH"
_ab_orig_codex_home="${SDD_CODEX_HOME:-}"
_ab_orig_cursor_dir="${SDD_CURSOR_DIR:-}"
_ab_orig_vscode_dir="${SDD_VSCODE_USER_DIR:-}"
make_fake_commands "$_ab_bin" "$_ab_log"
export PATH="${_ab_bin}:${_ab_orig_path}"
export SDD_CODEX_HOME="${_ab_root}/codex-home"
mkdir -p "$SDD_CODEX_HOME"
touch "${SDD_CODEX_HOME}/config.toml"
export SDD_CURSOR_DIR="${_ab_root}/cursor"
export SDD_VSCODE_USER_DIR="${_ab_root}/vscode-user"
mkdir -p "$SDD_CURSOR_DIR" "$SDD_VSCODE_USER_DIR"
printf 'not json at all { ]\n' > "${_ab_root}/vscode-user/mcp.json"
cp "${_ab_root}/vscode-user/mcp.json" "${_ab_root}/vscode-before.json"
_ab_failed=0
_ab_out="$(bash "$INSTALLER" --source-directory "$SOURCE_FIXTURE" --install-root "$_ab_install" --target All --skip-agent-install 2>&1)" || _ab_failed=1
export PATH="$_ab_orig_path"
if [[ -z "$_ab_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_ab_orig_codex_home"; fi
if [[ -z "$_ab_orig_cursor_dir" ]]; then unset SDD_CURSOR_DIR; else export SDD_CURSOR_DIR="$_ab_orig_cursor_dir"; fi
if [[ -z "$_ab_orig_vscode_dir" ]]; then unset SDD_VSCODE_USER_DIR; else export SDD_VSCODE_USER_DIR="$_ab_orig_vscode_dir"; fi
_ab_ok=1
[[ $_ab_failed -eq 0 ]] || { fail "corrupt vscode JSON (ab): installer exited non-zero"; _ab_ok=0; }
cmp -s "${_ab_root}/vscode-before.json" "${_ab_root}/vscode-user/mcp.json" || { fail "corrupt vscode JSON (ab): corrupt mcp.json was modified"; _ab_ok=0; }
if ! echo "$_ab_out" | grep -qi "invalid"; then
    fail "corrupt vscode JSON (ab): expected invalid-JSON error notice not printed"
    _ab_ok=0
fi
node -e '
const c = require(process.argv[1]);
const s = c.mcpServers || {};
for (const n of ["sdd-forge-mcp", "local-env-mcp", "ci-mcp"]) {
  const e = s[n];
  if (!e || e.command !== "node") process.exit(1);
}
' "${_ab_root}/cursor/mcp.json" 2>/dev/null || { fail "corrupt vscode JSON (ab): Cursor registration did not continue"; _ab_ok=0; }
rm -rf "$_ab_root"
[[ $_ab_ok -eq 1 ]] && ok "corrupt VS Code mcp.json is left unmodified with an error notice and Cursor registration continues"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[[ $FAIL -eq 0 ]]
