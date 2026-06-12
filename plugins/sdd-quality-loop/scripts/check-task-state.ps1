# Deterministic gate: validate the tasks.md state machine on disk.
# Usage: check-task-state.ps1 <path-to-tasks.md> [-ReportsDir <reports/quality-gate>] [-ImplReportsDir <reports/implementation>]
# Rules enforced:
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Done additionally requires a quality-gate report mentioning the task id,
#    AND a verification/<task-id>.contract.json file in the tasks.md directory.
#  - Implementation Complete requires an implementation report mentioning the task id.
#  - Blocked requires non-empty ### Blockers content (not None/whitespace/bare list markers).
#  - Duplicate task ids (## T-NNN repeated) → fail.
param(
    [Parameter(Mandatory)][string]$TasksPath,
    [string]$ReportsDir = "reports/quality-gate",
    [string]$ImplReportsDir = "reports/implementation"
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TasksPath)) {
    Write-Error "tasks file not found: $TasksPath"
    exit 1
}

$validApprovals = @("Draft", "Approved")
$validStatuses = @("Planned", "In Progress", "Blocked", "Implementation Complete", "Done")
$approvedOnlyStatuses = @("In Progress", "Implementation Complete", "Done")

$failures = @()
$currentTask = $null
$approval = @{}
$status = @{}
$blockers = @{}
$seenIds = @{}

$lines = Get-Content -Encoding Utf8 $TasksPath
$inBlockers = $false

foreach ($line in $lines) {
    if ($line -match '^##\s+(T-\d+)') {
        $newTask = $Matches[1]
        $inBlockers = $false
        if ($seenIds.ContainsKey($newTask)) {
            $failures += "duplicate task id $newTask"
            # Keep currentTask pointing to the first occurrence (first-wins); stop updating fields for this duplicate.
            $currentTask = $null
        } else {
            $currentTask = $newTask
            $seenIds[$currentTask] = $true
            if (-not $blockers.ContainsKey($currentTask)) { $blockers[$currentTask] = "" }
        }
    } elseif ($currentTask -and $line -match '^Approval:\s*(.+)$') {
        $approval[$currentTask] = $Matches[1].Trim()
        $inBlockers = $false
    } elseif ($currentTask -and $line -match '^Status:\s*(.+)$') {
        $status[$currentTask] = $Matches[1].Trim()
        $inBlockers = $false
    } elseif ($currentTask -and $line -match '^###\s+Blockers') {
        $inBlockers = $true
    } elseif ($line -match '^##') {
        $inBlockers = $false
    } elseif ($currentTask -and $inBlockers) {
        # Collect non-trivial blocker content
        $stripped = $line -replace '^[\s\-\*]+', '' -replace '^\s+', ''
        if ($stripped -ne "" -and $stripped.ToLower() -ne "none") {
            $blockers[$currentTask] += $stripped
        }
    }
}

if ($seenIds.Count -eq 0) {
    Write-Host "check-task-state: no tasks found in $TasksPath"
    exit 1
}

# Directory of the tasks file (for verification contract lookup)
$tasksDir = Split-Path -Parent (Resolve-Path $TasksPath)

$allTasks = @($seenIds.Keys) | Sort-Object
foreach ($task in $allTasks) {
    # Skip duplicate tasks already reported - still validate first occurrence
    $a = $approval[$task]
    $s = $status[$task]
    if (-not $a) { $failures += "$task has no Approval line"; continue }
    if (-not $s) { $failures += "$task has no Status line"; continue }
    if ($a -notin $validApprovals) { $failures += "$task has invalid Approval: $a" }
    if ($s -notin $validStatuses) { $failures += "$task has invalid Status: $s" }
    if ($s -in $approvedOnlyStatuses -and $a -ne "Approved") {
        $failures += "$task is '$s' without Approval: Approved"
    }
    if ($s -eq "Done") {
        $hasReport = $false
        if (Test-Path -LiteralPath $ReportsDir) {
            $hasReport = [bool](Get-ChildItem $ReportsDir -File -Recurse |
                Where-Object { Select-String -Path $_.FullName -Pattern $task -Quiet })
        }
        if (-not $hasReport) {
            $failures += "$task is Done but no quality-gate report in $ReportsDir mentions it"
        }
        # Check for verification contract file
        $contractPath = Join-Path $tasksDir "verification/$task.contract.json"
        if (-not (Test-Path -LiteralPath $contractPath)) {
            $failures += "$task is Done but verification/$task.contract.json does not exist in $tasksDir"
        }
    }
    if ($s -eq "Implementation Complete") {
        $hasImplReport = $false
        if (Test-Path -LiteralPath $ImplReportsDir) {
            $hasImplReport = [bool](Get-ChildItem $ImplReportsDir -File -Recurse |
                Where-Object { Select-String -Path $_.FullName -Pattern $task -Quiet })
        }
        if (-not $hasImplReport) {
            $failures += "$task is Implementation Complete but no implementation report in $ImplReportsDir mentions it"
        }
    }
    if ($s -eq "Blocked") {
        $blockersContent = $blockers[$task]
        if ([string]::IsNullOrWhiteSpace($blockersContent)) {
            $failures += "$task is Blocked but ### Blockers section has no content (not None or empty)"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Task state check FAILED:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host "Task state check passed for $($seenIds.Count) task(s)."
exit 0
