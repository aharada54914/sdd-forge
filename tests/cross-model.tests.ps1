$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
# cross-model.tests.ps1 — tests for check-cross-model.ps1 (AC-002..004)
# Style: mirrors scripts.tests.ps1 (Assert-ExitCode pattern, workDir fixtures)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts"
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-cross-model-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null

$Pass = 0
$Fail = 0
$script:gateOutput = ""

function Ok { param([string]$Name) Write-Host "ok: $Name"; $script:Pass++ }
function Fail { param([string]$Name) Write-Host "FAIL: $Name"; $script:Fail++ }

function Invoke-CrossModel {
    param([string[]]$Arguments)
    $script:gateOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-cross-model.ps1") @Arguments 2>&1
    return $LASTEXITCODE
}

function Assert-ExitCode {
    param([string]$Name, [int]$Actual, [int]$Expected)
    if ($Actual -ne $Expected) {
        $details = ($script:gateOutput | Out-String).Trim()
        Write-Host "FAIL: $Name expected exit $Expected but got $Actual`n$details"
        $script:Fail++
    } else {
        Write-Host "ok: $Name"
        $script:Pass++
    }
}

# Standard digest used in fixture verdicts
$DIGEST = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
$DIGEST2 = "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3"

function New-Verdict {
    param(
        [string]$Path,
        [string]$Vendor,
        [string]$VerdictVal = "PASS",
        [bool]$Critical = $false,
        [string]$Digest = $DIGEST,
        [bool]$Blind = $true,
        [bool]$IncludeConsent = $true,
        [bool]$HasConsentKind = $true
    )
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $findings = @()
    if ($Critical) {
        $findings = @(@{ severity = "Critical"; ref = "file:1"; note = "critical issue" })
    }

    $consentObj = $null
    if ($IncludeConsent) {
        if ($HasConsentKind) {
            $consentObj = @{ kind = "human-flag"; ref = "tasks.md T-002 Cross-Model: enabled" }
        } else {
            $consentObj = @{}
        }
    }

    $verdict = [ordered]@{
        schema       = "cross-model-verdict/v1"
        task_id      = "T-002"
        feature      = "cross-model-verification"
        vendor       = $Vendor
        model        = "$Vendor-model-1"
        verdict      = $VerdictVal
        findings     = $findings
        blind        = $Blind
        input_digest = $Digest
        consent      = $consentObj
    }

    $verdict | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 $Path
}

Push-Location $workDir
try {
    # ============================================================================
    # AC-002: Diversity checks
    # ============================================================================
    Write-Host "=== AC-002: Diversity checks ==="

    # CM-001: Anthropic-only panel → exit 1 (diversity fail)
    $cm001 = Join-Path $workDir "cm001/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm001 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm001 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    Assert-ExitCode "CM-001: anthropic-only panel fails (diversity)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm001/specs")) 1

    # CM-001b: aggregate written with result=FAIL
    $agg001 = Join-Path $cm001 "T-002.cross-model.json"
    if (Test-Path $agg001) {
        $agg001Data = Get-Content -Raw $agg001 | ConvertFrom-Json
        if ($agg001Data.result -eq "FAIL") {
            Ok "CM-001b: aggregate result=FAIL written"
        } else {
            Fail "CM-001b: aggregate result should be FAIL, got $($agg001Data.result)"
        }
    } else {
        Fail "CM-001b: aggregate JSON should be written even on diversity fail"
    }

    # CM-002: anthropic+openai panel → exit 0 (diversity satisfied)
    $cm002 = Join-Path $workDir "cm002/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm002 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm002 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    New-Verdict -Path (Join-Path $cm002 "T-002.panelist-openai.verdict.json") -Vendor "openai"
    Assert-ExitCode "CM-002: anthropic+openai panel passes diversity" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm002/specs")) 0

    # CM-003: no verdicts → exit 2 (tool error)
    $cm003 = Join-Path $workDir "cm003/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm003 -Force | Out-Null
    Assert-ExitCode "CM-003: no verdicts → exit 2 (tool error)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm003/specs")) 2

    # CM-004: two non-anthropic vendors → pass
    $cm004 = Join-Path $workDir "cm004/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm004 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm004 "T-002.panelist-openai.verdict.json") -Vendor "openai"
    New-Verdict -Path (Join-Path $cm004 "T-002.panelist-google.verdict.json") -Vendor "google"
    Assert-ExitCode "CM-004: openai+google panel passes (non_anthropic>=1, distinct>=2)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm004/specs")) 0

    # ============================================================================
    # AC-003: Schema validation
    # ============================================================================
    Write-Host "=== AC-003: Schema validation ==="

    # CM-005: blind=false → exit 2
    $cm005 = Join-Path $workDir "cm005/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm005 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm005 "T-002.panelist-openai.verdict.json") -Vendor "openai" -Blind $false
    New-Verdict -Path (Join-Path $cm005 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    Assert-ExitCode "CM-005: blind=false → exit 2 (schema error)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm005/specs")) 2

    # CM-006: bad input_digest → exit 2
    $cm006 = Join-Path $workDir "cm006/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm006 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm006 "T-002.panelist-openai.verdict.json") -Vendor "openai" -Digest "not-a-valid-hex-digest"
    New-Verdict -Path (Join-Path $cm006 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    Assert-ExitCode "CM-006: bad input_digest → exit 2 (schema error)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm006/specs")) 2

    # CM-007: missing consent.kind → exit 2
    $cm007 = Join-Path $workDir "cm007/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm007 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm007 "T-002.panelist-openai.verdict.json") -Vendor "openai" -HasConsentKind $false
    New-Verdict -Path (Join-Path $cm007 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    Assert-ExitCode "CM-007: missing consent.kind → exit 2 (schema error)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm007/specs")) 2

    # ============================================================================
    # AC-004: Consensus checks
    # ============================================================================
    Write-Host "=== AC-004: Consensus checks ==="

    # CM-008: NEEDS_WORK verdict → exit 1 (consensus fail)
    $cm008 = Join-Path $workDir "cm008/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm008 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm008 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    New-Verdict -Path (Join-Path $cm008 "T-002.panelist-openai.verdict.json") -Vendor "openai" -VerdictVal "NEEDS_WORK"
    Assert-ExitCode "CM-008: NEEDS_WORK verdict → exit 1 (consensus fail)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm008/specs")) 1

    # CM-009: Critical finding → exit 1
    $cm009 = Join-Path $workDir "cm009/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm009 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm009 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    New-Verdict -Path (Join-Path $cm009 "T-002.panelist-openai.verdict.json") -Vendor "openai" -Critical $true
    Assert-ExitCode "CM-009: Critical finding → exit 1 (consensus fail)" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm009/specs")) 1

    # CM-010: all PASS, no critical → exit 0
    $cm010 = Join-Path $workDir "cm010/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm010 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm010 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    New-Verdict -Path (Join-Path $cm010 "T-002.panelist-openai.verdict.json") -Vendor "openai"
    Assert-ExitCode "CM-010: all PASS no critical → exit 0" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm010/specs")) 0

    # CM-010b: aggregate result=PASS written
    $agg010 = Join-Path $cm010 "T-002.cross-model.json"
    if (Test-Path $agg010) {
        $agg010Data = Get-Content -Raw $agg010 | ConvertFrom-Json
        if ($agg010Data.result -eq "PASS") {
            Ok "CM-010b: aggregate result=PASS written"
        } else {
            Fail "CM-010b: aggregate should be PASS, got $($agg010Data.result)"
        }
    } else {
        Fail "CM-010b: aggregate JSON should be written on pass"
    }

    # CM-011: --evaluator PASS matches panel → exit 0
    $cm011 = Join-Path $workDir "cm011/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm011 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm011 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    New-Verdict -Path (Join-Path $cm011 "T-002.panelist-openai.verdict.json") -Vendor "openai"
    Assert-ExitCode "CM-011: --evaluator PASS matches panel → exit 0" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--evaluator","PASS","--spec-root","$workDir/cm011/specs")) 0

    # CM-012: --evaluator NEEDS_WORK diverges from panel PASS → exit 1, NEEDS_HUMAN
    $cm012 = Join-Path $workDir "cm012/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm012 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm012 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    New-Verdict -Path (Join-Path $cm012 "T-002.panelist-openai.verdict.json") -Vendor "openai"
    Assert-ExitCode "CM-012: evaluator diverges → exit 1" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--evaluator","NEEDS_WORK","--spec-root","$workDir/cm012/specs")) 1

    $agg012 = Join-Path $cm012 "T-002.cross-model.json"
    if (Test-Path $agg012) {
        $agg012Data = Get-Content -Raw $agg012 | ConvertFrom-Json
        if ($agg012Data.result -eq "NEEDS_HUMAN" -and $agg012Data.requires_human_decision -eq $true) {
            Ok "CM-012b: aggregate result=NEEDS_HUMAN, requires_human_decision=true"
        } else {
            Fail "CM-012b: expected NEEDS_HUMAN/true, got result=$($agg012Data.result) requires_human=$($agg012Data.requires_human_decision)"
        }
    } else {
        Fail "CM-012b: aggregate JSON should be written on divergence"
    }

    # CM-013: --expect-digest matches → exit 0
    $cm013 = Join-Path $workDir "cm013/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm013 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm013 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic" -Digest $DIGEST
    New-Verdict -Path (Join-Path $cm013 "T-002.panelist-openai.verdict.json") -Vendor "openai" -Digest $DIGEST
    Assert-ExitCode "CM-013: --expect-digest matches → exit 0" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--expect-digest",$DIGEST,"--spec-root","$workDir/cm013/specs")) 0

    # CM-014: --expect-digest mismatch → exit 1
    $cm014 = Join-Path $workDir "cm014/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm014 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm014 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic" -Digest $DIGEST
    New-Verdict -Path (Join-Path $cm014 "T-002.panelist-openai.verdict.json") -Vendor "openai" -Digest $DIGEST
    Assert-ExitCode "CM-014: --expect-digest mismatch → exit 1" `
        (Invoke-CrossModel @("--task","T-002","--feature","f1","--expect-digest",$DIGEST2,"--spec-root","$workDir/cm014/specs")) 1

    # CM-015: aggregate JSON has correct schema fields
    $cm015 = Join-Path $workDir "cm015/specs/f1/verification"
    New-Item -ItemType Directory -Path $cm015 -Force | Out-Null
    New-Verdict -Path (Join-Path $cm015 "T-002.panelist-anthropic.verdict.json") -Vendor "anthropic"
    New-Verdict -Path (Join-Path $cm015 "T-002.panelist-openai.verdict.json") -Vendor "openai"
    Invoke-CrossModel @("--task","T-002","--feature","f1","--spec-root","$workDir/cm015/specs") | Out-Null
    $agg015 = Join-Path $cm015 "T-002.cross-model.json"
    if (Test-Path $agg015) {
        $d = Get-Content -Raw $agg015 | ConvertFrom-Json
        $required = @('schema','task_id','feature','panelists','vendors_distinct','non_anthropic_count','all_pass','any_critical','evaluator_verdict','divergence','requires_human_decision','result')
        $missing = @($required | Where-Object { -not ($d.PSObject.Properties.Name -contains $_) })
        if ($missing.Count -eq 0 -and $d.schema -eq "cross-model-aggregate/v1") {
            Ok "CM-015: aggregate JSON has all required fields"
        } else {
            Fail "CM-015: aggregate JSON missing fields: $($missing -join ',') schema=$($d.schema)"
        }
    } else {
        Fail "CM-015: aggregate JSON not created"
    }

    # ============================================================================
    # Summary
    # ============================================================================
    Write-Host ""
    Write-Host "Results: $script:Pass passed, $script:Fail failed"
    if ($script:Fail -gt 0) { exit 1 }
    exit 0

} finally {
    Pop-Location
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}
