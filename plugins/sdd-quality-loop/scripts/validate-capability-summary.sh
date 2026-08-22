#!/bin/sh
# Thin POSIX dispatcher for validate-capability-summary (Python master).
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if ! . "$dir/lib/py-dispatch.sh"; then
  echo 'validate-capability-summary: VALIDATE_CAPABILITY_SUMMARY_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi

sdd_py_dispatch "$dir/validate-capability-summary.py" 'validate-capability-summary: VALIDATE_CAPABILITY_SUMMARY_RUNTIME_UNAVAILABLE' "$@"
