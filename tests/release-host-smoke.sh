#!/usr/bin/env bash
# release-host-smoke.sh — opt-in real CLI smoke for release operators.
#
# This deliberately uses real Codex, Claude Code, and Copilot CLIs rather than
# the deterministic shims in install.tests.sh. It is never run in pull-request
# CI: each host may require an authenticated release-operator session.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${REPO_ROOT}/install.sh"
HOSTS="codex,claude,copilot"

usage() {
    cat >&2 <<'EOF'
Usage: SDD_RELEASE_HOST_SMOKE=1 ./tests/release-host-smoke.sh [--hosts codex,claude,copilot]

Runs actual host CLI registration against a disposable local source install.
All selected CLIs must be installed and authenticated; unavailable hosts fail
loudly. Host configuration is isolated and removed after the smoke test.
EOF
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hosts) [[ $# -gt 1 ]] || usage; HOSTS="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [[ "${SDD_RELEASE_HOST_SMOKE:-}" != "1" ]]; then
    echo "Refusing to run real host smoke: set SDD_RELEASE_HOST_SMOKE=1." >&2
    exit 2
fi

SMOKE_ROOT="$(mktemp -d)"
CONFIG_ROOT="${SDD_HOST_SMOKE_CONFIG_ROOT:-${SMOKE_ROOT}/config}"
if [[ -e "$CONFIG_ROOT" ]]; then
    echo "SDD_HOST_SMOKE_CONFIG_ROOT must not already exist: $CONFIG_ROOT" >&2
    exit 2
fi
trap 'rm -rf "$SMOKE_ROOT" "$CONFIG_ROOT"' EXIT

# These locations are intentionally fresh. They prevent the smoke from
# registering plugins in the release operator's normal configuration.
export CODEX_HOME="${CONFIG_ROOT}/codex"
export CLAUDE_CONFIG_DIR="${CONFIG_ROOT}/claude"
export XDG_CONFIG_HOME="${CONFIG_ROOT}/xdg"
export SDD_CODEX_HOME="${CONFIG_ROOT}/sdd-codex"

IFS=',' read -r -a selected_hosts <<< "$HOSTS"
for host in "${selected_hosts[@]}"; do
    case "$host" in
        codex) target="Codex" ;;
        claude) target="Claude" ;;
        copilot) target="Copilot" ;;
        *) echo "Unknown host: $host" >&2; exit 2 ;;
    esac

    if ! command -v "$host" >/dev/null 2>&1; then
        echo "Release host smoke requires '$host' in PATH; refusing to skip it." >&2
        exit 1
    fi

    install_root="${SMOKE_ROOT}/${host}-install"
    echo "Running real ${host} registration smoke."
    "$INSTALLER" \
        --source-directory "$REPO_ROOT" \
        --install-root "$install_root" \
        --target "$target" \
        --plugins sdd-bootstrap \
        --skip-agent-install

    for plugin in sdd-bootstrap sdd-review-loop; do
        if [[ ! -f "${install_root}/plugins/${plugin}/.codex-plugin/plugin.json" ]]; then
            echo "Real ${host} smoke did not stage ${plugin}." >&2
            exit 1
        fi
    done
done

echo "Release host smoke passed for: ${HOSTS}"
