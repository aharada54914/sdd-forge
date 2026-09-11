#!/usr/bin/env bash
# Human application only. Do not invoke through an agent after guard denial.
set -euo pipefail
cd /Users/jrmag/sdd-forge
bash_target=plugins/sdd-review-loop/scripts/impl-review-precheck.sh
pwsh_target=plugins/sdd-review-loop/scripts/impl-review-precheck.ps1
bash_patch=reports/verification/adr-precheck-generation-candidate-20260909.patch
pwsh_patch=reports/verification/adr-precheck-powershell-generation-candidate-20260909.patch
command -v pwsh >/dev/null
for target in "$bash_target" "$pwsh_target" "$bash_patch" "$pwsh_patch"; do
  [[ -f "$target" && ! -L "$target" ]] || { printf 'Unsafe or missing file: %s\n' "$target" >&2; exit 1; }
done
printf '%s  %s\n' \
  54f33432a04937653a0377107e4862d83ed09d34c0bb1c0dc83419bcb0ad2b14 "$bash_target" \
  434beb369fede2cdf6648ac8bd4c535b1bfec6780eb69842761b8be2087d164f "$pwsh_target" \
  a20fd24a8dc305688e858af84fdd5075f5038ead197072308a252605f8f0a0c9 "$bash_patch" \
  c9a6ad63345c3c3247ccf2fec89afbc4d4d8176f160c8ab8e3b51fa72b323f64 "$pwsh_patch" | shasum -a 256 -c -
git apply --check --unidiff-zero "$bash_patch" "$pwsh_patch"
backup=$(mktemp -d /tmp/sdd-rt004-producer.XXXXXX) || exit 1
printf 'Backup: %s\n' "$backup"
cp -p "$bash_target" "$backup/impl-review-precheck.sh"
cp -p "$pwsh_target" "$backup/impl-review-precheck.ps1"
cp -p "$bash_patch" "$pwsh_patch" "$backup/"
git apply --unidiff-zero "$bash_patch" "$pwsh_patch"
bash -n "$bash_target"
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) "plugins/sdd-review-loop/scripts/impl-review-precheck.ps1"),[ref]$tokens,[ref]$errors); if ($errors.Count) { $errors; exit 1 }; "PowerShell syntax: OK"'
git diff --check -- "$bash_target" "$pwsh_target"
shasum -a 256 "$bash_target" "$pwsh_target"
printf '\n生成処理2ファイルの適用・構文確認が完了しました。出力をCodexへ送ってください。\n'
printf '回帰テスト・正式レビュー・CI・main統合は未完了。commit/push/mergeはしていません。\n'
