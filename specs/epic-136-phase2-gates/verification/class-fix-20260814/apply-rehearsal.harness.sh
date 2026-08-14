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

publisher_failures=0
leg() {  # $1 label, $2 staging dir, $3 manifest, $4 EXPECTED exit code
  snapshot "$WORK/before"
  # The publisher has no --repo-root: it publishes relative to the CWD, so the
  # rehearsal runs it from inside the scratch root (never the real repo).
  ( cd "$R" && sh "$PUB" --staging-dir "$2" --manifest "$3" ) >"$WORK/out" 2>&1
  local rc=$?
  printf '== %s\n  exit=%s (expected %s) | %s\n' "$1" "$rc" "$4" "$(tail -n 1 "$WORK/out" | cut -c1-90)"
  # An unvalidated exit code was the loophole: a missing or universally
  # refusing publisher leaves every snapshot untouched, and "no removals" then
  # reads as proof when nothing was ever applied. Each leg now declares the
  # outcome it expects -- success, or the specific refusal -- and a mismatch
  # fails the whole rehearsal. Snapshots are still compared either way, so a
  # failed leg that DID move bytes is still reported.
  if [ "$rc" -ne "$4" ]; then
    printf '    **** PUBLISHER LEG FAILED: expected exit %s, got %s\n' "$4" "$rc"
    publisher_failures=$((publisher_failures + 1))
  fi
  snapshot "$WORK/after"
  compare "$WORK/before" "$WORK/after" "$1"
}

echo "############ LEG 1: whole-batch, both bundles ############"
# Both manifests carry two SKILL.md targets, so the publisher refuses the whole
# batch fail-closed with DUPLICATE_BASENAME_IN_BATCH (19). That refusal is the
# EXPECTED outcome here, not an accident to be tolerated.
leg "whole-batch epic-136-phase2" "$B136" "$B136/MANIFEST.sha256" 19
leg "whole-batch epic-189-a1" "$B189" "$B189/MANIFEST.sha256" 19

echo
echo "############ LEG 2: single-target, EVERY manifest entry ############"
for bundle in "$B136" "$B189"; do
  name="$(basename "$(dirname "$bundle")")"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "$line" >"$WORK/one.sha256"
    # Every entry a manifest still lists must apply cleanly: exit 0.
    leg "single $name :: $(printf '%s' "$line" | sed 's/^[0-9a-f]\{64\}  //')" "$bundle" "$WORK/one.sha256" 0
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
  # Expectation is DERIVED from each bundle's tree, not hardcoded: where the
  # snapshot is evicted the publisher must refuse (10, staged candidate
  # absent); where it is still staged the replay is a legitimate no-op apply
  # (0). That asymmetry is precisely what this PR closes on 136 and leaves
  # open on 189, so the harness must assert it rather than accept either.
  [ -f "$B136/$p" ] && e136=0 || e136=10
  [ -f "$B189/$p" ] && e189=0 || e189=10
  leg "REPLAY 136 :: $p" "$B136" "$WORK/replay.sha256" "$e136"
  leg "REPLAY 189 :: $p" "$B189" "$WORK/replay.sha256" "$e189"
done

echo
echo "############ LEG 4: bundle-specific runner ############"
snapshot "$WORK/before"
pwsh -NoProfile -File "$B136/apply-protected-files.ps1" -RepositoryRoot "$R" >"$WORK/runner.out" 2>&1
runner_rc=$?
printf '== runner apply-protected-files.ps1\n  exit=%s | %s\n' "$runner_rc" "$(tail -n 1 "$WORK/runner.out" | cut -c1-100)"
snapshot "$WORK/after"
# A runner that refuses to start does no work, so its "no removals" reading is
# vacuous -- exactly the false-all-clear shape the cycle-5 rehearsal produced.
# Classify STRICTLY by exit code AND diagnostic, so that only the two
# recognised preflight refusals become SKIPPED and only a clean exit 0 is
# measured. Anything else -- a missing pwsh (127), a crash, a partial apply --
# is FAILED and fails the verdict. Without this, an unrecognised runner error
# fell through to compare on an untouched tree and printed ZERO REMOVALS.
runner_leg='FAILED'
if [ "$runner_rc" -eq 2 ] && grep -q 'apply-protected-files: Windows is required' "$WORK/runner.out"; then
  echo "  [runner] SKIPPED: host is not Windows; the runner refused before copying anything, so this leg proves nothing"
  runner_leg='SKIPPED (non-Windows host)'
elif [ "$runner_rc" -eq 2 ] && grep -qE 'unable to locate (this bundle staging directory|the staged canonical file) from the runner path' "$WORK/runner.out"; then
  echo "  [runner] SKIPPED: installed runner predates the refresh candidate and refused at startup; this leg proves nothing"
  runner_leg='SKIPPED (pre-refresh runner)'
elif [ "$runner_rc" -eq 0 ]; then
  runner_leg='measured'
  compare "$WORK/before" "$WORK/after" "runner"
else
  echo "  [runner] FAILED: exit $runner_rc with no recognised preflight refusal; this leg is neither a skip nor a proven apply"
  compare "$WORK/before" "$WORK/after" "runner (failed leg, state recorded)"
fi

echo
echo "############ VERDICT ############"
printf 'watched live paths: %s (plus the CI step-name set and every canonical array)\n' "$(watch_paths | wc -l | tr -d ' ')"
printf 'leg 4 (bundle runner): %s\n' "$runner_leg"
printf 'publisher legs with an unexpected exit code: %s\n' "$publisher_failures"
if [ "$publisher_failures" -ne 0 ]; then
  echo "PUBLISHER LEGS FAILED: $publisher_failures leg(s) did not produce the"
  echo "outcome they declared, so no zero-removal claim can be made from this"
  echo "run. Removals counted anyway: $removals."
  exit 1
fi
if [ "$runner_leg" = 'FAILED' ]; then
  echo "RUNNER LEG FAILED: the runner exited nonzero without a recognised"
  echo "preflight refusal, so no verdict can be issued for it. Removals counted"
  echo "on the other legs: $removals."
  exit 1
fi
if [ "$removals" -eq 0 ]; then
  echo "ZERO REMOVALS across every MEASURED leg: no live file deleted, no live"
  echo "line lost, no CI step lost, no registry key lost."
  [ "$runner_leg" = measured ] || echo "NOTE: the runner leg was skipped and contributes NOTHING to this verdict."
  exit 0
fi
echo "REMOVALS PRESENT: $removals"
exit 1
