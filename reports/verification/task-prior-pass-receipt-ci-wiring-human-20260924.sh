#!/usr/bin/env bash
set -euo pipefail

repo="${TASK_RECEIPT_REPO:-$(pwd -P)}"
source="${TASK_RECEIPT_SOURCE_ROOT:-$repo}"
patch="$source/reports/verification/task-prior-pass-receipt-ci-wiring-candidate-20260924.patch"
[[ "${TASK_RECEIPT_APPLY:-}" == 1 ]] || {
  printf 'Refusing protected-file apply; set TASK_RECEIPT_APPLY=1\n' >&2
  exit 2
}
[[ -f "$patch" ]] || { printf 'candidate patch missing: %s\n' "$patch" >&2; exit 2; }

cd "$repo"
expected_run_all_sh='8d0ff443973b9cf6836c55b6f49eef633bb3ec500cffe3e5e0270e3d94deb3c4'
expected_run_all_ps1='6865172c96ad890fbce4de83555cb738f3720912e7ad198291d0287463c8d079'
expected_workflow='dc0cc24c18c7edda87c7591f4cc1f0938ea10c5c6788eeb986426c168141d2b0'
for pair in \
  "tests/run-all.sh:$expected_run_all_sh" \
  "tests/run-all.ps1:$expected_run_all_ps1" \
  ".github/workflows/test.yml:$expected_workflow"; do
  file="${pair%%:*}"; expected="${pair##*:}"
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    printf 'protected target changed: %s (expected %s, got %s)\n' "$file" "$expected" "$actual" >&2
    exit 2
  }
done
git diff --quiet -- tests/run-all.sh tests/run-all.ps1 .github/workflows/test.yml || {
  printf 'protected targets are dirty; aborting\n' >&2
  exit 2
}

backup="$(mktemp -d "${TMPDIR:-/tmp}/sdd-task-receipt-ci.XXXXXX")"
cp tests/run-all.sh "$backup/run-all.sh"
cp tests/run-all.ps1 "$backup/run-all.ps1"
cp .github/workflows/test.yml "$backup/test.yml"
restore() {
  cp "$backup/run-all.sh" tests/run-all.sh
  cp "$backup/run-all.ps1" tests/run-all.ps1
  cp "$backup/test.yml" .github/workflows/test.yml
}
trap restore ERR

git apply --check "$patch"
git apply "$patch"
bash -n tests/run-all.sh
pwsh -NoProfile -NonInteractive -Command '$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile("tests/run-all.ps1",[ref]$tokens,[ref]$errors)|Out-Null;if($errors.Count -gt 0){$errors|ForEach-Object Message;exit 1}'
bash tests/task-prior-pass-receipt.tests.sh
pwsh -NoProfile -NonInteractive -File tests/task-prior-pass-receipt.tests.ps1
git diff --check -- tests/run-all.sh tests/run-all.ps1 .github/workflows/test.yml
trap - ERR
printf 'Applied T-002 CI wiring. Backup: %s\n' "$backup"
printf 'New hashes:\n'
shasum -a 256 tests/run-all.sh tests/run-all.ps1 .github/workflows/test.yml
printf 'No commit/push/merge performed.\n'
