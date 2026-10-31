# Deterministic gate: domain conformance (warn-phase).
# Usage: check-domain-conformance.ps1 -ProjectRoot <path> [-RequirementsMd <path>] [-DesignMd <path>]
#
# Checks (all skipped with exit 0 when <ProjectRoot>/domain is absent):
#  1. requirements.md's Bounded-Context: field (when present) names only
#     context(s) that exist in domain/domain-contract.json.
#  2. Every canonical term used in requirements.md structured fields
#     (heading-level [[term:Name]] markers) matches an exact canonical term
#     from domain-contract.json -- v1 term-matching scope is exact
#     canonical-term matching on structured fields only (no lexical-variant
#     or synonym matching), per design.md Assumptions / OQ-R1.
#  3. Every aggregate name referenced in design.md (an inline Markdown link
#     to an aggregates/ path) exists in domain/aggregates/<name>.md.
#  4. When Bounded-Context: lists exactly two contexts, the context map
#     (domain/domain-contract.json relations[]) must declare a relation
#     between them (AC-015); otherwise a warn finding is recorded.
#
# Warn-phase: findings print as WARN and exit 0. Set
# SDD_DOMAIN_ENFORCE=error to fail (exit 1) on findings instead.
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$RequirementsMd = "",
    [string]$DesignMd = ""
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    Write-Error "check-domain-conformance: project root not found: $ProjectRoot"
    exit 1
}
$domainDir = Join-Path $ProjectRoot "domain"
if (-not (Test-Path -LiteralPath $domainDir)) {
    Write-Host "check-domain-conformance skipped: no domain/ directory."
    exit 0
}

$contractPath = Join-Path $domainDir "domain-contract.json"
if (-not (Test-Path -LiteralPath $contractPath)) {
    Write-Host "check-domain-conformance skipped: no domain/domain-contract.json found."
    exit 0
}

$findings = @()

function Get-PropSafe {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

$contract = $null
try {
    $contract = Get-Content -Raw -Encoding Utf8 -LiteralPath $contractPath | ConvertFrom-Json
} catch {
    Write-Host "check-domain-conformance skipped: domain-contract.json is not valid JSON."
    exit 0
}

$contexts = @(Get-PropSafe $contract "contexts")
$contextNames = @($contexts | ForEach-Object { Get-PropSafe $_ "name" })
$canonicalTerms = New-Object System.Collections.Generic.List[string]
$aggregateNames = New-Object System.Collections.Generic.List[string]
foreach ($ctx in $contexts) {
    foreach ($term in @(Get-PropSafe $ctx "terms")) {
        $canonical = Get-PropSafe $term "canonical"
        if ($null -ne $canonical) { $canonicalTerms.Add([string]$canonical) }
    }
    foreach ($agg in @(Get-PropSafe $ctx "aggregates")) {
        $aggName = Get-PropSafe $agg "name"
        if ($null -ne $aggName) { $aggregateNames.Add([string]$aggName) }
    }
}
$relations = @(Get-PropSafe $contract "relations")

function Test-RelationDeclared {
    param([string]$A, [string]$B)
    foreach ($rel in $relations) {
        $from = Get-PropSafe $rel "from"
        $to = Get-PropSafe $rel "to"
        if (($from -eq $A -and $to -eq $B) -or ($from -eq $B -and $to -eq $A)) { return $true }
    }
    return $false
}

# --- Check 1 + 4: Bounded-Context: field in requirements.md -------------
if ($RequirementsMd -ne "") {
    if (Test-Path -LiteralPath $RequirementsMd) {
        $reqText = Get-Content -Raw -Encoding Utf8 -LiteralPath $RequirementsMd
        $bcMatch = [regex]::Match($reqText, '(?m)^Bounded-Context:\s*(.+)$')
        if ($bcMatch.Success) {
            $bcRaw = $bcMatch.Groups[1].Value
            $bcRaw = [regex]::Replace($bcRaw, '\(.*\)\s*$', '')
            $bcParts = $bcRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            foreach ($ctx in $bcParts) {
                if ($contextNames -notcontains $ctx) {
                    $findings += "requirements.md: Bounded-Context '$ctx' not found in domain-contract.json"
                }
            }
            if ($bcParts.Count -eq 2) {
                $c1 = $bcParts[0]
                $c2 = $bcParts[1]
                if (($contextNames -contains $c1) -and ($contextNames -contains $c2)) {
                    if (-not (Test-RelationDeclared -A $c1 -B $c2)) {
                        $findings += "requirements.md: Bounded-Context lists two contexts ('$c1', '$c2') with no declared relation in context map"
                    }
                }
            }
        }

        # --- Check 2: canonical-term structured-field usage (heading markers) ---
        # Iterate indexed lines (not a multiline regex over the raw text) so the
        # finding carries the 1-based source line number, matching the .sh twin's
        # "requirements.md:<lineno>:" prefix (RT-20260707-002 parity fix).
        $reqLines = $reqText -split "`r?`n"
        for ($i = 0; $i -lt $reqLines.Count; $i++) {
            $line = $reqLines[$i]
            if ($line -notmatch '^#{1,6}[ \t]') { continue }
            $termMatches = [regex]::Matches($line, '\[\[term:([^\]]+)\]\]')
            foreach ($tm in $termMatches) {
                $usedTerm = $tm.Groups[1].Value
                if ($canonicalTerms -notcontains $usedTerm) {
                    $findings += "requirements.md:$($i + 1): unrecognized term '$usedTerm' (not a canonical term in domain-contract.json)"
                }
            }
        }
    } else {
        $findings += "requirements.md not found: $RequirementsMd"
    }
}

# --- Check 3: aggregate references in design.md ---------------------------
if ($DesignMd -ne "") {
    if (Test-Path -LiteralPath $DesignMd) {
        $designText = Get-Content -Raw -Encoding Utf8 -LiteralPath $DesignMd
        $linkMatches = [regex]::Matches($designText, '\[([A-Z][A-Za-z0-9]*)\]\(([^)]*aggregates/[^)]*)\)')
        foreach ($lm in $linkMatches) {
            $agg = $lm.Groups[1].Value
            if ($aggregateNames -notcontains $agg) {
                $findings += "design.md: aggregate reference '$agg' not found in domain-contract.json aggregates"
            }
            $card = Join-Path $domainDir (Join-Path "aggregates" "$agg.md")
            if (-not (Test-Path -LiteralPath $card)) {
                $findings += "design.md: aggregate reference '$agg' has no domain/aggregates/$agg.md card"
            }
        }
    } else {
        $findings += "design.md not found: $DesignMd"
    }
}

if ($findings.Count -gt 0) {
    if ($env:SDD_DOMAIN_ENFORCE -eq 'error') {
        Write-Host "check-domain-conformance FAILED ($($findings.Count) finding(s)):"
        $findings | ForEach-Object { Write-Host " - $_" }
        exit 1
    }
    Write-Host "check-domain-conformance WARN ($($findings.Count) finding(s)):"
    $findings | ForEach-Object { Write-Host " - $_" }
    Write-Host "Warn-phase: findings do not block; record them in the quality-gate report. Set SDD_DOMAIN_ENFORCE=error to enforce."
    exit 0
}
Write-Host "check-domain-conformance passed."
exit 0
