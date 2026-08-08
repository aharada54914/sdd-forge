# T-005 verification harness -- pwsh twin of test054-harness.sh. Proves the
# staged candidate satisfies TEST-054 (AC-028) without applying it to the
# live, protected .github/workflows/test.yml.
#
# The check function below is copied verbatim from
# tests/design-sync-standing-consent.tests.ps1's own Test-054CiRegistered
# (lines 595-605 at authoring time), parameterized by a CiDir argument
# instead of the suite's hardcoded $ciDir (Join-Path $repositoryRoot
# ".github/workflows"), so this harness exercises the SAME logic the real
# suite runs, against a scratch directory that holds only the candidate.
#
# Usage: test054-harness.ps1 -CiDir <path>
#
# param() must be the script's first statement (only comments may precede
# it) or PowerShell fails to bind named arguments -- confirmed empirically
# during this task's own authoring (a Set-StrictMode/$ErrorActionPreference
# preamble ahead of param() made -CiDir unbindable), so no shebang or
# preamble statement precedes it here.

param(
    [Parameter(Mandatory = $true)]
    [string]$CiDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TextOrEmpty([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return "" }
    try {
        return (Get-Content -Raw -Encoding Utf8 -LiteralPath $path -ErrorAction Stop)
    } catch {
        return ""
    }
}

function Test-054CiRegistered {
    if (-not (Test-Path -LiteralPath $CiDir)) { return $false }
    $hasSh = $false
    $hasPs1 = $false
    Get-ChildItem -LiteralPath $CiDir -File | Where-Object { $_.Extension -in ".yml", ".yaml" } | ForEach-Object {
        $wfText = Get-TextOrEmpty $_.FullName
        if ($wfText.Contains("design-sync-standing-consent.tests.sh")) { $hasSh = $true }
        if ($wfText.Contains("design-sync-standing-consent.tests.ps1")) { $hasPs1 = $true }
    }
    return $hasSh -and $hasPs1
}

if (Test-054CiRegistered) {
    Write-Host "PASS: TEST-054 (harness) CiDir=$CiDir is reachable from a CI entry point (AC-028)"
    exit 0
} else {
    Write-Host "FAIL: TEST-054 (harness) CiDir=$CiDir is NOT reachable from a CI entry point (AC-028)"
    exit 1
}
