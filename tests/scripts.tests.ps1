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
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir $Script) @Arguments *> $null
    return $LASTEXITCODE
}

function Assert-ExitCode {
    param([string]$Name, [int]$Actual, [int]$Expected)
    if ($Actual -ne $Expected) {
        throw "$Name expected exit $Expected but got $Actual"
    }
    Write-Host "ok: $Name"
}

Push-Location $workDir
try {
    # --- check-task-state ---
    New-Item -ItemType Directory -Path "reports/quality-gate" -Force | Out-Null
    New-Item -ItemType Directory -Path "reports/implementation" -Force | Out-Null
    New-Item -ItemType Directory -Path "verification" -Force | Out-Null

    # tasks-good.md: T-001 is Done (needs quality-gate report + contract file), T-002 is Planned
    @"
# Tasks: demo
## T-001 First
Approval: Approved
Status: Done
## T-002 Second
Approval: Draft
Status: Planned
"@ | Set-Content -Encoding Utf8 "tasks-good.md"
    "quality gate report for T-001" | Set-Content -Encoding Utf8 "reports/quality-gate/r1.md"
    # Create verification contract file required by Done status
    '{"task_id":"T-001"}' | Set-Content -Encoding Utf8 "verification/T-001.contract.json"

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

    # -- Done without verification contract json → exit 1 --
    New-Item -ItemType Directory -Path "spec-dir/verification" -Force | Out-Null
    "quality gate report for T-040" | Set-Content -Encoding Utf8 "reports/quality-gate/r-T040.md"
    @"
## T-040 DoneNoContract
Approval: Approved
Status: Done
"@ | Set-Content -Encoding Utf8 "spec-dir/tasks-done-nocontract.md"
    Assert-ExitCode "check-task-state done without contract fails" (Invoke-Gate "check-task-state.ps1" @("spec-dir/tasks-done-nocontract.md", "-ReportsDir", "reports/quality-gate")) 1

    # -- Done with verification contract json AND quality-gate report → exit 0 --
    '{"task_id":"T-040"}' | Set-Content -Encoding Utf8 "spec-dir/verification/T-040.contract.json"
    Assert-ExitCode "check-task-state done with contract passes" (Invoke-Gate "check-task-state.ps1" @("spec-dir/tasks-done-nocontract.md", "-ReportsDir", "reports/quality-gate")) 0

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

        # Done without contract (use fresh task id T-041 not yet covered)
        New-Item -ItemType Directory -Path "spec-dir2/verification" -Force | Out-Null
        "quality gate report for T-041" | Set-Content -Encoding Utf8 "reports/quality-gate/r-T041.md"
        @"
## T-041 DoneNoContractSh
Approval: Approved
Status: Done
"@ | Set-Content -Encoding Utf8 "spec-dir2/tasks-done-nocontract-sh.md"
        & bash (Join-Path $scriptsDir "check-task-state.sh") "spec-dir2/tasks-done-nocontract-sh.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh done without contract fails" $LASTEXITCODE 1

        # Done with contract
        '{"task_id":"T-041"}' | Set-Content -Encoding Utf8 "spec-dir2/verification/T-041.contract.json"
        & bash (Join-Path $scriptsDir "check-task-state.sh") "spec-dir2/tasks-done-nocontract-sh.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh done with contract passes" $LASTEXITCODE 0

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
