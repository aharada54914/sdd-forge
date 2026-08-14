#!/bin/sh
# Thin argument-forwarding wrapper for generate-gate-capabilities.py
# (Python master). INV-014 (the sdd-hook-guard.sh pattern).
set -eu
dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/generate-gate-capabilities.py" "$@"
elif command -v python >/dev/null 2>&1; then
  exec python "$dir/generate-gate-capabilities.py" "$@"
else
  echo "generate-gate-capabilities: python3 (or python) is required" >&2
  exit 1
fi
