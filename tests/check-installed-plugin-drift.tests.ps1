[CmdletBinding()]
param([string]$Checker)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($Checker)) {
    $Checker = Join-Path $scriptDir "../plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.ps1"
}

& python3 (Join-Path $scriptDir "fixtures/installed-plugin-drift/fixture_driver.py") `
    --runtime ps1 --checker $Checker
exit $LASTEXITCODE
