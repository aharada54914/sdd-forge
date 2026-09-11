#!/usr/bin/env bash
# Run every canonical POSIX suite without a recognized execution in test.yml.
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
# Recognize the explicit step shape used by this workflow, not arbitrary text
# mentions. Only wholly simple run bodies qualify: unknown shell syntax,
# heredocs and conditionals retain the suite in the fallback inventory.
wired="$(awk '
  function command(line, path, tail) {
    sub(/^[[:space:]]+/, "", line)
    sub(/[[:space:]]+$/, "", line)
    if (line == "" || line ~ /^#/) return 1
    # A syntax-only preflight may precede execution, but is not execution.
    if (line ~ /^bash -n (\.\/)?tests\/[A-Za-z0-9._\/-]+\.sh$/) return 1
    sub(/^bash[[:space:]]+/, "", line)
    sub(/^\.\//, "", line)
    path = line
    sub(/[[:space:]].*$/, "", path)
    if (path !~ /^tests\/[A-Za-z0-9._\/-]+\.tests\.sh$/) return 0
    tail = substr(line, length(path) + 1)
    if (tail != "" && tail !~ /^ 2>&1 \| tee "[^"\r\n]+"$/) return 0
    pending = pending path "\n"
    return 1
  }
  function flush() {
    if (valid) printf "%s", pending
    pending = ""; valid = 1; block = 0
  }
  BEGIN { valid = 1 }
  {
    line = $0; sub(/\r$/, "", line)
    if (block && (line ~ /^          / || line ~ /^[[:space:]]*$/)) {
      if (!command(line)) valid = 0
      next
    }
    flush()
    if (line !~ /^(        run:|      - run:)[[:space:]]/) next
    sub(/^(        run:|      - run:)[[:space:]]+/, "", line)
    if (line ~ /^\|[-+]?[[:space:]]*$/) { block = 1; next }
    valid = command(line)
    flush()
  }
  END { flush() }
' "$WORKFLOW")"

for suite in "${registered[@]}"; do
  if ! grep -Fx -- "$suite" <<<"$wired" >/dev/null; then
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
