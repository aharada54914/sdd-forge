#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -P)"

prove_assertion() {
  local name=$1 mutation=$2 rc
  shift 2

  if [[ "${T003_PROOF_PHASE:-all}" != restore ]]; then
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
  fi

  if [[ "${T003_PROOF_PHASE:-all}" != mutate ]]; then
    printf 'RESTORE %s / GREEN\n' "$name"
    "$@"
  fi
}

requested() {
  local candidate=$1 requested_name
  if [[ $# -eq 1 && ${#REQUESTED[@]} -eq 0 ]]; then
    return 0
  fi
  for requested_name in "${REQUESTED[@]}"; do
    [[ "$requested_name" == "$candidate" ]] && return 0
  done
  return 1
}

REQUESTED=("$@")
case "${T003_PROOF_PHASE:-all}" in
  all|mutate|restore) ;;
  *) printf 'invalid T003_PROOF_PHASE: %s\n' "$T003_PROOF_PHASE" >&2; exit 2 ;;
esac
proof_count=0
if requested install-sh; then
  prove_assertion install-sh install-sh bash "$ROOT/tests/install.tests.sh"
  proof_count=$((proof_count + 1))
fi
if requested install-ps1; then
  prove_assertion install-ps1 install-ps1 pwsh -NoProfile -File "$ROOT/tests/install.tests.ps1"
  proof_count=$((proof_count + 1))
fi
if requested uninstall-sh; then
  prove_assertion uninstall-sh uninstall-sh bash "$ROOT/tests/uninstall.tests.sh"
  proof_count=$((proof_count + 1))
fi
if requested uninstall-ps1; then
  prove_assertion uninstall-ps1 uninstall-ps1 pwsh -NoProfile -File "$ROOT/tests/uninstall.tests.ps1"
  proof_count=$((proof_count + 1))
fi
if [[ $proof_count -eq 0 ]]; then
  printf 'no matching context-invariant assertions requested\n' >&2
  exit 2
fi
printf 'context invariant mutation proof complete: %d assertion(s)\n' "$proof_count"
