#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
runtime="${1:?sh or ps1}"
case "$runtime" in
  sh) command=(bash "$repo/tests/structural-compatibility.tests.sh") ;;
  ps1) command=(pwsh -NoProfile -File "$repo/tests/structural-compatibility.tests.ps1") ;;
  *) exit 2 ;;
esac
set +e
output="$("${command[@]}" 2>&1)"
status=$?
set -e
printf '%s\n' "$output"
failure=0
if (( status != 0 )); then printf 'FAIL: suite exit %s\n' "$status"; failure=1; fi
if ! grep -Fx 'AC-042 active: checking recorded F3 full-track artifacts' <<< "$output" >/dev/null; then
  printf '%s\n' 'FAIL: F3 activation assertion did not execute'; failure=1
fi
if grep -F 'SKIP: F3/AC-042' <<< "$output" >/dev/null; then
  printf '%s\n' 'FAIL: active F3 still emitted a dependency skip'; failure=1
fi
if (( failure == 0 )); then printf '%s\n' 'PASS: F3 active structural regression'; fi
exit "$failure"
