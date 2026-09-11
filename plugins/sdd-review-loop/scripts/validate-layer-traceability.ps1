param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$RequirementsPath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).LinkType) {
    throw "traceability input is missing or substituted: $Path"
}
if (-not (Test-Path -LiteralPath $RequirementsPath -PathType Leaf) -or
    (Get-Item -LiteralPath $RequirementsPath).LinkType) {
    throw "requirements input is missing or substituted: $RequirementsPath"
}
$requiredIds = @(
    [regex]::Matches([IO.File]::ReadAllText($RequirementsPath), '\bREQ-\d{3}\b') |
        ForEach-Object Value | Sort-Object -Unique
)
if ($requiredIds.Count -eq 0) { throw 'no requirement ids found in requirements.md' }
$anchorPattern = '^(?:(?:ux|frontend|infra|security)-spec\.md#[a-z0-9][a-z0-9-]*)(?:\s*;\s*(?:ux|frontend|infra|security)-spec\.md#[a-z0-9][a-z0-9-]*)*$'
$exclusionPattern = '^N/A — cross-layer only:\s*\S.*$'
$tracedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$inTraceabilityTable = $false
$layerSpecIndex = -1
foreach ($rawLine in Get-Content -LiteralPath $Path) {
    $line = $rawLine.TrimEnd()
    if ($line.StartsWith('## ', [StringComparison]::Ordinal) -or [string]::IsNullOrWhiteSpace($line)) {
        $inTraceabilityTable = $false
        $layerSpecIndex = -1
        continue
    }
    if (-not $line.StartsWith('|', [StringComparison]::Ordinal)) { continue }

    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if (-not $inTraceabilityTable) {
        $requirementIndex = [Array]::IndexOf($cells, 'Requirement')
        $candidateLayerSpecIndex = [Array]::IndexOf($cells, 'Layer Spec')
        if ($requirementIndex -eq 0 -and $candidateLayerSpecIndex -ge 0) {
            $inTraceabilityTable = $true
            $layerSpecIndex = $candidateLayerSpecIndex
        }
        continue
    }

    if ($cells.Count -gt 0 -and $cells[0] -cmatch '^REQ-\d{3}$') {
        [void]$tracedIds.Add($cells[0])
        $value = if ($cells.Count -gt $layerSpecIndex) { $cells[$layerSpecIndex] } else { '' }
        if ($value -cnotmatch $anchorPattern -and $value -cnotmatch $exclusionPattern) {
            throw "invalid Layer Spec for $($cells[0]): $value"
        }
    }
}
if ($tracedIds.Count -eq 0) { throw 'no requirement rows found in traceability.md' }
$missing = @($requiredIds | Where-Object { -not $tracedIds.Contains($_) })
if ($missing.Count -gt 0) {
    throw "requirements missing Layer Spec coverage: $($missing -join ', ')"
}
