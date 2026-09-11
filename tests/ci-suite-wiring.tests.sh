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

unwired="$($ROOT/tests/run-ci-unwired.sh --list | sort)"
while IFS= read -r suite; do
  grep -Fx -- "$suite" "$RUN_ALL" >/dev/null || {
    printf 'FAIL: fallback emitted an unregistered suite: %s\n' "$suite" >&2
    exit 1
  }
done <<<"$unwired"

if grep -Ev '^tests/[A-Za-z0-9._/-]+\.tests\.sh$' <<<"$unwired" | grep -q .; then
  printf 'FAIL: CI fallback emitted a comment or non-suite entry\n' >&2
  exit 1
fi

# Negative control: if a suite disappears from a specialized CI job, the
# fallback must discover it without changing either runner.
specialized_suite=tests/quality-gate-cycle-limit.tests.sh
grep -Fx -- "$specialized_suite" "$RUN_ALL" >/dev/null
grep -Fx -- "        run: bash ./$specialized_suite" "$WORKFLOW" >/dev/null
if grep -Fx -- "$specialized_suite" <<<"$unwired" >/dev/null; then
  printf 'FAIL: direct specialized suite was unnecessarily scheduled again\n' >&2
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

# Behavioral controls use the real runner and a one-suite inventory, not a
# second implementation of its workflow detector.
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/ci-wiring-controls.XXXXXX")"
trap 'rm -f "$tmp_workflow"; rm -rf "$fixture_dir"' EXIT
suite=tests/ci-suite-wiring.tests.sh
printf '%s\n' "$suite" > "$fixture_dir/inventory"
assert_fallback() {
  local label=$1 expected=$2 body=$3 actual
  printf 'jobs:\n  test:\n    steps:\n%s\n' "$body" > "$fixture_dir/workflow.yml"
  actual="$(SUITE_INVENTORY="$fixture_dir/inventory" CI_WORKFLOW="$fixture_dir/workflow.yml" bash "$ROOT/tests/run-ci-unwired.sh" --list)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s: expected fallback [%s], got [%s]\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}
assert_fallback step-name "$suite" "      - name: $suite
        run: echo done"
assert_fallback env-value "$suite" "      - env:
          TARGET: $suite
        run: echo done"
assert_fallback assertion "$suite" "      - run: test -f $suite"
assert_fallback echoed-command "$suite" "      - run: echo bash $suite"
assert_fallback heredoc "$suite" "      - run: |
          cat <<'EOF'
          bash $suite
          EOF"
assert_fallback conditional "$suite" "      - run: |
          if false; then
            bash $suite
          fi"
assert_fallback direct '' "      - name: execute
        run: bash ./$suite"
assert_fallback multiline '' "      - name: execute
        run: |
          bash $suite"
assert_fallback logging '' "      - name: execute
        run: |
          bash $suite 2>&1 | tee \"suite.log\""
assert_fallback path-prefix "$suite" "      - name: different suite
        run: bash ./${suite}.extra"
assert_fallback syntax-only "$suite" "      - run: bash -n ./$suite"
assert_fallback syntax-then-execution '' "      - name: execute
        run: |
          bash -n ./tests/release-host-smoke.sh
          ./$suite 2>&1 | tee \"suite.log\""
printf 'CI suite wiring behavioral controls passed (12 cases)\n'
