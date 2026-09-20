#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=tests/lib/fixture-matrix-builder.sh
source "$ROOT/tests/lib/fixture-matrix-builder.sh"

CANONICAL="${T003_CANONICAL_UNDER_TEST:-$ROOT/specs/epic-195-a7-compatibility/verification/golden-baseline/canonical}"
PRODUCT_ROOT="${T003_PRODUCT_ROOT_UNDER_TEST:-$ROOT}"
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

resolve_contract_track() {
  local document=$1 fixture=$2 flag=$3
  python3 - "$document" "$fixture" "$flag" <<'PY'
from pathlib import Path
import re
import sys

document = Path(sys.argv[1])
fixture = Path(sys.argv[2])
flag = sys.argv[3]
if not document.is_file():
    raise SystemExit(f"missing live product contract: {document}")

text = document.read_text(encoding="utf-8")
heading = re.search(
    r"(?m)^#{3,4} Compatibility fallback \(no Project Context\)\s*$", text
)
if heading is None:
    raise SystemExit(f"missing compatibility fallback section: {document}")
tail = text[heading.end():]
next_heading = re.search(r"(?m)^#{1,4} \S", tail)
section = tail[:next_heading.start()] if next_heading else tail
rows = {
    int(match.group(1)): match.group(2)
    for match in re.finditer(r"(?m)^\s*([1-4])\.\s+(.+?)\s*$", section)
}
if set(rows) != {1, 2, 3, 4}:
    raise SystemExit(f"incomplete compatibility fallback rows: {document}")

marker_present = False
agents = fixture / "AGENTS.md"
if agents.is_file():
    marker_present = "spec_profile: lite" in agents.read_text(encoding="utf-8").splitlines()
row = 1 if flag == "--full" else 2 if flag == "--lite" else 3 if marker_present else 4
tracks = re.findall(r"(?<![A-Za-z])(FULL|LITE)(?![A-Za-z])", rows[row])
if not tracks:
    raise SystemExit(f"fallback row {row} has no track resolution: {document}")
print(tracks[0])
PY
}

compare_cli_cell() {
  local cell=$1 flag marker fixture first second expected
  IFS='|' read -r flag marker <<<"$cell"
  if [[ "$marker" == present ]]; then
    fixture="$(build_fixture absent present disabled-legacy valid "$flag")"
  else
    fixture="$(build_fixture absent absent disabled-legacy valid "$flag")"
  fi
  FIXTURES+=("$fixture")
  if first="$(resolve_contract_track "$PRODUCT_ROOT/plugins/sdd-ship/skills/ship/SKILL.md" "$fixture" "$flag")" &&
     second="$(resolve_contract_track "$PRODUCT_ROOT/plugins/sdd-ship/skills/ship/SKILL.md" "$fixture" "$flag")" &&
     expected="$(resolve_contract_track "$PRODUCT_ROOT/PLUGIN-CONTRACTS.md" "$fixture" "$flag")" &&
     [[ "$first" == "$second" && "$first" == "$expected" ]]; then
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
  'none|present' 'none|absent' \
  '--full|present' '--full|absent' \
  '--lite|present' '--lite|absent'; do
  compare_cli_cell "$cell"
done

negative_self_check "$CANONICAL/targets/deterministic-script-output.bin"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
