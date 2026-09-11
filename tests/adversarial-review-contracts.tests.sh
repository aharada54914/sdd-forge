#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
exec node "$ROOT/tests/adversarial-review-contracts.tests.mjs"
