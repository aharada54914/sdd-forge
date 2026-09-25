#!/usr/bin/env bash
set -euo pipefail

# Compatibility entry point. The former script targeted an obsolete
# origin/main snapshot and a stale fixture patch. Delegate to the
# current-main atomic helper, which validates the target tip and candidate
# hashes before touching protected files.
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
exec bash "$ROOT/reports/verification/issue311-human-apply-main-20260923.sh" "$@"
