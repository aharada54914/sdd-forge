# Deterministic gate: validate a Done evidence bundle.
# Usage: check-evidence-bundle.ps1 <path-to-evidence-bundle.json> [-RepoRoot <path>]
# The bundle must name a quality report, verification contract, and include
# all passing evidence artifacts from the contract with matching SHA256.
param(
    [Parameter(Mandatory)][string]$BundlePath,
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib/evidence-key.ps1')
. (Join-Path $PSScriptRoot 'lib/evidence-path.ps1')

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
    if ($path.StartsWith("/", [StringComparison]::Ordinal) -or $path -cmatch '^[A-Za-z]:') {
        Add-Failure "$Label is an absolute path: $Value"
        return $null
    }
    if ($path -match '(^|/)\.\.(/|$)') {
        Add-Failure "$Label escapes repo root: $Value"
        return $null
    }
    while ($path.StartsWith("./", [StringComparison]::Ordinal)) {
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

    $rootPath = (Resolve-SddEvidenceFilesystemPath (Resolve-Path -LiteralPath $RepoRoot).Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')
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
    if (-not ($resolved.StartsWith($rootPath + $sep, [StringComparison]::Ordinal) -or $resolved -ceq $rootPath)) {
        Add-Failure "$Label escapes repo root: $RelativePath"
        return $null
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        Add-Failure "$Label missing: $RelativePath"
        return $null
    }
    try { $resolved = Resolve-SddEvidenceFilesystemPath $resolved }
    catch {
        Add-Failure "$Label could not be resolved: $RelativePath"
        return $null
    }
    if (-not $resolved.StartsWith($rootPath + $sep, [StringComparison]::Ordinal)) {
        Add-Failure "$Label escapes repo root: $RelativePath"
        return $null
    }
    $normalized = $resolved.Substring($rootPath.Length).TrimStart($sep, '/').Replace('\', '/')
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

function Remove-NonLowercaseMembers {
    # The .sh twin reads every JSON key by its exact lowercase name
    # (dict.get), so a mis-cased key such as Verdict or Spec_Revision is
    # absent there. A PowerShell property read ignores case and would find
    # it. Every key this checker reads is lowercase, so dropping each member
    # whose name has an upper-case letter makes every read here see exactly
    # what Python sees. pwsh 7 cannot hold verdict and Verdict in one object
    # (ConvertFrom-Json throws), so no exact-case value is ever dropped.
    param($Value)
    $pending = New-Object System.Collections.Stack
    $pending.Push($Value)
    while ($pending.Count -gt 0) {
        $item = $pending.Pop()
        if ($item -is [PSCustomObject]) {
            foreach ($property in @($item.PSObject.Properties)) {
                if ($property.Name -cne $property.Name.ToLowerInvariant()) {
                    $item.PSObject.Properties.Remove($property.Name)
                } else {
                    $pending.Push($property.Value)
                }
            }
        } elseif ($item -is [System.Array]) {
            foreach ($element in $item) { $pending.Push($element) }
        }
    }
}

# --- Signing verification helpers (T-007a) ---

# v1 signers sorted artifact pairs differently: the Python signer by code point,
# the PowerShell signer by UTF-16 code unit. A signature matching either is valid.
$SignerOrders = @("code-point", "utf-16")

function Get-EvidenceCanonical {
    param([Parameter(Mandatory)]$Bundle, [Parameter(Mandatory)][string]$Order)
    $artifacts = @($Bundle.artifacts)
    $pairs = @()
    foreach ($artifact in $artifacts) {
        $path = ([string]$artifact.path).Trim()
        $sha = ([string]$artifact.sha256).Trim().ToLowerInvariant()
        $pairs += $path + [char]0 + $sha
    }
    # Ordinal sort to match Python's code-point sort (Sort-Object is culture-aware
    # and would diverge across runtimes, breaking signature parity).
    $pairsArr = [string[]]$pairs
    if ($Order -ceq "code-point") {
        # Big-endian UTF-32 bytes, hex-encoded, compare in code-point order.
        $utf32 = [System.Text.UTF32Encoding]::new($true, $false)
        $keys = [string[]]@($pairsArr | ForEach-Object { ($utf32.GetBytes($_) | ForEach-Object { "{0:x2}" -f $_ }) -join "" })
        [System.Array]::Sort($keys, $pairsArr, [System.StringComparer]::Ordinal)
    } else {
        [System.Array]::Sort($pairsArr, [System.StringComparer]::Ordinal)
    }
    $pairsStr = $pairsArr -join "`n"
    $pairsBytes = [System.Text.Encoding]::UTF8.GetBytes($pairsStr)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $artifactsDigest = ($hasher.ComputeHash($pairsBytes) | ForEach-Object { "{0:x2}" -f $_ }) -join ""

    # Python: "true" only for a JSON true; a verdict only from an object.
    $dirty = if ($Bundle.git_generated_dirty -is [bool] -and $Bundle.git_generated_dirty) { "true" } else { "false" }
    $reviewVerdict = $Bundle.review_verdict
    $verdict = if ($reviewVerdict -is [PSCustomObject]) { ([string]$reviewVerdict.verdict).Trim() } else { "" }

    $lines = @(
        "sdd-evidence-v1",
        ([string]$Bundle.task_id).Trim(),
        ([string]$Bundle.feature).Trim(),
        ([string]$Bundle.risk).Trim(),
        ([string]$Bundle.required_workflow).Trim(),
        ([string]$Bundle.spec_revision).Trim(),
        ([string]$Bundle.git_commit).Trim(),
        $dirty,
        $verdict,
        $artifactsDigest
    )
    return $lines -join "`n"
}

$bundleJson = Get-Content -Raw -Encoding Utf8 -LiteralPath $BundlePath
$bundle = $bundleJson | ConvertFrom-Json
Remove-NonLowercaseMembers $bundle
if ($bundleJson.TrimStart() -notmatch '^\{' -or $bundle -isnot [PSCustomObject]) {
    [Console]::Error.WriteLine('check-evidence-bundle: bundle must be a JSON object')
    exit 1
}
$taskId = ([string]$bundle.task_id).Trim()
$bundleFeature = ([string]$bundle.feature).Trim()
$qualityReport = $bundle.quality_report
$verificationContract = $bundle.verification_contract
$gitCommit = $bundle.git_commit
$gitGeneratedDirty = $bundle.git_generated_dirty -is [bool] -and $bundle.git_generated_dirty
$artifacts = @()

if ($taskId -cnotmatch '^T-\d+$') {
    Add-Failure "task_id is invalid: $taskId"
}
if ($bundleFeature -and $bundleFeature -cnotmatch '^[a-z0-9][a-z0-9-]*$') {
    Add-Failure "feature is invalid: $bundleFeature"
}
if ((Split-Path -Leaf $BundlePath) -cne "$taskId.evidence.json") {
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

$qualityText = $null
if ($qualityInfo) {
    $qualityText = Get-Content -Raw -Encoding Utf8 -LiteralPath $qualityInfo.Resolved
    if ($qualityText -cnotmatch "(?m)^Task ID:\s*$([regex]::Escape($taskId))\s*$") {
        Add-Failure "quality_report missing Task ID: $taskId"
    }
    if ($qualityText -cnotmatch "(?m)^VERDICT:\s*PASS\s*$") {
        Add-Failure "quality_report missing VERDICT: PASS"
    }
    if ((Split-Path -Leaf $qualityInfo.Resolved) -cnotmatch '\.md$') {
        Add-Failure "quality_report must point to a markdown report: $qualityReport"
    }
}

$contract = $null
if ($contractInfo) {
    if ((Split-Path -Leaf $contractInfo.Resolved) -cnotmatch '\.contract\.json$') {
        Add-Failure "verification_contract must point to a contract JSON file: $verificationContract"
    }
    try {
        $contractJson = Get-Content -Raw -Encoding Utf8 -LiteralPath $contractInfo.Resolved
        $contract = $contractJson | ConvertFrom-Json
        Remove-NonLowercaseMembers $contract
        if ($contractJson.TrimStart() -notmatch '^\{' -or $contract -isnot [PSCustomObject]) {
            $contract = $null
            throw 'verification_contract must be a JSON object'
        }
    } catch {
        Add-Failure "verification_contract could not be parsed as JSON: $verificationContract"
    }
    if ($contract -and ([string]$contract.task_id).Trim() -cne $taskId) {
        Add-Failure "verification_contract task_id mismatch: $($contract.task_id) != $taskId"
    }
    $contractFeature = if ($contract) { ([string]$contract.feature).Trim() } else { "" }
    if ($contract -and ($contractFeature -or $bundleFeature) -and $contractFeature -cne $bundleFeature) {
        Add-Failure "verification_contract feature mismatch: $contractFeature != $bundleFeature"
    }
}

$expectedFeature = if ($contract -and ([string]$contract.feature).Trim()) {
    ([string]$contract.feature).Trim()
} else {
    $bundleFeature
}
if ($null -ne $qualityText) {
    $reportFeatureMatches = [regex]::Matches($qualityText, '(?m)^Feature:\s*(.*?)\s*$')
    if ($expectedFeature) {
        if ($reportFeatureMatches.Count -ne 1) {
            Add-Failure "quality_report must contain exactly one Feature line"
        } elseif (-not [string]::Equals(
            $reportFeatureMatches[0].Groups[1].Value,
            $expectedFeature,
            [StringComparison]::Ordinal
        )) {
            Add-Failure "quality_report feature mismatch: expected $expectedFeature"
        }
    } elseif ($reportFeatureMatches.Count -gt 0) {
        Add-Failure "quality_report feature mismatch: bundle and contract omit feature"
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

$requiredArtifacts = [hashtable]::new([StringComparer]::Ordinal)
if ($qualityInfo) { $requiredArtifacts[$qualityInfo.Normalized] = "quality_report" }
if ($contractInfo) { $requiredArtifacts[$contractInfo.Normalized] = "verification_contract" }

if ($contract) {
    if ($contract.checks -isnot [array]) {
        Add-Failure 'verification_contract checks must be an array'
    }
    foreach ($check in @($contract.checks)) {
        if ($check -isnot [PSCustomObject]) {
            Add-Failure 'verification_contract check entries must be objects'
            continue
        }
        if ([bool]$check.passes) {
            $evidenceInfo = Resolve-RepositoryPath -RelativePath ([string]$check.evidence) -Label "passing evidence for check '$($check.id)'"
            if ($evidenceInfo) {
                $requiredArtifacts[$evidenceInfo.Normalized] = "passing evidence for check '$($check.id)'"
            }
        }
    }
}

$artifactIndex = [hashtable]::new([StringComparer]::Ordinal)
foreach ($artifact in @($artifacts)) {
    if ($artifact -isnot [PSCustomObject]) {
        Add-Failure 'artifact entries must be objects'
        continue
    }
    $artifactPath = [string]$artifact.path
    $artifactSha = ([string]$artifact.sha256).Trim().ToLowerInvariant()
    $artifactInfo = Resolve-RepositoryPath -RelativePath $artifactPath -Label "artifact path"
    if (-not $artifactInfo) {
        continue
    }
    if ($artifactSha -cnotmatch '^[a-f0-9]{64}$') {
        Add-Failure "artifact sha256 is invalid for ${artifactPath}: $($artifact.sha256)"
        continue
    }
    if ($artifactIndex.ContainsKey($artifactInfo.Normalized)) {
        Add-Failure "duplicate artifact path in manifest: $($artifactInfo.Normalized)"
        continue
    }
    $artifactIndex[$artifactInfo.Normalized] = $artifactSha
    $actual = Get-Sha256 -Path $artifactInfo.Resolved
    if ($actual -cne $artifactSha) {
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
} elseif (([string]$gitCommit) -cnotmatch '^[0-9a-f]{40}$') {
    Add-Failure "git_commit is invalid (must be 40 lowercase hex): $gitCommit"
} else {
    $gitCommitStr = ([string]$gitCommit).Trim()
    $gitExe = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitExe) {
        Add-Failure "git is not available; cannot verify git_commit binding"
    } else {
        $absRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
        try {
            # Verify commit exists
            & $gitExe.Source -C $absRoot cat-file -e "${gitCommitStr}^{commit}" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Add-Failure "git_commit does not exist in repository: $gitCommitStr"
            } else {
                # Verify commit is HEAD or an ancestor of HEAD
                & $gitExe.Source -C $absRoot merge-base --is-ancestor $gitCommitStr HEAD 2>$null
                if ($LASTEXITCODE -ne 0) {
                    # Commit exists but is not an ancestor — may have been rewritten after
                    # amend/rebase. Tolerate if all artifact hashes still match (35.1).
                    $hashesOk = ($artifactIndex.Count -gt 0)
                    foreach ($norm in $artifactIndex.Keys) {
                        $artPath = [System.IO.Path]::Combine($absRoot, $norm)
                        if (-not (Test-Path -LiteralPath $artPath) -or (Get-Sha256 -Path $artPath) -cne $artifactIndex[$norm]) {
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
if ($contractRisk -and $contractRisk -cne $bundleRisk) {
    $shownRisk = if ($bundleRisk) { $bundleRisk } else { "(empty)" }
    Add-Failure "bundle risk '$shownRisk' != contract risk '$contractRisk'"
}
# Gate provenance on the trusted contract risk; fall back to bundle risk (legacy).
$effectiveRisk = if ($contractRisk) { $contractRisk } else { $bundleRisk }

# High/critical tier provenance requirements
if (@("high", "critical") -ccontains $effectiveRisk) {
    $specRevision = ([string]$bundle.spec_revision).Trim()
    if ($specRevision -cnotmatch '^[a-f0-9]{64}$') {
        Add-Failure "high/critical bundle requires spec_revision (64-hex), got: $(if ($specRevision) { $specRevision } else { '(empty)' })"
    }

    $buildEnv = $bundle.build_env
    if (-not $buildEnv -or -not (([string]$buildEnv.os).Trim())) {
        Add-Failure "high/critical bundle requires build_env.os"
    }

    $reviewVerdict = $bundle.review_verdict
    if (-not $reviewVerdict) {
        Add-Failure "high/critical bundle requires review_verdict object"
    } elseif ($reviewVerdict.verdict -isnot [string] -or $reviewVerdict.verdict.Trim() -cne "PASS") {
        Add-Failure "high/critical bundle requires review_verdict.verdict == PASS, got: $(if ($reviewVerdict.verdict) { $reviewVerdict.verdict } else { '(empty)' })"
    }
}

# Critical-only signature verification (T-007a)
if ($effectiveRisk -ceq "critical") {
    # The signed canonical form renders these with Python's str() in the .sh
    # twin; [string] renders a number, array or object differently, so only a
    # string (or an absent field) can be verified the same way by both.
    foreach ($field in @("task_id", "feature", "risk", "required_workflow", "spec_revision", "git_commit")) {
        $value = $bundle.$field
        if ($null -ne $value -and $value -isnot [string]) {
            Add-Failure "critical bundle field $field must be a string"
        }
    }
    if ($gitGeneratedDirty) {
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
        } elseif ($alg -ceq "hmac-sha256") {
            $keyInfo = Resolve-EvidenceKey
            if ($null -eq $keyInfo) {
                Add-Failure "critical bundle signature cannot be verified: no evidence key available"
            } else {
                # ::new() so the byte[] key is one ctor arg (New-Object -ArgumentList splats arrays).
                $hmac = [System.Security.Cryptography.HMACSHA256]::new([byte[]]$keyInfo.key)
                $valueUtf8 = [System.Text.Encoding]::UTF8.GetBytes($value)
                $matched = $false
                foreach ($order in $SignerOrders) {
                    $canonicalBytes = [System.Text.Encoding]::UTF8.GetBytes((Get-EvidenceCanonical -Bundle $bundle -Order $order))
                    $expected = ($hmac.ComputeHash($canonicalBytes) | ForEach-Object { "{0:x2}" -f $_ }) -join ""
                    # Constant-time like Python's hmac.compare_digest; also runs on Windows PowerShell 5.1.
                    $expectedUtf8 = [System.Text.Encoding]::UTF8.GetBytes($expected)
                    $diff = $expectedUtf8.Length -bxor $valueUtf8.Length
                    for ($i = 0; $i -lt $expectedUtf8.Length; $i++) {
                        $diff = $diff -bor ($expectedUtf8[$i] -bxor $valueUtf8[$i % [Math]::Max(1, $valueUtf8.Length)])
                    }
                    if ($diff -eq 0) { $matched = $true }
                }
                if (-not $matched) {
                    Add-Failure "critical bundle signature is invalid (HMAC mismatch)"
                }
            }
        } elseif ($alg -ceq "sigstore") {
            $verified = [System.Environment]::GetEnvironmentVariable("SDD_EVIDENCE_SIGSTORE_VERIFIED")
            if ($verified -cne "1") {
                Add-Failure "critical bundle uses sigstore signature but SDD_EVIDENCE_SIGSTORE_VERIFIED is not set"
            }
        } else {
            Add-Failure "critical bundle has unsupported signature alg: $alg"
        }
    }
}

if ($gitGeneratedDirty) {
    Write-Host "WARNING: evidence bundle for task ${taskId} was generated with a dirty working tree"
}

if ($failures.Count -gt 0) {
    Write-Host "Evidence bundle FAILED for task ${taskId}:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "Evidence bundle passed for task $taskId."
exit 0
