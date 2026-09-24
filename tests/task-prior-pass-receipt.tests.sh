#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if command -v python3 >/dev/null 2>&1; then
  python_bin=python3
elif command -v python >/dev/null 2>&1; then
  python_bin=python
else
  printf 'task-prior-pass-receipt: Python 3 is required\n' >&2
  exit 1
fi
exec "$python_bin" "$root/tests/task-prior-pass-receipt.tests.py"
