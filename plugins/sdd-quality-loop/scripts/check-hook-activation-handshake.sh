#!/bin/sh
# Thin POSIX dispatcher for check-hook-activation-handshake. Exactly ONE
# behavioral implementation exists (the Python master beside this file).
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if ! . "$dir/lib/py-dispatch.sh"; then
  echo 'check-hook-activation-handshake: CHECK_HOOK_ACTIVATION_HANDSHAKE_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi

sdd_py_dispatch "$dir/check-hook-activation-handshake.py" 'check-hook-activation-handshake: CHECK_HOOK_ACTIVATION_HANDSHAKE_RUNTIME_UNAVAILABLE' "$@"
