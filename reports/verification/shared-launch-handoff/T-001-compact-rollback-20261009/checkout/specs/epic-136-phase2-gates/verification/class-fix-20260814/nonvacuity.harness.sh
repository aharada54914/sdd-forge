#!/usr/bin/env bash
# Non-vacuity harness for the 2026-08-14 class lock.
#
# For every path the class lock declares evicted, re-add it in a SCRATCH copy
# two ways -- as a staged file, and as a MANIFEST.sha256 entry -- and require
# the amended suite to go RED each time; restore and require GREEN. An absence
# lock that cannot fail is worse than the bug it replaces.
#
# Usage: nonvacuity.sh <scratch-root>   (scratch-root must already be a copy)
set -uo pipefail
SCRATCH="$1"
STAGE="$SCRATCH/specs/epic-136-phase2-gates/human-copy"
MANIFEST="$STAGE/MANIFEST.sha256"
LANE_SH="$SCRATCH/tests/phase2-guard-invariants.tests.sh"
LANE_PS1="$SCRATCH/tests/phase2-guard-invariants.tests.ps1"

EVICTED=(
  '.github/workflows/test.yml'
  'plugins/sdd-quality-loop/references/guard-invariants.json'
  'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'
  'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py'
  'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js'
  'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1'
  'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh'
)

MANIFEST_BACKUP="$(mktemp)"
cp "$MANIFEST" "$MANIFEST_BACKUP"
trap 'cp "$MANIFEST_BACKUP" "$MANIFEST"; rm -f "$MANIFEST_BACKUP"' EXIT

LANE="${2:-both}"
RUN_OUT="$(mktemp)"

run_suite() {  # $1 = lane; captures ONE suite run for all seven lock readings
  if [ "$1" = sh ]; then
    bash "$LANE_SH" >"$RUN_OUT" 2>&1
  else
    pwsh -NoProfile -File "$LANE_PS1" >"$RUN_OUT" 2>&1
  fi
}

lock_state() {  # $1 = evicted path -> ok | FAIL | absent (reads the captured run)
  if grep -Fq "FAIL: TEST-013 class lock: repo-shared $1 " "$RUN_OUT"; then printf 'FAIL'
  elif grep -Fq "ok: TEST-013 class lock: repo-shared $1 " "$RUN_OUT"; then printf 'ok'
  else printf 'absent'; fi
}

fails=0
# Assert the FULL seven-lock vector after one run: the mutated path must be
# FAIL and every other lock must still be ok. That rules out both a lock that
# cannot fire and a lock that fires for the wrong path.
assert_vector() {  # $1 = lane, $2 = label, $3 = path expected FAIL ('' = none)
  run_suite "$1"
  local bad=""
  for p in "${EVICTED[@]}"; do
    local want=ok
    [ "$p" = "$3" ] && want=FAIL
    local got; got="$(lock_state "$p")"
    [ "$got" = "$want" ] || bad="$bad [$p want=$want got=$got]"
  done
  if [ -z "$bad" ]; then
    printf '  PASS  %-46s vector: 7/7 as required\n' "$2"
  else
    printf '  ****  %-46s VIOLATION:%s\n' "$2" "$bad"
    fails=$((fails + 1))
  fi
}

for lane in sh ps1; do
  [ "$LANE" = both ] || [ "$LANE" = "$lane" ] || continue
  echo "=================== lane: $lane ==================="
  assert_vector "$lane" "baseline (all evicted)" ""
  for path in "${EVICTED[@]}"; do
    mkdir -p "$(dirname "$STAGE/$path")"
    printf 'readded snapshot\n' >"$STAGE/$path"
    assert_vector "$lane" "re-added STAGED FILE: $path" "$path"
    rm -f "$STAGE/$path"

    printf '%s  %s\n' "$(printf 'readded' | shasum -a 256 | awk '{print $1}')" "$path" >>"$MANIFEST"
    assert_vector "$lane" "re-added MANIFEST ENTRY: $path" "$path"
    cp "$MANIFEST_BACKUP" "$MANIFEST"
  done
  assert_vector "$lane" "restored (all evicted again)" ""
done

rm -f "$RUN_OUT"
echo
if [ "$fails" -eq 0 ]; then
  echo "NON-VACUITY: every mutation flipped exactly its own lock to FAIL; restore returned all seven to ok. lane=$LANE"
  exit 0
fi
echo "NON-VACUITY: $fails violation(s). lane=$LANE"
exit 1
