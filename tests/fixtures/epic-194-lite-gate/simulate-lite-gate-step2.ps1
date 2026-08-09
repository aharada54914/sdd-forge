# simulate-lite-gate-step2.ps1 (epic-194-a6-lite-integration, T-004 test
# fixture, REQ-003/REQ-004). PowerShell twin of
# simulate-lite-gate-step2.sh -- see that file's header for the full
# rationale (SKILL.md is agent-facing prose; this simulates its documented
# Step 2a/2b algorithm so fixtures can exercise it; the schema check is a
# clearly-synthetic stand-in for A4/A5's own not-yet-existing validator).
#
# Dot-source this file, then call Invoke-LiteGateStep2Simulation, which
# returns a [pscustomobject]@{ Verdict; Reason; RanChecks }.

$Script:CheckIdGrammar = '^[a-z0-9][a-z0-9-]*$'
$Script:BaselineChecks = @('placeholder', 'lint', 'typecheck', 'build', 'test')

function Test-SimSummarySchema([string]$Path) {
    try {
        $content = Get-Content -LiteralPath $Path -Raw
        $data = $content | ConvertFrom-Json -ErrorAction Stop
        foreach ($key in @('schema', 'feature', 'track', 'capabilities', 'required_lite_checks', 'full_upgrade_required')) {
            if ($null -eq $data.PSObject.Properties[$key]) { return $false }
        }
        if ($data.schema -ne 'sdd-capability-summary/v1') { return $false }
        if ($data.track -ne 'lite') { return $false }
        if ($data.capabilities -isnot [array] -and $data.capabilities -isnot [System.Collections.IEnumerable]) { return $false }
        if ($data.full_upgrade_required -isnot [bool]) { return $false }
        return $true
    } catch {
        return $false
    }
}

function Get-SimSummaryField([string]$Path, [string]$Field) {
    $content = Get-Content -LiteralPath $Path -Raw
    $data = $content | ConvertFrom-Json
    return $data.$Field
}

function Resolve-SimCommand([string]$Id, [string]$RepoRoot) {
    $packageJson = Join-Path $RepoRoot 'package.json'
    if (Test-Path -LiteralPath $packageJson -PathType Leaf) {
        try {
            $pkg = Get-Content -LiteralPath $packageJson -Raw | ConvertFrom-Json
            if ($null -ne $pkg.scripts -and $null -ne $pkg.scripts.PSObject.Properties[$Id]) {
                return "npm:$Id"
            }
        } catch { }
    }
    $shPath = Join-Path $RepoRoot "scripts/$Id.sh"
    $ps1Path = Join-Path $RepoRoot "scripts/$Id.ps1"
    $scriptsDir = Join-Path $RepoRoot 'scripts'
    if ((Test-Path -LiteralPath $shPath) -and (Test-Path -LiteralPath $ps1Path)) {
        $shItem = Get-Item -LiteralPath $shPath -Force
        $ps1Item = Get-Item -LiteralPath $ps1Path -Force
        if ($shItem.LinkType -or $ps1Item.LinkType) { return 'unmapped' }
        if ($shItem.PSIsContainer -or $ps1Item.PSIsContainer) { return 'unmapped' }
        $scriptsCanon = (Resolve-Path -LiteralPath $scriptsDir).Path
        $shCanon = (Resolve-Path -LiteralPath $shPath).Path
        $ps1Canon = (Resolve-Path -LiteralPath $ps1Path).Path
        # These two prefix-containment checks are currently unreachable by any
        # fixture in this suite (quality-gate NEEDS_WORK cycle 1, Minor
        # finding) -- see simulate-lite-gate-step2.sh's matching comment for
        # the full rationale (grammar + symlink/regular-file checks already
        # foreclose any escape given today's grammar). Retained as
        # defense-in-depth matching SKILL.md:112's own documented containment
        # rule. Do not remove; the LinkType check above is a different,
        # load-bearing rule.
        if (-not $shCanon.StartsWith($scriptsCanon, [StringComparison]::Ordinal)) { return 'unmapped' }
        if (-not $ps1Canon.StartsWith($scriptsCanon, [StringComparison]::Ordinal)) { return 'unmapped' }
        return "scripts:$Id"
    }
    return 'unmapped'
}

function Invoke-LiteGateStep2Simulation([string]$SummaryPath, [string]$Enforcement, [string]$RepoRoot) {
    $result = [pscustomobject]@{ Verdict = 'PASS'; Reason = ''; RanChecks = @() }
    $requiredChecks = @()

    if ($Enforcement -ne 'none') {
        if ([string]::IsNullOrEmpty($SummaryPath) -or -not (Test-Path -LiteralPath $SummaryPath -PathType Leaf)) {
            $result.Verdict = 'FAIL'
            $result.Reason = 'capability-summary.yaml missing under active capability_enforcement'
            return $result
        }
        if (-not (Test-SimSummarySchema $SummaryPath)) {
            $result.Verdict = 'FAIL'
            $result.Reason = 'capability-summary.yaml failed schema validation'
            return $result
        }
        $fullUpgrade = Get-SimSummaryField $SummaryPath 'full_upgrade_required'
        if ($fullUpgrade -eq $true) {
            $result.Verdict = 'FAIL'
            $result.Reason = 'full_upgrade_required: true'
            return $result
        }
        $requiredChecks = @(Get-SimSummaryField $SummaryPath 'required_lite_checks')
    }

    foreach ($id in $requiredChecks) {
        if ([string]::IsNullOrEmpty($id)) { continue }
        if ($Script:BaselineChecks -contains $id) { continue }
        if ($id -notmatch $Script:CheckIdGrammar) {
            $result.Verdict = 'FAIL'
            $result.Reason = "$id`: check-id does not match the required ^[a-z0-9][a-z0-9-]*`$ grammar"
            return $result
        }
        $resolved = Resolve-SimCommand $id $RepoRoot
        if ($resolved -eq 'unmapped') {
            $result.Verdict = 'FAIL'
            $result.Reason = "$id`: required Lite check has no discoverable command"
            return $result
        }
        $result.RanChecks += $resolved
    }

    return $result
}
