# Generate a hash-verified evidence bundle for a quality-gate task.
# Usage: generate-evidence-bundle.ps1 -ContractPath <path> -QualityReport <path> [-RepoRoot <path>] [-OutputPath <path>]
#
# Reads the contract JSON, computes SHA256 for all referenced artifacts, records
# the current git HEAD commit, and writes a bundle JSON that check-evidence-bundle
# can validate deterministically.
param(
    [Parameter(Mandatory)][string]$ContractPath,
    [Parameter(Mandatory)][string]$QualityReport,
    [string]$RepoRoot = ".",
    [string]$OutputPath = ""
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ContractPath)) {
    Write-Error "generate-evidence-bundle: contract file not found: $ContractPath"
    exit 1
}
if (-not (Test-Path -LiteralPath $QualityReport)) {
    Write-Error "generate-evidence-bundle: quality report not found: $QualityReport"
    exit 1
}

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

function Get-Sha256Hex {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-NormalizedRelPath {
    param(
        [Parameter(Mandatory)][string]$AbsPath,
        [Parameter(Mandatory)][string]$AbsRoot
    )
    $rootSep = $AbsRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')
    $resolved = [System.IO.Path]::GetFullPath($AbsPath)
    $sep = [System.IO.Path]::DirectorySeparatorChar
    if (-not ($resolved.StartsWith($rootSep + $sep) -or $resolved -eq $rootSep)) {
        throw "Path '$AbsPath' is outside repo root '$AbsRoot'"
    }
    $rel = $resolved.Substring($rootSep.Length).TrimStart($sep, '/')
    # Normalize to forward slashes
    $rel = $rel.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($rel) -or $rel -match '\.\.') {
        throw "Unsafe relative path: $rel"
    }
    return $rel
}

# ------------------------------------------------------------------
# Parse contract
# ------------------------------------------------------------------

try {
    $contract = Get-Content -Raw -Encoding Utf8 $ContractPath | ConvertFrom-Json
} catch {
    Write-Error "generate-evidence-bundle: cannot parse contract: $_"
    exit 1
}

$taskId = ([string]$contract.task_id).Trim()
if ($taskId -notmatch '^T-\d+$') {
    Write-Error "generate-evidence-bundle: invalid task_id in contract: $taskId"
    exit 1
}

$feature = ([string]$contract.feature).Trim()

$absRoot = (Resolve-Path $RepoRoot).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')

# ------------------------------------------------------------------
# Determine output path
# ------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $contractDir = Split-Path -Parent (Resolve-Path $ContractPath).Path
    $resolvedOutputPath = Join-Path $contractDir "$taskId.evidence.json"
} else {
    $resolvedOutputPath = $OutputPath
}

# ------------------------------------------------------------------
# Build artifact list (deduplicated, relative paths)
# ------------------------------------------------------------------

$seenPaths = [ordered]@{}  # normalized rel-path -> abs path

function Add-Artifact {
    param(
        [Parameter(Mandatory)][string]$AbsPath,
        [Parameter(Mandatory)][string]$Label
    )
    $p = [System.IO.Path]::GetFullPath($AbsPath)
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Error "generate-evidence-bundle: $Label not found: $AbsPath"
        exit 1
    }
    if ((Get-Item -LiteralPath $p).PSIsContainer) {
        Write-Error "generate-evidence-bundle: $Label is not a regular file: $AbsPath"
        exit 1
    }
    try {
        $rel = Get-NormalizedRelPath -AbsPath $p -AbsRoot $absRoot
    } catch {
        Write-Error "generate-evidence-bundle: $_"
        exit 1
    }
    if (-not $script:seenPaths.Contains($rel)) {
        $script:seenPaths[$rel] = $p
    }
}

Add-Artifact -AbsPath (Resolve-Path $ContractPath).Path -Label "verification_contract"
Add-Artifact -AbsPath (Resolve-Path $QualityReport).Path -Label "quality_report"

foreach ($check in @($contract.checks)) {
    if ([bool]$check.passes) {
        $evidence = ([string]$check.evidence).Trim()
        if (-not [string]::IsNullOrWhiteSpace($evidence)) {
            $absEv = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($absRoot, $evidence))
            Add-Artifact -AbsPath $absEv -Label "passing evidence for check '$($check.id)'"
        }
    }
}

# Build artifacts array: contract first, report second, rest sorted
$contractRel = Get-NormalizedRelPath -AbsPath (Resolve-Path $ContractPath).Path -AbsRoot $absRoot
$reportRel   = Get-NormalizedRelPath -AbsPath (Resolve-Path $QualityReport).Path -AbsRoot $absRoot

$orderedRels = [System.Collections.Generic.List[string]]::new()
if ($seenPaths.Contains($contractRel)) { $orderedRels.Add($contractRel) }
if ($seenPaths.Contains($reportRel) -and -not $orderedRels.Contains($reportRel)) { $orderedRels.Add($reportRel) }
foreach ($rel in ($seenPaths.Keys | Sort-Object)) {
    if (-not $orderedRels.Contains($rel)) { $orderedRels.Add($rel) }
}

$artifacts = @()
foreach ($rel in $orderedRels) {
    $absP = $seenPaths[$rel]
    $sha = Get-Sha256Hex -Path $absP
    $artifacts += [ordered]@{ path = $rel; sha256 = $sha }
}

# ------------------------------------------------------------------
# git binding
# ------------------------------------------------------------------

$gitExe = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExe) {
    Write-Error "generate-evidence-bundle: git is not available"
    exit 1
}

try {
    $revResult = & git -C $absRoot rev-parse HEAD 2>&1
    $revExit = $LASTEXITCODE
} catch {
    Write-Error "generate-evidence-bundle: git rev-parse failed: $_"
    exit 1
}

if ($revExit -ne 0) {
    Write-Error "generate-evidence-bundle: not a git repository or git error: $revResult"
    exit 1
}

$gitCommit = ($revResult | Out-String).Trim()
if ($gitCommit -notmatch '^[0-9a-f]{40}$') {
    Write-Error "generate-evidence-bundle: unexpected git HEAD format: $gitCommit"
    exit 1
}

try {
    $statusResult = & git -C $absRoot status --porcelain 2>&1
    $statusExit = $LASTEXITCODE
} catch {
    Write-Error "generate-evidence-bundle: git status failed: $_"
    exit 1
}

if ($statusExit -ne 0) {
    Write-Error "generate-evidence-bundle: git status failed"
    exit 1
}

$gitGeneratedDirty = (-not [string]::IsNullOrWhiteSpace(($statusResult | Out-String).Trim()))

# ------------------------------------------------------------------
# Write bundle
# ------------------------------------------------------------------

$bundle = [ordered]@{
    task_id               = $taskId
    feature               = $feature
    quality_report        = $reportRel
    verification_contract = $contractRel
    git_commit            = $gitCommit
    git_generated_dirty   = $gitGeneratedDirty
    artifacts             = $artifacts
}

$outputDir = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$bundle | ConvertTo-Json -Depth 6 | Set-Content -Encoding Utf8 $resolvedOutputPath
# Ensure trailing newline
Add-Content -Value "" -Encoding Utf8 $resolvedOutputPath

$artifactCount = $artifacts.Count
$shortCommit = $gitCommit.Substring(0, 12)
$dirtyNote = if ($gitGeneratedDirty) { "  [dirty]" } else { "" }
Write-Host $resolvedOutputPath
Write-Host "Generated evidence bundle for ${taskId}: ${artifactCount} artifact(s), commit ${shortCommit}${dirtyNote}"
exit 0
