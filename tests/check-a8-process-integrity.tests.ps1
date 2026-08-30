# Acceptance driver for REQ-006/REQ-007 (TEST-025, TEST-029, TEST-030).
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $root 'plugins/sdd-quality-loop/scripts'
$feature = Join-Path $root 'specs/epic-196-a8-integration'
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("a8-process-integrity-" + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tempDir)
$script:passed = 0
$script:failed = 0

function Invoke-Check {
    param([string]$Command, [string[]]$Arguments)
    $output = & $Command @Arguments 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Expect-Pass {
    param([string]$Label, [string]$Command, [string[]]$Arguments)
    $result = Invoke-Check -Command $Command -Arguments $Arguments
    if ($result.ExitCode -ceq 0) {
        Write-Output "PASS: $Label"
        $script:passed++
    } else {
        Write-Output "FAIL: $Label (exit $($result.ExitCode))"
        Write-Output $result.Output
        $script:failed++
    }
}

function Expect-Reject {
    param([string]$Label, [string]$Command, [string[]]$Arguments)
    $result = Invoke-Check -Command $Command -Arguments $Arguments
    if (($result.ExitCode -cne 0) -and ($result.Output -cmatch '(?m)^missing: ')) {
        Write-Output "PASS: $Label"
        $script:passed++
    } else {
        Write-Output "FAIL: $Label (mutated fixture was not rejected with a missing: diagnostic)"
        Write-Output $result.Output
        $script:failed++
    }
}

try {
    $designMissing = Join-Path $tempDir 'design-missing.md'
    $designAmbiguous = Join-Path $tempDir 'design-ambiguous.md'
    $designDuplicate = Join-Path $tempDir 'design-duplicate.md'
    $designMalformed = Join-Path $tempDir 'design-malformed.md'
    $requirementsScope = Join-Path $tempDir 'requirements-scope.md'
    $designUncited = Join-Path $tempDir 'design-uncited.md'

    $design = [IO.File]::ReadAllText((Join-Path $feature 'design.md'))
    $missingLines = $design -split "`n" | Where-Object { $_ -cnotmatch 'Fixture Contract table definition \(AC-001\)' }
    [IO.File]::WriteAllText($designMissing, (($missingLines -join "`n").TrimEnd("`r", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    $ambiguousPattern = [regex]::new('\| automated \|', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    $ambiguousText = $ambiguousPattern.Replace($design, '| automated / manual-required |', 1)
    [IO.File]::WriteAllText($designAmbiguous, $ambiguousText, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($designDuplicate, $design.Replace("`n## Path/Line-Ending Regression Matrix", "`n## Automated / Manual Classification Table (REQ-006; AC-025)`n`n## Path/Line-Ending Regression Matrix"), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($designMalformed, $design.Replace('| Fixture Contract table definition (AC-001) | automated | — |', '| Fixture Contract table definition (AC-001) | automated — |'), [Text.UTF8Encoding]::new($false))

    $requirements = [IO.File]::ReadAllText((Join-Path $feature 'requirements.md'))
    $scopeMutation = "`n  Epic A8 will build for ``epic-195-a7-compatibility`` the new ``check-a7-owned-surface.sh`` / ``check-a7-owned-surface.ps1`` pair, plugin hook config ``plugins/a7/windows-hooks.json``, and environment-specific test ``tests/a7-windows.tests.ps1``.`n"
    [IO.File]::WriteAllText($requirementsScope, $requirements.Replace("`n- AC-029:", $scopeMutation + "`n- AC-029:"), [Text.UTF8Encoding]::new($false))

    $claimMutation = "`ninstall.sh currently accepts six targets.`n"
    [IO.File]::WriteAllText($designUncited, $design.Replace("`n## Automated / Manual Classification Table", $claimMutation + "`n## Automated / Manual Classification Table"), [Text.UTF8Encoding]::new($false))

    $classification = Join-Path $scripts 'check-a8-classification-table.ps1'
    $scope = Join-Path $scripts 'check-a8-scope-boundary.ps1'
    $citation = Join-Path $scripts 'check-a8-citation-compliance.ps1'

    if ($env:A8_PROCESS_CHECK_MODE -ceq 'red') {
        $redInvalid = 0
        $redCases = @(
            @('TEST-025 missing row', $classification, @($designMissing)),
            @('TEST-025 ambiguous row', $classification, @($designAmbiguous)),
            @('TEST-029 foreign-Epic artifact', $scope, @($requirementsScope)),
            @('TEST-030 uncited claim', $citation, @((Join-Path $feature 'investigation.md'), (Join-Path $feature 'requirements.md'), $designUncited))
        )
        foreach ($case in $redCases) {
            $result = Invoke-Check -Command $case[1] -Arguments $case[2]
            if (($result.ExitCode -cne 0) -and ($result.Output -cmatch '(?m)^missing: ')) {
                Write-Output "RED: $($case[0]) rejected (exit $($result.ExitCode))"
                Write-Output $result.Output.TrimEnd()
            } else {
                Write-Output "INVALID RED: $($case[0]) was not rejected with a missing: diagnostic"
                Write-Output $result.Output
                $redInvalid++
            }
        }
        if ($redInvalid -cne 0) { exit 2 }
        Write-Output 'RED: all required mutated fixtures were rejected; exiting non-zero by design'
        exit 1
    }

    Expect-Pass 'TEST-025 real classification table' $classification @((Join-Path $feature 'design.md'))
    Expect-Reject 'TEST-025 missing classification row' $classification @($designMissing)
    Expect-Reject 'TEST-025 ambiguous classification row' $classification @($designAmbiguous)
    Expect-Reject 'TEST-025 duplicate classification table' $classification @($designDuplicate)
    Expect-Reject 'TEST-025 malformed classification row' $classification @($designMalformed)
    Expect-Pass 'TEST-029 real scope boundary' $scope @((Join-Path $feature 'requirements.md'))
    Expect-Reject 'TEST-029 foreign-Epic artifact mutation' $scope @($requirementsScope)
    Expect-Pass 'TEST-030 real citation compliance' $citation @((Join-Path $feature 'investigation.md'), (Join-Path $feature 'requirements.md'), (Join-Path $feature 'design.md'))
    Expect-Reject 'TEST-030 uncited factual-claim mutation' $citation @((Join-Path $feature 'investigation.md'), (Join-Path $feature 'requirements.md'), $designUncited)

    if ($true) {
        $expectedSh = @('cross-runtime-handoff', 'check-installed-plugin-drift', 'install-uninstall-matrix', 'validate-live-host-proof', 'path-lineending-regression', 'check-a8-process-integrity')
        $expectedPs1 = @('cross-runtime-handoff', 'check-installed-plugin-drift', 'install-uninstall-matrix', 'validate-live-host-proof', 'path-lineending-regression', 'check-a8-process-integrity', 'cli-hook-enforcement')
        $runAllSh = [IO.File]::ReadAllText((Join-Path $root 'tests/run-all.sh'))
        $runAllPs1 = [IO.File]::ReadAllText((Join-Path $root 'tests/run-all.ps1'))
        foreach ($suite in $expectedSh) {
            $count = ([regex]::Matches($runAllSh, [regex]::Escape("tests/$suite.tests.sh"))).Count
            if ($count -cne 1) { Write-Output "FAIL: registration tests/$suite.tests.sh count=$count"; $script:failed++ }
        }
        foreach ($suite in $expectedPs1) {
            $name = if ($suite -ceq 'cli-hook-enforcement') { "tests/$suite.ps1" } else { "tests/$suite.tests.ps1" }
            $count = ([regex]::Matches($runAllPs1, [regex]::Escape($name))).Count
            if ($count -cne 1) { Write-Output "FAIL: PowerShell registration $name count=$count"; $script:failed++ }
        }
        $cliHookShCount = ([regex]::Matches($runAllSh, [regex]::Escape('tests/cli-hook-enforcement.ps1'))).Count
        if ($cliHookShCount -cne 1) { Write-Output "FAIL: POSIX aggregate registration cli-hook-enforcement count=$cliHookShCount"; $script:failed++ }
        $workflowPath = Join-Path $feature 'human-copy/.github/workflows/test.yml'
        $workflow = [IO.File]::ReadAllText($workflowPath)
        foreach ($suite in $expectedSh) {
            if (-not $workflow.Contains("tests/$suite.tests.sh")) { Write-Output "FAIL: staged CI missing $suite bash step"; $script:failed++ }
            if (-not $workflow.Contains("tests/$suite.tests.ps1")) { Write-Output "FAIL: staged CI missing $suite pwsh step"; $script:failed++ }
        }
        if (-not $workflow.Contains('tests/cli-hook-enforcement.ps1')) { Write-Output 'FAIL: staged CI missing cli-hook-enforcement'; $script:failed++ }
        $manifest = [IO.File]::ReadAllText((Join-Path $feature 'human-copy/MANIFEST.sha256'))
        $manifestMatch = [regex]::Match($manifest, '(?m)^([0-9a-f]{64})  \.github/workflows/test\.yml$')
        $actualHash = (Get-FileHash -Algorithm SHA256 $workflowPath).Hash.ToLowerInvariant()
        if ((-not $manifestMatch.Success) -or ($manifestMatch.Groups[1].Value -cne $actualHash)) { Write-Output 'FAIL: staged workflow manifest mismatch'; $script:failed++ }
        $versionDiff = & git -C $root diff HEAD -- . ':!scripts/bump-version.sh' | Out-String
        if ($versionDiff -cmatch '(?m)^\+[^+].*(VERSION|version)[^0-9]*[0-9]+\.[0-9]+\.[0-9]+') { Write-Output 'FAIL: version string changed outside scripts/bump-version.sh'; $script:failed++ }
    }

    Write-Output "check-a8-process-integrity: $script:passed passed, $script:failed failed"
    if ($script:failed -cne 0) { exit 1 }
    exit 0
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
