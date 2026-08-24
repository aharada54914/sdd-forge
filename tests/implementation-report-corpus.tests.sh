#!/usr/bin/env bash
# implementation-report-corpus.tests.sh -- the contract/corpus ratchet
# (WFI-017 recurrence countermeasure, 2026-08-21).
#
# Root cause this exists to close: the report contract (template, validator,
# evaluator boundary) is updated prospectively, and nothing measured its effect
# on the COMMITTED corpus. Reports valid when written were silently stranded by
# later contract changes, discovered one at a time months later when a gate
# needed them (WFI-017 first occurrence; recurrence recorded 2026-08-21, when
# 124 of 208 committed reports hard-failed the then-current validator). Same
# one-surface-updated shape as WFI-036/037/038.
#
# The ratchet: the baseline freezes the hard-failing set as of introduction.
#   (a) a report NOT in the baseline that hard-fails  -> RED. Either a new
#       report was committed non-conforming, or a contract change stranded a
#       previously-passing report. Both must be dealt with NOW, not at gate
#       time months later.
#   (b) a baseline entry that now passes              -> RED (stale entry).
#       Remove the line; the baseline only shrinks.
#   (c) a baseline entry that is gone from the tree   -> RED (stale entry).
# Adding a line to the baseline to silence (a) defeats the ratchet.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/plugins/sdd-implementation/scripts/validate-implementation-report.sh"
BASELINE="$ROOT/tests/fixtures/implementation-report-corpus-baseline.txt"
[[ -f "$VALIDATOR" ]] || { echo "FAIL: validator missing"; exit 1; }
[[ -f "$BASELINE" ]] || { echo "FAIL: baseline missing"; exit 1; }
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); }
bad(){ echo "FAIL: $1"; FAIL=$((FAIL+1)); }

declare -A baseline=()
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  baseline["$line"]=1
done < "$BASELINE"

checked=0
while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  checked=$((checked+1))
  out="$("$VALIDATOR" "$f" 2>&1 || true)"
  if [[ "$out" == *REPORT_OK* || "$out" == *LEGACY_OK* ]]; then
    if [[ -n "${baseline[$rel]:-}" ]]; then
      bad "stale baseline entry (now passes -- delete its line): $rel"
    else
      ok
    fi
  else
    if [[ -n "${baseline[$rel]:-}" ]]; then
      ok  # known-legacy, frozen at introduction
    else
      bad "report outside the baseline hard-fails the contract: $rel -> ${out%%$'\n'*}"
    fi
  fi
done < <(find "$ROOT/reports/implementation" -name 'T-[0-9][0-9][0-9].md' -not -name '*review*' -not -name '*attempt*' | sort)

for rel in "${!baseline[@]}"; do
  [[ -f "$ROOT/$rel" ]] || bad "stale baseline entry (file gone -- delete its line): $rel"
done

[[ "$checked" -gt 0 ]] || bad "corpus scan found zero reports -- the ratchet is measuring nothing"
echo "implementation-report-corpus: $checked reports checked, $PASS ok, $FAIL failing"
[[ "$FAIL" -eq 0 ]]
