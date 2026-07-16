# tests/hitl-wfi-terminal.tests.ps1 - PowerShell twin of
# tests/hitl-wfi-terminal.tests.sh (T-001 / Issue #145 / epic-159-pillar-a2
# REQ-001). See the bash twin for the full checklist description; this
# file mirrors TEST-001..TEST-006 with full parity.
#
# HITL leg (TEST-001, TEST-002): the driven template
# (plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh)
# is a bash-only script, so this leg shells out to bash via a small wrapper
# script (written with a NoBOM encoding, since a leading BOM would break
# bash parsing) that defines CHECK and execs the fixture copy of the real
# template. Degrades to a named SKIP when bash is not on PATH (AC-017).
$ErrorActionPreference = "Stop"

$startEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot "tests/lib/loop-driver.ps1")

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$cleanupRoots = New-Object System.Collections.Generic.List[string]
try {

# ---------------------------------------------------------------------------
# WFI field helpers (plain field extraction/mutation; parser rule: an
# absent Audit-Attempt: field is treated as 0)
# ---------------------------------------------------------------------------
function Get-WfiAttempt {
    param([string]$Path)
    $match = Select-String -LiteralPath $Path -Pattern '^Audit-Attempt:' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($match) {
        $val = ($match.Line -replace '^Audit-Attempt:\s*', '').Trim()
        if ($val -ne "") { return $val }
    }
    return "0"
}

function Get-WfiStatus {
    param([string]$Path)
    $match = Select-String -LiteralPath $Path -Pattern '^Audit-Status:' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($match) { return ($match.Line -replace '^Audit-Status:\s*', '').Trim() }
    return ""
}

function Set-WfiField {
    param([string]$Path, [string]$Field, [string]$Value)
    $lines = Get-Content -LiteralPath $Path
    $pattern = "^$Field`:"
    $found = $false
    $newLines = @()
    foreach ($l in $lines) {
        if ($l -match $pattern) { $found = $true; $newLines += "$Field`: $Value" } else { $newLines += $l }
    }
    if (-not $found) { $newLines += "$Field`: $Value" }
    [System.IO.File]::WriteAllText($Path, (($newLines -join "`n") + "`n"), $utf8NoBom)
}

# Test-WfiAuditTransition -File <path> -Before <string> -Verdict <string>
#   -ExpectedAfter <string> -ExpectedStatus <string> [-Threshold <int>]
# See the bash twin's assert_wfi_audit_transition for the full contract.
function Test-WfiAuditTransition {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Before,
        [Parameter(Mandatory = $true)][string]$Verdict,
        [Parameter(Mandatory = $true)][string]$ExpectedAfter,
        [Parameter(Mandatory = $true)][string]$ExpectedStatus,
        [int]$Threshold = 3
    )
    if ($Verdict -ne "BLOCKED") {
        Write-Error "Test-WfiAuditTransition: only the BLOCKED verdict is modeled (SKILL.md STEP 4/7)"
        return $false
    }

    $lines = @("# WFI fixture (T-001, synthetic)", "Category: process", "Audit-Status: Not-Started")
    if ($Before -ne "") { $lines += "Audit-Attempt: $Before" }
    [System.IO.File]::WriteAllText($File, (($lines -join "`n") + "`n"), $utf8NoBom)

    $parsedBefore = [int](Get-WfiAttempt $File)
    $after = $parsedBefore + 1
    if ($after -ge $Threshold) { $status = "Human-Blocked" } else { $status = "Not-Started" }
    Set-WfiField -Path $File -Field "Audit-Attempt" -Value $after
    Set-WfiField -Path $File -Field "Audit-Status" -Value $status

    $actualAfter = Get-WfiAttempt $File
    $actualStatus = Get-WfiStatus $File
    return ($actualAfter -eq [string]$ExpectedAfter -and $actualStatus -eq $ExpectedStatus)
}

# ---------------------------------------------------------------------------
# TEST-001 / TEST-002 (AC-001 / AC-002): HITL cap-5 terminal behavior
# ---------------------------------------------------------------------------
Write-Output "=== TEST-001/TEST-002: HITL cap-5 terminal behavior (real template, fixture copy) ==="

$hitlTemplateReal = Join-Path $repoRoot "plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh"
$bashCmd = Get-Command bash -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $hitlTemplateReal)) {
    Fail "TEST-001 (AC-001): hitl-loop.template.sh not found at $hitlTemplateReal"
    Fail "TEST-002 (AC-002): hitl-loop.template.sh not found at $hitlTemplateReal"
} elseif (-not $bashCmd) {
    Write-Output "SKIP: TEST-001/TEST-002 bash not found on PATH; the HITL leg drives a bash-only real template and cannot run natively in PowerShell (AC-017 recorded degradation)."
} else {
    $hitlRoot = Join-Path ([IO.Path]::GetTempPath()) ("hitl-wfi-terminal-hitl." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $hitlRoot | Out-Null
    $hitlRoot = (Resolve-Path -LiteralPath $hitlRoot).Path
    $cleanupRoots.Add($hitlRoot)

    $hitlCopy = Join-Path $hitlRoot "hitl-loop.template.sh"
    Copy-Item -LiteralPath $hitlTemplateReal -Destination $hitlCopy

    $stdinFive = ("`n" * 5)

    # TEST-001 (AC-001): CHECK never returns true -> 5 iterations, exit 0.
    $wrapper1 = Join-Path $hitlRoot "hitl-wrapper-never.sh"
    $wrapper1Content = 'CHECK() { return 1; }' + "`n" + 'export -f CHECK' + "`n" + ('exec bash "' + $hitlCopy + '" 5') + "`n"
    [System.IO.File]::WriteAllText($wrapper1, $wrapper1Content, $utf8NoBom)

    $out1 = $stdinFive | & bash $wrapper1 2>&1
    $rc1 = $LASTEXITCODE
    $out1Text = ($out1 -join "`n")
    $iterCount1 = ([regex]::Matches($out1Text, '(?m)^\[HITL loop\] iteration ')).Count
    if ($rc1 -eq 0 -and $iterCount1 -eq 5 -and $out1Text.Contains("loop finished without reproducing (5 iterations)")) {
        Ok "TEST-001 (AC-001): never-reproducing CHECK completes exactly 5 iterations, exits 0, prints the terminal string"
    } else {
        Fail "TEST-001 (AC-001): expected 5 iterations/exit 0/terminal string, got rc=$rc1 iterations=$iterCount1"
    }

    # TEST-002 (AC-002): CHECK returns true on iteration 3 -> immediate exit 1.
    $counterFile = Join-Path $hitlRoot "hitl-check-counter.txt"
    [System.IO.File]::WriteAllText($counterFile, "0", $utf8NoBom)
    $checkBody = @'
CHECK() {
  n=$(cat "$COUNTER_FILE")
  n=$((n + 1))
  printf '%s' "$n" > "$COUNTER_FILE"
  [ "$n" -eq 3 ]
}
export -f CHECK
'@
    $counterLine = 'export COUNTER_FILE="' + $counterFile + '"'
    $execLine = 'exec bash "' + $hitlCopy + '" 5'
    $wrapper2 = Join-Path $hitlRoot "hitl-wrapper-repro3.sh"
    $wrapper2Content = $counterLine + "`n" + $checkBody + "`n" + $execLine + "`n"
    [System.IO.File]::WriteAllText($wrapper2, $wrapper2Content, $utf8NoBom)

    $out2 = $stdinFive | & bash $wrapper2 2>&1
    $rc2 = $LASTEXITCODE
    $out2Text = ($out2 -join "`n")
    $iterCount2 = ([regex]::Matches($out2Text, '(?m)^\[HITL loop\] iteration ')).Count
    if ($rc2 -eq 1 -and $iterCount2 -eq 3 -and $out2Text.Contains("RED: symptom reproduced on iteration 3")) {
        Ok "TEST-002 (AC-002): CHECK returning true on iteration 3 exits 1 immediately with the RED canary message"
    } else {
        Fail "TEST-002 (AC-002): expected an immediate exit 1 at iteration 3 with the RED canary message, got rc=$rc2 iterations=$iterCount2"
    }
}

# ---------------------------------------------------------------------------
# TEST-003 (AC-003): WFI-audit one-directional sweep, 0 -> 1 -> 2 -> 3
# ---------------------------------------------------------------------------
Write-Output "=== TEST-003: WFI-audit one-directional sweep (Audit-Attempt 0 -> 1 -> 2 -> 3) ==="

$wfiRoot = Join-Path ([IO.Path]::GetTempPath()) ("hitl-wfi-terminal-audit." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $wfiRoot | Out-Null
$wfiRoot = (Resolve-Path -LiteralPath $wfiRoot).Path
$cleanupRoots.Add($wfiRoot)
$wfiFixture = Join-Path $wfiRoot "WFI-900.md"

if (Test-WfiAuditTransition -File $wfiFixture -Before "" -Verdict "BLOCKED" -ExpectedAfter "1" -ExpectedStatus "Not-Started") {
    Ok "TEST-003.1 (AC-003): Audit-Attempt absent (=0), BLOCKED -> Audit-Attempt 1, Audit-Status Not-Started"
} else {
    Fail "TEST-003.1 (AC-003): Audit-Attempt absent (=0), BLOCKED transition mismatch"
}

if (Test-WfiAuditTransition -File $wfiFixture -Before "1" -Verdict "BLOCKED" -ExpectedAfter "2" -ExpectedStatus "Not-Started") {
    Ok "TEST-003.2 (AC-003): Audit-Attempt 1, BLOCKED -> Audit-Attempt 2, Audit-Status Not-Started"
} else {
    Fail "TEST-003.2 (AC-003): Audit-Attempt 1, BLOCKED transition mismatch"
}

if (Test-WfiAuditTransition -File $wfiFixture -Before "2" -Verdict "BLOCKED" -ExpectedAfter "3" -ExpectedStatus "Human-Blocked") {
    Ok "TEST-003.3 (AC-003): Audit-Attempt 2, BLOCKED -> Audit-Attempt 3, Audit-Status Human-Blocked (convergence guard)"
} else {
    Fail "TEST-003.3 (AC-003): Audit-Attempt 2, BLOCKED transition mismatch"
}

# Negative self-check: mutate the threshold from 3 to 4 while still
# demanding the SAME correct Human-Blocked outcome for Audit-Attempt 2 -> 3.
if (Test-WfiAuditTransition -File $wfiFixture -Before "2" -Verdict "BLOCKED" -ExpectedAfter "3" -ExpectedStatus "Human-Blocked" -Threshold 4) {
    Fail "TEST-003.4 (AC-003, negative self-check): mutating the threshold to 4 did NOT turn the attempt-3 assertion red"
} else {
    Ok "TEST-003.4 (AC-003, negative self-check): mutating the threshold to 4 turns the attempt-3 assertion red, proving the check is live"
}

# ---------------------------------------------------------------------------
# TEST-004 (AC-004): construction proof
# ---------------------------------------------------------------------------
Write-Output "=== TEST-004: no remote-CLI invocation + Category construction proof ==="

$selfSh = Join-Path $repoRoot "tests/hitl-wfi-terminal.tests.sh"
$selfPs1 = Join-Path $repoRoot "tests/hitl-wfi-terminal.tests.ps1"

# Built at runtime (not embedded literally) so this very check line does
# not match its own pattern.
$noCliToken = -join @([char]103, [char]104, [char]32)
$cliMatch = $false
foreach ($f in @($selfSh, $selfPs1)) {
    if (Test-Path -LiteralPath $f) {
        $content = Get-Content -LiteralPath $f -Raw
        if ($content.Contains($noCliToken)) { $cliMatch = $true }
    }
}
if (-not $cliMatch) {
    Ok "TEST-004.1 (AC-004): neither new file in this feature invokes the remote issue-tracker CLI"
} else {
    Fail "TEST-004.1 (AC-004): a remote issue-tracker CLI invocation was found in a new file"
}

$categoryMatch = Select-String -LiteralPath $wfiFixture -Pattern '^Category:' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($categoryMatch) { $wfiFixtureCategory = ($categoryMatch.Line -replace '^Category:\s*', '').Trim() } else { $wfiFixtureCategory = "" }
if ($wfiFixtureCategory -eq "process") {
    Ok "TEST-004.2 (AC-004): WFI-audit fixture Category is process, keeping SKILL.md STEP 8 a documented no-op by construction"
} else {
    Fail "TEST-004.2 (AC-004): WFI-audit fixture Category is $wfiFixtureCategory, not the expected process value"
}

# ---------------------------------------------------------------------------
# TEST-005 (AC-005): real-document read-only smoke
# ---------------------------------------------------------------------------
Write-Output "=== TEST-005: WFI-010.md / WFI-011.md read-only smoke ==="

$realWfi010 = Join-Path $repoRoot "docs/workflow-improvements/WFI-010.md"
$realWfi011 = Join-Path $repoRoot "docs/workflow-improvements/WFI-011.md"

function Test-RealDocInvariant {
    param([string]$Path, [string]$Label)
    $attempt = [int](Get-WfiAttempt $Path)
    $status = Get-WfiStatus $Path
    if ($attempt -ge 3) {
        if ($status -eq "Human-Blocked") {
            Ok "TEST-005 (AC-005): $Label Audit-Attempt=$attempt (>=3) and Audit-Status=Human-Blocked -- invariant holds"
        } else {
            Fail "TEST-005 (AC-005): $Label Audit-Attempt=$attempt (>=3) but Audit-Status=$status -- invariant violated"
        }
    } else {
        if ($status -ne "Human-Blocked") {
            Ok "TEST-005 (AC-005): $Label Audit-Attempt=$attempt (<3) and Audit-Status=$status -- invariant holds"
        } else {
            Fail "TEST-005 (AC-005): $Label Audit-Attempt=$attempt (<3) but Audit-Status=Human-Blocked -- invariant violated"
        }
    }
}

if ((Test-Path -LiteralPath $realWfi010) -and (Test-Path -LiteralPath $realWfi011)) {
    $sha010Before = Get-LoopSha256 $realWfi010
    $sha011Before = Get-LoopSha256 $realWfi011

    $smoke010 = Join-Path $wfiRoot "WFI-010.md"
    $smoke011 = Join-Path $wfiRoot "WFI-011.md"
    Copy-Item -LiteralPath $realWfi010 -Destination $smoke010
    Copy-Item -LiteralPath $realWfi011 -Destination $smoke011

    Test-RealDocInvariant -Path $smoke010 -Label "WFI-010.md"
    Test-RealDocInvariant -Path $smoke011 -Label "WFI-011.md"

    $sha010After = Get-LoopSha256 $realWfi010
    $sha011After = Get-LoopSha256 $realWfi011
    if ($sha010Before -eq $sha010After) {
        Ok "TEST-005 (AC-005): WFI-010.md SHA-256 unchanged before vs. after this suite run"
    } else {
        Fail "TEST-005 (AC-005): WFI-010.md SHA-256 changed during this suite run"
    }
    if ($sha011Before -eq $sha011After) {
        Ok "TEST-005 (AC-005): WFI-011.md SHA-256 unchanged before vs. after this suite run"
    } else {
        Fail "TEST-005 (AC-005): WFI-011.md SHA-256 changed during this suite run"
    }
} else {
    Fail "TEST-005 (AC-005): docs/workflow-improvements/WFI-010.md and/or WFI-011.md not found"
}

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): self-registration + runtime budget
# ---------------------------------------------------------------------------
Write-Output "=== TEST-006: self-registration + runtime budget (LOOP_SUITE_BUDGET_SECONDS=$($script:LoopSuiteBudgetSeconds)) ==="

$runAllSh = Join-Path $repoRoot "tests/run-all.sh"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
$testYml = Join-Path $repoRoot ".github/workflows/test.yml"

$runAllShContent = if (Test-Path -LiteralPath $runAllSh) { Get-Content -LiteralPath $runAllSh -Raw } else { "" }
$runAllPs1Content = if (Test-Path -LiteralPath $runAllPs1) { Get-Content -LiteralPath $runAllPs1 -Raw } else { "" }
$testYmlContent = if (Test-Path -LiteralPath $testYml) { Get-Content -LiteralPath $testYml -Raw } else { "" }

if ($runAllShContent.Contains("tests/hitl-wfi-terminal.tests.sh") -and $testYmlContent.Contains("hitl-wfi-terminal.tests.sh")) {
    Ok "TEST-006.1 (AC-006): hitl-wfi-terminal.tests.sh is registered in run-all.sh and test.yml"
} else {
    Fail "TEST-006.1 (AC-006): hitl-wfi-terminal.tests.sh is NOT registered in run-all.sh and/or test.yml"
}

if ($runAllPs1Content.Contains("tests/hitl-wfi-terminal.tests.ps1") -and $testYmlContent.Contains("hitl-wfi-terminal.tests.ps1")) {
    Ok "TEST-006.2 (AC-006): hitl-wfi-terminal.tests.ps1 is registered in run-all.ps1 and test.yml"
} else {
    Fail "TEST-006.2 (AC-006): hitl-wfi-terminal.tests.ps1 is NOT registered in run-all.ps1 and/or test.yml"
}

$syntheticPastEpoch = $startEpoch - 1
if (Test-RuntimeBudget -Start $syntheticPastEpoch -Budget 0) {
    Fail "TEST-006.3 (AC-006, negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
} else {
    Ok "TEST-006.3 (AC-006, negative self-check): forcing the runtime budget to 0 turns the assertion red"
}

$elapsedSeconds = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $startEpoch
if (Test-RuntimeBudget -Start $startEpoch) {
    Ok "TEST-006.4 (AC-006): suite completed within the $($script:LoopSuiteBudgetSeconds)s runtime budget"
} else {
    Fail "TEST-006.4 (AC-006): suite exceeded the $($script:LoopSuiteBudgetSeconds)s runtime budget"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Output ""
Write-Output "hitl-wfi-terminal.tests.ps1: $($script:passCount) passed, $($script:failCount) failed, ${elapsedSeconds}s elapsed"
if ($script:failCount -ne 0) { exit 1 }
exit 0

} finally {
    foreach ($d in $cleanupRoots) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
    }
}
