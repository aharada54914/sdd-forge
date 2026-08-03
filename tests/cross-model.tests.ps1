$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
# cross-model.tests.ps1 — tests for check-cross-model.ps1 (AC-002..004)
# Style: mirrors scripts.tests.ps1 (Assert-ExitCode pattern, workDir fixtures)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts"
$threatModelPath = Join-Path $repositoryRoot "docs/THREAT-MODEL.md"
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

function Get-MonotonicMilliseconds {
    return [long]([System.Diagnostics.Stopwatch]::GetTimestamp() * 1000 / [System.Diagnostics.Stopwatch]::Frequency)
}

function Test-ProcessExited {
    param([int]$ProcessId)
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { return $true }
        Start-Sleep -Milliseconds 100
    }
    return -not [bool](Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}

function Get-RunnerDefault {
    param([string]$RunnerPath)
    $source = Get-Content -Raw -LiteralPath $RunnerPath
    $match = [regex]::Match($source, '(?m)^\$PanelistTimeoutDefault\s*=\s*([0-9]+)\s*$')
    if ($match.Success) { return $match.Groups[1].Value }
    return ""
}

function Invoke-PanelistRunner {
    param(
        [pscustomobject]$Runner,
        [ValidateSet("unset", "set")][string]$TimeoutMode,
        [string]$TimeoutValue,
        [string]$SpecRoot,
        [hashtable]$StubEnvironment = @{}
    )

    $savedPath = $env:PATH
    $hadTimeout = Test-Path Env:SDD_PANELIST_TIMEOUT
    $savedTimeout = $env:SDD_PANELIST_TIMEOUT
    $savedStubValues = @{}
    foreach ($key in $StubEnvironment.Keys) {
        $savedStubValues[$key] = if (Test-Path "Env:$key") { (Get-Item "Env:$key").Value } else { $null }
        Set-Item "Env:$key" ([string]$StubEnvironment[$key])
    }

    try {
        $env:PATH = $script:panelistStubPath + [System.IO.Path]::PathSeparator + $savedPath
        if ($TimeoutMode -eq "unset") {
            Remove-Item Env:SDD_PANELIST_TIMEOUT -ErrorAction SilentlyContinue
        } else {
            $env:SDD_PANELIST_TIMEOUT = $TimeoutValue
        }

        $output = & $script:powerShellHost -NoProfile -ExecutionPolicy Bypass -File $Runner.Path `
            --task T-901 --feature timeout-test --input $script:panelistInput `
            --spec-root $SpecRoot 2>&1
        $script:panelistExit = $LASTEXITCODE
        $script:panelistOutput = ($output | Out-String).Trim()
    } finally {
        $env:PATH = $savedPath
        if ($hadTimeout) { $env:SDD_PANELIST_TIMEOUT = $savedTimeout }
        else { Remove-Item Env:SDD_PANELIST_TIMEOUT -ErrorAction SilentlyContinue }
        foreach ($key in $StubEnvironment.Keys) {
            if ($null -eq $savedStubValues[$key]) { Remove-Item "Env:$key" -ErrorAction SilentlyContinue }
            else { Set-Item "Env:$key" $savedStubValues[$key] }
        }
    }
}

function Stop-TestProcess {
    param([int]$ProcessId)
    if ($ProcessId -gt 0 -and (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
}

$script:powerShellHost = (Get-Process -Id $PID).Path
$script:panelistStubPath = Join-Path $workDir "panelist-stubs"
$script:panelistInput = Join-Path $workDir "panelist-input.txt"
New-Item -ItemType Directory -Path $script:panelistStubPath -Force | Out-Null
Set-Content -Encoding Utf8 -Path $script:panelistInput -Value "sanitized test input"

$panelistWorker = Join-Path $script:panelistStubPath "panelist-worker.ps1"
@'
$ErrorActionPreference = "Stop"
if ($env:STUB_CALLED_FILE) { Set-Content -Path $env:STUB_CALLED_FILE -Value "called" }
if ($env:STUB_PID_FILE) { Set-Content -Path $env:STUB_PID_FILE -Value $PID }

if ($env:STUB_MODE -eq "hang") {
    $childStdout = "$($env:STUB_CHILD_PID_FILE).stdout"
    $childStderr = "$($env:STUB_CHILD_PID_FILE).stderr"
    $child = Start-Process -FilePath (Get-Process -Id $PID).Path `
        -ArgumentList "-NoProfile", "-Command", "Start-Sleep -Seconds 30" `
        -RedirectStandardOutput $childStdout -RedirectStandardError $childStderr -PassThru
    if ($env:STUB_CHILD_PID_FILE) { Set-Content -Path $env:STUB_CHILD_PID_FILE -Value $child.Id }
    Start-Sleep -Seconds 30
}

if ($env:STUB_DELAY_MS) { Start-Sleep -Milliseconds ([int]$env:STUB_DELAY_MS) }
@{
    schema = "cross-model-verdict/v1"
    task_id = "T-901"
    feature = "timeout-test"
    vendor = "stub"
    model = "stub-model"
    verdict = "PASS"
    findings = @()
    blind = $true
    input_digest = ("a" * 64)
    consent = @{ kind = "human-flag"; ref = "test fixture" }
} | ConvertTo-Json -Compress -Depth 5
'@ | Set-Content -Encoding Utf8 -Path $panelistWorker

if ($IsWindows) {
    foreach ($commandName in @("codex", "gemini")) {
        $wrapper = Join-Path $script:panelistStubPath "$commandName.cmd"
        "@echo off`r`n`"$script:powerShellHost`" -NoProfile -File `"$panelistWorker`" %*`r`n" |
            Set-Content -Encoding Ascii -NoNewline -Path $wrapper
    }
} else {
    $quotedHost = $script:powerShellHost.Replace('"', '\"')
    $quotedWorker = $panelistWorker.Replace('"', '\"')
    foreach ($commandName in @("codex", "gemini")) {
        $wrapper = Join-Path $script:panelistStubPath $commandName
        "#!/bin/sh`nexec `"$quotedHost`" -NoProfile -File `"$quotedWorker`" `"`$@`"`n" |
            Set-Content -Encoding Utf8 -NoNewline -Path $wrapper
        & chmod +x $wrapper
    }
}

$panelistRunners = @(
    [pscustomobject]@{
        Name = "gpt"
        Path = Join-Path $scriptsDir "run-panelist-gpt.ps1"
        VerdictName = "T-901.panelist-openai.verdict.json"
    },
    [pscustomobject]@{
        Name = "gemini"
        Path = Join-Path $scriptsDir "run-panelist-gemini.ps1"
        VerdictName = "T-901.panelist-google.verdict.json"
    }
)

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
    # TEST-003 / TEST-012: PowerShell runner timeout configuration
    # ============================================================================
    Write-Host "=== TEST-003/TEST-012: PowerShell timeout configuration ==="
    $runnerDefaults = @{}
    foreach ($runner in $panelistRunners) {
        $runnerDefault = Get-RunnerDefault $runner.Path
        $runnerDefaults[$runner.Name] = $runnerDefault
        if ($runnerDefault) {
            Ok "TEST-012: $($runner.Name) default is extracted from runner source"
        } else {
            Fail "TEST-012: $($runner.Name) default must be extractable from runner source"
        }

        foreach ($validCase in @(
            @{ Name = "unset"; Mode = "unset"; Value = "" },
            @{ Name = "empty"; Mode = "set"; Value = "" },
            @{ Name = "one"; Mode = "set"; Value = "1" }
        )) {
            $caseRoot = Join-Path $workDir "config-$($runner.Name)-$($validCase.Name)/specs"
            Invoke-PanelistRunner -Runner $runner -TimeoutMode $validCase.Mode `
                -TimeoutValue $validCase.Value -SpecRoot $caseRoot
            $verdict = Join-Path $caseRoot (Join-Path "timeout-test/verification" $runner.VerdictName)
            if ($script:panelistExit -eq 0 -and (Test-Path $verdict)) {
                Ok "TEST-003: $($runner.Name) accepts $($validCase.Name) timeout"
            } else {
                Fail "TEST-003: $($runner.Name) accepts $($validCase.Name) timeout (exit=$script:panelistExit verdict=$(Test-Path $verdict))"
            }
        }

        if ($runnerDefault) {
            $caseRoot = Join-Path $workDir "config-$($runner.Name)-source-default/specs"
            Invoke-PanelistRunner -Runner $runner -TimeoutMode set `
                -TimeoutValue $runnerDefault -SpecRoot $caseRoot
            $verdict = Join-Path $caseRoot (Join-Path "timeout-test/verification" $runner.VerdictName)
            if ($script:panelistExit -eq 0 -and (Test-Path $verdict)) {
                Ok "TEST-003: $($runner.Name) accepts its source-derived default"
            } else {
                Fail "TEST-003: $($runner.Name) accepts its source-derived default (exit=$script:panelistExit verdict=$(Test-Path $verdict))"
            }
        } else {
            Fail "TEST-003: $($runner.Name) source-derived default case is runnable"
        }

        foreach ($invalidValue in @("0", "-5", "abc")) {
            $safeValue = $invalidValue.Replace("-", "negative-")
            $caseRoot = Join-Path $workDir "config-$($runner.Name)-$safeValue/specs"
            $calledFile = Join-Path $workDir "config-$($runner.Name)-$safeValue.called"
            Invoke-PanelistRunner -Runner $runner -TimeoutMode set -TimeoutValue $invalidValue `
                -SpecRoot $caseRoot -StubEnvironment @{ STUB_CALLED_FILE = $calledFile }
            if ($script:panelistExit -eq 2 -and -not (Test-Path $calledFile)) {
                Ok "TEST-003: $($runner.Name) rejects '$invalidValue' before vendor invocation"
            } else {
                Fail "TEST-003: $($runner.Name) rejects '$invalidValue' before vendor invocation (exit=$script:panelistExit called=$(Test-Path $calledFile))"
            }
        }
    }

    if ($runnerDefaults.gpt -and $runnerDefaults.gemini -and $runnerDefaults.gpt -eq $runnerDefaults.gemini) {
        Ok "TEST-012: PowerShell runners declare the same source-derived default"
    } else {
        Fail "TEST-012: PowerShell runner source defaults must match (gpt='$($runnerDefaults.gpt)' gemini='$($runnerDefaults.gemini)')"
    }

    # ============================================================================
    # TEST-004(a) / TEST-005: wall-clock bound and no orphaned descendants
    # ============================================================================
    Write-Host "=== TEST-004(a)/TEST-005: PowerShell timeout lifecycle ==="
    $timeoutCaseRoots = @{}
    foreach ($runner in $panelistRunners) {
        $caseRoot = Join-Path $workDir "timeout-$($runner.Name)/specs"
        $timeoutCaseRoots[$runner.Name] = $caseRoot
        $stubPidFile = Join-Path $workDir "timeout-$($runner.Name).stub.pid"
        $childPidFile = Join-Path $workDir "timeout-$($runner.Name).child.pid"
        $started = Get-MonotonicMilliseconds
        Invoke-PanelistRunner -Runner $runner -TimeoutMode set -TimeoutValue "1" `
            -SpecRoot $caseRoot -StubEnvironment @{
                STUB_MODE = "hang"
                STUB_PID_FILE = $stubPidFile
                STUB_CHILD_PID_FILE = $childPidFile
            }
        $elapsed = (Get-MonotonicMilliseconds) - $started
        $stubPid = if (Test-Path $stubPidFile) { [int](Get-Content -Raw $stubPidFile) } else { 0 }
        $childPid = if (Test-Path $childPidFile) { [int](Get-Content -Raw $childPidFile) } else { 0 }
        $stubExited = $stubPid -gt 0 -and (Test-ProcessExited $stubPid)
        $childExited = $childPid -gt 0 -and (Test-ProcessExited $childPid)
        $verdict = Join-Path $caseRoot (Join-Path "timeout-test/verification" $runner.VerdictName)
        Write-Host "measurement: TEST-004(a) runner=$($runner.Name) elapsed_ms=$elapsed limit_ms=10000 stub_pid=$stubPid stub_alive=$([int](-not $stubExited)) child_pid=$childPid child_alive=$([int](-not $childExited)) exit=$script:panelistExit verdict=$([int](Test-Path $verdict))"

        if ($elapsed -le 10000 -and $stubExited -and $childExited) {
            Ok "TEST-004(a): $($runner.Name) returns within the wall-clock bound with no stub or child alive"
        } else {
            Fail "TEST-004(a): $($runner.Name) returns within the wall-clock bound with no stub or child alive"
        }
        if ($script:panelistExit -eq 1 -and -not (Test-Path $verdict)) {
            Ok "TEST-005: $($runner.Name) timeout exits 1 without a verdict"
        } else {
            Fail "TEST-005: $($runner.Name) timeout exits 1 without a verdict"
        }

        Stop-TestProcess $childPid
        Stop-TestProcess $stubPid
    }

    # TEST-006: the missing timed-out non-Anthropic verdict must prevent a
    # consensus PASS at the existing gate.
    $gateRoot = $timeoutCaseRoots.gpt
    $gateVerification = Join-Path $gateRoot "timeout-test/verification"
    $anthropicVerdict = Join-Path $gateVerification "T-901.panelist-anthropic.verdict.json"
    @{
        schema = "cross-model-verdict/v1"
        task_id = "T-901"
        feature = "timeout-test"
        vendor = "anthropic"
        model = "stub-model"
        verdict = "PASS"
        findings = @()
        blind = $true
        input_digest = ("a" * 64)
        consent = @{ kind = "human-flag"; ref = "test fixture" }
    } | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 -Path $anthropicVerdict
    $gateExit = Invoke-CrossModel @(
        "--task", "T-901", "--feature", "timeout-test", "--spec-root", $gateRoot
    )
    $gateAggregate = Join-Path $gateVerification "T-901.cross-model.json"
    $gateResult = if (Test-Path $gateAggregate) {
        (Get-Content -Raw $gateAggregate | ConvertFrom-Json).result
    } else { "" }
    $gateText = ($script:gateOutput | Out-String)
    if ($gateExit -ne 0 -and $gateResult -ne "PASS" -and $gateText -notmatch "consensus PASS") {
        Ok "TEST-006: missing timed-out non-Anthropic verdict fails gate without consensus PASS"
    } else {
        Fail "TEST-006: missing timed-out non-Anthropic verdict must fail gate (exit=$gateExit result='$gateResult')"
    }

    # TEST-004(b) is intentionally POSIX-only. Process.Kill() maps to an
    # untrappable TerminateProcess operation, so PowerShell has no meaningful
    # refusal stub. TEST-004(a)'s descendant-liveness check carries the
    # Kill($true) escalation risk instead.
    Write-Host "note: TEST-004(b) intentionally has no PowerShell counterpart; TEST-004(a) checks descendant liveness"

    # ============================================================================
    # TEST-004(c): near-boundary successful completion, repeated five times
    # ============================================================================
    Write-Host "=== TEST-004(c): PowerShell near-boundary completion ==="
    foreach ($runner in $panelistRunners) {
        for ($iteration = 1; $iteration -le 5; $iteration++) {
            $caseRoot = Join-Path $workDir "boundary-$($runner.Name)-$iteration/specs"
            $started = Get-MonotonicMilliseconds
            Invoke-PanelistRunner -Runner $runner -TimeoutMode set -TimeoutValue "2" `
                -SpecRoot $caseRoot -StubEnvironment @{ STUB_DELAY_MS = "1200" }
            $elapsed = (Get-MonotonicMilliseconds) - $started
            $verdict = Join-Path $caseRoot (Join-Path "timeout-test/verification" $runner.VerdictName)
            Write-Host "measurement: TEST-004(c) runner=$($runner.Name) iteration=$iteration elapsed_ms=$elapsed exit=$script:panelistExit verdict=$([int](Test-Path $verdict))"
            if ($script:panelistExit -eq 0 -and (Test-Path $verdict)) {
                Ok "TEST-004(c): $($runner.Name) near-boundary completion iteration $iteration"
            } else {
                Fail "TEST-004(c): $($runner.Name) near-boundary completion iteration $iteration"
            }
        }
    }

    # ============================================================================
    # TEST-001 / TEST-002: shipped policy taxonomy
    # ============================================================================
    Write-Host "=== TEST-001/002: panelist failure taxonomy ==="
    $policyPath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/cross-model-verification-policy.md"
    $policyText = Get-Content -Raw -Encoding Utf8 -LiteralPath $policyPath
    $taxonomyMatch = [regex]::Match(
        $policyText,
        '(?ms)^## Panelist Failure Taxonomy\s*$(.*?)(?=^##\s)')
    $taxonomySection = if ($taxonomyMatch.Success) { $taxonomyMatch.Groups[1].Value } else { "" }

    foreach ($mode in @(
        "CLI absent",
        "CLI exits non-zero",
        "CLI rate-limited",
        "CLI hangs / exceeds the time bound",
        "CLI returns malformed output"
    )) {
        $rowPrefix = "| $mode |"
        $row = $taxonomySection -split "`r?`n" |
            Where-Object { $_.StartsWith($rowPrefix, [StringComparison]::Ordinal) } |
            Select-Object -First 1
        $cells = if ($row) {
            @($row.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        } else { @() }
        $validRow = $cells.Count -eq 4 -and
            $cells[1].StartsWith('`1`', [StringComparison]::Ordinal) -and
            -not $cells[1].Contains('`2`', [StringComparison]::Ordinal) -and
            $cells[2].StartsWith("No.", [StringComparison]::Ordinal) -and
            $cells[3] -match '(?i)diversity' -and
            $cells[3] -match '(?i)gate' -and
            $cells[3] -match '(?i)exit 1' -and
            $cells[3] -match '(?i)exit 2'
        if ($validRow) {
            Ok "TEST-001: $mode states exit, no-verdict, and gate propagation"
        } else {
            Fail "TEST-001: $mode must state exit 1, no verdict, and diversity/gate propagation"
        }
    }

    $normalizedTaxonomy = [regex]::Replace($taxonomySection, '\s+', ' ')
    if ($normalizedTaxonomy.Contains(
            'Rate-limiting is **not separately handled**',
            [StringComparison]::Ordinal) -and
        $normalizedTaxonomy.Contains(
            'exit-non-zero or timeout',
            [StringComparison]::Ordinal)) {
        Ok "TEST-002: rate limiting is explicitly delegated to exit-non-zero or timeout"
    } else {
        Fail "TEST-002: rate limiting must be stated as not separately handled"
    }

    # ============================================================================
    # TEST-007 / TEST-008 / TEST-013: threat-model security cross-references
    # ============================================================================
    Write-Host "=== TEST-007/008/013: threat-model security cross-references ==="
    $threatModelText = Get-Content -Raw -Encoding Utf8 -LiteralPath $threatModelPath
    $owaspMatch = [regex]::Match(
        $threatModelText,
        '(?ms)^## OWASP LLM Top 10 \(2025\) Cross-Reference\s*$(.*?)(?=^##\s|\z)')
    $owaspRows = @()
    if ($owaspMatch.Success) {
        $owaspRows = @($owaspMatch.Groups[1].Value -split "`r?`n" |
            Where-Object { $_ -match '^\|\s*LLM(?:0[1-9]|10)\s*\|' } |
            ForEach-Object { ,@($_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }) })
    }
    $expectedOwaspIds = @(1..10 | ForEach-Object { "LLM{0:D2}" -f $_ })
    $actualOwaspIds = @($owaspRows | ForEach-Object { $_[0] } | Sort-Object)
    $owaspRowsValid = $owaspRows.Count -eq 10 -and
        (($actualOwaspIds -join ',') -ceq (($expectedOwaspIds | Sort-Object) -join ',')) -and
        @($owaspRows | Where-Object { $_.Count -ne 3 -or -not $_[1] -or -not $_[2] }).Count -eq 0
    if ($owaspRowsValid) {
        Ok "TEST-007: OWASP table maps LLM01 through LLM10 with dispositions and evidence"
    } else {
        Fail "TEST-007: OWASP table must map LLM01 through LLM10 exactly once"
    }

    $controlsMatch = [regex]::Match(
        $threatModelText,
        '(?ms)^## Controls Table\s*$(.*?)(?=^##\s|\z)')
    $controlNames = @()
    if ($controlsMatch.Success) {
        $controlNames = @([regex]::Matches($controlsMatch.Groups[1].Value, '\*\*([^*]+)\*\*') |
            ForEach-Object { $_.Groups[1].Value })
    }
    $naRows = @($owaspRows | Where-Object { $_.Count -eq 3 -and $_[1].StartsWith('N/A — ', [StringComparison]::Ordinal) })
    $mappedRows = @($owaspRows | Where-Object {
        $_.Count -eq 3 -and
        ($_[1].StartsWith('Control — ', [StringComparison]::Ordinal) -or
         $_[1].StartsWith('Partial control — ', [StringComparison]::Ordinal))
    })
    $reasonedNa = @($naRows | Where-Object { $_[1].Substring(6).Trim().Length -ge 12 }).Count -gt 0
    $namedControlCited = $false
    foreach ($row in $mappedRows) {
        foreach ($name in $controlNames) {
            if ($row[1].Contains($name, [StringComparison]::Ordinal) -or
                $row[2].Contains($name, [StringComparison]::Ordinal)) {
                $namedControlCited = $true
            }
        }
    }
    if ($reasonedNa -and $mappedRows.Count -gt 0 -and $namedControlCited) {
        Ok "TEST-008: OWASP mapping includes reasoned N/A and existing named-control rows"
    } else {
        Fail "TEST-008: OWASP mapping needs both a reasoned N/A and an existing named control"
    }

    $mcpMatch = [regex]::Match(
        $threatModelText,
        '(?ms)^## MCP Security Cross-Reference\s*$(.*?)(?=^##\s|\z)')
    $mcpRows = @()
    if ($mcpMatch.Success) {
        $mcpRows = @($mcpMatch.Groups[1].Value -split "`r?`n" |
            Where-Object { $_ -match '^\|\s*(?:sdd-forge-mcp|local-env-mcp|ci-mcp)\s*\|' } |
            ForEach-Object { ,@($_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }) })
    }
    $expectedMcpNames = @('ci-mcp', 'local-env-mcp', 'sdd-forge-mcp')
    $actualMcpNames = @($mcpRows | ForEach-Object { $_[0] } | Sort-Object)
    $mcpRowsValid = $mcpRows.Count -eq 3 -and
        (($actualMcpNames -join ',') -ceq ($expectedMcpNames -join ',')) -and
        @($mcpRows | Where-Object {
            $_.Count -ne 4 -or -not $_[1] -or -not $_[2] -or
            -not $_[3].Contains('https://modelcontextprotocol.io/', [StringComparison]::Ordinal)
        }).Count -eq 0
    if ($mcpRowsValid) {
        Ok "TEST-013: all three MCP servers state trust posture and cite primary MCP guidance"
    } else {
        Fail "TEST-013: MCP cross-reference must cover three servers with posture and primary sources"
    }

    # ============================================================================
    # TEST-009 / TEST-010 / TEST-014: runtime trust surfaces and closed risk
    # ============================================================================
    Write-Host "=== TEST-009/010/014: runtime trust surfaces and closed risk ==="
    $runtimeMatch = [regex]::Match(
        $threatModelText,
        '(?ms)^## Runtime Trust Surfaces\s*$(.*?)(?=^##\s|\z)')
    $runtimeRows = @()
    if ($runtimeMatch.Success) {
        $runtimeRows = @($runtimeMatch.Groups[1].Value -split "`r?`n" |
            Where-Object { $_ -match '^\|' } |
            ForEach-Object { ,@($_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }) } |
            Where-Object { $_.Count -eq 4 })
    }
    $expectedRuntimeSurfaces = @(
        '--dangerously-bypass-hook-trust',
        'Claude Code settings/permissions',
        'claude-hooks.json',
        'hooks.state',
        'managed by sdd-forge installer'
    )
    $surfaceRows = @($runtimeRows | Where-Object {
        $expectedRuntimeSurfaces -ccontains $_[0].Trim('`')
    })
    $actualRuntimeSurfaces = @($surfaceRows | ForEach-Object { $_[0].Trim('`') } | Sort-Object)
    $runtimeRowsValid = $surfaceRows.Count -eq 5 -and
        (($actualRuntimeSurfaces -join ',') -ceq (($expectedRuntimeSurfaces | Sort-Object) -join ',')) -and
        @($surfaceRows | Where-Object {
            -not $_[1].StartsWith('Trust assumption — ', [StringComparison]::Ordinal) -or
            (-not $_[2].StartsWith('Mitigation — ', [StringComparison]::Ordinal) -and
             -not $_[2].StartsWith('Residual risk — ', [StringComparison]::Ordinal)) -or
            $_[3] -notmatch '`[^`]+:\d+(?:-\d+)?`'
        }).Count -eq 0
    if ($runtimeRowsValid) {
        Ok "TEST-009: five runtime surfaces each state trust assumption, mitigation or risk, and evidence"
    } else {
        Fail "TEST-009: runtime trust table must substantively cover all five surfaces"
    }

    $normalizedRuntime = if ($runtimeMatch.Success) {
        [regex]::Replace($runtimeMatch.Groups[1].Value, '\s+', ' ')
    } else { '' }
    $bypassValid = $normalizedRuntime.Contains(
            '--dangerously-bypass-hook-trust', [StringComparison]::Ordinal) -and
        $normalizedRuntime.Contains('first-run trust approval', [StringComparison]::Ordinal) -and
        $normalizedRuntime -match '(?i)forfeit\w*'
    if ($bypassValid) {
        Ok "TEST-010: hook-trust bypass explicitly states the first-run approval forfeited"
    } else {
        Fail "TEST-010: bypass flag must name what its operator forfeits"
    }

    $residualMatch = [regex]::Match(
        $threatModelText,
        '(?ms)^## Residual Risks\s*$(.*?)(?=^##\s|\z)')
    $normalizedResidual = if ($residualMatch.Success) {
        [regex]::Replace($residualMatch.Groups[1].Value, '\s+', ' ')
    } else { '' }
    $closedRiskValid = $normalizedResidual -match '(?i)unbounded external panelist' -and
        $normalizedResidual.Contains('closed by this feature', [StringComparison]::Ordinal) -and
        $normalizedResidual.Contains('SDD_PANELIST_TIMEOUT', [StringComparison]::Ordinal)
    if ($closedRiskValid) {
        Ok "TEST-014: unbounded external panelist risk is recorded as closed with its timeout control"
    } else {
        Fail "TEST-014: residual risks must record the closed unbounded-panelist risk"
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
