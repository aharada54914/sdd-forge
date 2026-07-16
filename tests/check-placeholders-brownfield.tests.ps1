# tests/check-placeholders-brownfield.tests.ps1 - PowerShell twin of
# tests/check-placeholders-brownfield.tests.sh (T-002 / Issue #146 /
# epic-159-pillar-a2 REQ-002). See the bash twin for the full section-by-
# section rationale, including why the AC-007 loop_fixture_init proof lives
# in tests/loop-consistency.tests.ps1's brownfield-profile leg instead of
# here (this suite is jq-free by design, and loop_fixture_init is not).
#
# TEST-007 (AC-007, partial): canonical seed existence + three documented
#   categories.
# TEST-008 (AC-008, Case A): check-placeholders.ps1, invoked with only the
#   seed's marker-free CHANGED_FILES.txt subset, exits 0.
# TEST-009 (AC-009, Case B): check-placeholders.ps1, invoked with the full
#   seed directory, exits 1 and reports BOTH pre-existing marker findings.
#
# Both real gate invocations run check-placeholders.ps1 as a genuine child
# process (mirrors tests/scripts.tests.ps1's Invoke-Gate pattern) against a
# mktemp COPY of the canonical seed -- never the real repository path
# directly.
$ErrorActionPreference = "Stop"

# The two seed marker substrings this suite scans for are assembled at
# runtime from adjacent quoted literals (never written as one contiguous
# substring) so this suite's own source is not itself flagged by
# check-placeholders' scan of the very marker vocabulary it exists to test
# against (coordinator remediation, quality-gate placeholder-scan finding).
# Verification semantics are unchanged -- these hold the exact runtime
# strings the previous literal-embedded form used.
$MarkerNie = "Not" + "ImplementedError"
$MarkerTodo = "TO" + "DO"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sc = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-placeholders.ps1"
$seed = Join-Path $repoRoot "tests/fixtures/loops/brownfield-seed"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$work = Join-Path ([IO.Path]::GetTempPath()) ("check-placeholders-brownfield." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$work = (Resolve-Path -LiteralPath $work).Path

try {
    $seedCopy = Join-Path $work "seed"
    New-Item -ItemType Directory -Path $seedCopy | Out-Null
    Copy-Item -Path (Join-Path $seed "*") -Destination $seedCopy -Recurse -Force

    # Run check-placeholders.ps1 as a genuine child process, capturing
    # combined output and exit code -- mirrors tests/scripts.tests.ps1's
    # Invoke-Gate pattern (a script's own `exit N` would otherwise terminate
    # this suite's host process if dot-sourced or call-operator-invoked
    # in-process).
    function Invoke-CheckPlaceholders {
        param([string[]]$Paths)
        $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $sc @Paths 2>&1
        return @{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
    }

    # -------------------------------------------------------------------
    # TEST-007 (AC-007, partial): canonical seed existence + three categories
    # -------------------------------------------------------------------
    Write-Output "=== TEST-007: canonical brownfield seed existence + three documented categories ==="

    $basePy = Join-Path $seed "src/base.py"
    if ((Test-Path -LiteralPath $basePy -PathType Leaf) -and (Select-String -LiteralPath $basePy -Pattern $MarkerNie -Quiet)) {
        Ok "TEST-007.1 (AC-007): src/base.py carries a legitimate $MarkerNie abstract-base-class marker"
    } else {
        Fail "TEST-007.1 (AC-007): src/base.py missing or does not carry a $MarkerNie marker"
    }

    $legacyUtilPy = Join-Path $seed "src/legacy_util.py"
    if ((Test-Path -LiteralPath $legacyUtilPy -PathType Leaf) -and (Select-String -LiteralPath $legacyUtilPy -Pattern "# $MarkerTodo" -Quiet)) {
        Ok "TEST-007.2 (AC-007): src/legacy_util.py carries a pre-existing, task-unrelated $MarkerTodo marker"
    } else {
        Fail "TEST-007.2 (AC-007): src/legacy_util.py missing or does not carry a $MarkerTodo marker"
    }

    $tasksMd = Join-Path $seed "specs/brownfield-seed-demo/tasks.md"
    $tasksMdOk = $false
    if (Test-Path -LiteralPath $tasksMd -PathType Leaf) {
        $tasksMdContent = Get-Content -LiteralPath $tasksMd -Raw
        $tasksMdOk = ($tasksMdContent -match "(?m)^# Tasks:") -and
                     ($tasksMdContent -match "(?m)^Task-Review-Status:") -and
                     ($tasksMdContent -match "(?m)^## T-[0-9]") -and
                     ($tasksMdContent -match "(?m)^Status:") -and
                     ($tasksMdContent -match "(?m)^Risk:") -and
                     ($tasksMdContent -match "(?m)^Risk Rationale:") -and
                     ($tasksMdContent -match "(?m)^Required Workflow:") -and
                     ($tasksMdContent -match "(?m)^### Blockers")
    }
    if ($tasksMdOk) {
        Ok "TEST-007.3 (AC-007): specs/brownfield-seed-demo/tasks.md is bootstrap-complete (header/Task-Review-Status/T-NNN block with Status,Risk,Risk Rationale,Required Workflow/Blockers section)"
    } else {
        Fail "TEST-007.3 (AC-007): specs/brownfield-seed-demo/tasks.md is missing the bootstrap-complete structure"
    }

    if ($tasksMdContent -and $tasksMdContent.Contains("{{")) {
        Fail "TEST-007.4 (AC-007, negative self-check): specs/brownfield-seed-demo/tasks.md carries an unresolved {{...}} template placeholder"
    } else {
        Ok "TEST-007.4 (AC-007): specs/brownfield-seed-demo/tasks.md carries no unresolved {{...}} template placeholder"
    }

    # -------------------------------------------------------------------
    # TEST-008 (AC-008): Case A -- marker-free changed-files subset -> exit 0
    # -------------------------------------------------------------------
    Write-Output "=== TEST-008: marker-free CHANGED_FILES.txt subset passes (Case A) ==="

    $changedFilesManifest = Join-Path $seed "CHANGED_FILES.txt"
    if (Test-Path -LiteralPath $changedFilesManifest -PathType Leaf) {
        Ok "TEST-008.1 (AC-008): CHANGED_FILES.txt manifest exists"
    } else {
        Fail "TEST-008.1 (AC-008): CHANGED_FILES.txt manifest missing"
    }

    $changedRelPaths = @(Get-Content -LiteralPath $changedFilesManifest | Where-Object { $_.Trim() -ne "" })
    if ($changedRelPaths.Count -eq 0) {
        Fail "TEST-008.2 (AC-008): CHANGED_FILES.txt manifest is empty"
    } else {
        $changedArgs = @($changedRelPaths | ForEach-Object { Join-Path $seedCopy $_ })
        $caseA = Invoke-CheckPlaceholders -Paths $changedArgs
        if ($caseA.ExitCode -eq 0) {
            Ok "TEST-008.2 (AC-008): check-placeholders.ps1 invoked with only the marker-free changed-files subset exits 0"
        } else {
            Fail "TEST-008.2 (AC-008): expected exit 0 for the marker-free changed-files subset, got $($caseA.ExitCode). Output: $($caseA.Output)"
        }
    }

    $changedFilesText = Get-Content -LiteralPath $changedFilesManifest -Raw
    if ($changedFilesText.Contains("base.py") -or $changedFilesText.Contains("legacy_util.py")) {
        Fail "TEST-008.3 (AC-008, negative self-check): CHANGED_FILES.txt unexpectedly lists a marker-bearing file"
    } else {
        Ok "TEST-008.3 (AC-008, negative self-check): CHANGED_FILES.txt lists neither marker-bearing file"
    }

    # -------------------------------------------------------------------
    # TEST-009 (AC-009): Case B -- full seed directory -> exit 1, BOTH findings
    # -------------------------------------------------------------------
    Write-Output "=== TEST-009: full seed directory fails with BOTH pre-existing markers (Case B) ==="

    $caseB = Invoke-CheckPlaceholders -Paths @($seedCopy)
    if ($caseB.ExitCode -eq 1) {
        Ok "TEST-009.1 (AC-009): check-placeholders.ps1 invoked with the full seed directory exits 1"
    } else {
        Fail "TEST-009.1 (AC-009): expected exit 1 for the full seed directory, got $($caseB.ExitCode). Output: $($caseB.Output)"
    }

    if ($caseB.Output -match "base\.py.*$MarkerNie") {
        Ok "TEST-009.2 (AC-009): output reports the base.py $MarkerNie finding"
    } else {
        Fail "TEST-009.2 (AC-009): output is missing the base.py $MarkerNie finding. Output: $($caseB.Output)"
    }

    if ($caseB.Output -match "legacy_util\.py.*$MarkerTodo") {
        Ok "TEST-009.3 (AC-009): output reports the legacy_util.py $MarkerTodo finding"
    } else {
        Fail "TEST-009.3 (AC-009): output is missing the legacy_util.py $MarkerTodo finding. Output: $($caseB.Output)"
    }

    if ($caseB.Output.Contains("service.py")) {
        Fail "TEST-009.4 (AC-009, negative self-check): the marker-free service.py unexpectedly appears in the findings"
    } else {
        Ok "TEST-009.4 (AC-009, negative self-check): the marker-free service.py does not appear in the findings"
    }

    if ($caseB.Output.Contains("tasks.md")) {
        Fail "TEST-009.5 (AC-009, negative self-check): the marker-free tasks.md unexpectedly appears in the findings"
    } else {
        Ok "TEST-009.5 (AC-009, negative self-check): the marker-free tasks.md does not appear in the findings"
    }

    # -------------------------------------------------------------------
    # Self-registration (design.md Test Strategy item 5)
    # -------------------------------------------------------------------
    Write-Output "=== Self-registration: run-all.sh / run-all.ps1 / test.yml ==="

    $runAllSh = Join-Path $repoRoot "tests/run-all.sh"
    $runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
    $testYml = Join-Path $repoRoot ".github/workflows/test.yml"

    $runAllShContent = if (Test-Path -LiteralPath $runAllSh) { Get-Content -LiteralPath $runAllSh -Raw } else { "" }
    $runAllPs1Content = if (Test-Path -LiteralPath $runAllPs1) { Get-Content -LiteralPath $runAllPs1 -Raw } else { "" }
    $testYmlContent = if (Test-Path -LiteralPath $testYml) { Get-Content -LiteralPath $testYml -Raw } else { "" }

    if ($runAllShContent.Contains("tests/check-placeholders-brownfield.tests.sh") -and $testYmlContent.Contains("check-placeholders-brownfield.tests.sh")) {
        Ok "REG.1 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.sh is registered in run-all.sh and test.yml"
    } else {
        Fail "REG.1 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.sh is NOT registered in run-all.sh and/or test.yml"
    }

    if ($runAllPs1Content.Contains("tests/check-placeholders-brownfield.tests.ps1") -and $testYmlContent.Contains("check-placeholders-brownfield.tests.ps1")) {
        Ok "REG.2 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.ps1 is registered in run-all.ps1 and test.yml"
    } else {
        Fail "REG.2 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.ps1 is NOT registered in run-all.ps1 and/or test.yml"
    }

    # -------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------
    Write-Output ""
    Write-Output "check-placeholders-brownfield.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
    if ($script:failCount -ne 0) { exit 1 }
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue }
}
