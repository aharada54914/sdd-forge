#!/usr/bin/env bash
# Human-only candidate application. Never run this from an agent executor.
set -euo pipefail

root=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
patch=reports/verification/issue423-quality-launch-candidate.patch
expected_patch=4a41a8159274c197e4d170e448694194e74ce63a7567f40a184ca286f9ac6b38
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
plugins/sdd-quality-loop/scripts/validate-review-context-set.sh|8e5e885c026041a4059f0f5462d2c213f6072c0d8cc9e7056ee3713f48450d32
plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1|179fdb17ca1d8afa6044396ef497dd764353ea814d66c835147ceccd2909786b
plugins/sdd-quality-loop/skills/quality-gate/SKILL.md|d4b1f1d8d320c2a2b4c153e0dc7270f5979eb9ddebfcb26c73bf5c2a95fced26
plugins/sdd-review-loop/references/review-context-boundary.md|b537052a70eb52e73cd9add1ab2bb6e19f2b29796efd58bf7df2684b8bd318c1
tests/review-context-boundary.tests.sh|789c4a7b7d00b4f20f3d623784236ef0557b5d37f6cf5be8fb8eb57a4f9da6b1
tests/issue311-scratch-isolation.tests.py|355a7b99648186abd6a0c566a6b5ba58d7bd3d4e9c6c1d3c4deeffdf7e5c2248
tests/review-scratch-history.tests.py|6757aee629a1827448d912268c3e31f82d67f55080a1cac0fc862f5f7c709756
tests/review-agent-isolation.tests.sh|7f53e9c031a3d2883dc3f7a4c39a95520fbd7765fc45c2419b1022fc3335a808
INPUTS

rtk proxy git apply --check "$patch"
printf 'PATCH_CHECK_OK; protected targets unchanged\n'
[[ "$mode" == --apply ]] || exit 0

backup=$(rtk proxy mktemp -d "${TMPDIR:-/tmp}/issue423-quality-backup.XXXXXX")
for path in \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 \
  plugins/sdd-quality-loop/skills/quality-gate/SKILL.md \
  plugins/sdd-review-loop/references/review-context-boundary.md \
  tests/review-context-boundary.tests.sh \
  tests/issue311-scratch-isolation.tests.py \
  tests/review-scratch-history.tests.py \
  tests/review-agent-isolation.tests.sh; do
  rtk proxy mkdir -p "$backup/$(dirname "$path")"
  rtk proxy cp "$path" "$backup/$path"
done
printf 'BACKUP=%s\n' "$backup"

# This is intentionally the only mutating gate-target operation in this file.
# A refusal ends execution; it must not be retried with a different executor.
rtk proxy git apply "$patch"
rtk proxy git apply --reverse --check "$patch"
rtk proxy git diff --check -- \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 \
  plugins/sdd-quality-loop/skills/quality-gate/SKILL.md \
  plugins/sdd-review-loop/references/review-context-boundary.md \
  tests/review-context-boundary.tests.sh \
  tests/issue311-scratch-isolation.tests.py \
  tests/review-scratch-history.tests.py \
  tests/review-agent-isolation.tests.sh
while IFS='|' read -r path expected; do
  [[ -n "$path" ]] || continue
  actual_line=$(rtk proxy shasum -a 256 "$path")
  actual=${actual_line%% *}
  [[ "$actual" == "$expected" ]] || {
    printf 'READBACK_MISMATCH %s expected=%s actual=%s backup=%s\n' "$path" "$expected" "$actual" "$backup" >&2
    exit 1
  }
done <<'OUTPUTS'
plugins/sdd-quality-loop/scripts/validate-review-context-set.sh|3b780687498ce40f6d846934d2b05f24d994657480cbdd42d32ac2d4c0afcd5d
plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1|871c632500b047386f86576a2c7dbac6939e7eb05e92cf12df1dffebe3ee0089
plugins/sdd-quality-loop/skills/quality-gate/SKILL.md|5bc8931a755dd5c2cbc1045ca0dcdf39a5c9fe790bae6f3ffa50d1f2a6f6c9af
plugins/sdd-review-loop/references/review-context-boundary.md|360adaabc81656853b0cc2186330277a15dd74ec877d9713922f83d0a10f8652
tests/review-context-boundary.tests.sh|b50365f9db51329b39434e9835290442237e550554ee934caac8d5151f066d71
tests/issue311-scratch-isolation.tests.py|aebf09c0163a5ff62e320b357551fb24e6d859442fe3e8b7c6d43883cd5bdd9f
tests/review-scratch-history.tests.py|24dd3afc8139ae55f04df97ec42da9ae812da829bf28b54baf828591595cd0d0
tests/review-agent-isolation.tests.sh|7f8d15c2c95aafe4cfa5e812fb2f10c431d775ef0d35aecc72946e932f60c1b9
OUTPUTS
printf 'APPLIED_READBACK_OK; backup=%s\n' "$backup"
printf 'Run the separately supplied reserve-negative fixture before any gate launch.\n'
