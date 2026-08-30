$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$validator = if ($env:LIVE_HOST_VALIDATOR) {
    $env:LIVE_HOST_VALIDATOR
} else {
    Join-Path $root 'plugins/sdd-quality-loop/scripts/validate-live-host-proof.ps1'
}

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host 'SKIP: python3 not found; live-host proof tests not run'
    exit 0
}

$env:LIVE_HOST_VALIDATOR = $validator
# TEST-013–016 are additive acceptance cases in the shared Python driver.
# The invocation below is T-005's original TEST-026/027/028 path unchanged.
& $python.Source (Join-Path $root 'tests/fixtures/live-host-proof/run_cases.py')
exit $LASTEXITCODE
