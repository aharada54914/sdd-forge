#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdd-t003-mutation.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT

ASSERTIONS=()
for row in F1 F2; do
  while IFS= read -r target; do
    ASSERTIONS+=("$row:$target")
  done < <(python3 - "$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical/manifest.json" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding='utf-8'))['targets']:
    print(item['name'])
PY
)
done
for cell in \
  'none|present|LITE' 'none|absent|FULL' \
  '--full|present|FULL' '--full|absent|FULL' \
  '--lite|present|LITE' '--lite|absent|LITE'; do
  ASSERTIONS+=("CLI:$cell")
done
ASSERTIONS+=('negative-self-check')

prove_runtime() {
  local runtime=$1 cache="$WORK/cache-$1" assertion rc
  local command=()
  if [[ "$runtime" == bash ]]; then
    command=(bash "$ROOT/tests/compatibility-byte-identical.tests.sh")
  else
    command=(pwsh -NoProfile -File "$ROOT/tests/compatibility-byte-identical.tests.ps1")
  fi

  printf '=== %s cache prime / GREEN ===\n' "$runtime"
  T003_CAPTURE_CACHE="$cache" "${command[@]}"
  for assertion in "${ASSERTIONS[@]}"; do
    printf 'MUTATE %s %s\n' "$runtime" "$assertion"
    set +e
    T003_CAPTURE_CACHE="$cache" T003_MUTATE_ASSERTION="$assertion" "${command[@]}"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      printf 'FAIL: mutation survived: %s %s\n' "$runtime" "$assertion"
      return 1
    fi
    printf 'EXPECTED RED: %s %s (exit %d)\n' "$runtime" "$assertion" "$rc"
  done
  printf 'RESTORE %s / GREEN\n' "$runtime"
  T003_CAPTURE_CACHE="$cache" "${command[@]}"
}

prove_runtime bash
prove_runtime pwsh
printf 'mutation proof complete: %d assertions x 2 runtimes\n' "${#ASSERTIONS[@]}"
