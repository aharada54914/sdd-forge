# Deterministic gate: validate Risk field in tasks.md
# Usage: check-risk.ps1 <path-to-tasks.md> [-TaskId <id>]
#
# Rules enforced:
#  - Every task must have a Risk: line with a valid value (low, medium, high, critical)
#  - Every task must have a Risk Rationale: line with non-empty content
#  - A high/critical task MUST declare `Required Workflow: tdd` (risk->workflow
#    derivation, design.md:118). low/medium not constrained (stricter allowed).
#  - Structured risk fields (Risk Impact / Risk Reversibility / Risk Surface)
#    are optional (legacy tasks omit them). When present, each value maps to a
#    minimum tier per risk-classification-policy.md and the declared Risk must
#    be at or above the highest derived floor; unknown values and floor
#    violations are policy-inconsistent and fail closed (REQ-001).
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
$rank = @{ "low" = 1; "medium" = 2; "high" = 3; "critical" = 4 }
$tierName = @{ 1 = "low"; 2 = "medium"; 3 = "high"; 4 = "critical" }
# Minimum tier implied by each structured value (risk-classification-policy.md):
# material impact / difficult reversibility / sensitive surface describe the
# high tier; behavioral surface excludes low ("non-behavioral"), so medium.
$impactFloor = @{ "limited" = 1; "material" = 3 }
$reversibilityFloor = @{ "controlled" = 1; "difficult" = 3 }
$surfaceFloor = @{ "behavioral" = 2; "sensitive" = 3 }
$failures = @()
$currentTask = $null
$risk = @{}
$riskRationale = @{}
$requiredWorkflow = @{}
$riskImpact = @{}
$riskReversibility = @{}
$riskSurface = @{}
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
        if (-not $requiredWorkflow.ContainsKey($currentTask)) { $requiredWorkflow[$currentTask] = "" }
        if (-not $riskImpact.ContainsKey($currentTask)) { $riskImpact[$currentTask] = "" }
        if (-not $riskReversibility.ContainsKey($currentTask)) { $riskReversibility[$currentTask] = "" }
        if (-not $riskSurface.ContainsKey($currentTask)) { $riskSurface[$currentTask] = "" }
    } elseif ($currentTask -and $line -match '^Risk:\s*(.*)$') {
        $risk[$currentTask] = $Matches[1].Trim()
    } elseif ($currentTask -and $line -match '^Risk Rationale:\s*(.*)$') {
        $riskRationale[$currentTask] = $Matches[1].Trim()
    } elseif ($currentTask -and $line -match '^Required Workflow:\s*(.*)$') {
        $requiredWorkflow[$currentTask] = $Matches[1].Trim()
    } elseif ($currentTask -and $line -match '^Risk Impact:\s*(.*)$') {
        $riskImpact[$currentTask] = $Matches[1].Trim()
    } elseif ($currentTask -and $line -match '^Risk Reversibility:\s*(.*)$') {
        $riskReversibility[$currentTask] = $Matches[1].Trim()
    } elseif ($currentTask -and $line -match '^Risk Surface:\s*(.*)$') {
        $riskSurface[$currentTask] = $Matches[1].Trim()
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

    # Structured fields are optional; when present the declared Risk must not
    # sit below the highest tier floor they derive. Only compared when risk is
    # a valid tier, to avoid stacking on top of an "invalid Risk" report.
    $floor = 0
    $ri = $riskImpact[$task]
    if ($ri -ne "") {
        if (-not $impactFloor.ContainsKey($ri)) {
            $failures += "$task has invalid Risk Impact: $ri"
        } elseif ($impactFloor[$ri] -gt $floor) {
            $floor = $impactFloor[$ri]
        }
    }
    $rv = $riskReversibility[$task]
    if ($rv -ne "") {
        if (-not $reversibilityFloor.ContainsKey($rv)) {
            $failures += "$task has invalid Risk Reversibility: $rv"
        } elseif ($reversibilityFloor[$rv] -gt $floor) {
            $floor = $reversibilityFloor[$rv]
        }
    }
    $rs = $riskSurface[$task]
    if ($rs -ne "") {
        if (-not $surfaceFloor.ContainsKey($rs)) {
            $failures += "$task has invalid Risk Surface: $rs"
        } elseif ($surfaceFloor[$rs] -gt $floor) {
            $floor = $surfaceFloor[$rs]
        }
    }
    if ($floor -gt 0 -and $rank.ContainsKey($r) -and $rank[$r] -lt $floor) {
        $failures += "$task Risk: $r is inconsistent with its structured risk fields (policy floor: $($tierName[$floor]))"
    }

    # high/critical risk must declare Required Workflow: tdd (design.md:118).
    # Only checked for valid high/critical risk; low/medium unconstrained.
    if ($r -eq "high" -or $r -eq "critical") {
        $rw = $requiredWorkflow[$task]
        if ($rw -eq "") {
            $failures += "$task (risk $r) must declare Required Workflow: tdd (none found)"
        } elseif ($rw -ne "tdd") {
            $failures += "$task (risk $r) must declare Required Workflow: tdd, found: $rw"
        }
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
