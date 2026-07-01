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
#   - removes the Codex agent role files this project installed
#   - removes the installed files at the install root (unless -KeepFiles)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    throw "InstallRoot must not be empty."
}

$allPlugins = @("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop")
# Role files this project installs into ~/.codex/agents. Used as a fallback when
# the install root (the manifest source) is no longer present.
$shippedAgents = @("sdd-investigator.toml", "sdd-evaluator.toml", "sdd-panelist-gpt.toml", "sdd-panelist-gemini.toml")

# A full uninstall selects every known plugin. Only then is it safe to remove the
# marketplace, since removing it also uninstalls any plugins still registered.
$isFullUninstall = -not ($allPlugins | Where-Object { $Plugins -notcontains $_ })

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

function Remove-MarketplaceIfFull {
    param([Parameter(Mandatory)][string]$Command)
    if ($isFullUninstall) {
        Invoke-BestEffortPluginCommand $Command @("plugin", "marketplace", "remove", $MarketplaceName)
    }
}

function Uninstall-CodexPlugin {
    # Honor -SkipPluginUninstall before probing the CLI so a removed CLI does not
    # block the agent/file cleanup paths.
    if ($SkipPluginUninstall) { return }
    if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Codex") { throw "Codex CLI was not found in PATH." }
        Write-Warning "Codex CLI was not found. Codex unregistration was skipped."
        return
    }
    foreach ($plugin in $Plugins) {
        # Codex plugin state is keyed by the qualified plugin@marketplace id.
        Invoke-BestEffortPluginCommand "codex" @("plugin", "remove", "$plugin@$MarketplaceName")
    }
    Remove-MarketplaceIfFull "codex"
}

function Uninstall-ClaudePlugin {
    if ($SkipPluginUninstall) { return }
    if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Claude") { throw "Claude Code CLI was not found in PATH." }
        Write-Warning "Claude Code CLI was not found. Claude unregistration was skipped."
        return
    }
    foreach ($plugin in $Plugins) {
        Invoke-BestEffortPluginCommand "claude" @("plugin", "uninstall", "$plugin@$MarketplaceName")
    }
    Remove-MarketplaceIfFull "claude"
}

function Uninstall-CopilotPlugin {
    if ($SkipPluginUninstall) { return }
    if (-not (Get-Command "copilot" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Copilot") { throw "Copilot CLI was not found in PATH." }
        Write-Warning "Copilot CLI was not found. Copilot unregistration was skipped."
        return
    }
    foreach ($plugin in $Plugins) {
        Invoke-BestEffortPluginCommand "copilot" @("plugin", "uninstall", "$plugin@$MarketplaceName")
    }
    Remove-MarketplaceIfFull "copilot"
}

function Remove-CodexAgent {
    # Override destination via SDD_CODEX_HOME environment variable (for testing; default is user profile).
    $codexHome = if ($env:SDD_CODEX_HOME) { $env:SDD_CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex" }
    $agentDestDir = Join-Path $codexHome "agents"
    if (-not (Test-Path $agentDestDir)) { return }
    # Remove only the role files this project installed. Prefer the manifest in
    # the install root (the source install copied from); fall back to the known
    # shipped names if the install root is already gone. A user's own role files
    # — including any sdd-* they authored themselves — are never touched.
    $shipped = @()
    $srcAgents = Join-Path (Join-Path $InstallRoot ".codex") "agents"
    if (Test-Path $srcAgents) {
        $shipped = @(Get-ChildItem -Path $srcAgents -Filter "sdd-*.toml" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }
    if ($shipped.Count -eq 0) { $shipped = $shippedAgents }
    foreach ($name in $shipped) {
        $target = Join-Path $agentDestDir $name
        if (Test-Path $target) { Remove-Item -Path $target -Force }
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
# Refuse the home directory or its parent. A path like "$HOME\.." normalizes to
# the parent via GetFullPath, so guard against it explicitly.
$userProfile = [System.IO.Path]::GetFullPath([Environment]::GetFolderPath("UserProfile"))
$userProfileParent = [System.IO.Path]::GetDirectoryName($userProfile.TrimEnd("\", "/"))
if ($InstallRoot.TrimEnd("\", "/") -eq $userProfile.TrimEnd("\", "/")) {
    throw "refusing to remove the home directory: $InstallRoot"
}
if ($userProfileParent -and ($InstallRoot.TrimEnd("\", "/") -eq $userProfileParent.TrimEnd("\", "/"))) {
    throw "refusing to remove the parent of the home directory: $InstallRoot"
}

# ---------------------------------------------------------------------------
# Unregister from CLI tools
# ---------------------------------------------------------------------------
if ($Target -in @("All", "Codex")) {
    Uninstall-CodexPlugin
    if (-not $SkipAgentUninstall) {
        Remove-CodexAgent
    }
}
if ($Target -in @("All", "Claude")) {
    Uninstall-ClaudePlugin
}
if ($Target -in @("All", "Copilot")) {
    Uninstall-CopilotPlugin
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
