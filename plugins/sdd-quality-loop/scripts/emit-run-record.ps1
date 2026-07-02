# Deterministic run-record emitter for WFI effect measurement.
# Usage: emit-run-record.ps1 -Feature <slug> [-Track full|lite] [-ModelMain <id>]
#                            [-ModelReviewers <id>] [-PluginVersion <version>]
#
# Mirrors emit-run-record.sh exactly. Writes
# reports/runs/RUN-<UTC-timestamp>-<feature>.json from repository artifacts
# only. All metrics are counts, never percentages. Fail-closed: exits 1 when
# the feature's tasks.md is missing.
param(
    [Parameter(Mandatory)][string]$Feature,
    [string]$Track = "unknown",
    [string]$ModelMain = "unknown",
    [string]$ModelReviewers = "unknown",
    [string]$PluginVersion = "unknown"
)

$ErrorActionPreference = "Stop"

$tasksPath = "specs/$Feature/tasks.md"
if (-not (Test-Path $tasksPath)) {
    Write-Error "emit-run-record: tasks file not found: $tasksPath"
    exit 1
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$fileStamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$outDir = "reports/runs"
$out = "$outDir/RUN-$fileStamp-$Feature.json"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# --- Task counts from tasks.md (CRLF tolerated) --------------------------
$taskLines = (Get-Content -Encoding Utf8 $tasksPath) -replace "`r$", ""
$taskIds = @($taskLines | Where-Object { $_ -match '^## (T-\d+)' } | ForEach-Object { $Matches[1] })
$tasksTotal = $taskIds.Count
$tasksDone = @($taskLines | Where-Object { $_ -match '^Status:\s*Done\s*$' }).Count
$tasksBlocked = @($taskLines | Where-Object { $_ -match '^Status:\s*Blocked\s*$' }).Count

# --- Quality-gate reports per task ----------------------------------------
$gateTotal = 0
$gateBlocked = 0
$firstPassTasks = 0
$maxGateRuns = 0
if (Test-Path "reports/quality-gate") {
    $gateFiles = Get-ChildItem "reports/quality-gate" -File -Recurse
    foreach ($tid in $taskIds) {
        $n = @($gateFiles | Where-Object {
            (Get-Content -Raw -Encoding Utf8 $_.FullName) -match "Task: $tid\b"
        }).Count
        $gateTotal += $n
        if ($n -gt $maxGateRuns) { $maxGateRuns = $n }
        if ($n -eq 1) { $firstPassTasks++ }
    }
    $gateBlocked = @($gateFiles | Where-Object {
        (Get-Content -Raw -Encoding Utf8 $_.FullName) -match "BLOCKED"
    }).Count
}

# --- Review tickets by severity --------------------------------------------
$ticketsCritical = 0
$ticketsMajor = 0
$ticketsMinor = 0
if (Test-Path "docs/review-tickets") {
    $ticketFiles = Get-ChildItem "docs/review-tickets" -File -Recurse
    foreach ($tf in $ticketFiles) {
        $content = Get-Content -Raw -Encoding Utf8 $tf.FullName
        if ($content -match 'severity:\s*critical') { $ticketsCritical++ }
        elseif ($content -match 'severity:\s*major') { $ticketsMajor++ }
        elseif ($content -match 'severity:\s*minor') { $ticketsMinor++ }
    }
}

# --- Active (Applied) WFIs --------------------------------------------------
$activeWfis = @()
if (Test-Path "docs/workflow-improvements") {
    foreach ($wfi in Get-ChildItem "docs/workflow-improvements" -Filter "WFI-*.md" -File) {
        # Only bare WFI-NNN files carry status; skip audit-artifact suffixes.
        if ($wfi.BaseName -notmatch '^WFI-\d+$') { continue }
        $lines = (Get-Content -Encoding Utf8 $wfi.FullName) -replace "`r$", ""
        if (@($lines | Where-Object { $_ -match '^Status:\s*Applied\s*$' }).Count -gt 0) {
            $activeWfis += $wfi.BaseName
        }
    }
}

$record = [ordered]@{
    schema = "sdd-run-record/v1"
    run_id = "$fileStamp-$Feature"
    generated = $timestamp
    feature = $Feature
    track = $Track
    model_ids = [ordered]@{ main = $ModelMain; reviewers = $ModelReviewers }
    plugin_version = $PluginVersion
    active_wfis = $activeWfis
    metrics = [ordered]@{
        tasks = [ordered]@{ done = $tasksDone; blocked = $tasksBlocked; total = $tasksTotal }
        first_pass_gate = [ordered]@{ passed_first_try = $firstPassTasks; total = $tasksTotal }
        gate_reports = [ordered]@{ total = $gateTotal; blocked = $gateBlocked; max_runs_single_task = $maxGateRuns }
        review_tickets = [ordered]@{ critical = $ticketsCritical; major = $ticketsMajor; minor = $ticketsMinor }
    }
}

$record | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 $out
Write-Host "emit-run-record: wrote $out"
