# tests/release-loop-gate.tests.ps1 - PowerShell twin of
# tests/release-loop-gate.tests.sh (T-002 / Issue #148 / epic-159-pillar-b
# REQ-002). See the bash twin for the full test-technique description.
#
# This is a pure text-parsing structural check on the real
# .github/workflows/release.yml (no bash-only real script is driven, unlike
# T-001's fixture-copied scripts/bump-version.sh), so both lanes run
# unconditionally -- no Get-Command-degradation branch is needed here
# (design.md "release.yml parsing does not depend on any bash-only real
# script the way T-001's fixture does").
#
# The job-slice / marker logic is re-implemented natively (Get-Content -Raw
# + regex, per design.md's full-parity-port idiom) rather than shelling out
# to python3, mirroring the bash twin's job_slice() function line for line.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseYml = Join-Path $repoRoot ".github/workflows/release.yml"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
$testYml = Join-Path $repoRoot ".github/workflows/test.yml"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$cleanupRoots = New-Object System.Collections.Generic.List[string]
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$escapeHatchMarkers = @(
    "continue-on-error: true",
    "if: always()",
    "if: success() || failure()"
)

# Get-JobSlice -Text <workflow text> -JobName <name> — returns the text
# slice from the job's key line up to (excluding) the next top-level job
# key line, mirroring the bash twin's job_slice() python3 function. The
# job-key search is scoped to lines AFTER the top-level `jobs:` key (not the
# whole file) so the `on:` trigger section's own 2-space-indented `release:`
# key (`release.yml:10-13`'s `on: release: types: [published]`) is never
# misidentified as a job boundary.
function Get-JobSlice {
    param([string]$Text, [string]$JobName)
    $lines = $Text -split "`n"
    $jobsStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ([string]::Equals($lines[$i], "jobs:", [System.StringComparison]::Ordinal)) {
            $jobsStart = $i
            break
        }
    }
    if ($jobsStart -lt 0) { return "" }

    $jobStarts = @()
    for ($i = $jobsStart + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch '^  [A-Za-z0-9_-]+:\s*$') { $jobStarts += $i }
    }

    $marker = "  ${JobName}:"
    $start = -1
    foreach ($i in $jobStarts) {
        if ([string]::Equals($lines[$i].TrimEnd(), $marker, [System.StringComparison]::Ordinal)) {
            $start = $i
            break
        }
    }
    if ($start -lt 0) { return "" }

    $end = $lines.Count
    foreach ($i in $jobStarts) {
        if ($i -gt $start) { $end = $i; break }
    }
    return ($lines[$start..($end - 1)] -join "`n")
}

function Test-EscapeHatch {
    param([string]$SliceText)
    foreach ($marker in $escapeHatchMarkers) {
        if ($SliceText.Contains($marker)) { return $true }
    }
    return $false
}

function Test-ReleaseHasNeeds {
    param([string]$SliceText)
    if ($SliceText -cmatch '(?m)needs:\s*loop-gate\s*$') { return $true }
    if ($SliceText -cmatch 'needs:\s*\[\s*loop-gate\s*\]') { return $true }
    if ($SliceText -cmatch 'needs:\s*\n\s*-\s*loop-gate\b') { return $true }
    return $false
}

# ---------------------------------------------------------------------------
# TEST-007 (AC-007): loop-gate job slice contains both suite invocations
# ---------------------------------------------------------------------------
function Test-007 {
    Write-Output "=== TEST-007 (AC-007): loop-gate job slice contains both suite invocations ==="
    $text = Get-Content -LiteralPath $releaseYml -Raw
    $loopGateSlice = Get-JobSlice -Text $text -JobName "loop-gate"

    if ($loopGateSlice -ne "") {
        Ok "TEST-007 (AC-007): a loop-gate: job slice was found in release.yml"
    } else {
        Fail "TEST-007 (AC-007): no loop-gate: job slice found in release.yml"
        return
    }

    if ($loopGateSlice.Contains("tests/loop-consistency.tests.sh")) {
        Ok "TEST-007 (AC-007): loop-gate job slice invokes tests/loop-consistency.tests.sh"
    } else {
        Fail "TEST-007 (AC-007): loop-gate job slice does not invoke tests/loop-consistency.tests.sh"
    }

    if ($loopGateSlice.Contains("tests/loop-inventory.tests.sh")) {
        Ok "TEST-007 (AC-007): loop-gate job slice invokes tests/loop-inventory.tests.sh"
    } else {
        Fail "TEST-007 (AC-007): loop-gate job slice does not invoke tests/loop-inventory.tests.sh"
    }
}

# ---------------------------------------------------------------------------
# TEST-008 (AC-008): release job needs: loop-gate + weakened-gate negative
# scan
# ---------------------------------------------------------------------------
function Test-008 {
    Write-Output "=== TEST-008 (AC-008): release job needs: loop-gate + no escape hatch ==="
    $text = Get-Content -LiteralPath $releaseYml -Raw
    $loopGateSlice = Get-JobSlice -Text $text -JobName "loop-gate"
    $releaseSlice = Get-JobSlice -Text $text -JobName "release"

    if (Test-ReleaseHasNeeds -SliceText $releaseSlice) {
        Ok "TEST-008 (AC-008): release job slice carries a needs: loop-gate entry"
    } else {
        Fail "TEST-008 (AC-008): release job slice does not carry a needs: loop-gate entry"
    }

    if (-not (Test-EscapeHatch -SliceText $loopGateSlice)) {
        Ok "TEST-008 (AC-008): loop-gate job slice carries no continue-on-error:true / if:always() / if:success()||failure() escape hatch"
    } else {
        Fail "TEST-008 (AC-008): loop-gate job slice carries an escape hatch (weakened-gate threat)"
    }

    if (-not (Test-EscapeHatch -SliceText $releaseSlice)) {
        Ok "TEST-008 (AC-008): release job slice carries no continue-on-error:true / if:always() / if:success()||failure() escape hatch"
    } else {
        Fail "TEST-008 (AC-008): release job slice carries an escape hatch (weakened-gate threat)"
    }
}

# ---------------------------------------------------------------------------
# TEST-009 (AC-009): negative-branch canary — needs: textually stripped
# ---------------------------------------------------------------------------
function Test-009 {
    Write-Output "=== TEST-009 (AC-009): negative-branch canary (needs: stripped) ==="
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("release-loop-gate-canary." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $tempRoot = (Resolve-Path -LiteralPath $tempRoot).Path
    $cleanupRoots.Add($tempRoot)

    $text = Get-Content -LiteralPath $releaseYml -Raw
    $lines = $text -split "`n"
    $mutatedLines = $lines | Where-Object { $_ -cnotmatch '^\s*needs:\s*loop-gate\s*$' }
    $mutatedText = ($mutatedLines -join "`n")
    $fixtureCopy = Join-Path $tempRoot "release.yml"
    [System.IO.File]::WriteAllText($fixtureCopy, $mutatedText, $utf8NoBom)

    $mutatedFull = Get-Content -LiteralPath $fixtureCopy -Raw
    $releaseSlice = Get-JobSlice -Text $mutatedFull -JobName "release"
    if (-not (Test-ReleaseHasNeeds -SliceText $releaseSlice)) {
        Ok "TEST-009 (AC-009): the needs:-stripped fixture copy is reported non-compliant, proving TEST-008's assertion is not vacuously true"
    } else {
        Fail "TEST-009 (AC-009): the needs:-stripped fixture copy was still reported compliant -- the marker-check function is vacuous"
    }
}

# ---------------------------------------------------------------------------
# TEST-010 (AC-010): ubuntu-latest only + self-registration
# ---------------------------------------------------------------------------
function Test-010 {
    Write-Output "=== TEST-010 (AC-010): ubuntu-latest only + self-registration ==="
    $text = Get-Content -LiteralPath $releaseYml -Raw
    $loopGateSlice = Get-JobSlice -Text $text -JobName "loop-gate"

    if ($loopGateSlice.Contains("runs-on: ubuntu-latest")) {
        Ok "TEST-010 (AC-010): loop-gate job slice declares runs-on: ubuntu-latest"
    } else {
        Fail "TEST-010 (AC-010): loop-gate job slice does not declare runs-on: ubuntu-latest"
    }

    if (-not ($loopGateSlice.Contains("strategy:") -or $loopGateSlice.Contains("matrix:"))) {
        Ok "TEST-010 (AC-010): loop-gate job slice carries no strategy:/matrix: key (single-OS, matching release.yml's existing scope)"
    } else {
        Fail "TEST-010 (AC-010): loop-gate job slice unexpectedly carries a strategy:/matrix: key"
    }

    $runAllPs1Content = if (Test-Path -LiteralPath $runAllPs1) { Get-Content -LiteralPath $runAllPs1 -Raw } else { "" }
    $testYmlContent = if (Test-Path -LiteralPath $testYml) { Get-Content -LiteralPath $testYml -Raw } else { "" }
    if ($runAllPs1Content.Contains("release-loop-gate.tests.ps1") -and $testYmlContent.Contains("release-loop-gate.tests.ps1")) {
        Ok "TEST-010 (AC-010): release-loop-gate.tests.ps1 is registered in tests/run-all.ps1 and .github/workflows/test.yml"
    } else {
        Fail "TEST-010 (AC-010): release-loop-gate.tests.ps1 is NOT registered in tests/run-all.ps1 and/or .github/workflows/test.yml"
    }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
try {
    Test-007
    Test-008
    Test-009
    Test-010

    Write-Output ""
    Write-Output "release-loop-gate.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
    if ($script:failCount -ne 0) { exit 1 }
    exit 0
} finally {
    foreach ($d in $cleanupRoots) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
    }
}
