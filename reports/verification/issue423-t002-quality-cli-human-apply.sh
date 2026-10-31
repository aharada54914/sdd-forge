#!/usr/bin/env bash
# Human-only application of the independently reviewed, one-target CLI repair.
# Agents may run --check only. A protected-write refusal ends the operation.
set -euo pipefail

root=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
target=plugins/sdd-quality-loop/skills/quality-gate/SKILL.md
patch=reports/verification/issue423-t002-quality-cli-invocation-v2.patch
expected_head=3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9
expected_before=d0326f3617f0bf6de6ba7f99d7edc2388c79a6731866328133cff7bb1815b722
expected_patch=d912562f629b87fd9eb9d5502df460adbd25a5d44094544fc52a932de8eaf5bd
expected_after=2fdd7ff9d837eacc15ef948fa4fb7334ef58250b4e52f75edc022c4e46235033
mode=${1:---check}

[[ "$mode" == --check || "$mode" == --apply-human ]] || {
  printf 'usage: bash %s [--check|--apply-human]\n' "$0" >&2
  exit 2
}
[[ "$(pwd -P)" == "$root" ]] || { printf 'STOP: wrong owner checkout\n' >&2; exit 1; }
[[ -f "$target" && ! -L "$target" && -f "$patch" && ! -L "$patch" ]] || {
  printf 'STOP: missing or redirected input\n' >&2; exit 1;
}

sha() { rtk proxy shasum -a 256 "$1" | awk '{print $1}'; }
[[ "$(rtk proxy git rev-parse HEAD)" == "$expected_head" ]] || {
  printf 'STOP: HEAD mismatch\n' >&2; exit 1;
}
[[ "$(sha "$target")" == "$expected_before" ]] || {
  printf 'STOP: target preimage mismatch or already applied\n' >&2; exit 1;
}
[[ "$(sha "$patch")" == "$expected_patch" ]] || {
  printf 'STOP: patch hash mismatch\n' >&2; exit 1;
}
rtk proxy git apply --check "$patch"
candidate_hash=$(rtk proxy patch --output=- --input="$patch" "$target" | rtk proxy shasum -a 256 | awk '{print $1}')
[[ "$candidate_hash" == "$expected_after" ]] || {
  printf 'STOP: candidate postimage mismatch\n' >&2; exit 1;
}
printf 'CHECK_OK head=%s before=%s patch=%s after=%s\n' \
  "$expected_head" "$expected_before" "$expected_patch" "$expected_after"
[[ "$mode" == --apply-human ]] || exit 0

# Only a human may invoke this mode from the approved owner context.
backup=$(rtk proxy mktemp -d "${TMPDIR:-/tmp}/issue423-quality-cli-backup.XXXXXX")
rtk proxy cp "$target" "$backup/SKILL.md"
[[ "$(sha "$backup/SKILL.md")" == "$expected_before" ]] || {
  printf 'STOP: backup mismatch; retain %s\n' "$backup" >&2; exit 1;
}
[[ "$(sha "$target")" == "$expected_before" ]] || {
  printf 'STOP: source changed before apply; retain %s\n' "$backup" >&2; exit 1;
}
printf 'BACKUP=%s\n' "$backup"
rtk proxy git apply "$patch"
[[ "$(sha "$target")" == "$expected_after" ]] || {
  printf 'STOP: readback mismatch; retain %s\n' "$backup" >&2; exit 1;
}
rtk proxy git apply --reverse --check "$patch"
printf 'APPLIED_READBACK_OK %s %s backup=%s\n' "$target" "$expected_after" "$backup"
printf 'Application only; independent native evaluation and exact-head CI remain pending.\n'
