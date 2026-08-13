#!/usr/bin/env bash
# Apply rehearsal with the REAL publisher, post-class-fix.
#
# Pass condition: NO apply path may remove any live protected path, registry
# key, or CI step. The cycle-5 rehearsal declared "ZERO REMOVALS" after
# measuring only two JSON arrays and was a false all-clear, so this harness
# measures EVERY live path any manifest names, the live workflow's step-name
# set, and every array in the live canonical -- before and after each leg.
#
# Usage: rehearsal.sh <scratch-root>
set -uo pipefail
R="$1"
PUB="$R/plugins/sdd-quality-loop/scripts/apply-human-copy.sh"
B136="$R/specs/epic-136-phase2-gates/human-copy"
B189="$R/specs/epic-189-a1-project-context/human-copy"
WORK="$(mktemp -d)"
CANON='plugins/sdd-quality-loop/references/guard-invariants.json'
CI='.github/workflows/test.yml'
TAB="$(printf '\t')"

watch_paths() {
  { sed -e 's/^[0-9a-f]\{64\}  //' "$B136/MANIFEST.sha256" 2>/dev/null
    sed -e 's/^[0-9a-f]\{64\}  //' "$B189/MANIFEST.sha256" 2>/dev/null
    printf '%s\n%s\n' "$CANON" "$CI"
  } | sort -u
}

snapshot() {  # $1 = output prefix
  local p                      # must be local: the caller's loop variable is
  : >"$1"                      # also named p and was being clobbered
  while IFS= read -r p; do
    if [ -f "$R/$p" ]; then
      printf '%s\t%s\t%s\n' "$p" "$(shasum -a 256 "$R/$p" | awk '{print $1}')" "$(wc -l <"$R/$p" | tr -d ' ')" >>"$1"
    else
      printf '%s\tABSENT\t0\n' "$p" >>"$1"
    fi
  done < <(watch_paths)
  grep -oE '^[[:space:]]*- name: .*$' "$R/$CI" 2>/dev/null | sed 's/^ *//' | sort >"$1.steps"
  python3 - "$R/$CANON" >"$1.arrays" 2>/dev/null <<'PY' || : >"$1.arrays"
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
for k, v in sorted(d.items()):
    if isinstance(v, list):
        for e in v:
            print(f"{k}\t{e}")
PY
}

removals=0
compare() {  # $1 before prefix, $2 after prefix, $3 label
  local changed=0 steps_lost keys_lost
  while IFS="$TAB" read -r p h l; do
    a="$(awk -F'\t' -v k="$p" '$1==k {print $2}' "$2")"
    al="$(awk -F'\t' -v k="$p" '$1==k {print $3}' "$2")"
    if [ "$h" != "ABSENT" ] && [ "$a" = "ABSENT" ]; then
      printf '    **** REMOVED live file: %s\n' "$p"; removals=$((removals + 1))
    elif [ "$h" != "$a" ]; then
      printf '    changed: %s  lines %s -> %s\n' "$p" "$l" "$al"
      changed=$((changed + 1))
      if [ "${al:-0}" -lt "${l:-0}" ]; then
        printf '      **** LINE LOSS on %s (%s -> %s)\n' "$p" "$l" "$al"; removals=$((removals + 1))
      fi
    fi
  done <"$1"
  steps_lost="$(comm -23 "$1.steps" "$2.steps" | wc -l | tr -d ' ')"
  keys_lost="$(comm -23 "$1.arrays" "$2.arrays" | wc -l | tr -d ' ')"
  printf '  [%s] changed=%s  CI-steps-lost=%s  registry-keys-lost=%s\n' "$3" "$changed" "$steps_lost" "$keys_lost"
  if [ "$steps_lost" -ne 0 ]; then comm -23 "$1.steps" "$2.steps" | sed 's/^/      **** LOST STEP: /'; removals=$((removals + steps_lost)); fi
  if [ "$keys_lost" -ne 0 ]; then comm -23 "$1.arrays" "$2.arrays" | sed 's/^/      **** LOST KEY: /'; removals=$((removals + keys_lost)); fi
}

leg() {  # $1 label, $2 staging dir, $3 manifest
  snapshot "$WORK/before"
  # The publisher has no --repo-root: it publishes relative to the CWD, so the
  # rehearsal runs it from inside the scratch root (never the real repo).
  ( cd "$R" && sh "$PUB" --staging-dir "$2" --manifest "$3" ) >"$WORK/out" 2>&1
  local rc=$?
  printf '== %s\n  exit=%s | %s\n' "$1" "$rc" "$(tail -n 1 "$WORK/out" | cut -c1-100)"
  snapshot "$WORK/after"
  compare "$WORK/before" "$WORK/after" "$1"
}

echo "############ LEG 1: whole-batch, both bundles ############"
leg "whole-batch epic-136-phase2" "$B136" "$B136/MANIFEST.sha256"
leg "whole-batch epic-189-a1" "$B189" "$B189/MANIFEST.sha256"

echo
echo "############ LEG 2: single-target, EVERY manifest entry ############"
for bundle in "$B136" "$B189"; do
  name="$(basename "$(dirname "$bundle")")"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "$line" >"$WORK/one.sha256"
    leg "single $name :: $(printf '%s' "$line" | sed 's/^[0-9a-f]\{64\}  //')" "$bundle" "$WORK/one.sha256"
  done <"$bundle/MANIFEST.sha256"
done

echo
echo "############ LEG 3: adversarial replay of every EVICTED line ############"
echo "# The 2026-08-11 hazard shape: hand-craft the deleted manifest line and"
echo "# apply it as a single-target batch. Must be REFUSED (candidate absent)."
for p in "$CI" "$CANON" \
  plugins/sdd-quality-loop/scripts/generate-guard-invariants.py \
  plugins/sdd-quality-loop/scripts/generated/guard_invariants.py \
  plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js \
  plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1 \
  plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh; do
  printf '%s  %s\n' "$(shasum -a 256 "$R/$p" 2>/dev/null | awk '{print $1}')" "$p" >"$WORK/replay.sha256"
  leg "REPLAY 136 :: $p" "$B136" "$WORK/replay.sha256"
  leg "REPLAY 189 :: $p" "$B189" "$WORK/replay.sha256"
done

echo
echo "############ LEG 4: bundle-specific runner ############"
snapshot "$WORK/before"
pwsh -NoProfile -File "$B136/apply-protected-files.ps1" -RepositoryRoot "$R" >"$WORK/runner.out" 2>&1
printf '== runner apply-protected-files.ps1\n  exit=%s | %s\n' "$?" "$(tail -n 1 "$WORK/runner.out" | cut -c1-100)"
snapshot "$WORK/after"
compare "$WORK/before" "$WORK/after" "runner"

echo
echo "############ VERDICT ############"
printf 'watched live paths: %s (plus the CI step-name set and every canonical array)\n' "$(watch_paths | wc -l | tr -d ' ')"
if [ "$removals" -eq 0 ]; then
  echo "ZERO REMOVALS across every leg: no live file deleted, no live line lost,"
  echo "no CI step lost, no registry key lost."
  exit 0
fi
echo "REMOVALS PRESENT: $removals"
exit 1
