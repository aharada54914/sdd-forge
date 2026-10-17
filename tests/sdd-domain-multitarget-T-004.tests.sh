#!/usr/bin/env bash
# Shared acceptance driver; exec propagates Python's exit status to CI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
exec python3 -B "$ROOT/tests/sdd-domain-multitarget-T-004.tests.py"
