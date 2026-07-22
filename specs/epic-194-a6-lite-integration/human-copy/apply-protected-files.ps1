# apply-protected-files.ps1 (epic-194-a6-lite-integration)
#
# Feature-scoped human-copy application runner (T-001, REQ-002/REQ-005 share,
# AC-010/AC-031). Hard-anchored to this feature's own
# `specs/epic-194-a6-lite-integration/human-copy` prefix -- never the
# Epic-136 prefix (design.md Protected-File Statement, "Feature-scoped, not
# fixed-prefix"). Mirrors the discipline of
# `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
# (Get-CanonicalTargets / Get-ManifestDigests / VerifyPublished /
# Invoke-PostInstallVerification) against this feature's own, much smaller,
# four-target payload -- it does not call into that runner.
#
# Contract implemented (design.md Protected-File Statement, four points):
#   1. Feature-scoped, not fixed-prefix target/digest resolution.
#   2. Three-way exact-set verification: declared four-target payload list
#      == MANIFEST.sha256's own target set == the staged directory's own
#      payload file set (control files -- MANIFEST.sha256 and this runner
#      script itself -- excluded by construction, investigation.md
#      INV-020, "Payload file set, defined").
#   3. Per-target sha256 verification against MANIFEST.sha256 BEFORE any
#      copy is attempted.
#   4. Post-copy re-verification of every installed file's own hash against
#      the staged/manifest hash.
#
# Functions below are intentionally separable (dot-sourceable) so the test
# suite can exercise each contract point in isolation, including simulating
# a post-copy corruption between Copy-Payload and Test-PostCopyHashes --
# the real end-to-end flow (Invoke-ApplyProtectedFiles) always runs all
# four points in order.

[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Feature-scoped prefix (never the Epic-136 prefix, contract point 1).
$Script:HumanCopyPrefix = 'specs/epic-194-a6-lite-integration/human-copy'

# The four declared payload targets (design.md Protected-File Statement).
$Script:DeclaredTargets = @(
    'plugins/sdd-lite/references/risk-upgrade-policy.md',
    'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
    'plugins/sdd-lite/scripts/check-risk-upgrade.ps1',
    'plugins/sdd-lite/skills/lite-spec/SKILL.md'
)

# Control files excluded from the payload-set comparison by construction
# (investigation.md INV-020, "Payload file set, defined"). Matched by their
# path relative to the human-copy root.
$Script:ControlFileRelativePaths = @('MANIFEST.sha256', 'apply-protected-files.ps1')

function Fail {
    param([Parameter(Mandatory)][string]$Message)
    throw "apply-protected-files(epic-194-a6): $Message"
}

function Get-RepositoryRoot {
    if ($RepositoryRoot) {
        if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
            Fail 'RepositoryRoot must be an existing directory'
        }
        return (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd('/', '\')
    }
    $current = Split-Path -Parent $PSCommandPath
    for ($i = 0; $i -lt 20; $i++) {
        if (Test-Path -LiteralPath (Join-Path $current 'AGENTS.md') -PathType Leaf) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    Fail 'unable to locate repository root (no AGENTS.md found above runner path)'
}

function Assert-NotSymlink {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.LinkType) {
            Fail "$Label is a symlink/reparse point, refusing: $Path"
        }
    }
}

function Get-NormalizedRelativePath {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$FullPath)
    $rel = [IO.Path]::GetRelativePath($Root, $FullPath)
    return ($rel -replace '\\', '/')
}

# Contract point 2 (part a): enumerate the staged directory's own payload
# file set, excluding control files by construction.
function Get-PayloadFileSet {
    param([Parameter(Mandatory)][string]$HumanCopyRoot)
    if (-not (Test-Path -LiteralPath $HumanCopyRoot -PathType Container)) {
        Fail "human-copy root not found: $HumanCopyRoot"
    }
    $all = @(Get-ChildItem -LiteralPath $HumanCopyRoot -Recurse -File -Force -ErrorAction Stop)
    $payload = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $all) {
        $rel = Get-NormalizedRelativePath $HumanCopyRoot $entry.FullName
        if ($Script:ControlFileRelativePaths -contains $rel) { continue }
        [void]$payload.Add($rel)
    }
    return @($payload | Sort-Object)
}

# Parses MANIFEST.sha256 (GNU sha256sum two-space format, one line per
# target, lowercase hex digest, no duplicates).
function Get-ManifestTargets {
    param([Parameter(Mandatory)][string]$ManifestPath)
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        Fail "MANIFEST.sha256 not found: $ManifestPath"
    }
    Assert-NotSymlink $ManifestPath 'MANIFEST.sha256'
    $content = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop
    if ($null -eq $content) { $content = '' }
    if ($content.Contains("`r`n")) { $content = $content -replace "`r`n", "`n" }
    if ($content.Contains("`r")) { Fail 'MANIFEST.sha256 contains a bare carriage return' }
    $lines = @($content -split "`n" | Where-Object { $_ -ne '' })
    $digests = [ordered]@{}
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($line in $lines) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') {
            Fail "MANIFEST.sha256 line is not lowercase two-space sha256 format: $line"
        }
        $digest = $Matches[1]
        $target = $Matches[2]
        if ($target -match '^/' -or $target.Contains('\') -or $target.Contains(':') -or ($target -split '/' | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' })) {
            Fail "MANIFEST.sha256 target is not a normalized repository-relative path: $target"
        }
        if (-not $seen.Add($target)) {
            Fail "MANIFEST.sha256 has a duplicate target: $target"
        }
        $digests[$target] = $digest
    }
    return $digests
}

# Contract point 2 (part b): three-way exact-set verification. Fails BEFORE
# any copy is attempted.
function Test-ExactSet {
    param(
        [Parameter(Mandatory)][string[]]$Declared,
        [Parameter(Mandatory)]$ManifestDigests,
        [Parameter(Mandatory)][string[]]$PayloadSet
    )
    $declaredSet = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($t in $Declared) { [void]$declaredSet.Add($t) }
    $manifestSet = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($k in $ManifestDigests.Keys) { [void]$manifestSet.Add($k) }
    $payloadSetH = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($p in $PayloadSet) { [void]$payloadSetH.Add($p) }

    $extraInManifest = @($manifestSet | Where-Object { -not $declaredSet.Contains($_) })
    $missingFromManifest = @($declaredSet | Where-Object { -not $manifestSet.Contains($_) })
    if ($extraInManifest.Count -gt 0) {
        Fail "MANIFEST.sha256 declares an undeclared target: $($extraInManifest -join ', ')"
    }
    if ($missingFromManifest.Count -gt 0) {
        Fail "MANIFEST.sha256 is missing a declared target: $($missingFromManifest -join ', ')"
    }

    $extraInPayload = @($payloadSetH | Where-Object { -not $declaredSet.Contains($_) })
    $missingFromPayload = @($declaredSet | Where-Object { -not $payloadSetH.Contains($_) })
    if ($extraInPayload.Count -gt 0) {
        Fail "staged payload contains an undeclared path outside the four-target set: $($extraInPayload -join ', ')"
    }
    if ($missingFromPayload.Count -gt 0) {
        Fail "staged payload is missing a declared target: $($missingFromPayload -join ', ')"
    }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Contract point 3: per-target hash verification BEFORE any copy.
function Test-ManifestHashes {
    param(
        [Parameter(Mandatory)][string]$HumanCopyRoot,
        [Parameter(Mandatory)][string[]]$Targets,
        [Parameter(Mandatory)]$ManifestDigests
    )
    foreach ($target in $Targets) {
        $staged = Join-Path $HumanCopyRoot ($target -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $staged -PathType Leaf)) {
            Fail "staged payload target missing on disk: $target"
        }
        Assert-NotSymlink $staged "staged payload target ($target)"
        $actual = Get-Sha256Hex $staged
        $expected = $ManifestDigests[$target]
        if ($actual -ne $expected) {
            Fail "staged payload hash mismatch for $target (manifest expected $expected, staged file is $actual)"
        }
    }
}

# Copies every target from the staged human-copy tree to its live
# destination via write-to-temp-then-rename (same-directory rename is
# atomic on both POSIX and NTFS), refusing to follow a symlinked
# destination or destination parent.
function Copy-Payload {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$HumanCopyRoot,
        [Parameter(Mandatory)][string[]]$Targets
    )
    foreach ($target in $Targets) {
        $nativeTarget = $target -replace '/', [IO.Path]::DirectorySeparatorChar
        $source = Join-Path $HumanCopyRoot $nativeTarget
        $destination = Join-Path $RepoRoot $nativeTarget
        $destParent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
            Fail "destination parent directory does not exist: $destParent"
        }
        Assert-NotSymlink $destParent "destination parent directory ($target)"
        if (Test-Path -LiteralPath $destination) {
            Assert-NotSymlink $destination "destination ($target)"
        }
        $tempName = '.sdd-a6-' + [Guid]::NewGuid().ToString('N') + '.tmp'
        $tempPath = Join-Path $destParent $tempName
        Copy-Item -LiteralPath $source -Destination $tempPath -Force -ErrorAction Stop
        try {
            Move-Item -LiteralPath $tempPath -Destination $destination -Force -ErrorAction Stop
        } catch {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            throw
        }
    }
}

# Contract point 4: post-copy re-verification. Detects and reports a
# post-copy corruption rather than silently accepting it.
function Test-PostCopyHashes {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Targets,
        [Parameter(Mandatory)]$ManifestDigests
    )
    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($target in $Targets) {
        $nativeTarget = $target -replace '/', [IO.Path]::DirectorySeparatorChar
        $destination = Join-Path $RepoRoot $nativeTarget
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            [void]$failures.Add("$target : missing after copy")
            continue
        }
        $actual = Get-Sha256Hex $destination
        $expected = $ManifestDigests[$target]
        if ($actual -ne $expected) {
            [void]$failures.Add("$target : post-copy hash mismatch (manifest expected $expected, installed file is $actual)")
        }
    }
    if ($failures.Count -gt 0) {
        Fail "post-copy re-verification FAILED:`n$($failures -join "`n")"
    }
}

# End-to-end flow: all four contract points, in order. Exact-set and hash
# verification both run to completion BEFORE Copy-Payload is ever called.
function Invoke-ApplyProtectedFiles {
    param([string]$RepoRootOverride)
    $repoRoot = if ($RepoRootOverride) { $RepoRootOverride } else { Get-RepositoryRoot }
    $humanCopyRoot = Join-Path $repoRoot ($Script:HumanCopyPrefix -replace '/', [IO.Path]::DirectorySeparatorChar)

    $payloadSet = Get-PayloadFileSet $humanCopyRoot
    $manifestDigests = Get-ManifestTargets (Join-Path $humanCopyRoot 'MANIFEST.sha256')
    Test-ExactSet $Script:DeclaredTargets $manifestDigests $payloadSet
    Test-ManifestHashes $humanCopyRoot $Script:DeclaredTargets $manifestDigests

    Copy-Payload $repoRoot $humanCopyRoot $Script:DeclaredTargets
    Test-PostCopyHashes $repoRoot $Script:DeclaredTargets $manifestDigests

    Write-Host 'apply-protected-files(epic-194-a6): complete'
}

# Only auto-execute when invoked directly, not when dot-sourced by a test
# harness (the test suite dot-sources this file to call the functions above
# individually, e.g. to inject a post-copy corruption between Copy-Payload
# and Test-PostCopyHashes).
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ApplyProtectedFiles $RepositoryRoot
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 2
    }
}
