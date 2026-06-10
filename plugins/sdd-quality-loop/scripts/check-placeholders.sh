#!/bin/sh
# Deterministic gate: detect placeholder, stub, and generic-fallback
# implementations that agents sometimes ship to fake completion.
# Usage: check-placeholders.sh <file-or-dir> [<file-or-dir> ...]
# Pass changed production files (not test fixtures). Exit 1 when found.
if [ $# -eq 0 ]; then
  echo "usage: check-placeholders.sh <file-or-dir> [...]" >&2
  exit 1
fi

pattern='TODO|FIXME|HACK|NotImplemented|not[ _-]implemented|PLACEHOLDER|placeholder|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)'
out="$(grep -rEn --binary-files=without-match \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=bin \
  --exclude-dir=obj --exclude-dir=dist \
  -e "$pattern" "$@" 2>/dev/null)"

if [ -n "$out" ]; then
  count="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  echo "Placeholder scan FAILED ($count finding(s)):"
  printf '%s\n' "$out" | sed 's/^/ - /'
  echo "Each finding must be implemented properly, or explicitly accepted by a human in the quality-gate report."
  exit 1
fi
echo "Placeholder scan passed."
exit 0
