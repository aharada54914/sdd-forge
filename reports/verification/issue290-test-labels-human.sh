#!/usr/bin/env bash
# Human-only application; default mode checks without changing targets.
set -euo pipefail
cd -- "$(dirname -- "$0")/../.."
mode=${1:---check}
[[ $# -le 1 && ( $mode == --check || $mode == --apply ) ]] || exit 2
patch=reports/verification/issue290-t001-test-id-labels-20261002.patch
check_hashes() {
  printf '%s\n' \
    "b77e3775395d7827cbd3ed8078994dd6c3aa764cfaf1af75c00ba76dd8ad5eaf  $patch" \
    'ff9aed33cfa41026be40fba8c46f882aaa3fe870cc1b4b276a24ded17a37b2f3  tests/validate-approval-sidecar.tests.sh' \
    '43960010e5e0da653486a0955cd7789951288c77b4cb9e996942dcb04b472a38  tests/validate-approval-sidecar.tests.ps1' |
    rtk proxy shasum -a 256 -c -
}
check_hashes
rtk proxy git apply --check "$patch"
if [[ $mode == --check ]]; then
  printf 'CHECK_OK: protected targets unchanged; --apply is human-only.\n'
  exit 0
fi
backup=$(rtk proxy mktemp -d "${TMPDIR:-/tmp}/sdd290-test-labels.XXXXXX")
printf 'Backup: %s\n' "$backup"
rtk proxy cp -p tests/validate-approval-sidecar.tests.sh tests/validate-approval-sidecar.tests.ps1 "$backup/"
check_hashes
rtk proxy git apply "$patch"
rtk proxy git apply --reverse --check "$patch"
rtk proxy git diff --check -- tests/validate-approval-sidecar.tests.sh tests/validate-approval-sidecar.tests.ps1
rtk proxy shasum -a 256 tests/validate-approval-sidecar.tests.sh tests/validate-approval-sidecar.tests.ps1
printf 'Applied display labels only. Tests, review, CI and merge remain pending. No commit/push/merge.\n'
