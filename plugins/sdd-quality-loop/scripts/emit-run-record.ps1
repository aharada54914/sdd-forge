# Deterministic run-record emitter for WFI effect measurement.
# Usage: emit-run-record.ps1 -Feature <slug> [-Track full|lite] [-ModelMain <id>]
#                            [-ModelReviewers <id>] [-PluginVersion <version>]
#                            [-EffortMain <e>] [-EffortReviewers <e>]
#                            [-EffortControlMain <flag|frontmatter|none>]
#                            [-EffortControlReviewers <flag|frontmatter|none>]
#                            [-EffortAppliedMain <e|none>]
#                            [-EffortAppliedReviewers <e|none>]
#
# Mirrors emit-run-record.sh exactly. Writes
# reports/runs/RUN-<UTC-timestamp>-<feature>.json from repository artifacts
# only. All metrics are counts, never percentages. Fail-closed: exits 1 when
# the feature's tasks.md is missing.
#
# schema: emitted "sdd-run-record/v1" (unchanged, byte-identical to every
# pre-feature invocation) unless ANY -Effort* parameter below is bound, in
# which case "sdd-run-record/v2" is emitted with an additive sibling
# "effort" object (main/reviewers, each carrying effort_requested/
# effort_applied/effort_degraded_reason). effort_applied can only ever
# reach a non-null value through the confirmed-application path (an
# -EffortApplied<Role> value paired with -EffortControl<Role> "flag");
# every other combination structurally yields null + a named
# effort_degraded_reason (security-spec.md B4).
param(
    [Parameter(Mandatory)][string]$Feature,
    [string]$Track = "unknown",
    [string]$ModelMain = "unknown",
    [string]$ModelReviewers = "unknown",
    [string]$PluginVersion = "unknown",
    [string]$EffortMain,
    [string]$EffortReviewers,
    [string]$EffortControlMain,
    [string]$EffortControlReviewers,
    [string]$EffortAppliedMain,
    [string]$EffortAppliedReviewers
)

$ErrorActionPreference = "Stop"

# --- PowerShell case-sensitivity layer 1: ordinal enum membership check ----
# -Effort*Control* values must match {flag, frontmatter, none} exactly
# (never PowerShell's default case-insensitive comparison) -- a mis-cased
# value (e.g. "Flag") is rejected fail-closed rather than silently aliased.
$validEffortControls = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("flag", "frontmatter", "none"),
    [System.StringComparer]::Ordinal)

function Assert-EffortControlValue([string]$FlagName, [string]$Value) {
    if (-not $validEffortControls.Contains($Value)) {
        [Console]::Error.WriteLine("emit-run-record: $FlagName must be one of flag|frontmatter|none (got: $Value)")
        exit 1
    }
}

if ($PSBoundParameters.ContainsKey('EffortControlMain')) {
    Assert-EffortControlValue "-EffortControlMain" $EffortControlMain
}
if ($PSBoundParameters.ContainsKey('EffortControlReviewers')) {
    Assert-EffortControlValue "-EffortControlReviewers" $EffortControlReviewers
}

$emitV2 = $PSBoundParameters.ContainsKey('EffortMain') `
    -or $PSBoundParameters.ContainsKey('EffortReviewers') `
    -or $PSBoundParameters.ContainsKey('EffortControlMain') `
    -or $PSBoundParameters.ContainsKey('EffortControlReviewers') `
    -or $PSBoundParameters.ContainsKey('EffortAppliedMain') `
    -or $PSBoundParameters.ContainsKey('EffortAppliedReviewers')

# --- PowerShell case-sensitivity layer 2: -ceq branch dispatch --------------
# Resolve-EffortSlot's own control-value comparisons use -ceq exclusively
# (never bare -eq), independent of layer 1's entry gate above, mirroring the
# 2-layer discipline established in select-agent-model.ps1/
# render-agent-frontmatter.ps1 (T-002/T-003).
function Resolve-EffortSlot {
    param(
        [bool]$RequestedSet,
        [string]$RequestedValue,
        [string]$ControlValue,
        [bool]$AppliedSet,
        [string]$AppliedValue
    )
    if (-not $RequestedSet) {
        return [ordered]@{ effort_requested = $null; effort_applied = $null; effort_degraded_reason = $null }
    }

    if ($AppliedSet -and $AppliedValue -cne "none") {
        if ($ControlValue -cne "flag") {
            [Console]::Error.WriteLine("emit-run-record: -EffortApplied* requires the paired -EffortControl* to resolve to `"flag`" (got: $ControlValue)")
            exit 1
        }
        return [ordered]@{ effort_requested = $RequestedValue; effort_applied = $AppliedValue; effort_degraded_reason = $null }
    }

    $reason = $null
    if ($ControlValue -ceq "frontmatter") {
        $reason = "effort-control-frontmatter"
    } elseif ($ControlValue -ceq "none") {
        $reason = "effort-control-none"
    } elseif ($ControlValue -ceq "flag") {
        if ($AppliedSet) { $reason = "effort-application-declined" } else { $reason = "effort-application-not-confirmed" }
    } else {
        $reason = "effort-control-unspecified"
    }
    return [ordered]@{ effort_requested = $RequestedValue; effort_applied = $null; effort_degraded_reason = $reason }
}

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

# --- Quality-gate reports per task (scoped to this feature) ----------------
# Task IDs (T-NNN) restart per feature, so the same bare id lives in every
# feature's reports. Restrict counting to reports whose own "Feature:" line
# names this feature -- the same per-feature identity the evidence-bundle
# validator keys on -- or T-002 from ci-mcp, sdd-domain, local-env-mcp, ...
# would all be folded into one feature's totals. \s* tolerates a CRLF carriage
# return on the Feature line.
$gateTotal = 0
$gateBlocked = 0
$firstPassTasks = 0
$maxGateRuns = 0
if (Test-Path "reports/quality-gate") {
    $featureGateFiles = @(Get-ChildItem "reports/quality-gate" -File -Recurse | Where-Object {
        (Get-Content -Raw -Encoding Utf8 $_.FullName) -match "(?m)^Feature:\s*$([regex]::Escape($Feature))\s*$"
    })
    foreach ($tid in $taskIds) {
        $n = @($featureGateFiles | Where-Object {
            (Get-Content -Raw -Encoding Utf8 $_.FullName) -match "Task: $tid\b"
        }).Count
        $gateTotal += $n
        if ($n -gt $maxGateRuns) { $maxGateRuns = $n }
        if ($n -eq 1) { $firstPassTasks++ }
    }
    $gateBlocked = @($featureGateFiles | Where-Object {
        (Get-Content -Raw -Encoding Utf8 $_.FullName) -match "(?m)^VERDICT:\s*BLOCKED\s*$"
    }).Count
}

# --- Review tickets by severity (scoped to this feature) -------------------
# The ticket schema (references/review-ticket-rules.md) keys a ticket to its
# subject via target.feature. Without that scope every open ticket in the repo,
# regardless of which feature it targets, is charged to this run record.
$ticketsCritical = 0
$ticketsMajor = 0
$ticketsMinor = 0
if (Test-Path "docs/review-tickets") {
    $ticketFiles = Get-ChildItem "docs/review-tickets" -File -Recurse
    foreach ($tf in $ticketFiles) {
        $content = Get-Content -Raw -Encoding Utf8 $tf.FullName
        if ($content -notmatch "(?m)^\s*feature:\s*$([regex]::Escape($Feature))\s*$") { continue }
        # Anchor to the top-level severity field; an unanchored match would also
        # pick up the word in free-text prose (e.g. a resolution_record).
        if ($content -match '(?m)^severity:\s*critical\s*$') { $ticketsCritical++ }
        elseif ($content -match '(?m)^severity:\s*major\s*$') { $ticketsMajor++ }
        elseif ($content -match '(?m)^severity:\s*minor\s*$') { $ticketsMinor++ }
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

if ($emitV2) {
    $effortMainSlot = Resolve-EffortSlot `
        -RequestedSet $PSBoundParameters.ContainsKey('EffortMain') -RequestedValue $EffortMain `
        -ControlValue $EffortControlMain `
        -AppliedSet $PSBoundParameters.ContainsKey('EffortAppliedMain') -AppliedValue $EffortAppliedMain
    $effortReviewersSlot = Resolve-EffortSlot `
        -RequestedSet $PSBoundParameters.ContainsKey('EffortReviewers') -RequestedValue $EffortReviewers `
        -ControlValue $EffortControlReviewers `
        -AppliedSet $PSBoundParameters.ContainsKey('EffortAppliedReviewers') -AppliedValue $EffortAppliedReviewers

    $record = [ordered]@{
        schema = "sdd-run-record/v2"
        run_id = "$fileStamp-$Feature"
        generated = $timestamp
        feature = $Feature
        track = $Track
        model_ids = [ordered]@{ main = $ModelMain; reviewers = $ModelReviewers }
        effort = [ordered]@{
            main = $effortMainSlot
            reviewers = $effortReviewersSlot
        }
        plugin_version = $PluginVersion
        active_wfis = $activeWfis
        metrics = [ordered]@{
            tasks = [ordered]@{ done = $tasksDone; blocked = $tasksBlocked; total = $tasksTotal }
            first_pass_gate = [ordered]@{ passed_first_try = $firstPassTasks; total = $tasksTotal }
            gate_reports = [ordered]@{ total = $gateTotal; blocked = $gateBlocked; max_runs_single_task = $maxGateRuns }
            review_tickets = [ordered]@{ critical = $ticketsCritical; major = $ticketsMajor; minor = $ticketsMinor }
        }
    }
} else {
    # v1 shape, byte-identical to every pre-feature invocation (AC-025). This
    # branch is intentionally an exact, unmodified copy of the pre-T-004
    # record construction -- never touched when adding v2 fields above, so
    # the no-flags code path can never silently drift from v1's historical
    # shape.
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
}

$record | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 $out
Write-Host "emit-run-record: wrote $out"
exit 0
