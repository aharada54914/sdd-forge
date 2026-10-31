#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd -P)"
workflow="$repo/.github/workflows/test.yml"
patch="$repo/reports/verification/issue137-ci-registration-candidate.patch"
expected=92e65656434259fa1c92af36badbc4e969df8369f668f5442d492b5561b15f4d
actual="$(shasum -a 256 "$workflow")"
[[ "${actual%% *}" == "$expected" ]] || { printf 'Workflow changed; no apply.\n' >&2; exit 1; }
git -C "$repo" apply --check "$patch"
git -C "$repo" apply "$patch"
git -C "$repo" diff --check -- .github/workflows/test.yml
printf 'Applied CI registration only. Commit, push and CI remain pending.\n'
