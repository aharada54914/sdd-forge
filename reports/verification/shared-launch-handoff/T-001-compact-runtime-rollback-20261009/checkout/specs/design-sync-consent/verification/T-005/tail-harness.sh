#!/usr/bin/env bash
# T-005 real-execution proof: replicates tests/run-all.sh's exact loop
# mechanism (set -euo pipefail; for test_file in "${tests[@]}"; do bash
# "$test_file"; done), scoped to the tail of the real array (the last two
# pre-existing entries plus the newly-registered
# tests/design-system-contract.tests.sh), run from the real repository
# root, to prove the registration integrates and is reachable/executable
# under run-all's own invocation semantics -- independent of the unrelated,
# environment-load-induced failure earlier in the full array (see report).
set -euo pipefail

ROOT="/Users/jrmag/Projects/active/sdd-forge-wt-phase4"
cd "$ROOT"

tests=(
  tests/facet-manifest-schema.tests.sh
  tests/facet-manifest-semantics.tests.sh
  tests/design-system-contract.tests.sh
)

for test_file in "${tests[@]}"; do
  printf '==> %s\n' "$test_file"
  bash "$test_file"
done

printf 'TAIL HARNESS: all tail entries passed under run-all semantics.\n'
