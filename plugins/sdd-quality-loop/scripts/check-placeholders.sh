#!/bin/sh
# Deterministic gate: detect placeholder, stub, and generic-fallback
# implementations that agents sometimes ship to fake completion.
# Usage: check-placeholders.sh <file-or-dir> [<file-or-dir> ...]
# Pass changed production files (not test fixtures). Exit 1 when found.
if [ $# -eq 0 ]; then
  echo "usage: check-placeholders.sh <file-or-dir> [...]" >&2
  exit 1
fi

# Marker keywords are matched CASE-SENSITIVELY: real stub markers follow the
# ALL-CAPS convention (TODO:, FIXME, PLACEHOLDER), while lowercase occurrences
# ("placeholders", "`todo`", "check-placeholders") are ordinary prose in docs
# and skill files -- matching them case-insensitively produced false positives
# that blocked quality gates (RT-20260706-001). NotImplemented keeps its exact
# mixed case (Python/C# exception names). Multi-word phrases stay
# case-insensitive: they are unambiguous in any casing.
pattern_cs='TODO|FIXME|HACK\b|NotImplemented|PLACEHOLDER|TODO_REPLACE_WITH_PROJECT_COMMANDS'
pattern_ci='not[ _-]implemented|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)'
out_cs="$(grep -rEn --binary-files=without-match \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=bin \
  --exclude-dir=obj --exclude-dir=dist \
  -e "$pattern_cs" "$@" 2>/dev/null)"
out_ci="$(grep -rEin --binary-files=without-match \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=bin \
  --exclude-dir=obj --exclude-dir=dist \
  -e "$pattern_ci" "$@" 2>/dev/null)"
out="$(printf '%s\n%s\n' "$out_cs" "$out_ci" | grep -v '^$' | sort -u)"

if [ -n "$out" ]; then
  count="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  echo "Placeholder scan FAILED ($count finding(s)):"
  printf '%s\n' "$out" | sed 's/^/ - /'
  echo "Each finding must be implemented properly, or explicitly accepted by a human in the quality-gate report."
  exit 1
fi
echo "Placeholder scan passed."
exit 0
