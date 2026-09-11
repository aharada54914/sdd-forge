#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
VALIDATOR="${LIVE_HOST_VALIDATOR:-$ROOT/plugins/sdd-quality-loop/scripts/validate-live-host-proof.sh}"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'SKIP: python3 not found; live-host proof tests not run\n'
  exit 0
fi

LIVE_HOST_VALIDATOR="$VALIDATOR" python3 "$ROOT/tests/fixtures/live-host-proof/run_cases.py"
