#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t004-depth1.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

git clone --quiet --depth 1 "file://$ROOT" "$WORK/repo"
rsync -a --exclude '.git' "$ROOT/" "$WORK/repo/"
printf 'SHALLOW: %s depth=%s\n' \
  "$(git -C "$WORK/repo" rev-parse --is-shallow-repository)" \
  "$(git -C "$WORK/repo" rev-list --count HEAD)"

run_sh() { STRUCTURAL_COMPAT_REPO_ROOT="$WORK/repo" bash "$WORK/repo/tests/structural-compatibility.tests.sh"; }
run_ps() { STRUCTURAL_COMPAT_REPO_ROOT="$WORK/repo" pwsh -NoProfile -File "$WORK/repo/tests/structural-compatibility.tests.ps1"; }

run_sh
run_ps
corpus="$WORK/repo/tests/fixtures/structural-fixture-corpus/f1-full.json"
cp "$corpus" "$corpus.clean"
jq '.schema += "/depth1-mutation"' "$corpus.clean" > "$corpus"
if run_sh >/dev/null 2>&1; then
  printf '%s\n' 'MUTATION-SURVIVED: Bash accepted the depth-1 corpus mutation' >&2
  exit 1
fi
printf '%s\n' 'MUTATION-KILLED: Bash rejected the depth-1 corpus mutation'
if run_ps >/dev/null 2>&1; then
  printf '%s\n' 'MUTATION-SURVIVED: PowerShell accepted the depth-1 corpus mutation' >&2
  exit 1
fi
printf '%s\n' 'MUTATION-KILLED: PowerShell rejected the depth-1 corpus mutation'
mv "$corpus.clean" "$corpus"
run_sh
run_ps
printf '%s\n' 'RESTORE-GREEN: both runtimes pass in a real depth-1 clone'
