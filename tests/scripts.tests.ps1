$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Behavioral tests for the deterministic gate scripts (PowerShell variants).
# The POSIX variants are covered by the same fixtures when bash is available.

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts"
$templatesDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/templates"
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-script-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null

function Invoke-Gate {
    param([string]$Script, [string[]]$Arguments)
    $script:gateOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir $Script) @Arguments 2>&1
    return $LASTEXITCODE
}

function Assert-ExitCode {
    param([string]$Name, [int]$Actual, [int]$Expected)
    if ($Actual -ne $Expected) {
        $details = ($script:gateOutput | Out-String).Trim()
        throw "$Name expected exit $Expected but got $Actual`n$details"
    }
    Write-Host "ok: $Name"
}

function Get-Sha256Hex {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function New-ArtifactEntry {
    param([string]$Path)
    return [ordered]@{
        path = $Path
        sha256 = (Get-Sha256Hex -Path $Path)
    }
}

Push-Location $workDir
try {
    # --- check-task-state ---
    New-Item -ItemType Directory -Path "reports/quality-gate" -Force | Out-Null
    New-Item -ItemType Directory -Path "reports/implementation" -Force | Out-Null
    New-Item -ItemType Directory -Path "verification" -Force | Out-Null

    # Initialise a local git repo so check-evidence-bundle can verify git_commit binding.
    & git init -q . 2>&1 | Out-Null
    & git config user.name ci
    & git config user.email ci@example.com
    & git config commit.gpgsign false

    # tasks-good.md: T-001 is Done (needs quality-gate report + contract + evidence bundle), T-002 is Planned
    @"
# Tasks: demo
## T-001 First
Approval: Approved
Status: Done
## T-002 Second
Approval: Draft
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-good.md"
    @"
Task ID: T-001
VERDICT: PASS
quality gate report for T-001
"@ | Set-Content -Encoding Utf8 "reports/quality-gate/r1.md"
    "pass evidence for T-001" | Set-Content -Encoding Utf8 "verification/T-001.evidence.log"
    $taskOneContract = Get-Content -Raw -Encoding Utf8 (Join-Path $templatesDir "verification-contract.template.json") | ConvertFrom-Json
    $taskOneContract.task_id = "T-001"
    foreach ($check in $taskOneContract.checks) {
        if ($check.required) {
            $check.passes = $true
            $check.evidence = "verification/T-001.evidence.log"
        } else {
            $check | Add-Member -NotePropertyName waiver_reason -NotePropertyValue "not applicable to this demo" -Force
        }
    }
    $taskOneContract | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "verification/T-001.contract.json"

    # Commit all fixture files so we have a real HEAD commit for git_commit binding
    & git add -A 2>&1 | Out-Null
    & git commit -q -m "scripts.tests.ps1 initial fixture" 2>&1 | Out-Null
    $fixtureGitCommit = (& git rev-parse HEAD).Trim()

    $taskOneBundle = [ordered]@{
        task_id = "T-001"
        quality_report = "reports/quality-gate/r1.md"
        verification_contract = "verification/T-001.contract.json"
        git_commit = $fixtureGitCommit
        git_generated_dirty = $false
        artifacts = @(
            (New-ArtifactEntry "verification/T-001.contract.json"),
            (New-ArtifactEntry "reports/quality-gate/r1.md"),
            (New-ArtifactEntry "verification/T-001.evidence.log")
        )
    }
    $taskOneBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "verification/T-001.evidence.json"

    @"
## T-001 First
Approval: Draft
Status: In Progress
## T-002 Second
Approval: Approved
Status: Done
"@ | Set-Content -Encoding Utf8 "tasks-bad.md"

    Assert-ExitCode "check-task-state good" (Invoke-Gate "check-task-state.ps1" @("tasks-good.md", "-ReportsDir", "reports/quality-gate")) 0
    Assert-ExitCode "check-task-state bad" (Invoke-Gate "check-task-state.ps1" @("tasks-bad.md", "-ReportsDir", "reports/quality-gate")) 1

    # --- check-contract ---
    $templatePath = Join-Path $templatesDir "verification-contract.template.json"
    Assert-ExitCode "check-contract default-fail template" (Invoke-Gate "check-contract.ps1" @($templatePath, "-RepoRoot", ".")) 1

    $contract = Get-Content -Raw -Encoding Utf8 $templatePath | ConvertFrom-Json
    "evidence log" | Set-Content -Encoding Utf8 "ev.log"
    foreach ($check in $contract.checks) {
        if ($check.required) {
            $check.passes = $true
            $check.evidence = "ev.log"
        } else {
            # Required:false + passes:false must have non-empty waiver_reason
            $check | Add-Member -NotePropertyName waiver_reason -NotePropertyValue "not applicable to this project" -Force
        }
    }
    $contract | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-good.json"
    Assert-ExitCode "check-contract passing" (Invoke-Gate "check-contract.ps1" @("contract-good.json", "-RepoRoot", ".")) 0

    $contract.checks[0].evidence = "missing.log"
    $contract | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-badev.json"
    Assert-ExitCode "check-contract missing evidence" (Invoke-Gate "check-contract.ps1" @("contract-badev.json", "-RepoRoot", ".")) 1

    # --- check-placeholders ---
    New-Item -ItemType Directory -Path "src" -Force | Out-Null
    "def f():`n    pass  # TODO implement" | Set-Content -Encoding Utf8 "src/dirty.py"
    "clean = 1" | Set-Content -Encoding Utf8 "src/clean.py"
    Assert-ExitCode "check-placeholders dirty" (Invoke-Gate "check-placeholders.ps1" @("src/dirty.py")) 1
    Assert-ExitCode "check-placeholders clean" (Invoke-Gate "check-placeholders.ps1" @("src/clean.py")) 0

    # guard-task-approval.ps1 was superseded by sdd-hook-guard; guard tests live in hooks.tests.ps1.

    # =========================================================
    # check-placeholders case-insensitivity (Wave 2)
    # =========================================================
    # Lowercase "todo" must be flagged by the PS1 variant (grep -i added in Wave 1).
    "def f():`n    pass  # todo implement this" | Set-Content -Encoding Utf8 "src/todo-lower.py"
    Assert-ExitCode "check-placeholders ps1 lowercase todo flagged" (Invoke-Gate "check-placeholders.ps1" @("src/todo-lower.py")) 1

    # =========================================================
    # check-task-state header-only task (Wave 2)
    # =========================================================
    # A '## T-1' header with no Approval:/Status: lines must produce per-field errors
    # (not "no tasks found") and exit 1.
    @"
## T-1 Header only task
"@ | Set-Content -Encoding Utf8 "tasks-header-only.md"
    $headerOnlyOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-task-state.ps1") "tasks-header-only.md" 2>&1
    $headerOnlyExit = $LASTEXITCODE
    Assert-ExitCode "check-task-state header-only exits 1" $headerOnlyExit 1
    $headerOnlyStr = ($headerOnlyOutput | Out-String)
    if ($headerOnlyStr -match "no tasks found") {
        throw "check-task-state header-only must produce per-field errors, not 'no tasks found'"
    }
    if ($headerOnlyStr -notmatch "Approval" -and $headerOnlyStr -notmatch "Status") {
        throw "check-task-state header-only must report per-field errors (Approval/Status)"
    }
    Write-Host "ok: check-task-state header-only produces per-field errors"

    # =========================================================
    # NEW RULES: check-contract
    # =========================================================

    # -- Duplicate check ids → exit 1, listing them --
    $dupContract = $contract | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    # Re-read good contract as base and add a duplicate
    $goodContract = Get-Content -Raw -Encoding Utf8 "contract-good.json" | ConvertFrom-Json
    $dupEntry = $goodContract.checks[0] | ConvertTo-Json | ConvertFrom-Json
    $newChecks = @($goodContract.checks) + @($dupEntry)
    $goodContract | Add-Member -NotePropertyName checks -NotePropertyValue $newChecks -Force
    $goodContract | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-dup-ids.json"
    Assert-ExitCode "check-contract duplicate ids" (Invoke-Gate "check-contract.ps1" @("contract-dup-ids.json", "-RepoRoot", ".")) 1

    # -- Evidence path safety: ../outside.log → exit 1 --
    $escapeContract = Get-Content -Raw -Encoding Utf8 "contract-good.json" | ConvertFrom-Json
    $escapeContract.checks[0].evidence = "../outside.log"
    $escapeContract | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-escape.json"
    Assert-ExitCode "check-contract evidence escapes root" (Invoke-Gate "check-contract.ps1" @("contract-escape.json", "-RepoRoot", ".")) 1

    # -- Evidence path safety: absolute path → exit 1 --
    $absContract = Get-Content -Raw -Encoding Utf8 "contract-good.json" | ConvertFrom-Json
    $absContract.checks[0].evidence = "/etc/passwd"
    $absContract | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-abs.json"
    Assert-ExitCode "check-contract absolute evidence path" (Invoke-Gate "check-contract.ps1" @("contract-abs.json", "-RepoRoot", ".")) 1

    # -- required:false + passes:false + empty waiver_reason → exit 1 --
    $waiverBad = Get-Content -Raw -Encoding Utf8 "contract-good.json" | ConvertFrom-Json
    # Find an optional check and clear its waiver_reason
    $optCheck = $waiverBad.checks | Where-Object { -not $_.required } | Select-Object -First 1
    $optCheck.waiver_reason = ""
    $waiverBad | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-waiver-bad.json"
    Assert-ExitCode "check-contract optional no-waiver fails" (Invoke-Gate "check-contract.ps1" @("contract-waiver-bad.json", "-RepoRoot", ".")) 1

    # -- required:false + passes:false + non-empty waiver_reason → exit 0 --
    Assert-ExitCode "check-contract optional with-waiver passes" (Invoke-Gate "check-contract.ps1" @("contract-good.json", "-RepoRoot", ".")) 0

    # -- Baseline id removed → exit 1 --
    $removedBaseline = Get-Content -Raw -Encoding Utf8 "contract-good.json" | ConvertFrom-Json
    $removedBaseline.checks = @($removedBaseline.checks | Where-Object { $_.id -ne "lint" })
    $removedBaseline | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-no-lint.json"
    Assert-ExitCode "check-contract baseline id removed" (Invoke-Gate "check-contract.ps1" @("contract-no-lint.json", "-RepoRoot", ".")) 1

    # -- Baseline id downgraded to required:false without waiver_reason → exit 1 --
    $downgradedBad = Get-Content -Raw -Encoding Utf8 "contract-good.json" | ConvertFrom-Json
    $lintCheck = $downgradedBad.checks | Where-Object { $_.id -eq "lint" } | Select-Object -First 1
    $lintCheck.required = $false
    $lintCheck.waiver_reason = ""
    # lint is passes=true, so waiver enforcement doesn't apply, but baseline downgrade rule does
    $downgradedBad | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-downgrade-bad.json"
    Assert-ExitCode "check-contract baseline downgrade no-waiver fails" (Invoke-Gate "check-contract.ps1" @("contract-downgrade-bad.json", "-RepoRoot", ".")) 1

    # -- Baseline id downgraded to required:false WITH waiver_reason → exit 0 --
    $downgradedGood = Get-Content -Raw -Encoding Utf8 "contract-good.json" | ConvertFrom-Json
    $lintCheck2 = $downgradedGood.checks | Where-Object { $_.id -eq "lint" } | Select-Object -First 1
    $lintCheck2.required = $false
    $lintCheck2.waiver_reason = "lint toolchain not applicable: pure data repo"
    $downgradedGood | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-downgrade-good.json"
    Assert-ExitCode "check-contract baseline downgrade with-waiver passes" (Invoke-Gate "check-contract.ps1" @("contract-downgrade-good.json", "-RepoRoot", ".")) 0

    # =========================================================
    # T-003: risk-aware check-contract
    # =========================================================

    # Helper to create evidence file
    function New-Evidence {
        param([string]$Path)
        $dir = Split-Path -Parent $Path
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        "evidence data" | Set-Content -Encoding Utf8 $Path
    }

    # Test: T-003.1 - LEGACY: contract with NO risk field passes (regression test)
    New-Evidence "reports/test.log"
    $t003_1 = @{
        task_id = "T-003.1"
        feature = "test-feature"
        created = "2026-06-13T00:00:00Z"
        comment = "LEGACY: no risk field"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t003_1 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-1.json"
    Assert-ExitCode "T-003.1: LEGACY (no risk field) with baseline set passes" (Invoke-Gate "check-contract.ps1" @("contract-t003-1.json", "-RepoRoot", ".")) 0

    # Test: T-003.2 - risk: low with required set all required:true+passing
    $t003_2 = @{
        task_id = "T-003.2"
        feature = "test-feature"
        risk = "low"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: low, required set (unit-tests optional per low tier)"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $false; passes = $false; evidence = ""; waiver_reason = "test-after approach" }
        )
    }
    $t003_2 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-2.json"
    Assert-ExitCode "T-003.2: risk: low with required set passes (unit-tests optional)" (Invoke-Gate "check-contract.ps1" @("contract-t003-2.json", "-RepoRoot", ".")) 0

    # Test: T-003.3 - risk: low but build required:false → FAILS
    $t003_3 = @{
        task_id = "T-003.3"
        feature = "test-feature"
        risk = "low"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: low, but build is required:false (should fail)"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $false; passes = $false; evidence = ""; waiver_reason = "downgraded" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $false; passes = $false; evidence = ""; waiver_reason = "test-after" }
        )
    }
    $t003_3 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-3.json"
    Assert-ExitCode "T-003.3: risk: low with build required:false fails correctly" (Invoke-Gate "check-contract.ps1" @("contract-t003-3.json", "-RepoRoot", ".")) 1

    # Test: T-003.4 - risk: medium WITHOUT acceptance-tests check → FAILS
    $t003_4 = @{
        task_id = "T-003.4"
        feature = "test-feature"
        risk = "medium"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: medium, missing acceptance-tests"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t003_4 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-4.json"
    Assert-ExitCode "T-003.4: risk: medium missing acceptance-tests fails correctly" (Invoke-Gate "check-contract.ps1" @("contract-t003-4.json", "-RepoRoot", ".")) 1

    # Test: T-003.5 - risk: medium full (adds unit-tests, acceptance-tests, regression)
    $t003_5 = @{
        task_id = "T-003.5"
        feature = "test-feature"
        risk = "medium"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: medium, full required set"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t003_5 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-5.json"
    Assert-ExitCode "T-003.5: risk: medium with full required set passes" (Invoke-Gate "check-contract.ps1" @("contract-t003-5.json", "-RepoRoot", ".")) 0

    # Test: T-003.6 - risk: high WITHOUT requirement-traceability → FAILS
    $t003_6 = @{
        task_id = "T-003.6"
        feature = "test-feature"
        risk = "high"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: high, missing requirement-traceability"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t003_6 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-6.json"
    Assert-ExitCode "T-003.6: risk: high missing requirement-traceability fails correctly" (Invoke-Gate "check-contract.ps1" @("contract-t003-6.json", "-RepoRoot", ".")) 1

    # Test: T-003.7 - risk: high full (adds requirement-traceability)
    $t003_7 = @{
        task_id = "T-003.7"
        feature = "test-feature"
        risk = "high"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: high, full required set"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "requirement-traceability"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t003_7 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-7.json"
    Assert-ExitCode "T-003.7: risk: high with full required set passes" (Invoke-Gate "check-contract.ps1" @("contract-t003-7.json", "-RepoRoot", ".")) 0

    # Test: T-003.8 - risk: critical (same set as high)
    $t003_8 = @{
        task_id = "T-003.8"
        feature = "test-feature"
        risk = "critical"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: critical, full required set (same as high)"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "requirement-traceability"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t003_8 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-8.json"
    Assert-ExitCode "T-003.8: risk: critical with full required set passes" (Invoke-Gate "check-contract.ps1" @("contract-t003-8.json", "-RepoRoot", ".")) 0

    # Test: T-003.9 - risk: "severe" (invalid) → FAILS
    $t003_9 = @{
        task_id = "T-003.9"
        feature = "test-feature"
        risk = "severe"
        created = "2026-06-13T00:00:00Z"
        comment = "risk: severe (invalid)"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t003_9 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t003-9.json"
    Assert-ExitCode "T-003.9: risk: 'severe' (invalid) fails correctly" (Invoke-Gate "check-contract.ps1" @("contract-t003-9.json", "-RepoRoot", ".")) 1

    # =========================================================
    # T-004: Red→Green evidence enforcement
    # =========================================================

    # Test: T-004.1 - LEGACY: no risk, no required_workflow, valid set → passes (regression)
    $t004_1 = @{
        task_id = "T-004.1"
        feature = "test-feature"
        created = "2026-06-13T00:00:00Z"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t004_1 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t004-1.json"
    Assert-ExitCode "T-004.1: LEGACY (no risk, no required_workflow) passes without red/green" (Invoke-Gate "check-contract.ps1" @("contract-t004-1.json", "-RepoRoot", ".")) 0

    # Test: T-004.2 - required_workflow: test-after (low), no red/green present → passes (no tdd requirement)
    $t004_2 = @{
        task_id = "T-004.2"
        feature = "test-feature"
        risk = "low"
        required_workflow = "test-after"
        created = "2026-06-13T00:00:00Z"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $false; passes = $false; evidence = ""; waiver_reason = "test-after workflow" }
        )
    }
    $t004_2 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t004-2.json"
    Assert-ExitCode "T-004.2: required_workflow: test-after (low) passes without red/green" (Invoke-Gate "check-contract.ps1" @("contract-t004-2.json", "-RepoRoot", ".")) 0

    # Test: T-004.3 - required_workflow: tdd, unit-tests and acceptance-tests required:true WITH valid red_evidence+green_evidence → passes
    $t004_3 = @{
        task_id = "T-004.3"
        feature = "test-feature"
        risk = "high"
        required_workflow = "tdd"
        created = "2026-06-13T00:00:00Z"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = "reports/red.log"; green_evidence = "reports/green.log" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = "reports/red.log"; green_evidence = "reports/green.log" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "requirement-traceability"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t004_3 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t004-3.json"
    Assert-ExitCode "T-004.3: required_workflow: tdd with valid red+green evidence passes" (Invoke-Gate "check-contract.ps1" @("contract-t004-3.json", "-RepoRoot", ".")) 0

    # Test: T-004.4 - required_workflow: tdd, unit-tests required:true MISSING red_evidence → FAILS
    $t004_4 = @{
        task_id = "T-004.4"
        feature = "test-feature"
        risk = "high"
        required_workflow = "tdd"
        created = "2026-06-13T00:00:00Z"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = ""; green_evidence = "reports/green.log" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = "reports/red.log"; green_evidence = "reports/green.log" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "requirement-traceability"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t004_4 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t004-4.json"
    Assert-ExitCode "T-004.4: missing red_evidence fails with correct message" (Invoke-Gate "check-contract.ps1" @("contract-t004-4.json", "-RepoRoot", ".")) 1

    # Test: T-004.5 - required_workflow: tdd, unit-tests required:true with red_evidence pointing at NON-EXISTENT file → FAILS
    $t004_5 = @{
        task_id = "T-004.5"
        feature = "test-feature"
        risk = "high"
        required_workflow = "tdd"
        created = "2026-06-13T00:00:00Z"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = "reports/missing-red.log"; green_evidence = "reports/test.log" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = "reports/red.log"; green_evidence = "reports/green.log" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "requirement-traceability"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t004_5 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t004-5.json"
    Assert-ExitCode "T-004.5: non-existent red_evidence file fails correctly" (Invoke-Gate "check-contract.ps1" @("contract-t004-5.json", "-RepoRoot", ".")) 1

    # Test: T-004.6 - risk: high, required_workflow: acceptance-first (wrong workflow) → FAILS
    $t004_6 = @{
        task_id = "T-004.6"
        feature = "test-feature"
        risk = "high"
        required_workflow = "acceptance-first"
        created = "2026-06-13T00:00:00Z"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "requirement-traceability"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t004_6 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t004-6.json"
    Assert-ExitCode "T-004.6: risk high with wrong required_workflow fails" (Invoke-Gate "check-contract.ps1" @("contract-t004-6.json", "-RepoRoot", ".")) 1

    # Test: T-004.7 - risk: high, required_workflow: tdd, FULL high tier set required:true with red+green → passes
    $t004_7 = @{
        task_id = "T-004.7"
        feature = "test-feature"
        risk = "high"
        required_workflow = "tdd"
        created = "2026-06-13T00:00:00Z"
        checks = @(
            @{ id = "lint"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "typecheck"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "unit-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = "reports/red.log"; green_evidence = "reports/green.log" },
            @{ id = "acceptance-tests"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = ""; red_evidence = "reports/red.log"; green_evidence = "reports/green.log" },
            @{ id = "regression"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "requirement-traceability"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "build"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "placeholder-scan"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" },
            @{ id = "task-state-check"; required = $true; passes = $true; evidence = "reports/test.log"; waiver_reason = "" }
        )
    }
    $t004_7 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "contract-t004-7.json"
    Assert-ExitCode "T-004.7: risk high full tier set with tdd red+green passes" (Invoke-Gate "check-contract.ps1" @("contract-t004-7.json", "-RepoRoot", ".")) 0

    # =========================================================
    # NEW RULES: check-task-state
    # =========================================================

    # -- Duplicate task ids → exit 1 --
    @"
## T-010 First
Approval: Approved
Status: Planned
## T-010 Duplicate
Approval: Approved
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-dup.md"
    Assert-ExitCode "check-task-state duplicate task id" (Invoke-Gate "check-task-state.ps1" @("tasks-dup.md")) 1

    # -- Implementation Complete without impl report → exit 1 --
    @"
## T-020 Impl
Approval: Approved
Status: Implementation Complete
"@ | Set-Content -Encoding Utf8 "tasks-impl-no-report.md"
    Assert-ExitCode "check-task-state impl-complete no-report fails" (Invoke-Gate "check-task-state.ps1" @("tasks-impl-no-report.md", "-ReportsDir", "reports/quality-gate", "-ImplReportsDir", "reports/implementation")) 1

    # -- Implementation Complete with impl report → exit 0 --
    "implementation report for T-020" | Set-Content -Encoding Utf8 "reports/implementation/impl-T-020.md"
    Assert-ExitCode "check-task-state impl-complete with-report passes" (Invoke-Gate "check-task-state.ps1" @("tasks-impl-no-report.md", "-ReportsDir", "reports/quality-gate", "-ImplReportsDir", "reports/implementation")) 0

    # -- Blocked with None → exit 1 --
    @"
## T-030 Blocked
Approval: Approved
Status: Blocked
### Blockers
None
"@ | Set-Content -Encoding Utf8 "tasks-blocked-none.md"
    Assert-ExitCode "check-task-state blocked with None fails" (Invoke-Gate "check-task-state.ps1" @("tasks-blocked-none.md")) 1

    # -- Blocked with empty Blockers section → exit 1 --
    @"
## T-031 Blocked
Approval: Approved
Status: Blocked
### Blockers

"@ | Set-Content -Encoding Utf8 "tasks-blocked-empty.md"
    Assert-ExitCode "check-task-state blocked empty section fails" (Invoke-Gate "check-task-state.ps1" @("tasks-blocked-empty.md")) 1

    # -- Blocked with real text → exit 0 --
    @"
## T-032 Blocked
Approval: Approved
Status: Blocked
### Blockers
Waiting for API credentials from vendor.
"@ | Set-Content -Encoding Utf8 "tasks-blocked-real.md"
    Assert-ExitCode "check-task-state blocked with real text passes" (Invoke-Gate "check-task-state.ps1" @("tasks-blocked-real.md")) 0

    # -- Done without evidence bundle json → exit 1 --
    New-Item -ItemType Directory -Path "spec-dir/verification" -Force | Out-Null
    @"
Task ID: T-040
VERDICT: PASS
quality gate report for T-040
"@ | Set-Content -Encoding Utf8 "reports/quality-gate/r-T040.md"
    "pass evidence for T-040" | Set-Content -Encoding Utf8 "spec-dir/verification/T-040-evidence.log"
    $doneContract = Get-Content -Raw -Encoding Utf8 $templatePath | ConvertFrom-Json
    $doneContract.task_id = "T-040"
    foreach ($check in $doneContract.checks) {
        if ($check.required) {
            $check.passes = $true
            $check.evidence = "spec-dir/verification/T-040-evidence.log"
        } else {
            $check | Add-Member -NotePropertyName waiver_reason -NotePropertyValue "not applicable to this feature" -Force
        }
    }
    $doneContract | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040.contract.json"
    @"
## T-040 DoneNoContract
Approval: Approved
Status: Done
"@ | Set-Content -Encoding Utf8 "spec-dir/tasks-done-nocontract.md"
    Assert-ExitCode "check-task-state done without bundle fails" (Invoke-Gate "check-task-state.ps1" @("spec-dir/tasks-done-nocontract.md", "-ReportsDir", "reports/quality-gate")) 1

    # -- Done with evidence bundle → exit 0 --
    # Commit any new files so git_commit binding is valid for T-040 bundle
    & git add -A 2>&1 | Out-Null
    & git commit -q -m "scripts.tests.ps1 T-040 fixture" 2>&1 | Out-Null
    $t040GitCommit = (& git rev-parse HEAD).Trim()

    $doneBundle = [ordered]@{
        task_id = "T-040"
        quality_report = "reports/quality-gate/r-T040.md"
        verification_contract = "spec-dir/verification/T-040.contract.json"
        git_commit = $t040GitCommit
        git_generated_dirty = $false
        artifacts = @(
            (New-ArtifactEntry "spec-dir/verification/T-040.contract.json"),
            (New-ArtifactEntry "reports/quality-gate/r-T040.md"),
            (New-ArtifactEntry "spec-dir/verification/T-040-evidence.log")
        )
    }
    $doneBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040.evidence.json"
    & git add -A 2>&1 | Out-Null
    & git commit -q -m "scripts.tests.ps1 T-040 bundle" 2>&1 | Out-Null
    # Update git_commit to the bundle commit itself
    $t040GitCommit2 = (& git rev-parse HEAD).Trim()
    $doneBundle["git_commit"] = $t040GitCommit2
    $doneBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040.evidence.json"
    Assert-ExitCode "check-task-state done with bundle passes" (Invoke-Gate "check-task-state.ps1" @("spec-dir/tasks-done-nocontract.md", "-ReportsDir", "reports/quality-gate")) 0

    # -- check-evidence-bundle direct validation --
    Assert-ExitCode "check-evidence-bundle passing" (Invoke-Gate "check-evidence-bundle.ps1" @("spec-dir/verification/T-040.evidence.json", "-RepoRoot", ".")) 0

    $missingArtifactBundle = Get-Content -Raw -Encoding Utf8 "spec-dir/verification/T-040.evidence.json" | ConvertFrom-Json
    $missingArtifactBundle.artifacts = @(
        $missingArtifactBundle.artifacts[0],
        $missingArtifactBundle.artifacts[1]
    )
    $missingArtifactBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040-missing-artifact.evidence.json"
    Assert-ExitCode "check-evidence-bundle missing passing evidence artifact" (Invoke-Gate "check-evidence-bundle.ps1" @("spec-dir/verification/T-040-missing-artifact.evidence.json", "-RepoRoot", ".")) 1

    $badShaBundle = Get-Content -Raw -Encoding Utf8 "spec-dir/verification/T-040.evidence.json" | ConvertFrom-Json
    $badShaBundle.artifacts[0].sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
    $badShaBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040-bad-sha.evidence.json"
    Assert-ExitCode "check-evidence-bundle sha mismatch fails" (Invoke-Gate "check-evidence-bundle.ps1" @("spec-dir/verification/T-040-bad-sha.evidence.json", "-RepoRoot", ".")) 1

    $badPathBundle = Get-Content -Raw -Encoding Utf8 "spec-dir/verification/T-040.evidence.json" | ConvertFrom-Json
    $badPathBundle.artifacts[2].path = "../outside.log"
    $badPathBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040-bad-path.evidence.json"
    Assert-ExitCode "check-evidence-bundle path safety fails" (Invoke-Gate "check-evidence-bundle.ps1" @("spec-dir/verification/T-040-bad-path.evidence.json", "-RepoRoot", ".")) 1

    $badReportBundle = Get-Content -Raw -Encoding Utf8 "spec-dir/verification/T-040.evidence.json" | ConvertFrom-Json
    $badReportBundle.quality_report = "reports/quality-gate/r-T040-bad.md"
    @"
Task ID: T-040
VERDICT: NEEDS_WORK
quality gate report for T-040
"@ | Set-Content -Encoding Utf8 "reports/quality-gate/r-T040-bad.md"
    $badReportBundle.artifacts[1] = (New-ArtifactEntry "reports/quality-gate/r-T040-bad.md")
    $badReportBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040-bad-report.evidence.json"
    Assert-ExitCode "check-evidence-bundle bad report fails" (Invoke-Gate "check-evidence-bundle.ps1" @("spec-dir/verification/T-040-bad-report.evidence.json", "-RepoRoot", ".")) 1

    # =========================================================
    # H-02: check-evidence-bundle git_commit binding (PS1 path)
    # =========================================================
    # missing git_commit → exit 1
    $missingGitCommitBundle = Get-Content -Raw -Encoding Utf8 "spec-dir/verification/T-040.evidence.json" | ConvertFrom-Json
    $missingGitCommitBundleOrdered = [ordered]@{
        task_id               = $missingGitCommitBundle.task_id
        quality_report        = $missingGitCommitBundle.quality_report
        verification_contract = $missingGitCommitBundle.verification_contract
        # git_commit intentionally omitted
        artifacts             = $missingGitCommitBundle.artifacts
    }
    $missingGitCommitBundleOrdered | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040-no-git-commit.evidence.json"
    Assert-ExitCode "check-evidence-bundle ps1 missing git_commit fails" (Invoke-Gate "check-evidence-bundle.ps1" @("spec-dir/verification/T-040-no-git-commit.evidence.json", "-RepoRoot", ".")) 1

    # malformed git_commit (not 40 lowercase hex) → exit 1
    $malformedGitCommitBundle = Get-Content -Raw -Encoding Utf8 "spec-dir/verification/T-040.evidence.json" | ConvertFrom-Json
    $malformedGitCommitBundle | Add-Member -NotePropertyName git_commit -NotePropertyValue "DEADBEEF" -Force
    $malformedGitCommitBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir/verification/T-040-bad-git-commit.evidence.json"
    Assert-ExitCode "check-evidence-bundle ps1 malformed git_commit fails" (Invoke-Gate "check-evidence-bundle.ps1" @("spec-dir/verification/T-040-bad-git-commit.evidence.json", "-RepoRoot", ".")) 1

    # =========================================================
    # NEW RULES: check-placeholders - TODO_REPLACE_WITH_PROJECT_COMMANDS
    # =========================================================
    "echo TODO_REPLACE_WITH_PROJECT_COMMANDS" | Set-Content -Encoding Utf8 "src/ci-placeholder.sh"
    Assert-ExitCode "check-placeholders catches TODO_REPLACE_WITH_PROJECT_COMMANDS" (Invoke-Gate "check-placeholders.ps1" @("src/ci-placeholder.sh")) 1

    # =========================================================
    # POSIX variants via bash
    # =========================================================
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) {
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-good.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh good" $LASTEXITCODE 0
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-bad.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh bad" $LASTEXITCODE 1
        & bash (Join-Path $scriptsDir "check-placeholders.sh") "src/dirty.py" *> $null
        Assert-ExitCode "check-placeholders.sh dirty" $LASTEXITCODE 1

        # .sh new rules
        # duplicate task id
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-dup.md" *> $null
        Assert-ExitCode "check-task-state.sh duplicate task id" $LASTEXITCODE 1

        # Implementation Complete without report (use a fresh task id not yet in reports)
        @"
## T-021 ImplSh
Approval: Approved
Status: Implementation Complete
"@ | Set-Content -Encoding Utf8 "tasks-impl-no-report-sh.md"
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-impl-no-report-sh.md" "reports/quality-gate" "reports/implementation" *> $null
        Assert-ExitCode "check-task-state.sh impl-complete no-report fails" $LASTEXITCODE 1

        # Implementation Complete with report (add the report then re-run)
        "implementation report for T-021" | Set-Content -Encoding Utf8 "reports/implementation/impl-T-021.md"
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-impl-no-report-sh.md" "reports/quality-gate" "reports/implementation" *> $null
        Assert-ExitCode "check-task-state.sh impl-complete with-report passes" $LASTEXITCODE 0

        # Blocked with None
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-blocked-none.md" *> $null
        Assert-ExitCode "check-task-state.sh blocked None fails" $LASTEXITCODE 1

        # Blocked with real text
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-blocked-real.md" *> $null
        Assert-ExitCode "check-task-state.sh blocked real text passes" $LASTEXITCODE 0

        # Done without bundle (use fresh task id T-041 not yet covered)
        New-Item -ItemType Directory -Path "spec-dir2/verification" -Force | Out-Null
        @"
Task ID: T-041
VERDICT: PASS
quality gate report for T-041
"@ | Set-Content -Encoding Utf8 "reports/quality-gate/r-T041.md"
        "pass evidence for T-041" | Set-Content -Encoding Utf8 "spec-dir2/verification/T-041-evidence.log"
        $doneContractSh = Get-Content -Raw -Encoding Utf8 $templatePath | ConvertFrom-Json
        $doneContractSh.task_id = "T-041"
        foreach ($check in $doneContractSh.checks) {
            if ($check.required) {
                $check.passes = $true
                $check.evidence = "spec-dir2/verification/T-041-evidence.log"
            } else {
                $check | Add-Member -NotePropertyName waiver_reason -NotePropertyValue "not applicable to this feature" -Force
            }
        }
        $doneContractSh | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir2/verification/T-041.contract.json"
        @"
## T-041 DoneNoContractSh
Approval: Approved
Status: Done
"@ | Set-Content -Encoding Utf8 "spec-dir2/tasks-done-nocontract-sh.md"
        & bash (Join-Path $scriptsDir "check-task-state.sh") "spec-dir2/tasks-done-nocontract-sh.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh done without bundle fails" $LASTEXITCODE 1

        # Done with bundle — commit T-041 files so git_commit binding is valid
        & git add -A 2>&1 | Out-Null
        & git commit -q -m "scripts.tests.ps1 T-041 fixture" 2>&1 | Out-Null
        $t041GitCommit = (& git rev-parse HEAD).Trim()

        $doneBundleSh = [ordered]@{
            task_id = "T-041"
            quality_report = "reports/quality-gate/r-T041.md"
            verification_contract = "spec-dir2/verification/T-041.contract.json"
            git_commit = $t041GitCommit
            git_generated_dirty = $false
            artifacts = @(
                (New-ArtifactEntry "spec-dir2/verification/T-041.contract.json"),
                (New-ArtifactEntry "reports/quality-gate/r-T041.md"),
                (New-ArtifactEntry "spec-dir2/verification/T-041-evidence.log")
            )
        }
        $doneBundleSh | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir2/verification/T-041.evidence.json"
        & bash (Join-Path $scriptsDir "check-task-state.sh") "spec-dir2/tasks-done-nocontract-sh.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh done with bundle passes" $LASTEXITCODE 0

        & bash (Join-Path $scriptsDir "check-evidence-bundle.sh") "spec-dir2/verification/T-041.evidence.json" "." *> $null
        Assert-ExitCode "check-evidence-bundle.sh passing" $LASTEXITCODE 0

        $shMissingArtifactBundle = Get-Content -Raw -Encoding Utf8 "spec-dir2/verification/T-041.evidence.json" | ConvertFrom-Json
        $shMissingArtifactBundle.artifacts = @(
            $shMissingArtifactBundle.artifacts[0],
            $shMissingArtifactBundle.artifacts[1]
        )
        $shMissingArtifactBundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 "spec-dir2/verification/T-041-missing-artifact.evidence.json"
        & bash (Join-Path $scriptsDir "check-evidence-bundle.sh") "spec-dir2/verification/T-041-missing-artifact.evidence.json" "." *> $null
        Assert-ExitCode "check-evidence-bundle.sh missing passing evidence artifact" $LASTEXITCODE 1

        # TODO_REPLACE_WITH_PROJECT_COMMANDS
        & bash (Join-Path $scriptsDir "check-placeholders.sh") "src/ci-placeholder.sh" *> $null
        Assert-ExitCode "check-placeholders.sh catches TODO_REPLACE_WITH_PROJECT_COMMANDS" $LASTEXITCODE 1

        # check-placeholders.sh case-insensitivity: lowercase todo must be flagged
        & bash (Join-Path $scriptsDir "check-placeholders.sh") "src/todo-lower.py" *> $null
        Assert-ExitCode "check-placeholders.sh lowercase todo flagged" $LASTEXITCODE 1

        # check-task-state.sh header-only task: per-field errors, NOT "no tasks found"
        $shHeaderOut = & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-header-only.md" 2>&1
        $shHeaderExit = $LASTEXITCODE
        Assert-ExitCode "check-task-state.sh header-only exits 1" $shHeaderExit 1
        $shHeaderStr = ($shHeaderOut | Out-String)
        if ($shHeaderStr -match "no tasks found") {
            throw "check-task-state.sh header-only must produce per-field errors, not 'no tasks found'"
        }
        Write-Host "ok: check-task-state.sh header-only produces per-field errors"

        # check-contract.sh: duplicate ids
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-dup-ids.json" "." *> $null
        Assert-ExitCode "check-contract.sh duplicate ids" $LASTEXITCODE 1

        # check-contract.sh: evidence escapes root
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-escape.json" "." *> $null
        Assert-ExitCode "check-contract.sh evidence escapes root" $LASTEXITCODE 1

        # check-contract.sh: absolute evidence path
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-abs.json" "." *> $null
        Assert-ExitCode "check-contract.sh absolute evidence path" $LASTEXITCODE 1

        # check-contract.sh: optional no-waiver fails
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-waiver-bad.json" "." *> $null
        Assert-ExitCode "check-contract.sh optional no-waiver fails" $LASTEXITCODE 1

        # check-contract.sh: optional with-waiver passes
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-good.json" "." *> $null
        Assert-ExitCode "check-contract.sh optional with-waiver passes" $LASTEXITCODE 0

        # check-contract.sh: baseline id removed
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-no-lint.json" "." *> $null
        Assert-ExitCode "check-contract.sh baseline id removed" $LASTEXITCODE 1

        # check-contract.sh: baseline downgrade no-waiver fails
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-downgrade-bad.json" "." *> $null
        Assert-ExitCode "check-contract.sh baseline downgrade no-waiver fails" $LASTEXITCODE 1

        # check-contract.sh: baseline downgrade with-waiver passes
        & bash (Join-Path $scriptsDir "check-contract.sh") "contract-downgrade-good.json" "." *> $null
        Assert-ExitCode "check-contract.sh baseline downgrade with-waiver passes" $LASTEXITCODE 0
    } else {
        Write-Host "bash not found; skipping POSIX variant tests."
    }

    # =========================================================
    # T-002: check-risk (PowerShell)
    # =========================================================

    # Test: T-002.1 - valid task with Risk and Rationale passes
    @"
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-01.md"
    Assert-ExitCode "T-002.1: valid task passes" (Invoke-Gate "check-risk.ps1" @("tasks-t002-01.md")) 0

    # Test: T-002.2 - missing Risk line fails
    @"
# Tasks

## T-001

Risk Rationale: some reason
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-02.md"
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-risk.ps1") "tasks-t002-02.md" 2>&1
    $outStr = ($out | Out-String)
    if ($outStr -match "has no Risk line") {
        Write-Host "ok: T-002.2: missing Risk line fails"
    } else {
        throw "T-002.2: should fail on missing Risk line"
    }
    Assert-ExitCode "T-002.2: missing Risk exits 1" $LASTEXITCODE 1

    # Test: T-002.3 - invalid Risk value fails
    @"
# Tasks

## T-001

Risk: severe
Risk Rationale: verifies tokens
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-03.md"
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-risk.ps1") "tasks-t002-03.md" 2>&1
    $outStr = ($out | Out-String)
    if ($outStr -match "has invalid Risk:") {
        Write-Host "ok: T-002.3: invalid Risk value fails"
    } else {
        throw "T-002.3: should fail on invalid Risk value"
    }
    Assert-ExitCode "T-002.3: invalid Risk exits 1" $LASTEXITCODE 1

    # Test: T-002.4 - placeholder Risk value fails
    @"
# Tasks

## T-001

Risk: {{risk}}
Risk Rationale: verifies tokens
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-04.md"
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-risk.ps1") "tasks-t002-04.md" 2>&1
    Assert-ExitCode "T-002.4: placeholder Risk exits 1" $LASTEXITCODE 1

    # Test: T-002.5 - empty Rationale fails
    @"
# Tasks

## T-001

Risk: high
Risk Rationale:
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-05.md"
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-risk.ps1") "tasks-t002-05.md" 2>&1
    $outStr = ($out | Out-String)
    if ($outStr -match "has empty Risk Rationale") {
        Write-Host "ok: T-002.5: empty Rationale fails"
    } else {
        throw "T-002.5: should fail on empty Rationale"
    }
    Assert-ExitCode "T-002.5: empty Rationale exits 1" $LASTEXITCODE 1

    # Test: T-002.6 - missing Rationale line fails
    @"
# Tasks

## T-001

Risk: medium
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-06.md"
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-risk.ps1") "tasks-t002-06.md" 2>&1
    Assert-ExitCode "T-002.6: missing Rationale exits 1" $LASTEXITCODE 1

    # Test: T-002.7 - two valid tasks pass
    @"
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned

## T-002

Risk: low
Risk Rationale: documentation change
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-07.md"
    Assert-ExitCode "T-002.7: two valid tasks pass" (Invoke-Gate "check-risk.ps1" @("tasks-t002-07.md")) 0

    # Test: T-002.8 - two tasks, one invalid fails
    @"
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned

## T-002

Risk: invalid_value
Risk Rationale: something
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-08.md"
    Assert-ExitCode "T-002.8: two tasks, one invalid fails" (Invoke-Gate "check-risk.ps1" @("tasks-t002-08.md")) 1

    # Test: T-002.9 - file not found fails
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-risk.ps1") "nonexistent.md" 2>&1
    Assert-ExitCode "T-002.9: nonexistent file exits 1" $LASTEXITCODE 1

    # Test: T-002.10 - task-id arg selects one valid section
    @"
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned

## T-002

Risk: bad_value
Risk Rationale: bad
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-10.md"
    Assert-ExitCode "T-002.10: task-id filter selects valid task" (Invoke-Gate "check-risk.ps1" @("tasks-t002-10.md", "-TaskId", "T-001")) 0

    # Test: T-002.11 - valid low risk passes
    @"
# Tasks

## T-001

Risk: low
Risk Rationale: documentation update
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-11.md"
    Assert-ExitCode "T-002.11: valid low risk passes" (Invoke-Gate "check-risk.ps1" @("tasks-t002-11.md")) 0

    # Test: T-002.12 - valid medium risk passes
    @"
# Tasks

## T-001

Risk: medium
Risk Rationale: normal feature implementation
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-12.md"
    Assert-ExitCode "T-002.12: valid medium risk passes" (Invoke-Gate "check-risk.ps1" @("tasks-t002-12.md")) 0

    # Test: T-002.13 - valid critical risk passes
    @"
# Tasks

## T-001

Risk: critical
Risk Rationale: payment settlement path
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-13.md"
    Assert-ExitCode "T-002.13: valid critical risk passes" (Invoke-Gate "check-risk.ps1" @("tasks-t002-13.md")) 0

    # Test: T-002.14 - task-id filter matching no task fails closed (no silent pass)
    @"
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-t002-14.md"
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-risk.ps1") "tasks-t002-14.md" "-TaskId" "T-999" 2>&1
    Assert-ExitCode "T-002.14: filter task-id not found fails closed" $LASTEXITCODE 1

    # =========================================================
    # T-005: check-traceability
    # =========================================================

    # Test: T-005.1 - valid traceability (req+acs+tests, no evidence, no require-evidence) → exit 0
    $t005_1 = @{
        feature = "test-feature"
        links = @(
            @{ req = "REQ-001"; acs = @("AC-001"); tests = @("TEST-001") }
        )
    }
    $t005_1 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-1.json"
    Assert-ExitCode "T-005.1: valid traceability (req+acs+tests, no evidence) passes" (Invoke-Gate "check-traceability.ps1" @("traceability-t005-1.json", "-RepoRoot", ".")) 0

    # Test: T-005.2 - empty acs array → exit 1 ("has no acceptance criteria")
    $t005_2 = @{
        feature = "test-feature"
        links = @(
            @{ req = "REQ-001"; acs = @(); tests = @("TEST-001") }
        )
    }
    $t005_2 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-2.json"
    $t005_2_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "traceability-t005-2.json" 2>&1
    Assert-ExitCode "T-005.2: empty acs array fails with correct message" $LASTEXITCODE 1
    if ($t005_2_out -notmatch "has no acceptance criteria") {
        throw "T-005.2 should fail with 'has no acceptance criteria'"
    }

    # Test: T-005.3 - empty tests array → exit 1 ("has no tests")
    $t005_3 = @{
        feature = "test-feature"
        links = @(
            @{ req = "REQ-001"; acs = @("AC-001"); tests = @() }
        )
    }
    $t005_3 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-3.json"
    $t005_3_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "traceability-t005-3.json" 2>&1
    Assert-ExitCode "T-005.3: empty tests array fails with correct message" $LASTEXITCODE 1
    if ($t005_3_out -notmatch "has no tests") {
        throw "T-005.3 should fail with 'has no tests'"
    }

    # Test: T-005.4 - evidence key present but file missing → exit 1
    $t005_4 = @{
        feature = "test-feature"
        links = @(
            @{ req = "REQ-001"; acs = @("AC-001"); tests = @("TEST-001"); evidence = @("specs/missing.log") }
        )
    }
    $t005_4 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-4.json"
    $t005_4_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "traceability-t005-4.json" 2>&1
    Assert-ExitCode "T-005.4: missing evidence file fails correctly" $LASTEXITCODE 1
    if ($t005_4_out -notmatch "file missing") {
        throw "T-005.4 should fail with 'file missing'"
    }

    # Test: T-005.5 - evidence present + existing non-empty file → exit 0
    New-Item -ItemType Directory -Path "specs/test-feature/verification" -Force | Out-Null
    "evidence data" | Set-Content -Encoding Utf8 "specs/test-feature/verification/T-001.unit.log"
    $t005_5 = @{
        feature = "test-feature"
        links = @(
            @{ req = "REQ-001"; acs = @("AC-001"); tests = @("TEST-001"); evidence = @("specs/test-feature/verification/T-001.unit.log") }
        )
    }
    $t005_5 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-5.json"
    Assert-ExitCode "T-005.5: evidence file present and non-empty passes" (Invoke-Gate "check-traceability.ps1" @("traceability-t005-5.json", "-RepoRoot", ".")) 0

    # Test: T-005.6 - require-evidence mode, link has NO evidence → exit 1 ("requires evidence")
    $t005_6 = @{
        feature = "test-feature"
        links = @(
            @{ req = "REQ-001"; acs = @("AC-001"); tests = @("TEST-001") }
        )
    }
    $t005_6 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-6.json"
    $t005_6_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "traceability-t005-6.json" "-RequireEvidence" 2>&1
    Assert-ExitCode "T-005.6: require-evidence mode without evidence fails correctly" $LASTEXITCODE 1
    if ($t005_6_out -notmatch "requires evidence") {
        throw "T-005.6 should fail with 'requires evidence'"
    }

    # Test: T-005.7 - require-evidence mode, link has existing evidence → exit 0
    $t005_7 = @{
        feature = "test-feature"
        links = @(
            @{ req = "REQ-001"; acs = @("AC-001"); tests = @("TEST-001"); evidence = @("specs/test-feature/verification/T-001.unit.log") }
        )
    }
    $t005_7 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-7.json"
    Assert-ExitCode "T-005.7: require-evidence mode with evidence passes" (Invoke-Gate "check-traceability.ps1" @("traceability-t005-7.json", "-RepoRoot", ".", "-RequireEvidence")) 0

    # Test: T-005.8 - invalid JSON → exit 1
    "{ invalid json" | Set-Content -Encoding Utf8 "traceability-t005-8.json"
    $t005_8_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "traceability-t005-8.json" 2>&1
    Assert-ExitCode "T-005.8: invalid JSON fails with correct message" $LASTEXITCODE 1
    if ($t005_8_out -notmatch "invalid JSON") {
        throw "T-005.8 should fail with 'invalid JSON'"
    }

    # Test: T-005.9 - file not found → exit 1
    $t005_9_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "nonexistent.json" 2>&1
    Assert-ExitCode "T-005.9: nonexistent file fails with correct message" $LASTEXITCODE 1
    if ($t005_9_out -notmatch "file not found") {
        throw "T-005.9 should fail with 'file not found'"
    }

    # Test: T-005.10 - links empty array → exit 1 ("has no links")
    $t005_10 = @{
        feature = "test-feature"
        links = @()
    }
    $t005_10 | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 "traceability-t005-10.json"
    $t005_10_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "traceability-t005-10.json" 2>&1
    Assert-ExitCode "T-005.10: empty links array fails with correct message" $LASTEXITCODE 1
    if ($t005_10_out -notmatch "has no links") {
        throw "T-005.10 should fail with 'has no links'"
    }

    # Test: T-005.11 - require-evidence with EMPTY evidence array fails closed (no silent pass)
    @"
{ "feature": "test-feature", "links": [ { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"], "evidence": [] } ] }
"@ | Set-Content -Encoding Utf8 "traceability-t005-11.json"
    $t005_11_out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-traceability.ps1") "traceability-t005-11.json" "-RequireEvidence" 2>&1
    Assert-ExitCode "T-005.11: require-evidence + empty array fails closed" $LASTEXITCODE 1
    if ($t005_11_out -notmatch "requires evidence but none listed") {
        throw "T-005.11 empty evidence array must fail in require-evidence mode"
    }

    # --- check-sdd-structure ---
    $bootstrapScriptsDir = Join-Path $repositoryRoot "plugins/sdd-bootstrap/scripts"

    function Invoke-BootstrapGate {
        param([string]$Script, [string[]]$Arguments)
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bootstrapScriptsDir $Script) @Arguments *> $null
        return $LASTEXITCODE
    }

    # Helper: build a fresh sub-directory under $workDir for an isolated fixture tree.
    function New-Fixture {
        param([string]$Name)
        $path = Join-Path $workDir $Name
        New-Item -ItemType Directory -Path $path | Out-Null
        return $path
    }

    # Test 1: complete structure → exit 0
    $fixtureComplete = New-Fixture "sdd-complete"
    foreach ($d in @("specs", "reports/implementation", "reports/quality-gate", "docs/adr", "docs/review-tickets")) {
        New-Item -ItemType Directory -Path (Join-Path $fixtureComplete $d) -Force | Out-Null
    }
    "" | Set-Content -Encoding Utf8 (Join-Path $fixtureComplete "AGENTS.md")
    Assert-ExitCode "check-sdd-structure complete → OK" (Invoke-BootstrapGate "check-sdd-structure.ps1" @($fixtureComplete)) 0

    # Test 2: missing AGENTS.md and docs/adr → exit 1
    $fixtureMissing = New-Fixture "sdd-missing"
    foreach ($d in @("specs", "reports/implementation", "reports/quality-gate", "docs/review-tickets")) {
        New-Item -ItemType Directory -Path (Join-Path $fixtureMissing $d) -Force | Out-Null
    }
    # No AGENTS.md, no docs/adr
    Assert-ExitCode "check-sdd-structure missing AGENTS.md + docs/adr → FAIL" (Invoke-BootstrapGate "check-sdd-structure.ps1" @($fixtureMissing)) 1

    # Test 3: drift dir specs/foo/adr present, structure otherwise complete → exit 0
    $fixtureDrift = New-Fixture "sdd-drift"
    foreach ($d in @("specs/foo/adr", "reports/implementation", "reports/quality-gate", "docs/adr", "docs/review-tickets")) {
        New-Item -ItemType Directory -Path (Join-Path $fixtureDrift $d) -Force | Out-Null
    }
    "" | Set-Content -Encoding Utf8 (Join-Path $fixtureDrift "AGENTS.md")
    Assert-ExitCode "check-sdd-structure drift dir present + complete → OK" (Invoke-BootstrapGate "check-sdd-structure.ps1" @($fixtureDrift)) 0

    # Test 4: advisory-only missing (CLAUDE.md absent, contracts absent) → exit 0
    $fixtureAdvisory = New-Fixture "sdd-advisory"
    foreach ($d in @("specs", "reports/implementation", "reports/quality-gate", "docs/adr", "docs/review-tickets")) {
        New-Item -ItemType Directory -Path (Join-Path $fixtureAdvisory $d) -Force | Out-Null
    }
    "" | Set-Content -Encoding Utf8 (Join-Path $fixtureAdvisory "AGENTS.md")
    # CLAUDE.md, contracts/, docs/architecture/ are intentionally absent
    Assert-ExitCode "check-sdd-structure advisory-only missing → OK" (Invoke-BootstrapGate "check-sdd-structure.ps1" @($fixtureAdvisory)) 0

    # POSIX variants via bash
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) {
        & bash (Join-Path $bootstrapScriptsDir "check-sdd-structure.sh") $fixtureComplete *> $null
        Assert-ExitCode "check-sdd-structure.sh complete → OK" $LASTEXITCODE 0

        & bash (Join-Path $bootstrapScriptsDir "check-sdd-structure.sh") $fixtureMissing *> $null
        Assert-ExitCode "check-sdd-structure.sh missing AGENTS.md + docs/adr → FAIL" $LASTEXITCODE 1

        & bash (Join-Path $bootstrapScriptsDir "check-sdd-structure.sh") $fixtureDrift *> $null
        Assert-ExitCode "check-sdd-structure.sh drift dir present + complete → OK" $LASTEXITCODE 0

        & bash (Join-Path $bootstrapScriptsDir "check-sdd-structure.sh") $fixtureAdvisory *> $null
        Assert-ExitCode "check-sdd-structure.sh advisory-only missing → OK" $LASTEXITCODE 0
    } else {
        Write-Host "bash not found; skipping check-sdd-structure.sh POSIX tests."
    }

    Write-Host "Script gate tests passed."
} finally {
    Pop-Location
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}

# Explicit success exit: GitHub Actions pwsh appends "exit $LASTEXITCODE", which
# would otherwise leak the exit code of the last native command run above
# (e.g. a gate test that intentionally exits non-zero).
exit 0
