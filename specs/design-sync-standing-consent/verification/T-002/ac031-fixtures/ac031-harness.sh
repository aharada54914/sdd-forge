#!/bin/sh
set -u
# Standalone positive-control harness for AC-031's two fixtures
# (tasks.md T-002 Done-When, AC-031 bullet). Reproduces
# tests/design-sync-standing-consent.tests.sh's section_between,
# flatten_text and the exact TEST-055/TEST-056 conditions verbatim, so the
# demonstration runs against the fixture argument's path instead of the
# live tree -- the live AGENTS.md is never touched by this harness.

FIXTURE="$1"

section_between() {
  awk -v start="$2" -v end="$3" '
    $0 ~ start { flag = 1 }
    flag && $0 ~ end && $0 !~ start { exit }
    flag { print }
  ' "$1" 2>/dev/null
}
flatten_text() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s '[:space:]' ' '
}

AG_PS_SECTION=$(section_between "$FIXTURE" '^## Project Settings$' '^## ')
AG_PS_FLAT=$(flatten_text "$AG_PS_SECTION")

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'not exactly one of.{0,40}lowercase literals' \
  && printf '%s' "$AG_PS_FLAT" | grep -Eiq 'never.{0,5}standing' \
  && printf '%s' "$AG_PS_FLAT" | grep -Eiq 'never.{0,5}off'; then
  echo "PASS: TEST-055 branch 3: a present out-of-domain value is stated to resolve to per-feature, never standing, never off (AC-031)"
else
  echo "FAIL: TEST-055 branch 3: a present out-of-domain value is stated to resolve to per-feature, never standing, never off (AC-031)"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'exact.{0,15}case-sensitive' \
  && printf '%s' "$AG_PS_FLAT" | grep -Fq 'Standing'; then
  echo "PASS: TEST-056 value matching is stated as exact and case-sensitive, a case variant is named as out-of-domain input (AC-031)"
else
  echo "FAIL: TEST-056 value matching is stated as exact and case-sensitive, a case variant is named as out-of-domain input (AC-031)"
fi
