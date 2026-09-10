#!/usr/bin/env bash
# Human-only application; an actual protected edit was denied.
set -euo pipefail
cd /Users/jrmag/sdd-forge
target=plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
candidate=reports/verification/rt004-adr-binding-pwsh-20260911.patch
printf '%s  %s\n' \
  af3537e3b54ed6b9a85d79cdac19c995f8f6d504f874d5a031a8e42c8cdb0438 "$target" \
  4f0add61f1303b74863557419af3c28ae9981e0ce8cbe0406060cfef3befc157 "$candidate" | shasum -a 256 -c -
command -v pwsh
git apply --recount --check "$candidate"
backup=$(mktemp -d /tmp/sdd-rt004-adr-pwsh.XXXXXX)
printf 'Backup: %s\n' "$backup"
cp -p "$target" "$backup/validate-review-context-set.ps1"
cp -p "$candidate" "$backup/candidate.patch"
git apply --recount "$candidate"
pwsh -NoProfile -Command '$t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"),[ref]$t,[ref]$e); if ($e.Count) { $e; exit 1 }; "PowerShell syntax: OK"'
git diff --check -- "$target"
shasum -a 256 "$target"
printf '\nPowerShell修正の適用・構文確認のみ完了。出力をCodexへ送ってください。\n'
printf '回帰テスト・正式レビュー・CI・main統合は未完了。commit/push/mergeはしていません。\n'
