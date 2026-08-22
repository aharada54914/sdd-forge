#!/bin/sh
# Thin POSIX dispatcher for validate-facet-manifest (Python master).
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if ! . "$dir/lib/py-dispatch.sh"; then
  echo 'validate-facet-manifest: VALIDATE_FACET_MANIFEST_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi

sdd_py_dispatch "$dir/validate-facet-manifest.py" 'validate-facet-manifest: VALIDATE_FACET_MANIFEST_RUNTIME_UNAVAILABLE' "$@"
