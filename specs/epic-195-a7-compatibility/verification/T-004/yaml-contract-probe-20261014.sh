#!/usr/bin/env bash
# Diagnostic only: no corpus writes, status changes, or acceptance verdict.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/a7-yaml-contract.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
printf '%s\n' '---' 'title: [unterminated' '---' '# Heading' > "$scratch/flow.md"
printf '%s\n' '---' 'title: "unterminated' '---' '# Heading' > "$scratch/quote.md"
printf '%s\n' '---' 'title: alpha: beta' '---' '# Heading' > "$scratch/colon.md"
printf '%s\n' '---' 'title: alpha' '---' '# Heading' > "$scratch/plain.md"
printf '%s\n' '---' "title: 'alpha'" '---' '# Heading' > "$scratch/quoted.md"
failures=0
for runtime in bash powershell; do
  for name in flow quote colon plain quoted; do
    code=0
    if [[ "$runtime" == bash ]]; then
      bash "$ROOT/tests/lib/markdown-ast-canonicalizer.sh" "$scratch/$name.md" > "$scratch/$runtime-$name.json" 2> "$scratch/$runtime-$name.err" || code=$?
    else
      pwsh -NoProfile -File "$ROOT/tests/lib/markdown-ast-canonicalizer.ps1" -Path "$scratch/$name.md" > "$scratch/$runtime-$name.json" 2> "$scratch/$runtime-$name.err" || code=$?
    fi
    printf '%s %s exit=%s\n' "$runtime" "$name" "$code"
    if [[ "$name" == flow || "$name" == quote || "$name" == colon ]]; then
      if [[ "$code" == 0 ]]; then failures=$((failures + 1)); fi
    elif [[ "$code" != 0 ]]; then
      failures=$((failures + 1))
    fi
  done
  if cmp -s "$scratch/$runtime-plain.json" "$scratch/$runtime-quoted.json"; then
    printf '%s equivalent-scalar same\n' "$runtime"
  else
    printf '%s equivalent-scalar DIFFERENT\n' "$runtime"
    failures=$((failures + 1))
  fi
done
printf 'contract violations=%s (diagnostic, not a gate verdict)\n' "$failures"
[[ "$failures" == 0 ]]
