# Deterministic gate (lite): validate the tasks.md state machine for the sdd-lite flow.
# Usage: check-task-state-lite.ps1 <tasks> <reports-qg-dir> <impl-reports-dir> <repo-root>
# Lite differences vs check-task-state.ps1:
#  - Done does NOT require verification/<id>.evidence.json or .contract.json.
#  - Done requires: Approval: Approved + an implementation report mentioning the
#    task id + a quality-gate report mentioning the task id with VERDICT: PASS.
#  - No critical two-person-approval enforcement (lite has no critical tier).
# Shared rules (same as the full gate):
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Implementation Complete (and Done) require an implementation report mentioning the task id.
#  - Blocked requires non-empty ### Blockers content.
#  - Duplicate task ids -> fail.
param(
    [Parameter(Mandatory)][string]$TasksPath,
    [string]$ReportsDir = "reports/quality-gate",
    [string]$ImplReportsDir = "reports/implementation",
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TasksPath)) {
    Write-Error "check-task-state-lite: tasks file not found: $TasksPath"
    exit 1
}

$validStatuses = @("Planned", "In Progress", "Blocked", "Implementation Complete", "Done")
$approvedOnlyStatuses = @("In Progress", "Implementation Complete", "Done")

# Pattern for generalized approval: Approved (<id> YYYY-MM-DDTHH:MM:SSZ)
$namedApprovalPattern = "^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$"

$failures = @()
$currentTask = $null
$approval = @{}
$status = @{}
$blockers = @{}
$seenIds = @{}

# Normalize CRLF: read as raw text and split on LF after stripping CR
$rawContent = [System.IO.File]::ReadAllText($TasksPath) -replace "`r`n", "`n" -replace "`r", "`n"
$lines = $rawContent -split "`n"

$inBlockers = $false

foreach ($line in $lines) {
    if ($line -match '^##\s+(T-\d+)') {
        $newTask = $Matches[1]
        $inBlockers = $false
        if ($seenIds.ContainsKey($newTask)) {
            $failures += "duplicate task id $newTask"
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
        $stripped = $line -replace '^[\s\-\*]+', '' -replace '^\s+', ''
        if ($stripped -ne "" -and $stripped.ToLower() -ne "none") {
            $blockers[$currentTask] += $stripped
        }
    }
}

if ($seenIds.Count -eq 0) {
    Write-Host "check-task-state-lite: no tasks found in $TasksPath"
    exit 1
}

$allTasks = @($seenIds.Keys) | Sort-Object
foreach ($task in $allTasks) {
    $a = $approval[$task]
    $s = $status[$task]
    if (-not $a) { $failures += "$task has no Approval line"; continue }
    if (-not $s) { $failures += "$task has no Status line"; continue }

    # Validate Approval: Draft | Approved | Approved (<id> YYYY-MM-DDTHH:MM:SSZ)
    $isValidApproval = ($a -eq "Draft" -or $a -eq "Approved" -or $a -match $namedApprovalPattern)
    if (-not $isValidApproval) {
        $failures += "$task has invalid Approval: $a"
    }

    $isApproved = ($a -eq "Approved" -or $a -match $namedApprovalPattern)

    if ($s -notin $validStatuses) { $failures += "$task has invalid Status: $s" }
    if ($s -in $approvedOnlyStatuses -and -not $isApproved) {
        $failures += "$task is '$s' without Approval: Approved"
    }

    # Implementation report required for Implementation Complete AND Done
    if ($s -eq "Implementation Complete" -or $s -eq "Done") {
        $hasImplReport = $false
        if (Test-Path -LiteralPath $ImplReportsDir) {
            $hasImplReport = [bool](Get-ChildItem $ImplReportsDir -File -Recurse |
                Where-Object { Select-String -Path $_.FullName -Pattern "\b$task\b" -Quiet })
        }
        if (-not $hasImplReport) {
            $failures += "$task is '$s' but no implementation report in $ImplReportsDir mentions it"
        }
    }

    # Lite Done: require a quality-gate report mentioning the task with VERDICT: PASS
    if ($s -eq "Done") {
        $qaFound = $false
        if (Test-Path -LiteralPath $ReportsDir) {
            $candidates = Get-ChildItem $ReportsDir -File -Recurse |
                Where-Object { Select-String -Path $_.FullName -Pattern "\b$task\b" -Quiet }
            foreach ($candidate in $candidates) {
                $hasVerdict = Select-String -Path $candidate.FullName -Pattern "^VERDICT:\s*PASS\s*$" -Quiet
                if ($hasVerdict) { $qaFound = $true; break }
            }
        }
        if (-not $qaFound) {
            $failures += "$task is Done but no quality-gate report in $ReportsDir mentions it with VERDICT: PASS"
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
    Write-Host "Task state (lite) check FAILED:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host "Task state (lite) check passed for $($seenIds.Count) task(s)."
exit 0
