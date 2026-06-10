# Deterministic gate: validate the tasks.md state machine on disk.
# Usage: check-task-state.ps1 <path-to-tasks.md> [-ReportsDir <reports/quality-gate>]
# Rules enforced:
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Done additionally requires a quality-gate report mentioning the task id.
param(
    [Parameter(Mandatory)][string]$TasksPath,
    [string]$ReportsDir = "reports/quality-gate"
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $TasksPath)) {
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

foreach ($line in Get-Content -Encoding Utf8 $TasksPath) {
    if ($line -match '^##\s+(T-\d+)') {
        $currentTask = $Matches[1]
    } elseif ($currentTask -and $line -match '^Approval:\s*(.+)$') {
        $approval[$currentTask] = $Matches[1].Trim()
    } elseif ($currentTask -and $line -match '^Status:\s*(.+)$') {
        $status[$currentTask] = $Matches[1].Trim()
    }
}

if ($approval.Count -eq 0 -and $status.Count -eq 0) {
    Write-Host "check-task-state: no tasks found in $TasksPath"
    exit 1
}

$allTasks = @($approval.Keys) + @($status.Keys) | Sort-Object -Unique
foreach ($task in $allTasks) {
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
        if (Test-Path $ReportsDir) {
            $hasReport = [bool](Get-ChildItem $ReportsDir -File -Recurse |
                Where-Object { Select-String -Path $_.FullName -Pattern $task -Quiet })
        }
        if (-not $hasReport) {
            $failures += "$task is Done but no quality-gate report in $ReportsDir mentions it"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Task state check FAILED:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host "Task state check passed for $($approval.Count) task(s)."
exit 0
