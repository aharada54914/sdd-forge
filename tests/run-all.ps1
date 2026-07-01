# Run the local, deterministic PowerShell regression suite in CI order.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$powerShell = (Get-Process -Id $PID).Path
$tests = @(
    'tests/validate-repository.ps1',
    'tests/scripts.tests.ps1',
    'tests/review-contract-foundation.tests.ps1',
    'tests/task-context-isolation.tests.ps1',
    'tests/downstream-review-precheck.tests.ps1',
    'tests/impl-layer-review-inputs.tests.ps1',
    'tests/task-layer-review-inputs.tests.ps1',
    'tests/cross-model.tests.ps1',
    'tests/hooks.tests.ps1',
    'tests/scenario.tests.ps1',
    'tests/install.tests.ps1',
    'tests/uninstall.tests.ps1',
    'tests/claude-registration.tests.ps1',
    'tests/workflow-state-registry.tests.ps1',
    'tests/workflow-state.tests.ps1',
    'tests/workflow-state-repository-integration.tests.ps1',
    'tests/structure-check-feature-mode.tests.ps1'
)

Push-Location $root
try {
    foreach ($testFile in $tests) {
        Write-Host "==> $testFile"
        & $powerShell -NoProfile -File (Join-Path $root $testFile)
        if ($LASTEXITCODE -ne 0) {
            throw "$testFile failed with exit code $LASTEXITCODE"
        }
    }
} finally {
    Pop-Location
}

Write-Host 'All PowerShell regression tests passed.'
exit 0
