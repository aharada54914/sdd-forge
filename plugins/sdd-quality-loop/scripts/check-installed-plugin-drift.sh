#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/sdd-plugins"
MODE="preflight"
TARGET="All"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-root) [[ $# -ge 2 ]] || { echo "--install-root requires a path" >&2; exit 2; }; INSTALL_ROOT="$2"; shift 2 ;;
        --mode) [[ $# -ge 2 ]] || { echo "--mode requires preflight or verify" >&2; exit 2; }; MODE="$2"; shift 2 ;;
        --target) [[ $# -ge 2 ]] || { echo "--target requires All|Codex|Claude|Copilot" >&2; exit 2; }; TARGET="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$MODE" in preflight|verify) ;; *) echo "Invalid --mode: $MODE" >&2; exit 2 ;; esac
exec python3 "${SCRIPT_DIR}/check-installed-plugin-drift.py" \
    --install-root "$INSTALL_ROOT" --mode "$MODE" --target "$TARGET"
