#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="${SCRIPT_DIR}/../plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.sh"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --checker) CHECKER="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

python3 "${SCRIPT_DIR}/fixtures/installed-plugin-drift/fixture_driver.py" \
    --runtime sh --checker "$CHECKER"
