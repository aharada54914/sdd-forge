#!/bin/sh
# T-004 (epic-193-a5-capability-resolver) confirmation-panel remediation
# (third recurrence of this exact staleness class -- see this task's own
# implementation report, "Traceability-log staleness, third recurrence").
#
# Makes a stale traceability.log LOUD (a failing check) instead of
# discovered only by a later confirmation panel: scans every
# specs/epic-193-a5-capability-resolver/verification/qg/T-0*/traceability.log
# for a machine-readable `TRACEABILITY-LOG-LIVE-TOTAL:` trailer line
# (`driver=<path> result="RESULT: N passed, M failed"`), re-runs the cited
# driver for real, and asserts its own current last-line RESULT matches the
# trailer byte-for-byte.
#
# Scope note (why a trailer convention, not a free-prose parser): a first
# attempt at parsing the LAST "N passed / M failed" occurrence directly out
# of each log's own free-form prose failed on three genuinely distinct,
# demonstrated failure modes -- T-002's own citation line-wraps across two
# lines ("102\n  passed, 0 failed overall"), T-004's own uses " / " with
# spaces around the separator where T-002/T-005 use ", "/"/" without, and
# T-005's own prose legitimately cites a LATER, smaller mutant-kill count
# (a deliberately-failing capture) after its own genuine baseline count,
# so "the last number mentioned" is not reliably "the current true state"
# at all. Rather than ship a fragile, false-positive-prone regex over free
# prose, this check instead requires an explicit, single-line, unambiguous
# machine-readable trailer -- a log without one is SKIPPED, never failed,
# so this convention is opt-in per log, not retroactively imposed on every
# historical capture (T-001/T-002's own logs, which describe a fixed
# historical snapshot rather than "the driver's current live state", never
# carry one).
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

QG_DIR="specs/epic-193-a5-capability-resolver/verification/qg"

found_any=0
for log in "$QG_DIR"/T-0*/traceability.log; do
  [ -f "$log" ] || continue
  line=$(grep -m1 '^TRACEABILITY-LOG-LIVE-TOTAL:' "$log" 2>/dev/null || true)
  [ -n "$line" ] || continue
  found_any=1
  driver=$(printf '%s\n' "$line" | sed -n 's/.*driver=\([^ ]*\) .*/\1/p')
  expected=$(printf '%s\n' "$line" | sed -n 's/.*result="\(.*\)"$/\1/p')
  if [ -z "$driver" ] || [ -z "$expected" ]; then
    bad "$log: TRACEABILITY-LOG-LIVE-TOTAL trailer malformed: $line"
    continue
  fi
  if [ ! -f "$driver" ]; then
    bad "$log: cited driver does not exist: $driver"
    continue
  fi
  actual=$(bash "$driver" 2>/dev/null | tail -1)
  if [ "$actual" = "$expected" ]; then
    ok "$log: cited RESULT ('$expected') matches a live re-run of $driver"
  else
    bad "$log: cited RESULT ('$expected') does NOT match a live re-run of $driver (got: '$actual') -- this traceability.log is STALE, re-run and re-cite it"
  fi
done

if [ "$found_any" -eq 0 ]; then
  bad "no traceability.log under $QG_DIR/T-0*/ carries a TRACEABILITY-LOG-LIVE-TOTAL trailer -- this check would be vacuous"
fi

printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
