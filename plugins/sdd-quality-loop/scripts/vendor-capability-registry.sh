#!/bin/sh
# Thin POSIX dispatcher for vendor-capability-registry (Python master).
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if ! . "$dir/lib/py-dispatch.sh"; then
  echo 'vendor-capability-registry: VENDOR_CAPABILITY_REGISTRY_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi

sdd_py_dispatch "$dir/vendor-capability-registry.py" 'vendor-capability-registry: VENDOR_CAPABILITY_REGISTRY_RUNTIME_UNAVAILABLE' "$@"
