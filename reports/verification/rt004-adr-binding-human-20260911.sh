#!/usr/bin/env bash
# Human-only application after independent RT004 advisory review.
set -euo pipefail
cd /Users/jrmag/sdd-forge
target=plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
candidate=reports/verification/rt004-adr-binding-bash-20260911.patch
target_sha=978368b883231a02817b948c784b938b28d1c313e7420521939d52ec77a759e7
candidate_sha=82c5756b479627c2aa444262d2cfca309fbfb912d4e59de7e00905a66d76e875
printf '%s  %s\n' "$target_sha" "$target" "$candidate_sha" "$candidate" |
  shasum -a 256 -c -
git apply --recount --check "$candidate"
backup=$(mktemp -d /tmp/sdd-rt004-adr-binding.XXXXXX)
printf 'Backup: %s\n' "$backup"
cp -p "$target" "$backup/validate-review-context-set.sh"
cp -p "$candidate" "$backup/candidate.patch"
git apply --recount "$candidate"
bash -n "$target"
git diff --check -- "$target"
shasum -a 256 "$target"
printf '\nBash修正の適用・構文確認のみ完了。出力をCodexへ送ってください。\n'
printf '回帰テスト・正式レビュー・CI・main統合は未完了。commit/push/mergeはしていません。\n'
