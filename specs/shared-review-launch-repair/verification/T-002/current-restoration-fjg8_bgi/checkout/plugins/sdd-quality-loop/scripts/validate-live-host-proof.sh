#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$SCRIPT_DIR/validate-live-host-proof.py" "$@"
fi
if command -v python >/dev/null 2>&1; then
  exec python "$SCRIPT_DIR/validate-live-host-proof.py" "$@"
fi

printf 'ERR_SCHEMA_INVALID: Python runtime unavailable\n' >&2
exit 3
