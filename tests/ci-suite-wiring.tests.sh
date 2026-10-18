#!/usr/bin/env bash
# Registration, planning and failure propagation share the executable catalog.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
python3 "$ROOT/tests/verification-catalog.tests.py"
# Structural workflow coverage is checked by required-checks-posix.tests.py;
# the fallback no longer infers execution from workflow formatting.
