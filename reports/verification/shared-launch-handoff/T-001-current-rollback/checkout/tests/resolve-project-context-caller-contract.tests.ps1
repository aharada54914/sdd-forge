$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) { throw 'FAIL: no python3/python interpreter available' }
& $python.Source (Join-Path $root 'tests/resolve-project-context-caller-contract-check.py') --launcher ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
