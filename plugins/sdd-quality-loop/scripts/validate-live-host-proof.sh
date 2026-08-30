#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$SCRIPT_DIR/lib/py-dispatch.sh"

sdd_py_dispatch \
  "$SCRIPT_DIR/validate-live-host-proof.py" \
  "validate-live-host-proof: ERR_SCHEMA_INVALID" \
  "$@"
