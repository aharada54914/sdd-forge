# Deterministic gate: detect placeholder, stub, and generic-fallback
# implementations that agents sometimes ship to fake completion.
# Usage: check-placeholders.ps1 <file-or-dir> [<file-or-dir> ...]
# Pass changed production files (not test fixtures). Exit 1 when found.
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Paths
)
$ErrorActionPreference = "Stop"

$pattern = 'TODO|FIXME|HACK\b|NotImplemented|not[ _-]implemented|PLACEHOLDER|placeholder|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)'
$findings = @()

foreach ($path in $Paths) {
    if (-not (Test-Path $path)) {
        Write-Host "check-placeholders: path not found, skipping: $path"
        continue
    }
    $files = if ((Get-Item $path).PSIsContainer) {
        Get-ChildItem $path -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|bin|obj|dist)[\\/]' }
    } else {
        Get-Item $path
    }
    foreach ($file in $files) {
        $matched = Select-String -Path $file.FullName -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue
        foreach ($m in $matched) {
            $findings += "$($m.Path):$($m.LineNumber): $($m.Line.Trim())"
        }
    }
}

if ($findings.Count -gt 0) {
    Write-Host "Placeholder scan FAILED ($($findings.Count) finding(s)):"
    $findings | ForEach-Object { Write-Host " - $_" }
    Write-Host "Each finding must be implemented properly, or explicitly accepted by a human in the quality-gate report."
    exit 1
}
Write-Host "Placeholder scan passed."
exit 0
