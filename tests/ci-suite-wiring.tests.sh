#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
RUN_ALL="$ROOT/tests/suite-inventory.posix"
WORKFLOW="$ROOT/.github/workflows/test.yml"

count="$(grep -Ec '^[[:space:]]*run: bash ./tests/run-ci-unwired\.sh[[:space:]]*$' "$WORKFLOW")"
if [[ "$count" != "1" ]]; then
  printf 'FAIL: expected exactly one CI invocation of tests/run-ci-unwired.sh, found %s\n' "$count" >&2
  exit 1
fi

if ! test -s "$RUN_ALL"; then
  printf 'FAIL: canonical inventory file is empty\n' >&2
  exit 1
fi

if grep -Ev '^(#.*|$|tests/[A-Za-z0-9._/-]+\.tests\.sh)$' "$RUN_ALL" | grep -q .; then
  printf 'FAIL: canonical inventory contains a non-canonical entry\n' >&2
  exit 1
fi

duplicates="$(grep -E '^tests/[A-Za-z0-9._/-]+\.tests\.sh$' "$RUN_ALL" | sort | uniq -d)"
if [[ -n "$duplicates" ]]; then
  printf 'FAIL: canonical inventory contains duplicate suites:\n%s\n' "$duplicates" >&2
  exit 1
fi

while IFS= read -r suite; do
  [[ -z "$suite" || "$suite" == \#* ]] && continue
  if [[ ! -f "$ROOT/$suite" ]]; then
    printf 'FAIL: canonical inventory names a missing suite: %s\n' "$suite" >&2
    exit 1
  fi
done < "$RUN_ALL"

expected="$(
  while IFS= read -r suite; do
    [[ -n "$suite" && "$suite" != \#* ]] || continue
    if ! awk -v suite="$suite" '
      $0 !~ /^[[:space:]]*#/ && index($0, suite) { found = 1 }
      END { exit found ? 0 : 1 }
    ' "$WORKFLOW"; then
      printf '%s\n' "$suite"
    fi
  done < "$RUN_ALL" | sort
)"
unwired="$($ROOT/tests/run-ci-unwired.sh --list | sort)"
if [[ "$unwired" != "$expected" ]]; then
  printf 'FAIL: run-ci-unwired.sh inventory drifted from the canonical inventory/workflow diff\n' >&2
  printf 'expected:\n%s\n' "$expected" >&2
  printf 'actual:\n%s\n' "$unwired" >&2
  exit 1
fi

if grep -Ev '^tests/[A-Za-z0-9._/-]+\.tests\.sh$' <<<"$unwired" | grep -q .; then
  printf 'FAIL: CI fallback emitted a comment or non-suite entry\n' >&2
  exit 1
fi

# Negative control: if a suite disappears from a specialized CI job, the
# fallback must discover it without changing either runner.
specialized_suite="$(
  while IFS= read -r suite; do
    [[ -n "$suite" && "$suite" != \#* ]] || continue
    awk -v suite="$suite" '
      $0 !~ /^[[:space:]]*#/ && index($0, suite) { found = 1 }
      END { exit found ? 0 : 1 }
    ' "$WORKFLOW" && { printf '%s\n' "$suite"; break; }
  done < "$RUN_ALL"
)"
if [[ -z "$specialized_suite" ]]; then
  printf 'FAIL: no specialized suite is shared by the canonical inventory and workflow\n' >&2
  exit 1
fi

tmp_workflow="$(mktemp "${TMPDIR:-/tmp}/ci-suite-wiring.XXXXXX")"
trap 'rm -f "$tmp_workflow"' EXIT
grep -vF -- "$specialized_suite" "$WORKFLOW" > "$tmp_workflow"
printf '# comment-only reference must not count as execution: %s\n' "$specialized_suite" >> "$tmp_workflow"
mutated_unwired="$(CI_WORKFLOW="$tmp_workflow" "$ROOT/tests/run-ci-unwired.sh" --list)"
if ! grep -Fxq -- "$specialized_suite" <<<"$mutated_unwired"; then
  printf 'FAIL: CI fallback did not discover suite removed from specialized workflow: %s\n' "$specialized_suite" >&2
  exit 1
fi

printf 'CI suite wiring tests passed\n'
