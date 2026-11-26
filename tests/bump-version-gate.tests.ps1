# Exercise the shared workstation bump cases from PowerShell and retain the
# native no-bypass and registration checks.
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$bumpVersionSh = Join-Path $repoRoot "scripts/bump-version.sh"
$selfPs1 = Join-Path $repoRoot "tests/bump-version-gate.tests.ps1"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
$testYml = Join-Path $repoRoot ".github/workflows/test.yml"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

function Test-BumpCase([string]$Id, [string]$Case) {
    if (-not $env:SDD_TEST_BASH -and -not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Output "SKIP: $Id bash not found; scripts/bump-version.sh requires Bash (REQ-004)"
        return
    }
    $python = if ($IsWindows) { 'python' } else { 'python3' }
    & $python -B (Join-Path $PSScriptRoot 'release-readiness.tests.py') "ReleaseReadiness.$Case"
    if ($LASTEXITCODE -eq 0) { Ok "$Id $Case" } else { Fail "$Id $Case" }
}

# TEST-004 (AC-004): no-bypass self-check over the REAL
# scripts/bump-version.sh source
# ---------------------------------------------------------------------------
function Test-004 {
    Write-Output "=== TEST-004 (AC-004): no-bypass self-check (real scripts/bump-version.sh) ==="
    $srcLines = Get-Content -LiteralPath $bumpVersionSh

    $startIdx = -1
    for ($i = 0; $i -lt $srcLines.Count; $i++) {
        if ($srcLines[$i] -eq '# Loop-suite prerequisite (issue #148): both suites must pass before any') {
            $startIdx = $i
            break
        }
    }
    if ($startIdx -lt 0) {
        Fail "TEST-004 (AC-004): loop-gate marker comment not found in scripts/bump-version.sh"
        return
    }

    $endIdx = -1
    for ($i = $startIdx + 1; $i -lt $srcLines.Count; $i++) {
        if ($srcLines[$i] -eq 'done') { $endIdx = $i; break }
    }
    if ($endIdx -lt 0) {
        Fail "TEST-004 (AC-004): loop-gate block's closing 'done' not found after the marker comment"
        return
    }

    $block = $srcLines[$startIdx..$endIdx]

    $forIdx = -1
    for ($i = 0; $i -lt $block.Count; $i++) {
        if ($block[$i] -eq 'for suite in tests/loop-consistency.tests.sh tests/loop-inventory.tests.sh; do') {
            $forIdx = $i
            break
        }
    }
    if ($forIdx -lt 0) {
        Fail "TEST-004 (AC-004): the loop-gate 'for' statement is missing or indented (possibly nested inside a bypass conditional)"
        return
    }
    Ok "TEST-004 (AC-004): the loop-gate 'for' statement is unindented (top-level, not nested inside a conditional)"

    # Keyword sweep over the CODE only (the 'for' line through 'done'),
    # excluding the two leading comment lines -- the comment above the
    # block legitimately documents "no bypass" in prose, which would
    # otherwise false-trip a whole-block sweep.
    $codeBlock = $block[$forIdx..($block.Count - 1)]
    $codeText = ($codeBlock -join "`n")
    if ($codeText -match '(?i)SKIP|BYPASS|OVERRIDE|CONTINUE-ON-ERROR') {
        Fail "TEST-004 (AC-004): a bypass-suggestive token (SKIP/BYPASS/OVERRIDE) was found inside the loop-gate block's code"
    } else {
        Ok "TEST-004 (AC-004): no bypass-suggestive token (SKIP/BYPASS/OVERRIDE) inside the loop-gate block's code"
    }

    $preFor = @()
    for ($i = 0; $i -lt $forIdx; $i++) {
        $line = $block[$i].Trim()
        if ($line -ne '' -and -not $line.StartsWith('#')) { $preFor += $block[$i] }
    }
    if ($preFor.Count -eq 0) {
        Ok "TEST-004 (AC-004): no statement (conditional or otherwise) precedes the loop-gate 'for' entry"
    } else {
        Fail "TEST-004 (AC-004): a statement precedes the loop-gate 'for' entry, possibly gating it: $($preFor -join '; ')"
    }
}

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): CI-resilience + self-registration conformance
# ---------------------------------------------------------------------------
function Test-006 {
    Write-Output "=== TEST-006 (AC-006): CI-resilience + self-registration ==="
    $selfContent = Get-Content -LiteralPath $selfPs1 -Raw

    if ($selfContent.Contains("Resolve-Path")) {
        Ok "TEST-006 (AC-006, CI-resilience): fixture-root normalization uses Resolve-Path (pwd -P equivalent)"
    } else {
        Fail "TEST-006 (AC-006, CI-resilience): Resolve-Path normalization not found in this suite's own source"
    }

    # Forbidden-substring tokens are built at runtime -- with names/messages
    # that also avoid the literal substring -- so these self-checks do not
    # trip on their own construction lines.
    $queryToolChar1 = "j"
    $queryToolChar2 = "q"
    $queryToolToken = "$queryToolChar1$queryToolChar2"
    if ($selfContent.Contains($queryToolToken)) {
        Fail "TEST-006 (AC-006, CI-resilience): this suite unexpectedly consumes JSON-query-tool output (non-use declaration violated)"
    } else {
        Ok "TEST-006 (AC-006, CI-resilience): this suite consumes no JSON-query-tool output (non-use declaration)"
    }

    $validatorPartA = "validate-review"
    $validatorPartB = "-context-set"
    $validatorToken = "$validatorPartA$validatorPartB"
    if ($selfContent.Contains($validatorToken)) {
        Fail "TEST-006 (AC-006, CI-resilience): this suite unexpectedly drives the real validator (non-use declaration violated)"
    } else {
        Ok "TEST-006 (AC-006, CI-resilience): this suite drives no real validator (non-use declaration)"
    }

    $runAllPs1Content = if (Test-Path -LiteralPath $runAllPs1) { (& (Join-Path $PSScriptRoot 'lib/verification-registration.ps1') $runAllPs1) } else { "" }
    $testYmlContent = if (Test-Path -LiteralPath $testYml) { Get-Content -LiteralPath $testYml -Raw } else { "" }
    if ($runAllPs1Content.Contains("bump-version-gate.tests.ps1") -and $testYmlContent.Contains("bump-version-gate.tests.ps1")) {
        Ok "TEST-006 (AC-006): bump-version-gate.tests.ps1 is registered in tests/run-all.ps1 and .github/workflows/test.yml"
    } else {
        Fail "TEST-006 (AC-006): bump-version-gate.tests.ps1 is NOT registered in tests/run-all.ps1 and/or .github/workflows/test.yml"
    }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
Test-BumpCase TEST-001 check_bump_green
Test-BumpCase TEST-002 check_bump_first_suite_failure
Test-BumpCase TEST-003 check_bump_last_suite_failure
Test-004
Test-BumpCase TEST-005 check_bump_doctor_failure
Test-006

Write-Output ""
Write-Output "bump-version-gate.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
