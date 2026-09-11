#!/usr/bin/env bash
# Human-run only: restores two stale mirror files; never changes live guards.
set -euo pipefail
repo=/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
cd "$repo"
test "$(git rev-parse HEAD)" = 3971c93a5705dc15f86ba56cc62118613e4b19db
candidate=specs/epic-190-a2-capability-registry/drafts/human-copy-candidate
mirror=specs/epic-190-a2-capability-registry/human-copy
assert_hash() {
  local actual
  actual=$(shasum -a 256 "$1")
  test "${actual%% *}" = "$2" || { printf 'Hash mismatch: %s\n' "$1" >&2; exit 1; }
}
assert_hash "$candidate/MANIFEST.sha256.candidate" cb7eb6800d988664e934bda35e62ce62efc421dc518a226bed66377d02be5025
assert_hash "$mirror/MANIFEST.sha256" 233d45811a8d52395bfe30f82d2b9ccaf3ff709474b8e37fbea5e1a416948ee7
assert_hash "$mirror/.github/workflows/test.yml" d1f171ee0c92ee60892922c5b58dfc80a6267d61e41959df0a2aaacb4515f0a4
count=0
while read -r expected rel; do
  assert_hash "$candidate/$rel.candidate" "$expected"
  cmp "$candidate/$rel.candidate" "$rel"
  if test "$rel" != .github/workflows/test.yml; then
    cmp "$candidate/$rel.candidate" "$mirror/$rel"
  fi
  count=$((count + 1))
done < "$candidate/MANIFEST.sha256.candidate"
test "$count" -eq 7
backup=$(mktemp -d /Users/jrmag/.local/share/pr381-mirror-backup.XXXXXX)
cp "$mirror/.github/workflows/test.yml" "$backup/test.yml"
cp "$mirror/MANIFEST.sha256" "$backup/MANIFEST.sha256"
printf 'Backup: %s\n' "$backup"
cp "$candidate/.github/workflows/test.yml.candidate" "$mirror/.github/workflows/test.yml"
cp "$candidate/MANIFEST.sha256.candidate" "$mirror/MANIFEST.sha256"
while read -r expected rel; do
  assert_hash "$mirror/$rel" "$expected"
done < "$mirror/MANIFEST.sha256"
python3 plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check
bash tests/generate-gate-capabilities.tests.sh
pwsh -NoProfile -File tests/generate-gate-capabilities.tests.ps1
git diff --check
printf 'Applied and verified. Send this output to Codex. No commit/push/merge was performed.\n'
