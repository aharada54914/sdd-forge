#!/bin/sh
# Thin argument-forwarding wrapper for evaluate-predicate.py (Python master).
# INV-014 (the sdd-hook-guard.sh pattern): all evaluation logic lives in the
# Python master; this wrapper only locates it and forwards arguments as-is.
set -eu
dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/evaluate-predicate.py" "$@"
elif command -v python >/dev/null 2>&1; then
  exec python "$dir/evaluate-predicate.py" "$@"
else
  echo "evaluate-predicate: python3 (or python) is required" >&2
  exit 1
fi
