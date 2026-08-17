# Thin argument-forwarding wrapper for evaluate-predicate.py (Python master).
# INV-014 (the sdd-hook-guard.sh pattern): all evaluation logic lives in the
# Python master; this wrapper only locates it and forwards arguments as-is.
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$pyScript = Join-Path $scriptDir 'evaluate-predicate.py'

$pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $pythonCmd) { $pythonCmd = Get-Command python -ErrorAction SilentlyContinue }
if (-not $pythonCmd) {
  Write-Error "evaluate-predicate: python3 (or python) is required"
  exit 1
}

& $pythonCmd.Source $pyScript @args
exit $LASTEXITCODE
