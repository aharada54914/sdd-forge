#!/bin/sh
# remedy1-evidence.sh -- T-012 quality-gate seq0370 remedy-1 evidence producer.
#
# Two jobs, both re-runnable from a clean checkout:
#
#   A. FIDELITY DIFFS (closes Major 2). Emits a self-describing
#      `diff -u <live> <staged>` for each of the two protected consumers, so
#      the claim "the staged candidate is byte-identical to the live file
#      OUTSIDE the migrated region" stops being prose and becomes a persisted,
#      re-readable artifact. Read-only with respect to every protected path.
#
#   B. MUTATION PROOFS (detection power for the three assertions this remedy
#      added or repaired). Every proof runs the REAL suite -- never a
#      re-implementation of its assertions in another language -- against a
#      THROWAWAY FULL COPY of the worktree, and every proof runs its PRISTINE
#      BASELINE first. Without the baseline a mutant's failure could be caused
#      by the copy itself rather than by the mutation, and would prove nothing.
#      The repository is never mutated.
#
# Usage:  sh remedy1-evidence.sh <scratch-dir>
#         (the scratch dir must NOT be inside the repository)
#
# Exit 0 iff every baseline passed AND every mutant was detected.
set -u

SCRATCH=${1:?usage: remedy1-evidence.sh <scratch-dir>}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH= cd -- "$HERE/../../../.." && pwd)

case "$SCRATCH" in
  "$REPO"|"$REPO"/*)
    printf 'refusing to use a scratch dir inside the repository: %s\n' "$SCRATCH" >&2
    exit 2 ;;
esac

LIVE_SHIP=plugins/sdd-ship/skills/ship/SKILL.md
LIVE_LITE=plugins/sdd-lite/skills/lite-spec/SKILL.md
STAGE=specs/epic-189-a1-project-context/human-copy
OUT="$HERE"

COMMIT=$(cd "$REPO" && git rev-parse HEAD 2>/dev/null || echo UNKNOWN)
STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

RC=0
note() { printf '%s\n' "$*"; }
verdict() {
  # verdict <ok|no> <label>
  if [ "$1" = ok ]; then
    printf 'PROOF-OK   %s\n' "$2"
  else
    printf 'PROOF-FAIL %s\n' "$2"
    RC=1
  fi
}

# ===========================================================================
# A. Fidelity diffs.
# ===========================================================================
emit_diff() {
  # emit_diff <live-relpath> <out-basename>
  live_rel=$1
  out="$OUT/$2"
  staged_rel="$STAGE/$live_rel"
  {
    printf '# T-012 fidelity diff -- live protected file vs staged human-copy candidate\n'
    printf '#\n'
    printf '# Produced by: specs/epic-189-a1-project-context/verification/T-012/remedy1-evidence.sh\n'
    printf '# Generated at (UTC): %s\n' "$STAMP"
    printf '# Repository HEAD at generation time: %s\n' "$COMMIT"
    printf '#\n'
    printf '# LEFT  (a/) = the LIVE, R-10-protected file, unmodified by this task:\n'
    printf '#              %s\n' "$live_rel"
    printf '#              sha256 %s\n' "$(cd "$REPO" && shasum -a 256 "$live_rel" | awk '{print $1}')"
    printf '# RIGHT (b/) = the STAGED human-copy candidate this task authored:\n'
    printf '#              %s\n' "$staged_rel"
    printf '#              sha256 %s\n' "$(cd "$REPO" && shasum -a 256 "$staged_rel" | awk '{print $1}')"
    printf '#\n'
    printf '# What this artifact is FOR: the staged candidate overwrites the live file\n'
    printf '# WHOLESALE when a human runs apply-human-copy. The safety-critical property\n'
    printf '# is therefore that every byte OUTSIDE the intended migration is unchanged.\n'
    printf '# The hunks below are the complete, exhaustive set of differences: anything\n'
    printf '# not shown here is byte-identical between the two files. A reviewer checks\n'
    printf '# fidelity by confirming every hunk below is an intended part of the\n'
    printf '# ADR-0023 track-selection migration plus the REQ-010 handshake wiring, and\n'
    printf '# that no hunk touches anything else.\n'
    printf '#\n'
    printf '# Command: diff -u %s %s\n' "$live_rel" "$staged_rel"
    printf '# NOTE: an EMPTY hunk list below would mean the candidate has already been\n'
    printf '# published (live == staged), not that the migration is missing.\n'
    printf '# ---------------------------------------------------------------------------\n'
    ( cd "$REPO" && diff -u "$live_rel" "$staged_rel" ) || :
  } > "$out"
  note "wrote $2 ($(wc -l < "$out" | tr -d ' ') lines)"
}

note '=== A. fidelity diffs ==='
emit_diff "$LIVE_SHIP" ship-SKILL.live-vs-staged.diff
emit_diff "$LIVE_LITE" lite-spec-SKILL.live-vs-staged.diff

# ===========================================================================
# B. Mutation proofs against a throwaway full copy.
# ===========================================================================
note ''
note '=== B. mutation proofs (throwaway copy; repository never mutated) ==='
MUT="$SCRATCH/mutroot"
rm -rf "$MUT"
mkdir -p "$SCRATCH"
cp -R "$REPO" "$MUT"
rm -f "$MUT/.git"          # never let the copy resolve to the real gitdir
note "throwaway copy at $MUT"

run_suite() {
  # run_suite <suite-relpath> <logfile> -> prints "<pass>/<fail>"
  ( cd "$MUT" && bash "$1" ) > "$2" 2>&1 || :
  p=$(awk '/^PASS: [0-9]+$/{print $2}' "$2" | tail -1)
  f=$(awk '/^FAIL: [0-9]+$/{print $2}' "$2" | tail -1)
  printf '%s/%s' "${p:-?}" "${f:-?}"
}

fails_matching() {
  # fails_matching <logfile> <fixed-string> -> count of FAIL lines containing it
  grep '^FAIL' "$1" 2>/dev/null | grep -cF "$2" || echo 0
}

# --- M1: guard-invariants pins T-012's own two manifest entries -------------
# Verdict seq0370 Minor: dropping BOTH T-012 entries previously yielded
# "entries=8 floor=True dupes=0 wf=1 missing_byname=none -> ALL-PASS".
GI=tests/guard-invariants-epic-a1.tests.sh
BASE=$(run_suite "$GI" "$SCRATCH/m1-baseline.log")
note "M1 baseline (pristine copy): $BASE"
case "$BASE" in
  */0) verdict ok "M1 baseline passes on the pristine copy ($BASE)" ;;
  *)   verdict no "M1 baseline passes on the pristine copy ($BASE)" ;;
esac

cp "$MUT/$STAGE/MANIFEST.sha256" "$SCRATCH/manifest.orig"
grep -v -E '  plugins/sdd-(ship/skills/ship|lite/skills/lite-spec)/SKILL\.md$' \
  "$SCRATCH/manifest.orig" > "$MUT/$STAGE/MANIFEST.sha256"
note "M1 mutant: manifest now has $(grep -cE '^[0-9a-f]{64}  ' "$MUT/$STAGE/MANIFEST.sha256") entries (was $(grep -cE '^[0-9a-f]{64}  ' "$SCRATCH/manifest.orig"))"
MUT1=$(run_suite "$GI" "$SCRATCH/m1-mutant.log")
note "M1 mutant result: $MUT1"
n_ship=$(fails_matching "$SCRATCH/m1-mutant.log" 'registers plugins/sdd-ship/skills/ship/SKILL.md')
n_lite=$(fails_matching "$SCRATCH/m1-mutant.log" 'registers plugins/sdd-lite/skills/lite-spec/SKILL.md')
if [ "$n_ship" -ge 1 ] && [ "$n_lite" -ge 1 ]; then
  verdict ok "M1 dropping BOTH T-012 manifest entries is DETECTED by name (ship=$n_ship lite-spec=$n_lite FAIL lines)"
else
  verdict no "M1 dropping BOTH T-012 manifest entries is DETECTED by name (ship=$n_ship lite-spec=$n_lite FAIL lines)"
fi
cp "$SCRATCH/manifest.orig" "$MUT/$STAGE/MANIFEST.sha256"

# --- M2: TEST-PUB pair consistency catches a half-applied pair --------------
# This is the assertion that replaces the cross-pair atomicity forfeited by
# splitting the publish into two single-target batches.
T12=tests/ship-track-selection-migration.tests.sh
BASE2=$(run_suite "$T12" "$SCRATCH/m2-baseline.log")
note "M2 baseline (pristine copy): $BASE2"
case "$BASE2" in
  */0) verdict ok "M2 baseline passes on the pristine copy ($BASE2)" ;;
  *)   verdict no "M2 baseline passes on the pristine copy ($BASE2)" ;;
esac

# Simulate exactly the state the runbook can leave between batch 1 and batch 2:
# ship published, lite-spec not. Inside the THROWAWAY copy only.
cp "$MUT/$LIVE_SHIP" "$SCRATCH/live-ship.orig"
cp "$MUT/$STAGE/$LIVE_SHIP" "$MUT/$LIVE_SHIP"
MUT2=$(run_suite "$T12" "$SCRATCH/m2-mutant.log")
note "M2 mutant result: $MUT2"
n_pair=$(fails_matching "$SCRATCH/m2-mutant.log" 'TEST-PUB pair consistency')
if [ "$n_pair" -ge 1 ]; then
  verdict ok "M2 a half-applied pair (ship published, lite-spec not) is DETECTED by the pair-consistency assertion ($n_pair FAIL line)"
else
  verdict no "M2 a half-applied pair (ship published, lite-spec not) is DETECTED by the pair-consistency assertion ($n_pair FAIL lines)"
fi
# Cross-check the verdict's own finding: WITHOUT the pair assertion the
# half-applied state is invisible. Every OTHER assertion must still be green.
other=$(( $(grep -c '^FAIL' "$SCRATCH/m2-mutant.log" || echo 0) - 1 - n_pair ))
if [ "$other" -le 0 ]; then
  verdict ok "M2 the half-applied pair trips ONLY the pair assertion (every other assertion stays green -- confirming nothing else covers it)"
else
  verdict no "M2 the half-applied pair trips ONLY the pair assertion (got $other other FAIL lines)"
fi
cp "$SCRATCH/live-ship.orig" "$MUT/$LIVE_SHIP"

# --- M3: the repaired TEST-CGS g3/g4 assertion is non-vacuous ---------------
# Verdict seq0370 Minor: `assert_eq "$g3" "$g4"` passed vacuously when both
# sides were empty. Deleting the capability-gate block empties both.
python3 - "$MUT/$STAGE/$LIVE_SHIP" <<'PYEOF'
import re
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t2 = re.sub(r"<!-- sdd:capability-gate-scope v1 -->.*?<!-- /sdd:capability-gate-scope -->",
            "", t, flags=re.S)
assert t2 != t, "gate block not found -- mutation would have been a no-op"
open(p, "w", encoding="utf-8").write(t2)
PYEOF
MUT3=$(run_suite "$T12" "$SCRATCH/m3-mutant.log")
note "M3 mutant result: $MUT3"
n_g3g4=$(fails_matching "$SCRATCH/m3-mutant.log" 'does NOT change an absent-Context')
if [ "$n_g3g4" -ge 1 ]; then
  verdict ok "M3 deleting the capability-gate block is DETECTED by the g3/g4 assertion itself ($n_g3g4 FAIL line) -- it no longer passes vacuously on two empty sides"
else
  verdict no "M3 deleting the capability-gate block is DETECTED by the g3/g4 assertion itself ($n_g3g4 FAIL lines)"
fi

note ''
if [ "$RC" = 0 ]; then note 'ALL PROOFS OK'; else note 'SOME PROOFS FAILED'; fi
exit "$RC"
