#!/usr/bin/env bash
set -euo pipefail
if ! command -v node >/dev/null 2>&1; then
  printf '%s\n' 'markdown AST parse failure: Node.js is required' >&2
  exit 2
fi
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/markdown-ast-canonicalizer.mjs" "$@"
