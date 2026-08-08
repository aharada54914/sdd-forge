# T-005 verification harness: replicates tests/run-all.ps1's own per-file
# loop body (verbatim mechanism -- Write-Host header, `& $powerShell -NoProfile
# -File`, $LASTEXITCODE check, failure tracking) scoped to the array's last
# three entries, so this task's own new tail entry
# (tests/design-sync-scan.tests.ps1) is exercised under run-all's exact
# invocation semantics without paying the cost of the full 38-suite array
# (QG cycle-1 correction, scan T-005 Minor: 38 counted directly from
# tests/run-all.ps1's $tests = @(...) array; a prior draft misstated this
# as ~34).
#
# QG cycle-1 correction (scan T-005 Minor): the prior text here claimed a
# full `pwsh -File tests/run-all.ps1` background run's log would be at
# `run-all-ps1-full.log` in this same directory. That run was attempted for
# real during T-005 but never reached completion in that session's window,
# and its own log was not persisted -- `run-all-ps1-full.log` does not exist
# in this directory. `standalone-ps1.log` (this task's two new entries run
# directly) and `tail-harness-ps1.log` (this harness's own scoped run,
# output below) are the decisive, real, persisted PowerShell-side evidence
# for T-005 instead; see `reports/implementation/design-sync-scan/T-005.md`
# for the corrected narrative.
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
