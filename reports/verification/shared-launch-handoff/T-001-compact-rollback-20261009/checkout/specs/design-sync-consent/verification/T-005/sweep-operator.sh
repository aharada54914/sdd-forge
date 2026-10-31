#!/bin/sh
# T-005 case-sensitivity sweep -- operator layer, .sh side.
# section_between() body copied VERBATIM from
# tests/design-system-contract.tests.sh:179-185 (not modified).
set -u

section_between() {
  awk -v start="$2" -v end="$3" '
    $0 ~ start { flag = 1 }
    flag && $0 ~ end && $0 !~ start { exit }
    flag { print }
  ' "$1" 2>/dev/null
}

echo "=== section_between() (.sh, awk ~ operator) case-sensitivity ==="
echo "--- mis-cased heading '## loop' against pattern '^## Loop$' (must be EMPTY) ---"
OUT=$(section_between fixture-miscased-loop-heading.md '^## Loop$' '^## ')
printf 'result=[%s]\n' "$OUT"
if [ -z "$OUT" ]; then echo "EMPTY (correct: case-sensitive, no match)"; else echo "NON-EMPTY (unexpected)"; fi

echo "--- correctly-cased heading '## Loop' against pattern '^## Loop$' (must be NON-EMPTY) ---"
OUT2=$(section_between fixture-correctcased-loop-heading.md '^## Loop$' '^## ')
printf 'result=[%s]\n' "$OUT2"
if [ -n "$OUT2" ]; then echo "NON-EMPTY (correct: match found)"; else echo "EMPTY (unexpected)"; fi

echo
echo "=== TEST-037 anchor find, plain 'grep -n' (.sh side, case-SENSITIVE, no -i) ==="
echo "--- mis-cased anchor 'Design-Sync-Loop\`' against pattern 'design-sync-loop\`' (must be NOT FOUND) ---"
ANCHOR=$(grep -n 'design-sync-loop`' fixture-miscased-changelog-anchor.md | head -1 | cut -d: -f1)
if [ -z "$ANCHOR" ]; then echo "NOT FOUND (correct: case-sensitive)"; else echo "FOUND at line $ANCHOR (unexpected)"; fi

echo "--- correctly-cased anchor 'design-sync-loop\`' (must be FOUND) ---"
ANCHOR2=$(grep -n 'design-sync-loop`' fixture-correctcased-changelog-anchor.md | head -1 | cut -d: -f1)
if [ -n "$ANCHOR2" ]; then echo "FOUND at line $ANCHOR2 (correct)"; else echo "NOT FOUND (unexpected)"; fi
