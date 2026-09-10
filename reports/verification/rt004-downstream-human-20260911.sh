#!/usr/bin/env bash
# Human application only; never invoke through an agent after guard denial.
set -euo pipefail
cd /Users/jrmag/sdd-forge
bash_target=plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh
pwsh_target=plugins/sdd-review-loop/scripts/task-review-precheck.ps1
bash_patch=reports/verification/adr-persisted-bash-candidate-20260909.patch
pwsh_patch=reports/verification/adr-persisted-powershell-candidate-20260909.patch
command -v pwsh >/dev/null
for target in "$bash_target" "$pwsh_target" "$bash_patch" "$pwsh_patch"; do
  [[ -f "$target" && ! -L "$target" ]] || { printf 'Unsafe or missing file: %s\n' "$target" >&2; exit 1; }
done
printf '%s  %s\n' \
  e80233361f70a3739c65c364544ee5486ca842d3596b06355557b777885b7e20 "$bash_target" \
  1d9495dbf7a55471266e5315c83df5353400b1fd880fd7f8585ed978f6dfc536 "$pwsh_target" \
  3880a194e818f7c24b6ac329b747fb87dbec15866f38a4a0d887a85d1be12ba6 "$bash_patch" \
  e8182f380ce64c0b1918e52aed0dae97758183660839c46838a3fc78bc995ecc "$pwsh_patch" | shasum -a 256 -c -
git apply --check --unidiff-zero "$bash_patch" "$pwsh_patch"
backup=$(mktemp -d /tmp/sdd-rt004-downstream.XXXXXX) || exit 1
printf 'Backup: %s\n' "$backup"
cp -p "$bash_target" "$backup/review-precheck-common.sh"
cp -p "$pwsh_target" "$backup/task-review-precheck.ps1"
cp -p "$bash_patch" "$pwsh_patch" "$backup/"
git apply --unidiff-zero "$bash_patch" "$pwsh_patch"
bash -n "$bash_target"
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) "plugins/sdd-review-loop/scripts/task-review-precheck.ps1"),[ref]$tokens,[ref]$errors); if ($errors.Count) { $errors; exit 1 }; "PowerShell syntax: OK"'
git diff --check -- "$bash_target" "$pwsh_target"
shasum -a 256 "$bash_target" "$pwsh_target"
printf '\n後段検証2ファイルの適用・構文確認が完了しました。出力をCodexへ送ってください。\n'
printf '回帰テスト・正式レビュー・CI・main統合は未完了。commit/push/mergeはしていません。\n'
