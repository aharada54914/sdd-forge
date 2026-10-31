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

# WFI-021: two independently broken features are BOTH reported in one run
# (cross-feature accumulation), while a feature's own chain still stops at
# its first diagnostic (within-feature short-circuit).
$acc = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-state-acc-" + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $acc "specs/feat-a") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $acc "specs/feat-b") | Out-Null
    Set-Content -LiteralPath (Join-Path $acc "specs/feat-a/acceptance-tests.md") -Value "x"
    Set-Content -LiteralPath (Join-Path $acc "specs/feat-b/requirements.md") -Value "Spec-Review-Status: Bogus"
    Set-Content -LiteralPath (Join-Path $acc "specs/feat-b/design.md") -Value "Impl-Review-Status: Pending"
    Set-Content -LiteralPath (Join-Path $acc "specs/feat-b/acceptance-tests.md") -Value "x"
    $real = Get-Content -LiteralPath (Join-Path $Root "specs/workflow-state-registry.json") -Raw | ConvertFrom-Json
    $registry = [ordered]@{
        schema_version = $real.schema_version
        migration_baseline_commit = $real.migration_baseline_commit
        entries = @(
            [ordered]@{ feature = "feat-a"; profile = "full" },
            [ordered]@{ feature = "feat-b"; profile = "full" }
        )
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $acc "specs/workflow-state-registry.json") -Value $registry
    $accOutput = @(& pwsh -NoProfile -File $Checker --registry (Join-Path $acc "specs/workflow-state-registry.json") 2>&1)
    $joined = ($accOutput | ForEach-Object { [string]$_ }) -join "`n"
    if ($LASTEXITCODE -eq 0) { throw "not ok: WFI-021 accumulate fixture unexpectedly passed" }
    if ($joined -notmatch "workflow-state: feat-a: stage-input:") {
        throw "not ok: WFI-021 first feature diagnostic missing: $joined"
    }
    if ($joined -notmatch "workflow-state: feat-b: stage-status:") {
        throw "not ok: WFI-021 second feature diagnostic missing (exit-at-first regression): $joined"
    }
    if (@($accOutput | Where-Object { [string]$_ -match "^workflow-state: feat-a:" }).Count -ne 1) {
        throw "not ok: WFI-021 within-feature short-circuit lost: $joined"
    }
} finally {
    Remove-Item -LiteralPath $acc -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "ok: PowerShell workflow-state validation fixtures passed"
