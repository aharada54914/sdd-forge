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

# Extract risk and required_workflow from contract (may be absent for legacy bundles)
$contractRisk = ([string]$contract.risk).Trim()
$contractRequiredWorkflow = ([string]$contract.required_workflow).Trim()

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
# Compute spec_revision (sha256 over spec files)
# ------------------------------------------------------------------

function Get-SpecRevision {
    param([Parameter(Mandatory)][string]$FeatureSlug, [Parameter(Mandatory)][string]$AbsRoot)
    $specFiles = @(
        (Join-Path $AbsRoot "specs" $FeatureSlug "requirements.md"),
        (Join-Path $AbsRoot "specs" $FeatureSlug "design.md"),
        (Join-Path $AbsRoot "specs" $FeatureSlug "acceptance-tests.md")
    )
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $foundAny = $false
    foreach ($specFile in $specFiles) {
        if (Test-Path -LiteralPath $specFile) {
            $bytes = [System.IO.File]::ReadAllBytes($specFile)
            $hasher.TransformBlock($bytes, 0, $bytes.Length, $null, 0) | Out-Null
            $foundAny = $true
        }
    }
    $hasher.TransformFinalBlock([byte[]]@(), 0, 0) | Out-Null
    if ($foundAny) {
        return ($hasher.Hash | ForEach-Object { "{0:x2}" -f $_ }) -join ""
    }
    return ""
}

$specRevision = Get-SpecRevision -FeatureSlug $feature -AbsRoot $absRoot

# ------------------------------------------------------------------
# Parse review_verdict from quality report
# ------------------------------------------------------------------

function Get-ReviewVerdict {
    param([Parameter(Mandatory)][string]$ReportPath)
    $verdict = ""
    $critical = 0
    $major = 0
    $minor = 0
    try {
        $content = Get-Content -Raw -LiteralPath $ReportPath -Encoding Utf8
        if ($content -match "(?m)^VERDICT:\s*(\S+)") {
            $verdict = $matches[1]
        }
        if ($content -match "(?m)^Critical:\s*(\d+)") { $critical = [int]$matches[1] }
        if ($content -match "(?m)^Major:\s*(\d+)") { $major = [int]$matches[1] }
        if ($content -match "(?m)^Minor:\s*(\d+)") { $minor = [int]$matches[1] }
    } catch {
        # If parsing fails, return defaults
    }
    return [ordered]@{
        verdict  = $verdict
        critical = $critical
        major    = $major
        minor    = $minor
        reviewer = "sdd-evaluator"
    }
}

$reviewVerdict = Get-ReviewVerdict -ReportPath (Resolve-Path $QualityReport).Path

# ------------------------------------------------------------------
# Build build_env
# ------------------------------------------------------------------

$osName = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
if ($osName -match "Windows") { $osName = "windows" }
elseif ($osName -match "Linux") { $osName = "linux" }
elseif ($osName -match "Darwin") { $osName = "darwin" }
else { $osName = $osName.ToLower() }

$pythonVersion = python --version 2>&1 | Out-String
$pythonVersion = [regex]::Match($pythonVersion, '\d+\.\d+').Value

$gitVersion = ""
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitVersion = (& git --version) -join " "
}

$buildEnv = [ordered]@{
    os              = $osName
    python          = $pythonVersion
    git             = $gitVersion
    lockfile_sha256 = $null
}

# ------------------------------------------------------------------
# Build builder
# ------------------------------------------------------------------

$builderKind = if ($env:CI -or $env:GITHUB_ACTIONS) { "ci" } else { "local" }
$builderId = $env:GITHUB_RUN_ID
if ([string]::IsNullOrWhiteSpace($builderId)) {
    $builderId = $env:USERNAME
    if ([string]::IsNullOrWhiteSpace($builderId)) { $builderId = "unknown" }
}
$builderRuntime = if ($env:SDD_RUNTIME) { $env:SDD_RUNTIME } else { "unknown" }

$builder = [ordered]@{
    kind    = $builderKind
    id      = $builderId
    runtime = $builderRuntime
}

# ------------------------------------------------------------------
# Signing helpers (T-007a)
# ------------------------------------------------------------------

function Resolve-EvidenceKey {
    $envKey = [System.Environment]::GetEnvironmentVariable("SDD_EVIDENCE_KEY")
    if (-not [string]::IsNullOrWhiteSpace($envKey)) {
        return @{ key = [System.Text.Encoding]::UTF8.GetBytes($envKey); ref = "env:SDD_EVIDENCE_KEY" }
    }
    $envKeyFile = [System.Environment]::GetEnvironmentVariable("SDD_EVIDENCE_KEY_FILE")
    if (-not [string]::IsNullOrWhiteSpace($envKeyFile)) {
        try {
            $raw = [System.IO.File]::ReadAllBytes($envKeyFile)
            # Strip BOM (0xEF 0xBB 0xBF)
            if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) {
                $raw = $raw[3..($raw.Length-1)]
            }
            # Strip trailing whitespace
            $raw = [System.Linq.Enumerable]::Reverse(
                [System.Linq.Enumerable]::SkipWhile(
                    [System.Linq.Enumerable]::Reverse($raw),
                    { param($b) $b -in @(0x20, 0x09, 0x0D, 0x0A) }
                )
            ).ToArray()
            if ($raw.Length -gt 0) {
                return @{ key = $raw; ref = "file:$envKeyFile" }
            }
        } catch {
            return $null
        }
    }
    $home = $env:HOME
    if ([string]::IsNullOrWhiteSpace($home)) { $home = $env:USERPROFILE }
    if (-not [string]::IsNullOrWhiteSpace($home)) {
        $keyPath = Join-Path $home ".sdd" "evidence-key"
        if (Test-Path -LiteralPath $keyPath) {
            try {
                $raw = [System.IO.File]::ReadAllBytes($keyPath)
                # Strip BOM
                if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) {
                    $raw = $raw[3..($raw.Length-1)]
                }
                # Strip trailing whitespace
                $raw = [System.Linq.Enumerable]::Reverse(
                    [System.Linq.Enumerable]::SkipWhile(
                        [System.Linq.Enumerable]::Reverse($raw),
                        { param($b) $b -in @(0x20, 0x09, 0x0D, 0x0A) }
                    )
                ).ToArray()
                if ($raw.Length -gt 0) {
                    return @{ key = $raw; ref = "file:~/.sdd/evidence-key" }
                }
            } catch {
                return $null
            }
        }
    }
    return $null
}

function Get-EvidenceCanonical {
    param([Parameter(Mandatory)]$Bundle)
    $artifacts = @($Bundle.artifacts)
    $pairs = @()
    foreach ($artifact in $artifacts) {
        $path = [string]($artifact.path).Trim()
        $sha = ([string]($artifact.sha256).Trim()).ToLowerInvariant()
        $pairs += $path + [char]0 + $sha
    }
    # Ordinal sort to match Python's code-point sort (Sort-Object is culture-aware
    # and would diverge across runtimes, breaking signature parity).
    $pairsArr = [string[]]$pairs
    [System.Array]::Sort($pairsArr, [System.StringComparer]::Ordinal)
    $pairsStr = $pairsArr -join "`n"
    $pairsBytes = [System.Text.Encoding]::UTF8.GetBytes($pairsStr)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $artifactsDigest = ($hasher.ComputeHash($pairsBytes) | ForEach-Object { "{0:x2}" -f $_ }) -join ""

    $dirty = if ($Bundle.git_generated_dirty) { "true" } else { "false" }
    $verdict = [string]($Bundle.review_verdict.verdict).Trim()

    $lines = @(
        "sdd-evidence-v1",
        [string]($Bundle.task_id).Trim(),
        [string]($Bundle.feature).Trim(),
        [string]($Bundle.risk).Trim(),
        [string]($Bundle.required_workflow).Trim(),
        [string]($Bundle.spec_revision).Trim(),
        [string]($Bundle.git_commit).Trim(),
        $dirty,
        $verdict,
        $artifactsDigest
    )
    return $lines -join "`n"
}

# ------------------------------------------------------------------
# Write bundle
# ------------------------------------------------------------------

$bundle = [ordered]@{
    task_id               = $taskId
    feature               = $feature
    risk                  = $contractRisk
    required_workflow     = $contractRequiredWorkflow
    spec_revision         = $specRevision
    quality_report        = $reportRel
    verification_contract = $contractRel
    git_commit            = $gitCommit
    git_generated_dirty   = $gitGeneratedDirty
    build_env             = $buildEnv
    builder               = $builder
    review_verdict        = $reviewVerdict
    artifacts             = $artifacts
}

# Sign critical bundles (T-007a)
if ($contractRisk -eq "critical") {
    $keyInfo = Resolve-EvidenceKey
    if ($null -eq $keyInfo) {
        Write-Error "generate-evidence-bundle: risk=critical requires an evidence signing key (SDD_EVIDENCE_KEY / SDD_EVIDENCE_KEY_FILE / ~/.sdd/evidence-key); none found"
        exit 1
    }
    $canonical = Get-EvidenceCanonical -Bundle $bundle
    $canonicalBytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256 -ArgumentList $keyInfo.key
    $signatureBytes = $hmac.ComputeHash($canonicalBytes)
    $signatureValue = ($signatureBytes | ForEach-Object { "{0:x2}" -f $_ }) -join ""
    $bundle["signature"] = [ordered]@{
        alg     = "hmac-sha256"
        value   = $signatureValue
        key_ref = $keyInfo.ref
    }
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
