# Deterministic gate: detect placeholder, stub, and generic-fallback
# implementations that agents sometimes ship to fake completion.
# Usage: check-placeholders.ps1 <file-or-dir> [<file-or-dir> ...]
# Pass changed production files (not test fixtures). Exit 1 when found.
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Paths
)
$ErrorActionPreference = "Stop"

# Marker keywords are matched CASE-SENSITIVELY: real stub markers follow the
# ALL-CAPS convention (TODO:, FIXME, PLACEHOLDER), while lowercase occurrences
# ("placeholders", "`todo`", "check-placeholders") are ordinary prose in docs
# and skill files -- matching them case-insensitively produced false positives
# that blocked quality gates (RT-20260706-001). NotImplemented keeps its exact
# mixed case (Python/C# exception names). Multi-word phrases stay
# case-insensitive: they are unambiguous in any casing.
$patternCs = 'TODO|FIXME|HACK\b|NotImplemented|PLACEHOLDER|TODO_REPLACE_WITH_PROJECT_COMMANDS'
$patternCi = 'not[ _-]implemented|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)'
$findings = @()

foreach ($path in $Paths) {
    if (-not (Test-Path $path)) {
        # issue #127 parity: a missing scan target must fail closed, not be
        # silently skipped. Skipping reported a false pass when the caller
        # passed a bad or moved path -- the PowerShell twin of the .sh grep
        # exit-2 fail-open bug.
        [Console]::Error.WriteLine("check-placeholders: FATAL path not found: $path")
        [Console]::Error.WriteLine("check-placeholders: cannot scan a nonexistent path; failing closed instead of reporting a false pass.")
        exit 2
    }
    $files = if ((Get-Item $path).PSIsContainer) {
        Get-ChildItem $path -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|bin|obj|dist)[\\/]' }
    } else {
        Get-Item $path
    }
    foreach ($file in $files) {
        $matched = @()
        # Do NOT swallow read errors: an unreadable file previously slipped
        # through -ErrorAction SilentlyContinue and was reported clean. Surface
        # it and fail closed, mirroring the .sh grep exit>=2 handling.
        try {
            $matched += Select-String -Path $file.FullName -Pattern $patternCs -CaseSensitive -AllMatches -ErrorAction Stop
            $matched += Select-String -Path $file.FullName -Pattern $patternCi -AllMatches -ErrorAction Stop
        } catch {
            [Console]::Error.WriteLine("check-placeholders: FATAL could not scan file: $($file.FullName)")
            [Console]::Error.WriteLine("check-placeholders: $($_.Exception.Message)")
            exit 2
        }
        $matched = $matched | Sort-Object Path, LineNumber -Unique
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
