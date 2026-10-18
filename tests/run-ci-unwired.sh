#!/usr/bin/env bash
# Explicit CI fallback membership; no workflow source inference.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
for argument in "$@"; do
  case "$argument" in
    --list|--plan|--run) exec python3 "$ROOT/tests/verification.py" --profile ci-posix-fallback "$@" ;;
  esac
done
exec python3 "$ROOT/tests/verification.py" --profile ci-posix-fallback --run "$@"
