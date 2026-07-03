# Deterministic gate: design-system conformance (warn-phase).
# Usage: check-design-system.ps1 -ProjectRoot <path> [-DesignMd <path>] [-ChangedFiles <paths...>]
#
# Checks (all skipped with exit 0 when <ProjectRoot>/design-system is absent):
#  1. design-system/design-tokens.json carries the contract meta envelope
#     (schema design-system-contract/v1, semver version, generated_by) and the
#     required token groups (color, typography, spacing).
#  2. Each ChangedFiles entry contains no raw style values (#hex colors,
#     rgb(, hsl( calls). Excluded: design-system/, build/, tests/ paths and
#     *.md / *.svg files.
#  3. When -DesignMd is given: it contains a "## Design System Compliance"
#     section and does not record ds_profile: none while design-system/ exists.
#
# Warn-phase: findings print as WARN and exit 0. Set
# SDD_DESIGN_SYSTEM_ENFORCE=error to fail (exit 1) on findings instead.
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$DesignMd = "",
    [string[]]$ChangedFiles = @()
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    Write-Error "check-design-system: project root not found: $ProjectRoot"
    exit 1
}
$dsDir = Join-Path $ProjectRoot "design-system"
if (-not (Test-Path -LiteralPath $dsDir)) {
    Write-Host "check-design-system skipped: no design-system/ directory."
    exit 0
}

$findings = @()
$tokensPath = Join-Path $dsDir "design-tokens.json"
if (-not (Test-Path -LiteralPath $tokensPath)) {
    $findings += "design-tokens.json missing"
} else {
    try {
        $tokens = Get-Content -Raw -Encoding Utf8 $tokensPath | ConvertFrom-Json
        if ($tokens.meta.schema -ne 'design-system-contract/v1') { $findings += "design-tokens.json: meta.schema is not design-system-contract/v1" }
        if ([string]$tokens.meta.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { $findings += "design-tokens.json: meta.version is not semver" }
        if ([string]::IsNullOrEmpty([string]$tokens.meta.generated_by)) { $findings += "design-tokens.json: meta.generated_by missing" }
        foreach ($group in @('color', 'typography', 'spacing')) {
            if ($null -eq $tokens.PSObject.Properties[$group]) { $findings += "design-tokens.json: token group $group missing" }
        }
    } catch {
        $findings += "design-tokens.json: not valid JSON"
    }
}

foreach ($f in $ChangedFiles) {
    $rel = [string]$f
    if ($rel -match '(^|[\\/])design-system[\\/]' -or $rel -match '\.(md|svg)$' -or $rel -match '(^|[\\/])tests[\\/]' -or $rel -match '(^|[\\/])build[\\/]') { continue }
    $target = $rel
    if (-not (Test-Path -LiteralPath $target)) { $target = Join-Path $ProjectRoot $rel }
    if (-not (Test-Path -LiteralPath $target)) { continue }
    $hits = @(Select-String -LiteralPath $target -Pattern '#[0-9a-fA-F]{6}([^0-9a-fA-F]|$)|#[0-9a-fA-F]{3}([^0-9a-fA-F]|$)|rgb\(|hsl\(' | Select-Object -First 20)
    foreach ($hit in $hits) { $findings += "raw style value: ${rel}: $($hit.LineNumber):$($hit.Line)" }
}

if ($DesignMd -ne "") {
    if (Test-Path -LiteralPath $DesignMd) {
        $dm = Get-Content -Raw -Encoding Utf8 $DesignMd
        if ($dm -notmatch '## Design System Compliance') {
            $findings += "design.md: missing '## Design System Compliance' section"
        } elseif ($dm -match 'ds_profile: none') {
            $findings += "design.md: records ds_profile: none while design-system/ exists"
        }
    } else {
        $findings += "design.md not found: $DesignMd"
    }
}

if ($findings.Count -gt 0) {
    if ($env:SDD_DESIGN_SYSTEM_ENFORCE -eq 'error') {
        Write-Host "check-design-system FAILED ($($findings.Count) finding(s)):"
        $findings | ForEach-Object { Write-Host " - $_" }
        exit 1
    }
    Write-Host "check-design-system WARN ($($findings.Count) finding(s)):"
    $findings | ForEach-Object { Write-Host " - $_" }
    Write-Host "Warn-phase: findings do not block; record them in the quality-gate report. Set SDD_DESIGN_SYSTEM_ENFORCE=error to enforce."
    exit 0
}
Write-Host "check-design-system passed."
exit 0
