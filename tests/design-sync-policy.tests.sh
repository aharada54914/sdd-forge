#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
exec python3 -B "$ROOT/tests/design-sync-policy.tests.py"
