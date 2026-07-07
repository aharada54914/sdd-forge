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
    [switch]$SkipAgentUninstall,
    [ValidateSet("sdd-forge-mcp", "local-env-mcp", "ci-mcp")]
    [string[]]$Mcp = @("sdd-forge-mcp", "local-env-mcp", "ci-mcp"),
    [switch]$SkipMcpUninstall
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
# MCP: unregister from Claude/Codex and remove the placed payload
# (mirror install.ps1's placement/registration split; all best-effort)
# ---------------------------------------------------------------------------
function Unregister-ClaudeMcp {
    if ($SkipMcpUninstall) { return }
    if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
        Write-Warning "Claude Code CLI was not found. Claude MCP unregistration was skipped."
        return
    }
    foreach ($name in $Mcp) {
        Invoke-BestEffortPluginCommand "claude" @("mcp", "remove", $name)
    }
}

function Unregister-CodexMcp {
    if ($SkipMcpUninstall) { return }
    $codexHome = if ($env:SDD_CODEX_HOME) { $env:SDD_CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex" }
    $configToml = Join-Path $codexHome "config.toml"
    if (-not (Test-Path $configToml)) { return }
    foreach ($name in $Mcp) {
        $markerBegin = "# >>> $name (managed by sdd-forge installer; do not edit by hand) >>>"
        $markerEnd = "# <<< $name <<<"
        $existingLines = @(Get-Content -Path $configToml)
        $filtered = [System.Collections.Generic.List[string]]::new()
        $skip = $false
        foreach ($line in $existingLines) {
            if ($line -eq $markerBegin) { $skip = $true; continue }
            if ($line -eq $markerEnd) { $skip = $false; continue }
            if (-not $skip) { $filtered.Add($line) }
        }
        Set-Content -Path $configToml -Value $filtered
    }
}

function Remove-McpPayload {
    if ($SkipMcpUninstall) { return }
    if ($KeepFiles) { return }
    foreach ($name in $Mcp) {
        $payloadDir = Join-Path (Join-Path $InstallRoot "mcp") $name
        if (Test-Path $payloadDir) { Remove-Item -Path $payloadDir -Recurse -Force }
    }
}

# Tracks whether the "Node not found" notice has been printed so it appears at
# most once across the Cursor and VS Code unregistration attempts.
$script:McpJsonNodeNoticePrinted = $false

function Test-McpJsonNodeAvailable {
    # Returns $true if `node` is on PATH; otherwise prints a one-time notice that
    # IDE (Cursor / VS Code) registrations could not be removed and returns
    # $false. The uninstaller must not hard-require Node: the payload / Claude /
    # Codex removals still run without it.
    if (Get-Command "node" -ErrorAction SilentlyContinue) { return $true }
    if (-not $script:McpJsonNodeNoticePrinted) {
        Write-Warning "Node.js was not found in PATH. Cursor / VS Code MCP registrations could not be removed (edit ~/.cursor/mcp.json and the VS Code user mcp.json by hand to remove the sdd-forge-mcp / local-env-mcp / ci-mcp keys). Other uninstall steps continue."
        $script:McpJsonNodeNoticePrinted = $true
    }
    return $false
}

function Remove-McpJsonKeys {
    # Shared idempotent JSON key removal for IDE client MCP configs (ADR-0005),
    # the inverse of install.ps1's Update-McpJson. Deletes ONLY <TopKey>.<name>
    # for every selected MCP, preserving all other entries and unknown top-level
    # keys. To guarantee byte-parity with uninstall.sh, the JSON handling is done
    # by the SAME Node one-liner uninstall.sh uses. Fail-safes (security-spec
    # B3): a present-but-invalid JSON file is never overwritten (error notice,
    # uninstaller continues with other clients); an absent file is a silent skip.
    param(
        [Parameter(Mandatory)][string]$ClientLabel,
        [Parameter(Mandatory)][string]$ConfigFile,
        [Parameter(Mandatory)][string]$TopKey
    )
    # Absent file: nothing was ever registered here — silent skip.
    if (-not (Test-Path $ConfigFile)) { return }

    $nodeScript = @'
const fs = require("fs");
const [file, topKey, ...names] = process.argv.slice(1);
let text = "";
try { text = fs.readFileSync(file, "utf8"); } catch (err) { process.exit(0); }
if (text.trim() === "") process.exit(0);
let root;
try { root = JSON.parse(text); } catch (err) { process.exit(3); }
if (root === null || typeof root !== "object" || Array.isArray(root)) process.exit(3);
const section = root[topKey];
if (section === undefined) process.exit(0);
if (section === null || typeof section !== "object" || Array.isArray(section)) process.exit(3);
for (const name of names) {
  if (Object.prototype.hasOwnProperty.call(section, name)) delete section[name];
}
const out = JSON.stringify(root, null, 2) + "\n";
const tmp = file + ".sdd-forge.tmp";
fs.writeFileSync(tmp, out);
fs.renameSync(tmp, file);
'@

    & node -e $nodeScript $ConfigFile $TopKey @($Mcp)
    $rc = $LASTEXITCODE
    if ($rc -eq 3) {
        Write-Error "$ConfigFile contains invalid JSON. $ClientLabel MCP unregistration was skipped and the file was left unmodified. Fix or remove the file manually." -ErrorAction Continue
        return
    }
    if ($rc -ne 0) {
        Write-Warning "Failed to update $ConfigFile. $ClientLabel MCP unregistration was skipped."
        return
    }
}

function Unregister-CursorMcp {
    # Removes only mcpServers.<name> from ~/.cursor/mcp.json for each selected
    # MCP. An absent ~/.cursor directory means Cursor is not installed: skip with
    # a notice and never create anything. Override via SDD_CURSOR_DIR.
    if ($SkipMcpUninstall) { return }
    $cursorDir = if ($env:SDD_CURSOR_DIR) { $env:SDD_CURSOR_DIR } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) ".cursor" }
    if (-not (Test-Path $cursorDir)) {
        Write-Warning "$cursorDir was not found. Cursor MCP unregistration was skipped (Cursor does not appear to be installed)."
        return
    }
    if (-not (Test-McpJsonNodeAvailable)) { return }
    Remove-McpJsonKeys -ClientLabel "Cursor" -ConfigFile (Join-Path $cursorDir "mcp.json") -TopKey "mcpServers"
}

function Unregister-VSCodeMcp {
    # Removes only servers.<name> from the VS Code user-profile mcp.json for each
    # selected MCP (Windows %APPDATA%\Code\User, macOS
    # ~/Library/Application Support/Code/User, Linux ~/.config/Code/User). An
    # absent user directory means VS Code is not installed: skip with a notice
    # and never create anything. Override via SDD_VSCODE_USER_DIR.
    if ($SkipMcpUninstall) { return }
    $onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) -and $IsWindows)
    $onMac = (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) -and $IsMacOS
    if ($env:SDD_VSCODE_USER_DIR) {
        $vscodeUserDir = $env:SDD_VSCODE_USER_DIR
    }
    elseif ($onWindows) {
        $vscodeUserDir = Join-Path (Join-Path $env:APPDATA "Code") "User"
    }
    elseif ($onMac) {
        $vscodeUserDir = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Library/Application Support/Code/User"
    }
    else {
        $vscodeUserDir = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".config/Code/User"
    }
    if (-not (Test-Path $vscodeUserDir)) {
        Write-Warning "$vscodeUserDir was not found. VS Code MCP unregistration was skipped (VS Code does not appear to be installed)."
        return
    }
    if (-not (Test-McpJsonNodeAvailable)) { return }
    Remove-McpJsonKeys -ClientLabel "VS Code" -ConfigFile (Join-Path $vscodeUserDir "mcp.json") -TopKey "servers"
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
    Unregister-CodexMcp
}
if ($Target -in @("All", "Claude")) {
    Uninstall-ClaudePlugin
    Unregister-ClaudeMcp
}
if ($Target -in @("All", "Copilot")) {
    Uninstall-CopilotPlugin
}
# IDE-client MCP unregistration mirrors install.ps1's registration scoping:
# Cursor has no dedicated -Target value, so it participates in All only; VS Code
# consumes the MCP config through Copilot, so it participates in All and Copilot.
if ($Target -eq "All") {
    Unregister-CursorMcp
}
if ($Target -in @("All", "Copilot")) {
    Unregister-VSCodeMcp
}

# ---------------------------------------------------------------------------
# Remove installed files
# ---------------------------------------------------------------------------
# MCP payload removal mirrors -KeepFiles semantics for the rest of the
# install root; when the whole root is removed below, this is redundant but
# harmless (already-removed directories are treated as success).
Remove-McpPayload

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
