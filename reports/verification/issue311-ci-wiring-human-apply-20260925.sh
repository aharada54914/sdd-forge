#!/usr/bin/env bash
set -euo pipefail

# Human-only apply: the SDD hook protects these runner/workflow files.
repo="${ISSUE311_REPO:-$(pwd -P)}"
source="${ISSUE311_SOURCE_ROOT:-$repo}"
patch="$source/reports/verification/issue311-ci-wiring-candidate-20260925-v2.patch"
[[ "${ISSUE311_APPLY:-}" == 1 ]] || { printf 'Refusing protected-file apply; set ISSUE311_APPLY=1\n' >&2; exit 2; }
[[ -f "$patch" ]] || { printf 'candidate patch missing: %s\n' "$patch" >&2; exit 2; }
cd "$repo"
git diff --quiet -- tests/run-all.sh .github/workflows/test.yml || { printf 'target files are dirty; aborting\n' >&2; exit 2; }
git apply --check "$patch"
git apply "$patch"
bash -n tests/run-all.sh
python3 tests/issue311-scratch-isolation.tests.py --repo "$repo"
printf 'issue311 CI wiring applied and 28-case regression passed\n'
