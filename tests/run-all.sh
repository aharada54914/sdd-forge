#!/usr/bin/env bash
# The catalog owns suite registration across runtimes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
for argument in "$@"; do
  case "$argument" in
    --list|--plan|--run) exec python3 "$ROOT/tests/verification.py" --profile local-posix "$@" ;;
  esac
done
exec python3 "$ROOT/tests/verification.py" --profile local-posix --run "$@"
