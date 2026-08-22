#!/bin/sh
# Thin POSIX dispatcher for generate-approval-sidecar (REQ-004). Exactly
# ONE behavioral implementation exists (the Python master beside this
# file); this wrapper never reimplements generation natively.
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# Probe before sourcing: POSIX shells (dash among them) treat a failed `.`
# special builtin as fatal, so an if-guard around the dot itself can never
# run its else branch -- the readability test is what keeps the documented
# exit 3 reachable on a partial or damaged installation.
if [ ! -r "$dir/lib/py-dispatch.sh" ]; then
  echo 'generate-approval-sidecar: GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi
. "$dir/lib/py-dispatch.sh"

sdd_py_dispatch "$dir/generate-approval-sidecar.py" 'generate-approval-sidecar: GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE' "$@"
