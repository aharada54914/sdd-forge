$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw 'a9-dogfood: Python 3 is required'
}

$test = Join-Path $PSScriptRoot 'a9-dogfood.tests.py'
& $python.Source $test
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $python.Source (Join-Path $PSScriptRoot 'a9-advisory-evidence.tests.py')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $python.Source (Join-Path $PSScriptRoot 'a9-rollback-receipt.tests.py')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
