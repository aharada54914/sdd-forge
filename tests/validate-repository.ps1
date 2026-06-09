$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$jsonFiles = @(
    ".agents/plugins/marketplace.json",
    ".claude-plugin/marketplace.json",
    "plugins/sdd-bootstrap/.codex-plugin/plugin.json",
    "plugins/sdd-bootstrap/.claude-plugin/plugin.json",
    "plugins/sdd-quality-loop/.codex-plugin/plugin.json",
    "plugins/sdd-quality-loop/.claude-plugin/plugin.json"
)

foreach ($relativePath in $jsonFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path $path)) {
        throw "Missing required file: $relativePath"
    }
    Get-Content -Raw $path | ConvertFrom-Json | Out-Null
}

$codexMarketplace = Get-Content -Raw (Join-Path $repositoryRoot ".agents/plugins/marketplace.json") | ConvertFrom-Json
$claudeMarketplace = Get-Content -Raw (Join-Path $repositoryRoot ".claude-plugin/marketplace.json") | ConvertFrom-Json
$expectedNames = @("sdd-bootstrap", "sdd-quality-loop")

foreach ($name in $expectedNames) {
    if ($name -notin $codexMarketplace.plugins.name) {
        throw "Codex marketplace does not contain $name."
    }
    if ($name -notin $claudeMarketplace.plugins.name) {
        throw "Claude marketplace does not contain $name."
    }

    $pluginRoot = Join-Path $repositoryRoot "plugins/$name"
    $codexManifest = Get-Content -Raw (Join-Path $pluginRoot ".codex-plugin/plugin.json") | ConvertFrom-Json
    $claudeManifest = Get-Content -Raw (Join-Path $pluginRoot ".claude-plugin/plugin.json") | ConvertFrom-Json
    if ($codexManifest.name -ne $name -or $claudeManifest.name -ne $name) {
        throw "Plugin directory and manifest names differ for $name."
    }
    if (-not (Test-Path (Join-Path $pluginRoot "skills"))) {
        throw "Plugin has no skills directory: $name"
    }
}

Write-Host "Repository validation passed."
