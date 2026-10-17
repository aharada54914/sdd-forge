# Run every domain contract suite with the same pinned Pester version as CI.
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 4.10.1 -ErrorAction Stop
$result = Invoke-Pester -Script (Join-Path $PSScriptRoot 'sdd-domain') -PassThru
if ($result.FailedCount -gt 0 -or $result.SkippedCount -gt 0 -or
    $result.PendingCount -gt 0 -or $result.InconclusiveCount -gt 0) {
    exit 1
}
