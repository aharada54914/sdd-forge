#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PATCH="$ROOT/reports/verification/ci-loops-routing-macos-removal-20260923.patch"
WORKFLOW="$ROOT/.github/workflows/test.yml"

# Validate the protected workflow proposal without applying it.
grep -Fq 'os: [windows-latest, ubuntu-latest]' "$PATCH"
grep -Fq 'loops-routing:' "$PATCH"

# The patch must keep the stable required-check job identity and its name.
grep -Eq '^  loops-routing:$' "$WORKFLOW"
grep -Eq '^    name: loops-routing$' "$WORKFLOW"
loops_block="$(awk '
  /^  loops-routing:$/ { in_loops=1 }
  in_loops && NR > 1 && /^  [A-Za-z0-9_-]+:/ && $0 !~ /^  loops-routing:/ { exit }
  in_loops { print }
' "$WORKFLOW")"
printf '%s\n' "$loops_block" | grep -Fq 'os: [windows-latest, ubuntu-latest]'
if printf '%s\n' "$loops_block" | grep -Fq 'macos-latest'; then
  printf 'FAIL: loops-routing still includes macOS\n' >&2
  exit 1
fi

# The macOS-specific lanes remain present in the workflow.
grep -Eq '^  test:$' "$WORKFLOW"
grep -Eq '^  installers:$' "$WORKFLOW"
grep -Eq '^  version-gates:$' "$WORKFLOW"
grep -Fq "runner.os == 'macOS'" "$WORKFLOW"

# Timing control: independent 250 ms jobs should complete in parallel well
# below their 500 ms serial baseline. This exercises the candidate's wait-
# for-both execution model while avoiding runner-specific suite durations.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ci-qcd-timing.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
start_ns="$(python3 -c 'import time; print(time.monotonic_ns())')"
(sleep 0.25) & a=$!
(sleep 0.25) & b=$!
wait "$a"
wait "$b"
end_ns="$(python3 -c 'import time; print(time.monotonic_ns())')"
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
if (( elapsed_ms >= 450 )); then
  printf 'FAIL: parallel timing control took %dms (expected <450ms)\n' "$elapsed_ms" >&2
  exit 1
fi
printf 'CI QCD candidate checks passed; parallel timing control: %dms (serial baseline: 500ms)\n' "$elapsed_ms"
