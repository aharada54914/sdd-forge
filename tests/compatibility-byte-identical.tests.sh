#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=tests/lib/fixture-matrix-builder.sh
source "$ROOT/tests/lib/fixture-matrix-builder.sh"

CANONICAL="${T003_CANONICAL_UNDER_TEST:-$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical}"
PRODUCT_ROOT="${T003_PRODUCT_ROOT_UNDER_TEST:-$ROOT}"
# Historical cache directories must never suppress current-product execution.
MUTATION="${T003_MUTATE_ASSERTION:-}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdd-compatibility-byte.XXXXXX")"
# Canonical inventory asserted from manifest rows: deterministic-script-output,
# exit-code, stdout-stderr, template-copy-result, schema-validator-result,
# install-result, uninstall-result, generated-directory-listing, plugin-manifest.
PASS=0
FAIL=0
FIXTURES=()

cleanup() {
  local fixture
  for fixture in "${FIXTURES[@]}"; do
    _fixture_matrix_cleanup "$fixture"
  done
  rm -rf -- "$WORK"
}
trap cleanup EXIT

ok() { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

fixed_capture() {
  python3 "$ROOT/tests/lib/current-byte-capture.py" --product "$PRODUCT_ROOT" \
    --fixture "$1" --destination "$2" --canonical "$CANONICAL" --runtime bash
}

compare_target() {
  local row=$1 target=$2 relative=$3 first=$4 second=$5
  if [[ "$MUTATION" == "$row:$target" ]]; then
    local mutated="$WORK/mutated-$row-$target"
    cp -R "$first" "$mutated"
    python3 - "$mutated/$relative" <<'PY'
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
    first="$mutated"
  fi
  if cmp -s "$first/$relative" "$second/$relative" && cmp -s "$first/$relative" "$second/expected/$relative" && cmp -s "$first/expected/$relative" "$second/expected/$relative"; then
    ok "$row $target is byte-identical across two fixed-environment invocations and independent expected bytes"
  else
    fail "$row $target differs across invocation or independent expected bytes"
  fi
}

# Q09 (owner decision 2026-11-28): the six CLI cells (no flag, --full, --lite,
# each with and without the retired `spec_profile: lite` marker) resolve to the
# v2 standard flow by each task's Risk, identically in the public contract
# (PLUGIN-CONTRACTS.md) and in the ship skill. The fixture's marker is read so
# that a contract mapping either coordinate differently is caught.
resolve_contract_track() {
  local document=$1 fixture=$2 flag=$3
  python3 "$ROOT/tests/lib/track-contract.py" "$document" "$fixture" "$flag"
}

compare_cli_cell() {
  local cell=$1 flag marker context fixture first second expected oracle=STANDARD_BY_RISK
  IFS='|' read -r flag marker context <<<"$cell"
  case "$context" in
    absent) fixture="$(build_fixture absent "$marker" disabled-legacy valid "$flag")" ;;
    valid) fixture="$(build_fixture present "$marker" advisory valid "$flag")" ;;
    invalid) fixture="$(build_fixture present "$marker" advisory PROJECT_CONTEXT_INVALID "$flag")" ;;
  esac
  FIXTURES+=("$fixture")
  if first="$(resolve_contract_track "$PRODUCT_ROOT/plugins/sdd-ship/skills/ship/SKILL.md" "$fixture" "$flag")" &&
     second="$(resolve_contract_track "$PRODUCT_ROOT/plugins/sdd-ship/skills/ship/SKILL.md" "$fixture" "$flag")" &&
     expected="$(resolve_contract_track "$PRODUCT_ROOT/PLUGIN-CONTRACTS.md" "$fixture" "$flag")" &&
     [[ "$first" == "$second" && "$first" == "$expected" && "$first" == "$oracle" ]]; then
    ok "CLI cell $cell resolves identically from both live product contracts"
  else
    fail "CLI cell $cell is missing or inconsistent across live product contracts"
  fi
}

negative_self_check() {
  local source=$1 observed expected actual
  observed=$source
  if [[ "$MUTATION" == 'negative-self-check' ]]; then
    observed="$WORK/one-byte-mutated.bin"
    cp -p "$source" "$observed"
    python3 - "$observed" <<'PY'
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
  fi
  expected="$(python3 - "$CANONICAL/manifest.json" <<'PY'
import json, sys
for target in json.load(open(sys.argv[1], encoding="utf-8"))["targets"]:
    if target["name"] == "deterministic-script-output":
        print(target["sha256"])
        break
else:
    raise SystemExit("deterministic-script-output missing from manifest")
PY
)"
  actual="$(python3 - "$observed" <<'PY'
import hashlib, sys
with open(sys.argv[1], "rb") as stream:
    print(hashlib.sha256(stream.read()).hexdigest())
PY
)"
  if [[ "$actual" == "$expected" ]]; then
    ok 'negative self-check: canonical target bytes match the manifest sha256'
  else
    fail 'negative self-check: canonical target bytes differ from the manifest sha256'
  fi
}

TARGET_ROWS="$(python3 - "$CANONICAL/manifest.json" <<'PY'
import json, sys
for target in json.load(open(sys.argv[1], encoding="utf-8"))["targets"]:
    print(f'{target["name"]}\t{target["path"]}')
PY
)"

for row in F1 F2; do
  if [[ "$row" == F1 ]]; then
    fixture="$(build_fixture absent absent disabled-legacy valid none)"
  else
    fixture="$(build_fixture absent present disabled-legacy valid none)"
  fi
  FIXTURES+=("$fixture")
  first="$WORK/$row-invocation-1"
  second="$WORK/$row-invocation-2"
  if fixed_capture "$fixture" "$first" && fixed_capture "$fixture" "$second"; then
    while IFS=$'\t' read -r target relative; do
      compare_target "$row" "$target" "$relative" "$first" "$second"
    done <<<"$TARGET_ROWS"
  else
    fail "$row capture failed"
  fi
done

# Each of the six flag x marker cells is checked with no Project Context, a
# valid one and an invalid one; the v2 flow never depends on it (Q09).
for context in absent valid invalid; do
  for cell in \
    'none|present' 'none|absent' \
    '--full|present' '--full|absent' \
    '--lite|present' '--lite|absent'; do
    compare_cli_cell "$cell|$context"
  done
done

negative_self_check "$CANONICAL/targets/deterministic-script-output.bin"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
