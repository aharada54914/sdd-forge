# Exercise the shared workstation bump cases from PowerShell and retain the
# native fixture hygiene checks.
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$selfPs1 = Join-Path $repoRoot "tests/bump-version-gate.tests.ps1"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

function Test-BumpCase([string]$Id, [string]$Case, [switch]$Static) {
    if (-not $Static -and -not $env:SDD_TEST_BASH -and -not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Output "SKIP: $Id bash not found; scripts/bump-version.sh requires Bash (REQ-004)"
        return
    }
    $python = if ($IsWindows) { 'python' } else { 'python3' }
    & $python -B (Join-Path $PSScriptRoot 'release-readiness.tests.py') "ReleaseReadiness.$Case"
    if ($LASTEXITCODE -eq 0) { Ok "$Id $Case" } else { Fail "$Id $Case" }
}

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

    Test-BumpCase TEST-006 check_bump_powershell_registration -Static
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
Test-BumpCase TEST-001 check_bump_green
Test-BumpCase TEST-002 check_bump_first_suite_failure
Test-BumpCase TEST-003 check_bump_last_suite_failure
Test-BumpCase TEST-004 check_bump_gate_source
Test-BumpCase TEST-005 check_bump_doctor_failure
Test-006
Test-BumpCase TEST-007 check_bump_stale_readme
Test-BumpCase TEST-007 check_bump_missing_helper

Write-Output ""
Write-Output "bump-version-gate.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
