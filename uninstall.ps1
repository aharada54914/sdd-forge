[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "sdd-plugins"),
    [string]$MarketplaceName = "sdd-plugins",
    [ValidateSet("All", "Codex", "Claude", "Copilot", "FilesOnly")]
    [string]$Target = "All",
    [ValidateSet("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop")]
    [string[]]$Plugins = @("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop"),
    [switch]$KeepFiles,
    [switch]$SkipPluginUninstall,
    [switch]$SkipAgentUninstall
)

# uninstall.ps1 — SDD plugins uninstaller for Windows.
# Mirrors uninstall.sh behavior exactly. Reverses install.ps1:
#   - unregisters plugins and the marketplace from Codex / Claude / Copilot
#   - removes installed Codex agent role files (~/.codex/agents/sdd-*.toml)
#   - removes the installed files at the install root (unless -KeepFiles)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Best-effort plugin command. A non-zero exit (e.g. "plugin not installed") is
# reported as a warning but never aborts the uninstall — re-running the
# uninstaller must converge on a clean state.
function Invoke-BestEffortPluginCommand {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    & $Command @Arguments 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "'$Command $($Arguments -join ' ')' exited with code $LASTEXITCODE (already removed?). Continuing."
    }
}

function Uninstall-CodexPlugins {
    if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Codex") {
            throw "Codex CLI was not found in PATH."
        }
        Write-Warning "Codex CLI was not found. Codex unregistration was skipped."
        return
    }
    if (-not $SkipPluginUninstall) {
        foreach ($plugin in $Plugins) {
            Invoke-BestEffortPluginCommand "codex" @("plugin", "remove", "$plugin")
        }
        Invoke-BestEffortPluginCommand "codex" @("plugin", "marketplace", "remove", $MarketplaceName)
    }
}

function Uninstall-ClaudePlugins {
    if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Claude") {
            throw "Claude Code CLI was not found in PATH."
        }
        Write-Warning "Claude Code CLI was not found. Claude unregistration was skipped."
        return
    }
    if (-not $SkipPluginUninstall) {
        foreach ($plugin in $Plugins) {
            Invoke-BestEffortPluginCommand "claude" @("plugin", "uninstall", "$plugin@$MarketplaceName")
        }
        Invoke-BestEffortPluginCommand "claude" @("plugin", "marketplace", "remove", $MarketplaceName)
    }
}

function Uninstall-CopilotPlugins {
    if (-not (Get-Command "copilot" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Copilot") {
            throw "Copilot CLI was not found in PATH."
        }
        Write-Warning "Copilot CLI was not found. Copilot unregistration was skipped."
        return
    }
    if (-not $SkipPluginUninstall) {
        foreach ($plugin in $Plugins) {
            Invoke-BestEffortPluginCommand "copilot" @("plugin", "uninstall", "$plugin@$MarketplaceName")
        }
        Invoke-BestEffortPluginCommand "copilot" @("plugin", "marketplace", "remove", $MarketplaceName)
    }
}

function Remove-CodexAgents {
    # Override destination via SDD_CODEX_HOME environment variable (for testing; default is user profile).
    $codexHome = if ($env:SDD_CODEX_HOME) { $env:SDD_CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex" }
    $agentDestDir = Join-Path $codexHome "agents"
    if (-not (Test-Path $agentDestDir)) {
        return
    }
    # Remove only the role files shipped by this project (sdd-*.toml), mirroring
    # the install glob. A user's own agent role files are never touched.
    foreach ($tomlFile in (Get-ChildItem -Path $agentDestDir -Filter "sdd-*.toml" -ErrorAction SilentlyContinue)) {
        Remove-Item -Path $tomlFile.FullName -Force
    }
}

# ---------------------------------------------------------------------------
# Resolve install root and safety checks (mirror install.ps1)
# ---------------------------------------------------------------------------
$InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
$installRootBoundary = [System.IO.Path]::GetPathRoot($InstallRoot)
if ($InstallRoot.TrimEnd("\", "/") -eq $installRootBoundary.TrimEnd("\", "/")) {
    throw "InstallRoot must not be a filesystem root: $InstallRoot"
}
$userProfile = [System.IO.Path]::GetFullPath([Environment]::GetFolderPath("UserProfile"))
if ($InstallRoot.TrimEnd("\", "/") -eq $userProfile.TrimEnd("\", "/")) {
    throw "refusing to remove the home directory: $InstallRoot"
}

# ---------------------------------------------------------------------------
# Unregister from CLI tools
# ---------------------------------------------------------------------------
if ($Target -in @("All", "Codex")) {
    Uninstall-CodexPlugins
    if (-not $SkipAgentUninstall) {
        Remove-CodexAgents
    }
}
if ($Target -in @("All", "Claude")) {
    Uninstall-ClaudePlugins
}
if ($Target -in @("All", "Copilot")) {
    Uninstall-CopilotPlugins
}

# ---------------------------------------------------------------------------
# Remove installed files
# ---------------------------------------------------------------------------
if ($KeepFiles) {
    Write-Host "Kept installed files at: $InstallRoot (-KeepFiles)."
}
elseif (Test-Path $InstallRoot) {
    Remove-Item -Path $InstallRoot -Recurse -Force
    Write-Host "Removed installed files at: $InstallRoot."
}
else {
    Write-Host "No installed files found at: $InstallRoot."
}

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "SDD plugins uninstalled."
if ($Target -eq "FilesOnly") {
    Write-Host "Plugin unregistration was skipped because Target=FilesOnly."
}
