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

# --- Signing verification helpers (T-007a) ---

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
    # NB: do not name this $home — $HOME is a read-only automatic variable in
    # PowerShell (case-insensitive), and assigning to it throws under -ErrorAction Stop.
    $userHome = $env:HOME
    if ([string]::IsNullOrWhiteSpace($userHome)) { $userHome = $env:USERPROFILE }
    if (-not [string]::IsNullOrWhiteSpace($userHome)) {
        $keyPath = Join-Path $userHome ".sdd" "evidence-key"
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

$bundle = Get-Content -Raw -Encoding Utf8 $BundlePath | ConvertFrom-Json
$taskId = ([string]$bundle.task_id).Trim()
$qualityReport = $bundle.quality_report
$verificationContract = $bundle.verification_contract
$gitCommit = $bundle.git_commit
$gitGeneratedDirty = $bundle.git_generated_dirty
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
    & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $checkContractScript -ContractPath $contractInfo.Resolved -RepoRoot $RepoRoot
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

# --- git_commit binding ---
if ($null -eq $gitCommit -or ($gitCommit -is [string] -and [string]::IsNullOrWhiteSpace($gitCommit))) {
    Add-Failure "git_commit is required but missing"
} elseif (([string]$gitCommit) -notmatch '^[0-9a-f]{40}$') {
    Add-Failure "git_commit is invalid (must be 40 lowercase hex): $gitCommit"
} else {
    $gitCommitStr = ([string]$gitCommit).Trim()
    $gitExe = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitExe) {
        Add-Failure "git is not available; cannot verify git_commit binding"
    } else {
        $absRoot = (Resolve-Path $RepoRoot).Path
        try {
            # Verify commit exists
            $r1 = Start-Process -FilePath "git" -ArgumentList @("-C", $absRoot, "cat-file", "-e", "${gitCommitStr}^{commit}") -NoNewWindow -Wait -PassThru
            if ($r1.ExitCode -ne 0) {
                Add-Failure "git_commit does not exist in repository: $gitCommitStr"
            } else {
                # Verify commit is HEAD or an ancestor of HEAD
                $r2 = Start-Process -FilePath "git" -ArgumentList @("-C", $absRoot, "merge-base", "--is-ancestor", $gitCommitStr, "HEAD") -NoNewWindow -Wait -PassThru
                if ($r2.ExitCode -ne 0) {
                    # Commit exists but is not an ancestor — may have been rewritten after
                    # amend/rebase. Tolerate if all artifact hashes still match (35.1).
                    $hashesOk = ($artifactIndex.Count -gt 0)
                    foreach ($norm in $artifactIndex.Keys) {
                        $artPath = [System.IO.Path]::Combine($absRoot, $norm)
                        if (-not (Test-Path -LiteralPath $artPath) -or (Get-Sha256 -Path $artPath) -ne $artifactIndex[$norm]) {
                            $hashesOk = $false
                            break
                        }
                    }
                    if ($hashesOk) {
                        Write-Host ("WARNING: git_commit $gitCommitStr is not an ancestor of HEAD " +
                            "(history may have been rewritten after amend/rebase), " +
                            "but all artifact hashes still match")
                    } else {
                        Add-Failure "git_commit is not an ancestor of HEAD (foreign or future commit): $gitCommitStr"
                    }
                }
            }
        } catch {
            Add-Failure "git verification failed unexpectedly: $_"
        }
    }
}

# --- provenance validation (gated on risk) ---
$bundleRisk = ([string]$bundle.risk).Trim()

# The contract is hash-validated and re-checked, so it is the trusted source of
# the risk tier. The bundle's own risk must agree; a stripped or forged bundle
# risk must NOT be able to dodge the provenance requirements.
$contractRisk = ""
if ($contract) { $contractRisk = ([string]$contract.risk).Trim() }
if ($contractRisk -and $contractRisk -ne $bundleRisk) {
    $shownRisk = if ($bundleRisk) { $bundleRisk } else { "(empty)" }
    Add-Failure "bundle risk '$shownRisk' != contract risk '$contractRisk'"
}
# Gate provenance on the trusted contract risk; fall back to bundle risk (legacy).
$effectiveRisk = if ($contractRisk) { $contractRisk } else { $bundleRisk }

# High/critical tier provenance requirements
if (@("high", "critical") -contains $effectiveRisk) {
    $specRevision = ([string]$bundle.spec_revision).Trim()
    if ($specRevision -notmatch '^[a-f0-9]{64}$') {
        Add-Failure "high/critical bundle requires spec_revision (64-hex), got: $(if ($specRevision) { $specRevision } else { '(empty)' })"
    }

    $buildEnv = $bundle.build_env
    if (-not $buildEnv -or -not (([string]$buildEnv.os).Trim())) {
        Add-Failure "high/critical bundle requires build_env.os"
    }

    $reviewVerdict = $bundle.review_verdict
    if (-not $reviewVerdict) {
        Add-Failure "high/critical bundle requires review_verdict object"
    } elseif (([string]$reviewVerdict.verdict).Trim() -ne "PASS") {
        Add-Failure "high/critical bundle requires review_verdict.verdict == PASS, got: $(if ($reviewVerdict.verdict) { $reviewVerdict.verdict } else { '(empty)' })"
    }
}

# Critical-only signature verification (T-007a)
if ($effectiveRisk -eq "critical") {
    if ($gitGeneratedDirty -eq $true) {
        Add-Failure "critical bundle must not be generated with a dirty working tree (git_generated_dirty=true)"
    }
    $signature = $bundle.signature
    if ($null -eq $signature -or -not ($signature -is [PSCustomObject] -or $signature -is [Hashtable])) {
        Add-Failure "critical bundle requires a signature object"
    } else {
        $alg = ([string]$signature.alg).Trim()
        $value = ([string]$signature.value).Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($alg) -or [string]::IsNullOrWhiteSpace($value)) {
            Add-Failure "critical bundle signature requires non-empty alg and value"
        } elseif ($alg -eq "hmac-sha256") {
            $keyInfo = Resolve-EvidenceKey
            if ($null -eq $keyInfo) {
                Add-Failure "critical bundle signature cannot be verified: no evidence key available"
            } else {
                $canonical = Get-EvidenceCanonical -Bundle $bundle
                $canonicalBytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
                # ::new() so the byte[] key is one ctor arg (New-Object -ArgumentList splats arrays).
                $hmac = [System.Security.Cryptography.HMACSHA256]::new([byte[]]$keyInfo.key)
                $expectedBytes = $hmac.ComputeHash($canonicalBytes)
                $expected = ($expectedBytes | ForEach-Object { "{0:x2}" -f $_ }) -join ""
                if ([string]::Compare($expected, $value, [System.StringComparison]::OrdinalIgnoreCase) -ne 0) {
                    Add-Failure "critical bundle signature is invalid (HMAC mismatch)"
                }
            }
        } elseif ($alg -eq "sigstore") {
            $verified = [System.Environment]::GetEnvironmentVariable("SDD_EVIDENCE_SIGSTORE_VERIFIED")
            if ([string]::IsNullOrWhiteSpace($verified)) {
                Add-Failure "critical bundle uses sigstore signature but SDD_EVIDENCE_SIGSTORE_VERIFIED is not set"
            }
        } else {
            Add-Failure "critical bundle has unsupported signature alg: $alg"
        }
    }
}

if ($gitGeneratedDirty -eq $true) {
    Write-Host "WARNING: evidence bundle for task ${taskId} was generated with a dirty working tree"
}

if ($failures.Count -gt 0) {
    Write-Host "Evidence bundle FAILED for task ${taskId}:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "Evidence bundle passed for task $taskId."
exit 0
