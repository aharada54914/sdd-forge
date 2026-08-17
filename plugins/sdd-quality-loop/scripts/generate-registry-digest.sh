#!/bin/sh
# Thin argument-forwarding wrapper for generate-registry-digest.py.
set -eu
dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/generate-registry-digest.py" "$@"
elif command -v python >/dev/null 2>&1; then
  exec python "$dir/generate-registry-digest.py" "$@"
else
  echo "generate-registry-digest: python3 (or python) is required" >&2
  exit 3
fi
