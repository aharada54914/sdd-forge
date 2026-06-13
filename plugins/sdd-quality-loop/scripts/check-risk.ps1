# Deterministic gate: validate Risk field in tasks.md
# Usage: check-risk.ps1 <path-to-tasks.md> [-TaskId <id>]
#
# Rules enforced:
#  - Every task must have a Risk: line with a valid value (low, medium, high, critical)
#  - Every task must have a Risk Rationale: line with non-empty content
#  - If TaskId arg is given, validate only that task
#  - Fail-closed; exit 1 on any validation failure
param(
    [Parameter(Mandatory)][string]$TasksPath,
    [string]$TaskId = ""
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TasksPath)) {
    Write-Error "check-risk: tasks file not found: $TasksPath"
    exit 1
}

$validRisks = @("low", "medium", "high", "critical")
$failures = @()
$currentTask = $null
$risk = @{}
$riskRationale = @{}
$seenIds = @{}
$foundFilter = $false

$lines = Get-Content -Encoding Utf8 $TasksPath

foreach ($line in $lines) {
    if ($line -match '^##\s+(T-\d+)') {
        $newTask = $Matches[1]
        if (-not $seenIds.ContainsKey($newTask)) {
            $seenIds[$newTask] = $true
        }
        $currentTask = $newTask
        if (-not $risk.ContainsKey($currentTask)) { $risk[$currentTask] = "" }
        if (-not $riskRationale.ContainsKey($currentTask)) { $riskRationale[$currentTask] = "" }
    } elseif ($currentTask -and $line -match '^Risk:\s*(.*)$') {
        $risk[$currentTask] = $Matches[1].Trim()
    } elseif ($currentTask -and $line -match '^Risk Rationale:\s*(.*)$') {
        $riskRationale[$currentTask] = $Matches[1].Trim()
    }
}

if ($seenIds.Count -eq 0) {
    Write-Host "check-risk: no tasks found in $TasksPath"
    exit 1
}

$allTasks = @($seenIds.Keys) | Sort-Object

foreach ($task in $allTasks) {
    # If filter provided, skip non-matching tasks
    if ($TaskId -ne "" -and $task -ne $TaskId) {
        continue
    }
    if ($TaskId -ne "") { $foundFilter = $true }

    $r = $risk[$task]
    $rr = $riskRationale[$task]

    if ($r -eq "") {
        $failures += "$task has no Risk line"
    } elseif ($r -notin $validRisks) {
        $failures += "$task has invalid Risk: $r"
    }

    if ($rr -eq "") {
        $failures += "$task has empty Risk Rationale"
    }
}

if ($TaskId -ne "" -and -not $foundFilter) {
    # Fail closed: a requested task id that is not present is an error, not a pass.
    $failures += "requested task $TaskId not found in $TasksPath"
}

if ($failures.Count -gt 0) {
    Write-Host "Risk check FAILED:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

if ($TaskId -ne "") {
    Write-Host "Risk check passed for task $TaskId."
} else {
    Write-Host "Risk check passed for $($seenIds.Count) task(s)."
}
exit 0
