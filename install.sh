#!/usr/bin/env bash
# install.sh — SDD plugins installer for macOS and Linux
# Mirrors install.ps1 behavior exactly.
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
REPOSITORY="aharada54914/sdd-forge"
REF="main"
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/sdd-plugins"
TARGET="All"
PLUGINS="sdd-bootstrap,sdd-ship"
SKIP_PLUGIN_INSTALL=0
SKIP_AGENT_INSTALL=0
SOURCE_DIRECTORY=""
SKIP_MCP=0
MCP_LIST="sdd-forge-mcp,local-env-mcp"

VALID_PLUGINS="sdd-bootstrap sdd-ship sdd-implementation sdd-quality-loop sdd-lite sdd-review-loop"
VALID_MCPS="sdd-forge-mcp local-env-mcp"
# The ~/.codex/config.toml block for each selected MCP is delimited by a
# per-MCP marker pair built inside register_codex_mcp (using the MCP name), so
# a block can be idempotently added, replaced, or removed without touching any
# other content a user has in that file. No single-MCP marker constant is
# defined here because the installer ships more than one MCP.

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
    cat >&2 <<EOF
Usage: install.sh [options]

  --repository <owner/repo>      Default: aharada54914/sdd-forge
  --ref <ref>                    Default: main
  --install-root <path>          Default: \${XDG_DATA_HOME:-\$HOME/.local/share}/sdd-plugins
  --target All|Codex|Claude|Copilot|FilesOnly
                                 Default: All
  --plugins <comma-separated>    Names from: sdd-bootstrap,sdd-ship,sdd-implementation,sdd-quality-loop,sdd-lite,sdd-review-loop
                                 Default: sdd-bootstrap,sdd-ship
  --skip-plugin-install          Skip registering plugins with CLI tools
  --skip-agent-install           Skip copying Codex agent TOML files
  --source-directory <path>      Use a local directory instead of downloading
  --skip-mcp                     Skip placing and registering all MCP servers
  --mcp <comma-separated>        Names from: sdd-forge-mcp,local-env-mcp
                                 Default: sdd-forge-mcp,local-env-mcp

Environment: SDD_CODEX_HOME     Override ~/.codex destination for agent TOML files and config.toml
  Remote installs require a GitHub CLI-authenticated session (`gh auth login`).
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repository)       [[ $# -gt 1 ]] || usage; REPOSITORY="$2"; shift 2 ;;
        --ref)              [[ $# -gt 1 ]] || usage; REF="$2"; shift 2 ;;
        --install-root)     [[ $# -gt 1 ]] || usage; INSTALL_ROOT="$2"; shift 2 ;;
        --target)           [[ $# -gt 1 ]] || usage; TARGET="$2"; shift 2 ;;
        --plugins)          [[ $# -gt 1 ]] || usage; PLUGINS="$2"; shift 2 ;;
        --skip-plugin-install) SKIP_PLUGIN_INSTALL=1; shift ;;
        --skip-agent-install)  SKIP_AGENT_INSTALL=1; shift ;;
        --source-directory) [[ $# -gt 1 ]] || usage; SOURCE_DIRECTORY="$2"; shift 2 ;;
        --skip-mcp)         SKIP_MCP=1; shift ;;
        --mcp)              [[ $# -gt 1 ]] || usage; MCP_LIST="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

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
if [[ $SKIP_MCP -eq 0 ]]; then
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

# Resolve dependencies to a fixed point. This is deliberately iterative: lite
# adds bootstrap, and bootstrap then adds the internal review loop.
AUTO_INCLUDED=()
dependencies_changed=1
while [[ $dependencies_changed -eq 1 ]]; do
    dependencies_changed=0
    for plugin in "${PLUGIN_LIST[@]}"; do
        dependencies=()
        case "$plugin" in
            sdd-bootstrap) dependencies=(sdd-review-loop) ;;
            sdd-lite) dependencies=(sdd-bootstrap sdd-implementation sdd-quality-loop) ;;
            sdd-ship) dependencies=(sdd-bootstrap sdd-review-loop sdd-implementation sdd-quality-loop sdd-lite) ;;
        esac
        if [[ ${#dependencies[@]} -gt 0 ]]; then
            for dep in "${dependencies[@]}"; do
                case ",$PLUGINS," in
                    *,"$dep",*) ;;
                    *)
                        PLUGINS="$PLUGINS,$dep"
                        PLUGIN_LIST+=("$dep")
                        AUTO_INCLUDED+=("$dep")
                        dependencies_changed=1
                        ;;
                esac
            done
        fi
    done
done
if [[ ${#AUTO_INCLUDED[@]} -gt 0 ]]; then
    echo "Note: dependency resolution auto-included: ${AUTO_INCLUDED[*]}." >&2
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
run_plugin_command() {
    local cmd="$1"; shift
    local rc=0
    "$cmd" "$@" || rc=$?
    if [[ $rc -ne 0 ]]; then
        # Use printf %q so multi-word arguments are unambiguous in the message.
        local quoted_args
        printf -v quoted_args '%q ' "$@"
        echo "Error: '$cmd ${quoted_args% }' failed with exit code $rc." >&2
        return 1
    fi
}

target_requires() {
    # Returns 0 if $TARGET is exactly the given value (hard-error context)
    [[ "$TARGET" == "$1" ]]
}

install_codex_plugins() {
    local marketplace_root="$1"
    if ! command -v codex >/dev/null 2>&1; then
        if target_requires Codex; then
            echo "Error: Codex CLI was not found in PATH." >&2
            return 1
        fi
        echo "Warning: Codex CLI was not found. Codex registration was skipped." >&2
        return 0
    fi
    run_plugin_command codex plugin marketplace add "$marketplace_root" || return 1
    if [[ $SKIP_PLUGIN_INSTALL -eq 0 ]]; then
        for p in "${PLUGIN_LIST[@]}"; do
            run_plugin_command codex plugin add "${p}@sdd-plugins" || return 1
        done
    fi
}

install_claude_plugins() {
    local marketplace_root="$1"
    if ! command -v claude >/dev/null 2>&1; then
        if target_requires Claude; then
            echo "Error: Claude Code CLI was not found in PATH." >&2
            return 1
        fi
        echo "Warning: Claude Code CLI was not found. Claude registration was skipped." >&2
        return 0
    fi
    # Validate every selected manifest before marketplace registration. A
    # rejected manifest must not leave a partially registered Claude install.
    for p in "${PLUGIN_LIST[@]}"; do
        run_plugin_command claude plugin validate "${marketplace_root}/plugins/${p}" || return 1
    done
    run_plugin_command claude plugin marketplace add "$marketplace_root" --scope user || return 1
    if [[ $SKIP_PLUGIN_INSTALL -eq 0 ]]; then
        for p in "${PLUGIN_LIST[@]}"; do
            run_plugin_command claude plugin install "${p}@sdd-plugins" --scope user || return 1
        done
    fi
}

install_copilot_plugins() {
    local marketplace_root="$1"
    if ! command -v copilot >/dev/null 2>&1; then
        if target_requires Copilot; then
            echo "Error: Copilot CLI was not found in PATH." >&2
            return 1
        fi
        echo "Warning: Copilot CLI was not found. Copilot registration was skipped." >&2
        return 0
    fi
    run_plugin_command copilot plugin marketplace add "$marketplace_root" || return 1
    if [[ $SKIP_PLUGIN_INSTALL -eq 0 ]]; then
        for p in "${PLUGIN_LIST[@]}"; do
            run_plugin_command copilot plugin install "${p}@sdd-plugins" || return 1
        done
    fi
}

get_github_auth_token() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) was not found in PATH. Install it or use --source-directory." >&2
        return 1
    fi
    local token=""
    if ! token="$(gh auth token 2>/dev/null)"; then
        echo "Error: GitHub CLI authentication is required for remote installs. Run 'gh auth login' first." >&2
        return 1
    fi
    if [[ -z "$token" ]]; then
        echo "Error: GitHub CLI did not return an auth token. Run 'gh auth login' first." >&2
        return 1
    fi
    printf '%s' "$token"
}

download_authenticated_archive() {
    local archive_path="$1"
    local archive_url="https://api.github.com/repos/${REPOSITORY}/tarball/${REF}"
    local token
    token="$(get_github_auth_token)" || return 1
    echo "Downloading authenticated archive from ${archive_url}"
    printf 'header = "Authorization: Bearer %s"\nheader = "Accept: application/vnd.github+json"\n' "$token" |
        curl -fsSL --config - "$archive_url" -o "$archive_path"
}

install_codex_agents() {
    local install_root_path="$1"
    local agent_source_dir="${install_root_path}/.codex/agents"
    if [[ ! -d "$agent_source_dir" ]]; then
        echo "Warning: No .codex/agents directory found in install root. Codex agent install skipped." >&2
        return 0
    fi
    # Override destination via SDD_CODEX_HOME environment variable (for testing; default is user profile).
    local codex_home="${SDD_CODEX_HOME:-$HOME/.codex}"
    local agent_dest_dir="${codex_home}/agents"
    # A partial copy from a prior failed run is safe to overwrite on re-run.
    if ! {
        mkdir -p "$agent_dest_dir"
        for toml in "${agent_source_dir}"/sdd-*.toml; do
            [[ -f "$toml" ]] || continue
            cp -f "$toml" "$agent_dest_dir/"
        done
    }; then
        echo "Warning: Codex agent install failed." >&2
        return 1
    fi
    # Scan destination for malformed agent role files (warning only; do not modify or delete).
    for toml_file in "${agent_dest_dir}"/*.toml; do
        [[ -f "$toml_file" ]] || continue
        if ! grep -Eq '^[[:space:]]*developer_instructions[[:space:]]*=' "$toml_file"; then
            echo "Warning: Codex will ignore malformed agent role file at startup ('Ignoring malformed agent role definition'): ${toml_file}. Add a developer_instructions entry or delete the file." >&2
        fi
    done
}

# ---------------------------------------------------------------------------
# MCP: Node version check, placement, and Claude/Codex registration
# ---------------------------------------------------------------------------
mcp_selected() {
    # Returns 0 if the given MCP name is in MCP_SELECTION.
    local name="$1"
    local m
    for m in "${MCP_SELECTION[@]}"; do
        [[ "$m" == "$name" ]] && return 0
    done
    return 1
}

node_version_ok() {
    # Returns 0 if `node` is on PATH and its major version is >= 20.
    if ! command -v node >/dev/null 2>&1; then
        echo "Warning: Node.js was not found in PATH. MCP server installation was skipped (plugin installation continues)." >&2
        return 1
    fi
    local version major
    version="$(node --version 2>/dev/null)" || version=""
    # Expected form: vNN.N.N
    major="${version#v}"
    major="${major%%.*}"
    if [[ -z "$major" || ! "$major" =~ ^[0-9]+$ ]]; then
        echo "Warning: Could not determine Node.js version (got '${version}'). MCP server installation was skipped (plugin installation continues)." >&2
        return 1
    fi
    if [[ "$major" -lt 20 ]]; then
        echo "Warning: Node.js >= 20 is required for MCP servers (found ${version}). MCP server installation was skipped (plugin installation continues)." >&2
        return 1
    fi
    return 0
}

place_mcp_servers() {
    # Copies the minimal MCP payload (dist/ + package.json) for each selected
    # MCP from the source tree into INSTALL_ROOT/mcp/<name>/. This is
    # independent of Git tracking state (unlike REQUIRED_PATHS) because the
    # MCP dist/ bundle is not yet committed to the repository as of this task.
    local source_root="$1"
    local install_root_path="$2"
    local name src_dir dest_dir
    for name in "${MCP_SELECTION[@]}"; do
        src_dir="${source_root}/mcp/${name}"
        if [[ ! -f "${src_dir}/dist/index.js" || ! -f "${src_dir}/package.json" ]]; then
            echo "Warning: MCP server '${name}' payload (dist/index.js, package.json) was not found under mcp/${name}. Skipping placement." >&2
            continue
        fi
        dest_dir="${install_root_path}/mcp/${name}"
        mkdir -p "${dest_dir}/dist"
        cp -R "${src_dir}/dist/." "${dest_dir}/dist/"
        cp -f "${src_dir}/package.json" "${dest_dir}/package.json"
    done
}

register_claude_mcp() {
    # Registers each selected MCP with Claude Code (user scope). Best-effort:
    # a missing Claude CLI is a warning, mirroring install_claude_plugins.
    local install_root_path="$1"
    if ! command -v claude >/dev/null 2>&1; then
        echo "Warning: Claude Code CLI was not found. Claude MCP registration was skipped." >&2
        return 0
    fi
    local name entry_point
    for name in "${MCP_SELECTION[@]}"; do
        entry_point="${install_root_path}/mcp/${name}/dist/index.js"
        [[ -f "$entry_point" ]] || continue
        run_plugin_command claude mcp add "$name" --scope user -- node "$entry_point" || return 1
    done
}

register_codex_mcp() {
    # Idempotently adds/replaces a marker-delimited block in
    # ~/.codex/config.toml for each selected MCP. If config.toml does not
    # exist, registration is skipped with a warning (a new file is never
    # created, per requirements).
    local install_root_path="$1"
    local codex_home="${SDD_CODEX_HOME:-$HOME/.codex}"
    local config_toml="${codex_home}/config.toml"
    if [[ ! -f "$config_toml" ]]; then
        echo "Warning: ${config_toml} was not found. Codex MCP registration was skipped (the installer does not create a new config.toml)." >&2
        return 0
    fi
    local name entry_point block_file tmp_config
    for name in "${MCP_SELECTION[@]}"; do
        entry_point="${install_root_path}/mcp/${name}/dist/index.js"
        [[ -f "$entry_point" ]] || continue
        local marker_begin="# >>> ${name} (managed by sdd-forge installer; do not edit by hand) >>>"
        local marker_end="# <<< ${name} <<<"
        tmp_config="$(mktemp)"
        # Strip any prior block for this MCP (idempotent re-registration),
        # then append a fresh block.
        awk -v begin="$marker_begin" -v end="$marker_end" '
            $0 == begin { skip = 1; next }
            $0 == end { skip = 0; next }
            skip { next }
            { print }
        ' "$config_toml" > "$tmp_config"
        {
            cat "$tmp_config"
            printf '\n%s\n[mcp_servers.%s]\ncommand = "node"\nargs = ["%s"]\n%s\n' \
                "$marker_begin" "$name" "$entry_point" "$marker_end"
        } > "${tmp_config}.new"
        mv "${tmp_config}.new" "$config_toml"
        rm -f "$tmp_config"
    done
}

MCP_NODE_OK=0

place_mcp_servers_if_selected() {
    # Placement (like plugin files) happens regardless of --target; only
    # registration is target-scoped. Sets MCP_NODE_OK for callers to check
    # before attempting registration.
    local source_root="$1"
    local install_root_path="$2"
    MCP_NODE_OK=0
    if [[ $SKIP_MCP -eq 1 || ${#MCP_SELECTION[@]} -eq 0 ]]; then
        return 0
    fi
    if ! node_version_ok; then
        return 0
    fi
    MCP_NODE_OK=1
    place_mcp_servers "$source_root" "$install_root_path"
}

install_mcp_servers() {
    local install_root_path="$1"
    if [[ $SKIP_MCP -eq 1 || ${#MCP_SELECTION[@]} -eq 0 || $MCP_NODE_OK -ne 1 ]]; then
        return 0
    fi
    if [[ "$TARGET" == "All" || "$TARGET" == "Claude" ]]; then
        register_claude_mcp "$install_root_path" || return 1
    fi
    if [[ "$TARGET" == "All" || "$TARGET" == "Codex" ]]; then
        register_codex_mcp "$install_root_path" || return 1
    fi
}

# ---------------------------------------------------------------------------
# Cleanup state
# ---------------------------------------------------------------------------
TEMPORARY_ROOT=""
BACKUP_ROOT=""
STAGING_ROOT=""
NEW_INSTALL_PLACED=0
LOCK_DIR=""
LOCK_HELD=0

cleanup() {
    # Called from trap EXIT — runs on every exit path
    if [[ -n "$STAGING_ROOT" && -d "$STAGING_ROOT" ]]; then
        rm -rf "$STAGING_ROOT"
    fi
    if [[ -n "$TEMPORARY_ROOT" && -d "$TEMPORARY_ROOT" ]]; then
        rm -rf "$TEMPORARY_ROOT"
    fi
    # Release the exclusive lock if we hold it.
    # Only remove the lock directory we created — never remove a lock we do not hold.
    if [[ $LOCK_HELD -eq 1 && -n "$LOCK_DIR" && -d "$LOCK_DIR" ]]; then
        rm -rf "$LOCK_DIR"
        LOCK_HELD=0
    fi
}

rollback() {
    # Restore previous installation on error
    if [[ -n "$BACKUP_ROOT" && -d "$BACKUP_ROOT" ]]; then
        if [[ -d "$INSTALL_ROOT" ]]; then
            rm -rf "$INSTALL_ROOT"
        fi
        mv "$BACKUP_ROOT" "$INSTALL_ROOT"
        BACKUP_ROOT=""
    elif [[ $NEW_INSTALL_PLACED -eq 1 && -d "$INSTALL_ROOT" ]]; then
        rm -rf "$INSTALL_ROOT"
    fi
}

trap 'rc=$?; rollback; cleanup; exit $rc' EXIT

# ---------------------------------------------------------------------------
# Resolve source
# ---------------------------------------------------------------------------
SOURCE_IS_LOCAL=0
if [[ -n "$SOURCE_DIRECTORY" ]]; then
    SOURCE_ROOT="$(cd "$SOURCE_DIRECTORY" && pwd)"
    SOURCE_IS_LOCAL=1
    if ! git_prefix="$(git -C "$SOURCE_ROOT" rev-parse --show-prefix 2>/dev/null)" || [[ -n "$git_prefix" ]]; then
        echo "Error: --source-directory must be the root of a Git worktree so only tracked files can be installed." >&2
        exit 1
    fi
else
    TEMPORARY_ROOT="$(mktemp -d)"
    download_authenticated_archive "${TEMPORARY_ROOT}/source.tar.gz"
    tar -xzf "${TEMPORARY_ROOT}/source.tar.gz" -C "$TEMPORARY_ROOT"

    SOURCE_ROOT=""
    for d in "${TEMPORARY_ROOT}"/*/; do
        if [[ -f "${d}.agents/plugins/marketplace.json" ]]; then
            SOURCE_ROOT="${d%/}"
            break
        fi
    done
    if [[ -z "$SOURCE_ROOT" ]]; then
        echo "Error: The downloaded archive does not contain an SDD plugin marketplace." >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Validate required paths
# ---------------------------------------------------------------------------
REQUIRED_PATHS=(
    ".agents/plugins/marketplace.json"
    ".claude-plugin/marketplace.json"
    "plugins/sdd-bootstrap/.codex-plugin/plugin.json"
    "plugins/sdd-bootstrap/.plugin/plugin.json"
    "plugins/sdd-ship/.claude-plugin/plugin.json"
    "plugins/sdd-ship/.codex-plugin/plugin.json"
    "plugins/sdd-ship/.plugin/plugin.json"
    "plugins/sdd-implementation/.codex-plugin/plugin.json"
    "plugins/sdd-implementation/.plugin/plugin.json"
    "plugins/sdd-quality-loop/.codex-plugin/plugin.json"
    "plugins/sdd-quality-loop/.plugin/plugin.json"
    "plugins/sdd-lite/.codex-plugin/plugin.json"
    "plugins/sdd-lite/.plugin/plugin.json"
    "plugins/sdd-review-loop/.claude-plugin/plugin.json"
    "plugins/sdd-review-loop/.codex-plugin/plugin.json"
    "plugins/sdd-review-loop/.plugin/plugin.json"
    ".codex/agents/sdd-investigator.toml"
    ".codex/agents/sdd-evaluator.toml"
)
for rel in "${REQUIRED_PATHS[@]}"; do
    if [[ ! -e "${SOURCE_ROOT}/${rel}" ]]; then
        echo "Error: Required file is missing: ${rel}" >&2
        exit 1
    fi
done

# A local worktree is staged from its Git index, not by recursively copying the
# directory. Reject a source whose required release files are present only as
# untracked working-tree changes; otherwise the installation could report
# success while omitting a required manifest from the staged result.
if [[ $SOURCE_IS_LOCAL -eq 1 ]]; then
    for rel in "${REQUIRED_PATHS[@]}"; do
        if ! git -C "$SOURCE_ROOT" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
            echo "Error: Required file is not Git-tracked in --source-directory: ${rel}" >&2
            exit 1
        fi
    done
fi

# Validate all sdd-*.toml files: must have no BOM and must define name and developer_instructions.
agent_source_dir="${SOURCE_ROOT}/.codex/agents"
if [[ -d "$agent_source_dir" ]]; then
    for toml_file in "${agent_source_dir}"/sdd-*.toml; do
        [[ -f "$toml_file" ]] || continue
        # Check for UTF-8 BOM
        if head -c 3 "$toml_file" | LC_ALL=C grep -q "$(printf '\xef\xbb\xbf')"; then
            echo "Error: Malformed Codex agent role file (must define developer_instructions, no BOM): $(basename "$toml_file")" >&2
            exit 1
        fi
        # Check for name and developer_instructions
        if ! grep -Eq '^name[[:space:]]*=' "$toml_file"; then
            echo "Error: Malformed Codex agent role file (must define developer_instructions, no BOM): $(basename "$toml_file")" >&2
            exit 1
        fi
        if ! grep -Eq '^developer_instructions[[:space:]]*=' "$toml_file"; then
            echo "Error: Malformed Codex agent role file (must define developer_instructions, no BOM): $(basename "$toml_file")" >&2
            exit 1
        fi
    done
fi

# ---------------------------------------------------------------------------
# Resolve install root and safety checks
# ---------------------------------------------------------------------------
# Canonicalise without requiring the path to already exist.
# Preference order: python3 (most portable), realpath -m (GNU coreutils),
# then a pure-shell fallback that does NOT create directories or silently
# yield a wrong path if cd fails.
_canon_install_root() {
    local p="$1"
    # python3: available on macOS 12+ and virtually all Linux distros
    if python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$p" 2>/dev/null; then
        return 0
    fi
    # realpath -m: GNU coreutils; BSD realpath (macOS) does not support -m
    if realpath -m "$p" 2>/dev/null; then
        return 0
    fi
    # An absolute path with no '.'/'..' segments needs no resolution; accept it
    # as-is. This covers default roots whose parents may not exist yet
    # (e.g. ~/.local/share/sdd-plugins on a fresh macOS without python3).
    case "$p" in
        /*)
            case "/${p}/" in
                */./*|*/../*) : ;;
                *) printf '%s\n' "$p"; return 0 ;;
            esac
            ;;
    esac
    # Pure-shell fallback: resolve existing parent first, then append basename.
    # Validates that parent either exists or can be resolved; exits on cd failure
    # rather than continuing with a wrong path.
    local _parent _base
    _parent="$(dirname "$p")"
    _base="$(basename "$p")"
    # Resolve parent without creating it (it must already exist or be creatable
    # — we create it in the staging step only after all validation has passed).
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
# Check it is not exactly a root by seeing if parent == itself
_parent="$(dirname "$INSTALL_ROOT")"
if [[ "$_parent" == "$INSTALL_ROOT" ]]; then
    echo "Error: --install-root must not be a filesystem root: $INSTALL_ROOT" >&2
    exit 1
fi

# Must differ from source directory
_resolved_source="$(cd "$SOURCE_ROOT" && pwd)"
if [[ "$INSTALL_ROOT" == "$_resolved_source" ]]; then
    echo "Error: --install-root must differ from --source-directory." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Stage, swap, register
# ---------------------------------------------------------------------------
INSTALL_PARENT="$(dirname "$INSTALL_ROOT")"
mkdir -p "$INSTALL_PARENT"

# ---------------------------------------------------------------------------
# Exclusive per-install-root lock (atomic mkdir; portable: no flock required)
#
# LOCK_DIR is a sibling of INSTALL_ROOT so separate roots never contend.
# mkdir is atomic on POSIX — only one process can succeed for a given path.
# Stale-lock reclaim: if the lock's mtime is older than SDD_INSTALL_LOCK_STALE
# seconds (default 600) OR the recorded pid is not alive, the lock is reclaimed.
# Staleness is decided by ownership first: a lock whose recorded PID is still
# alive is NEVER reclaimed, however old it is (a long install must not be
# evicted). Only a dead/unknown owner makes a lock eligible, and reclamation is
# done by an atomic rename (one racer wins) followed by a re-check that the
# claimed lock is the dead one we observed — so a racer cannot delete a fresh
# lock another installer just created.
# ---------------------------------------------------------------------------
LOCK_DIR="${INSTALL_ROOT}.sdd-install.lock"
_lock_timeout="${SDD_INSTALL_LOCK_TIMEOUT:-120}"
_lock_stale="${SDD_INSTALL_LOCK_STALE:-600}"
_lock_deadline=$(( $(date +%s) + _lock_timeout ))
_lock_reclaimed=0

while true; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        # We created the directory — we own the lock.
        printf '%s\n' "$$" > "${LOCK_DIR}/pid"
        LOCK_HELD=1
        break
    fi

    # Lock exists — decide staleness before waiting. Ownership wins: a live
    # recorded PID is never stale (don't evict a long-running install).
    if [[ $_lock_reclaimed -eq 0 && -d "$LOCK_DIR" ]]; then
        _stale=0
        _lock_pid=""
        if [[ -f "${LOCK_DIR}/pid" ]]; then
            _lock_pid="$(cat "${LOCK_DIR}/pid" 2>/dev/null || true)"
        fi
        if [[ -n "$_lock_pid" ]]; then
            # Owner known: stale only if that process is no longer alive.
            if ! kill -0 "$_lock_pid" 2>/dev/null; then
                _stale=1
            fi
        else
            # Owner unknown (missing/empty pid): fall back to mtime age.
            _lock_mtime=0
            if _lock_mtime_raw="$(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null)"; then
                _lock_mtime="$_lock_mtime_raw"
            fi
            _now="$(date +%s)"
            if (( _now - _lock_mtime > _lock_stale )); then
                _stale=1
            fi
        fi
        if [[ $_stale -eq 1 ]]; then
            # Atomic, ownership-checked reclamation. Rename the stale lock to a
            # private name (only one racer can win this rename); then verify the
            # claimed lock is the dead-owner one we observed before removing it.
            # If it changed underfoot (a fresh lock), put it back and retry.
            _claim="${LOCK_DIR}.reclaim.$$.${RANDOM}"
            if mv "$LOCK_DIR" "$_claim" 2>/dev/null; then
                _claim_pid=""
                if [[ -f "${_claim}/pid" ]]; then
                    _claim_pid="$(cat "${_claim}/pid" 2>/dev/null || true)"
                fi
                if [[ "$_claim_pid" == "$_lock_pid" ]] && { [[ -z "$_claim_pid" ]] || ! kill -0 "$_claim_pid" 2>/dev/null; }; then
                    rm -rf "$_claim" 2>/dev/null || true
                else
                    # Not the lock we observed (likely a fresh one) — restore it.
                    mv "$_claim" "$LOCK_DIR" 2>/dev/null || rm -rf "$_claim" 2>/dev/null || true
                fi
            fi
            _lock_reclaimed=1
            continue  # retry mkdir
        fi
    fi

    # Check timeout
    if (( $(date +%s) >= _lock_deadline )); then
        echo "Error: another sdd-forge install is in progress (lock: ${LOCK_DIR}). Retry later, or remove the lock if it is stale." >&2
        exit 1
    fi

    sleep 0.5
done
unset _lock_timeout _lock_stale _lock_deadline _lock_reclaimed _stale _lock_mtime _lock_mtime_raw _now _lock_pid _claim _claim_pid

STAGING_ROOT="$(mktemp -d "${INSTALL_PARENT}/sdd-plugins-staging-XXXXXX")"

# A local worktree can contain credentials, caches, and nested untracked files.
# Copy its Git index only. Downloaded archives are trusted release inputs and
# have no local untracked state, so retain their complete archive layout.
# The mcp/ tree is excluded here even though it is Git-tracked: MCP payload
# placement is handled exclusively by place_mcp_servers (dist/ + package.json
# only, gated by --skip-mcp / --mcp / the Node >= 20 check), so staging it
# unconditionally here would bypass that gating.
if [[ $SOURCE_IS_LOCAL -eq 1 ]]; then
    while IFS= read -r -d '' relative_path; do
        destination_path="${STAGING_ROOT}/${relative_path}"
        mkdir -p "$(dirname "$destination_path")"
        cp -P "${SOURCE_ROOT}/${relative_path}" "$destination_path"
    done < <(git -C "$SOURCE_ROOT" ls-files -z -- . ':!mcp/**')
else
    for entry in "${SOURCE_ROOT}"/* "${SOURCE_ROOT}"/.[!.]* "${SOURCE_ROOT}"/..?*; do
        [[ -e "$entry" ]] || continue
        case "$(basename "$entry")" in
            .git|mcp) continue ;;
        esac
        cp -R "$entry" "${STAGING_ROOT}/"
    done
fi

# Backup existing install — generate a unique path without pre-creating it
# so that `mv` renames the directory rather than moving it inside.
if [[ -d "$INSTALL_ROOT" ]]; then
    BACKUP_ROOT="${INSTALL_PARENT}/sdd-plugins-backup-$$-${RANDOM}${RANDOM}"
    while [[ -e "$BACKUP_ROOT" ]]; do
        BACKUP_ROOT="${INSTALL_PARENT}/sdd-plugins-backup-$$-${RANDOM}${RANDOM}"
    done
    mv "$INSTALL_ROOT" "$BACKUP_ROOT"
fi

mv "$STAGING_ROOT" "$INSTALL_ROOT"
STAGING_ROOT=""
NEW_INSTALL_PLACED=1

RESOLVED_INSTALL_ROOT="$(cd "$INSTALL_ROOT" && pwd)"

# MCP placement mirrors plugin file placement: it happens regardless of
# --target and is controlled only by --skip-mcp / --mcp.
place_mcp_servers_if_selected "$SOURCE_ROOT" "$RESOLVED_INSTALL_ROOT"

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
# Track whether codex agent install succeeded so we can warn in the summary.
CODEX_AGENTS_FAILED=0

if [[ "$TARGET" == "All" || "$TARGET" == "Codex" ]]; then
    install_codex_plugins "$RESOLVED_INSTALL_ROOT" || exit 1
    if [[ $SKIP_AGENT_INSTALL -eq 0 ]] && command -v codex >/dev/null 2>&1; then
        install_codex_agents "$RESOLVED_INSTALL_ROOT" || CODEX_AGENTS_FAILED=1
    fi
fi
if [[ "$TARGET" == "All" || "$TARGET" == "Claude" ]]; then
    install_claude_plugins "$RESOLVED_INSTALL_ROOT" || exit 1
fi
if [[ "$TARGET" == "All" || "$TARGET" == "Copilot" ]]; then
    install_copilot_plugins "$RESOLVED_INSTALL_ROOT" || exit 1
fi
install_mcp_servers "$RESOLVED_INSTALL_ROOT" || exit 1

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
echo ""
echo "SDD plugins installed at: ${RESOLVED_INSTALL_ROOT}"
if [[ "$TARGET" == "FilesOnly" ]]; then
    echo "Plugin registration was skipped because --target=FilesOnly."
fi
if [[ $CODEX_AGENTS_FAILED -eq 1 ]]; then
    echo "" >&2
    echo "WARNING: Codex agents were not installed to ~/.codex/agents." >&2
    echo "         Re-run the installer or copy .codex/agents/sdd-*.toml manually." >&2
fi

# Remove backup on success
if [[ -n "$BACKUP_ROOT" && -d "$BACKUP_ROOT" ]]; then
    rm -rf "$BACKUP_ROOT"
    BACKUP_ROOT=""
fi

# Disarm rollback — success path
NEW_INSTALL_PLACED=0
