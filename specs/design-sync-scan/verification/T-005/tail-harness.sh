#!/usr/bin/env bash
# T-005 verification harness: replicates tests/run-all.sh's own per-file loop
# body (verbatim mechanism -- printf header, `bash "$test_file"`, failure
# tracking) scoped to the array's last three entries, so this task's own new
# tail entry (tests/design-sync-scan.tests.sh) is exercised under run-all's
# exact invocation semantics without paying the cost of the full ~87-suite
# array, some of whose earlier members invoke real external tools (codex)
# and run for many minutes. This is supporting, in-scope evidence; the full
# `bash tests/run-all.sh` background run (see run-all-sh-full.log in this
# same directory) is the primary, real end-to-end evidence per the Done-When
# item's "exercise for real" branch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"
cd "$ROOT"

tests=(
  tests/design-system-contract.tests.sh
  tests/design-sync-standing-consent.tests.sh
  tests/design-sync-scan.tests.sh
)

failed=()

for test_file in "${tests[@]}"; do
  printf '==> %s\n' "$test_file"
  if ! bash "$test_file"; then
    printf 'FAILED: %s\n' "$test_file"
    failed+=("$test_file")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\n%d failing suite(s):\n' "${#failed[@]}"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi

printf 'Tail-harness: all scoped suites passed.\n'
