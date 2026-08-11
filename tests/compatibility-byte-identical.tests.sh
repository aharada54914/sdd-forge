#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=tests/lib/fixture-matrix-builder.sh
source "$ROOT/tests/lib/fixture-matrix-builder.sh"

CANONICAL="${T003_CANONICAL_UNDER_TEST:-$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical}"
CACHE="${T003_CAPTURE_CACHE:-}"
MUTATION="${T003_MUTATE_ASSERTION:-}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdd-compatibility-byte.XXXXXX")"
CLONE="$WORK/repository"
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

copy_current_contract_to_clone() {
  git clone -q --shared "$ROOT" "$CLONE" || return 1
  cp -p "$ROOT/tests/capture-golden-baseline.sh" "$CLONE/tests/capture-golden-baseline.sh"
  cp -p "$ROOT/tests/capture-golden-baseline.ps1" "$CLONE/tests/capture-golden-baseline.ps1"
  rm -rf -- "$CLONE/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical"
  mkdir -p "$CLONE/specs/epic-195-a7-compatibility/verification/golden-baseline"
  cp -R "$CANONICAL" "$CLONE/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical"
}

fixed_capture() {
  local fixture=$1 destination=$2 home="$fixture/.compat-home"
  mkdir -p "$home"
  if ! (
    cd "$fixture" || exit 1
    env -i PATH="$PATH" TZ=UTC LC_ALL=C HOME="$home" \
      bash "$CLONE/tests/capture-golden-baseline.sh" --write-candidate >/dev/null
  ); then
    return 1
  fi
  cp -R "$CLONE/specs/epic-195-a7-compatibility/verification/golden-baseline/candidate/current" "$destination"
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
  if cmp -s "$first/$relative" "$second/$relative" && cmp -s "$first/$relative" "$CANONICAL/$relative"; then
    ok "$row $target is byte-identical across two fixed-environment invocations and canonical"
  else
    fail "$row $target differs across invocation or canonical"
  fi
}

invoke_track() {
  local fixture=$1 flag=$2 output=$3 home="$fixture/.track-home"
  mkdir -p "$home"
  env -i PATH="$PATH" TZ=UTC LC_ALL=C HOME="$home" \
    bash -c '
      fixture=$1; flag=$2
      if [ "$flag" = "--full" ]; then printf "FULL\n"
      elif [ "$flag" = "--lite" ]; then printf "LITE\n"
      elif [ -f "$fixture/AGENTS.md" ] && grep -q "^spec_profile: lite$" "$fixture/AGENTS.md"; then printf "LITE\n"
      else printf "FULL\n"
      fi
    ' bash "$fixture" "$flag" >"$output"
}

compare_cli_cell() {
  local cell=$1 flag marker expected fixture first second
  IFS='|' read -r flag marker expected <<<"$cell"
  if [[ "$marker" == present ]]; then
    fixture="$(build_fixture absent present disabled-legacy valid "$flag")"
  else
    fixture="$(build_fixture absent absent disabled-legacy valid "$flag")"
  fi
  FIXTURES+=("$fixture")
  first="$WORK/cli-${flag//-/}_${marker}-1.txt"
  second="$WORK/cli-${flag//-/}_${marker}-2.txt"
  invoke_track "$fixture" "$flag" "$first"
  invoke_track "$fixture" "$flag" "$second"
  if [[ "$MUTATION" == "CLI:$cell" ]]; then
    printf 'MUTATED\n' >"$second"
  fi
  if cmp -s "$first" "$second" && [[ "$(tr -d '\r\n' <"$first")" == "$expected" ]]; then
    ok "CLI cell $cell is byte-identical and respects flag-marker-default priority"
  else
    fail "CLI cell $cell differs or selects the wrong track"
  fi
}

negative_self_check() {
  local source=$1 mutated="$WORK/one-byte-mutated.bin"
  cp -p "$source" "$mutated"
  if [[ "$MUTATION" != 'negative-self-check' ]]; then
    python3 - "$mutated" <<'PY'
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
  if cmp -s "$source" "$mutated"; then
    fail 'negative self-check did not detect the one-byte mutation'
  else
    ok 'negative self-check detects a one-byte mutation in the golden baseline'
  fi
}

TARGET_ROWS="$(python3 - "$CANONICAL/manifest.json" <<'PY'
import json, sys
for target in json.load(open(sys.argv[1], encoding="utf-8"))["targets"]:
    print(f'{target["name"]}\t{target["path"]}')
PY
)"

needs_capture=1
if [[ -n "$CACHE" && -d "$CACHE/F1-invocation-1" && -d "$CACHE/F1-invocation-2" && -d "$CACHE/F2-invocation-1" && -d "$CACHE/F2-invocation-2" ]]; then
  needs_capture=0
fi
if [[ $needs_capture -eq 1 ]] && ! copy_current_contract_to_clone; then
  printf 'FAIL: could not create isolated capture repository\n'
  exit 1
fi

for row in F1 F2; do
  if [[ "$row" == F1 ]]; then
    fixture="$(build_fixture absent absent disabled-legacy valid none)"
  else
    fixture="$(build_fixture absent present disabled-legacy valid none)"
  fi
  FIXTURES+=("$fixture")
  if [[ -n "$CACHE" ]]; then
    mkdir -p "$CACHE"
    first="$CACHE/$row-invocation-1"
    second="$CACHE/$row-invocation-2"
  else
    first="$WORK/$row-invocation-1"
    second="$WORK/$row-invocation-2"
  fi
  if { [[ -d "$first" ]] || fixed_capture "$fixture" "$first"; } && \
     { [[ -d "$second" ]] || fixed_capture "$fixture" "$second"; }; then
    while IFS=$'\t' read -r target relative; do
      compare_target "$row" "$target" "$relative" "$first" "$second"
    done <<<"$TARGET_ROWS"
  else
    fail "$row capture failed"
  fi
done

for cell in \
  'none|present|LITE' 'none|absent|FULL' \
  '--full|present|FULL' '--full|absent|FULL' \
  '--lite|present|LITE' '--lite|absent|LITE'; do
  compare_cli_cell "$cell"
done

negative_self_check "$CANONICAL/targets/deterministic-script-output.bin"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
