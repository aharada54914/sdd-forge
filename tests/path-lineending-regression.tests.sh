#!/usr/bin/env bash
# Acceptance driver for REQ-004 (TEST-018 through TEST-021).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON=python
else
  printf 'python3 or python is required\n' >&2
  exit 1
fi
exec "$PYTHON" "${ROOT}/tests/fixtures/path-lineending-regression/run_matrix.py"
