[CmdletBinding()]
param(
    [string]$Repository = "aharada54914/sdd-forge",
    [string]$Ref = "main",
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "sdd-plugins"),
    [ValidateSet("All", "Codex", "Claude", "Copilot", "FilesOnly")]
    [string]$Target = "All",
    [ValidateSet("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite")]
    [string[]]$Plugins = @("sdd-bootstrap", "sdd-ship"),
    [switch]$SkipPluginInstall,
    [switch]$SkipAgentInstall,
    [string]$SourceDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# sdd-ship orchestrates implement-tasks, quality-gate, and lite-gate internally;
# those internal plugins must be present for the orchestrator to function.
# Selecting sdd-ship alone would silently omit the self-approval protection that
# lives in sdd-quality-loop hooks, so auto-expand to include all companions.
if ($Plugins -contains "sdd-ship") {
    foreach ($dep in @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop", "sdd-lite")) {
        if ($Plugins -notcontains $dep) { $Plugins += $dep }
    }
    Write-Warning "sdd-ship selected; auto-included its companions (sdd-bootstrap, sdd-implementation, sdd-quality-loop, sdd-lite)."
}

# sdd-lite depends on its companions and cannot run standalone:
#  - lite-spec requires sdd-bootstrap (sdd-adopt / check-sdd-structure) and
#    sdd-implementation (implement-task).
#  - lite-gate requires sdd-quality-loop (check-placeholders) and the approval /
#    kill-switch hooks live only in sdd-quality-loop.
# Selecting sdd-lite alone would silently omit the self-approval protection, so
# auto-expand the selection to include the companions.
if ($Plugins -contains "sdd-lite") {
    foreach ($dep in @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop")) {
        if ($Plugins -notcontains $dep) { $Plugins += $dep }
    }
    Write-Warning "sdd-lite selected; auto-included its companions (sdd-bootstrap, sdd-implementation, sdd-quality-loop)."
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

$temporaryRoot = $null
$backupRoot = $null
$stagingRoot = $null
$newInstallPlaced = $false
$mutex = $null
$mutexAcquired = $false
try {
    if ($SourceDirectory) {
        $sourceRoot = (Resolve-Path $SourceDirectory).Path
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

    $requiredPaths = @(
        ".agents/plugins/marketplace.json",
        ".claude-plugin/marketplace.json",
        "plugins/sdd-bootstrap/.codex-plugin/plugin.json",
        "plugins/sdd-ship/.claude-plugin/plugin.json",
        "plugins/sdd-ship/.codex-plugin/plugin.json",
        "plugins/sdd-ship/.plugin/plugin.json",
        "plugins/sdd-implementation/.codex-plugin/plugin.json",
        "plugins/sdd-quality-loop/.codex-plugin/plugin.json",
        "plugins/sdd-bootstrap/.plugin/plugin.json",
        "plugins/sdd-implementation/.plugin/plugin.json",
        "plugins/sdd-quality-loop/.plugin/plugin.json",
        "plugins/sdd-lite/.codex-plugin/plugin.json",
        "plugins/sdd-lite/.plugin/plugin.json",
        ".codex/agents/sdd-investigator.toml",
        ".codex/agents/sdd-evaluator.toml"
    )
    foreach ($relativePath in $requiredPaths) {
        if (-not (Test-Path (Join-Path $sourceRoot $relativePath))) {
            throw "Required file is missing: $relativePath"
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
    # An AbandonedMutexException means a prior holder exited without releasing —
    # we take ownership; the install tree may be in an unknown state but the
    # backup/rollback logic below handles that.
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
    # Use Get-ChildItem -Force so that dot-directories (hidden on Windows) are
    # included.  Copying each top-level entry individually avoids the double-
    # nesting that occurs when Copy-Item with a wildcard is followed by
    # explicit dot-dir copies: on PowerShell Core those dirs are not hidden so
    # the wildcard already copied them, and re-copying would create
    # .agents\.agents\, .codex\.codex\, etc.
    foreach ($entry in (Get-ChildItem -Path $sourceRoot -Force | Where-Object { $_.Name -ne ".git" })) {
        Copy-Item -Path $entry.FullName -Destination (Join-Path $stagingRoot $entry.Name) -Recurse -Force
    }

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
