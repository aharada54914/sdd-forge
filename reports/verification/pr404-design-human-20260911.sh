#!/usr/bin/env bash
# HUMAN ONLY: apply the reviewed, hash-pinned three-document amendment.
set -euo pipefail
repo=/Users/jrmag/.local/share/sdd-forge-pr404-current-20260911
cd "$repo"
patch=reports/verification/pr404-design-amendment-candidate-20260911.patch
check_hash() {
  local expected=$1 file=$2 actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || { printf 'STOP: hash mismatch: %s\n' "$file" >&2; exit 1; }
}
check_hash 0e144638e05d127664b9eef878d4871f50af3bb720aeb2b9a0ef8cebb1a75ca3 "$patch"
check_hash f4cbe691e6f11d8ae1424285007c1110e817ed677925591bd04725eb7187fc29 specs/epic-195-a7-compatibility/design.md
check_hash 4b31d724cd326ee89b87de867e0f857cf2b7ca69d794956ebb7ce4edc6ff8d31 specs/epic-195-a7-compatibility/security-spec.md
check_hash a62bd5d421590fed03945fa12826d29ab9450bf4ccc8e20f4dff319e9433b96c specs/epic-195-a7-compatibility/infra-spec.md
git diff --quiet -- specs/epic-195-a7-compatibility/design.md specs/epic-195-a7-compatibility/security-spec.md specs/epic-195-a7-compatibility/infra-spec.md
git diff --cached --quiet -- specs/epic-195-a7-compatibility/design.md specs/epic-195-a7-compatibility/security-spec.md specs/epic-195-a7-compatibility/infra-spec.md
git apply --check "$patch"
backup="$(mktemp -d "${TMPDIR:-/tmp}/sdd-pr404-design.XXXXXX")"
for name in design.md security-spec.md infra-spec.md; do
  cp "specs/epic-195-a7-compatibility/$name" "$backup/$name"
done
printf 'Backup: %s\n' "$backup"
git apply "$patch"
git diff --check
git diff --stat -- specs/epic-195-a7-compatibility/design.md specs/epic-195-a7-compatibility/security-spec.md specs/epic-195-a7-compatibility/infra-spec.md
shasum -a 256 specs/epic-195-a7-compatibility/design.md specs/epic-195-a7-compatibility/security-spec.md specs/epic-195-a7-compatibility/infra-spec.md
printf '\nApplied three documents only. Send this output to Codex. No commit/push/merge or review-status changes performed.\n'
