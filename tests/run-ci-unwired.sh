#!/usr/bin/env bash
# Run every canonical POSIX suite that is not already named by test.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
INVENTORY="${SUITE_INVENTORY:-$ROOT/tests/suite-inventory.posix}"
WORKFLOW="${CI_WORKFLOW:-$ROOT/.github/workflows/test.yml}"

registered=()
while IFS= read -r suite || [[ -n "$suite" ]]; do
  [[ -z "$suite" || "$suite" == \#* ]] && continue
  registered+=("$suite")
done < "$INVENTORY"

missing=()
workflow_runs_suite() {
  local suite=$1
  awk -v suite="$suite" '
    $0 !~ /^[[:space:]]*#/ && index($0, suite) { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$WORKFLOW"
}

for suite in "${registered[@]}"; do
  if ! workflow_runs_suite "$suite"; then
    missing+=("$suite")
  fi
done

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${missing[@]}"
  exit 0
fi

failed=()
cd "$ROOT"
for suite in "${missing[@]}"; do
  printf '==> %s\n' "$suite"
  if ! bash "$suite"; then
    failed+=("$suite")
  fi
done

if ((${#failed[@]})); then
  printf '\n%d previously-unwired suite(s) failed:\n' "${#failed[@]}" >&2
  printf '  %s\n' "${failed[@]}" >&2
  exit 1
fi

printf 'All %d previously-unwired POSIX suites passed.\n' "${#missing[@]}"
