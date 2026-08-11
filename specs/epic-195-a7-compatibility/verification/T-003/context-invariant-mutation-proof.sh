#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"

prove_assertion() {
  local name=$1 mutation=$2 rc
  shift 2

  printf 'MUTATE %s\n' "$name"
  set +e
  T003_MUTATE_CONTEXT_INVARIANT="$mutation" "$@"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    printf 'FAIL: mutation survived: %s\n' "$name"
    return 1
  fi
  printf 'EXPECTED RED: %s (exit %d)\n' "$name" "$rc"

  printf 'RESTORE %s / GREEN\n' "$name"
  "$@"
}

prove_assertion install-sh install-sh bash "$ROOT/tests/install.tests.sh"
prove_assertion install-ps1 install-ps1 pwsh -NoProfile -File "$ROOT/tests/install.tests.ps1"
prove_assertion uninstall-sh uninstall-sh bash "$ROOT/tests/uninstall.tests.sh"
prove_assertion uninstall-ps1 uninstall-ps1 pwsh -NoProfile -File "$ROOT/tests/uninstall.tests.ps1"
printf 'context invariant mutation proof complete: 4 assertions\n'
