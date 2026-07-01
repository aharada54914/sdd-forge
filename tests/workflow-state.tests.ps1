$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Checker = Join-Path $Root "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1"

if (-not (Test-Path -LiteralPath $Checker -PathType Leaf)) {
    throw "not ok: workflow-state PowerShell adapter is missing"
}

& $Checker --registry (Join-Path $Root "specs/workflow-state-registry.json")
if ($LASTEXITCODE -ne 0) {
    throw "not ok: canonical repository workflow state failed"
}

$bad = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-state-" + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $bad "specs") | Out-Null
    Set-Content -LiteralPath (Join-Path $bad "specs/workflow-state-registry.json") -Value "{bad json" -NoNewline
    $output = & pwsh -NoProfile -File $Checker --registry (Join-Path $bad "specs/workflow-state-registry.json") 2>&1
    if ($LASTEXITCODE -eq 0 -or ($output -join "`n") -notmatch ": registry-malformed:") {
        throw "not ok: malformed registry did not fail closed"
    }
} finally {
    Remove-Item -LiteralPath $bad -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "ok: PowerShell workflow-state validation fixtures passed"
