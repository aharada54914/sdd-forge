$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw 'task-prior-pass-receipt: Python 3 is required'
}

$test = Join-Path $PSScriptRoot 'task-prior-pass-receipt.tests.py'
& $python.Source $test
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
