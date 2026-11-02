#!/usr/bin/env bash
# Documentation links, Mermaid diagrams and pinned anchors (see doc-diagrams.tests.py).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "${ROOT}/tests/doc-diagrams.tests.py" "$@"
