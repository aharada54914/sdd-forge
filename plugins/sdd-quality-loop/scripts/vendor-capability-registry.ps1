# Thin argument-forwarding wrapper for vendor-capability-registry.py
# (Python master). INV-014 (the sdd-hook-guard.sh pattern).
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$pyScript = Join-Path $scriptDir 'vendor-capability-registry.py'

$pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $pythonCmd) { $pythonCmd = Get-Command python -ErrorAction SilentlyContinue }
if (-not $pythonCmd) {
  Write-Error "vendor-capability-registry: python3 (or python) is required"
  exit 1
}

& $pythonCmd.Source $pyScript @args
exit $LASTEXITCODE
