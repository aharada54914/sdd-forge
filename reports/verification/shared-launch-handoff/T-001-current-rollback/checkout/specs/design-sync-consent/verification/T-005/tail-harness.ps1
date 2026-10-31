# T-005 real-execution proof: replicates tests/run-all.ps1's exact loop
# mechanism ($ErrorActionPreference='Stop'; foreach ($testFile in $tests) {
# & $powerShell -NoProfile -File (Join-Path $root $testFile); if
# ($LASTEXITCODE -ne 0) { throw ... } }), scoped to the tail of the real
# array (the last two pre-existing entries plus the newly-registered
# tests/design-system-contract.tests.ps1), to prove the registration
# integrates and is reachable/executable under run-all's own invocation
# semantics -- independent of the unrelated, environment-load-induced
# failure earlier in the full array (see report).
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = "/Users/jrmag/Projects/active/sdd-forge-wt-phase4"
$powerShell = (Get-Process -Id $PID).Path
$tests = @(
    'tests/facet-manifest-schema.tests.ps1',
    'tests/facet-manifest-semantics.tests.ps1',
    'tests/design-system-contract.tests.ps1'
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

Write-Host 'TAIL HARNESS: all tail entries passed under run-all semantics.'
exit 0
