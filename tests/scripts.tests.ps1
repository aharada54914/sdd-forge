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

    # --- guard-task-approval (hook payload over stdin) ---
    function Invoke-Guard {
        param([string]$Payload)
        $Payload | & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "guard-task-approval.ps1") *> $null
        return $LASTEXITCODE
    }
    $block = Invoke-Guard '{"tool_input":{"file_path":"/x/specs/f/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    Assert-ExitCode "guard blocks self-approval" $block 2
    $allow = Invoke-Guard '{"tool_input":{"file_path":"/x/specs/f/tasks.md","old_string":"Status: Planned","new_string":"Status: In Progress"}}'
    Assert-ExitCode "guard allows status change" $allow 0
    $other = Invoke-Guard '{"tool_input":{"file_path":"/x/src/a.py","old_string":"a","new_string":"b"}}'
    Assert-ExitCode "guard ignores other files" $other 0

    # --- POSIX variants via bash when available (e.g. Git Bash on Windows) ---
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) {
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-good.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh good" $LASTEXITCODE 0
        & bash (Join-Path $scriptsDir "check-task-state.sh") "tasks-bad.md" "reports/quality-gate" *> $null
        Assert-ExitCode "check-task-state.sh bad" $LASTEXITCODE 1
        & bash (Join-Path $scriptsDir "check-placeholders.sh") "src/dirty.py" *> $null
        Assert-ExitCode "check-placeholders.sh dirty" $LASTEXITCODE 1
    } else {
        Write-Host "bash not found; skipping POSIX variant tests."
    }

    Write-Host "Script gate tests passed."
} finally {
    Pop-Location
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}
