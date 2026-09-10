#!/usr/bin/env bash
# Human-only application. Do not run this helper through an agent executor.
set -euo pipefail
cd /Users/jrmag/sdd-forge
patch=reports/verification/rt004-posix-root-candidate-20260910.patch
bash_file=plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
pwsh_file=plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
rtk proxy shasum -a 256 -c <<'HASHES'
2b81bc746e059a0b287052f7c1054dbc739f219e1151f3a42aa46c0d0ab237dd  reports/verification/rt004-posix-root-candidate-20260910.patch
04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
977fd6ac16e4f2b37e11dcd42178b69a2b81addd2fba43483447171927c7ec8e  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
HASHES
rtk proxy git apply --check --unidiff-zero "$patch"
backup=$(rtk proxy mktemp -d /tmp/sdd-rt004-posix-root.XXXXXX)
printf 'バックアップ: %s\n' "$backup"
rtk proxy cp -p "$bash_file" "$backup/validate-review-context-set.sh"
rtk proxy cp -p "$pwsh_file" "$backup/validate-review-context-set.ps1"
rtk proxy cp -p "$patch" "$backup/applied.patch"
rtk proxy git apply --unidiff-zero "$patch"
rtk proxy git diff --check -- "$bash_file" "$pwsh_file"
rtk proxy shasum -a 256 "$bash_file" "$pwsh_file"
printf '\nルート表記の限定修正を適用しました。出力をCodexへ送ってください。\n'
printf 'テスト・正式レビュー・CI・main統合は未完了。commit/push/mergeは未実行です。\n'
