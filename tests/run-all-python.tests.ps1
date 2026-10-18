# Exercise the shared runner's registration, missing runtime and failure behavior.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Verification requires python3 or python.' }
& $python.Source -B (Join-Path $PSScriptRoot 'verification-catalog.tests.py')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$hostPath = (Get-Process -Id $PID).Path
$listed = @(& $hostPath -NoProfile -File (Join-Path $PSScriptRoot 'run-all.ps1') -List)
if ($LASTEXITCODE -ne 0) { throw 'PowerShell catalog listing failed.' }
$catalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'verification-catalog.json') -Raw | ConvertFrom-Json
if (($listed -join "`n") -cne ($catalog.profiles.'local-powershell' -join "`n")) {
    throw 'PowerShell launcher changed the catalog selection.'
}
Write-Host 'PASS: native PowerShell launcher listing and shared runner behavior'
