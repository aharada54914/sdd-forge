# T-005 (epic-193-a5): PowerShell twin for resolve-project-context-match,
# the full match/no-match/conditional/WARN fixture matrix (design.md Test
# Strategy item 3).
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Python) { $Python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $Python) {
  Write-Output 'FAIL: no python3/python interpreter available'
  exit 1
}
& $Python.Source (Join-Path $Root 'tests/resolve-project-context-match-check.py') --launcher ps1
exit $LASTEXITCODE
