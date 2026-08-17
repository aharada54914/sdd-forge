#!/usr/bin/env bash
# Thin wrapper: dispatch to the single Python implementation
# (compare-facet-manifest-staleness.py). No runtime-specific logic lives
# here. Both channels (stdout verdict, stderr exit-3 diagnostics) pass
# through unmodified.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "${SCRIPT_DIR}/compare-facet-manifest-staleness.py" "$@"
