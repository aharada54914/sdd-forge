#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
WORKFLOW="$ROOT/.github/workflows/test.yml"
RUN_ALL="$ROOT/tests/run-all.sh"

# CI must consume the canonical inventory through its missing-suite runner;
# otherwise a newly registered suite silently remains local-only.
count="$(grep -Ec '^[[:space:]]*run: bash ./tests/run-ci-unwired\.sh[[:space:]]*$' "$WORKFLOW")"
if [[ "$count" != "1" ]]; then
  printf 'FAIL: expected exactly one CI invocation of tests/run-ci-unwired.sh, found %s\n' "$count" >&2
  exit 1
fi

expected="$(
  sed -n '/^tests=(/,/^)/p' "$RUN_ALL" |
    sed -n 's/^[[:space:]]*\(tests\/[^[:space:]]*\.tests\.sh\)[[:space:]]*$/\1/p' |
    while IFS= read -r suite; do
      if ! grep -qF -- "$suite" "$WORKFLOW"; then
        printf '%s\n' "$suite"
      fi
    done | sort
)"
unwired="$($ROOT/tests/run-ci-unwired.sh --list | sort)"
if [[ "$unwired" != "$expected" ]]; then
  printf 'FAIL: run-ci-unwired.sh inventory drifted from the canonical run-all/workflow diff\n' >&2
  printf 'expected:\n%s\n' "$expected" >&2
  printf 'actual:\n%s\n' "$unwired" >&2
  exit 1
fi

if ! grep -qE '^  posix-regression:' "$WORKFLOW"; then
  printf 'FAIL: canonical POSIX inventory must run in its own job\n' >&2
  exit 1
fi

printf 'CI suite wiring tests passed\n'
