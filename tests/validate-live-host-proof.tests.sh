#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
VALIDATOR="${LIVE_HOST_VALIDATOR:-$ROOT/plugins/sdd-quality-loop/scripts/validate-live-host-proof.sh}"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'SKIP: python3 not found; live-host proof tests not run\n'
  exit 0
fi

# TEST-013–016 are additive acceptance cases in the shared Python driver.
# The invocation below is T-005's original TEST-026/027/028 path unchanged.
LIVE_HOST_VALIDATOR="$VALIDATOR" python3 "$ROOT/tests/fixtures/live-host-proof/run_cases.py"
