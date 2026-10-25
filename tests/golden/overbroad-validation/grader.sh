#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$HERE/../../golden-eval.py" grade --case "overbroad-validation" --output "$1"
