#!/bin/sh
# Thin POSIX dispatcher for validate-approval-sidecar (REQ-005). Exactly
# ONE behavioral implementation exists (the Python master beside this
# file); this wrapper never reimplements validation natively.
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if ! . "$dir/lib/py-dispatch.sh"; then
  echo 'validate-approval-sidecar: VALIDATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi

sdd_py_dispatch "$dir/validate-approval-sidecar.py" 'validate-approval-sidecar: VALIDATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE' "$@"
