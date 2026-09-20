#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdd-t003-live-contract.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT

prime_cache() {
  local runtime=$1 cache=$2
  if [[ "$runtime" == bash ]]; then
    env -u T003_CANONICAL_UNDER_TEST -u T003_PRODUCT_ROOT_UNDER_TEST -u T003_MUTATE_ASSERTION \
      T003_CAPTURE_CACHE="$cache" bash "$ROOT/tests/compatibility-byte-identical.tests.sh" >/dev/null
  else
    env -u T003_CANONICAL_UNDER_TEST -u T003_PRODUCT_ROOT_UNDER_TEST -u T003_MUTATE_ASSERTION \
      T003_CAPTURE_CACHE="$cache" pwsh -NoProfile -File "$ROOT/tests/compatibility-byte-identical.tests.ps1" >/dev/null
  fi
}

run_suite() {
  local runtime=$1 suite_root=$2 cache=$3 product_root=$4
  if [[ "$runtime" == bash ]]; then
    env T003_CAPTURE_CACHE="$cache" \
      T003_CANONICAL_UNDER_TEST="$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical" \
      T003_PRODUCT_ROOT_UNDER_TEST="$product_root" \
      bash "$suite_root/tests/compatibility-byte-identical.tests.sh"
  else
    env T003_CAPTURE_CACHE="$cache" \
      T003_CANONICAL_UNDER_TEST="$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical" \
      T003_PRODUCT_ROOT_UNDER_TEST="$product_root" \
      pwsh -NoProfile -File "$suite_root/tests/compatibility-byte-identical.tests.ps1"
  fi
}

expect_red() {
  local name=$1
  shift
  local rc
  set +e
  "$@"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    printf 'FAIL: mutation survived: %s\n' "$name"
    return 1
  fi
  printf 'EXPECTED RED: %s (exit %d)\n' "$name" "$rc"
}

cache="$WORK/cache"
prime_cache bash "$cache"

for runtime in bash pwsh; do

  empty_root="$WORK/no-product-$runtime"
  mkdir -p "$empty_root/tests/lib"
  cp "$ROOT/tests/compatibility-byte-identical.tests.$([[ "$runtime" == bash ]] && printf sh || printf ps1)" "$empty_root/tests/"
  cp "$ROOT/tests/lib/fixture-matrix-builder.$([[ "$runtime" == bash ]] && printf sh || printf ps1)" "$empty_root/tests/lib/"
  expect_red "$runtime missing product contracts" run_suite "$runtime" "$empty_root" "$cache" "$empty_root"

  scratch="$WORK/mutated-product-$runtime"
  mkdir -p "$scratch/plugins/sdd-ship/skills/ship"
  cp "$ROOT/plugins/sdd-ship/skills/ship/SKILL.md" "$scratch/plugins/sdd-ship/skills/ship/SKILL.md"
  cp "$ROOT/PLUGIN-CONTRACTS.md" "$scratch/PLUGIN-CONTRACTS.md"
  python3 - "$scratch/plugins/sdd-ship/skills/ship/SKILL.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = "1. `--full` flag present → **FULL** track."
new = "1. `--full` flag present → **LITE** track."
if text.count(old) != 1:
    raise SystemExit("expected one live --full fallback row")
path.write_text(text.replace(old, new), encoding="utf-8")
PY
  expect_red "$runtime mutated ship fallback contract" run_suite "$runtime" "$ROOT" "$cache" "$scratch"
done

printf 'live-contract dependency proof complete: 4 expected RED runs\n'
