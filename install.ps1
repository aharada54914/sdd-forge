[CmdletBinding()]
param(
    [string]$Repository = "aharada54914/sdd-forge",
    [string]$Ref = "main",
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "sdd-plugins"),
    [ValidateSet("All", "Codex", "Claude", "Copilot", "FilesOnly")]
    [string]$Target = "All",
    [ValidateSet("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop", "sdd-domain", "sdd-azure-cloud", "sdd-aws-cloud", IgnoreCase = $false)]
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
        $dependencies = switch -CaseSensitive ($plugin) {
            "sdd-bootstrap" { @("sdd-review-loop"); break }
            "sdd-azure-cloud" { @("sdd-quality-loop"); break }
            "sdd-aws-cloud" { @("sdd-quality-loop"); break }
            "sdd-domain" { @("sdd-bootstrap", "sdd-quality-loop"); break }
            "sdd-lite" { @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop"); break }
            "sdd-ship" { @("sdd-bootstrap", "sdd-review-loop", "sdd-implementation", "sdd-quality-loop", "sdd-lite"); break }
            default { @() }
        }
        foreach ($dependency in $dependencies) {
            if ($Plugins -cnotcontains $dependency) {
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

# External CLIs report an already-present marketplace, MCP server, or plugin as
# an error, not as success. WFI-041: propagating that as fatal made every
# re-run of the installer on an installed machine roll the install root back to
# the previous version while reporting an error about something unrelated.
# "Already there" is the desired end state, so match the CLIs' own wording and
# treat it as success. Every other non-zero exit stays fatal.
$script:IdempotentRegistrationPattern = 'already (registered|exists|added|installed|configured)'

# claude reports an existing plugin installation as *success*, so a plain
# re-run leaves the cache a version behind. These two patterns drive the
# upgrade path in Install-ClaudePlugins.
$script:ClaudeAlreadyInstalledPattern = 'already installed'
$script:ClaudeUpgradePattern = 'updated from \S+ to \S+'

function Invoke-CapturedCommand {
    # Runs a native command, capturing stdout and stderr to files so both can
    # be scanned (the CLIs disagree about which stream carries the message),
    # then re-emitting each on its original stream so the caller still sees
    # exactly what the CLI said. Returns @{ ExitCode; Output }.
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        & $Command @Arguments > $outFile 2> $errFile
        $exitCode = $LASTEXITCODE
        $stdout = (Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue)
        $stderr = (Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue)
        if ($stdout) { Write-Host $stdout.TrimEnd() }
        if ($stderr) { [Console]::Error.WriteLine($stderr.TrimEnd()) }
        return @{ ExitCode = $exitCode; Output = "$stdout`n$stderr" }
    }
    finally {
        Remove-Item -Path $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-IdempotentPluginCommand {
    # Like Invoke-PluginCommand, but tolerates the "already there" outcome.
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $result = Invoke-CapturedCommand -Command $Command -Arguments $Arguments
    if ($result.ExitCode -eq 0) { return }
    if ($result.Output -imatch $script:IdempotentRegistrationPattern) {
        Write-Host "Note: $Label is already registered; keeping the existing registration."
        return
    }
    throw "'$Command $($Arguments -join ' ')' failed with exit code $($result.ExitCode)."
}

function Update-ClaudePlugins {
    # Converge already-installed Claude plugins on the marketplace's current
    # version. Reports each plugin's transition so that a run which changed
    # nothing is distinguishable from one that upgraded.
    param([Parameter(Mandatory)][string[]]$PluginNames)

    Invoke-PluginCommand "claude" @("plugin", "marketplace", "update", "sdd-plugins")
    $upgraded = 0
    foreach ($plugin in $PluginNames) {
        $result = Invoke-CapturedCommand -Command "claude" -Arguments @("plugin", "update", "$plugin@sdd-plugins")
        if ($result.ExitCode -ne 0) {
            throw "'claude plugin update $plugin@sdd-plugins' failed with exit code $($result.ExitCode)."
        }
        $match = [regex]::Match($result.Output, $script:ClaudeUpgradePattern, 'IgnoreCase')
        if ($match.Success) {
            Write-Host "sdd-forge: upgraded $plugin ($($match.Value))"
            $upgraded++
        }
        else {
            Write-Host "sdd-forge: $plugin was already up to date"
        }
    }
    if ($upgraded -eq 0) {
        Write-Host "sdd-forge: no Claude plugin needed an upgrade."
    }
    else {
        Write-Host "sdd-forge: upgraded $upgraded Claude plugin(s)."
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

    Invoke-IdempotentPluginCommand "the Codex sdd-plugins marketplace" "codex" @("plugin", "marketplace", "add", $MarketplaceRoot)
    if ($SkipPluginInstall) {
        $script:CodexRegistrationStatus = "marketplace registered; plugin install skipped"
        return
    }
    foreach ($plugin in $Plugins) {
        Invoke-IdempotentPluginCommand "Codex plugin '$plugin'" "codex" @("plugin", "add", "$plugin@sdd-plugins")
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

    Invoke-IdempotentPluginCommand "the Copilot sdd-plugins marketplace" "copilot" @("plugin", "marketplace", "add", $MarketplaceRoot)
    if ($SkipPluginInstall) {
        $script:CopilotRegistrationStatus = "marketplace registered; plugin install skipped"
        return
    }
    foreach ($plugin in $Plugins) {
        Invoke-IdempotentPluginCommand "Copilot plugin '$plugin'" "copilot" @("plugin", "install", "$plugin@sdd-plugins")
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
    Invoke-IdempotentPluginCommand "the Claude sdd-plugins marketplace" "claude" @("plugin", "marketplace", "add", $MarketplaceRoot, "--scope", "user")
    if ($SkipPluginInstall) {
        $script:ClaudeRegistrationStatus = "marketplace registered; plugin install skipped"
        return
    }
    # `claude plugin install` reports an existing installation as success and
    # returns without upgrading, so a re-run would silently leave the cache a
    # version behind (WFI-041). Collect those plugins and put them through the
    # update path below.
    $alreadyInstalled = [System.Collections.Generic.List[string]]::new()
    foreach ($plugin in $Plugins) {
        $result = Invoke-CapturedCommand -Command "claude" -Arguments @("plugin", "install", "$plugin@sdd-plugins", "--scope", "user")
        if ($result.ExitCode -ne 0) {
            throw "'claude plugin install $plugin@sdd-plugins --scope user' failed with exit code $($result.ExitCode)."
        }
        if ($result.Output -imatch $script:ClaudeAlreadyInstalledPattern) {
            $alreadyInstalled.Add($plugin)
        }
    }
    if ($alreadyInstalled.Count -gt 0) {
        Update-ClaudePlugins -PluginNames $alreadyInstalled.ToArray()
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
    $trimmedVersion = "$version".Trim()
    if ($trimmedVersion -notmatch '^v?([0-9]+)\.([0-9]+)\.([0-9]+)$') {
        Write-Warning "Could not determine Node.js version (got '$version'). MCP server installation was skipped (plugin installation continues)."
        return $false
    }
    $major = 0
    $minor = 0
    $patch = 0
    if (-not [int]::TryParse($Matches[1], [ref]$major) -or
        -not [int]::TryParse($Matches[2], [ref]$minor) -or
        -not [int]::TryParse($Matches[3], [ref]$patch)) {
        Write-Warning "Could not determine Node.js version (got '$version'). MCP server installation was skipped (plugin installation continues)."
        return $false
    }
    $parsedVersion = [version]::new($major, $minor, $patch)
    if ($parsedVersion -lt [version]"22.19.0") {
        Write-Warning "Node.js >= 22.19.0 is required for MCP servers (found $version). MCP server installation was skipped (plugin installation continues)."
        return $false
    }
    return $true
}

function Test-PlainItem {
    # True when the path exists and is not a symlink / reparse point.
    param([Parameter(Mandatory)][string]$Path)

    try {
        return (([System.IO.File]::GetAttributes($Path) -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)
    }
    catch {
        return $false
    }
}

function Install-McpServerPayloads {
    # Each MCP is a self-contained esbuild bundle (--outfile=dist/index.js), so
    # exactly dist/index.js and package.json are placed; nothing else under
    # dist/ is copied. A symlinked mcp tree or payload file is treated as absent
    # rather than followed out of the source.
    param(
        [Parameter(Mandatory)][string]$SourceRootPath,
        [Parameter(Mandatory)][string]$InstallRootPath
    )

    foreach ($name in $Mcp) {
        $srcMcp = Join-Path $SourceRootPath "mcp"
        $srcDir = Join-Path $srcMcp $name
        $srcDist = Join-Path $srcDir "dist"
        $srcIndex = Join-Path $srcDist "index.js"
        $srcPackageJson = Join-Path $srcDir "package.json"
        if (-not (Test-Path -LiteralPath $srcIndex -PathType Leaf) -or -not (Test-Path -LiteralPath $srcPackageJson -PathType Leaf) -or
            -not (Test-PlainItem $srcMcp) -or -not (Test-PlainItem $srcDir) -or -not (Test-PlainItem $srcDist) -or
            -not (Test-PlainItem $srcIndex) -or -not (Test-PlainItem $srcPackageJson)) {
            Write-Warning "MCP server '$name' payload (dist/index.js, package.json) was not found under mcp/$name. Skipping placement."
            continue
        }
        $destDir = Join-Path (Join-Path $InstallRootPath "mcp") $name
        $destDist = Join-Path $destDir "dist"
        New-Item -ItemType Directory -Path $destDist -Force | Out-Null
        Copy-Item -LiteralPath $srcIndex -Destination (Join-Path $destDist "index.js") -Force
        Copy-Item -LiteralPath $srcPackageJson -Destination (Join-Path $destDir "package.json") -Force
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
        Invoke-IdempotentPluginCommand "MCP server '$name'" "claude" @("mcp", "add", $name, "--scope", "user", "--", "node", $entryPoint)
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
    # SAME Node one-liner install.sh uses (Node >= 22.19.0 is guaranteed here by the
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

$cloudEntryFiles = @(".claude-plugin/plugin.json", ".codex-plugin/plugin.json", ".plugin/plugin.json", "skills/orchestrate/SKILL.md", "scripts/cloud.py")

function Get-RequiredPaths {
    $allPluginNames = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop", "sdd-ship", "sdd-domain")
    $paths = @(
        ".agents/plugins/marketplace.json",
        ".claude-plugin/marketplace.json",
        ".codex/agents/sdd-investigator.toml",
        ".codex/agents/sdd-evaluator.toml",
        "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md",
        "plugins/sdd-ship/skills/ship/SKILL.md",
        # Managed prepare/launch runtime closure read by the installed entry and helper.
        "plugins/sdd-implementation/scripts/managed-model-entry.py",
        "plugins/sdd-implementation/scripts/model-policy.py",
        "plugins/sdd-implementation/scripts/select-agent-model.sh",
        "plugins/sdd-implementation/scripts/select-agent-model.ps1",
        "contracts/agent-model-capabilities.v2.json",
        "contracts/model-policy.v1.json",
        "contracts/model-launch-controls.schema.json",
        "plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py",
        "plugins/sdd-quality-loop/agents/wfi-auditor-a.md",
        "plugins/sdd-quality-loop/agents/wfi-auditor-b.md",
        "plugins/sdd-quality-loop/references/wfi-category-guide.md",
        "plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs",
        "plugins/sdd-implementation/skills/diagnose/SKILL.md",
        "plugins/sdd-implementation/skills/diagnose/references/diagnosis-loop-policy.md",
        "plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh",
        "plugins/sdd-implementation/templates/diagnosis-report.template.md",
        "plugins/sdd-quality-loop/references/risk-gate-matrix.md",
        "plugins/sdd-implementation/skills/implement-task/SKILL.md",
        "plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md",
        "plugins/sdd-implementation/skills/implement-task/references/implementation-craft-policy.md",
        "plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md",
        "plugins/sdd-quality-loop/references/sudo-mode-policy.md",
        "plugins/sdd-quality-loop/references/debugging-recovery-policy.md",
        "plugins/sdd-implementation/templates/implementation-report.template.md",
        "plugins/sdd-bootstrap/agents/investigator.md",
        "plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md",
        "plugins/sdd-bootstrap/skills/investigate-codebase/templates/investigation.template.md",
        "plugins/sdd-bootstrap/skills/investigate-codebase/templates/codemap.template.md",
        "plugins/sdd-bootstrap/skills/investigate-codebase/templates/baseline-behavior.template.md",
        "plugins/sdd-bootstrap/skills/investigate-codebase/references/spec-id-rules.md",
        "plugins/sdd-bootstrap/skills/investigate-codebase/references/investigation-policy.md",
        # The payload manifest selects what is installed; without it nothing can be.
        "install-payload.txt"
    )
    foreach ($plugin in $allPluginNames) {
        $paths += "plugins/$plugin/.codex-plugin/plugin.json"
        $paths += "plugins/$plugin/.claude-plugin/plugin.json"
        $paths += "plugins/$plugin/.plugin/plugin.json"
    }
    foreach ($plugin in @($Plugins | Where-Object { $_ -cin @("sdd-azure-cloud", "sdd-aws-cloud") })) {
        foreach ($file in $cloudEntryFiles + @("scripts/$($plugin.Split('-')[1])_local.py")) {
            $paths += "plugins/$plugin/$file"
        }
    }
    return $paths
}

# install-payload.txt (repository root) lists the exact paths and directory
# prefixes (ending in '/') that make up the installed product. A local Git
# source and a downloaded archive are filtered by the same manifest, so an
# install never carries development specs, reports, tests, or local state.
# -Plugins controls registration and dependencies, not what is copied.
# install.sh implements the identical policy; keep the two in step.
$payloadManifestName = "install-payload.txt"
# Caches and private artifacts are never installed, even under an admitted directory.
$payloadExcludedNames = @(".git", "node_modules", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".cache", ".venv", ".private", ".learnings", ".DS_Store")

function Read-InstallPayloadManifest {
    # One entry per line; blank lines and '#' comments are ignored. Entries are
    # canonical relative paths: no '..', '.', absolute, backslash, wildcard, or
    # empty segments. Anything else fails the install.
    param([Parameter(Mandatory)][string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf) -or -not (Test-PlainItem $ManifestPath)) {
        throw "$payloadManifestName must be a regular file."
    }
    $text = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($ManifestPath))
    $entries = [System.Collections.Generic.List[string]]::new()
    foreach ($rawLine in ($text -split "`r?`n")) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith("#")) { continue }
        if ($line -cnotmatch '^[A-Za-z0-9._@+-]+(/[A-Za-z0-9._@+-]+)*/?$' -or $line -cmatch '(^|/)\.+(/|$)') {
            throw "Invalid $payloadManifestName entry (expected a canonical relative path or a directory prefix ending in '/'): $line"
        }
        $entries.Add($line)
    }
    if ($entries.Count -eq 0) {
        throw "$payloadManifestName lists no payload paths."
    }
    return , $entries.ToArray()
}

function Get-ArchiveCandidatePaths {
    # Files and symlinks below an extracted archive, as forward-slash relative
    # paths. Symlinked directories are reported but never descended into.
    param([Parameter(Mandatory)][string]$Root)

    $paths = [System.Collections.Generic.List[string]]::new()
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push("")
    while ($pending.Count -gt 0) {
        $relativeDirectory = $pending.Pop()
        $directoryPath = if ($relativeDirectory) { Join-Path $Root $relativeDirectory } else { $Root }
        foreach ($entry in [System.IO.DirectoryInfo]::new($directoryPath).EnumerateFileSystemInfos()) {
            if ($payloadExcludedNames -ccontains $entry.Name) { continue }
            $relativePath = if ($relativeDirectory) { "$relativeDirectory/$($entry.Name)" } else { $entry.Name }
            $isReparsePoint = ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            if (-not $isReparsePoint -and ($entry.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
                $pending.Push($relativePath)
            }
            else {
                $paths.Add($relativePath)
            }
        }
    }
    return , $paths.ToArray()
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
# Set once the install root holds the new tree and only external-CLI
# registration remains. See the catch block (WFI-041).
$registrationStarted = $false
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
        if ($LASTEXITCODE -ne 0) {
            throw "Downloaded archive extraction failed with exit code $LASTEXITCODE."
        }

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

    # The manifest is read from the source (working-tree bytes for a local
    # source, whose tracked state was verified above) and validated before
    # anything is staged.
    # Direct assignment: the function returns `, $array`, and wrapping the call in
    # @() would nest that array one level deeper.
    $payloadEntries = Read-InstallPayloadManifest -ManifestPath (Join-Path $sourceRoot $payloadManifestName)

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
    # The staging loop below uses static .NET file APIs, which resolve
    # relative paths against the process working directory rather than the
    # PowerShell location -- keep the root absolute so they always agree.
    $stagingRoot = (Resolve-Path -LiteralPath $stagingRoot).Path
    # Stage only the payload listed in install-payload.txt. A local worktree is
    # enumerated from its Git index (so untracked files never leak in) and the
    # current working-tree bytes of each admitted path are copied; a downloaded
    # archive is enumerated from its extracted tree and filtered by the same
    # manifest, so both sources install the same product and neither carries
    # development trees. The mcp/ tree is not in the manifest on purpose: MCP
    # payload placement is handled exclusively by Install-McpServerPayloads
    # (dist/index.js + package.json only, gated by -SkipMcp / -Mcp / the
    # Node >= 22.19.0 check).
    if ($isLocalSource) {
        # Read the NUL-delimited UTF-8 stream directly: PowerShell's native
        # pipeline splits lines, while Git's ordinary output quotes special names.
        # Fixed arguments and WorkingDirectory also avoid shell/path quoting.
        $gitInfo = New-Object System.Diagnostics.ProcessStartInfo
        $gitInfo.FileName = @(Get-Command git -CommandType Application -ErrorAction Stop)[0].Source
        $gitInfo.Arguments = "ls-files -z"
        $gitInfo.WorkingDirectory = $sourceRoot
        $gitInfo.UseShellExecute = $false
        $gitInfo.RedirectStandardOutput = $true
        $gitInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $gitProcess = New-Object System.Diagnostics.Process
        $gitProcess.StartInfo = $gitInfo
        try {
            [void]$gitProcess.Start()
            $trackedOutput = $gitProcess.StandardOutput.ReadToEnd()
            $gitProcess.WaitForExit()
            if ($gitProcess.ExitCode -ne 0) {
                throw "Unable to enumerate Git-tracked source files."
            }
            $candidatePaths = $trackedOutput.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries)
        }
        finally {
            $gitProcess.Dispose()
        }
    }
    else {
        $candidatePaths = Get-ArchiveCandidatePaths -Root $sourceRoot
    }
    $exactEntries = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $prefixEntries = [System.Collections.Generic.List[string]]::new()
    foreach ($payloadEntry in $payloadEntries) {
        if ($payloadEntry.EndsWith("/")) { $prefixEntries.Add($payloadEntry) } else { [void]$exactEntries.Add($payloadEntry) }
    }
    # Raw .NET file APIs instead of one Get-Item/New-Item/Copy-Item provider
    # round-trip per file: each parent directory is created once, each
    # directory is checked for symlinks once, and File.Copy preserves file
    # modes just as Copy-Item does. An admitted path that is a symlink / reparse
    # point, or that sits below one, fails the install instead of being
    # followed out of the source.
    $createdDirectories = New-Object 'System.Collections.Generic.HashSet[string]'
    $checkedDirectories = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($relativePath in $candidatePaths) {
        $segments = $relativePath.Split("/")
        $admitted = $false
        if ($relativePath -cnotmatch '\.py[co]$' -and -not ($segments | Where-Object { $payloadExcludedNames -ccontains $_ })) {
            if ($exactEntries.Contains($relativePath)) {
                $admitted = $true
            }
            else {
                foreach ($prefix in $prefixEntries) {
                    if ($relativePath.StartsWith($prefix, [System.StringComparison]::Ordinal)) { $admitted = $true; break }
                }
            }
        }
        if (-not $admitted) { continue }

        $walk = ""
        for ($i = 0; $i -lt $segments.Length - 1; $i++) {
            $walk = if ($walk) { "$walk/$($segments[$i])" } else { $segments[$i] }
            if ($checkedDirectories.Add($walk) -and -not (Test-PlainItem (Join-Path $sourceRoot $walk))) {
                throw "Refusing to stage through a symlink/reparse point: $walk"
            }
        }
        $sourcePath = Join-Path $sourceRoot $relativePath
        try {
            $attributes = [System.IO.File]::GetAttributes($sourcePath)
        }
        catch {
            throw "Missing source file: $relativePath"
        }
        if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to stage symlink/reparse point: $relativePath"
        }
        if (($attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
            throw "Refusing to stage non-file payload entry: $relativePath"
        }
        $destination = Join-Path $stagingRoot $relativePath
        $parent = Split-Path -Parent $destination
        if ($createdDirectories.Add($parent)) {
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        }
        [System.IO.File]::Copy($sourcePath, $destination, $true)
    }

    # Fail closed if the manifest does not admit everything the installed runtime needs.
    foreach ($relativePath in (Get-RequiredPaths)) {
        if (-not (Test-Path -LiteralPath (Join-Path $stagingRoot $relativePath))) {
            throw "$payloadManifestName does not admit required file: $relativePath"
        }
    }

    # Rebuild selected and previously materialized runtimes before replacing the tree.
    # Prior payload presence retains availability, never registration or executable bytes.
    # Copy only the already staged tracked/archive bytes (no source-tree fallback).
    foreach ($plugin in @("sdd-azure-cloud", "sdd-aws-cloud")) {
        if ($Plugins -cnotcontains $plugin -and -not (Test-Path -LiteralPath (Join-Path $InstallRoot "plugins/$plugin/runtime") -PathType Container)) {
            continue
        }
        foreach ($file in $cloudEntryFiles + @("scripts/$($plugin.Split('-')[1])_local.py")) {
            if (-not (Test-Path -LiteralPath (Join-Path $stagingRoot "plugins/$plugin/$file") -PathType Leaf)) {
                throw "Required staged cloud entry file is missing: plugins/$plugin/$file"
            }
        }
        $runtime = Join-Path $stagingRoot "plugins/$plugin/runtime"
        foreach ($directory in @("scripts", "references", "contracts")) {
            New-Item -ItemType Directory -Path (Join-Path $runtime $directory) -Force | Out-Null
        }
        foreach ($module in @("cloud_contracts.py", "cloud_authorization.py", "cloud_verification.py", "cloud_dependencies.py")) {
            Copy-Item -LiteralPath (Join-Path $stagingRoot "plugins/sdd-quality-loop/scripts/$module") -Destination (Join-Path $runtime "scripts/$module")
        }
        Copy-Item -LiteralPath (Join-Path $stagingRoot "plugins/sdd-quality-loop/references/cloud-verification-registry.json") -Destination (Join-Path $runtime "references")
        $cloudSchemas = @(Get-ChildItem -LiteralPath (Join-Path $stagingRoot "contracts") -File |
            Where-Object { $_.Name -cmatch '^cloud-.*\.schema\.json$' })
        if ($cloudSchemas.Count -eq 0) { throw "Cloud schemas are missing from staged payload." }
        foreach ($schema in $cloudSchemas) {
            Copy-Item -LiteralPath $schema.FullName -Destination (Join-Path $runtime "contracts")
        }
        foreach ($schema in @("verification-contract-v3.schema.json", "selected-verification-plan-v2.schema.json")) {
            Copy-Item -LiteralPath (Join-Path $stagingRoot "plugins/sdd-quality-loop/contracts/$schema") -Destination (Join-Path $runtime "contracts")
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

    # Everything below registers the placed tree with external CLIs. A failure
    # from here on must not revert the install root — see the catch block
    # (WFI-041).
    $registrationStarted = $true

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
    # WFI-041: roll back only for failures up to and including placement. Once
    # the tree is in the install root and the run has moved on to registering
    # it with external CLIs, reverting would discard a correct install for a
    # failure that is not the install's — one CLI's complaint used to undo the
    # whole upgrade. The failing registration is reported by its own call site;
    # the tree stays at the new version and a re-run retries registration,
    # which is now idempotent (Invoke-IdempotentPluginCommand).
    if ($registrationStarted) {
        if ($backupRoot -and (Test-Path $backupRoot)) {
            try {
                Remove-Item -Path $backupRoot -Recurse -Force
                $backupRoot = $null
            }
            catch {
                Write-Warning "Could not remove superseded backup at '$backupRoot': $_"
            }
        }
        Write-Warning "Registration failed, but the install root at '$InstallRoot' was left at the newly installed version. Re-run the installer to retry registration."
        throw
    }
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
