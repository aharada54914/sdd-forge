#!/usr/bin/env bash
# Run every canonical POSIX suite that is not already named by test.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
RUN_ALL="$ROOT/tests/run-all.sh"
WORKFLOW="$ROOT/.github/workflows/test.yml"

mapfile -t registered < <(
  sed -n '/^tests=(/,/^)/p' "$RUN_ALL" |
    sed -n 's/^[[:space:]]*\(tests\/[^[:space:]]*\.tests\.sh\)[[:space:]]*$/\1/p'
)

missing=()
for suite in "${registered[@]}"; do
  if ! grep -qF -- "$suite" "$WORKFLOW"; then
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
