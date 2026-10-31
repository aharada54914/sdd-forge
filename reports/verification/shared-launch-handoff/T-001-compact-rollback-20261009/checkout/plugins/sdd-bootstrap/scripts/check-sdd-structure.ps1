# Deterministic preflight: verify the SDD project directory structure.
# Usage: check-sdd-structure.ps1 [[-Root] <project-root>] [-Feature <slug>]
# Default project-root is the current directory.
#
# Required items (missing → "missing: <path>", counted toward exit code):
#   AGENTS.md, specs/, reports/implementation/, reports/quality-gate/,
#   docs/adr/, docs/review-tickets/
#
# Advisory items (missing → "advisory: <path>", do not affect exit code):
#   CLAUDE.md, contracts/, docs/architecture/
#
# Drift check (advisory, does not affect exit code):
#   Any directory matching specs/*/adr prints:
#   "drift: <path> (ADRs belong in docs/adr/)"
#
# Host detection:
#   "host: gitlab"  if .gitlab-ci.yml or .gitlab/ exists
#   "host: github"  if .github/ exists
#   "host: local"   if neither
#
# Final line:
#   "check-sdd-structure: OK"                   (exit 0) when no missing items
#   "check-sdd-structure: FAIL (N missing)"  to stderr and exit 1 otherwise
param(
    [string]$Root = ".",
    [AllowEmptyString()]
    [string]$Feature
)
$ErrorActionPreference = "Stop"

$featureSelected = $PSBoundParameters.ContainsKey("Feature")
if ($featureSelected -and $Feature -cnotmatch '^[a-z0-9][a-z0-9-]*$') {
    $Host.UI.WriteErrorLine("invalid feature: $Feature")
    exit 1
}

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Error "check-sdd-structure: project root not found: $Root"
    exit 1
}

$missing = 0

function Check-Required {
    param([string]$RelPath, [string]$Kind)
    $full = Join-Path $Root $RelPath
    $exists = if ($Kind -eq "f") { Test-Path -LiteralPath $full -PathType Leaf } else { Test-Path -LiteralPath $full -PathType Container }
    if (-not $exists) {
        Write-Host "missing: $RelPath"
        $script:missing++
    }
}

function Check-Advisory {
    param([string]$RelPath, [string]$Kind)
    $full = Join-Path $Root $RelPath
    $exists = if ($Kind -eq "f") { Test-Path -LiteralPath $full -PathType Leaf } else { Test-Path -LiteralPath $full -PathType Container }
    if (-not $exists) {
        Write-Host "advisory: $RelPath"
    }
}

function Test-ReparsePoint {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    return $null -ne $item -and
        (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

# --- required items ---
Check-Required "AGENTS.md"              "f"
Check-Required "specs"                  "d"
Check-Required "reports/implementation" "d"
Check-Required "reports/quality-gate"   "d"
Check-Required "docs/adr"              "d"
Check-Required "docs/review-tickets"   "d"

# --- selected full-profile feature ---
if ($featureSelected) {
    $specsPathForFeature = Join-Path $Root "specs"
    $featurePath = Join-Path $specsPathForFeature $Feature
    if ((Test-ReparsePoint $specsPathForFeature) -or (Test-ReparsePoint $featurePath)) {
        $Host.UI.WriteErrorLine("invalid feature: $Feature")
        exit 1
    }
    $featureFiles = @(
        "requirements.md",
        "design.md",
        "ux-spec.md",
        "frontend-spec.md",
        "infra-spec.md",
        "security-spec.md",
        "acceptance-tests.md",
        "tasks.md",
        "traceability.md"
    )
    foreach ($name in $featureFiles) {
        if (Test-ReparsePoint (Join-Path $featurePath $name)) {
            $Host.UI.WriteErrorLine("invalid feature: $Feature")
            exit 1
        }
        Check-Required "specs/$Feature/$name" "f"
    }
}

# --- advisory items ---
Check-Advisory "CLAUDE.md"           "f"
Check-Advisory "contracts"           "d"
Check-Advisory "docs/architecture"   "d"

# --- drift check: specs/*/adr directories ---
$specsPath = Join-Path $Root "specs"
# Hoist Resolve-Path outside the foreach loop to avoid repeated syscalls.
$absRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')
if (Test-Path -LiteralPath $specsPath -PathType Container) {
    $adrDirs = Get-ChildItem -Path $specsPath -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $candidate = Join-Path $_.FullName "adr"
            if (Test-Path -LiteralPath $candidate -PathType Container) { $candidate }
        }
    foreach ($adrDir in $adrDirs) {
        # Produce relative path from Root
        $rel = $adrDir.Substring($absRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, '/')
        # Normalise to forward slashes for cross-platform consistency
        $rel = $rel -replace '\\', '/'
        Write-Host "drift: $rel (ADRs belong in docs/adr/)"
    }
}

# --- host detection ---
$detectedHost = $false
$gitlabCi = Join-Path $Root ".gitlab-ci.yml"
$gitlabDir = Join-Path $Root ".gitlab"
if ((Test-Path -LiteralPath $gitlabCi -PathType Leaf) -or (Test-Path -LiteralPath $gitlabDir -PathType Container)) {
    Write-Host "host: gitlab"
    $detectedHost = $true
}
$githubDir = Join-Path $Root ".github"
if (Test-Path -LiteralPath $githubDir -PathType Container) {
    Write-Host "host: github"
    $detectedHost = $true
}
if (-not $detectedHost) {
    Write-Host "host: local"
}

# --- final result ---
if ($missing -eq 0) {
    Write-Host "check-sdd-structure: OK"
    exit 0
} else {
    $Host.UI.WriteErrorLine("check-sdd-structure: FAIL ($missing missing)")
    exit 1
}
