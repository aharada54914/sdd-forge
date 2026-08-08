#!/bin/sh
set -u

# T-005 verification harness -- proves the staged candidate satisfies
# TEST-054 (AC-028) without applying it to the live, protected
# .github/workflows/test.yml (which this task's own Done-When forbids the
# agent from writing, staged or live).
#
# The check function below is copied verbatim from
# tests/design-sync-standing-consent.tests.sh's own test_054_ci_registered
# (lines 577-588 at authoring time), parameterized by a CI_DIR argument
# instead of the suite's hardcoded "$ROOT/.github/workflows", so this
# harness exercises the SAME logic the real suite runs, against a scratch
# directory that holds only the candidate -- simulating "a human has applied
# this one file" without ever creating a path ending in the protected
# ".github/workflows/test.yml" suffix inside this repository.
#
# Usage: test054-harness.sh CI_DIR
#   CI_DIR -- a directory to scan for *.yml/*.yaml files (mirrors the real
#   suite's $ROOT/.github/workflows scan).

CI_DIR="${1:?usage: test054-harness.sh CI_DIR}"

test_054_ci_registered() {
  ci_dir="$CI_DIR"
  [ -d "$ci_dir" ] || return 1
  has_sh=0
  has_ps1=0
  for wf in "$ci_dir"/*.yml "$ci_dir"/*.yaml; do
    [ -f "$wf" ] || continue
    grep -q 'design-sync-standing-consent\.tests\.sh' "$wf" && has_sh=1
    grep -q 'design-sync-standing-consent\.tests\.ps1' "$wf" && has_ps1=1
  done
  [ "$has_sh" -eq 1 ] && [ "$has_ps1" -eq 1 ]
}

if test_054_ci_registered; then
  printf 'PASS: %s\n' "TEST-054 (harness) CI_DIR=$CI_DIR is reachable from a CI entry point (AC-028)"
  exit 0
else
  printf 'FAIL: %s\n' "TEST-054 (harness) CI_DIR=$CI_DIR is NOT reachable from a CI entry point (AC-028)"
  exit 1
fi
