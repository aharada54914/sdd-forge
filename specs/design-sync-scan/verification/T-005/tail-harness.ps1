# T-005 verification harness: replicates tests/run-all.ps1's own per-file
# loop body (verbatim mechanism -- Write-Host header, `& $powerShell -NoProfile
# -File`, $LASTEXITCODE check, failure tracking) scoped to the array's last
# three entries, so this task's own new tail entry
# (tests/design-sync-scan.tests.ps1) is exercised under run-all's exact
# invocation semantics without paying the cost of the full ~34-suite array.
# This is supporting, in-scope evidence; the full
# `pwsh -File tests/run-all.ps1` background run (see run-all-ps1-full.log in
# this same directory) is the primary, real end-to-end evidence per the
# Done-When item's "exercise for real" branch.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$powerShell = (Get-Process -Id $PID).Path
$tests = @(
    'tests/design-system-contract.tests.ps1',
    'tests/design-sync-standing-consent.tests.ps1',
    'tests/design-sync-scan.tests.ps1'
)

$failed = @()

Push-Location $root
try {
    foreach ($testFile in $tests) {
        Write-Host "==> $testFile"
        & $powerShell -NoProfile -File (Join-Path $root $testFile)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAILED: $testFile (exit code $LASTEXITCODE)"
            $failed += $testFile
        }
    }
} finally {
    Pop-Location
}

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host "$($failed.Count) failing suite(s):"
    foreach ($failedTest in $failed) {
        Write-Host "  $failedTest"
    }
    exit 1
}

Write-Host 'Tail-harness: all scoped suites passed.'
exit 0
