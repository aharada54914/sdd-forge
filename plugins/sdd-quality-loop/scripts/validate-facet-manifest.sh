#!/usr/bin/env bash
# Thin wrapper: dispatch to the single Python implementation
# (validate-facet-manifest.py). No runtime-specific logic lives here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "${SCRIPT_DIR}/validate-facet-manifest.py" "$@"
