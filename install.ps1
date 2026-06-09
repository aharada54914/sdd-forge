[CmdletBinding()]
param(
    [string]$Repository = "aharada54914/sdd-plugins-windows-installer",
    [string]$Ref = "main",
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "sdd-plugins"),
    [ValidateSet("All", "Codex", "Claude", "FilesOnly")]
    [string]$Target = "All",
    [switch]$SkipPluginInstall,
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
        Invoke-PluginCommand "codex" @("plugin", "add", "sdd-bootstrap@sdd-plugins")
        Invoke-PluginCommand "codex" @("plugin", "add", "sdd-quality-loop@sdd-plugins")
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
        Invoke-PluginCommand "claude" @("plugin", "install", "sdd-bootstrap@sdd-plugins", "--scope", "user")
        Invoke-PluginCommand "claude" @("plugin", "install", "sdd-quality-loop@sdd-plugins", "--scope", "user")
    }
}

$temporaryRoot = $null
$backupRoot = $null
$stagingRoot = $null
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
        "plugins/sdd-quality-loop/.codex-plugin/plugin.json"
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

    if (Test-Path $InstallRoot) {
        $backupRoot = Join-Path $installParent ("sdd-plugins-backup-" + [guid]::NewGuid())
        Move-Item -Path $InstallRoot -Destination $backupRoot
    }
    Move-Item -Path $stagingRoot -Destination $InstallRoot
    $stagingRoot = $null

    $resolvedInstallRoot = (Resolve-Path $InstallRoot).Path
    if ($Target -in @("All", "Codex")) {
        Install-CodexPlugins $resolvedInstallRoot
    }
    if ($Target -in @("All", "Claude")) {
        Install-ClaudePlugins $resolvedInstallRoot
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
