#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
exec python3 "$ROOT/specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration-cli.tests.py"
