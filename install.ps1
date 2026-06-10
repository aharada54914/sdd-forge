[CmdletBinding()]
param(
    [string]$Repository = "aharada54914/sdd-plugins-windows-installer",
    [string]$Ref = "main",
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "sdd-plugins"),
    [ValidateSet("All", "Codex", "Claude", "Copilot", "FilesOnly")]
    [string]$Target = "All",
    [ValidateSet("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop")]
    [string[]]$Plugins = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop"),
    [switch]$SkipPluginInstall,
    [switch]$SkipAgentInstall,
    [string]$SourceDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-PluginCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE."
    }
}

function Install-CodexPlugins {
    param([Parameter(Mandatory)][string]$MarketplaceRoot)

    if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Codex") {
            throw "Codex CLI was not found in PATH."
        }
        Write-Warning "Codex CLI was not found. Codex registration was skipped."
        return
    }

    Invoke-PluginCommand "codex" @("plugin", "marketplace", "add", $MarketplaceRoot)
    if (-not $SkipPluginInstall) {
        foreach ($plugin in $Plugins) {
            Invoke-PluginCommand "codex" @("plugin", "add", "$plugin@sdd-plugins")
        }
    }
}

function Install-CopilotPlugins {
    param([Parameter(Mandatory)][string]$MarketplaceRoot)

    if (-not (Get-Command "copilot" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Copilot") {
            throw "Copilot CLI was not found in PATH."
        }
        Write-Warning "Copilot CLI was not found. Copilot registration was skipped."
        return
    }

    Invoke-PluginCommand "copilot" @("plugin", "marketplace", "add", $MarketplaceRoot)
    if (-not $SkipPluginInstall) {
        foreach ($plugin in $Plugins) {
            Invoke-PluginCommand "copilot" @("plugin", "install", "$plugin@sdd-plugins")
        }
    }
}

function Install-ClaudePlugins {
    param([Parameter(Mandatory)][string]$MarketplaceRoot)

    if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Claude") {
            throw "Claude Code CLI was not found in PATH."
        }
        Write-Warning "Claude Code CLI was not found. Claude registration was skipped."
        return
    }

    Invoke-PluginCommand "claude" @("plugin", "marketplace", "add", $MarketplaceRoot, "--scope", "user")
    if (-not $SkipPluginInstall) {
        foreach ($plugin in $Plugins) {
            Invoke-PluginCommand "claude" @("plugin", "install", "$plugin@sdd-plugins", "--scope", "user")
        }
    }
}

function Install-CodexAgents {
    param([Parameter(Mandatory)][string]$InstallRootPath)

    $agentSourceDir = Join-Path (Join-Path $InstallRootPath ".codex") "agents"
    if (-not (Test-Path $agentSourceDir)) {
        Write-Warning "No .codex/agents directory found in install root. Codex agent install skipped."
        return
    }

    try {
        $agentDestDir = Join-Path (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex") "agents"
        if (-not (Test-Path $agentDestDir)) {
            New-Item -ItemType Directory -Path $agentDestDir -Force | Out-Null
        }
        foreach ($tomlFile in (Get-ChildItem -Path $agentSourceDir -Filter "sdd-*.toml")) {
            $destFile = Join-Path $agentDestDir $tomlFile.Name
            Copy-Item -Path $tomlFile.FullName -Destination $destFile -Force
        }
    }
    catch {
        Write-Warning "Codex agent install failed: $_"
    }
}

$temporaryRoot = $null
$backupRoot = $null
$stagingRoot = $null
$newInstallPlaced = $false
try {
    if ($SourceDirectory) {
        $sourceRoot = (Resolve-Path $SourceDirectory).Path
    }
    else {
        $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-plugins-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

        $archivePath = Join-Path $temporaryRoot "source.zip"
        $downloadUrl = "https://codeload.github.com/$Repository/zip/$Ref"
        Write-Host "Downloading $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
        Expand-Archive -Path $archivePath -DestinationPath $temporaryRoot -Force

        $sourceRoot = Get-ChildItem -Path $temporaryRoot -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName ".agents/plugins/marketplace.json") } |
            Select-Object -First 1 -ExpandProperty FullName
        if (-not $sourceRoot) {
            throw "The downloaded archive does not contain an SDD plugin marketplace."
        }
    }

    $requiredPaths = @(
        ".agents/plugins/marketplace.json",
        ".claude-plugin/marketplace.json",
        "plugins/sdd-bootstrap/.codex-plugin/plugin.json",
        "plugins/sdd-implementation/.codex-plugin/plugin.json",
        "plugins/sdd-quality-loop/.codex-plugin/plugin.json",
        "plugins/sdd-bootstrap/.plugin/plugin.json",
        "plugins/sdd-implementation/.plugin/plugin.json",
        "plugins/sdd-quality-loop/.plugin/plugin.json",
        ".codex/agents/sdd-investigator.toml"
    )
    foreach ($relativePath in $requiredPaths) {
        if (-not (Test-Path (Join-Path $sourceRoot $relativePath))) {
            throw "Required file is missing: $relativePath"
        }
    }

    $InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
    $installRootBoundary = [System.IO.Path]::GetPathRoot($InstallRoot)
    if ($InstallRoot.TrimEnd("\", "/") -eq $installRootBoundary.TrimEnd("\", "/")) {
        throw "InstallRoot must not be a filesystem root: $InstallRoot"
    }
    if ($InstallRoot.TrimEnd("\", "/") -eq ([System.IO.Path]::GetFullPath($sourceRoot)).TrimEnd("\", "/")) {
        throw "InstallRoot must differ from SourceDirectory."
    }

    $installParent = Split-Path -Parent $InstallRoot
    if (-not (Test-Path $installParent)) {
        New-Item -ItemType Directory -Path $installParent -Force | Out-Null
    }

    $stagingRoot = Join-Path $installParent ("sdd-plugins-staging-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $stagingRoot | Out-Null
    Copy-Item -Path (Join-Path $sourceRoot "*") -Destination $stagingRoot -Recurse -Force
    Copy-Item -Path (Join-Path $sourceRoot ".agents") -Destination $stagingRoot -Recurse -Force
    Copy-Item -Path (Join-Path $sourceRoot ".claude-plugin") -Destination $stagingRoot -Recurse -Force
    Copy-Item -Path (Join-Path $sourceRoot ".codex") -Destination $stagingRoot -Recurse -Force

    if (Test-Path $InstallRoot) {
        $backupRoot = Join-Path $installParent ("sdd-plugins-backup-" + [guid]::NewGuid())
        Move-Item -Path $InstallRoot -Destination $backupRoot
    }
    Move-Item -Path $stagingRoot -Destination $InstallRoot
    $stagingRoot = $null
    $newInstallPlaced = $true

    $resolvedInstallRoot = (Resolve-Path $InstallRoot).Path
    if ($Target -in @("All", "Codex")) {
        Install-CodexPlugins $resolvedInstallRoot
        if (-not $SkipAgentInstall -and (Get-Command "codex" -ErrorAction SilentlyContinue)) {
            Install-CodexAgents $resolvedInstallRoot
        }
    }
    if ($Target -in @("All", "Claude")) {
        Install-ClaudePlugins $resolvedInstallRoot
    }
    if ($Target -in @("All", "Copilot")) {
        Install-CopilotPlugins $resolvedInstallRoot
    }

    Write-Host ""
    Write-Host "SDD plugins installed at: $resolvedInstallRoot"
    if ($Target -eq "FilesOnly") {
        Write-Host "Plugin registration was skipped because Target=FilesOnly."
    }
    if ($backupRoot -and (Test-Path $backupRoot)) {
        Remove-Item -Path $backupRoot -Recurse -Force
        $backupRoot = $null
    }
}
catch {
    if ($backupRoot -and (Test-Path $backupRoot)) {
        if (Test-Path $InstallRoot) {
            Remove-Item -Path $InstallRoot -Recurse -Force
        }
        Move-Item -Path $backupRoot -Destination $InstallRoot
        $backupRoot = $null
    }
    elseif ($newInstallPlaced -and (Test-Path $InstallRoot)) {
        Remove-Item -Path $InstallRoot -Recurse -Force
    }
    throw
}
finally {
    if ($stagingRoot -and (Test-Path $stagingRoot)) {
        Remove-Item -Path $stagingRoot -Recurse -Force
    }
    if ($temporaryRoot -and (Test-Path $temporaryRoot)) {
        Remove-Item -Path $temporaryRoot -Recurse -Force
    }
}
