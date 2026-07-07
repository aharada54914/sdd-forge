#!/usr/bin/env bash
# uninstall.sh — SDD plugins uninstaller for macOS and Linux
# Mirrors uninstall.ps1 behavior exactly. Reverses install.sh:
#   - unregisters plugins and the marketplace from Codex / Claude / Copilot
#   - removes the Codex agent role files this project installed
#   - removes the installed files at the install root (unless --keep-files)
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/sdd-plugins"
MARKETPLACE_NAME="sdd-plugins"
TARGET="All"
PLUGINS="sdd-bootstrap,sdd-ship,sdd-implementation,sdd-quality-loop,sdd-lite,sdd-review-loop"
KEEP_FILES=0
SKIP_PLUGIN_UNINSTALL=0
SKIP_AGENT_UNINSTALL=0
MCP_LIST="sdd-forge-mcp,local-env-mcp,ci-mcp"
SKIP_MCP_UNINSTALL=0

VALID_PLUGINS="sdd-bootstrap sdd-ship sdd-implementation sdd-quality-loop sdd-lite sdd-review-loop"
VALID_MCPS="sdd-forge-mcp local-env-mcp ci-mcp"
# Role files this project installs into ~/.codex/agents. Used as a fallback when
# the install root (the manifest source) is no longer present.
SHIPPED_AGENTS="sdd-investigator.toml sdd-evaluator.toml sdd-panelist-gpt.toml sdd-panelist-gemini.toml"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
    cat >&2 <<EOF
Usage: uninstall.sh [options]

  --install-root <path>          Default: \${XDG_DATA_HOME:-\$HOME/.local/share}/sdd-plugins
  --marketplace-name <name>      Registered marketplace name. Default: sdd-plugins
  --target All|Codex|Claude|Copilot|FilesOnly
                                 Default: All
  --plugins <comma-separated>    Names from: sdd-bootstrap,sdd-ship,sdd-implementation,sdd-quality-loop,sdd-lite,sdd-review-loop
                                 Default: all plugins
  --keep-files                   Unregister from CLI tools but keep the installed files
  --skip-plugin-uninstall        Skip unregistering plugins/marketplace from CLI tools
  --skip-agent-uninstall         Skip removing Codex agent TOML files
  --mcp <comma-separated>        Names from: sdd-forge-mcp,local-env-mcp,ci-mcp
                                 Default: sdd-forge-mcp,local-env-mcp,ci-mcp
  --skip-mcp-uninstall           Skip removing MCP payloads/registrations

Environment:
  SDD_CODEX_HOME      Override ~/.codex location for agent TOML files and config.toml
  SDD_CURSOR_DIR      Override the ~/.cursor directory used for Cursor MCP unregistration
  SDD_VSCODE_USER_DIR Override the VS Code user-profile directory used for MCP unregistration
  Unregistration is best-effort: a plugin or marketplace that is already absent
  is treated as success so the uninstaller is idempotent. The marketplace is only
  removed during a full uninstall (every plugin selected) because removing it
  would also uninstall any plugins left behind by a subset uninstall.
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-root)         [[ $# -gt 1 ]] || usage; INSTALL_ROOT="$2"; shift 2 ;;
        --marketplace-name)     [[ $# -gt 1 ]] || usage; MARKETPLACE_NAME="$2"; shift 2 ;;
        --target)               [[ $# -gt 1 ]] || usage; TARGET="$2"; shift 2 ;;
        --plugins)              [[ $# -gt 1 ]] || usage; PLUGINS="$2"; shift 2 ;;
        --keep-files)           KEEP_FILES=1; shift ;;
        --skip-plugin-uninstall) SKIP_PLUGIN_UNINSTALL=1; shift ;;
        --skip-agent-uninstall)  SKIP_AGENT_UNINSTALL=1; shift ;;
        --mcp)                  [[ $# -gt 1 ]] || usage; MCP_LIST="$2"; shift 2 ;;
        --skip-mcp-uninstall)    SKIP_MCP_UNINSTALL=1; shift ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# Reject an empty install root before any canonicalization. os.path.realpath('')
# resolves to the current working directory, so an unset caller variable
# (e.g. --install-root "$UNSET") must never reach the removal step.
if [[ -z "${INSTALL_ROOT//[[:space:]]/}" ]]; then
    echo "Error: --install-root must not be empty." >&2
    exit 1
fi

# Validate --target
case "$TARGET" in
    All|Codex|Claude|Copilot|FilesOnly) ;;
    *) echo "Invalid --target value: $TARGET (must be All, Codex, Claude, Copilot, or FilesOnly)" >&2; usage ;;
esac

# Validate --plugins
# bash 3.2 treats the zero-element array produced by `read -ra` on an empty
# string as unset under `set -u`, so reject an empty list before the read.
if [[ -z "$PLUGINS" ]]; then
    echo "Invalid plugin name: (empty) (must be one of: $VALID_PLUGINS)" >&2
    exit 1
fi
IFS=',' read -ra PLUGIN_LIST <<< "$PLUGINS"
for p in "${PLUGIN_LIST[@]}"; do
    valid=0
    for v in $VALID_PLUGINS; do
        [[ "$p" == "$v" ]] && valid=1 && break
    done
    if [[ $valid -eq 0 ]]; then
        echo "Invalid plugin name: $p (must be one of: $VALID_PLUGINS)" >&2
        exit 1
    fi
done

# Validate --mcp
MCP_SELECTION=()
if [[ $SKIP_MCP_UNINSTALL -eq 0 ]]; then
    if [[ -z "$MCP_LIST" ]]; then
        echo "Invalid MCP name: (empty) (must be one of: $VALID_MCPS)" >&2
        exit 1
    fi
    IFS=',' read -ra MCP_SELECTION <<< "$MCP_LIST"
    for m in "${MCP_SELECTION[@]}"; do
        valid=0
        for v in $VALID_MCPS; do
            [[ "$m" == "$v" ]] && valid=1 && break
        done
        if [[ $valid -eq 0 ]]; then
            echo "Invalid MCP name: $m (must be one of: $VALID_MCPS)" >&2
            exit 1
        fi
    done
fi

# A full uninstall selects every known plugin. Only then is it safe to remove the
# marketplace, since removing it also uninstalls any plugins still registered
# from it.
IS_FULL_UNINSTALL=1
for v in $VALID_PLUGINS; do
    found=0
    for p in "${PLUGIN_LIST[@]}"; do
        [[ "$p" == "$v" ]] && found=1 && break
    done
    if [[ $found -eq 0 ]]; then IS_FULL_UNINSTALL=0; break; fi
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
target_requires() {
    # Returns 0 if $TARGET is exactly the given value (hard-error context)
    [[ "$TARGET" == "$1" ]]
}

# Best-effort plugin command. A non-zero exit (e.g. "plugin not installed")
# is reported as a warning but never aborts the uninstall — re-running the
# uninstaller must converge on a clean state.
try_plugin_command() {
    local cmd="$1"; shift
    local rc=0
    "$cmd" "$@" >/dev/null 2>&1 || rc=$?
    if [[ $rc -ne 0 ]]; then
        local quoted_args
        printf -v quoted_args '%q ' "$@"
        echo "Warning: '$cmd ${quoted_args% }' exited with code $rc (already removed?). Continuing." >&2
    fi
    return 0
}

remove_marketplace_if_full() {
    # Only remove the marketplace for a full uninstall (see IS_FULL_UNINSTALL).
    local cmd="$1"
    if [[ $IS_FULL_UNINSTALL -eq 1 ]]; then
        try_plugin_command "$cmd" plugin marketplace remove "$MARKETPLACE_NAME"
    fi
}

uninstall_codex_plugins() {
    # Honor --skip-plugin-uninstall before probing the CLI so a removed CLI does
    # not block the agent/file cleanup paths.
    [[ $SKIP_PLUGIN_UNINSTALL -ne 0 ]] && return 0
    if ! command -v codex >/dev/null 2>&1; then
        if target_requires Codex; then
            echo "Error: Codex CLI was not found in PATH." >&2
            return 1
        fi
        echo "Warning: Codex CLI was not found. Codex unregistration was skipped." >&2
        return 0
    fi
    for p in "${PLUGIN_LIST[@]}"; do
        # Codex plugin state is keyed by the qualified plugin@marketplace id.
        try_plugin_command codex plugin remove "${p}@${MARKETPLACE_NAME}"
    done
    remove_marketplace_if_full codex
}

uninstall_claude_plugins() {
    [[ $SKIP_PLUGIN_UNINSTALL -ne 0 ]] && return 0
    if ! command -v claude >/dev/null 2>&1; then
        if target_requires Claude; then
            echo "Error: Claude Code CLI was not found in PATH." >&2
            return 1
        fi
        echo "Warning: Claude Code CLI was not found. Claude unregistration was skipped." >&2
        return 0
    fi
    for p in "${PLUGIN_LIST[@]}"; do
        try_plugin_command claude plugin uninstall "${p}@${MARKETPLACE_NAME}"
    done
    remove_marketplace_if_full claude
}

uninstall_copilot_plugins() {
    [[ $SKIP_PLUGIN_UNINSTALL -ne 0 ]] && return 0
    if ! command -v copilot >/dev/null 2>&1; then
        if target_requires Copilot; then
            echo "Error: Copilot CLI was not found in PATH." >&2
            return 1
        fi
        echo "Warning: Copilot CLI was not found. Copilot unregistration was skipped." >&2
        return 0
    fi
    for p in "${PLUGIN_LIST[@]}"; do
        try_plugin_command copilot plugin uninstall "${p}@${MARKETPLACE_NAME}"
    done
    remove_marketplace_if_full copilot
}

uninstall_codex_agents() {
    # Override destination via SDD_CODEX_HOME environment variable (for testing; default is user profile).
    local codex_home="${SDD_CODEX_HOME:-$HOME/.codex}"
    local agent_dest_dir="${codex_home}/agents"
    [[ -d "$agent_dest_dir" ]] || return 0
    # Remove only the role files this project installed. Prefer the manifest in
    # the install root (the source install copied from); fall back to the known
    # shipped names if the install root is already gone. A user's own role files
    # — including any sdd-* they authored themselves — are never touched.
    local -a shipped=()
    local src_agents="${INSTALL_ROOT}/.codex/agents"
    if [[ -d "$src_agents" ]]; then
        for f in "$src_agents"/sdd-*.toml; do
            [[ -e "$f" ]] && shipped+=("$(basename "$f")")
        done
    fi
    if [[ ${#shipped[@]} -eq 0 ]]; then
        # shellcheck disable=SC2206
        shipped=($SHIPPED_AGENTS)
    fi
    for name in "${shipped[@]}"; do
        if [[ -e "${agent_dest_dir}/${name}" ]]; then
            rm -f "${agent_dest_dir}/${name}"
        fi
    done
    # Always succeed: a non-existent last entry must not make the function (and,
    # under set -e, the whole uninstaller) exit non-zero on a repeat run.
    return 0
}

# ---------------------------------------------------------------------------
# MCP: unregister from Claude/Codex and remove the placed payload
# (mirror install.sh's placement/registration split; all best-effort)
# ---------------------------------------------------------------------------
unregister_claude_mcp() {
    [[ $SKIP_MCP_UNINSTALL -ne 0 ]] && return 0
    if ! command -v claude >/dev/null 2>&1; then
        echo "Warning: Claude Code CLI was not found. Claude MCP unregistration was skipped." >&2
        return 0
    fi
    local name
    for name in "${MCP_SELECTION[@]}"; do
        try_plugin_command claude mcp remove "$name"
    done
}

unregister_codex_mcp() {
    # Remove the marker-delimited block for each selected MCP from
    # ~/.codex/config.toml. Best-effort: a missing config.toml or a missing
    # block for a given MCP is not an error (nothing to remove).
    [[ $SKIP_MCP_UNINSTALL -ne 0 ]] && return 0
    local codex_home="${SDD_CODEX_HOME:-$HOME/.codex}"
    local config_toml="${codex_home}/config.toml"
    [[ -f "$config_toml" ]] || return 0
    local name tmp_config
    for name in "${MCP_SELECTION[@]}"; do
        local marker_begin="# >>> ${name} (managed by sdd-forge installer; do not edit by hand) >>>"
        local marker_end="# <<< ${name} <<<"
        tmp_config="$(mktemp)"
        awk -v begin="$marker_begin" -v end="$marker_end" '
            $0 == begin { skip = 1; next }
            $0 == end { skip = 0; next }
            skip { next }
            { print }
        ' "$config_toml" > "$tmp_config"
        mv "$tmp_config" "$config_toml"
    done
    return 0
}

remove_mcp_json_keys() {
    # Shared idempotent JSON key removal for IDE client MCP configs (ADR-0005),
    # the inverse of install.sh's upsert_mcp_json. Deletes ONLY <top_key>.<name>
    # for every selected MCP, preserving all other entries and unknown top-level
    # keys. The output is stable 2-space JSON (matching the installer's upsert
    # output). Fail-safes (security-spec B3): a present-but-invalid JSON file is
    # never overwritten (error notice, uninstaller continues with other
    # clients); an absent file is a silent skip. Node absence is handled by the
    # caller (a notice is printed once and IDE unregistration is skipped) so the
    # uninstaller never hard-requires Node.
    # Args: <client_label> <config_file> <top_key>
    local client_label="$1"
    local config_file="$2"
    local top_key="$3"
    # Absent file: nothing was ever registered here — silent skip.
    [[ -f "$config_file" ]] || return 0
    # Guard the expansion: bash 3.2 treats a zero-element array as unset under
    # set -u. MCP_SELECTION is always non-empty here (validated at parse time),
    # but keep the guard for defensiveness.
    [[ ${#MCP_SELECTION[@]} -eq 0 ]] && return 0
    local rc=0
    node -e '
const fs = require("fs");
const [file, topKey, ...names] = process.argv.slice(1);
let text = "";
try { text = fs.readFileSync(file, "utf8"); } catch (err) { process.exit(0); }
if (text.trim() === "") process.exit(0);
let root;
try { root = JSON.parse(text); } catch (err) { process.exit(3); }
if (root === null || typeof root !== "object" || Array.isArray(root)) process.exit(3);
const section = root[topKey];
// Nothing managed here (no top key): leave the file untouched.
if (section === undefined) process.exit(0);
if (section === null || typeof section !== "object" || Array.isArray(section)) process.exit(3);
for (const name of names) {
  if (Object.prototype.hasOwnProperty.call(section, name)) delete section[name];
}
const out = JSON.stringify(root, null, 2) + "\n";
const tmp = file + ".sdd-forge.tmp";
fs.writeFileSync(tmp, out);
fs.renameSync(tmp, file);
' "$config_file" "$top_key" "${MCP_SELECTION[@]}" || rc=$?
    if [[ $rc -eq 3 ]]; then
        echo "Error: ${config_file} contains invalid JSON. ${client_label} MCP unregistration was skipped and the file was left unmodified. Fix or remove the file manually." >&2
        return 0
    fi
    if [[ $rc -ne 0 ]]; then
        echo "Warning: Failed to update ${config_file}. ${client_label} MCP unregistration was skipped." >&2
        return 0
    fi
    return 0
}

# Tracks whether the "Node not found" notice has been printed so it appears at
# most once across the Cursor and VS Code unregistration attempts.
MCP_JSON_NODE_NOTICE_PRINTED=0

mcp_json_node_available() {
    # Returns 0 if `node` is on PATH; otherwise prints a one-time notice that IDE
    # (Cursor / VS Code) registrations could not be removed and returns 1. The
    # uninstaller must not hard-require Node: the payload/Claude/Codex removals
    # still run without it.
    if command -v node >/dev/null 2>&1; then
        return 0
    fi
    if [[ $MCP_JSON_NODE_NOTICE_PRINTED -eq 0 ]]; then
        echo "Warning: Node.js was not found in PATH. Cursor / VS Code MCP registrations could not be removed (edit ~/.cursor/mcp.json and the VS Code user mcp.json by hand to remove the sdd-forge-mcp / local-env-mcp / ci-mcp keys). Other uninstall steps continue." >&2
        MCP_JSON_NODE_NOTICE_PRINTED=1
    fi
    return 1
}

unregister_cursor_mcp() {
    # Removes only mcpServers.<name> from ~/.cursor/mcp.json for each selected
    # MCP. An absent ~/.cursor directory means Cursor is not installed: skip
    # with a notice and never create anything. Override via SDD_CURSOR_DIR.
    [[ $SKIP_MCP_UNINSTALL -ne 0 ]] && return 0
    local cursor_dir="${SDD_CURSOR_DIR:-$HOME/.cursor}"
    if [[ ! -d "$cursor_dir" ]]; then
        echo "Warning: ${cursor_dir} was not found. Cursor MCP unregistration was skipped (Cursor does not appear to be installed)." >&2
        return 0
    fi
    mcp_json_node_available || return 0
    remove_mcp_json_keys "Cursor" "${cursor_dir}/mcp.json" "mcpServers"
}

unregister_vscode_mcp() {
    # Removes only servers.<name> from the VS Code user-profile mcp.json for each
    # selected MCP (macOS: ~/Library/Application Support/Code/User, Linux:
    # ~/.config/Code/User; Windows %APPDATA%\Code\User is handled by
    # uninstall.ps1). An absent user directory means VS Code is not installed:
    # skip with a notice and never create anything. Override via
    # SDD_VSCODE_USER_DIR.
    [[ $SKIP_MCP_UNINSTALL -ne 0 ]] && return 0
    local vscode_user_dir
    if [[ -n "${SDD_VSCODE_USER_DIR:-}" ]]; then
        vscode_user_dir="$SDD_VSCODE_USER_DIR"
    else
        case "$(uname -s)" in
            Darwin) vscode_user_dir="$HOME/Library/Application Support/Code/User" ;;
            *)      vscode_user_dir="$HOME/.config/Code/User" ;;
        esac
    fi
    if [[ ! -d "$vscode_user_dir" ]]; then
        echo "Warning: ${vscode_user_dir} was not found. VS Code MCP unregistration was skipped (VS Code does not appear to be installed)." >&2
        return 0
    fi
    mcp_json_node_available || return 0
    remove_mcp_json_keys "VS Code" "${vscode_user_dir}/mcp.json" "servers"
}

remove_mcp_payload() {
    # Removes the placed MCP directories under INSTALL_ROOT/mcp/<name>/.
    # Best-effort: absence is success (idempotent, mirrors --keep-files logic
    # for the rest of the install root).
    [[ $SKIP_MCP_UNINSTALL -ne 0 ]] && return 0
    [[ $KEEP_FILES -ne 0 ]] && return 0
    local name
    for name in "${MCP_SELECTION[@]}"; do
        if [[ -d "${INSTALL_ROOT}/mcp/${name}" ]]; then
            rm -rf "${INSTALL_ROOT}/mcp/${name}"
        fi
    done
    return 0
}

# ---------------------------------------------------------------------------
# Resolve install root and safety checks (mirror install.sh)
# ---------------------------------------------------------------------------
_canon_install_root() {
    local p="$1"
    if python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$p" 2>/dev/null; then
        return 0
    fi
    if realpath -m "$p" 2>/dev/null; then
        return 0
    fi
    case "$p" in
        /*)
            case "/${p}/" in
                */./*|*/../*) : ;;
                *) printf '%s\n' "$p"; return 0 ;;
            esac
            ;;
    esac
    local _parent _base
    _parent="$(dirname "$p")"
    _base="$(basename "$p")"
    local _resolved_parent
    _resolved_parent="$(cd "$_parent" 2>/dev/null && pwd)" || {
        echo "Error: cannot resolve parent directory of --install-root: ${_parent}" >&2
        exit 1
    }
    echo "${_resolved_parent}/${_base}"
}
INSTALL_ROOT="$(_canon_install_root "$INSTALL_ROOT")"
unset -f _canon_install_root

# Must not be a filesystem root
case "$INSTALL_ROOT" in
    /) echo "Error: --install-root must not be a filesystem root: $INSTALL_ROOT" >&2; exit 1 ;;
    *) ;;
esac
_parent="$(dirname "$INSTALL_ROOT")"
if [[ "$_parent" == "$INSTALL_ROOT" ]]; then
    echo "Error: --install-root must not be a filesystem root: $INSTALL_ROOT" >&2
    exit 1
fi
# Refuse obviously dangerous roots: the home directory or its parent. A path like
# "$HOME/.." canonicalizes to the parent above, so guard against it explicitly.
HOME_PARENT="$(dirname "$HOME")"
case "$INSTALL_ROOT" in
    "$HOME"|"$HOME/") echo "Error: refusing to remove the home directory: $INSTALL_ROOT" >&2; exit 1 ;;
    "$HOME_PARENT"|"$HOME_PARENT/") echo "Error: refusing to remove the parent of the home directory: $INSTALL_ROOT" >&2; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Unregister from CLI tools
# ---------------------------------------------------------------------------
if [[ "$TARGET" == "All" || "$TARGET" == "Codex" ]]; then
    uninstall_codex_plugins || exit 1
    if [[ $SKIP_AGENT_UNINSTALL -eq 0 ]]; then
        uninstall_codex_agents
    fi
    unregister_codex_mcp
fi
if [[ "$TARGET" == "All" || "$TARGET" == "Claude" ]]; then
    uninstall_claude_plugins || exit 1
    unregister_claude_mcp
fi
if [[ "$TARGET" == "All" || "$TARGET" == "Copilot" ]]; then
    uninstall_copilot_plugins || exit 1
fi
# IDE-client MCP unregistration mirrors install.sh's registration scoping:
# Cursor has no dedicated --target value, so it participates in All only; VS
# Code consumes the MCP config through Copilot, so it participates in All and
# Copilot.
if [[ "$TARGET" == "All" ]]; then
    unregister_cursor_mcp
fi
if [[ "$TARGET" == "All" || "$TARGET" == "Copilot" ]]; then
    unregister_vscode_mcp
fi

# ---------------------------------------------------------------------------
# Remove installed files
# ---------------------------------------------------------------------------
# MCP payload removal mirrors --keep-files semantics for the rest of the
# install root; when the whole root is removed below, this is redundant but
# harmless (already-removed directories are treated as success).
remove_mcp_payload

if [[ $KEEP_FILES -eq 1 ]]; then
    echo "Kept installed files at: ${INSTALL_ROOT} (--keep-files)."
elif [[ -d "$INSTALL_ROOT" ]]; then
    rm -rf "$INSTALL_ROOT"
    echo "Removed installed files at: ${INSTALL_ROOT}."
else
    echo "No installed files found at: ${INSTALL_ROOT}."
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
echo ""
echo "SDD plugins uninstalled."
if [[ "$TARGET" == "FilesOnly" ]]; then
    echo "Plugin unregistration was skipped because --target=FilesOnly."
fi
