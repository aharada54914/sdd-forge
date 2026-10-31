#!/usr/bin/env bash
# Human-only application of two pinned T-001 evidence-alignment patches.
# --check is read-only; agents must not invoke --apply after a protected-hook refusal.
set -euo pipefail
cd -- "$(dirname -- "$0")/../.."
mode=${1:---check}
[[ $# -le 1 && ( $mode == --check || $mode == --apply ) ]] || exit 2
labels=reports/verification/issue290-t001-test-id-labels-20261002.patch
path=reports/verification/issue290-t001-done-when-path.patch
check_hashes() {
  printf '%s\n' \
    "b77e3775395d7827cbd3ed8078994dd6c3aa764cfaf1af75c00ba76dd8ad5eaf  $labels" \
    "a57210abad923cf21117d1a96e8bc2e8dd70146e0885aa6f686db4195c8616f8  $path" \
    'ff9aed33cfa41026be40fba8c46f882aaa3fe870cc1b4b276a24ded17a37b2f3  tests/validate-approval-sidecar.tests.sh' \
    '43960010e5e0da653486a0955cd7789951288c77b4cb9e996942dcb04b472a38  tests/validate-approval-sidecar.tests.ps1' \
    '9a23cd27e44a80042aaff74f9e6f79ca1d2ad2cc7fcc646f493dba91dfa8c5db  specs/sdd-domain-concept-test/tasks.md' |
    rtk proxy shasum -a 256 -c -
}
check_hashes
rtk proxy git apply --check "$labels" "$path"
if [[ $mode == --check ]]; then
  printf 'CHECK_OK: three protected/frozen targets unchanged; --apply is human-only.\n'
  exit 0
fi
backup=$(rtk proxy mktemp -d "${TMPDIR:-/tmp}/sdd290-t001-align.XXXXXX")
printf 'Backup: %s\n' "$backup"
rtk proxy cp -p tests/validate-approval-sidecar.tests.sh tests/validate-approval-sidecar.tests.ps1 specs/sdd-domain-concept-test/tasks.md "$backup/"
check_hashes
rtk proxy git apply "$labels" "$path"
rtk proxy git apply --reverse --check "$labels" "$path"
rtk proxy git diff --check -- tests/validate-approval-sidecar.tests.sh tests/validate-approval-sidecar.tests.ps1 specs/sdd-domain-concept-test/tasks.md
rtk proxy shasum -a 256 tests/validate-approval-sidecar.tests.sh tests/validate-approval-sidecar.tests.ps1 specs/sdd-domain-concept-test/tasks.md
rtk proxy rg -n -F 'reports/implementation/sdd-domain-concept-test/T-001.md' specs/sdd-domain-concept-test/tasks.md
printf 'Applied two pinned patches. Re-run suites and task-stage provenance review; quality gate, CI and Done remain pending. No commit/push/merge.\n'
