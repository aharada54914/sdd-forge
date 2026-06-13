# Deterministic gate: validate a Done evidence bundle.
# Usage: check-evidence-bundle.ps1 <path-to-evidence-bundle.json> [-RepoRoot <path>]
# The bundle must name a quality report, verification contract, and include
# all passing evidence artifacts from the contract with matching SHA256.
param(
    [Parameter(Mandatory)][string]$BundlePath,
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BundlePath)) {
    Write-Error "Evidence bundle file not found: $BundlePath"
    exit 1
}

$failures = @()

function Add-Failure {
    param([Parameter(Mandatory)][string]$Message)
    $script:failures += $Message
}

function Resolve-RepoRelativePath {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Label
    )

    $path = ([string]$Value).Trim().Replace("\", "/")
    if ([string]::IsNullOrWhiteSpace($path)) {
        Add-Failure "$Label is empty"
        return $null
    }
    if ($path.StartsWith("/") -or $path.StartsWith("//") -or $path -match '^[A-Za-z]:') {
        Add-Failure "$Label is an absolute path: $Value"
        return $null
    }
    if ($path -match '(^|/)\.\.(/|$)') {
        Add-Failure "$Label escapes repo root: $Value"
        return $null
    }
    while ($path.StartsWith("./")) {
        $path = $path.Substring(2)
    }
    if ([string]::IsNullOrWhiteSpace($path)) {
        Add-Failure "$Label is empty after normalization"
        return $null
    }
    return $path
}

function Resolve-RepositoryPath {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Label
    )

    $rootPath = (Resolve-Path $RepoRoot).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')
    $normalized = Resolve-RepoRelativePath -Value $RelativePath -Label $Label
    if (-not $normalized) {
        return $null
    }

    try {
        $resolved = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($rootPath, $normalized))
    } catch {
        Add-Failure "$Label could not be resolved: $RelativePath"
        return $null
    }

    $sep = [System.IO.Path]::DirectorySeparatorChar
    if (-not ($resolved.StartsWith($rootPath + $sep) -or $resolved -eq $rootPath)) {
        Add-Failure "$Label escapes repo root: $RelativePath"
        return $null
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        Add-Failure "$Label missing: $RelativePath"
        return $null
    }
    if ((Get-Item -LiteralPath $resolved).PSIsContainer) {
        Add-Failure "$Label is not a regular file: $RelativePath"
        return $null
    }
    return [pscustomobject]@{
        Normalized = $normalized
        Resolved = $resolved
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

$bundle = Get-Content -Raw -Encoding Utf8 $BundlePath | ConvertFrom-Json
$taskId = ([string]$bundle.task_id).Trim()
$qualityReport = $bundle.quality_report
$verificationContract = $bundle.verification_contract
$artifacts = @()

if ($taskId -notmatch '^T-\d+$') {
    Add-Failure "task_id is invalid: $taskId"
}
if ((Split-Path -Leaf $BundlePath) -ne "$taskId.evidence.json") {
    Add-Failure "bundle filename does not match task_id: $(Split-Path -Leaf $BundlePath) vs $taskId"
}
if ($null -eq $bundle.artifacts) {
    Add-Failure "artifacts must be an array"
} elseif ($bundle.artifacts -isnot [System.Array]) {
    Add-Failure "artifacts must be an array"
} else {
    $artifacts = @($bundle.artifacts)
    if ($artifacts.Count -eq 0) {
        Add-Failure "artifacts must not be empty"
    }
}

$qualityInfo = Resolve-RepositoryPath -RelativePath ([string]$qualityReport) -Label "quality_report"
$contractInfo = Resolve-RepositoryPath -RelativePath ([string]$verificationContract) -Label "verification_contract"

if ($qualityInfo) {
    $qualityText = Get-Content -Raw -Encoding Utf8 $qualityInfo.Resolved
    if ($qualityText -notmatch "(?m)^Task ID:\s*$([regex]::Escape($taskId))\s*$") {
        Add-Failure "quality_report missing Task ID: $taskId"
    }
    if ($qualityText -notmatch "(?m)^VERDICT:\s*PASS\s*$") {
        Add-Failure "quality_report missing VERDICT: PASS"
    }
    if ((Split-Path -Leaf $qualityInfo.Resolved) -notmatch '\.md$') {
        Add-Failure "quality_report must point to a markdown report: $qualityReport"
    }
}

$contract = $null
if ($contractInfo) {
    if ((Split-Path -Leaf $contractInfo.Resolved) -notmatch '\.contract\.json$') {
        Add-Failure "verification_contract must point to a contract JSON file: $verificationContract"
    }
    try {
        $contract = Get-Content -Raw -Encoding Utf8 $contractInfo.Resolved | ConvertFrom-Json
    } catch {
        Add-Failure "verification_contract could not be parsed as JSON: $verificationContract"
    }
    if ($contract -and ([string]$contract.task_id).Trim() -ne $taskId) {
        Add-Failure "verification_contract task_id mismatch: $($contract.task_id) != $taskId"
    }
}

$scriptRoot = Split-Path -Parent $PSScriptRoot
$checkContractScript = Join-Path $scriptRoot "scripts/check-contract.ps1"
if ($contractInfo) {
    $powerShellExe = (Get-Process -Id $PID).Path
    & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $checkContractScript -ContractPath $contractInfo.Normalized -RepoRoot $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "verification_contract failed check-contract validation: $verificationContract"
    }
}

$requiredArtifacts = @{}
if ($qualityInfo) { $requiredArtifacts[$qualityInfo.Normalized] = "quality_report" }
if ($contractInfo) { $requiredArtifacts[$contractInfo.Normalized] = "verification_contract" }

if ($contract) {
    foreach ($check in @($contract.checks)) {
        if ([bool]$check.passes) {
            $evidenceInfo = Resolve-RepositoryPath -RelativePath ([string]$check.evidence) -Label "passing evidence for check '$($check.id)'"
            if ($evidenceInfo) {
                $requiredArtifacts[$evidenceInfo.Normalized] = "passing evidence for check '$($check.id)'"
            }
        }
    }
}

$artifactIndex = @{}
foreach ($artifact in @($artifacts)) {
    $artifactPath = [string]$artifact.path
    $artifactSha = ([string]$artifact.sha256).Trim().ToLowerInvariant()
    $artifactInfo = Resolve-RepositoryPath -RelativePath $artifactPath -Label "artifact path"
    if (-not $artifactInfo) {
        continue
    }
    if ($artifactSha -notmatch '^[a-f0-9]{64}$') {
        Add-Failure "artifact sha256 is invalid for ${artifactPath}: $($artifact.sha256)"
        continue
    }
    if ($artifactIndex.ContainsKey($artifactInfo.Normalized)) {
        Add-Failure "duplicate artifact path in manifest: $($artifactInfo.Normalized)"
        continue
    }
    $artifactIndex[$artifactInfo.Normalized] = $artifactSha
    $actual = Get-Sha256 -Path $artifactInfo.Resolved
    if ($actual -ne $artifactSha) {
        Add-Failure "artifact sha256 mismatch for $($artifactInfo.Normalized)"
    }
}

foreach ($requiredPath in $requiredArtifacts.Keys) {
    if (-not $artifactIndex.ContainsKey($requiredPath)) {
        Add-Failure "manifest is missing $($requiredArtifacts[$requiredPath]): $requiredPath"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Evidence bundle FAILED for task ${taskId}:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "Evidence bundle passed for task $taskId."
exit 0
