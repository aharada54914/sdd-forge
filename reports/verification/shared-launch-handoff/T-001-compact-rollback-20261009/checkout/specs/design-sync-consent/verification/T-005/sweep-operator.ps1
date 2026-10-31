# T-005 case-sensitivity sweep -- operator layer, .ps1 side.
# Get-SectionBetween / Get-FirstLineIndex / Get-LinesOrEmpty bodies copied
# VERBATIM from tests/design-system-contract.tests.ps1:207-214, 249-266,
# 284-289 (not modified).
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-LinesOrEmpty([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        return @(Get-Content -Encoding Utf8 -LiteralPath $path -ErrorAction Stop)
    } catch {
        return @()
    }
}

function Get-SectionBetween([string[]]$lines, [string]$startPattern, [string]$endPattern) {
    $result = New-Object System.Collections.Generic.List[string]
    $flag = $false
    foreach ($line in $lines) {
        if (-not $flag) {
            if ($line -match $startPattern) {
                $flag = $true
                $result.Add($line)
            }
            continue
        }
        if (($line -match $endPattern) -and ($line -notmatch $startPattern)) {
            break
        }
        $result.Add($line)
    }
    return $result.ToArray()
}

function Get-FirstLineIndex([string[]]$lines, [string]$pattern) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) { return $i }
    }
    return -1
}

Write-Host "=== Get-SectionBetween() (.ps1, plain -match operator) case-sensitivity ==="
Write-Host "--- mis-cased heading '## loop' against pattern '^## Loop$' (must be EMPTY if parity with .sh held) ---"
$miscasedLines = Get-LinesOrEmpty "fixture-miscased-loop-heading.md"
$sectionA = Get-SectionBetween $miscasedLines '^## Loop$' '^## '
Write-Host ("count=" + $sectionA.Count)
if ($sectionA.Count -eq 0) {
    Write-Host "EMPTY (would be correct: case-sensitive, no match)"
} else {
    Write-Host "NON-EMPTY -- DIVERGENCE: .ps1 -match is case-INSENSITIVE, matched '## loop' where .sh's awk ~ (case-sensitive) would not"
    $sectionA | ForEach-Object { Write-Host "  > $_" }
}

Write-Host "--- correctly-cased heading '## Loop' against pattern '^## Loop$' (must be NON-EMPTY) ---"
$correctLines = Get-LinesOrEmpty "fixture-correctcased-loop-heading.md"
$sectionB = Get-SectionBetween $correctLines '^## Loop$' '^## '
Write-Host ("count=" + $sectionB.Count)
if ($sectionB.Count -gt 0) { Write-Host "NON-EMPTY (correct: match found)" } else { Write-Host "EMPTY (unexpected)" }

Write-Host ""
Write-Host "=== TEST-037 anchor find, Get-FirstLineIndex w/ plain -match (.ps1 side) ==="
Write-Host "--- mis-cased anchor 'Design-Sync-Loop``' against pattern 'design-sync-loop``' (must be NOT FOUND if parity with .sh held) ---"
$miscasedAnchorLines = Get-LinesOrEmpty "fixture-miscased-changelog-anchor.md"
$idxA = Get-FirstLineIndex $miscasedAnchorLines 'design-sync-loop`'
if ($idxA -lt 0) {
    Write-Host "NOT FOUND (would be correct: case-sensitive)"
} else {
    Write-Host ("FOUND at index " + $idxA + " -- DIVERGENCE: .ps1 -match is case-INSENSITIVE, matched 'Design-Sync-Loop``' where .sh's plain grep (case-sensitive, no -i) would not")
}

Write-Host "--- correctly-cased anchor 'design-sync-loop``' (must be FOUND) ---"
$correctAnchorLines = Get-LinesOrEmpty "fixture-correctcased-changelog-anchor.md"
$idxB = Get-FirstLineIndex $correctAnchorLines 'design-sync-loop`'
if ($idxB -ge 0) { Write-Host ("FOUND at index " + $idxB + " (correct)") } else { Write-Host "NOT FOUND (unexpected)" }
