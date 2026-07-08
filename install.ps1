[CmdletBinding()]
param(
    [string]$Repository = "aharada54914/sdd-forge",
    [string]$Ref = "main",
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "sdd-plugins"),
    [ValidateSet("All", "Codex", "Claude", "Copilot", "FilesOnly")]
    [string]$Target = "All",
    [ValidateSet("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop")]
    [string[]]$Plugins = @("sdd-bootstrap", "sdd-ship"),
    [switch]$SkipPluginInstall,
    [switch]$SkipAgentInstall,
    [switch]$RequireClaude,
    [string]$SourceDirectory,
    [switch]$SkipMcp,
    [ValidateSet("sdd-forge-mcp", "local-env-mcp", "ci-mcp")]
    [string[]]$Mcp = @("sdd-forge-mcp", "local-env-mcp", "ci-mcp")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Resolve dependency closure to a fixed point. In particular, lite adds
# bootstrap, which then adds the internal review-loop plugin.
$autoIncluded = [System.Collections.Generic.List[string]]::new()
$dependenciesChanged = $true
while ($dependenciesChanged) {
    $dependenciesChanged = $false
    foreach ($plugin in @($Plugins)) {
        $dependencies = switch ($plugin) {
            "sdd-bootstrap" { @("sdd-review-loop"); break }
            "sdd-lite" { @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop"); break }
            "sdd-ship" { @("sdd-bootstrap", "sdd-review-loop", "sdd-implementation", "sdd-quality-loop", "sdd-lite"); break }
            default { @() }
        }
        foreach ($dependency in $dependencies) {
            if ($Plugins -notcontains $dependency) {
                $Plugins += $dependency
                $autoIncluded.Add($dependency)
                $dependenciesChanged = $true
            }
        }
    }
}
if ($autoIncluded.Count -gt 0) {
    Write-Warning "Dependency resolution auto-included: $($autoIncluded -join ', ')."
}

if ($PSVersionTable.PSEdition -eq 'Desktop') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

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

    $script:CodexRegistrationStatus = "requested"
    if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Codex") {
            throw "Codex CLI was not found in PATH."
        }
        $script:CodexRegistrationStatus = "skipped: Codex CLI was not found in PATH"
        Write-Warning "Codex CLI was not found. Codex registration was skipped."
        return
    }

    Invoke-PluginCommand "codex" @("plugin", "marketplace", "add", $MarketplaceRoot)
    if ($SkipPluginInstall) {
        $script:CodexRegistrationStatus = "marketplace registered; plugin install skipped"
        return
    }
    foreach ($plugin in $Plugins) {
        Invoke-PluginCommand "codex" @("plugin", "add", "$plugin@sdd-plugins")
    }
    $script:CodexRegistrationStatus = "registered"
}

function Install-CopilotPlugins {
    param([Parameter(Mandatory)][string]$MarketplaceRoot)

    $script:CopilotRegistrationStatus = "requested"
    if (-not (Get-Command "copilot" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Copilot") {
            throw "Copilot CLI was not found in PATH."
        }
        $script:CopilotRegistrationStatus = "skipped: Copilot CLI was not found in PATH"
        Write-Warning "Copilot CLI was not found. Copilot registration was skipped."
        return
    }

    Invoke-PluginCommand "copilot" @("plugin", "marketplace", "add", $MarketplaceRoot)
    if ($SkipPluginInstall) {
        $script:CopilotRegistrationStatus = "marketplace registered; plugin install skipped"
        return
    }
    foreach ($plugin in $Plugins) {
        Invoke-PluginCommand "copilot" @("plugin", "install", "$plugin@sdd-plugins")
    }
    $script:CopilotRegistrationStatus = "registered"
}

function Install-ClaudePlugins {
    param([Parameter(Mandatory)][string]$MarketplaceRoot)

    $script:ClaudeRegistrationStatus = "requested"
    if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
        if ($Target -eq "Claude" -or $RequireClaude) {
            throw "Claude Code CLI was not found in PATH. Install Claude Code, make sure 'claude' is on PATH, or rerun without -RequireClaude."
        }
        $script:ClaudeRegistrationStatus = "skipped: Claude Code CLI was not found in PATH"
        Write-Warning "Claude Code CLI was not found. Claude registration was skipped."
        return
    }

    # Validate before registration so an invalid selected manifest cannot leave
    # the marketplace registered as a successful Claude installation.
    foreach ($plugin in $Plugins) {
        Invoke-PluginCommand "claude" @("plugin", "validate", (Join-Path $MarketplaceRoot "plugins/$plugin"))
    }
    Invoke-PluginCommand "claude" @("plugin", "marketplace", "add", $MarketplaceRoot, "--scope", "user")
    if ($SkipPluginInstall) {
        $script:ClaudeRegistrationStatus = "marketplace registered; plugin install skipped"
        return
    }
    foreach ($plugin in $Plugins) {
        Invoke-PluginCommand "claude" @("plugin", "install", "$plugin@sdd-plugins", "--scope", "user")
    }
    $script:ClaudeRegistrationStatus = "registered"
}

function Install-CodexAgents {
    param([Parameter(Mandatory)][string]$InstallRootPath)

    $agentSourceDir = Join-Path (Join-Path $InstallRootPath ".codex") "agents"
    if (-not (Test-Path $agentSourceDir)) {
        Write-Warning "No .codex/agents directory found in install root. Codex agent install skipped."
        return
    }

    try {
        # Override destination via SDD_CODEX_HOME environment variable (for testing; default is user profile).
        $codexHome = if ($env:SDD_CODEX_HOME) { $env:SDD_CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex" }
        $agentDestDir = Join-Path $codexHome "agents"
        if (-not (Test-Path $agentDestDir)) {
            New-Item -ItemType Directory -Path $agentDestDir -Force | Out-Null
        }
        foreach ($tomlFile in (Get-ChildItem -Path $agentSourceDir -Filter "sdd-*.toml")) {
            $destFile = Join-Path $agentDestDir $tomlFile.Name
            Copy-Item -Path $tomlFile.FullName -Destination $destFile -Force
        }
        # Scan destination for malformed agent role files (warning only; do not modify or delete).
        foreach ($tomlFile in (Get-ChildItem -Path $agentDestDir -Filter "*.toml")) {
            $content = Get-Content -Path $tomlFile.FullName -Raw
            if (-not ($content -match '(?m)^\s*developer_instructions\s*=')) {
                Write-Warning "Codex will ignore malformed agent role file at startup ('Ignoring malformed agent role definition'): $($tomlFile.FullName). Add a developer_instructions entry or delete the file."
            }
        }
    }
    catch {
        Write-Warning "Codex agent install failed: $_"
    }
}

# ---------------------------------------------------------------------------
# MCP: Node version check, placement, and Claude/Codex/Cursor/VS Code registration
# ---------------------------------------------------------------------------
function Test-NodeVersionOk {
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        Write-Warning "Node.js was not found in PATH. MCP server installation was skipped (plugin installation continues)."
        return $false
    }
    $version = & node --version 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($version)) {
        Write-Warning "Could not determine Node.js version. MCP server installation was skipped (plugin installation continues)."
        return $false
    }
    $majorText = ($version.TrimStart("v") -split '\.')[0]
    $major = 0
    if (-not [int]::TryParse($majorText, [ref]$major)) {
        Write-Warning "Could not determine Node.js version (got '$version'). MCP server installation was skipped (plugin installation continues)."
        return $false
    }
    if ($major -lt 20) {
        Write-Warning "Node.js >= 20 is required for MCP servers (found $version). MCP server installation was skipped (plugin installation continues)."
        return $false
    }
    return $true
}

function Install-McpServerPayloads {
    param(
        [Parameter(Mandatory)][string]$SourceRootPath,
        [Parameter(Mandatory)][string]$InstallRootPath
    )

    foreach ($name in $Mcp) {
        $srcDir = Join-Path (Join-Path $SourceRootPath "mcp") $name
        $srcDist = Join-Path $srcDir "dist"
        $srcIndex = Join-Path $srcDist "index.js"
        $srcPackageJson = Join-Path $srcDir "package.json"
        if (-not (Test-Path $srcIndex) -or -not (Test-Path $srcPackageJson)) {
            Write-Warning "MCP server '$name' payload (dist/index.js, package.json) was not found under mcp/$name. Skipping placement."
            continue
        }
        $destDir = Join-Path (Join-Path $InstallRootPath "mcp") $name
        $destDist = Join-Path $destDir "dist"
        New-Item -ItemType Directory -Path $destDist -Force | Out-Null
        Copy-Item -Path (Join-Path $srcDist "*") -Destination $destDist -Recurse -Force
        Copy-Item -Path $srcPackageJson -Destination (Join-Path $destDir "package.json") -Force
    }
}

function Register-ClaudeMcp {
    param([Parameter(Mandatory)][string]$InstallRootPath)

    if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
        Write-Warning "Claude Code CLI was not found. Claude MCP registration was skipped."
        return
    }
    foreach ($name in $Mcp) {
        $entryPoint = Join-Path (Join-Path (Join-Path $InstallRootPath "mcp") $name) "dist/index.js"
        if (-not (Test-Path $entryPoint)) { continue }
        Invoke-PluginCommand "claude" @("mcp", "add", $name, "--scope", "user", "--", "node", $entryPoint)
    }
}

function Register-CodexMcp {
    param([Parameter(Mandatory)][string]$InstallRootPath)

    $codexHome = if ($env:SDD_CODEX_HOME) { $env:SDD_CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex" }
    $configToml = Join-Path $codexHome "config.toml"
    if (-not (Test-Path $configToml)) {
        Write-Warning "$configToml was not found. Codex MCP registration was skipped (the installer does not create a new config.toml)."
        return
    }
    foreach ($name in $Mcp) {
        $entryPoint = Join-Path (Join-Path (Join-Path $InstallRootPath "mcp") $name) "dist/index.js"
        if (-not (Test-Path $entryPoint)) { continue }
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
        $entryPointToml = $entryPoint -replace '\\', '/'
        $filtered.Add("")
        $filtered.Add($markerBegin)
        $filtered.Add("[mcp_servers.$name]")
        $filtered.Add('command = "node"')
        $filtered.Add("args = [`"$entryPointToml`"]")
        $filtered.Add($markerEnd)
        Set-Content -Path $configToml -Value $filtered
    }
}

function Update-McpJson {
    # Shared idempotent JSON upsert for IDE client MCP configs (ADR-0005).
    # Upserts <TopKey>.<name> for every selected MCP whose payload was placed,
    # preserving all other entries and unknown top-level keys. The output is
    # stable 2-space JSON, so re-running produces a byte-identical file. To
    # guarantee byte-parity with install.sh, the JSON handling is done by the
    # SAME Node one-liner install.sh uses (Node >= 20 is guaranteed here by the
    # MCP gate / McpNodeOk). Fail-safes (security-spec B3): a present-but-invalid
    # JSON file is never overwritten (error notice, installer continues with
    # other clients).
    param(
        [Parameter(Mandatory)][string]$ClientLabel,
        [Parameter(Mandatory)][string]$ConfigFile,
        [Parameter(Mandatory)][string]$TopKey,
        [Parameter(Mandatory)][string]$EntryKind,
        [Parameter(Mandatory)][string]$InstallRootPath
    )

    $pairs = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $Mcp) {
        $entryPoint = Join-Path (Join-Path (Join-Path $InstallRootPath "mcp") $name) "dist/index.js"
        if (-not (Test-Path $entryPoint)) { continue }
        # Normalise to forward slashes so the stored args match install.sh and
        # are portable across the client's platform expectations.
        $pairs.Add($name)
        $pairs.Add(($entryPoint -replace '\\', '/'))
    }
    if ($pairs.Count -eq 0) { return }

    $nodeScript = @'
const fs = require("fs");
const [file, topKey, kind, ...pairs] = process.argv.slice(1);
let text = "";
try { text = fs.readFileSync(file, "utf8"); } catch (err) { text = ""; }
let root = {};
if (text.trim() !== "") {
  try { root = JSON.parse(text); } catch (err) { process.exit(3); }
  if (root === null || typeof root !== "object" || Array.isArray(root)) process.exit(3);
}
if (root[topKey] === undefined) root[topKey] = {};
const section = root[topKey];
if (section === null || typeof section !== "object" || Array.isArray(section)) process.exit(3);
for (let i = 0; i + 1 < pairs.length; i += 2) {
  section[pairs[i]] = kind === "vscode"
    ? { type: "stdio", command: "node", args: [pairs[i + 1]] }
    : { command: "node", args: [pairs[i + 1]] };
}
const out = JSON.stringify(root, null, 2) + "\n";
const tmp = file + ".sdd-forge.tmp";
fs.writeFileSync(tmp, out);
fs.renameSync(tmp, file);
'@

    & node -e $nodeScript $ConfigFile $TopKey $EntryKind @($pairs)
    $rc = $LASTEXITCODE
    if ($rc -eq 3) {
        Write-Error "$ConfigFile contains invalid JSON. $ClientLabel MCP registration was skipped and the file was left unmodified. Fix or remove the file and re-run the installer." -ErrorAction Continue
        return
    }
    if ($rc -ne 0) {
        Write-Warning "Failed to update $ConfigFile. $ClientLabel MCP registration was skipped."
        return
    }
}

function Register-CursorMcp {
    # Idempotently upserts mcpServers.<name> into ~/.cursor/mcp.json for each
    # selected MCP. An absent ~/.cursor directory means Cursor is not installed:
    # skip with a notice and never create the directory (creating mcp.json
    # inside an EXISTING directory is fine). Override the directory via
    # SDD_CURSOR_DIR (for testing; default is the user profile).
    param([Parameter(Mandatory)][string]$InstallRootPath)

    $cursorDir = if ($env:SDD_CURSOR_DIR) { $env:SDD_CURSOR_DIR } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) ".cursor" }
    if (-not (Test-Path $cursorDir)) {
        Write-Warning "$cursorDir was not found. Cursor MCP registration was skipped (Cursor does not appear to be installed; the installer does not create the directory)."
        return
    }
    Update-McpJson -ClientLabel "Cursor" -ConfigFile (Join-Path $cursorDir "mcp.json") -TopKey "mcpServers" -EntryKind "cursor" -InstallRootPath $InstallRootPath
}

function Register-VSCodeMcp {
    # Idempotently upserts servers.<name> into the VS Code user-profile mcp.json
    # for each selected MCP (Windows %APPDATA%\Code\User, macOS
    # ~/Library/Application Support/Code/User, Linux ~/.config/Code/User). An
    # absent user directory means VS Code is not installed: skip with a notice
    # and never create the directory. Override via SDD_VSCODE_USER_DIR (testing).
    param([Parameter(Mandatory)][string]$InstallRootPath)

    # Windows PowerShell 5.1 (Desktop) has no $IsWindows/$IsMacOS/$IsLinux
    # automatic variables and always runs on Windows; PowerShell 7+ exposes
    # them cross-platform. Detect accordingly.
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
        Write-Warning "$vscodeUserDir was not found. VS Code MCP registration was skipped (VS Code does not appear to be installed; the installer does not create the directory)."
        return
    }
    Update-McpJson -ClientLabel "VS Code" -ConfigFile (Join-Path $vscodeUserDir "mcp.json") -TopKey "servers" -EntryKind "vscode" -InstallRootPath $InstallRootPath
}

$script:McpNodeOk = $false

function Install-McpServersIfSelected {
    param(
        [Parameter(Mandatory)][string]$SourceRootPath,
        [Parameter(Mandatory)][string]$InstallRootPath
    )

    $script:McpNodeOk = $false
    if ($SkipMcp -or $Mcp.Count -eq 0) { return }
    if (-not (Test-NodeVersionOk)) { return }
    $script:McpNodeOk = $true
    Install-McpServerPayloads -SourceRootPath $SourceRootPath -InstallRootPath $InstallRootPath
}

function Register-McpServers {
    param([Parameter(Mandatory)][string]$InstallRootPath)

    if ($SkipMcp -or $Mcp.Count -eq 0 -or -not $script:McpNodeOk) { return }
    if ($Target -in @("All", "Claude")) {
        Register-ClaudeMcp -InstallRootPath $InstallRootPath
    }
    if ($Target -in @("All", "Codex")) {
        Register-CodexMcp -InstallRootPath $InstallRootPath
    }
    # Cursor has no dedicated -Target value, so it participates in All only.
    if ($Target -eq "All") {
        Register-CursorMcp -InstallRootPath $InstallRootPath
    }
    # VS Code consumes the MCP config through Copilot, so it participates in
    # both All and Copilot.
    if ($Target -in @("All", "Copilot")) {
        Register-VSCodeMcp -InstallRootPath $InstallRootPath
    }
}

function Get-GitHubAuthToken {
    foreach ($tokenVariable in @("GH_TOKEN", "GITHUB_TOKEN")) {
        $token = [Environment]::GetEnvironmentVariable($tokenVariable)
        if (-not [string]::IsNullOrWhiteSpace($token)) {
            return $token.Trim()
        }
    }

    if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
        throw "GitHub authentication is required for remote installs. Set GH_TOKEN/GITHUB_TOKEN, install and authenticate gh, or use -SourceDirectory."
    }

    $token = & gh auth token 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw "GitHub authentication is required for remote installs. Set GH_TOKEN/GITHUB_TOKEN or run 'gh auth login'."
    }

    return $token.Trim()
}

function Download-AuthenticatedArchive {
    param(
        [Parameter(Mandatory)][string]$RepositoryName,
        [Parameter(Mandatory)][string]$RefName,
        [Parameter(Mandatory)][string]$ArchivePath
    )

    $token = Get-GitHubAuthToken
    $downloadUrl = "https://api.github.com/repos/$RepositoryName/tarball/$RefName"
    Write-Host "Downloading authenticated archive from $downloadUrl"
    Invoke-WebRequest -Uri $downloadUrl -Headers @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json" } -OutFile $ArchivePath
}

function Get-RequiredPaths {
    $allPluginNames = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop", "sdd-ship")
    $paths = @(
        ".agents/plugins/marketplace.json",
        ".claude-plugin/marketplace.json",
        ".codex/agents/sdd-investigator.toml",
        ".codex/agents/sdd-evaluator.toml",
        "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md",
        "plugins/sdd-ship/skills/ship/SKILL.md"
    )
    foreach ($plugin in $allPluginNames) {
        $paths += "plugins/$plugin/.codex-plugin/plugin.json"
        $paths += "plugins/$plugin/.claude-plugin/plugin.json"
        $paths += "plugins/$plugin/.plugin/plugin.json"
    }
    return $paths
}

function Write-InstallSummary {
    param([Parameter(Mandatory)][string]$ResolvedInstallRoot)

    Write-Host ""
    Write-Host "SDD plugins installed at: $ResolvedInstallRoot"
    # ci-mcp needs a read-only GitHub token at runtime. The installer never
    # stores a token value (REQ-010, security-spec B3); it only names the
    # environment variables the user must set for their MCP client (AC-017).
    if (($Mcp -contains "ci-mcp") -and $script:McpNodeOk) {
        Write-Host ""
        Write-Host "ci-mcp needs a read-only GitHub token to call the GitHub Actions API."
        Write-Host "Set one of these environment variables for your MCP client before it starts ci-mcp: CI_MCP_GITHUB_TOKEN (preferred), GH_READONLY_TOKEN, or GITHUB_TOKEN."
    }
    if ($Target -eq "FilesOnly") {
        Write-Host "Plugin registration was skipped because Target=FilesOnly."
        return
    }

    Write-Host ""
    Write-Host "Registration summary:"
    if ($Target -in @("All", "Codex")) { Write-Host "  Codex : $script:CodexRegistrationStatus" }
    if ($Target -in @("All", "Claude")) { Write-Host "  Claude: $script:ClaudeRegistrationStatus" }
    if ($Target -in @("All", "Copilot")) { Write-Host "  Copilot: $script:CopilotRegistrationStatus" }

    if ($Target -in @("All", "Claude")) {
        Write-Host ""
        if ($script:ClaudeRegistrationStatus -eq "registered") {
            Write-Host "Claude Code next step: run /reload-plugins or restart Claude Code."
            Write-Host "Expected slash commands after reload:"
            Write-Host "  /sdd-bootstrap:bootstrap"
            Write-Host "  /sdd-ship:ship"
        }
        elseif ($script:ClaudeRegistrationStatus -like "skipped:*") {
            Write-Warning "Claude Code registration did not complete. Re-run with: .\install.ps1 -Target Claude -Plugins sdd-bootstrap,sdd-ship -RequireClaude"
        }
        elseif ($script:ClaudeRegistrationStatus -like "marketplace registered;*") {
            Write-Warning "Claude marketplace was registered, but plugin install was skipped because -SkipPluginInstall was set. /sdd-bootstrap:bootstrap and /sdd-ship:ship will not appear until the plugins are installed."
        }
    }
}

$temporaryRoot = $null
$backupRoot = $null
$stagingRoot = $null
$newInstallPlaced = $false
$mutex = $null
$mutexAcquired = $false
try {
    $isLocalSource = -not [string]::IsNullOrWhiteSpace($SourceDirectory)
    if ($SourceDirectory) {
        $sourceRoot = (Resolve-Path $SourceDirectory).Path
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "SourceDirectory must be the root of a Git worktree so only tracked files can be installed (git was not found)."
        }
        # --show-prefix is empty only at the worktree root. This avoids false
        # negatives when a platform exposes the same temporary directory via
        # canonical and symlinked paths (for example /var and /private/var).
        $gitPrefix = & git -C $sourceRoot rev-parse --show-prefix 2>$null
        if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrEmpty($gitPrefix.Trim())) {
            throw "SourceDirectory must be the root of a Git worktree so only tracked files can be installed."
        }
    }
    else {
        $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-plugins-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

        $archivePath = Join-Path $temporaryRoot "source.tar.gz"
        Download-AuthenticatedArchive -RepositoryName $Repository -RefName $Ref -ArchivePath $archivePath
        & tar -xzf $archivePath -C $temporaryRoot

        $sourceRoot = Get-ChildItem -Path $temporaryRoot -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName ".agents/plugins/marketplace.json") } |
            Select-Object -First 1 -ExpandProperty FullName
        if (-not $sourceRoot) {
            throw "The downloaded archive does not contain an SDD plugin marketplace."
        }
    }

    foreach ($relativePath in (Get-RequiredPaths)) {
        if (-not (Test-Path (Join-Path $sourceRoot $relativePath))) {
            throw "Required file is missing: $relativePath"
        }
    }

    # Local sources are staged from Git-tracked files only. Do not allow a
    # required release file that exists solely as an untracked working-tree
    # change, because it would be omitted from the successful installation.
    if ($isLocalSource) {
        foreach ($relativePath in (Get-RequiredPaths)) {
            & git -C $sourceRoot ls-files --error-unmatch -- $relativePath 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Required file is not Git-tracked in SourceDirectory: $relativePath"
            }
        }
    }

    # Validate all sdd-*.toml files: must have no BOM and must define name and developer_instructions.
    $agentSourceDir = Join-Path (Join-Path $sourceRoot ".codex") "agents"
    if (Test-Path $agentSourceDir) {
        foreach ($tomlFile in (Get-ChildItem -Path $agentSourceDir -Filter "sdd-*.toml")) {
            $bytes = [System.IO.File]::ReadAllBytes($tomlFile.FullName)
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                throw "Malformed Codex agent role file (must define developer_instructions, no BOM): $($tomlFile.Name)"
            }
            $content = Get-Content -Path $tomlFile.FullName -Raw
            if (-not ($content -match '(?m)^name\s*=')) {
                throw "Malformed Codex agent role file (must define developer_instructions, no BOM): $($tomlFile.Name)"
            }
            if (-not ($content -match '(?m)^developer_instructions\s*=')) {
                throw "Malformed Codex agent role file (must define developer_instructions, no BOM): $($tomlFile.Name)"
            }
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

    # ---------------------------------------------------------------------------
    # Exclusive per-install-root named mutex
    # The mutex name is keyed to the resolved InstallRoot (case-insensitive) so
    # concurrent installs to different roots do not contend.
    # ---------------------------------------------------------------------------
    $mutexTimeoutSeconds = if ($env:SDD_INSTALL_LOCK_TIMEOUT) { [int]$env:SDD_INSTALL_LOCK_TIMEOUT } else { 120 }
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $rootBytes = [System.Text.Encoding]::UTF8.GetBytes($InstallRoot.ToLower())
    $hashBytes = $sha256.ComputeHash($rootBytes)
    $sha256.Dispose()
    $rootHash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    $mutexName = "Global\sdd-forge-install-$rootHash"
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    try {
        $mutexAcquired = $mutex.WaitOne([TimeSpan]::FromSeconds($mutexTimeoutSeconds))
    }
    catch [System.Threading.AbandonedMutexException] {
        # Prior holder died without releasing — we now own it.
        $mutexAcquired = $true
    }
    if (-not $mutexAcquired) {
        throw "another sdd-forge install is in progress (mutex: $mutexName). Retry later."
    }

    $stagingRoot = Join-Path $installParent ("sdd-plugins-staging-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $stagingRoot | Out-Null
    if ($isLocalSource) {
        # The mcp/ tree is excluded here even though it is Git-tracked: MCP
        # payload placement is handled exclusively by Install-McpServerPayloads
        # (dist/ + package.json only, gated by -SkipMcp / -Mcp / the Node >= 20
        # check), so staging it unconditionally here would bypass that gating.
        $trackedFiles = & git -C $sourceRoot ls-files -- . ':!mcp/**'
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to enumerate Git-tracked source files."
        }
        foreach ($relativePath in $trackedFiles) {
            $sourcePath = Join-Path $sourceRoot $relativePath
            $sourceItem = Get-Item -LiteralPath $sourcePath -Force
            if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing to stage Git-tracked symlink/reparse point: $relativePath"
            }
            $destination = Join-Path $stagingRoot $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Copy-Item -LiteralPath $sourcePath -Destination $destination -Force
        }
    }
    else {
        # Remote archive input is a trusted release artifact with no local
        # untracked state. Preserve its complete layout, excluding .git and
        # mcp/ (MCP payload placement is handled exclusively by
        # Install-McpServerPayloads, gated by -SkipMcp / -Mcp / Node >= 20).
        foreach ($entry in (Get-ChildItem -Path $sourceRoot -Force | Where-Object { $_.Name -ne ".git" -and $_.Name -ne "mcp" })) {
            Copy-Item -Path $entry.FullName -Destination (Join-Path $stagingRoot $entry.Name) -Recurse -Force
        }
    }

    if (Test-Path $InstallRoot) {
        $backupRoot = Join-Path $installParent ("sdd-plugins-backup-" + [guid]::NewGuid())
        Move-Item -Path $InstallRoot -Destination $backupRoot
    }
    Move-Item -Path $stagingRoot -Destination $InstallRoot
    $stagingRoot = $null
    $newInstallPlaced = $true

    $resolvedInstallRoot = (Resolve-Path $InstallRoot).Path

    # MCP placement mirrors plugin file placement: it happens regardless of
    # -Target and is controlled only by -SkipMcp / -Mcp.
    Install-McpServersIfSelected -SourceRootPath $sourceRoot -InstallRootPath $resolvedInstallRoot

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
    Register-McpServers -InstallRootPath $resolvedInstallRoot

    Write-InstallSummary $resolvedInstallRoot

    if ($backupRoot -and (Test-Path $backupRoot)) {
        Remove-Item -Path $backupRoot -Recurse -Force
        $backupRoot = $null
    }
}
catch {
    # Rollback is best-effort: wrap each destructive step so that a locked file
    # or other Windows error does not prevent the restore from being attempted.
    if ($backupRoot -and (Test-Path $backupRoot)) {
        try {
            if (Test-Path $InstallRoot) {
                Remove-Item -Path $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Warning "Could not remove failed install at '$InstallRoot': $_"
        }
        # Only restore when the failed install is fully gone: Move-Item into a
        # still-existing directory would nest the backup INSIDE it and lose the
        # recovery location.
        if (Test-Path $InstallRoot) {
            Write-Warning "CRITICAL: failed install could not be removed from '$InstallRoot' (locked files?). Your previous installation is preserved at: $backupRoot"
        }
        else {
            try {
                Move-Item -Path $backupRoot -Destination $InstallRoot
                $backupRoot = $null
            }
            catch {
                Write-Warning "CRITICAL: Could not restore backup. Your previous installation is preserved at: $backupRoot"
            }
        }
    }
    elseif ($newInstallPlaced -and (Test-Path $InstallRoot)) {
        try {
            Remove-Item -Path $InstallRoot -Recurse -Force
        }
        catch {
            Write-Warning "Could not remove incomplete install at '$InstallRoot': $_"
        }
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
    # Release the exclusive mutex if we acquired it.
    if ($mutexAcquired -and $mutex) {
        try { $mutex.ReleaseMutex() } catch { }
    }
    if ($mutex) {
        $mutex.Dispose()
    }
}
