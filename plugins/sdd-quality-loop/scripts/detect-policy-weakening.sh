#!/bin/sh
# Thin POSIX dispatcher for detect-policy-weakening (REQ-006). Exactly
# ONE behavioral implementation exists (the Python master beside this
# file); this wrapper never reimplements classification/verdict logic
# natively.
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if ! . "$dir/lib/py-dispatch.sh"; then
  echo 'detect-policy-weakening: DETECT_POLICY_WEAKENING_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi

sdd_py_dispatch "$dir/detect-policy-weakening.py" 'detect-policy-weakening: DETECT_POLICY_WEAKENING_RUNTIME_UNAVAILABLE' "$@"
