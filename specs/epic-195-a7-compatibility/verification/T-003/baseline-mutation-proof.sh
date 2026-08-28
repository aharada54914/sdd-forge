#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"
CANONICAL="$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdd-t003-baseline-mutation.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT

prove_runtime() {
  local runtime=$1 cache="$WORK/cache-$1" mutated="$WORK/canonical-$1" rc
  local command=()
  if [[ "$runtime" == bash ]]; then
    command=(bash "$ROOT/tests/compatibility-byte-identical.tests.sh")
  else
    command=(pwsh -NoProfile -File "$ROOT/tests/compatibility-byte-identical.tests.ps1")
  fi

  printf '=== %s baseline GREEN ===\n' "$runtime"
  T003_CAPTURE_CACHE="$cache" "${command[@]}"

  cp -R "$CANONICAL" "$mutated"
  python3 - "$mutated/targets/deterministic-script-output.bin" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = bytearray(p.read_bytes())
if data:
    data[0] ^= 1
else:
    data.append(1)
p.write_bytes(data)
PY
  printf 'MUTATE %s canonical deterministic-script-output by one byte\n' "$runtime"
  set +e
  T003_CAPTURE_CACHE="$cache" T003_CANONICAL_UNDER_TEST="$mutated" "${command[@]}"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    printf 'FAIL: %s suite accepted the one-byte-mutated golden baseline\n' "$runtime"
    return 1
  fi
  printf 'EXPECTED RED: %s one-byte-mutated golden baseline (exit %d)\n' "$runtime" "$rc"

  rm -rf -- "$mutated"
  cp -R "$CANONICAL" "$mutated"
  printf 'RESTORE %s canonical / GREEN\n' "$runtime"
  T003_CAPTURE_CACHE="$cache" T003_CANONICAL_UNDER_TEST="$mutated" "${command[@]}"
}

prove_runtime bash
prove_runtime pwsh
printf 'baseline mutation proof complete\n'
