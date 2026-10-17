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
  local cell=$1 flag marker fixture first second expected oracle
  IFS='|' read -r flag marker <<<"$cell"
  if [[ "$marker" == present ]]; then
    fixture="$(build_fixture absent present disabled-legacy valid "$flag")"
  else
    fixture="$(build_fixture absent absent disabled-legacy valid "$flag")"
  fi
  FIXTURES+=("$fixture")
  oracle=FULL
  if [[ "$flag" == --lite || ( "$flag" == none && "$marker" == present ) ]]; then oracle=LITE; fi
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

for cell in \
  'none|present' 'none|absent' \
  '--full|present' '--full|absent' \
  '--lite|present' '--lite|absent'; do
  compare_cli_cell "$cell"
done

negative_self_check "$CANONICAL/targets/deterministic-script-output.bin"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
