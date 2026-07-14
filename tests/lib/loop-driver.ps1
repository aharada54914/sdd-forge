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

- loop-driver $Profile fixture for feature $Feature (A2 / Issue #142).
"@ | Set-Content -LiteralPath (Join-Path $root "specs/$Feature/requirements.md") -NoNewline -Encoding utf8
    @"
# Acceptance tests

| AC-ID | Requirement | Status |
|---|---|---|
| AC-001 | REQ-001 | Planned |
"@ | Set-Content -LiteralPath (Join-Path $root "specs/$Feature/acceptance-tests.md") -NoNewline -Encoding utf8

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
        "plugins/sdd-domain/scripts/domain-review-precheck.ps1"
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
        "plugins/sdd-domain/references/domain-review-calibration.md"
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

function Invoke-LoopReserveReviewContext {
    param([string]$Stage, [string]$Role, [string]$Feature, [string]$ManifestEntries)
    $validator = Join-Path $script:SddLoopRepoRoot "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        Write-Error "Invoke-LoopReserveReviewContext: validator missing: $validator"
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

    & $validator -Manifest $manifestPath -RepositoryRoot $script:LoopFixtureRoot -Reserve | Out-Null
    $rc = $LASTEXITCODE
    Remove-Item -LiteralPath $manifestPath -ErrorAction SilentlyContinue
    return ($rc -eq 0)
}

# ---------------------------------------------------------------------------
# Test-PriorRoundComplete -Stage <s> -RoundDir <path>
# ---------------------------------------------------------------------------
function Get-LoopRequiredRoundFiles([string]$Stage) {
    switch ($Stage) {
        "spec" { return @("precheck-result.json", "integrated-summary.json", "reviewer-a.json", "reviewer-b.json", "integrated-verdict.json", "spec-review-contract.json") }
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
        { $_ -in @("impl", "task", "domain") } {
            Write-Error "Invoke-DriveReviewRound: stage '$Stage' is not implemented by A2/#142 (spec-review only; driving impl/task/domain is A3/#143 scope)"
            return $false
        }
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
