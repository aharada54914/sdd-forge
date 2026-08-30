# Acceptance driver for REQ-004 (TEST-018 through TEST-021).
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$python = Get-Command python3 -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command python -ErrorAction Stop
}

& $python.Source (Join-Path $root 'tests/fixtures/path-lineending-regression/run_matrix.py')
if ($LASTEXITCODE -cne 0) {
    exit $LASTEXITCODE
}
exit 0
