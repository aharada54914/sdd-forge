#!/usr/bin/env bash
# Run the local, deterministic POSIX regression suite in CI order.
set -euo pipefail

main() {
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"

tests=()
while IFS= read -r test_file || [[ -n "$test_file" ]]; do
  [[ -z "$test_file" || "$test_file" == \#* ]] && continue
  tests+=("$test_file")
done < "$ROOT/tests/suite-inventory.posix"

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${tests[@]}"
  exit 0
fi

# Every suite runs even after one fails: the suites are mutually independent,
# so aborting at the first failure hides the status of every later suite and
# turns an unbounded set of unrelated defects into a serial discovery queue.
failed=()

for test_file in "${tests[@]}"; do
  printf '==> %s\n' "$test_file"
  if ! bash "$test_file"; then
    printf 'FAILED: %s\n' "$test_file"
    failed+=("$test_file")
  fi
done

# Cross-runtime guard parity (PowerShell host suite; itself self-skips when
# python3 or node is absent). Skip only when pwsh is not installed.
printf '==> %s\n' "tests/guard-r10-port.tests.ps1"
if command -v pwsh >/dev/null 2>&1; then
  if ! pwsh -NoProfile -ExecutionPolicy Bypass -File tests/guard-r10-port.tests.ps1; then
    printf 'FAILED: %s\n' "tests/guard-r10-port.tests.ps1"
    failed+=("tests/guard-r10-port.tests.ps1")
  fi
else
  printf 'SKIP: pwsh not found; guard-r10-port.tests.ps1 not run\n'
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\n%d failing suite(s):\n' "${#failed[@]}"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi

printf 'All POSIX regression tests passed.\n'
exit 0
}

main "$@"
