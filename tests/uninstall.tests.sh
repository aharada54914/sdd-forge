#!/usr/bin/env bash
# uninstall.tests.sh — bash port of uninstall.tests.ps1
# Exercises uninstall.sh without network or real CLIs by stubbing codex/claude/
# copilot with logging shims and simulating an installed layout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNINSTALLER="${REPO_ROOT}/uninstall.sh"
ALL_PLUGINS="sdd-bootstrap sdd-ship sdd-implementation sdd-quality-loop sdd-lite sdd-review-loop"
PASS=0
FAIL=0

ok() { echo "ok: $*"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# Create fake codex / claude / copilot shims in a temp bin dir.
# Args: bin_dir log_path [omit_cmd]
# omit_cmd: a command name to NOT create (simulate a missing CLI).
make_fake_commands() {
    local bin_dir="$1"
    local log_path="$2"
    local omit_cmd="${3:-}"
    mkdir -p "$bin_dir"
    for cmd in codex claude copilot; do
        [[ "$cmd" == "$omit_cmd" ]] && continue
        local shim="${bin_dir}/${cmd}"
        cat > "$shim" <<SHIM
#!/bin/sh
echo "${cmd} \$*" >> "${log_path}"
exit 0
SHIM
        chmod +x "$shim"
    done
}

# Simulate an installed layout: install-root files (including the agent manifest
# install copied from) + the installed Codex agent role files in the dest, plus
# user-owned role files that must survive uninstall.
# Args: install_root codex_home
seed_installed_layout() {
    local install_root="$1"
    local codex_home="$2"
    mkdir -p "${install_root}/plugins/sdd-bootstrap"
    echo "marker" > "${install_root}/marker.txt"
    echo "plugin" > "${install_root}/plugins/sdd-bootstrap/plugin.json"
    # Manifest: the role files this project ships (source install copied from).
    local manifest="${install_root}/.codex/agents"
    mkdir -p "$manifest"
    printf 'name = "sdd-investigator"\ndeveloper_instructions = "x"\n' > "${manifest}/sdd-investigator.toml"
    printf 'name = "sdd-evaluator"\ndeveloper_instructions = "x"\n' > "${manifest}/sdd-evaluator.toml"
    # Destination ~/.codex/agents: shipped roles + user-owned roles.
    local agents="${codex_home}/agents"
    mkdir -p "$agents"
    printf 'name = "sdd-investigator"\ndeveloper_instructions = "x"\n' > "${agents}/sdd-investigator.toml"
    printf 'name = "sdd-evaluator"\ndeveloper_instructions = "x"\n' > "${agents}/sdd-evaluator.toml"
    # A user's own non-project role file — must NOT be removed.
    echo 'name = "auditor"' > "${agents}/auditor.toml"
    # A user-authored role that merely shares the sdd- prefix — must NOT be removed.
    printf 'name = "sdd-custom"\ndeveloper_instructions = "x"\n' > "${agents}/sdd-custom.toml"
}

# ---------------------------------------------------------------------------
# Scenario (a): full uninstall — unregisters all plugins + marketplace from
# every CLI, removes installed files and only the shipped agent role files.
# ---------------------------------------------------------------------------
run_full_uninstall_scenario() {
    local keep_files="${1:-0}"
    local skip_agents="${2:-0}"
    local test_root install_root codex_home fake_bin command_log
    test_root="$(mktemp -d)"
    install_root="${test_root}/installed"
    codex_home="${test_root}/codex-home"
    fake_bin="${test_root}/bin"
    command_log="${test_root}/commands.log"
    local original_path="$PATH"
    local _orig_codex_home="${SDD_CODEX_HOME:-}"

    make_fake_commands "$fake_bin" "$command_log"
    seed_installed_layout "$install_root" "$codex_home"
    export PATH="${fake_bin}:${original_path}"
    export SDD_CODEX_HOME="$codex_home"

    local extra_args=()
    [[ "$keep_files" -eq 1 ]] && extra_args+=(--keep-files)
    [[ "$skip_agents" -eq 1 ]] && extra_args+=(--skip-agent-uninstall)

    local failed=0
    # Expand an empty array safely under `set -u` on bash 3.2 (macOS default).
    bash "$UNINSTALLER" --install-root "$install_root" --target All "${extra_args[@]+"${extra_args[@]}"}" >/dev/null 2>&1 || failed=1

    export PATH="$original_path"
    if [[ -z "$_orig_codex_home" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_orig_codex_home"; fi

    local all_ok=1
    [[ $failed -ne 0 ]] && { fail "full uninstall: uninstaller exited non-zero"; all_ok=0; }
    local log=""
    [[ -f "$command_log" ]] && log="$(cat "$command_log")"

    for p in $ALL_PLUGINS; do
        echo "$log" | grep -qF "codex plugin remove ${p}@sdd-plugins" || { fail "missing: codex plugin remove ${p}@sdd-plugins"; all_ok=0; }
        echo "$log" | grep -qF "claude plugin uninstall ${p}@sdd-plugins" || { fail "missing: claude plugin uninstall ${p}@sdd-plugins"; all_ok=0; }
        echo "$log" | grep -qF "copilot plugin uninstall ${p}@sdd-plugins" || { fail "missing: copilot plugin uninstall ${p}@sdd-plugins"; all_ok=0; }
    done
    # Full uninstall removes the marketplace from every CLI.
    echo "$log" | grep -qF "codex plugin marketplace remove sdd-plugins" || { fail "missing: codex marketplace remove"; all_ok=0; }
    echo "$log" | grep -qF "claude plugin marketplace remove sdd-plugins" || { fail "missing: claude marketplace remove"; all_ok=0; }
    echo "$log" | grep -qF "copilot plugin marketplace remove sdd-plugins" || { fail "missing: copilot marketplace remove"; all_ok=0; }

    # User-owned role files are always preserved.
    [[ -f "${codex_home}/agents/auditor.toml" ]] || { fail "user's auditor.toml was removed"; all_ok=0; }

    if [[ "$keep_files" -eq 1 ]]; then
        [[ -f "${install_root}/marker.txt" ]] || { fail "--keep-files removed install root"; all_ok=0; }
    else
        [[ ! -d "$install_root" ]] || { fail "install root not removed"; all_ok=0; }
    fi

    if [[ "$skip_agents" -eq 1 ]]; then
        [[ -f "${codex_home}/agents/sdd-investigator.toml" ]] || { fail "--skip-agent-uninstall removed agent toml"; all_ok=0; }
    else
        [[ ! -f "${codex_home}/agents/sdd-investigator.toml" ]] || { fail "shipped sdd-investigator.toml not removed"; all_ok=0; }
        [[ ! -f "${codex_home}/agents/sdd-evaluator.toml" ]] || { fail "shipped sdd-evaluator.toml not removed"; all_ok=0; }
        # A user-authored sdd-* role (not shipped) must survive.
        [[ -f "${codex_home}/agents/sdd-custom.toml" ]] || { fail "user-authored sdd-custom.toml was removed"; all_ok=0; }
    fi

    rm -rf "$test_root"
    [[ $all_ok -eq 1 ]]
}

if run_full_uninstall_scenario 0 0; then
    ok "full uninstall: unregisters all plugins+marketplace, removes files and only shipped agents"
else
    fail "full uninstall: unregisters all plugins+marketplace, removes files and only shipped agents"
fi

# ---------------------------------------------------------------------------
# Scenario (b): --keep-files unregisters but preserves installed files
# ---------------------------------------------------------------------------
if run_full_uninstall_scenario 1 0; then
    ok "--keep-files preserves installed files while unregistering"
else
    fail "--keep-files preserves installed files while unregistering"
fi

# ---------------------------------------------------------------------------
# Scenario (c): --skip-agent-uninstall preserves shipped agent role files
# ---------------------------------------------------------------------------
if run_full_uninstall_scenario 0 1; then
    ok "--skip-agent-uninstall preserves shipped agent role files"
else
    fail "--skip-agent-uninstall preserves shipped agent role files"
fi

# ---------------------------------------------------------------------------
# Scenario (d): subset --plugins unregisters only chosen plugins and KEEPS the
# marketplace (removing it would uninstall the unselected plugins too).
# ---------------------------------------------------------------------------
_d_root="$(mktemp -d)"; _d_install="${_d_root}/installed"; _d_codex="${_d_root}/codex-home"
_d_bin="${_d_root}/bin"; _d_log="${_d_root}/commands.log"
_d_orig_path="$PATH"; _d_orig_codex="${SDD_CODEX_HOME:-}"
make_fake_commands "$_d_bin" "$_d_log"
seed_installed_layout "$_d_install" "$_d_codex"
export PATH="${_d_bin}:${_d_orig_path}"; export SDD_CODEX_HOME="$_d_codex"
_d_failed=0
bash "$UNINSTALLER" --install-root "$_d_install" --target All --plugins "sdd-bootstrap,sdd-implementation" >/dev/null 2>&1 || _d_failed=1
export PATH="$_d_orig_path"
if [[ -z "$_d_orig_codex" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_d_orig_codex"; fi
_d_ok=1
[[ $_d_failed -eq 0 ]] || { fail "subset --plugins exited non-zero"; _d_ok=0; }
_d_logc="$(cat "$_d_log")"
echo "$_d_logc" | grep -qF "claude plugin uninstall sdd-bootstrap@sdd-plugins" || { fail "subset: sdd-bootstrap not unregistered"; _d_ok=0; }
echo "$_d_logc" | grep -qF "claude plugin uninstall sdd-implementation@sdd-plugins" || { fail "subset: sdd-implementation not unregistered"; _d_ok=0; }
if echo "$_d_logc" | grep -qF "uninstall sdd-ship@sdd-plugins" || echo "$_d_logc" | grep -qF "remove sdd-ship@sdd-plugins"; then
    fail "subset: unselected sdd-ship was unregistered"; _d_ok=0
fi
if echo "$_d_logc" | grep -qF "marketplace remove"; then
    fail "subset: marketplace must not be removed for a partial uninstall"; _d_ok=0
fi
rm -rf "$_d_root"
[[ $_d_ok -eq 1 ]] && ok "subset --plugins unregisters only chosen plugins and keeps the marketplace"

# ---------------------------------------------------------------------------
# Scenario (e): missing optional CLI (target All) is tolerated
# ---------------------------------------------------------------------------
_e_root="$(mktemp -d)"; _e_install="${_e_root}/installed"; _e_codex="${_e_root}/codex-home"
_e_bin="${_e_root}/bin"; _e_log="${_e_root}/commands.log"
_e_orig_path="$PATH"; _e_orig_codex="${SDD_CODEX_HOME:-}"
make_fake_commands "$_e_bin" "$_e_log" "codex"   # omit codex
seed_installed_layout "$_e_install" "$_e_codex"
# Restricted PATH (coreutils only) so the real codex on the host PATH cannot
# shadow the omitted shim — this is what makes "codex absent" observable.
export PATH="${_e_bin}:/usr/bin:/bin"; export SDD_CODEX_HOME="$_e_codex"
_e_failed=0
bash "$UNINSTALLER" --install-root "$_e_install" --target All >/dev/null 2>&1 || _e_failed=1
export PATH="$_e_orig_path"
if [[ -z "$_e_orig_codex" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_e_orig_codex"; fi
_e_ok=1
[[ $_e_failed -eq 0 ]] || { fail "missing optional codex CLI should be tolerated under target All"; _e_ok=0; }
[[ ! -d "$_e_install" ]] || { fail "files not removed when an optional CLI was absent"; _e_ok=0; }
rm -rf "$_e_root"
[[ $_e_ok -eq 1 ]] && ok "missing optional CLI tolerated under target All"

# ---------------------------------------------------------------------------
# Scenario (f): target Codex with codex absent is a hard error
# ---------------------------------------------------------------------------
_f_root="$(mktemp -d)"; _f_install="${_f_root}/installed"; _f_codex="${_f_root}/codex-home"
_f_bin="${_f_root}/bin"; _f_log="${_f_root}/commands.log"
_f_orig_path="$PATH"; _f_orig_codex="${SDD_CODEX_HOME:-}"
make_fake_commands "$_f_bin" "$_f_log" "codex"   # omit codex
seed_installed_layout "$_f_install" "$_f_codex"
# Restricted PATH (coreutils only) so the real codex cannot shadow the omission.
export PATH="${_f_bin}:/usr/bin:/bin"; export SDD_CODEX_HOME="$_f_codex"
_f_failed=0
bash "$UNINSTALLER" --install-root "$_f_install" --target Codex >/dev/null 2>&1 || _f_failed=1
export PATH="$_f_orig_path"
if [[ -z "$_f_orig_codex" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_f_orig_codex"; fi
if [[ $_f_failed -eq 1 ]]; then ok "target Codex with codex absent fails as required"; else fail "target Codex with codex absent should fail"; fi
rm -rf "$_f_root"

# ---------------------------------------------------------------------------
# Scenario (f2): --skip-plugin-uninstall proceeds even when the CLI is absent
# (target Codex, codex missing): no error, files still removed.
# ---------------------------------------------------------------------------
_f2_root="$(mktemp -d)"; _f2_install="${_f2_root}/installed"; _f2_codex="${_f2_root}/codex-home"
_f2_bin="${_f2_root}/bin"; _f2_log="${_f2_root}/commands.log"
_f2_orig_path="$PATH"; _f2_orig_codex="${SDD_CODEX_HOME:-}"
make_fake_commands "$_f2_bin" "$_f2_log" "codex"
seed_installed_layout "$_f2_install" "$_f2_codex"
export PATH="${_f2_bin}:/usr/bin:/bin"; export SDD_CODEX_HOME="$_f2_codex"
_f2_failed=0
bash "$UNINSTALLER" --install-root "$_f2_install" --target Codex --skip-plugin-uninstall >/dev/null 2>&1 || _f2_failed=1
export PATH="$_f2_orig_path"
if [[ -z "$_f2_orig_codex" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_f2_orig_codex"; fi
_f2_ok=1
[[ $_f2_failed -eq 0 ]] || { fail "--skip-plugin-uninstall should not error on absent CLI"; _f2_ok=0; }
[[ ! -d "$_f2_install" ]] || { fail "--skip-plugin-uninstall should still remove files"; _f2_ok=0; }
rm -rf "$_f2_root"
[[ $_f2_ok -eq 1 ]] && ok "--skip-plugin-uninstall proceeds when CLI is absent"

# ---------------------------------------------------------------------------
# Scenario (g): idempotency — a second uninstall still exits 0
# ---------------------------------------------------------------------------
_g_root="$(mktemp -d)"; _g_install="${_g_root}/installed"; _g_codex="${_g_root}/codex-home"
_g_bin="${_g_root}/bin"; _g_log="${_g_root}/commands.log"
_g_orig_path="$PATH"; _g_orig_codex="${SDD_CODEX_HOME:-}"
make_fake_commands "$_g_bin" "$_g_log"
seed_installed_layout "$_g_install" "$_g_codex"
export PATH="${_g_bin}:${_g_orig_path}"; export SDD_CODEX_HOME="$_g_codex"
_g_failed=0
bash "$UNINSTALLER" --install-root "$_g_install" --target All >/dev/null 2>&1 || _g_failed=1
bash "$UNINSTALLER" --install-root "$_g_install" --target All >/dev/null 2>&1 || _g_failed=1
export PATH="$_g_orig_path"
if [[ -z "$_g_orig_codex" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_g_orig_codex"; fi
if [[ $_g_failed -eq 0 ]]; then ok "idempotency: second uninstall exits 0"; else fail "idempotency: second uninstall should exit 0"; fi
rm -rf "$_g_root"

# ---------------------------------------------------------------------------
# Scenario (h): invalid plugin name rejected
# ---------------------------------------------------------------------------
_h_failed=0
bash "$UNINSTALLER" --install-root "$(mktemp -d)/x" --target FilesOnly --plugins "not-a-plugin" >/dev/null 2>&1 || _h_failed=1
if [[ $_h_failed -eq 1 ]]; then ok "invalid plugin name rejected"; else fail "invalid plugin name was accepted"; fi

# ---------------------------------------------------------------------------
# Scenario (h2): invalid --target rejected
# ---------------------------------------------------------------------------
_h2_failed=0
bash "$UNINSTALLER" --install-root "$(mktemp -d)/x" --target NotATarget >/dev/null 2>&1 || _h2_failed=1
if [[ $_h2_failed -eq 1 ]]; then ok "invalid --target rejected"; else fail "invalid --target was accepted"; fi

# ---------------------------------------------------------------------------
# Scenario (h3): empty --install-root rejected before any removal
# ---------------------------------------------------------------------------
_h3_failed=0
bash "$UNINSTALLER" --install-root "" --target FilesOnly --skip-plugin-uninstall --skip-agent-uninstall >/dev/null 2>&1 || _h3_failed=1
if [[ $_h3_failed -eq 1 ]]; then ok "empty --install-root rejected"; else fail "empty --install-root was accepted"; fi

# ---------------------------------------------------------------------------
# Scenario (i): refuses a filesystem root as --install-root
# ---------------------------------------------------------------------------
_i_failed=0
bash "$UNINSTALLER" --install-root "/" --target FilesOnly --skip-plugin-uninstall --skip-agent-uninstall >/dev/null 2>&1 || _i_failed=1
if [[ $_i_failed -eq 1 ]]; then ok "filesystem root rejected as --install-root"; else fail "filesystem root was accepted as --install-root"; fi

# ---------------------------------------------------------------------------
# Scenario (i2): refuses the home directory as --install-root
# ---------------------------------------------------------------------------
_i2_failed=0
bash "$UNINSTALLER" --install-root "$HOME" --target FilesOnly --skip-plugin-uninstall --skip-agent-uninstall >/dev/null 2>&1 || _i2_failed=1
if [[ $_i2_failed -eq 1 ]]; then ok "home directory rejected as --install-root"; else fail "home directory was accepted as --install-root"; fi

# ---------------------------------------------------------------------------
# Scenario (j): FilesOnly skips CLI calls but still removes files
# ---------------------------------------------------------------------------
_j_root="$(mktemp -d)"; _j_install="${_j_root}/installed"; _j_codex="${_j_root}/codex-home"
_j_bin="${_j_root}/bin"; _j_log="${_j_root}/commands.log"
_j_orig_path="$PATH"; _j_orig_codex="${SDD_CODEX_HOME:-}"
make_fake_commands "$_j_bin" "$_j_log"
seed_installed_layout "$_j_install" "$_j_codex"
export PATH="${_j_bin}:${_j_orig_path}"; export SDD_CODEX_HOME="$_j_codex"
_j_failed=0
bash "$UNINSTALLER" --install-root "$_j_install" --target FilesOnly >/dev/null 2>&1 || _j_failed=1
export PATH="$_j_orig_path"
if [[ -z "$_j_orig_codex" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$_j_orig_codex"; fi
_j_ok=1
[[ $_j_failed -eq 0 ]] || { fail "FilesOnly exited non-zero"; _j_ok=0; }
[[ ! -s "$_j_log" ]] || { fail "FilesOnly should not call any CLI"; _j_ok=0; }
[[ ! -d "$_j_install" ]] || { fail "FilesOnly should still remove installed files"; _j_ok=0; }
rm -rf "$_j_root"
[[ $_j_ok -eq 1 ]] && ok "FilesOnly skips CLI calls but removes files"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[[ $FAIL -eq 0 ]]
