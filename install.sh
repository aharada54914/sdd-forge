#!/usr/bin/env bash
# install.sh — SDD plugins installer for macOS and Linux
# Mirrors install.ps1 behavior exactly.
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
REPOSITORY="aharada54914/sdd-plugins-windows-installer"
REF="main"
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/sdd-plugins"
TARGET="All"
PLUGINS="sdd-bootstrap,sdd-implementation,sdd-quality-loop"
SKIP_PLUGIN_INSTALL=0
SKIP_AGENT_INSTALL=0
SOURCE_DIRECTORY=""

VALID_PLUGINS="sdd-bootstrap sdd-implementation sdd-quality-loop"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
    cat >&2 <<EOF
Usage: install.sh [options]

  --repository <owner/repo>      Default: aharada54914/sdd-plugins-windows-installer
  --ref <ref>                    Default: main
  --install-root <path>          Default: \${XDG_DATA_HOME:-\$HOME/.local/share}/sdd-plugins
  --target All|Codex|Claude|Copilot|FilesOnly
                                 Default: All
  --plugins <comma-separated>    Names from: sdd-bootstrap,sdd-implementation,sdd-quality-loop
                                 Default: all three
  --skip-plugin-install          Skip registering plugins with CLI tools
  --skip-agent-install           Skip copying Codex agent TOML files
  --source-directory <path>      Use a local directory instead of downloading

Environment: SDD_CODEX_HOME     Override ~/.codex destination for agent TOML files
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
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# Validate --target
case "$TARGET" in
    All|Codex|Claude|Copilot|FilesOnly) ;;
    *) echo "Invalid --target value: $TARGET (must be All, Codex, Claude, Copilot, or FilesOnly)" >&2; usage ;;
esac

# Validate --plugins
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
# Cleanup state
# ---------------------------------------------------------------------------
TEMPORARY_ROOT=""
BACKUP_ROOT=""
STAGING_ROOT=""
NEW_INSTALL_PLACED=0

cleanup() {
    # Called from trap EXIT — runs on every exit path
    if [[ -n "$STAGING_ROOT" && -d "$STAGING_ROOT" ]]; then
        rm -rf "$STAGING_ROOT"
    fi
    if [[ -n "$TEMPORARY_ROOT" && -d "$TEMPORARY_ROOT" ]]; then
        rm -rf "$TEMPORARY_ROOT"
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
if [[ -n "$SOURCE_DIRECTORY" ]]; then
    SOURCE_ROOT="$(cd "$SOURCE_DIRECTORY" && pwd)"
else
    TEMPORARY_ROOT="$(mktemp -d)"
    DOWNLOAD_URL="https://codeload.github.com/${REPOSITORY}/tar.gz/${REF}"
    echo "Downloading ${DOWNLOAD_URL}"
    curl -fsSL "$DOWNLOAD_URL" -o "${TEMPORARY_ROOT}/source.tar.gz"
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
    "plugins/sdd-implementation/.codex-plugin/plugin.json"
    "plugins/sdd-quality-loop/.codex-plugin/plugin.json"
    "plugins/sdd-bootstrap/.plugin/plugin.json"
    "plugins/sdd-implementation/.plugin/plugin.json"
    "plugins/sdd-quality-loop/.plugin/plugin.json"
    ".codex/agents/sdd-investigator.toml"
    ".codex/agents/sdd-evaluator.toml"
)
for rel in "${REQUIRED_PATHS[@]}"; do
    if [[ ! -e "${SOURCE_ROOT}/${rel}" ]]; then
        echo "Error: Required file is missing: ${rel}" >&2
        exit 1
    fi
done

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

STAGING_ROOT="$(mktemp -d "${INSTALL_PARENT}/sdd-plugins-staging-XXXXXX")"

# Copy everything including dot-dirs.
# `cp -R src/. dst/` copies dot-directories on all POSIX platforms; an
# additional explicit loop would double-nest them (.agents/.agents/ etc.).
cp -R "${SOURCE_ROOT}/." "${STAGING_ROOT}/"

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
