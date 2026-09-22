#!/usr/bin/env bash
# Run every canonical POSIX suite without a recognized execution in test.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
INVENTORY="${SUITE_INVENTORY:-$ROOT/tests/suite-inventory.posix}"
WORKFLOW="${CI_WORKFLOW:-$ROOT/.github/workflows/test.yml}"
SHARD_INDEX="${CI_UNWIRED_SHARD_INDEX:-}"
SHARD_COUNT="${CI_UNWIRED_SHARD_COUNT:-1}"

usage() {
  printf 'usage: %s [--list] [--shard-index N --shard-count N]\n' "$0" >&2
}

while (($#)); do
  case "$1" in
    --list) LIST_ONLY=1 ;;
    --shard-index)
      (($# >= 2)) || { usage; exit 2; }
      SHARD_INDEX="$2"
      shift
      ;;
    --shard-count)
      (($# >= 2)) || { usage; exit 2; }
      SHARD_COUNT="$2"
      shift
      ;;
    *) usage; exit 2 ;;
  esac
  shift
done

if [[ -n "$SHARD_INDEX" ]]; then
  [[ "$SHARD_INDEX" =~ ^[0-9]+$ && "$SHARD_COUNT" =~ ^[1-9][0-9]*$ ]] || {
    printf 'invalid shard selection: index=%s count=%s\n' "$SHARD_INDEX" "$SHARD_COUNT" >&2
    exit 2
  }
  ((SHARD_INDEX < SHARD_COUNT)) || {
    printf 'shard index must be less than shard count: index=%s count=%s\n' "$SHARD_INDEX" "$SHARD_COUNT" >&2
    exit 2
  }
else
  SHARD_INDEX=0
  SHARD_COUNT=1
fi
LIST_ONLY="${LIST_ONLY:-0}"

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
  function unknown_condition(line, expr) {
    sub(/^[[:space:]]*(if:|- if:)[[:space:]]*/, "", line)
    sub(/^[[:space:]]+/, "", line)
    sub(/[[:space:]]+$/, "", line)
    expr = line
    if (expr == "runner.os != '\''Windows'\''") return 0
    if (expr == "runner.os != \"Windows\"") return 0
    return 1
  }
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
    if (valid) step_pending = step_pending pending
    pending = ""; valid = 1; block = 0
  }
  function flush_step() {
    # Conditions can follow run in YAML. Decide only after the whole step.
    # Unknown conditions retain fallback coverage rather than proving execution.
    if (!conditional) job_pending = job_pending step_pending
    step_pending = ""; conditional = 0
  }
  function flush_job() {
    if (!job_conditional) printf "%s", job_pending
    job_pending = ""; job_conditional = 0
  }
  BEGIN { valid = 1 }
  {
    line = $0; sub(/\r$/, "", line)
    if (block && (line ~ /^          / || line ~ /^[[:space:]]*$/)) {
      if (!command(line)) valid = 0
      next
    }
    flush()
    if (line ~ /^      - / || line ~ /^  [^ ]/) flush_step()
    if (line ~ /^  [^ ]/) flush_job()
    if (line ~ /^    if:/ && unknown_condition(line)) job_conditional = 1
    if (line ~ /^(        if:|      - if:)/ && unknown_condition(line)) conditional = 1
    if (line !~ /^(        run:|      - run:)[[:space:]]/) next
    sub(/^(        run:|      - run:)[[:space:]]+/, "", line)
    if (line ~ /^\|[-+]?[[:space:]]*$/) { block = 1; next }
    valid = command(line)
    flush()
  }
  END { flush(); flush_step(); flush_job() }
' "$WORKFLOW")"

for suite in "${registered[@]}"; do
  if ! grep -Fx -- "$suite" <<<"$wired" >/dev/null; then
    missing+=("$suite")
  fi
done

selected=()
for ((position = 0; position < ${#missing[@]}; position++)); do
  if ((position % SHARD_COUNT == SHARD_INDEX)); then
    selected+=("${missing[position]}")
  fi
done

if ((LIST_ONLY)); then
  if ((${#selected[@]})); then
    printf '%s\n' "${selected[@]}"
  fi
  exit 0
fi

failed=()
cd "$ROOT"
for suite in "${selected[@]}"; do
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

printf 'All %d previously-unwired POSIX suites passed (shard %s/%s).\n' \
  "${#selected[@]}" "$((SHARD_INDEX + 1))" "$SHARD_COUNT"
