# Deterministic gate: validate the tasks.md state machine on disk.
# Usage: check-task-state.ps1 <path-to-tasks.md> [-ReportsDir <reports/quality-gate>] [-ImplReportsDir <reports/implementation>] [-RepoRoot <path>]
# Rules enforced:
#  - Approval is Draft or Approved (bare) or Approved (<any annotation>); Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Done additionally requires a verification/<task-id>.evidence.json file
#    in the tasks.md directory, and that bundle must validate the report,
#    contract, and passing evidence artifacts.
#  - Done additionally requires the evidence bundle's declared quality-gate
#    report to mention the task id and contain VERDICT: PASS.
#  - Implementation Complete requires an implementation report mentioning the task id.
#  - Blocked requires non-empty ### Blockers content (not None/whitespace/bare list markers).
#  - Duplicate task ids (## T-NNN repeated) → fail.
param(
    [Parameter(Mandatory)][string]$TasksPath,
    [string]$ReportsDir = "reports/quality-gate",
    [string]$ImplReportsDir = "reports/implementation",
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TasksPath)) {
    Write-Error "tasks file not found: $TasksPath"
    exit 1
}

$validStatuses = @("Planned", "In Progress", "Blocked", "Implementation Complete", "Done")
$approvedOnlyStatuses = @("In Progress", "Implementation Complete", "Done")

# Strict pattern for critical two-person approval (named approver + ISO timestamp)
$namedApprovalPattern = "^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$"
# Relaxed pattern: Approved (<any non-empty annotation>) — used for non-critical gate checks
$flexApprovalPattern = "^Approved \(.+\)$"

$failures = @()
$currentTask = $null
$approval = @{}
$status = @{}
$risk = @{}
$second = @{}
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
    } elseif ($currentTask -and $line -match '^Risk:\s*(.+)$') {
        $risk[$currentTask] = $Matches[1].Trim().ToLower()
        $inBlockers = $false
    } elseif ($currentTask -and $line -match '^Second Approval:\s*(.+)$') {
        $second[$currentTask] = $Matches[1].Trim()
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

# Extract approver id from an approval string (e.g. "Approved (alice 2026-06-13T...Z)" → "alice")
function Get-ApproverId([string]$s) {
    if ($s -match "^Approved \(([^ )]+) [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$") {
        return $Matches[1]
    }
    return ""
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

    # Validate Approval: Draft | Approved | Approved (<any non-empty annotation>)
    $isValidApproval = ($a -eq "Draft" -or $a -eq "Approved" -or $a -match $flexApprovalPattern)
    if (-not $isValidApproval) {
        $failures += "$task has invalid Approval: $a"
    }

    # For gate checks, treat Approved (with any non-empty annotation) same as Approved
    $isApproved = ($a -eq "Approved" -or $a -match $flexApprovalPattern)

    if ($s -notin $validStatuses) { $failures += "$task has invalid Status: $s" }
    if ($s -in $approvedOnlyStatuses -and -not $isApproved) {
        $failures += "$task is '$s' without Approval: Approved"
    }
    if ($s -eq "Done") {
        # Two-person approval enforcement for critical Done tasks
        $taskRisk = if ($risk.ContainsKey($task)) { $risk[$task] } else { "" }
        if ($taskRisk -eq "critical") {
            $primId = Get-ApproverId -s $a
            $secValue = if ($second.ContainsKey($task)) { $second[$task] } else { "" }
            $secId = Get-ApproverId -s $secValue

            if ($primId -eq "") {
                $failures += "$task is critical Done but primary Approval lacks a named approver (need 'Approved (<id> <ISO>)')"
            }
            if ($primId.ToLower() -eq "sudo") {
                $failures += "$task is critical Done but primary approver is 'sudo'; critical requires a named human approver"
            }
            if ($secValue -eq "" -or $secId -eq "") {
                $failures += "$task is critical Done but Second Approval is missing or not a named 'Approved (<id> <ISO>)'"
            }
            if ($secId.ToLower() -eq "sudo") {
                $failures += "$task is critical Done but Second Approval approver is 'sudo'; critical requires a named human second approver"
            }
            if ($primId -ne "" -and $primId.ToLower() -eq $secId.ToLower()) {
                $failures += "$task is critical Done but both approvals are by the same approver '$primId'; two distinct approvers required"
            }
        }

        $evidenceBundlePath = Join-Path $tasksDir "verification/$task.evidence.json"
        $contractPath = Join-Path $tasksDir "verification/$task.contract.json"

        # Check evidence bundle
        if (-not (Test-Path -LiteralPath $evidenceBundlePath)) {
            $failures += "$task is Done but verification/$task.evidence.json does not exist in $tasksDir"
        } else {
            $powerShellExe = (Get-Process -Id $PID).Path
            & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "check-evidence-bundle.ps1") -BundlePath $evidenceBundlePath -RepoRoot $RepoRoot
            if ($LASTEXITCODE -ne 0) {
                $failures += "$task evidence bundle failed validation: $evidenceBundlePath"
            }
        }

        # C-07: Check contract existence, size, and task_id match
        if (-not (Test-Path -LiteralPath $contractPath)) {
            $failures += "$task is Done but verification/$task.contract.json does not exist in $tasksDir"
        } else {
            $fileInfo = Get-Item -LiteralPath $contractPath -ErrorAction SilentlyContinue
            if ($null -eq $fileInfo -or $fileInfo.Length -eq 0) {
                $failures += "$task is Done but verification/$task.contract.json is empty in $tasksDir"
            } else {
                # Validate contract JSON and task_id match
                try {
                    $contract = Get-Content -Raw -Encoding Utf8 $contractPath | ConvertFrom-Json
                    if ($contract.task_id -ne $task) {
                        $failures += "$task is Done but verification/$task.contract.json has mismatched task_id"
                    }
                } catch {
                    $failures += "$task is Done but verification/$task.contract.json has invalid JSON"
                }
            }
        }
        # The evidence-bundle gate above validates its declared quality_report,
        # including repository confinement, task identity, digest, and PASS verdict.
        # Do not search the shared report directory by task id: task ids are only
        # unique within a feature and a global search can select another feature.
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
