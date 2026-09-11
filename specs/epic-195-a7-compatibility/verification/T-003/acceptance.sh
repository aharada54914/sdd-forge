#!/usr/bin/env bash
set -u

ROOT="${T003_REPO_UNDER_TEST:-$(cd "$(dirname "$0")/../../../.." && pwd -P)}"
PASS=0
FAIL=0

pass() { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

assert_files() {
  local message=$1
  shift
  local path
  for path in "$@"; do
    if [[ ! -f "$ROOT/$path" ]]; then
      fail "$message (missing $path)"
      return
    fi
  done
  pass "$message"
}

assert_contains_all() {
  local message=$1 path=$2
  shift 2
  local needle
  if [[ ! -f "$ROOT/$path" ]]; then
    fail "$message (missing $path)"
    return
  fi
  for needle in "$@"; do
    if ! grep -Fq -- "$needle" "$ROOT/$path"; then
      fail "$message (missing '$needle' in $path)"
      return
    fi
  done
  pass "$message"
}

assert_files \
  'A1 compatibility suite twins exist' \
  tests/compatibility-byte-identical.tests.sh \
  tests/compatibility-byte-identical.tests.ps1

assert_contains_all \
  'A2 Bash suite sources the fixture builder and names F1/F2' \
  tests/compatibility-byte-identical.tests.sh \
  'tests/lib/fixture-matrix-builder.sh' 'build_fixture' 'F1' 'F2'
assert_contains_all \
  'A2 PowerShell suite dot-sources the fixture builder and names F1/F2' \
  tests/compatibility-byte-identical.tests.ps1 \
  'tests/lib/fixture-matrix-builder.ps1' 'build_fixture' 'F1' 'F2'

inventory=(
  deterministic-script-output exit-code stdout-stderr template-copy-result
  schema-validator-result install-result uninstall-result
  generated-directory-listing plugin-manifest
)
assert_contains_all \
  'A3 Bash suite asserts all nine canonical targets' \
  tests/compatibility-byte-identical.tests.sh "${inventory[@]}"
assert_contains_all \
  'A3 PowerShell suite asserts all nine canonical targets' \
  tests/compatibility-byte-identical.tests.ps1 "${inventory[@]}"

assert_contains_all \
  'A4 Bash suite carries all six CLI cells and reads both live contracts' \
  tests/compatibility-byte-identical.tests.sh \
  'none|present' 'none|absent' '--full|present' '--full|absent' \
  '--lite|present' '--lite|absent' \
  'plugins/sdd-ship/skills/ship/SKILL.md' 'PLUGIN-CONTRACTS.md'
assert_contains_all \
  'A4 PowerShell suite carries all six CLI cells and reads both live contracts' \
  tests/compatibility-byte-identical.tests.ps1 \
  'none|present' 'none|absent' '--full|present' '--full|absent' \
  '--lite|present' '--lite|absent' \
  'plugins/sdd-ship/skills/ship/SKILL.md' 'PLUGIN-CONTRACTS.md'

assert_contains_all \
  'A5 Bash suite includes a one-byte negative self-check' \
  tests/compatibility-byte-identical.tests.sh \
  'manifest sha256' 'negative self-check'
assert_contains_all \
  'A5 PowerShell suite includes a one-byte negative self-check' \
  tests/compatibility-byte-identical.tests.ps1 \
  'manifest sha256' 'negative self-check'

for twin in \
  tests/install.tests.sh tests/install.tests.ps1 \
  tests/uninstall.tests.sh tests/uninstall.tests.ps1; do
  assert_contains_all \
    "A6 $twin has the T-003 context-presence invariant" \
    "$twin" 'T-003 context-presence invariant' 'build_fixture'
done

assert_contains_all \
  'A7 Bash aggregate runner directly registers the suite' \
  tests/run-all.sh 'tests/compatibility-byte-identical.tests.sh'
assert_contains_all \
  'A7 PowerShell aggregate runner directly registers the suite' \
  tests/run-all.ps1 'tests/compatibility-byte-identical.tests.ps1'

if python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = json.loads((root / "specs/epic-195-a7-compatibility/verification/golden-baseline/canonical/manifest.json").read_text(encoding="utf-8"))
target = next(item for item in manifest["targets"] if item["name"] == "generated-directory-listing")
assert target["capture_format"] == "filesystem manifest"
PY
then
  pass 'A8 generated-directory-listing capture_format matches the frozen inventory'
else
  fail 'A8 generated-directory-listing capture_format matches the frozen inventory'
fi

if [[ -x "$ROOT/tests/compatibility-byte-identical.tests.sh" ]]; then
  if (cd "$ROOT" && bash tests/compatibility-byte-identical.tests.sh); then
    pass 'A9 Bash compatibility suite is GREEN'
  else
    fail 'A9 Bash compatibility suite is GREEN'
  fi
else
  fail 'A9 Bash compatibility suite is GREEN (suite is absent or not executable)'
fi

if [[ -f "$ROOT/tests/compatibility-byte-identical.tests.ps1" ]] && command -v pwsh >/dev/null 2>&1; then
  if (cd "$ROOT" && pwsh -NoProfile -File tests/compatibility-byte-identical.tests.ps1); then
    pass 'A9 PowerShell compatibility suite is GREEN'
  else
    fail 'A9 PowerShell compatibility suite is GREEN'
  fi
else
  fail 'A9 PowerShell compatibility suite is GREEN (suite or pwsh is absent)'
fi

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
