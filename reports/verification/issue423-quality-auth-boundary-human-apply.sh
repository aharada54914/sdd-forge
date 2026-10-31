#!/usr/bin/env bash
# Human-only follow-up to issue423-quality-launch-human-apply.sh.
# Do not run this from an agent executor after the protected-target refusal.
set -euo pipefail

root=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
patch=reports/verification/issue423-quality-auth-boundary-candidate.patch
expected_patch=4fa7df08eaf232e4eb010e3d5329f660b10cbd3a364370419b1a8d0fbc3666c4
mode=${1:---check}
[[ "$mode" == --check || "$mode" == --apply ]] || {
  printf 'usage: bash %s [--check|--apply]\n' "$0" >&2
  exit 2
}
cd "$root"
patch_line=$(rtk proxy shasum -a 256 "$patch")
actual_patch=${patch_line%% *}
[[ "$actual_patch" == "$expected_patch" ]] || {
  printf 'STALE_PATCH expected=%s actual=%s\n' "$expected_patch" "$actual_patch" >&2
  exit 1
}

while IFS='|' read -r path expected; do
  [[ -n "$path" ]] || continue
  actual_line=$(rtk proxy shasum -a 256 "$path")
  actual=${actual_line%% *}
  [[ "$actual" == "$expected" ]] || {
    printf 'STALE_INPUT %s expected=%s actual=%s\n' "$path" "$expected" "$actual" >&2
    exit 1
  }
done <<'INPUTS'
plugins/sdd-quality-loop/scripts/validate-review-context-set.sh|4dffb010188208a5b9a1da306f1f3807aee4ccb9511da3618089aec55e84fffd
plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1|13541b8d37f55112b76d27829f964ee9864127292abd12accdde06867d6702bf
plugins/sdd-review-loop/references/review-context-boundary.md|bf7ead454e76cba017378d99f629c5f6f219a7aa087b12fe25c47cdd38f20911
tests/issue311-scratch-isolation.tests.py|e5b42d2b89ff93195bf407c488c05371ad9e0a3b94d46751a7e3c6036f85aa07
INPUTS

rtk proxy git apply --check "$patch"
printf 'PATCH_CHECK_OK; protected targets unchanged\n'
[[ "$mode" == --apply ]] || exit 0

backup=$(rtk proxy mktemp -d "${TMPDIR:-/tmp}/issue423-auth-backup.XXXXXX")
for path in \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 \
  plugins/sdd-review-loop/references/review-context-boundary.md \
  tests/issue311-scratch-isolation.tests.py; do
  rtk proxy mkdir -p "$backup/$(dirname "$path")"
  rtk proxy cp "$path" "$backup/$path"
done
printf 'BACKUP=%s\n' "$backup"

# Only a human runs the following protected-target mutation. A refusal is final.
rtk proxy git apply "$patch"
rtk proxy git apply --reverse --check "$patch"
rtk proxy git diff --check -- \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 \
  plugins/sdd-review-loop/references/review-context-boundary.md \
  tests/issue311-scratch-isolation.tests.py
printf 'APPLIED_READBACK_OK; backup=%s\n' "$backup"
