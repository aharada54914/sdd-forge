#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdd-t003-live-contract.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT


run_suite() {
  local runtime=$1 suite_root=$2 product_root=$3
  if [[ "$runtime" == bash ]]; then
    env T003_CANONICAL_UNDER_TEST="$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical" \
      T003_PRODUCT_ROOT_UNDER_TEST="$product_root" \
      bash "$suite_root/tests/compatibility-byte-identical.tests.sh"
  else
    env T003_CANONICAL_UNDER_TEST="$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical" \
      T003_PRODUCT_ROOT_UNDER_TEST="$product_root" \
      pwsh -NoProfile -File "$suite_root/tests/compatibility-byte-identical.tests.ps1"
  fi
}

expect_red() {
  local name=$1 diagnostic=$2
  shift 2
  local rc log="$WORK/negative.log"
  set +e
  "$@" >"$log" 2>&1
  rc=$?
  set -e
  cat "$log"
  if [[ $rc -eq 0 ]] || ! grep -Fq -- "$diagnostic" "$log"; then
    printf 'FAIL: mutation survived or failed for an unrelated reason: %s\n' "$name"
    return 1
  fi
  printf 'EXPECTED RED: %s (exit %d)\n' "$name" "$rc"
}

for runtime in bash pwsh; do
  scratch="$WORK/mutated-product-$runtime"
  git clone -q --shared "$ROOT" "$scratch"
  cp "$ROOT/plugins/sdd-ship/skills/ship/SKILL.md" "$scratch/plugins/sdd-ship/skills/ship/SKILL.md"
  cp "$ROOT/PLUGIN-CONTRACTS.md" "$scratch/PLUGIN-CONTRACTS.md"
  run_suite "$runtime" "$ROOT" "$scratch" >/dev/null

  # A copied suite must still depend on live product documents; provide all
  # executable dependencies so a missing helper cannot masquerade as success.
  suite_root="$WORK/copied-suite-$runtime"
  mkdir -p "$suite_root/tests/lib"
  cp "$ROOT/tests/compatibility-byte-identical.tests.$([[ "$runtime" == bash ]] && printf sh || printf ps1)" "$suite_root/tests/"
  cp "$ROOT/tests/lib/fixture-matrix-builder.$([[ "$runtime" == bash ]] && printf sh || printf ps1)" "$suite_root/tests/lib/"
  cp "$ROOT/tests/lib/current-byte-capture.py" "$suite_root/tests/lib/"
  run_suite "$runtime" "$suite_root" "$scratch" >/dev/null
  git -C "$scratch" rm -q -- PLUGIN-CONTRACTS.md
  expect_red "$runtime missing product contract" 'missing live product contract:' run_suite "$runtime" "$suite_root" "$scratch"
  git -C "$scratch" reset -q HEAD -- PLUGIN-CONTRACTS.md
  cp "$ROOT/PLUGIN-CONTRACTS.md" "$scratch/PLUGIN-CONTRACTS.md"
  run_suite "$runtime" "$ROOT" "$scratch" >/dev/null

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
  expect_red "$runtime mutated ship fallback contract" 'FAIL: CLI cell --full|present' run_suite "$runtime" "$ROOT" "$scratch"
done

printf 'live-contract dependency proof complete: 4 expected RED runs\n'
