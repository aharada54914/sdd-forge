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
  'none|present' 'none|absent' \
  '--full|present' '--full|absent' \
  '--lite|present' '--lite|absent'; do
  ASSERTIONS+=("CLI:$cell")
done
ASSERTIONS+=('negative-self-check')

if [[ -n "${T003_ASSERTION_RANGE:-}" ]]; then
  IFS=: read -r range_start range_count <<<"$T003_ASSERTION_RANGE"
  if [[ ! "$range_start" =~ ^[0-9]+$ || ! "$range_count" =~ ^[1-9][0-9]*$ ]]; then
    printf 'invalid T003_ASSERTION_RANGE (expected START:COUNT): %s\n' "$T003_ASSERTION_RANGE" >&2
    exit 2
  fi
  ASSERTIONS=("${ASSERTIONS[@]:range_start:range_count}")
fi

mutate_contract_for_cell() {
  local cell=$1 destination=$2
  mkdir -p "$destination/plugins/sdd-ship/skills/ship"
  cp "$ROOT/plugins/sdd-ship/skills/ship/SKILL.md" "$destination/plugins/sdd-ship/skills/ship/SKILL.md"
  cp "$ROOT/PLUGIN-CONTRACTS.md" "$destination/PLUGIN-CONTRACTS.md"
  python3 - "$destination/plugins/sdd-ship/skills/ship/SKILL.md" "$cell" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
flag, marker = sys.argv[2].split("|")
row = 1 if flag == "--full" else 2 if flag == "--lite" else 3 if marker == "present" else 4
text = path.read_text(encoding="utf-8")
heading = re.search(r"(?m)^### Compatibility fallback \(no Project Context\)\s*$", text)
if heading is None:
    raise SystemExit("missing ship compatibility fallback section")
tail = text[heading.end():]
next_heading = re.search(r"(?m)^#{1,4} \S", tail)
end = heading.end() + (next_heading.start() if next_heading else len(tail))
section = text[heading.end():end]
pattern = re.compile(rf"(?m)^(\s*{row}\.\s+.+?)\s*$")
match = pattern.search(section)
if match is None:
    raise SystemExit(f"missing ship fallback row {row}")
body = match.group(1)
if "**FULL**" in body:
    mutated = body.replace("**FULL**", "**LITE**", 1)
elif "**LITE**" in body:
    mutated = body.replace("**LITE**", "**FULL**", 1)
else:
    raise SystemExit(f"ship fallback row {row} has no track literal")
section = section[:match.start(1)] + mutated + section[match.end(1):]
path.write_text(text[:heading.end()] + section + text[end:], encoding="utf-8")
PY
}

prove_runtime() {
  local runtime=$1 cache="$WORK/cache-$1" assertion rc mutation_root
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
    if [[ "$assertion" == CLI:* ]]; then
      mutation_root="$WORK/contract-$runtime-${assertion//[^A-Za-z0-9]/_}"
      mutate_contract_for_cell "${assertion#CLI:}" "$mutation_root"
      T003_CAPTURE_CACHE="$cache" T003_PRODUCT_ROOT_UNDER_TEST="$mutation_root" "${command[@]}"
    else
      T003_CAPTURE_CACHE="$cache" T003_MUTATE_ASSERTION="$assertion" "${command[@]}"
    fi
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

runtimes=(bash pwsh)
if [[ $# -gt 0 ]]; then
  runtimes=("$@")
fi
for runtime in "${runtimes[@]}"; do
  case "$runtime" in
    bash|pwsh) prove_runtime "$runtime" ;;
    *) printf 'unsupported runtime: %s\n' "$runtime" >&2; exit 2 ;;
  esac
done
printf 'mutation proof complete: %d assertions x %d runtime(s)\n' "${#ASSERTIONS[@]}" "${#runtimes[@]}"
