# tests/lib/loop-driver.ps1 - PowerShell twin of tests/lib/loop-driver.sh,
# byte-equivalent in coverage (A2 / Issue #142 / epic-159-pillar-a REQ-002).
# See tests/lib/loop-driver.sh for the full design rationale (symlink
# skeleton for dirname-rooted scripts, cp-not-symlink for reference docs,
# repository-root-as-argument for validate-review-context-set, physical
# path normalization). Dot-sourced by tests/loop-driver.tests.ps1; defines
# functions only, never executed directly.
#
# Public functions:
#   Initialize-LoopFixture -Profile <greenfield|brownfield> -Feature <name>
#   Invoke-DriveReviewRound -Stage <s> -Attempt <n> -Round <n> -Verdict <v> [-Severity <s>]
#   Test-PriorRoundComplete -Stage <s> -RoundDir <path>
#   Test-ArtifactsSchema -Dir <path>
#   Test-LoopTerminal -LoopId <id> -Observed <state> [-ExitCode <n>]
#   Test-RuntimeBudget -Start <epoch> [-Budget <seconds>]
#
# Environment:
#   SDD_LOOP_REPO_ROOT  - checkout whose REAL gate scripts are driven
#   LOOP_INVENTORY_PATH - loop-inventory/v1 JSON path
#   LOOP_FIXTURE_SEED   - brownfield seed directory
#
# Scope note (tasks.md T-002 Out of Scope): Invoke-DriveReviewRound only
# fully implements stage "spec"; impl/task/domain are refused explicitly.
# spec-review-precheck.ps1 does not exist anywhere in this repository at
# T-002 time (only the .sh form exists), so the "spec" stage resolves its
# script by substituting .sh -> .ps1 in the inventory-registered path and
# fails cleanly when that file is absent; the calling suite turns that into
# a named SKIP rather than a false green or an unrelated failure (see
# tests/loop-driver.tests.ps1 TEST-006 and this task's implementation
# report).

if ($script:_LoopDriverSourced) { return }
$script:_LoopDriverSourced = $true

$script:LoopSuiteBudgetSeconds = 300
if ($env:LOOP_SUITE_BUDGET_SECONDS) { $script:LoopSuiteBudgetSeconds = [int]$env:LOOP_SUITE_BUDGET_SECONDS }

$script:LoopDriverLibDir = $PSScriptRoot
$script:SddLoopRepoRoot = $env:SDD_LOOP_REPO_ROOT
if ([string]::IsNullOrEmpty($script:SddLoopRepoRoot)) {
    $script:SddLoopRepoRoot = (Resolve-Path (Join-Path $script:LoopDriverLibDir "../..")).Path
}
$script:LoopInventoryPath = $env:LOOP_INVENTORY_PATH
if ([string]::IsNullOrEmpty($script:LoopInventoryPath)) {
    $script:LoopInventoryPath = Join-Path $script:SddLoopRepoRoot "tests/loops/loop-inventory.json"
}

function Get-LoopSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Get-LoopSha256Text([string]$Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return -join ($hash | ForEach-Object { $_.ToString("x2") })
}
function Invoke-LoopJq {
    param([string[]]$JqArgs, [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $out = & jq @JqArgs $Path 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

function Get-LoopIdForStage([string]$Stage) {
    switch ($Stage) {
        "spec" { return "spec-review" }
        "impl" { return "impl-review" }
        "task" { return "task-review" }
        "domain" { return "domain-review" }
        default { return $null }
    }
}

function Get-LoopDriverScript([string]$Stage) {
    $id = Get-LoopIdForStage $Stage
    if (-not $id) { return $null }
    return (Invoke-LoopJq @("-r", "--arg", "id", $id, '.loops[] | select(.id == $id) | .driver_scripts[0] // empty') $script:LoopInventoryPath)
}

# ---------------------------------------------------------------------------
# Initialize-LoopFixture -Profile <greenfield|brownfield> -Feature <name>
# ---------------------------------------------------------------------------
function Initialize-LoopFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Profile,
        [Parameter(Mandatory = $true)][string]$Feature
    )
    if ($Profile -ne "greenfield" -and $Profile -ne "brownfield") {
        Write-Error "Initialize-LoopFixture: unknown profile: $Profile (want greenfield|brownfield)"
        return $false
    }
    if ($Feature -notmatch '^[a-z0-9][a-z0-9-]*$') {
        Write-Error "Initialize-LoopFixture: invalid feature slug: $Feature"
        return $false
    }

    $root = Join-Path ([IO.Path]::GetTempPath()) ("loop-fixture." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root | Out-Null
    # Physical-path normalization: mirrors the bash twin's `pwd -P` step so
    # that path strings this library writes into reviewer/contract JSON
    # match whatever a driven script's own root resolution computes.
    $root = (Resolve-Path -LiteralPath $root).Path

    if ($root -eq $script:SddLoopRepoRoot -or $root.StartsWith($script:SddLoopRepoRoot + [IO.Path]::DirectorySeparatorChar)) {
        Write-Error "Initialize-LoopFixture: fixture root resolved inside the repository working tree"
        return $false
    }

    if ($Profile -eq "brownfield") {
        $seed = $env:LOOP_FIXTURE_SEED
        if ([string]::IsNullOrEmpty($seed) -or -not (Test-Path -LiteralPath $seed -PathType Container)) {
            Write-Error "Initialize-LoopFixture: brownfield profile requires LOOP_FIXTURE_SEED to name an existing directory"
            return $false
        }
        Copy-Item -Path (Join-Path $seed "*") -Destination $root -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (-not (Copy-LoopFixtureScripts $root)) { return $false }
    if (-not (Copy-LoopFixtureReferences $root)) { return $false }

    New-Item -ItemType Directory -Path (Join-Path $root "specs/$Feature") -Force | Out-Null
    @"
# Requirements

Spec-Review-Status: Pending

## Goals

- REQ-001: loop-driver $Profile fixture for feature $Feature (A2 / Issue #142; A3 / Issue #143).
"@ | Set-Content -LiteralPath (Join-Path $root "specs/$Feature/requirements.md") -NoNewline -Encoding utf8
    @"
# Acceptance tests

| AC-ID | Requirement | Status |
|---|---|---|
| AC-001 | REQ-001 | Planned |
"@ | Set-Content -LiteralPath (Join-Path $root "specs/$Feature/acceptance-tests.md") -NoNewline -Encoding utf8

    # impl/task-review full-profile inputs (A3 / Issue #143). See the bash
    # twin (tests/lib/loop-driver.sh) for the full rationale: design.md and
    # the four layer specs are synthesized unconditionally (harmless to
    # stages that never read them); tasks.md is deliberately NOT created
    # here (Initialize-LoopTaskFixture creates it lazily, only after both
    # upstream statuses are genuinely Passed).
    @"
# Design

Impl-Review-Status: Pending

## Components

- loop-driver $Profile fixture component for feature $Feature (A3 / Issue #143).

Feature Type: internal-tooling

Data Entities: none

Existing Data Affected: none

## Security Boundaries

- none (synthetic loop-driver fixture; no real security surface).
"@ | Set-Content -LiteralPath (Join-Path $root "specs/$Feature/design.md") -NoNewline -Encoding utf8
    @"
# Traceability

| REQ-ID | Description | Layer Spec |
|---|---|---|
| REQ-001 | loop-driver fixture requirement | ux-spec.md#req-001 |
"@ | Set-Content -LiteralPath (Join-Path $root "specs/$Feature/traceability.md") -NoNewline -Encoding utf8
    foreach ($layerName in @("ux", "frontend", "infra", "security")) {
        @"
# $layerName spec

<a id="req-001"></a>
## req-001

Synthetic $layerName layer content for loop-driver fixture REQ-001.
"@ | Set-Content -LiteralPath (Join-Path $root "specs/$Feature/$layerName-spec.md") -NoNewline -Encoding utf8
    }

    Initialize-LoopFixtureDomain $root

    New-Item -ItemType Directory -Path (Join-Path $root "reports") -Force | Out-Null

    & jq -n --arg feature $Feature '{schema_version: 1, migration_baseline_commit: "0369c8c96de2eb3179868d1949d66644488f65aa", entries: [{feature: $feature, profile: "full"}]}' |
        Set-Content -LiteralPath (Join-Path $root "specs/workflow-state-registry.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $ledgerDir = Join-Path $root "reports/review-context"
    New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null
    $genesisHash = Get-LoopSha256Text "1|genesis|loop-driver-fixture|fixture-genesis-run|fixture-genesis-session|"
    & jq -n --arg hash $genesisHash '{schema: "review-identity-ledger/v1", records: [{sequence: 1, stage: "genesis", role: "loop-driver-fixture", run_id: "fixture-genesis-run", host_session_id: "fixture-genesis-session", previous_record_sha256: "", record_sha256: $hash}]}' |
        Set-Content -LiteralPath (Join-Path $ledgerDir "identity-ledger.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $script:LoopFixtureRoot = $root
    $script:LoopFixtureFeature = $Feature
    $env:LOOP_FIXTURE_ROOT = $root
    $env:LOOP_FIXTURE_FEATURE = $Feature
    return $true
}

function Copy-LoopFixtureScripts([string]$Root) {
    $rels = @(
        "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1",
        "plugins/sdd-review-loop/scripts/review-contract-validate.ps1",
        "plugins/sdd-review-loop/scripts/impl-review-precheck.ps1",
        "plugins/sdd-review-loop/scripts/task-review-precheck.ps1",
        "plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1",
        "plugins/sdd-domain/scripts/domain-review-precheck.ps1",
        "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1",
        "plugins/sdd-quality-loop/scripts/check-risk.ps1"
    )
    foreach ($rel in $rels) {
        $src = Join-Path $script:SddLoopRepoRoot $rel
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
        $destDir = Join-Path $Root (Split-Path -Parent $rel)
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        $dest = Join-Path $Root $rel
        try {
            New-Item -ItemType SymbolicLink -Path $dest -Target $src -ErrorAction Stop | Out-Null
        } catch {
            # Symlink creation can require elevated privilege on Windows;
            # fall back to a fresh read-only copy of the real, unmodified
            # script content (never edited) so the fixture still exercises
            # the REAL script when symlinks are unavailable.
            Copy-Item -LiteralPath $src -Destination $dest -Force
        }
    }
    return $true
}

function Copy-LoopFixtureReferences([string]$Root) {
    $rels = @(
        "plugins/sdd-review-loop/references/spec-review-calibration.md",
        "plugins/sdd-review-loop/references/reviewer-calibration.md",
        "plugins/sdd-domain/references/domain-review-calibration.md",
        "contracts/workflow-state-registry.schema.json"
    )
    foreach ($rel in $rels) {
        $src = Join-Path $script:SddLoopRepoRoot $rel
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
        $destDir = Join-Path $Root (Split-Path -Parent $rel)
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination (Join-Path $Root $rel) -Force
    }
    return $true
}

# Initialize-LoopFixtureDomain -- synthesizes the canonical domain/ tree
# (domain-review-precheck's fixed, repo-root-relative input set; A3 / Issue
# #143) once per fixture, unconditionally, since domain-review is not
# feature-scoped.
function Initialize-LoopFixtureDomain([string]$Root) {
    $domainDir = Join-Path $Root "domain"
    New-Item -ItemType Directory -Path (Join-Path $domainDir "aggregates") -Force | Out-Null
    @"
# Context map

Domain-Model-Status: Pending

## Contexts

- loop-driver-fixture-context: synthetic bounded context for the loop-driver domain fixture.
"@ | Set-Content -LiteralPath (Join-Path $domainDir "context-map.md") -NoNewline -Encoding utf8
    foreach ($name in @("domain-story", "event-storming", "ubiquitous-language", "message-flow", "c4-container")) {
        @"
# $name

Synthetic $name content for the loop-driver domain fixture (A3 / Issue #143).
"@ | Set-Content -LiteralPath (Join-Path $domainDir "$name.md") -NoNewline -Encoding utf8
    }
    & jq -n '{schema: "domain-contract/v1", contexts: ["loop-driver-fixture-context"]}' |
        Set-Content -LiteralPath (Join-Path $domainDir "domain-contract.json") -Encoding utf8
    @"
# loop-driver-fixture aggregate

Synthetic aggregate card for the loop-driver domain fixture.
"@ | Set-Content -LiteralPath (Join-Path $domainDir "aggregates/loop-driver-fixture.md") -NoNewline -Encoding utf8
}

# Initialize-LoopTaskFixture -Feature <name> -- lazily synthesizes tasks.md,
# called by Invoke-LoopDriveTaskRound immediately before the first task
# round it drives. Deferred for the same reason as the bash twin: tasks.md
# merely existing forces check-workflow-state.ps1's task-lifecycle gate to
# require both Spec-Review-Status and Impl-Review-Status to already read
# Passed.
function Initialize-LoopTaskFixture([string]$Feature) {
    $tasksPath = Join-Path $script:LoopFixtureRoot "specs/$Feature/tasks.md"
    if (Test-Path -LiteralPath $tasksPath -PathType Leaf) { return $true }
    @"
# Tasks

Task-Review-Status: Pending

## T-001 loop-driver fixture task

Approval: Draft

Status: Planned

Risk: low

Risk Rationale: synthetic loop-driver fixture task; no real change surface.

Blockers: None
"@ | Set-Content -LiteralPath $tasksPath -NoNewline -Encoding utf8
    return $true
}

# Set-LoopStatusField -File <path> -Field <name> -Value <value> -- flips a
# canonical status header field (e.g. "Spec-Review-Status") in place.
function Set-LoopStatusField([string]$File, [string]$Field, [string]$Value) {
    $content = Get-Content -LiteralPath $File -Raw
    $pattern = "(?m)^${Field}:[ \t]*.*$"
    $replacement = "${Field}: ${Value}"
    ($content -replace $pattern, $replacement) | Set-Content -LiteralPath $File -NoNewline -Encoding utf8
}

# ---------------------------------------------------------------------------
# Manifest helpers
# ---------------------------------------------------------------------------
function Get-LoopManifestEntry([string]$Rel) {
    $abs = Join-Path $script:LoopFixtureRoot $Rel
    $item = Get-Item -LiteralPath $abs -ErrorAction SilentlyContinue
    if (-not $item -or $item.LinkType) {
        Write-Error "Get-LoopManifestEntry: missing or symlinked artifact: $Rel"
        return $null
    }
    $sha = Get-LoopSha256 $abs
    return (& jq -n --arg path $Rel --arg sha256 $sha '{path: $path, sha256: $sha256}')
}

function Get-LoopManifestArray([string[]]$Rels) {
    $entries = @()
    foreach ($rel in $Rels) {
        $entry = Get-LoopManifestEntry $rel
        if ($null -eq $entry) { return $null }
        $entries += $entry
    }
    return ($entries -join "`n" | & jq -sc '.')
}

function Get-LoopNextSequence {
    return [int](Invoke-LoopJq @("-r", '(.records | length) + 1') (Join-Path $script:LoopFixtureRoot "reports/review-context/identity-ledger.json"))
}
function Get-LoopPreviousHash {
    return (Invoke-LoopJq @("-r", '.records[-1].record_sha256') (Join-Path $script:LoopFixtureRoot "reports/review-context/identity-ledger.json"))
}

function Invoke-LoopReviewContextCall {
    param([string]$Stage, [string]$Role, [string]$Feature, [string]$ManifestEntries, [string]$Mode = "reserve")
    $validator = Join-Path $script:SddLoopRepoRoot "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        Write-Error "Invoke-LoopReviewContextCall: validator missing: $validator"
        return $false
    }
    $ledger = Join-Path $script:LoopFixtureRoot "reports/review-context/identity-ledger.json"
    $ledgerSha = Get-LoopSha256 $ledger
    $sequence = Get-LoopNextSequence
    $previous = Get-LoopPreviousHash
    $runId = "fixture-$Role-$Feature-seq$sequence"
    $session = "fixture-session-$Role-seq$sequence"
    $manifestPath = Join-Path ([IO.Path]::GetTempPath()) ("loop-manifest." + [Guid]::NewGuid().ToString("N") + ".json")
    & jq -n --arg schema "review-context-invocation/v2" --arg stage $Stage --arg role $Role `
        --arg feature $Feature --arg run_id $runId --arg session $session `
        --argjson sequence $sequence --arg previous $previous `
        --arg ledger_path "reports/review-context/identity-ledger.json" --arg ledger_sha $ledgerSha `
        --argjson manifest $ManifestEntries `
        '{schema: $schema, stage: $stage, role: $role, feature: $feature, run_id: $run_id, host_session_id: $session, sequence: $sequence, previous_record_sha256: $previous, identity_ledger_path: $ledger_path, identity_ledger_sha256: $ledger_sha, input_mode: "file-manifest", fallback_mode: "none", read_only: true, allowed_input_manifest: $manifest}' |
        Set-Content -LiteralPath $manifestPath -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Remove-Item -LiteralPath $manifestPath -ErrorAction SilentlyContinue; return $false }

    if ($Mode -eq "check") {
        & $validator -Manifest $manifestPath -RepositoryRoot $script:LoopFixtureRoot | Out-Null
    } else {
        & $validator -Manifest $manifestPath -RepositoryRoot $script:LoopFixtureRoot -Reserve | Out-Null
    }
    $rc = $LASTEXITCODE
    Remove-Item -LiteralPath $manifestPath -ErrorAction SilentlyContinue
    return ($rc -eq 0)
}

function Invoke-LoopReserveReviewContext {
    param([string]$Stage, [string]$Role, [string]$Feature, [string]$ManifestEntries)
    return (Invoke-LoopReviewContextCall $Stage $Role $Feature $ManifestEntries "reserve")
}

# Test-LoopBidirectionalInvariant -Stage <s> -Role <r> -Feature <f> -ManifestEntries <json>
# A3 / Issue #143, AC-010: read-only re-validation (no -Reserve) of the
# manifest against the REAL validate-review-context-set.ps1 (this loop's
# cross_gates script). See tests/lib/loop-driver.sh's
# assert_bidirectional_invariant for the full rationale.
function Test-LoopBidirectionalInvariant {
    param([string]$Stage, [string]$Role, [string]$Feature, [string]$ManifestEntries)
    return (Invoke-LoopReviewContextCall $Stage $Role $Feature $ManifestEntries "check")
}

# ---------------------------------------------------------------------------
# Test-PriorRoundComplete -Stage <s> -RoundDir <path>
# ---------------------------------------------------------------------------
function Get-LoopRequiredRoundFiles([string]$Stage) {
    switch ($Stage) {
        "spec" { return @("precheck-result.json", "integrated-summary.json", "reviewer-a.json", "reviewer-b.json", "integrated-verdict.json", "spec-review-contract.json") }
        "impl" { return @("precheck-result.json", "integrated-summary.json", "reviewer-a.json", "reviewer-b.json", "integrated-verdict.json", "impl-review-contract.json") }
        "task" { return @("precheck-result.json", "dependency-graph.json", "integrated-summary.json", "reviewer-a.json", "reviewer-b.json", "integrated-verdict.json", "task-review-contract.json") }
        "domain" { return @("precheck-result.json", "integrated-summary.json", "reviewer-a.json", "reviewer-b.json", "integrated-verdict.json", "domain-review-contract.json") }
        default { return $null }
    }
}

function Test-PriorRoundComplete {
    param([Parameter(Mandatory = $true)][string]$Stage, [Parameter(Mandatory = $true)][string]$RoundDir)
    if (-not (Test-Path -LiteralPath $RoundDir -PathType Container)) { return $false }
    $names = Get-LoopRequiredRoundFiles $Stage
    if ($null -eq $names) { return $false }
    foreach ($name in $names) {
        if (-not (Test-Path -LiteralPath (Join-Path $RoundDir $name) -PathType Leaf)) { return $false }
    }
    return $true
}

# ---------------------------------------------------------------------------
# Spec-review round emission (PowerShell port of the write_contract() shape
# in tests/spec-review-loop.tests.sh:39-99, INV-008)
# ---------------------------------------------------------------------------
function Publish-LoopSpecRoundA {
    param([string]$RoundDir, [string]$Severity)
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    switch ($Severity) {
        "none"     { $aVerdict = "PASS";       $aResult = "PASS"; $aFails = 0; $aPasses = 6; $checkSeverity = "Minor" }
        "Critical" { $aVerdict = "BLOCKED";    $aResult = "FAIL"; $aFails = 1; $aPasses = 5; $checkSeverity = "Critical" }
        "Major"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5; $checkSeverity = "Major" }
        "Minor"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5; $checkSeverity = "Minor" }
        default { Write-Error "Publish-LoopSpecRoundA: unknown severity: $Severity"; return $false }
    }
    $warning = 0
    if ($round -eq 3 -and $Severity -eq "Minor") { $warning = 1 }

    $idsJq = '["REQ-TESTABILITY","GOAL-AC-TRACE","AC-OBSERVABLE","SCOPE-BOUNDARY","CONSTRAINTS-EXPLICIT","RISK-VALIDATION-SURFACE"] as $ids | {schema:"integrated-summary/v1",attempt:$attempt,round:$round,reviewer_a_checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end)})),reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}'
    & jq -n --argjson attempt 1 --argjson round $round --arg result $aResult --arg severity $checkSeverity `
        --argjson fail_count $aFails --argjson pass_count $aPasses $idsJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-summary.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $requirementsPath = Join-Path $script:LoopFixtureRoot "specs/$($script:LoopFixtureFeature)/requirements.md"
    $acceptancePath = Join-Path $script:LoopFixtureRoot "specs/$($script:LoopFixtureFeature)/acceptance-tests.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-review-loop/references/spec-review-calibration.md"
    $requirementsSha = Get-LoopSha256 $requirementsPath
    $acceptanceSha = Get-LoopSha256 $acceptancePath
    $precheckSha = Get-LoopSha256 $precheckPath
    $calibrationSha = Get-LoopSha256 $calibrationPath

    $reviewerAJq = '["REQ-TESTABILITY","GOAL-AC-TRACE","AC-OBSERVABLE","SCOPE-BOUNDARY","CONSTRAINTS-EXPLICIT","RISK-VALIDATION-SURFACE"] as $ids | {schema:"spec-reviewer-a/v1",stage:"spec",role:"spec-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha}],verdict:$verdict,checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}'
    & jq -n --arg result $aResult --arg severity $checkSeverity --arg verdict $aVerdict `
        --arg requirements $requirementsPath --arg acceptance $acceptancePath --arg precheck $precheckPath --arg calibration $calibrationPath `
        --arg requirements_sha $requirementsSha --arg acceptance_sha $acceptanceSha --arg precheck_sha $precheckSha --arg calibration_sha $calibrationSha `
        $reviewerAJq | Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-a.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Publish-LoopSpecRoundBContract {
    param([string]$RoundDir, [string]$Verdict, [string]$Severity)
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    $warning = 0
    if ($round -eq 3 -and $Severity -eq "Minor") { $warning = 1 }
    switch ($Severity) {
        "none"     { $critical = 0; $major = 0; $minor = 0 }
        "Critical" { $critical = 1; $major = 0; $minor = 0 }
        "Major"    { $critical = 0; $major = 1; $minor = 0 }
        "Minor"    { $critical = 0; $major = 0; $minor = 1 }
        default { Write-Error "Publish-LoopSpecRoundBContract: unknown severity: $Severity"; return $false }
    }

    $requirementsPath = Join-Path $script:LoopFixtureRoot "specs/$($script:LoopFixtureFeature)/requirements.md"
    $acceptancePath = Join-Path $script:LoopFixtureRoot "specs/$($script:LoopFixtureFeature)/acceptance-tests.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-review-loop/references/spec-review-calibration.md"
    $summaryPath = Join-Path $RoundDir "integrated-summary.json"
    $requirementsSha = Get-LoopSha256 $requirementsPath
    $acceptanceSha = Get-LoopSha256 $acceptancePath
    $precheckSha = Get-LoopSha256 $precheckPath
    $calibrationSha = Get-LoopSha256 $calibrationPath
    $summarySha = Get-LoopSha256 $summaryPath

    $verdictJq = '{schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:$round,reviewer_a_run_id:"fixture-a",reviewer_b_run_id:"fixture-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",finding_counts:{critical:$critical,major:$major,minor:$minor},verdict:$verdict,warningCount:$warning}'
    & jq -n --arg feature $script:LoopFixtureFeature --arg verdict $Verdict --argjson round $round --argjson warning $warning `
        --argjson critical $critical --argjson major $major --argjson minor $minor $verdictJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-verdict.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $reviewerBJq = '["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids | {schema:"spec-reviewer-b/v1",stage:"spec",role:"spec-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}],verdict:"PASS",checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}'
    & jq -n --arg requirements $requirementsPath --arg acceptance $acceptancePath --arg precheck $precheckPath --arg summary $summaryPath `
        --arg calibration $calibrationPath --arg requirements_sha $requirementsSha --arg acceptance_sha $acceptanceSha `
        --arg precheck_sha $precheckSha --arg summary_sha $summarySha --arg calibration_sha $calibrationSha `
        $reviewerBJq | Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-b.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $contractJq = '{schema:"spec-review-contract/v1",stage:"spec",feature:$feature,attempt:1,round:$round,requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,reviewers:[{role:"spec-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha256},{path:$acceptance,sha256:$acceptance_sha256},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha}]},{role:"spec-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha256},{path:$acceptance,sha256:$acceptance_sha256},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}]}],run_id:"fixture-orchestrator",verdict:$verdict,warningCount:$warning}'
    & jq -n --arg feature $script:LoopFixtureFeature --arg verdict $Verdict `
        --arg requirements_sha256 $requirementsSha --arg acceptance_sha256 $acceptanceSha `
        --argjson round $round --argjson warning $warning `
        --arg requirements $requirementsPath --arg acceptance $acceptancePath --arg precheck $precheckPath --arg summary $summaryPath --arg calibration $calibrationPath `
        --arg precheck_sha $precheckSha --arg summary_sha $summarySha --arg calibration_sha $calibrationSha `
        $contractJq | Set-Content -LiteralPath (Join-Path $RoundDir "spec-review-contract.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Get-LoopSpecManifestA([string]$RoundDir) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    return (Get-LoopManifestArray @(
        "specs/$($script:LoopFixtureFeature)/requirements.md",
        "specs/$($script:LoopFixtureFeature)/acceptance-tests.md",
        "plugins/sdd-review-loop/references/spec-review-calibration.md",
        "$roundRel/precheck-result.json"
    ))
}
function Get-LoopSpecManifestB([string]$RoundDir) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    return (Get-LoopManifestArray @(
        "specs/$($script:LoopFixtureFeature)/requirements.md",
        "specs/$($script:LoopFixtureFeature)/acceptance-tests.md",
        "plugins/sdd-review-loop/references/spec-review-calibration.md",
        "$roundRel/precheck-result.json",
        "$roundRel/integrated-summary.json"
    ))
}

function Invoke-LoopDriveSpecRound {
    param([int]$Attempt, [int]$Round, [string]$Verdict, [string]$Severity)
    $feature = $script:LoopFixtureFeature
    if ([string]::IsNullOrEmpty($feature)) {
        Write-Error "Invoke-LoopDriveSpecRound requires a fixture (call Initialize-LoopFixture first)"
        return $false
    }
    $scriptRelSh = Get-LoopDriverScript "spec"
    if ([string]::IsNullOrEmpty($scriptRelSh)) {
        Write-Error "Invoke-DriveReviewRound: spec-review driver script not registered in the inventory"
        return $false
    }
    $scriptRelPs1 = $scriptRelSh -replace '\.sh$', '.ps1'
    $scriptPath = Join-Path $script:LoopFixtureRoot $scriptRelPs1
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Error "Invoke-DriveReviewRound: precheck script missing at $scriptPath (spec-review-precheck.ps1 does not exist upstream at T-002 time; see this task's implementation report)"
        return $false
    }

    $requirementsPath = Join-Path $script:LoopFixtureRoot "specs/$feature/requirements.md"
    $precheckArgs = @($feature, $Attempt, $Round)
    if ($Round -gt 1) {
        $priorDir = Join-Path $script:LoopFixtureRoot "reports/spec-review/$feature/attempt-$Attempt/round-$($Round - 1)"
        if (-not (Test-PriorRoundComplete "spec" $priorDir)) {
            Write-Error "Invoke-DriveReviewRound: round-$($Round - 1) output set is incomplete on disk; refusing to start round $Round"
            return $false
        }
        Add-Content -LiteralPath $requirementsPath -Value "`n<!-- loop-driver round $Round edit -->`n"
        $precheckArgs += "--edit-summary=round-$Round-edit"
    }

    & $scriptPath @precheckArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }

    $roundDir = Join-Path $script:LoopFixtureRoot "reports/spec-review/$feature/attempt-$Attempt/round-$Round"
    if (-not (Test-Path -LiteralPath (Join-Path $roundDir "precheck-result.json") -PathType Leaf)) {
        Write-Error "Invoke-DriveReviewRound: precheck-result.json missing after a successful precheck run"
        return $false
    }

    $manifestA = Get-LoopSpecManifestA $roundDir
    if ($null -eq $manifestA) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "spec" "spec-reviewer-a" $feature $manifestA)) { return $false }
    if (-not (Publish-LoopSpecRoundA $roundDir $Severity)) { return $false }

    $manifestB = Get-LoopSpecManifestB $roundDir
    if ($null -eq $manifestB) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "spec" "spec-reviewer-b" $feature $manifestB)) { return $false }
    if (-not (Publish-LoopSpecRoundBContract $roundDir $Verdict $Severity)) { return $false }

    return $true
}

# =============================================================================
# A3 / Issue #143 stage dispatch extension: impl/task/domain review rounds.
# See tests/lib/loop-driver.sh for the full scope-adjudication rationale;
# this is the byte-equivalent PowerShell twin of that extension.
# =============================================================================

function Get-LoopImplLayerNames { return @("ux-spec", "frontend-spec", "infra-spec", "security-spec") }

function Get-LoopImplLayerShaJson([string]$Feature) {
    $obj = [ordered]@{}
    foreach ($name in (Get-LoopImplLayerNames)) {
        $path = Join-Path $script:LoopFixtureRoot "specs/$Feature/$name.md"
        $obj["$name.md"] = Get-LoopSha256 $path
    }
    return ($obj | ConvertTo-Json -Compress)
}

function Publish-LoopImplRoundA {
    param([string]$RoundDir, [string]$Severity)
    $feature = $script:LoopFixtureFeature
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    switch ($Severity) {
        "none"     { $aVerdict = "PASS";       $aResult = "PASS"; $aFails = 0; $aPasses = 6 }
        "Critical" { $aVerdict = "BLOCKED";    $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        "Major"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        "Minor"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        default { Write-Error "Publish-LoopImplRoundA: unknown severity: $Severity"; return $false }
    }
    $checkSeverity = if ($Severity -eq "none") { "Minor" } else { $Severity }

    $summaryJq = '["INPUT-COMPLETENESS","DESIGN-ALIGNMENT","LAYER-COVERAGE","RISK-SURFACE","IMPLEMENTABILITY","SCOPE-BOUNDARY"] as $ids | {schema:"integrated-summary/v1",attempt:$attempt,round:$round,reviewer_a_check_ids:$ids,reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}'
    & jq -n --argjson attempt 1 --argjson round $round --argjson fail_count $aFails --argjson pass_count $aPasses $summaryJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-summary.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $requirementsPath = Join-Path $script:LoopFixtureRoot "specs/$feature/requirements.md"
    $acceptancePath = Join-Path $script:LoopFixtureRoot "specs/$feature/acceptance-tests.md"
    $designPath = Join-Path $script:LoopFixtureRoot "specs/$feature/design.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-review-loop/references/reviewer-calibration.md"
    $requirementsSha = Get-LoopSha256 $requirementsPath
    $acceptanceSha = Get-LoopSha256 $acceptancePath
    $designSha = Get-LoopSha256 $designPath
    $precheckSha = Get-LoopSha256 $precheckPath
    $calibrationSha = Get-LoopSha256 $calibrationPath

    # Manifest path VALUES must use forward slashes on every host: Windows
    # Join-Path yields backslashes, which the forward-slash assertions (e.g.
    # loop-consistency TEST-008.7) and any suffix matching never accept.
    $manifestJq = '[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$design,sha256:$design_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha}]'
    $manifestJson = & jq -n --arg requirements ($requirementsPath -replace '\\', '/') --arg requirements_sha $requirementsSha `
        --arg acceptance ($acceptancePath -replace '\\', '/') --arg acceptance_sha $acceptanceSha `
        --arg design ($designPath -replace '\\', '/') --arg design_sha $designSha `
        --arg precheck ($precheckPath -replace '\\', '/') --arg precheck_sha $precheckSha `
        --arg calibration ($calibrationPath -replace '\\', '/') --arg calibration_sha $calibrationSha $manifestJq
    foreach ($name in (Get-LoopImplLayerNames)) {
        $lpath = Join-Path $script:LoopFixtureRoot "specs/$feature/$name.md"
        $lsha = Get-LoopSha256 $lpath
        $manifestJson = $manifestJson | & jq -c --arg p ($lpath -replace '\\', '/') --arg s $lsha '. + [{path:$p,sha256:$s}]'
    }
    if ($round -gt 1) {
        $priorSummary = Join-Path $script:LoopFixtureRoot "reports/impl-review/$feature/attempt-1/round-$($round - 1)/integrated-summary.json"
        $priorSha = Get-LoopSha256 $priorSummary
        $manifestJson = $manifestJson | & jq -c --arg p ($priorSummary -replace '\\', '/') --arg s $priorSha '. + [{path:$p,sha256:$s}]'
    }

    $reviewerAJq = '["INPUT-COMPLETENESS","DESIGN-ALIGNMENT","LAYER-COVERAGE","RISK-SURFACE","IMPLEMENTABILITY","SCOPE-BOUNDARY"] as $ids | {schema:"impl-reviewer-a/v1",stage:"impl",role:"impl-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:$manifest,verdict:$verdict,checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}'
    & jq -n --arg verdict $aVerdict --argjson manifest $manifestJson --arg result $aResult --arg severity $checkSeverity $reviewerAJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-a.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Publish-LoopImplRoundBContract {
    param([string]$RoundDir, [string]$Verdict, [string]$Severity)
    $feature = $script:LoopFixtureFeature
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    switch ($Severity) {
        "none"     { $critical = 0; $major = 0; $minor = 0 }
        "Critical" { $critical = 1; $major = 0; $minor = 0 }
        "Major"    { $critical = 0; $major = 1; $minor = 0 }
        "Minor"    { $critical = 0; $major = 0; $minor = 1 }
        default { Write-Error "Publish-LoopImplRoundBContract: unknown severity: $Severity"; return $false }
    }
    $aVerdict = if ($critical -gt 0) { "BLOCKED" } elseif (($major + $minor) -gt 0) { "NEEDS_WORK" } else { "PASS" }

    $requirementsPath = Join-Path $script:LoopFixtureRoot "specs/$feature/requirements.md"
    $acceptancePath = Join-Path $script:LoopFixtureRoot "specs/$feature/acceptance-tests.md"
    $designPath = Join-Path $script:LoopFixtureRoot "specs/$feature/design.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-review-loop/references/reviewer-calibration.md"
    $summaryPath = Join-Path $RoundDir "integrated-summary.json"
    $requirementsSha = Get-LoopSha256 $requirementsPath
    $acceptanceSha = Get-LoopSha256 $acceptancePath
    $designSha = Get-LoopSha256 $designPath
    $precheckSha = Get-LoopSha256 $precheckPath
    $calibrationSha = Get-LoopSha256 $calibrationPath
    $summarySha = Get-LoopSha256 $summaryPath
    $layerSha = Get-LoopImplLayerShaJson $feature

    $verdictJq = '{schema:"integrated-verdict/v1",stage:"impl",feature:$feature,attempt:1,round:$round,run_id:"fixture-orchestrator",verdict:$verdict,reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",findings_critical:$critical,findings_major:$major,findings_minor:$minor}'
    & jq -n --arg feature $feature --arg verdict $Verdict --argjson round $round `
        --argjson critical $critical --argjson major $major --argjson minor $minor --arg a_verdict $aVerdict $verdictJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-verdict.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $manifestBJq = '[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$design,sha256:$design_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}]'
    $manifestBJson = & jq -n --arg requirements $requirementsPath --arg requirements_sha $requirementsSha `
        --arg acceptance $acceptancePath --arg acceptance_sha $acceptanceSha `
        --arg design $designPath --arg design_sha $designSha `
        --arg precheck $precheckPath --arg precheck_sha $precheckSha `
        --arg calibration $calibrationPath --arg calibration_sha $calibrationSha `
        --arg summary $summaryPath --arg summary_sha $summarySha $manifestBJq
    foreach ($name in (Get-LoopImplLayerNames)) {
        $lpath = Join-Path $script:LoopFixtureRoot "specs/$feature/$name.md"
        $lsha = Get-LoopSha256 $lpath
        $manifestBJson = $manifestBJson | & jq -c --arg p $lpath --arg s $lsha '. + [{path:$p,sha256:$s}]'
    }
    $reviewerBJq = '["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids | {schema:"impl-reviewer-b/v1",stage:"impl",role:"impl-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:$manifest,verdict:"PASS",checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}'
    & jq -n --argjson manifest $manifestBJson $reviewerBJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-b.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $manifestAJson = @(Invoke-LoopJq @("-c", ".allowed_input_manifest") (Join-Path $RoundDir "reviewer-a.json")) -join "`n"
    $contractJq = '{schema:"impl-review-contract/v1",stage:"impl",feature:$feature,attempt:1,round:$round,run_id:"fixture-orchestrator",verdict:$verdict,reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",findings_critical:$critical,findings_major:$major,findings_minor:$minor,requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,design_sha256:$design_sha256,layer_sha256:$layer_sha256,reviewers:[{role:"impl-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:$manifest_a},{role:"impl-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:$manifest_b}]}'
    & jq -n --arg feature $feature --arg verdict $Verdict --argjson round $round `
        --argjson critical $critical --argjson major $major --argjson minor $minor --arg a_verdict $aVerdict `
        --arg requirements_sha256 $requirementsSha --arg acceptance_sha256 $acceptanceSha `
        --arg design_sha256 $designSha --argjson layer_sha256 $layerSha `
        --argjson manifest_a $manifestAJson --argjson manifest_b $manifestBJson $contractJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "impl-review-contract.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Get-LoopImplManifestA([string]$RoundDir, [int]$Round, [string]$Feature) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    $rels = [System.Collections.Generic.List[string]]::new()
    $rels.Add("specs/$Feature/requirements.md")
    $rels.Add("specs/$Feature/acceptance-tests.md")
    $rels.Add("specs/$Feature/design.md")
    $rels.Add("plugins/sdd-review-loop/references/reviewer-calibration.md")
    $rels.Add("$roundRel/precheck-result.json")
    foreach ($name in (Get-LoopImplLayerNames)) { $rels.Add("specs/$Feature/$name.md") }
    if ($Round -gt 1) { $rels.Add("reports/impl-review/$Feature/attempt-1/round-$($Round - 1)/integrated-summary.json") }
    return (Get-LoopManifestArray $rels.ToArray())
}
function Get-LoopImplManifestB([string]$RoundDir, [string]$Feature) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    $rels = [System.Collections.Generic.List[string]]::new()
    $rels.Add("specs/$Feature/requirements.md")
    $rels.Add("specs/$Feature/acceptance-tests.md")
    $rels.Add("specs/$Feature/design.md")
    $rels.Add("plugins/sdd-review-loop/references/reviewer-calibration.md")
    $rels.Add("$roundRel/precheck-result.json")
    $rels.Add("$roundRel/integrated-summary.json")
    foreach ($name in (Get-LoopImplLayerNames)) { $rels.Add("specs/$Feature/$name.md") }
    return (Get-LoopManifestArray $rels.ToArray())
}

# Initialize-LoopImplPrereqs -Feature <name> -- drives spec rounds 1->3 to a
# genuine PASS (reusing Invoke-LoopDriveSpecRound unmodified) and flips
# Spec-Review-Status to Passed.
function Initialize-LoopImplPrereqs([string]$Feature) {
    if (-not (Invoke-LoopDriveSpecRound -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major")) { return $false }
    if (-not (Invoke-LoopDriveSpecRound -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major")) { return $false }
    if (-not (Invoke-LoopDriveSpecRound -Attempt 1 -Round 3 -Verdict "PASS" -Severity "Minor")) { return $false }
    Set-LoopStatusField (Join-Path $script:LoopFixtureRoot "specs/$Feature/requirements.md") "Spec-Review-Status" "Passed"
    return $true
}

# Initialize-LoopTaskPrereqs -Feature <name> -- additionally drives impl
# rounds 1->3 to a genuine PASS, flips Impl-Review-Status to Passed, then
# lazily synthesizes tasks.md.
function Initialize-LoopTaskPrereqs([string]$Feature) {
    if (-not (Initialize-LoopImplPrereqs $Feature)) { return $false }
    if (-not (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major")) { return $false }
    if (-not (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major")) { return $false }
    if (-not (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 3 -Verdict "PASS" -Severity "none")) { return $false }
    Set-LoopStatusField (Join-Path $script:LoopFixtureRoot "specs/$Feature/design.md") "Impl-Review-Status" "Passed"
    Initialize-LoopTaskFixture $Feature | Out-Null
    return $true
}

function Invoke-LoopDriveImplRound {
    param([int]$Attempt, [int]$Round, [string]$Verdict, [string]$Severity)
    $feature = $script:LoopFixtureFeature
    if ([string]::IsNullOrEmpty($feature)) { Write-Error "Invoke-LoopDriveImplRound requires a fixture"; return $false }
    $scriptRel = Get-LoopDriverScript "impl"
    if ([string]::IsNullOrEmpty($scriptRel)) { Write-Error "drive_review_round: impl-review driver script not registered in the inventory"; return $false }
    $scriptRelPs1 = $scriptRel -replace '\.sh$', '.ps1'
    $scriptPath = Join-Path $script:LoopFixtureRoot $scriptRelPs1
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Error "drive_review_round: precheck script missing at $scriptPath"
        return $false
    }

    $design = Join-Path $script:LoopFixtureRoot "specs/$feature/design.md"
    if ($Round -gt 1) {
        $priorDir = Join-Path $script:LoopFixtureRoot "reports/impl-review/$feature/attempt-$Attempt/round-$($Round - 1)"
        if (-not (Test-PriorRoundComplete "impl" $priorDir)) {
            Write-Error "drive_review_round: round-$($Round - 1) output set is incomplete on disk; refusing to start round $Round"
            return $false
        }
        Add-Content -LiteralPath $design -Value "`n<!-- loop-driver round $Round edit -->`n"
    }

    & $scriptPath $feature $Attempt $Round | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }

    $roundDir = Join-Path $script:LoopFixtureRoot "reports/impl-review/$feature/attempt-$Attempt/round-$Round"
    if (-not (Test-Path -LiteralPath (Join-Path $roundDir "precheck-result.json") -PathType Leaf)) {
        Write-Error "drive_review_round: precheck-result.json missing after a successful precheck run"
        return $false
    }

    $manifestA = Get-LoopImplManifestA $roundDir $Round $feature
    if ($null -eq $manifestA) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "impl" "impl-reviewer-a" $feature $manifestA)) { return $false }
    if (-not (Publish-LoopImplRoundA $roundDir $Severity)) { return $false }

    $manifestB = Get-LoopImplManifestB $roundDir $feature
    if ($null -eq $manifestB) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "impl" "impl-reviewer-b" $feature $manifestB)) { return $false }
    if (-not (Publish-LoopImplRoundBContract $roundDir $Verdict $Severity)) { return $false }

    return $true
}

# ---------------------------------------------------------------------------
# task-review round emission
# ---------------------------------------------------------------------------
function Publish-LoopTaskRoundA {
    param([string]$RoundDir, [string]$Severity)
    $feature = $script:LoopFixtureFeature
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    switch ($Severity) {
        "none"     { $aVerdict = "PASS";       $aResult = "PASS"; $aFails = 0; $aPasses = 6 }
        "Critical" { $aVerdict = "BLOCKED";    $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        "Major"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        "Minor"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        default { Write-Error "Publish-LoopTaskRoundA: unknown severity: $Severity"; return $false }
    }
    $checkSeverity = if ($Severity -eq "none") { "Minor" } else { $Severity }

    $summaryJq = '["DEPENDENCY-GRAPH-VALID","TASK-AC-TRACE","RISK-WORKFLOW-MATCH","SCOPE-DISJOINT","ROLLBACK-PLANNED","SIZE-APPROPRIATE"] as $ids | {schema:"integrated-summary/v1",attempt:$attempt,round:$round,reviewer_a_check_ids:$ids,reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}'
    & jq -n --argjson attempt 1 --argjson round $round --argjson fail_count $aFails --argjson pass_count $aPasses $summaryJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-summary.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $tasksPath = Join-Path $script:LoopFixtureRoot "specs/$feature/tasks.md"
    $requirementsPath = Join-Path $script:LoopFixtureRoot "specs/$feature/requirements.md"
    $acceptancePath = Join-Path $script:LoopFixtureRoot "specs/$feature/acceptance-tests.md"
    $designPath = Join-Path $script:LoopFixtureRoot "specs/$feature/design.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $depPath = Join-Path $RoundDir "dependency-graph.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-review-loop/references/reviewer-calibration.md"
    $tasksSha = Get-LoopSha256 $tasksPath
    $requirementsSha = Get-LoopSha256 $requirementsPath
    $acceptanceSha = Get-LoopSha256 $acceptancePath
    $designSha = Get-LoopSha256 $designPath
    $precheckSha = Get-LoopSha256 $precheckPath
    $depSha = Get-LoopSha256 $depPath
    $calibrationSha = Get-LoopSha256 $calibrationPath

    $reviewerAJq = '["DEPENDENCY-GRAPH-VALID","TASK-AC-TRACE","RISK-WORKFLOW-MATCH","SCOPE-DISJOINT","ROLLBACK-PLANNED","SIZE-APPROPRIATE"] as $ids | {schema:"task-reviewer-a/v1",stage:"task",role:"task-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:[{path:$tasks,sha256:$tasks_sha},{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$design,sha256:$design_sha},{path:$precheck,sha256:$precheck_sha},{path:$dep,sha256:$dep_sha},{path:$calibration,sha256:$calibration_sha}],verdict:$verdict,checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}'
    & jq -n --arg verdict $aVerdict --arg result $aResult --arg severity $checkSeverity `
        --arg tasks $tasksPath --arg tasks_sha $tasksSha `
        --arg requirements $requirementsPath --arg requirements_sha $requirementsSha `
        --arg acceptance $acceptancePath --arg acceptance_sha $acceptanceSha `
        --arg design $designPath --arg design_sha $designSha `
        --arg precheck $precheckPath --arg precheck_sha $precheckSha `
        --arg dep $depPath --arg dep_sha $depSha `
        --arg calibration $calibrationPath --arg calibration_sha $calibrationSha $reviewerAJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-a.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Publish-LoopTaskRoundBContract {
    param([string]$RoundDir, [string]$Verdict, [string]$Severity)
    $feature = $script:LoopFixtureFeature
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    switch ($Severity) {
        "none"     { $critical = 0; $major = 0; $minor = 0 }
        "Critical" { $critical = 1; $major = 0; $minor = 0 }
        "Major"    { $critical = 0; $major = 1; $minor = 0 }
        "Minor"    { $critical = 0; $major = 0; $minor = 1 }
        default { Write-Error "Publish-LoopTaskRoundBContract: unknown severity: $Severity"; return $false }
    }
    $aVerdict = if ($critical -gt 0) { "BLOCKED" } elseif (($major + $minor) -gt 0) { "NEEDS_WORK" } else { "PASS" }

    $tasksPath = Join-Path $script:LoopFixtureRoot "specs/$feature/tasks.md"
    $requirementsPath = Join-Path $script:LoopFixtureRoot "specs/$feature/requirements.md"
    $acceptancePath = Join-Path $script:LoopFixtureRoot "specs/$feature/acceptance-tests.md"
    $designPath = Join-Path $script:LoopFixtureRoot "specs/$feature/design.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-review-loop/references/reviewer-calibration.md"
    $summaryPath = Join-Path $RoundDir "integrated-summary.json"
    $tasksSha = Get-LoopSha256 $tasksPath
    $requirementsSha = Get-LoopSha256 $requirementsPath
    $acceptanceSha = Get-LoopSha256 $acceptancePath
    $designSha = Get-LoopSha256 $designPath
    $precheckSha = Get-LoopSha256 $precheckPath
    $calibrationSha = Get-LoopSha256 $calibrationPath
    $summarySha = Get-LoopSha256 $summaryPath

    $verdictJq = '{schema:"integrated-verdict/v1",stage:"task",feature:$feature,attempt:1,round:$round,run_id:"fixture-orchestrator",verdict:$verdict,reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",findings_critical:$critical,findings_major:$major,findings_minor:$minor}'
    & jq -n --arg feature $feature --arg verdict $Verdict --argjson round $round `
        --argjson critical $critical --argjson major $major --argjson minor $minor --arg a_verdict $aVerdict $verdictJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-verdict.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $reviewerBJq = '["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids | {schema:"task-reviewer-b/v1",stage:"task",role:"task-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:[{path:$tasks,sha256:$tasks_sha},{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$design,sha256:$design_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}],verdict:"PASS",checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}'
    & jq -n --arg tasks $tasksPath --arg tasks_sha $tasksSha `
        --arg requirements $requirementsPath --arg requirements_sha $requirementsSha `
        --arg acceptance $acceptancePath --arg acceptance_sha $acceptanceSha `
        --arg design $designPath --arg design_sha $designSha `
        --arg precheck $precheckPath --arg precheck_sha $precheckSha `
        --arg calibration $calibrationPath --arg calibration_sha $calibrationSha `
        --arg summary $summaryPath --arg summary_sha $summarySha $reviewerBJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-b.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $manifestAJson = @(Invoke-LoopJq @("-c", ".allowed_input_manifest") (Join-Path $RoundDir "reviewer-a.json")) -join "`n"
    $manifestBJson = @(Invoke-LoopJq @("-c", ".allowed_input_manifest") (Join-Path $RoundDir "reviewer-b.json")) -join "`n"
    $contractJq = '{schema:"task-review-contract/v1",stage:"task",feature:$feature,attempt:1,round:$round,run_id:"fixture-orchestrator",verdict:$verdict,reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",findings_critical:$critical,findings_major:$major,findings_minor:$minor,tasks_sha256:$tasks_sha256,requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,reviewers:[{role:"task-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:$manifest_a},{role:"task-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:$manifest_b}]}'
    & jq -n --arg feature $feature --arg verdict $Verdict --argjson round $round `
        --argjson critical $critical --argjson major $major --argjson minor $minor --arg a_verdict $aVerdict `
        --arg tasks_sha256 $tasksSha --arg requirements_sha256 $requirementsSha --arg acceptance_sha256 $acceptanceSha `
        --argjson manifest_a $manifestAJson --argjson manifest_b $manifestBJson $contractJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "task-review-contract.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Get-LoopTaskManifestA([string]$RoundDir, [string]$Feature) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    return (Get-LoopManifestArray @(
        "specs/$Feature/tasks.md", "specs/$Feature/requirements.md", "specs/$Feature/acceptance-tests.md",
        "specs/$Feature/design.md", "plugins/sdd-review-loop/references/reviewer-calibration.md",
        "$roundRel/precheck-result.json", "$roundRel/dependency-graph.json"
    ))
}
function Get-LoopTaskManifestB([string]$RoundDir, [string]$Feature) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    return (Get-LoopManifestArray @(
        "specs/$Feature/tasks.md", "specs/$Feature/requirements.md", "specs/$Feature/acceptance-tests.md",
        "specs/$Feature/design.md", "plugins/sdd-review-loop/references/reviewer-calibration.md",
        "$roundRel/precheck-result.json", "$roundRel/integrated-summary.json"
    ))
}

function Invoke-LoopDriveTaskRound {
    param([int]$Attempt, [int]$Round, [string]$Verdict, [string]$Severity)
    $feature = $script:LoopFixtureFeature
    if ([string]::IsNullOrEmpty($feature)) { Write-Error "Invoke-LoopDriveTaskRound requires a fixture"; return $false }
    $scriptRel = Get-LoopDriverScript "task"
    if ([string]::IsNullOrEmpty($scriptRel)) { Write-Error "drive_review_round: task-review driver script not registered in the inventory"; return $false }
    $scriptRelPs1 = $scriptRel -replace '\.sh$', '.ps1'
    $scriptPath = Join-Path $script:LoopFixtureRoot $scriptRelPs1
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Error "drive_review_round: precheck script missing at $scriptPath"
        return $false
    }

    $tasks = Join-Path $script:LoopFixtureRoot "specs/$feature/tasks.md"
    if (-not (Test-Path -LiteralPath $tasks -PathType Leaf)) {
        Write-Error "drive_review_round: tasks.md missing; call Initialize-LoopTaskPrereqs first"
        return $false
    }
    if ($Round -gt 1) {
        $priorDir = Join-Path $script:LoopFixtureRoot "reports/task-review/$feature/attempt-$Attempt/round-$($Round - 1)"
        if (-not (Test-PriorRoundComplete "task" $priorDir)) {
            Write-Error "drive_review_round: round-$($Round - 1) output set is incomplete on disk; refusing to start round $Round"
            return $false
        }
        Add-Content -LiteralPath $tasks -Value "`n<!-- loop-driver round $Round edit -->`n"
    }

    & $scriptPath $feature $Attempt $Round | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }

    $roundDir = Join-Path $script:LoopFixtureRoot "reports/task-review/$feature/attempt-$Attempt/round-$Round"
    if (-not (Test-Path -LiteralPath (Join-Path $roundDir "precheck-result.json") -PathType Leaf)) {
        Write-Error "drive_review_round: precheck-result.json missing after a successful precheck run"
        return $false
    }

    $manifestA = Get-LoopTaskManifestA $roundDir $feature
    if ($null -eq $manifestA) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "task" "task-reviewer-a" $feature $manifestA)) { return $false }
    if (-not (Publish-LoopTaskRoundA $roundDir $Severity)) { return $false }

    $manifestB = Get-LoopTaskManifestB $roundDir $feature
    if ($null -eq $manifestB) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "task" "task-reviewer-b" $feature $manifestB)) { return $false }
    if (-not (Publish-LoopTaskRoundBContract $roundDir $Verdict $Severity)) { return $false }

    return $true
}

# ---------------------------------------------------------------------------
# domain-review round emission (not feature-scoped)
# ---------------------------------------------------------------------------
function Publish-LoopDomainRoundA {
    param([string]$RoundDir, [string]$Severity)
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    switch ($Severity) {
        "none"     { $aVerdict = "PASS";       $aResult = "PASS"; $aFails = 0; $aPasses = 6 }
        "Critical" { $aVerdict = "BLOCKED";    $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        "Major"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        "Minor"    { $aVerdict = "NEEDS_WORK"; $aResult = "FAIL"; $aFails = 1; $aPasses = 5 }
        default { Write-Error "Publish-LoopDomainRoundA: unknown severity: $Severity"; return $false }
    }
    $checkSeverity = if ($Severity -eq "none") { "Minor" } else { $Severity }

    $summaryJq = '["MODEL-CONSISTENCY","UBIQUITOUS-LANGUAGE","CONTEXT-BOUNDARY","AGGREGATE-INTEGRITY","EVENT-COVERAGE","C4-ALIGNMENT"] as $ids | {schema:"integrated-summary/v1",attempt:$attempt,round:$round,reviewer_a_check_ids:$ids,reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}'
    & jq -n --argjson attempt 1 --argjson round $round --argjson fail_count $aFails --argjson pass_count $aPasses $summaryJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-summary.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $contextPath = Join-Path $script:LoopFixtureRoot "domain/context-map.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-domain/references/domain-review-calibration.md"
    $contextSha = Get-LoopSha256 $contextPath
    $precheckSha = Get-LoopSha256 $precheckPath
    $calibrationSha = Get-LoopSha256 $calibrationPath

    $reviewerAJq = '["MODEL-CONSISTENCY","UBIQUITOUS-LANGUAGE","CONTEXT-BOUNDARY","AGGREGATE-INTEGRITY","EVENT-COVERAGE","C4-ALIGNMENT"] as $ids | {schema:"domain-reviewer-a/v1",stage:"domain",role:"domain-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:[{path:$context,sha256:$context_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha}],verdict:$verdict,checks: ($ids | to_entries | map({id:.value,result:(if .key == 0 then $result else "PASS" end),severity:(if .key == 0 then $severity else "Minor" end),finding:(if .key == 0 and $result == "FAIL" then "fixture finding" else "No issues found." end)}))}'
    & jq -n --arg verdict $aVerdict --arg result $aResult --arg severity $checkSeverity `
        --arg context $contextPath --arg context_sha $contextSha `
        --arg precheck $precheckPath --arg precheck_sha $precheckSha `
        --arg calibration $calibrationPath --arg calibration_sha $calibrationSha $reviewerAJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-a.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Publish-LoopDomainRoundBContract {
    param([string]$RoundDir, [string]$Verdict, [string]$Severity)
    $round = [int](Invoke-LoopJq @("-r", ".round") (Join-Path $RoundDir "precheck-result.json"))
    switch ($Severity) {
        "none"     { $critical = 0; $major = 0; $minor = 0 }
        "Critical" { $critical = 1; $major = 0; $minor = 0 }
        "Major"    { $critical = 0; $major = 1; $minor = 0 }
        "Minor"    { $critical = 0; $major = 0; $minor = 1 }
        default { Write-Error "Publish-LoopDomainRoundBContract: unknown severity: $Severity"; return $false }
    }
    $aVerdict = if ($critical -gt 0) { "BLOCKED" } elseif (($major + $minor) -gt 0) { "NEEDS_WORK" } else { "PASS" }

    $contextPath = Join-Path $script:LoopFixtureRoot "domain/context-map.md"
    $precheckPath = Join-Path $RoundDir "precheck-result.json"
    $calibrationPath = Join-Path $script:LoopFixtureRoot "plugins/sdd-domain/references/domain-review-calibration.md"
    $summaryPath = Join-Path $RoundDir "integrated-summary.json"
    $contextSha = Get-LoopSha256 $contextPath
    $precheckSha = Get-LoopSha256 $precheckPath
    $calibrationSha = Get-LoopSha256 $calibrationPath
    $summarySha = Get-LoopSha256 $summaryPath

    $verdictJq = '{schema:"integrated-verdict/v1",stage:"domain",attempt:1,round:$round,run_id:"fixture-orchestrator",verdict:$verdict,reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",findings_critical:$critical,findings_major:$major,findings_minor:$minor}'
    & jq -n --arg verdict $Verdict --argjson round $round `
        --argjson critical $critical --argjson major $major --argjson minor $minor --arg a_verdict $aVerdict $verdictJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "integrated-verdict.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $reviewerBJq = '["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids | {schema:"domain-reviewer-b/v1",stage:"domain",role:"domain-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:[{path:$context,sha256:$context_sha},{path:$precheck,sha256:$precheck_sha},{path:$calibration,sha256:$calibration_sha},{path:$summary,sha256:$summary_sha}],verdict:"PASS",checks: ($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}'
    & jq -n --arg context $contextPath --arg context_sha $contextSha `
        --arg precheck $precheckPath --arg precheck_sha $precheckSha `
        --arg calibration $calibrationPath --arg calibration_sha $calibrationSha `
        --arg summary $summaryPath --arg summary_sha $summarySha $reviewerBJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "reviewer-b.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }

    $manifestAJson = @(Invoke-LoopJq @("-c", ".allowed_input_manifest") (Join-Path $RoundDir "reviewer-a.json")) -join "`n"
    $manifestBJson = @(Invoke-LoopJq @("-c", ".allowed_input_manifest") (Join-Path $RoundDir "reviewer-b.json")) -join "`n"
    $contractJq = '{schema:"domain-review-contract/v1",stage:"domain",attempt:1,round:$round,run_id:"fixture-orchestrator",verdict:$verdict,reviewer_a_verdict:$a_verdict,reviewer_b_verdict:"PASS",findings_critical:$critical,findings_major:$major,findings_minor:$minor,reviewers:[{role:"domain-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:$manifest_a},{role:"domain-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:$manifest_b}]}'
    & jq -n --arg verdict $Verdict --argjson round $round `
        --argjson critical $critical --argjson major $major --argjson minor $minor --arg a_verdict $aVerdict `
        --argjson manifest_a $manifestAJson --argjson manifest_b $manifestBJson $contractJq |
        Set-Content -LiteralPath (Join-Path $RoundDir "domain-review-contract.json") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

function Get-LoopDomainManifestA([string]$RoundDir) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    return (Get-LoopManifestArray @(
        "domain/context-map.md", "plugins/sdd-domain/references/domain-review-calibration.md",
        "$roundRel/precheck-result.json"
    ))
}
function Get-LoopDomainManifestB([string]$RoundDir) {
    $roundRel = $RoundDir.Substring($script:LoopFixtureRoot.Length + 1) -replace '\\', '/'
    return (Get-LoopManifestArray @(
        "domain/context-map.md", "plugins/sdd-domain/references/domain-review-calibration.md",
        "$roundRel/precheck-result.json", "$roundRel/integrated-summary.json"
    ))
}

function Invoke-LoopDriveDomainRound {
    param([int]$Attempt, [int]$Round, [string]$Verdict, [string]$Severity)
    $scriptRel = Get-LoopDriverScript "domain"
    if ([string]::IsNullOrEmpty($scriptRel)) { Write-Error "drive_review_round: domain-review driver script not registered in the inventory"; return $false }
    $scriptRelPs1 = $scriptRel -replace '\.sh$', '.ps1'
    $scriptPath = Join-Path $script:LoopFixtureRoot $scriptRelPs1
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Error "drive_review_round: precheck script missing at $scriptPath (domain-review-precheck.ps1 does not exist upstream; see #147 and this task's implementation report)"
        return $false
    }

    $storyMd = Join-Path $script:LoopFixtureRoot "domain/domain-story.md"
    $precheckArgs = @([string]$Attempt, [string]$Round)
    if ($Round -gt 1) {
        $priorDir = Join-Path $script:LoopFixtureRoot "reports/domain-review/attempt-$Attempt/round-$($Round - 1)"
        if (-not (Test-PriorRoundComplete "domain" $priorDir)) {
            Write-Error "drive_review_round: round-$($Round - 1) output set is incomplete on disk; refusing to start round $Round"
            return $false
        }
        Add-Content -LiteralPath $storyMd -Value "`n<!-- loop-driver round $Round edit -->`n"
        $precheckArgs += "--edit-summary=round-$Round-edit"
    }

    & $scriptPath @precheckArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }

    $roundDir = Join-Path $script:LoopFixtureRoot "reports/domain-review/attempt-$Attempt/round-$Round"
    if (-not (Test-Path -LiteralPath (Join-Path $roundDir "precheck-result.json") -PathType Leaf)) {
        Write-Error "drive_review_round: precheck-result.json missing after a successful precheck run"
        return $false
    }

    $manifestA = Get-LoopDomainManifestA $roundDir
    if ($null -eq $manifestA) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "domain" "domain-reviewer-a" "loop-driver-domain" $manifestA)) { return $false }
    if (-not (Publish-LoopDomainRoundA $roundDir $Severity)) { return $false }

    $manifestB = Get-LoopDomainManifestB $roundDir
    if ($null -eq $manifestB) { return $false }
    if (-not (Invoke-LoopReserveReviewContext "domain" "domain-reviewer-b" "loop-driver-domain" $manifestB)) { return $false }
    if (-not (Publish-LoopDomainRoundBContract $roundDir $Verdict $Severity)) { return $false }

    return $true
}

# ---------------------------------------------------------------------------
# Invoke-DriveReviewRound -Stage <s> -Attempt <n> -Round <n> -Verdict <v> [-Severity <s>]
# ---------------------------------------------------------------------------
function Invoke-DriveReviewRound {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][int]$Attempt,
        [Parameter(Mandatory = $true)][int]$Round,
        [Parameter(Mandatory = $true)][string]$Verdict,
        [string]$Severity
    )
    if ([string]::IsNullOrEmpty($Severity)) {
        switch ($Verdict) {
            "PASS" { $Severity = "none" }
            "NEEDS_WORK" { $Severity = "Major" }
            "BLOCKED" { $Severity = "Critical" }
            default { Write-Error "Invoke-DriveReviewRound: cannot default severity for verdict '$Verdict'; pass it explicitly"; return $false }
        }
    }
    switch ($Stage) {
        "spec" { return (Invoke-LoopDriveSpecRound -Attempt $Attempt -Round $Round -Verdict $Verdict -Severity $Severity) }
        "impl" { return (Invoke-LoopDriveImplRound -Attempt $Attempt -Round $Round -Verdict $Verdict -Severity $Severity) }
        "task" { return (Invoke-LoopDriveTaskRound -Attempt $Attempt -Round $Round -Verdict $Verdict -Severity $Severity) }
        "domain" { return (Invoke-LoopDriveDomainRound -Attempt $Attempt -Round $Round -Verdict $Verdict -Severity $Severity) }
        default {
            Write-Error "Invoke-DriveReviewRound: unknown stage: $Stage"
            return $false
        }
    }
}

# ---------------------------------------------------------------------------
# Test-ArtifactsSchema -Dir <path>
# ---------------------------------------------------------------------------
function Test-ArtifactsSchema {
    param([Parameter(Mandatory = $true)][string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
    $knownJson = Invoke-LoopJq @("-c", '[.loops[].artifact_schemas[]] | unique') $script:LoopInventoryPath
    if ($null -eq $knownJson) { return $false }
    $files = Get-ChildItem -LiteralPath $Dir -Filter "*.json" -File -ErrorAction SilentlyContinue
    if (-not $files -or $files.Count -eq 0) { return $false }
    foreach ($f in $files) {
        $schema = Invoke-LoopJq @("-r", '.schema? // empty') $f.FullName
        if ([string]::IsNullOrEmpty($schema)) { return $false }
        $found = ($knownJson | & jq -r --arg s $schema 'index($s) != null')
        if ($found -ne "true") { return $false }
    }
    return $true
}

# ---------------------------------------------------------------------------
# Test-LoopTerminal -LoopId <id> -Observed <state> [-ExitCode <n>]
# ---------------------------------------------------------------------------
function Test-LoopTerminal {
    param(
        [Parameter(Mandatory = $true)][string]$LoopId,
        [Parameter(Mandatory = $true)][string]$Observed,
        [int]$ExitCode = 0
    )
    if ($ExitCode -ne 0) { return $false }
    $expected = Invoke-LoopJq @("-r", "--arg", "id", $LoopId, '.loops[] | select(.id == $id) | .terminal.state // empty') $script:LoopInventoryPath
    if ([string]::IsNullOrEmpty($expected)) { return $false }
    return ($expected -eq $Observed)
}

# ---------------------------------------------------------------------------
# Test-RuntimeBudget -Start <epoch> [-Budget <seconds>]
# ---------------------------------------------------------------------------
function Test-RuntimeBudget {
    param([Parameter(Mandatory = $true)][long]$Start, [int]$Budget = -1)
    if ($Budget -eq -1) { $Budget = $script:LoopSuiteBudgetSeconds }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $elapsed = $now - $Start
    return ($elapsed -le $Budget)
}
