#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
WORKFLOW="$ROOT/.github/workflows/test.yml"

# CI must consume the canonical inventory through its missing-suite runner;
# otherwise a newly registered suite silently remains local-only.
count="$(grep -Ec '^[[:space:]]*run: bash ./tests/run-ci-unwired\.sh[[:space:]]*$' "$WORKFLOW")"
if [[ "$count" != "1" ]]; then
  printf 'FAIL: expected exactly one CI invocation of tests/run-ci-unwired.sh, found %s\n' "$count" >&2
  exit 1
fi

unwired="$($ROOT/tests/run-ci-unwired.sh --list)"
for required in \
  tests/workflow-state-registry.tests.sh \
  tests/facet-manifest-schema.tests.sh \
  tests/guard-negative-corpus.tests.sh \
  tests/guard-cwd-bypass.tests.sh; do
  if ! grep -qxF "$required" <<<"$unwired"; then
    printf 'FAIL: expected fallback inventory to contain %s\n' "$required" >&2
    exit 1
  fi
done

if ! grep -qE '^  posix-regression:' "$WORKFLOW"; then
  printf 'FAIL: canonical POSIX inventory must run in its own job\n' >&2
  exit 1
fi

printf 'CI suite wiring tests passed\n'
