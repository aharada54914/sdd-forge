#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
exec python3 "$root/tests/golden-eval.py" grade --case cancelled-result-fencing --output "${1:?output directory required}"
