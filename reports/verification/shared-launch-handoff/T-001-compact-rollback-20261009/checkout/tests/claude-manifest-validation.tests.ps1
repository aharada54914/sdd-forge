$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($null -eq $claude) {
    throw "Claude Code CLI is required for manifest validation."
}

$pluginRoots = Get-ChildItem -Path (Join-Path $repositoryRoot "plugins") -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName ".claude-plugin/plugin.json") } |
    Sort-Object Name
if ($pluginRoots.Count -eq 0) {
    throw "No Claude plugin manifests found."
}

foreach ($pluginRoot in $pluginRoots) {
    & $claude.Source plugin validate $pluginRoot.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Claude manifest validation failed for $($pluginRoot.Name)."
    }
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-invalid-claude-manifest-" + [guid]::NewGuid())
try {
    Copy-Item -Path (Join-Path $repositoryRoot "plugins/sdd-bootstrap") -Destination $fixtureRoot -Recurse
    $manifestPath = Join-Path $fixtureRoot ".claude-plugin/plugin.json"
    $manifest = Get-Content -Raw -Encoding Utf8 $manifestPath | ConvertFrom-Json
    $manifest | Add-Member -NotePropertyName agents -NotePropertyValue @("./agents/")
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Encoding Utf8 -NoNewline $manifestPath

    & $claude.Source plugin validate $fixtureRoot
    if ($LASTEXITCODE -eq 0) {
        throw "Invalid Claude manifest fixture unexpectedly validated."
    }
    Write-Host "ok: invalid Claude manifest fixture is rejected"
} finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "ok: Claude $(& $claude.Source --version) validated $($pluginRoots.Count) shipped plugin manifests"
