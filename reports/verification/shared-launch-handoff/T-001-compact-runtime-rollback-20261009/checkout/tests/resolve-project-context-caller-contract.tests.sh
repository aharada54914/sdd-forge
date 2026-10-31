#!/bin/sh
# A5 caller contract: live SKILL integration, AC-042/046/053.
set -eu
printf '%s\n' '# runner: bash'
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$ROOT/tests/resolve-project-context-caller-contract-check.py" --launcher sh
fi
if command -v python >/dev/null 2>&1; then
  exec python "$ROOT/tests/resolve-project-context-caller-contract-check.py" --launcher sh
fi
printf '%s\n' 'FAIL: no python3/python interpreter available' >&2
exit 1
