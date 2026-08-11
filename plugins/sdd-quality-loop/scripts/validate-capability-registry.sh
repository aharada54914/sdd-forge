#!/bin/sh
# Thin argument-forwarding wrapper for validate-capability-registry.py
# (Python master). INV-014 (the sdd-hook-guard.sh pattern).
set -eu
dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/validate-capability-registry.py" "$@"
elif command -v python >/dev/null 2>&1; then
  exec python "$dir/validate-capability-registry.py" "$@"
else
  echo "validate-capability-registry: python3 (or python) is required" >&2
  exit 1
fi
