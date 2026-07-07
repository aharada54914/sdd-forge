$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$allPlugins = @("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop")
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function New-TrackedFixture {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    # Do not clone local Git objects: macOS can invoke a host credential helper
    # while cloning. A Git archive contains only tracked content and expands
    # much faster than copying every file one by one.
    $archivePath = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-fixture-" + [guid]::NewGuid() + ".zip")
    try {
        & git -C $Source archive --format=zip "--output=$archivePath" HEAD
        if ($LASTEXITCODE -ne 0) { throw "Unable to archive tracked fixture files." }
        Expand-Archive -LiteralPath $archivePath -DestinationPath $Destination -Force
        & git -C $Destination init -q
        & git -C $Destination add -A
        & git -C $Destination -c user.name="Installer Test" -c user.email="installer-test@example.invalid" commit -qm "Fixture baseline"
        if ($LASTEXITCODE -ne 0) { throw "Unable to initialise installer source fixture." }
    }
    finally {
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
    }
}

# Local installs use Git's tracked-file list. Copy the files directly rather
# than cloning local Git objects, which can invoke a host credential helper.
$installerSourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-source-" + [guid]::NewGuid())
New-TrackedFixture -Source $repositoryRoot -Destination $installerSourceRoot
foreach ($relativePath in @(
    ".claude-plugin/marketplace.json",
    ".agents/plugins/marketplace.json",
    "install.sh",
    "install.ps1",
    "plugins/sdd-bootstrap/.claude-plugin/plugin.json",
    "plugins/sdd-quality-loop/.claude-plugin/plugin.json",
    "plugins/sdd-review-loop/.claude-plugin/plugin.json",
    "plugins/sdd-review-loop/.codex-plugin/plugin.json",
    "plugins/sdd-review-loop/.plugin/plugin.json"
)) {
    $destination = Join-Path $installerSourceRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination $destination -Force
}
& git -C $installerSourceRoot add `
    .claude-plugin/marketplace.json `
    .agents/plugins/marketplace.json `
    install.sh `
    install.ps1 `
    plugins/sdd-bootstrap/.claude-plugin/plugin.json `
    plugins/sdd-quality-loop/.claude-plugin/plugin.json `
    plugins/sdd-review-loop
$stagedDiff = & git -C $installerSourceRoot diff --cached --name-only
if ($stagedDiff) {
    & git -C $installerSourceRoot -c user.name="Installer Test" -c user.email="installer-test@example.invalid" commit -qm "Add review-loop fixture"
    if ($LASTEXITCODE -ne 0) { throw "Unable to commit installer source fixture." }
}

# The MCP server payload (mcp/sdd-forge-mcp/dist + package.json) is not yet
# Git-tracked (dist/ is committed by a later task). The installer must copy
# it from the filesystem regardless of Git tracking state, so seed a minimal
# MCP payload directly on disk (untracked is fine).
$mcpSourceDir = Join-Path $installerSourceRoot "mcp/sdd-forge-mcp"
New-Item -ItemType Directory -Path (Join-Path $mcpSourceDir "dist") -Force | Out-Null
Set-Content -Path (Join-Path $mcpSourceDir "dist/index.js") -Value "console.log('sdd-forge-mcp fixture stub');" -Encoding Utf8NoBOM
Set-Content -Path (Join-Path $mcpSourceDir "package.json") -Value '{"name":"sdd-forge-mcp","version":"0.1.0","private":true,"type":"module","engines":{"node":">=20"}}' -Encoding Utf8NoBOM
# Files that must NOT be copied into the install root (node_modules/src/tests).
New-Item -ItemType Directory -Path (Join-Path $mcpSourceDir "node_modules/should-not-copy") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $mcpSourceDir "src") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $mcpSourceDir "tests") -Force | Out-Null
Set-Content -Path (Join-Path $mcpSourceDir "node_modules/should-not-copy/index.js") -Value "noise" -Encoding Utf8NoBOM
Set-Content -Path (Join-Path $mcpSourceDir "src/index.ts") -Value "noise" -Encoding Utf8NoBOM
Set-Content -Path (Join-Path $mcpSourceDir "tests/index.test.ts") -Value "noise" -Encoding Utf8NoBOM

# local-env-mcp (T-006/T-008): a second first-class MCP that ships by default.
# Seed a minimal payload the same way as sdd-forge-mcp so the installer's
# generic $Mcp selection machinery is exercised for BOTH servers.
$localEnvMcpSourceDir = Join-Path $installerSourceRoot "mcp/local-env-mcp"
New-Item -ItemType Directory -Path (Join-Path $localEnvMcpSourceDir "dist") -Force | Out-Null
Set-Content -Path (Join-Path $localEnvMcpSourceDir "dist/index.js") -Value "console.log('local-env-mcp fixture stub');" -Encoding Utf8NoBOM
Set-Content -Path (Join-Path $localEnvMcpSourceDir "package.json") -Value '{"name":"local-env-mcp","version":"0.1.0","private":true,"type":"module","engines":{"node":">=20"}}' -Encoding Utf8NoBOM
# Files that must NOT be copied into the install root (node_modules/src/tests).
New-Item -ItemType Directory -Path (Join-Path $localEnvMcpSourceDir "node_modules/should-not-copy") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $localEnvMcpSourceDir "src") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $localEnvMcpSourceDir "tests") -Force | Out-Null
Set-Content -Path (Join-Path $localEnvMcpSourceDir "node_modules/should-not-copy/index.js") -Value "noise" -Encoding Utf8NoBOM
Set-Content -Path (Join-Path $localEnvMcpSourceDir "src/index.ts") -Value "noise" -Encoding Utf8NoBOM
Set-Content -Path (Join-Path $localEnvMcpSourceDir "tests/index.test.ts") -Value "noise" -Encoding Utf8NoBOM

# T-007/T-008 (AC-010/011/013/015): install.ps1 registers MCP servers with
# Cursor and VS Code via SDD_CURSOR_DIR / SDD_VSCODE_USER_DIR-overridable config
# paths. Tests must NEVER touch the real user's client configs, so point both at
# non-existent directories inside an isolated root by default (an absent client
# directory means "client not installed" and registration skips). Scenarios that
# exercise the upsert override these per-scenario and restore them afterwards.
$global:SddInstallerIdeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-ide-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $global:SddInstallerIdeRoot -Force | Out-Null
$env:SDD_CURSOR_DIR = Join-Path $global:SddInstallerIdeRoot "cursor-not-installed"
$env:SDD_VSCODE_USER_DIR = Join-Path $global:SddInstallerIdeRoot "vscode-not-installed"

function New-FakeCommands {
    param(
        [Parameter(Mandatory)][string]$BinRoot,
        [Parameter(Mandatory)][string]$LogPath,
        [string]$FailPattern
    )

    New-Item -ItemType Directory -Path $BinRoot -Force | Out-Null
    foreach ($command in @("codex", "claude", "copilot", "gh")) {
        if ($isWindowsPlatform) {
            $commandPath = Join-Path $BinRoot "$command.cmd"
            $failureLine = if ($FailPattern -and $command -ne "gh") { "@echo %*| findstr /c:`"$FailPattern`" >nul && exit /b 9`r`n" } else { "" }
            if ($command -eq "gh") {
                "@echo gh %*>>`"$LogPath`"`r`n@if /i `"%~1`"==auth if /i `"%~2`"==token echo fake-gh-token`r`n@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
            }
            else {
                "@echo $command %*>>`"$LogPath`"`r`n$failureLine@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
            }
        }
        else {
            $commandPath = Join-Path $BinRoot $command
            $failureLine = if ($FailPattern -and $command -ne "gh") { "echo `"`$*`" | grep -F `"$FailPattern`" >/dev/null && exit 9`n" } else { "" }
            if ($command -eq "gh") {
                "#!/bin/sh`necho `"$command `$*`" >> `"$LogPath`"`nif [ `"`$1`" = auth ] && [ `"`$2`" = token ]; then`n    printf '%s\n' fake-gh-token`n    exit 0`nfi`nexit 0`n" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
            }
            else {
                "#!/bin/sh`necho `"$command `$*`" >> `"$LogPath`"`n$failureLine" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
            }
            & chmod +x $commandPath
        }
    }
}

function New-ArchiveFixture {
    param(
        [Parameter(Mandatory)][string]$SourceRoot
    )

    $archiveRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-archive-" + [guid]::NewGuid())
    $archiveSource = Join-Path $archiveRoot "repo"
    $archivePath = Join-Path $archiveRoot "source.tar.gz"
    New-Item -ItemType Directory -Path $archiveSource -Force | Out-Null
    $trackedFiles = & git -C $SourceRoot ls-files
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to enumerate tracked fixture files."
    }
    foreach ($relativePath in $trackedFiles) {
        $destination = Join-Path $archiveSource $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $SourceRoot $relativePath) -Destination $destination -Force
    }
    & tar -czf $archivePath -C $archiveRoot "repo"
    return $archivePath
}

function Resolve-ExpectedPlugins {
    param([Parameter(Mandatory)][string[]]$Plugins)

    $resolved = [System.Collections.Generic.List[string]]::new()
    foreach ($plugin in $Plugins) {
        if (-not $resolved.Contains($plugin)) { $resolved.Add($plugin) }
    }
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($plugin in @($resolved)) {
            $dependencies = switch ($plugin) {
                "sdd-bootstrap" { @("sdd-review-loop"); break }
                "sdd-lite" { @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop"); break }
                "sdd-ship" { @("sdd-bootstrap", "sdd-review-loop", "sdd-implementation", "sdd-quality-loop", "sdd-lite"); break }
                default { @() }
            }
            foreach ($dependency in $dependencies) {
                if (-not $resolved.Contains($dependency)) {
                    $resolved.Add($dependency)
                    $changed = $true
                }
            }
        }
    }
    return @($resolved)
}

function Invoke-InstallerScenario {
    param(
        [Parameter(Mandatory)][string[]]$Plugins,
        [string]$FailPattern,
        [switch]$SeedExistingInstall
    )

    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-test-" + [guid]::NewGuid())
    $installRoot = Join-Path $testRoot "installed"
    $fakeBin = Join-Path $testRoot "bin"
    $commandLog = Join-Path $testRoot "commands.log"
    $originalPath = $env:PATH
    $originalCodexHome = $env:SDD_CODEX_HOME

    try {
        New-FakeCommands -BinRoot $fakeBin -LogPath $commandLog -FailPattern $FailPattern
        $env:PATH = "$fakeBin$([System.IO.Path]::PathSeparator)$originalPath"
        $env:SDD_CODEX_HOME = Join-Path $testRoot "codex-home"

        if ($SeedExistingInstall) {
            New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
            Set-Content -Path (Join-Path $installRoot "existing.marker") -Value "keep" -Encoding Ascii
        }

        $failed = $false
        try {
            & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $installRoot -Target All -Plugins $Plugins
        }
        catch {
            $failed = $true
            if (-not $FailPattern) {
                throw
            }
        }

        if ($FailPattern) {
            if (-not $failed) {
                throw "Installer was expected to fail for pattern: $FailPattern"
            }
            if ($SeedExistingInstall) {
                if (-not (Test-Path (Join-Path $installRoot "existing.marker"))) {
                    throw "Installer did not restore the previous installation."
                }
            }
            elseif (Test-Path $installRoot) {
                throw "Installer left an incomplete initial installation."
            }
            return
        }

        foreach ($plugin in $allPlugins) {
            if (-not (Test-Path (Join-Path $installRoot "plugins/$plugin/.codex-plugin/plugin.json"))) {
                throw "Installer did not copy plugin: $plugin"
            }
        }

        $log = Get-Content -Raw $commandLog
        $expectedRegistration = Resolve-ExpectedPlugins -Plugins $Plugins
        foreach ($plugin in $expectedRegistration) {
            foreach ($expectedCommand in @("codex plugin add $plugin@sdd-plugins", "claude plugin install $plugin@sdd-plugins", "copilot plugin install $plugin@sdd-plugins")) {
                if ($log -notmatch [regex]::Escape($expectedCommand)) {
                    throw "Installer did not run expected command: $expectedCommand"
                }
            }
        }
        # Copilot marketplace command must appear
        if ($log -notmatch [regex]::Escape("copilot plugin marketplace add")) {
            throw "Installer did not run copilot plugin marketplace add"
        }
        if ($log -notmatch [regex]::Escape("codex plugin marketplace add")) {
            throw "Installer did not run codex plugin marketplace add"
        }
        foreach ($plugin in $allPlugins | Where-Object { $_ -notin $expectedRegistration }) {
            if ($log -match [regex]::Escape("plugin add $plugin@sdd-plugins") -or $log -match [regex]::Escape("plugin install $plugin@sdd-plugins")) {
                throw "Installer registered an unselected plugin: $plugin"
            }
        }
    }
    finally {
        $env:PATH = $originalPath
        if ($null -eq $originalCodexHome) {
            Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:SDD_CODEX_HOME = $originalCodexHome
        }
        if (Test-Path $testRoot) {
            Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-RemoteInstallerScenario {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-remote-" + [guid]::NewGuid())
    $installRoot = Join-Path $testRoot "installed"
    $fakeBin = Join-Path $testRoot "bin"
    $commandLog = Join-Path $testRoot "commands.log"
    $originalPath = $env:PATH
    $originalCodexHome = $env:SDD_CODEX_HOME
    $originalGhToken = $env:GH_TOKEN
    $global:SddInstallerFixtureArchivePath = New-ArchiveFixture -SourceRoot $installerSourceRoot

    function global:Invoke-WebRequest {
        param(
            [Parameter(Mandatory)][string]$Uri,
            [hashtable]$Headers,
            [Parameter(Mandatory)][string]$OutFile
        )

        Add-Content -Path $commandLog -Value "Invoke-WebRequest $Uri"
        if ($Headers.Authorization -ne "Bearer fake-gh-token") {
            throw "missing GitHub auth header"
        }
        if ($Uri -notmatch '^https://api\.github\.com/repos/aharada54914/sdd-forge/tarball/main$') {
            throw "unexpected remote download URL: $Uri"
        }
        if ($Uri -match 'raw\.githubusercontent\.com|codeload\.github\.com') {
            throw "remote download still references raw/codeload hosts: $Uri"
        }
        Copy-Item -Path $global:SddInstallerFixtureArchivePath -Destination $OutFile -Force
    }

    try {
        New-FakeCommands -BinRoot $fakeBin -LogPath $commandLog
        $env:PATH = "$fakeBin$([System.IO.Path]::PathSeparator)$originalPath"
        $env:SDD_CODEX_HOME = Join-Path $testRoot "codex-home"
        $env:GH_TOKEN = "fake-gh-token"

        $failed = $false
        try {
            & (Join-Path $repositoryRoot "install.ps1") -InstallRoot $installRoot -Target All -Plugins $allPlugins
        }
        catch {
            $failed = $true
            throw
        }

        foreach ($plugin in $allPlugins) {
            if (-not (Test-Path (Join-Path $installRoot "plugins/$plugin/.codex-plugin/plugin.json"))) {
                throw "Authenticated remote install did not copy plugin: $plugin"
            }
        }

        $log = Get-Content -Raw $commandLog
        if ($log -notmatch 'Invoke-WebRequest https://api\.github\.com/repos/aharada54914/sdd-forge/tarball/main') {
            throw "Authenticated remote install did not use the GitHub API archive URL"
        }
        if ($log -match 'raw\.githubusercontent\.com|codeload\.github\.com') {
            throw "Authenticated remote install still referenced raw/codeload hosts"
        }
        Write-Host "ok: authenticated remote install uses GitHub token flow"
    }
    finally {
        Remove-Item Function:Invoke-WebRequest -ErrorAction SilentlyContinue
        $env:PATH = $originalPath
        if ($null -eq $originalCodexHome) {
            Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:SDD_CODEX_HOME = $originalCodexHome
        }
        if ($null -eq $originalGhToken) {
            Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
        }
        else {
            $env:GH_TOKEN = $originalGhToken
        }
        if (Test-Path $testRoot) {
            Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path (Split-Path -Parent $global:SddInstallerFixtureArchivePath)) {
            Remove-Item -Path (Split-Path -Parent $global:SddInstallerFixtureArchivePath) -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Variable -Name SddInstallerFixtureArchivePath -Scope Global -ErrorAction SilentlyContinue
    }
}

Invoke-InstallerScenario -Plugins $allPlugins
Invoke-InstallerScenario -Plugins @("sdd-bootstrap", "sdd-implementation")
Invoke-InstallerScenario -Plugins @("sdd-lite")
Invoke-InstallerScenario -Plugins $allPlugins -FailPattern "sdd-implementation@sdd-plugins"
Invoke-InstallerScenario -Plugins $allPlugins -FailPattern "sdd-implementation@sdd-plugins" -SeedExistingInstall

$filesOnlyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-filesonly-" + [guid]::NewGuid())
$filesOnlyInstall = Join-Path $filesOnlyRoot "installed"
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $filesOnlyInstall -Target FilesOnly
    $filesOnlyChecks = @(
        ".codex/agents/sdd-investigator.toml",
        "plugins/sdd-quality-loop/.plugin/plugin.json",
        "plugins/sdd-quality-loop/hooks/copilot-hooks.json"
    )
    foreach ($relativePath in $filesOnlyChecks) {
        if (-not (Test-Path (Join-Path $filesOnlyInstall $relativePath))) {
            throw "FilesOnly install did not copy: $relativePath"
        }
    }
}
finally {
    if (Test-Path $filesOnlyRoot) {
        Remove-Item -Path $filesOnlyRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A local source is a Git worktree; untracked files must never be staged.
$trackedOnlyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-tracked-only-" + [guid]::NewGuid())
$trackedOnlySource = Join-Path $trackedOnlyRoot "source"
$trackedOnlyInstall = Join-Path $trackedOnlyRoot "installed"
try {
    New-TrackedFixture -Source $installerSourceRoot -Destination $trackedOnlySource
    New-Item -ItemType Directory -Path (Join-Path $trackedOnlySource ".private") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $trackedOnlySource "plugins/sdd-bootstrap/.private") -Force | Out-Null
    Set-Content -Path (Join-Path $trackedOnlySource ".private/secret.txt") -Value "root-secret" -Encoding Ascii
    Set-Content -Path (Join-Path $trackedOnlySource "plugins/sdd-bootstrap/.private/secret.txt") -Value "nested-secret" -Encoding Ascii
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $trackedOnlySource -InstallRoot $trackedOnlyInstall -Target FilesOnly -SkipPluginInstall -SkipAgentInstall
    foreach ($leakedPath in @(".private/secret.txt", "plugins/sdd-bootstrap/.private/secret.txt")) {
        if (Test-Path (Join-Path $trackedOnlyInstall $leakedPath)) {
            throw "Tracked-only local source leaked untracked file: $leakedPath"
        }
    }
    Write-Host "ok: local source installs Git-tracked files only"
}
finally {
    if (Test-Path $trackedOnlyRoot) { Remove-Item -Path $trackedOnlyRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# A required release file must be Git-tracked too; otherwise strict local
# staging would omit it while reporting a successful installation.
$untrackedRequiredRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-untracked-required-" + [guid]::NewGuid())
$untrackedRequiredSource = Join-Path $untrackedRequiredRoot "source"
$untrackedRequiredInstall = Join-Path $untrackedRequiredRoot "installed"
try {
    New-TrackedFixture -Source $installerSourceRoot -Destination $untrackedRequiredSource
    & git -C $untrackedRequiredSource rm --cached -q "plugins/sdd-review-loop/.codex-plugin/plugin.json"
    if ($LASTEXITCODE -ne 0) { throw "Could not prepare untracked required-file fixture" }
    New-Item -ItemType Directory -Path $untrackedRequiredInstall -Force | Out-Null
    Set-Content -Path (Join-Path $untrackedRequiredInstall "existing.marker") -Value "keep" -Encoding Ascii
    $untrackedRequiredFailed = $false
    $untrackedRequiredOutput = ""
    try {
        $untrackedRequiredOutput = & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $untrackedRequiredSource -InstallRoot $untrackedRequiredInstall -Target FilesOnly 2>&1 | Out-String
    }
    catch {
        $untrackedRequiredFailed = $true
        $untrackedRequiredOutput = $_ | Out-String
    }
    if (-not $untrackedRequiredFailed) { throw "Installer accepted an untracked required manifest" }
    if (-not (Test-Path (Join-Path $untrackedRequiredInstall "existing.marker"))) {
        throw "Installer modified an existing install before rejecting an untracked required manifest"
    }
    if ($untrackedRequiredOutput -notmatch "not Git-tracked") {
        throw "Expected Git-tracked validation error was not reported: $untrackedRequiredOutput"
    }
    Write-Host "ok: untracked required release file is rejected before deployment"
}
finally {
    # Best-effort cleanup: transient git object files can vanish mid-enumeration
    # on Linux pwsh (observed flake in CI); the assertion above already ran.
    if (Test-Path $untrackedRequiredRoot) { Remove-Item -Path $untrackedRequiredRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

$preDeploymentRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-predeploy-" + [guid]::NewGuid())
$badSourceRoot = Join-Path $preDeploymentRoot "bad-source"
$existingInstallRoot = Join-Path $preDeploymentRoot "installed"
try {
    New-Item -ItemType Directory -Path $badSourceRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $existingInstallRoot -Force | Out-Null
    Set-Content -Path (Join-Path $existingInstallRoot "existing.marker") -Value "keep" -Encoding Ascii
    $preDeploymentFailed = $false
    $preDeploymentError = ""
    try {
        & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $badSourceRoot -InstallRoot $existingInstallRoot -Target FilesOnly
    }
    catch {
        $preDeploymentFailed = $true
        $preDeploymentError = $_.Exception.Message
    }
    if (-not $preDeploymentFailed) {
        throw "Installer accepted an invalid source directory."
    }
    if (-not (Test-Path (Join-Path $existingInstallRoot "existing.marker"))) {
        throw "Installer removed the existing installation before deployment started."
    }
    if ($preDeploymentError -notmatch "Git worktree") {
        throw "Non-Git source directory did not report the Git worktree requirement."
    }
}
finally {
    if (Test-Path $preDeploymentRoot) {
        Remove-Item -Path $preDeploymentRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$invalidFailed = $false
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot (Join-Path $env:TEMP ([guid]::NewGuid())) -Target FilesOnly -Plugins @("not-a-plugin")
}
catch {
    $invalidFailed = $true
}
if (-not $invalidFailed) {
    throw "Installer accepted an invalid plugin name."
}

# ---------------------------------------------------------------------------
# Idempotency: second successful install into same root exits 0, state consistent
# ---------------------------------------------------------------------------
$idempotencyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-idempotency-" + [guid]::NewGuid())
$idempotencyInstall = Join-Path $idempotencyRoot "installed"
$idempotencyBin = Join-Path $idempotencyRoot "bin"
$idempotencyLog = Join-Path $idempotencyRoot "commands.log"
$savedPath = $env:PATH
$idempotencyOriginalCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $idempotencyBin -LogPath $idempotencyLog
    $env:PATH = "$idempotencyBin$([System.IO.Path]::PathSeparator)$savedPath"
    $env:SDD_CODEX_HOME = Join-Path $idempotencyRoot "codex-home"
    # First install
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $idempotencyInstall -Target All -Plugins $allPlugins
    # Second install (idempotent)
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $idempotencyInstall -Target All -Plugins $allPlugins
    foreach ($plugin in $allPlugins) {
        if (-not (Test-Path (Join-Path $idempotencyInstall "plugins/$plugin/.codex-plugin/plugin.json"))) {
            throw "Idempotency: plugin not present after second install: $plugin"
        }
    }
    if (Test-Path (Join-Path $idempotencyInstall ".git")) {
        throw "Idempotency: .git repository history was installed"
    }
    Write-Host "ok: idempotency: second install exits 0, state consistent"
}
finally {
    $env:PATH = $savedPath
    if ($null -eq $idempotencyOriginalCodexHome) {
        Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:SDD_CODEX_HOME = $idempotencyOriginalCodexHome
    }
    if (Test-Path $idempotencyRoot) { Remove-Item -Path $idempotencyRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# No-nesting assertion after install
# ---------------------------------------------------------------------------
$nonestingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-nonest-" + [guid]::NewGuid())
$nonestingInstall = Join-Path $nonestingRoot "installed"
$nonestingBin = Join-Path $nonestingRoot "bin"
$nonestingLog = Join-Path $nonestingRoot "commands.log"
$savedPath2 = $env:PATH
$nonestingOriginalCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $nonestingBin -LogPath $nonestingLog
    $env:PATH = "$nonestingBin$([System.IO.Path]::PathSeparator)$savedPath2"
    $env:SDD_CODEX_HOME = Join-Path $nonestingRoot "codex-home"
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $nonestingInstall -Target All -Plugins $allPlugins
    foreach ($nested in @(".agents/.agents", ".codex/.codex", ".claude-plugin/.claude-plugin")) {
        if (Test-Path (Join-Path $nonestingInstall $nested)) {
            throw "No-nesting: found unexpected nested directory: $nested"
        }
    }
    foreach ($toml in @(".codex/agents/sdd-investigator.toml", ".codex/agents/sdd-evaluator.toml")) {
        if (-not (Test-Path (Join-Path $nonestingInstall $toml))) {
            throw "No-nesting: expected file missing after install: $toml"
        }
    }
    Write-Host "ok: no-nesting: layout correct after install"
}
finally {
    $env:PATH = $savedPath2
    if ($null -eq $nonestingOriginalCodexHome) {
        Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:SDD_CODEX_HOME = $nonestingOriginalCodexHome
    }
    if (Test-Path $nonestingRoot) { Remove-Item -Path $nonestingRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Codex agent install + malformed-role diagnostic
# ---------------------------------------------------------------------------
$malformedRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-malformed-" + [guid]::NewGuid())
$malformedInstall = Join-Path $malformedRoot "installed"
$malformedCodexHome = Join-Path $malformedRoot "codex-home"
$malformedCodexAgents = Join-Path $malformedCodexHome "agents"
$malformedBin = Join-Path $malformedRoot "bin"
$malformedLog = Join-Path $malformedRoot "commands.log"
$malformedSavedPath = $env:PATH
$malformedSavedCodexHome = $env:SDD_CODEX_HOME
try {
    New-Item -ItemType Directory -Path $malformedCodexAgents -Force | Out-Null
    Set-Content -Path (Join-Path $malformedCodexAgents "auditor.toml") -Value 'name = "auditor"' -Encoding Utf8
    New-FakeCommands -BinRoot $malformedBin -LogPath $malformedLog
    $env:PATH = "$malformedBin$([System.IO.Path]::PathSeparator)$malformedSavedPath"
    $env:SDD_CODEX_HOME = $malformedCodexHome
    # *>&1 also merges the warning stream; 2>&1 alone would miss Write-Warning.
    $malformedOutput = & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $malformedInstall -Target All *>&1 | Out-String
    # Verify agents were installed with developer_instructions
    if (-not (Test-Path (Join-Path $malformedCodexAgents "sdd-investigator.toml"))) {
        throw "sdd-investigator.toml was not installed. Installer output:`n$malformedOutput"
    }
    if (-not (Test-Path (Join-Path $malformedCodexAgents "sdd-evaluator.toml"))) {
        throw "sdd-evaluator.toml was not installed"
    }
    $investigatorContent = Get-Content -Path (Join-Path $malformedCodexAgents "sdd-investigator.toml") -Raw
    if ($investigatorContent -notmatch '(?m)^developer_instructions\s*=') {
        throw "sdd-investigator.toml missing developer_instructions"
    }
    $evaluatorContent = Get-Content -Path (Join-Path $malformedCodexAgents "sdd-evaluator.toml") -Raw
    if ($evaluatorContent -notmatch '(?m)^developer_instructions\s*=') {
        throw "sdd-evaluator.toml missing developer_instructions"
    }
    # Verify warning output
    if ($malformedOutput -notmatch "Ignoring malformed agent role definition") {
        throw "Expected warning about malformed agent not found in output"
    }
    if ($malformedOutput -notmatch "auditor\.toml") {
        throw "Expected auditor.toml path not found in output"
    }
    # Verify auditor.toml unchanged (Set-Content appends a newline, so trim before comparing)
    $auditorContent = (Get-Content -Path (Join-Path $malformedCodexAgents "auditor.toml") -Raw).Trim()
    if ($auditorContent -ne 'name = "auditor"') {
        throw "auditor.toml was modified"
    }
    if ($auditorContent -match 'developer_instructions') {
        throw "auditor.toml unexpectedly gained developer_instructions"
    }
    Write-Host "ok: codex agent install + malformed-role diagnostic"
}
finally {
    $env:PATH = $malformedSavedPath
    if ($null -eq $malformedSavedCodexHome) {
        Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:SDD_CODEX_HOME = $malformedSavedCodexHome
    }
    if (Test-Path $malformedRoot) { Remove-Item -Path $malformedRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Malformed source agent TOML rejected before deployment
# ---------------------------------------------------------------------------
$badDeployRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-baddeploy-" + [guid]::NewGuid())
$badDeploySource = Join-Path $badDeployRoot "bad-source"
$badDeployInstall = Join-Path $badDeployRoot "installed"
try {
    New-TrackedFixture -Source $installerSourceRoot -Destination $badDeploySource
    # Keep the malformed TOML tracked so validation is exercised after the
    # source-directory Git worktree check.
    $investigatorPath = Join-Path $badDeploySource ".codex/agents/sdd-investigator.toml"
    Set-Content -Path $investigatorPath -Value 'name = "sdd-investigator"' -Encoding Utf8
    & git -C $badDeploySource add .codex/agents/sdd-investigator.toml
    & git -C $badDeploySource -c user.name="Installer Test" -c user.email="installer-test@example.invalid" commit -qm "Malformed agent fixture"
    if ($LASTEXITCODE -ne 0) { throw "Could not commit malformed source fixture." }
    # Pre-create install root with existing.marker
    New-Item -ItemType Directory -Path $badDeployInstall -Force | Out-Null
    Set-Content -Path (Join-Path $badDeployInstall "existing.marker") -Value "keep" -Encoding Ascii
    $badDeployFailed = $false
    try {
        & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $badDeploySource -InstallRoot $badDeployInstall -Target FilesOnly
    }
    catch {
        $badDeployFailed = $true
    }
    if (-not $badDeployFailed) {
        throw "Installer accepted malformed source TOML"
    }
    if (-not (Test-Path (Join-Path $badDeployInstall "existing.marker"))) {
        throw "existing.marker was removed before deployment"
    }
Write-Host "ok: malformed source agent TOML rejected before deployment"
}
finally {
    if (Test-Path $badDeployRoot) { Remove-Item -Path $badDeployRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Invoke-RemoteInstallerScenario

# ---------------------------------------------------------------------------
# Lock scenario (l): concurrent install is blocked when mutex is already held
# ---------------------------------------------------------------------------
$lockTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-lock-" + [guid]::NewGuid())
$lockInstallRoot = Join-Path $lockTestRoot "installed"
$lockBin = Join-Path $lockTestRoot "bin"
$lockLog = Join-Path $lockTestRoot "commands.log"
$lockSavedPath = $env:PATH
$lockSavedCodexHome = $env:SDD_CODEX_HOME
$holderJob = $null
try {
    New-FakeCommands -BinRoot $lockBin -LogPath $lockLog
    $env:PATH = "$lockBin$([System.IO.Path]::PathSeparator)$lockSavedPath"
    $env:SDD_CODEX_HOME = Join-Path $lockTestRoot "codex-home"

    # Compute the same mutex name as install.ps1 will compute for $lockInstallRoot
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $rootBytes = [System.Text.Encoding]::UTF8.GetBytes($lockInstallRoot.ToLower())
    $hashBytes = $sha256.ComputeHash($rootBytes)
    $sha256.Dispose()
    $rootHash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    $mutexName = "Global\sdd-forge-install-$rootHash"

    # Hold the mutex in a SEPARATE process so the installer (invoked in-process
    # below) cannot reentrantly acquire it. .NET mutexes are reentrant for the
    # owning thread, so an in-process holder would let the same-thread installer
    # acquire immediately and defeat the test. Start-Job runs in a child
    # process; named mutexes are visible across processes on Windows, Linux, and
    # macOS, so this exercises real cross-process exclusion.
    $holderReady = Join-Path $lockTestRoot "holder-ready"
    $holderJob = Start-Job -ScriptBlock {
        param($name, $ready)
        $m = New-Object System.Threading.Mutex($false, $name)
        [void]$m.WaitOne()
        New-Item -ItemType File -Path $ready -Force | Out-Null
        Start-Sleep -Seconds 30
        try { $m.ReleaseMutex() } catch { }
        $m.Dispose()
    } -ArgumentList $mutexName, $holderReady

    # Wait (up to ~15s) for the holder process to actually acquire the mutex.
    $holderWait = 0
    while (-not (Test-Path $holderReady) -and $holderWait -lt 150) {
        Start-Sleep -Milliseconds 100
        $holderWait++
    }
    if (-not (Test-Path $holderReady)) {
        throw "Lock scenario (l): holder job failed to acquire the mutex"
    }

    $env:SDD_INSTALL_LOCK_TIMEOUT = "1"
    $lockFailed = $false
    try {
        & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $lockInstallRoot -Target FilesOnly -SkipPluginInstall -SkipAgentInstall
    }
    catch {
        $lockFailed = $true
        if ($_ -notmatch "in progress") {
            throw "Lock scenario (l): expected 'in progress' in error but got: $_"
        }
    }
    finally {
        Remove-Item Env:SDD_INSTALL_LOCK_TIMEOUT -ErrorAction SilentlyContinue
    }
    if (-not $lockFailed) {
        throw "Lock scenario (l): installer should have failed when mutex is held"
    }
    if (Test-Path $lockInstallRoot) {
        throw "Lock scenario (l): INSTALL_ROOT was modified while mutex was held"
    }

    # Stop the holder process (its mutex is released when the child exits) and
    # verify a normal install now succeeds.
    Stop-Job $holderJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $holderJob -Force -ErrorAction SilentlyContinue | Out-Null
    $holderJob = $null

    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $lockInstallRoot -Target FilesOnly -SkipPluginInstall -SkipAgentInstall

    Write-Host "ok: lock: concurrent install blocked, succeeds after mutex released"
}
finally {
    if ($holderJob) {
        Stop-Job $holderJob -ErrorAction SilentlyContinue | Out-Null
        Remove-Job $holderJob -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $env:PATH = $lockSavedPath
    if ($null -eq $lockSavedCodexHome) {
        Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:SDD_CODEX_HOME = $lockSavedCodexHome
    }
    Remove-Item Env:SDD_INSTALL_LOCK_TIMEOUT -ErrorAction SilentlyContinue
    if (Test-Path $lockTestRoot) { Remove-Item -Path $lockTestRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Lock scenario (m): lock released on success — mutex not held after install
# ---------------------------------------------------------------------------
$lockSuccessRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-locksucc-" + [guid]::NewGuid())
$lockSuccessInstall = Join-Path $lockSuccessRoot "installed"
$lockSuccessBin = Join-Path $lockSuccessRoot "bin"
$lockSuccessLog = Join-Path $lockSuccessRoot "commands.log"
$lockSuccessSavedPath = $env:PATH
$lockSuccessSavedCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $lockSuccessBin -LogPath $lockSuccessLog
    $env:PATH = "$lockSuccessBin$([System.IO.Path]::PathSeparator)$lockSuccessSavedPath"
    $env:SDD_CODEX_HOME = Join-Path $lockSuccessRoot "codex-home"

    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $lockSuccessInstall -Target FilesOnly -SkipPluginInstall -SkipAgentInstall

    # Verify the mutex is no longer held: we should be able to acquire it immediately
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $rootBytes = [System.Text.Encoding]::UTF8.GetBytes($lockSuccessInstall.ToLower())
    $hashBytes = $sha256.ComputeHash($rootBytes)
    $sha256.Dispose()
    $rootHash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    $mutexName = "Global\sdd-forge-install-$rootHash"

    $checkMutex = New-Object System.Threading.Mutex($false, $mutexName)
    $canAcquire = $false
    try {
        $canAcquire = $checkMutex.WaitOne([TimeSpan]::FromSeconds(0))
    }
    catch [System.Threading.AbandonedMutexException] {
        $canAcquire = $true
    }
    finally {
        if ($canAcquire) { try { $checkMutex.ReleaseMutex() } catch { } }
        $checkMutex.Dispose()
    }
    if (-not $canAcquire) {
        throw "Lock scenario (m): mutex was not released after successful install"
    }

    Write-Host "ok: lock: released on success — mutex acquirable after install"
}
finally {
    $env:PATH = $lockSuccessSavedPath
    if ($null -eq $lockSuccessSavedCodexHome) {
        Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:SDD_CODEX_HOME = $lockSuccessSavedCodexHome
    }
    if (Test-Path $lockSuccessRoot) { Remove-Item -Path $lockSuccessRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Scenario (D): post-install functional smoke — run installed check-risk gate
# ---------------------------------------------------------------------------
$smokeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-smoke-" + [guid]::NewGuid())
$smokeInstall = Join-Path $smokeRoot "installed"
$smokeBin = Join-Path $smokeRoot "bin"
$smokeLog = Join-Path $smokeRoot "commands.log"
$smokeFixtures = Join-Path $smokeRoot "fixtures"
$smokeSavedPath = $env:PATH
$smokeSavedCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $smokeBin -LogPath $smokeLog
    $env:PATH = "$smokeBin$([System.IO.Path]::PathSeparator)$smokeSavedPath"
    $env:SDD_CODEX_HOME = Join-Path $smokeRoot "codex-home"
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $smokeInstall -Target FilesOnly -SkipPluginInstall -SkipAgentInstall

    $smokeGate = Join-Path $smokeInstall "plugins/sdd-quality-loop/scripts/check-risk.ps1"
    if (-not (Test-Path $smokeGate)) {
        throw "smoke (D): installed check-risk.ps1 not found at: $smokeGate"
    }

    New-Item -ItemType Directory -Path $smokeFixtures -Force | Out-Null

    # Pass fixture: high-risk task with Required Workflow: tdd
    $passFixture = Join-Path $smokeFixtures "pass.md"
    Set-Content -Path $passFixture -Encoding Utf8NoBOM -Value @"
## T-001
Risk: high
Risk Rationale: affects critical auth path
Required Workflow: tdd
"@

    # Fail fixture: high-risk task missing Required Workflow: tdd
    $failFixture = Join-Path $smokeFixtures "fail.md"
    Set-Content -Path $failFixture -Encoding Utf8NoBOM -Value @"
## T-001
Risk: high
Risk Rationale: affects critical auth path
"@

    # Pass path: must exit 0
    $passExitCode = 0
    try {
        & pwsh -NoProfile -NonInteractive -File $smokeGate -TasksPath $passFixture | Out-Null
        $passExitCode = $LASTEXITCODE
    } catch {
        $passExitCode = 1
    }
    if ($passExitCode -eq 0) {
        Write-Host "ok: smoke (D): installed gate exits 0 for well-formed high+tdd task"
    } else {
        throw "smoke (D): installed gate unexpectedly failed on well-formed task (exit $passExitCode)"
    }

    # Fail path: must exit non-zero
    $failExitCode = 0
    try {
        & pwsh -NoProfile -NonInteractive -File $smokeGate -TasksPath $failFixture | Out-Null
        $failExitCode = $LASTEXITCODE
    } catch {
        $failExitCode = 1
    }
    if ($failExitCode -ne 0) {
        Write-Host "ok: smoke (D): installed gate exits non-zero for high task missing Required Workflow: tdd"
    } else {
        throw "smoke (D): installed gate incorrectly passed on task missing Required Workflow: tdd"
    }
}
finally {
    $env:PATH = $smokeSavedPath
    if ($null -eq $smokeSavedCodexHome) {
        Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
    } else {
        $env:SDD_CODEX_HOME = $smokeSavedCodexHome
    }
    if (Test-Path $smokeRoot) { Remove-Item -Path $smokeRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# MCP scenarios (T-006): AC-007 / AC-008
# ---------------------------------------------------------------------------

# Scenario (t): default install places the MCP payload and registers it,
# excluding node_modules/src/tests.
$mcpDefaultRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-default-" + [guid]::NewGuid())
$mcpDefaultInstall = Join-Path $mcpDefaultRoot "installed"
$mcpDefaultBin = Join-Path $mcpDefaultRoot "bin"
$mcpDefaultLog = Join-Path $mcpDefaultRoot "commands.log"
$mcpDefaultOriginalPath = $env:PATH
$mcpDefaultOriginalCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $mcpDefaultBin -LogPath $mcpDefaultLog
    $env:PATH = "$mcpDefaultBin$([System.IO.Path]::PathSeparator)$mcpDefaultOriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $mcpDefaultRoot "codex-home"
    New-Item -ItemType Directory -Path $env:SDD_CODEX_HOME -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Force | Out-Null

    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $mcpDefaultInstall -Target All -SkipAgentInstall

    foreach ($mcpName in @("sdd-forge-mcp", "local-env-mcp")) {
        if (-not (Test-Path (Join-Path $mcpDefaultInstall "mcp/$mcpName/dist/index.js"))) {
            throw "default MCP install (t): $mcpName dist/index.js not placed"
        }
        if (-not (Test-Path (Join-Path $mcpDefaultInstall "mcp/$mcpName/package.json"))) {
            throw "default MCP install (t): $mcpName package.json not placed"
        }
        if (Test-Path (Join-Path $mcpDefaultInstall "mcp/$mcpName/node_modules")) {
            throw "default MCP install (t): $mcpName node_modules was copied"
        }
        if (Test-Path (Join-Path $mcpDefaultInstall "mcp/$mcpName/src")) {
            throw "default MCP install (t): $mcpName src/ was copied"
        }
        if (Test-Path (Join-Path $mcpDefaultInstall "mcp/$mcpName/tests")) {
            throw "default MCP install (t): $mcpName tests/ was copied"
        }
    }
    $mcpDefaultLogContent = Get-Content -Raw $mcpDefaultLog
    if ($mcpDefaultLogContent -notmatch [regex]::Escape("claude mcp add sdd-forge-mcp")) {
        throw "default MCP install (t): claude mcp add not invoked for sdd-forge-mcp"
    }
    if ($mcpDefaultLogContent -notmatch [regex]::Escape("claude mcp add local-env-mcp")) {
        throw "default MCP install (t): claude mcp add not invoked for local-env-mcp"
    }
    $configTomlContent = Get-Content -Raw (Join-Path $env:SDD_CODEX_HOME "config.toml")
    if ($configTomlContent -notmatch "sdd-forge-mcp") {
        throw "default MCP install (t): Codex config.toml missing sdd-forge-mcp entry"
    }
    if ($configTomlContent -notmatch "local-env-mcp") {
        throw "default MCP install (t): Codex config.toml missing local-env-mcp entry"
    }
    Write-Host "ok: default install places and registers BOTH MCP servers"
}
finally {
    $env:PATH = $mcpDefaultOriginalPath
    if ($null -eq $mcpDefaultOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $mcpDefaultOriginalCodexHome }
    if (Test-Path $mcpDefaultRoot) { Remove-Item -Path $mcpDefaultRoot -Recurse -Force }
}

# Scenario (u): -SkipMcp skips both placement and registration, and leaves
# seeded Cursor / VS Code configs untouched (T-007/T-008 gating parity).
$mcpSkipRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-skip-" + [guid]::NewGuid())
$mcpSkipInstall = Join-Path $mcpSkipRoot "installed"
$mcpSkipBin = Join-Path $mcpSkipRoot "bin"
$mcpSkipLog = Join-Path $mcpSkipRoot "commands.log"
$mcpSkipOriginalPath = $env:PATH
$mcpSkipOriginalCodexHome = $env:SDD_CODEX_HOME
$mcpSkipOriginalCursorDir = $env:SDD_CURSOR_DIR
$mcpSkipOriginalVSCodeDir = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $mcpSkipBin -LogPath $mcpSkipLog
    $env:PATH = "$mcpSkipBin$([System.IO.Path]::PathSeparator)$mcpSkipOriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $mcpSkipRoot "codex-home"
    New-Item -ItemType Directory -Path $env:SDD_CODEX_HOME -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Force | Out-Null
    $env:SDD_CURSOR_DIR = Join-Path $mcpSkipRoot "cursor"
    $env:SDD_VSCODE_USER_DIR = Join-Path $mcpSkipRoot "vscode-user"
    New-Item -ItemType Directory -Path $env:SDD_CURSOR_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $env:SDD_VSCODE_USER_DIR -Force | Out-Null
    Set-Content -Path (Join-Path $env:SDD_CURSOR_DIR "mcp.json") -Value "{`n  `"mcpServers`": {}`n}`n" -Encoding Utf8NoBOM -NoNewline
    Set-Content -Path (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json") -Value "{`n  `"servers`": {}`n}`n" -Encoding Utf8NoBOM -NoNewline
    $cursorBefore = Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")
    $vscodeBefore = Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")

    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $mcpSkipInstall -Target All -SkipAgentInstall -SkipMcp

    if (Test-Path (Join-Path $mcpSkipInstall "mcp")) {
        throw "-SkipMcp (u): mcp/ was placed despite -SkipMcp"
    }
    if (Test-Path $mcpSkipLog) {
        $mcpSkipLogContent = Get-Content -Raw $mcpSkipLog
        if ($mcpSkipLogContent -match [regex]::Escape("claude mcp add")) {
            throw "-SkipMcp (u): claude mcp add was invoked despite -SkipMcp"
        }
    }
    $configTomlContent = Get-Content -Raw (Join-Path $env:SDD_CODEX_HOME "config.toml")
    if ($configTomlContent -match "sdd-forge-mcp") {
        throw "-SkipMcp (u): Codex config.toml was modified despite -SkipMcp"
    }
    if ((Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")) -ne $cursorBefore) {
        throw "-SkipMcp (u): Cursor mcp.json was modified despite -SkipMcp"
    }
    if ((Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")) -ne $vscodeBefore) {
        throw "-SkipMcp (u): VS Code mcp.json was modified despite -SkipMcp"
    }
    Write-Host "ok: -SkipMcp skips both MCP placement and registration"
}
finally {
    $env:PATH = $mcpSkipOriginalPath
    if ($null -eq $mcpSkipOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $mcpSkipOriginalCodexHome }
    $env:SDD_CURSOR_DIR = $mcpSkipOriginalCursorDir
    $env:SDD_VSCODE_USER_DIR = $mcpSkipOriginalVSCodeDir
    if (Test-Path $mcpSkipRoot) { Remove-Item -Path $mcpSkipRoot -Recurse -Force }
}

# Scenario (v): -Mcp sdd-forge-mcp installs ONLY sdd-forge-mcp (AC-013 single-MCP
# selection); an invalid MCP name is rejected.
$mcpValidRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-valid-" + [guid]::NewGuid())
$mcpValidInstall = Join-Path $mcpValidRoot "installed"
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $mcpValidInstall -Target FilesOnly -Mcp @("sdd-forge-mcp")
    if (-not (Test-Path (Join-Path $mcpValidInstall "mcp/sdd-forge-mcp/dist/index.js"))) {
        throw "-Mcp sdd-forge-mcp (v): dist/index.js not placed"
    }
    # AC-013 behavior: selecting only sdd-forge-mcp must NOT place local-env-mcp.
    if (Test-Path (Join-Path $mcpValidInstall "mcp/local-env-mcp")) {
        throw "-Mcp sdd-forge-mcp (v): local-env-mcp was placed despite not being selected"
    }
    Write-Host "ok: -Mcp sdd-forge-mcp installs only the selected MCP"
}
finally {
    if (Test-Path $mcpValidRoot) { Remove-Item -Path $mcpValidRoot -Recurse -Force }
}

# Scenario (v-le): -Mcp local-env-mcp is a valid selection that places ONLY
# local-env-mcp (sdd-forge-mcp absent). Confirms local-env-mcp is in the
# ValidateSet and per-name selection is honoured in both directions (AC-013).
$mcpLeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-le-" + [guid]::NewGuid())
$mcpLeInstall = Join-Path $mcpLeRoot "installed"
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $mcpLeInstall -Target FilesOnly -Mcp @("local-env-mcp")
    if (-not (Test-Path (Join-Path $mcpLeInstall "mcp/local-env-mcp/dist/index.js"))) {
        throw "-Mcp local-env-mcp (v-le): local-env-mcp dist/index.js not placed"
    }
    if (Test-Path (Join-Path $mcpLeInstall "mcp/sdd-forge-mcp")) {
        throw "-Mcp local-env-mcp (v-le): sdd-forge-mcp was placed despite not being selected"
    }
    Write-Host "ok: -Mcp local-env-mcp installs only the selected MCP"
}
finally {
    if (Test-Path $mcpLeRoot) { Remove-Item -Path $mcpLeRoot -Recurse -Force }
}

$mcpInvalidRejected = $false
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-bogus-" + [guid]::NewGuid())) -Target FilesOnly -Mcp @("bogus-mcp") 2>$null
}
catch {
    $mcpInvalidRejected = $true
}
if (-not $mcpInvalidRejected) {
    throw "-Mcp bogus-mcp (v2): installer accepted an invalid MCP name"
}
Write-Host "ok: -Mcp bogus-mcp is rejected"

# Scenario (v3): -Mcp "" (empty value) is rejected cleanly by ValidateSet
# parameter binding rather than being silently accepted as "no MCP selected".
$mcpEmptyRejected = $false
$mcpEmptyError = $null
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-empty-" + [guid]::NewGuid())) -Target FilesOnly -Mcp "" 2>$null
}
catch {
    $mcpEmptyRejected = $true
    $mcpEmptyError = $_
}
if (-not $mcpEmptyRejected) {
    throw "-Mcp `"`" (v3): installer accepted an empty MCP value"
}
if ($mcpEmptyError -and ($mcpEmptyError.Exception.Message -match "unbound variable")) {
    throw "-Mcp `"`" (v3): installer crashed with an unbound variable error"
}
Write-Host "ok: -Mcp `"`" (empty) is rejected"

# Scenario (v4): -Plugins "" (empty value) is rejected cleanly by ValidateSet
# parameter binding (mirrors install.sh's guard against bash 3.2's
# unbound-variable crash on an empty --plugins list).
$pluginsEmptyRejected = $false
$pluginsEmptyError = $null
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-plugins-empty-" + [guid]::NewGuid())) -Target FilesOnly -Plugins "" 2>$null
}
catch {
    $pluginsEmptyRejected = $true
    $pluginsEmptyError = $_
}
if (-not $pluginsEmptyRejected) {
    throw "-Plugins `"`" (v4): installer accepted an empty plugin value"
}
if ($pluginsEmptyError -and ($pluginsEmptyError.Exception.Message -match "unbound variable")) {
    throw "-Plugins `"`" (v4): installer crashed with an unbound variable error"
}
Write-Host "ok: -Plugins `"`" (empty) is rejected"

# Scenario (w): missing Node >= 20 warns and skips MCP only; plugins still
# install. Shadow `node` with a fake old-version binary.
$mcpOldNodeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-oldnode-" + [guid]::NewGuid())
$mcpOldNodeInstall = Join-Path $mcpOldNodeRoot "installed"
$mcpOldNodeBin = Join-Path $mcpOldNodeRoot "bin"
$mcpOldNodeLog = Join-Path $mcpOldNodeRoot "commands.log"
$mcpOldNodeOriginalPath = $env:PATH
try {
    New-FakeCommands -BinRoot $mcpOldNodeBin -LogPath $mcpOldNodeLog
    if ($isWindowsPlatform) {
        $nodeShimPath = Join-Path $mcpOldNodeBin "node.cmd"
        "@if `"%~1`"==`"--version`" (echo v14.21.0`r`n) else (exit /b 0)`r`n" | Set-Content -Path $nodeShimPath -Encoding Ascii
    }
    else {
        $nodeShimPath = Join-Path $mcpOldNodeBin "node"
        "#!/bin/sh`nif [ `"`$1`" = --version ]; then echo v14.21.0; exit 0; fi`nexit 0`n" | Set-Content -Path $nodeShimPath -Encoding Utf8NoBOM
        & chmod +x $nodeShimPath
    }
    $env:PATH = "$mcpOldNodeBin$([System.IO.Path]::PathSeparator)$mcpOldNodeOriginalPath"

    $warnings = $null
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $mcpOldNodeInstall -Target FilesOnly -WarningVariable warnings -WarningAction SilentlyContinue

    if (Test-Path (Join-Path $mcpOldNodeInstall "mcp")) {
        throw "old Node (w): MCP was placed despite Node < 20"
    }
    foreach ($plugin in $allPlugins) {
        if (-not (Test-Path (Join-Path $mcpOldNodeInstall "plugins/$plugin/.codex-plugin/plugin.json"))) {
            throw "old Node (w): plugin not copied despite MCP-only skip: $plugin"
        }
    }
    if (-not ($warnings | Where-Object { $_.Message -match "(?i)node" })) {
        throw "old Node (w): expected warning mentioning Node was not raised"
    }
    Write-Host "ok: Node < 20 warns and skips MCP only, plugin install continues"
}
finally {
    $env:PATH = $mcpOldNodeOriginalPath
    if (Test-Path $mcpOldNodeRoot) { Remove-Item -Path $mcpOldNodeRoot -Recurse -Force }
}

# Scenario (w2): Node < 20 boundary (v18.x) for the DEFAULT multi-MCP install
# under -Target All. requirements.md Edge Case: "Node < 20 → 既存の MCP 配置
# ゲート(MCP_NODE_OK)により配置・登録とも行わない". A v18.x node shim ahead of
# the real node must cause NO placement of EITHER MCP and NO Claude/Codex/
# Cursor/VS Code registration, while a warning mentioning Node is raised.
$mcpV18Root = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-v18-" + [guid]::NewGuid())
$mcpV18Install = Join-Path $mcpV18Root "installed"
$mcpV18Bin = Join-Path $mcpV18Root "bin"
$mcpV18Log = Join-Path $mcpV18Root "commands.log"
$mcpV18OriginalPath = $env:PATH
$mcpV18OriginalCodexHome = $env:SDD_CODEX_HOME
$mcpV18OriginalCursorDir = $env:SDD_CURSOR_DIR
$mcpV18OriginalVSCodeDir = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $mcpV18Bin -LogPath $mcpV18Log
    if ($isWindowsPlatform) {
        $v18ShimPath = Join-Path $mcpV18Bin "node.cmd"
        "@if `"%~1`"==`"--version`" (echo v18.19.0`r`n) else (exit /b 0)`r`n" | Set-Content -Path $v18ShimPath -Encoding Ascii
    }
    else {
        $v18ShimPath = Join-Path $mcpV18Bin "node"
        "#!/bin/sh`nif [ `"`$1`" = --version ]; then echo v18.19.0; exit 0; fi`nexit 0`n" | Set-Content -Path $v18ShimPath -Encoding Utf8NoBOM
        & chmod +x $v18ShimPath
    }
    $env:PATH = "$mcpV18Bin$([System.IO.Path]::PathSeparator)$mcpV18OriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $mcpV18Root "codex-home"
    New-Item -ItemType Directory -Path $env:SDD_CODEX_HOME -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Force | Out-Null
    $env:SDD_CURSOR_DIR = Join-Path $mcpV18Root "cursor"
    $env:SDD_VSCODE_USER_DIR = Join-Path $mcpV18Root "vscode-user"
    New-Item -ItemType Directory -Path $env:SDD_CURSOR_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $env:SDD_VSCODE_USER_DIR -Force | Out-Null
    Set-Content -Path (Join-Path $env:SDD_CURSOR_DIR "mcp.json") -Value "{`n  `"mcpServers`": {}`n}`n" -Encoding Utf8NoBOM -NoNewline
    Set-Content -Path (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json") -Value "{`n  `"servers`": {}`n}`n" -Encoding Utf8NoBOM -NoNewline
    $v18CursorBefore = Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")
    $v18VSCodeBefore = Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")

    $warnings = $null
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $mcpV18Install -Target All -SkipAgentInstall -WarningVariable warnings -WarningAction SilentlyContinue

    if (Test-Path (Join-Path $mcpV18Install "mcp")) {
        throw "old Node v18 (w2): MCP was placed despite Node < 20"
    }
    if (Test-Path $mcpV18Log) {
        $v18LogContent = Get-Content -Raw $mcpV18Log
        if ($v18LogContent -match [regex]::Escape("claude mcp add")) {
            throw "old Node v18 (w2): claude mcp add was invoked despite Node < 20"
        }
    }
    $v18ConfigToml = Get-Content -Raw (Join-Path $env:SDD_CODEX_HOME "config.toml")
    if ($v18ConfigToml -match "sdd-forge-mcp" -or $v18ConfigToml -match "local-env-mcp") {
        throw "old Node v18 (w2): Codex config.toml was modified despite Node < 20"
    }
    if ((Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")) -ne $v18CursorBefore) {
        throw "old Node v18 (w2): Cursor mcp.json was modified despite Node < 20"
    }
    if ((Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")) -ne $v18VSCodeBefore) {
        throw "old Node v18 (w2): VS Code mcp.json was modified despite Node < 20"
    }
    if (-not ($warnings | Where-Object { $_.Message -match "(?i)node" })) {
        throw "old Node v18 (w2): expected warning mentioning Node was not raised"
    }
    Write-Host "ok: Node v18.x skips MCP placement and registration for both MCPs, with a warning"
}
finally {
    $env:PATH = $mcpV18OriginalPath
    if ($null -eq $mcpV18OriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $mcpV18OriginalCodexHome }
    $env:SDD_CURSOR_DIR = $mcpV18OriginalCursorDir
    $env:SDD_VSCODE_USER_DIR = $mcpV18OriginalVSCodeDir
    if (Test-Path $mcpV18Root) { Remove-Item -Path $mcpV18Root -Recurse -Force }
}

# Scenario (x): Codex config.toml absent — MCP registration for Codex is
# skipped with a warning rather than creating a new config.toml.
$mcpNoConfigRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-mcp-noconfig-" + [guid]::NewGuid())
$mcpNoConfigInstall = Join-Path $mcpNoConfigRoot "installed"
$mcpNoConfigBin = Join-Path $mcpNoConfigRoot "bin"
$mcpNoConfigLog = Join-Path $mcpNoConfigRoot "commands.log"
$mcpNoConfigOriginalPath = $env:PATH
$mcpNoConfigOriginalCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $mcpNoConfigBin -LogPath $mcpNoConfigLog
    $env:PATH = "$mcpNoConfigBin$([System.IO.Path]::PathSeparator)$mcpNoConfigOriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $mcpNoConfigRoot "codex-home-missing"

    $warnings = $null
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $mcpNoConfigInstall -Target All -SkipAgentInstall -WarningVariable warnings -WarningAction SilentlyContinue

    if (Test-Path (Join-Path $env:SDD_CODEX_HOME "config.toml")) {
        throw "missing config.toml (x): installer created a new config.toml"
    }
    if (-not ($warnings | Where-Object { $_.Message -match "(?i)config\.toml" })) {
        throw "missing config.toml (x): expected warning about missing config.toml not raised"
    }
    Write-Host "ok: missing Codex config.toml skips Codex MCP registration with a warning"
}
finally {
    $env:PATH = $mcpNoConfigOriginalPath
    if ($null -eq $mcpNoConfigOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $mcpNoConfigOriginalCodexHome }
    if (Test-Path $mcpNoConfigRoot) { Remove-Item -Path $mcpNoConfigRoot -Recurse -Force }
}

# ---------------------------------------------------------------------------
# MCP scenarios (T-007/T-008): AC-010 / AC-011 / AC-013 / AC-015 —
# Cursor / VS Code upsert parity in install.ps1
# ---------------------------------------------------------------------------

# Scenario (y): AC-010/AC-013 Cursor registration. A pre-existing
# ~/.cursor/mcp.json (via SDD_CURSOR_DIR) containing a foreign entry and an
# unknown top-level key keeps both; the two selected MCPs are upserted under
# mcpServers.<name> as { command: "node", args: [<install-root>/mcp/<name>/dist/index.js] };
# a second run is byte-identical (idempotent). The VS Code user dir is absent
# here, so VS Code registration is skipped with a notice and never created.
$cursorRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-cursor-" + [guid]::NewGuid())
$cursorInstall = Join-Path $cursorRoot "installed"
$cursorBin = Join-Path $cursorRoot "bin"
$cursorLog = Join-Path $cursorRoot "commands.log"
$cursorOriginalPath = $env:PATH
$cursorOriginalCodexHome = $env:SDD_CODEX_HOME
$cursorOriginalCursorDir = $env:SDD_CURSOR_DIR
$cursorOriginalVSCodeDir = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $cursorBin -LogPath $cursorLog
    $env:PATH = "$cursorBin$([System.IO.Path]::PathSeparator)$cursorOriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $cursorRoot "codex-home"
    New-Item -ItemType Directory -Path $env:SDD_CODEX_HOME -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Force | Out-Null
    $env:SDD_CURSOR_DIR = Join-Path $cursorRoot "cursor"
    $env:SDD_VSCODE_USER_DIR = Join-Path $cursorRoot "vscode-user-missing"
    New-Item -ItemType Directory -Path $env:SDD_CURSOR_DIR -Force | Out-Null
    $cursorSeed = @'
{
  "mcpServers": {
    "user-defined-mcp": {
      "command": "python3",
      "args": ["/opt/user/mcp.py"]
    }
  },
  "unknownTopLevelKey": { "keep": true }
}
'@
    Set-Content -Path (Join-Path $env:SDD_CURSOR_DIR "mcp.json") -Value $cursorSeed -Encoding Utf8NoBOM

    $cursorWarnings = $null
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $cursorInstall -Target All -SkipAgentInstall -WarningVariable cursorWarnings -WarningAction SilentlyContinue
    $cursorAfterFirst = Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $cursorInstall -Target All -SkipAgentInstall -WarningAction SilentlyContinue | Out-Null
    $cursorAfterSecond = Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")

    $cursorCheck = & node -e '
const c = require(process.argv[1]);
const s = c.mcpServers || {};
const f = s["user-defined-mcp"];
if (!f || f.command !== "python3" || !Array.isArray(f.args) || f.args[0] !== "/opt/user/mcp.py") process.exit(1);
for (const n of ["sdd-forge-mcp", "local-env-mcp"]) {
  const e = s[n];
  if (!e || e.command !== "node" || !Array.isArray(e.args) || e.args.length !== 1) process.exit(1);
  if (!e.args[0].replace(/\\/g, "/").endsWith("/mcp/" + n + "/dist/index.js")) process.exit(1);
}
if (!c.unknownTopLevelKey || c.unknownTopLevelKey.keep !== true) process.exit(1);
' (Join-Path $env:SDD_CURSOR_DIR "mcp.json") 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "cursor upsert (y): mcp.json missing managed entries, foreign entry, or unknown top-level key"
    }
    if ($cursorAfterFirst -ne $cursorAfterSecond) {
        throw "cursor upsert (y): second run is not byte-identical (not idempotent)"
    }
    if (Test-Path (Join-Path $cursorRoot "vscode-user-missing")) {
        throw "cursor upsert (y): absent VS Code user dir was created"
    }
    if (-not ($cursorWarnings | Where-Object { $_.Message -match "(?i)vs code" })) {
        throw "cursor upsert (y): expected VS Code skip notice for absent user dir not raised"
    }
    Write-Host "ok: Cursor mcp.json upsert preserves foreign entries, is idempotent, and absent VS Code dir is skipped with a notice"
}
finally {
    $env:PATH = $cursorOriginalPath
    if ($null -eq $cursorOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $cursorOriginalCodexHome }
    $env:SDD_CURSOR_DIR = $cursorOriginalCursorDir
    $env:SDD_VSCODE_USER_DIR = $cursorOriginalVSCodeDir
    if (Test-Path $cursorRoot) { Remove-Item -Path $cursorRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# Scenario (z): AC-011/AC-013 VS Code registration. A pre-existing user-profile
# mcp.json (via SDD_VSCODE_USER_DIR) containing a foreign entry and an unknown
# top-level key keeps both; the two selected MCPs are upserted under
# servers.<name> as { type: "stdio", command: "node", args: [...] }; a second
# run is byte-identical. The Cursor dir is absent here, so Cursor registration
# is skipped with a notice and never created.
$vscodeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-vscode-" + [guid]::NewGuid())
$vscodeInstall = Join-Path $vscodeRoot "installed"
$vscodeBin = Join-Path $vscodeRoot "bin"
$vscodeLog = Join-Path $vscodeRoot "commands.log"
$vscodeOriginalPath = $env:PATH
$vscodeOriginalCodexHome = $env:SDD_CODEX_HOME
$vscodeOriginalCursorDir = $env:SDD_CURSOR_DIR
$vscodeOriginalVSCodeDir = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $vscodeBin -LogPath $vscodeLog
    $env:PATH = "$vscodeBin$([System.IO.Path]::PathSeparator)$vscodeOriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $vscodeRoot "codex-home"
    New-Item -ItemType Directory -Path $env:SDD_CODEX_HOME -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Force | Out-Null
    $env:SDD_CURSOR_DIR = Join-Path $vscodeRoot "cursor-missing"
    $env:SDD_VSCODE_USER_DIR = Join-Path $vscodeRoot "vscode-user"
    New-Item -ItemType Directory -Path $env:SDD_VSCODE_USER_DIR -Force | Out-Null
    $vscodeSeed = @'
{
  "servers": {
    "user-defined-mcp": {
      "type": "stdio",
      "command": "python3",
      "args": ["/opt/user/mcp.py"]
    }
  },
  "inputs": [{ "id": "keep-me", "type": "promptString" }]
}
'@
    Set-Content -Path (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json") -Value $vscodeSeed -Encoding Utf8NoBOM

    $vscodeWarnings = $null
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $vscodeInstall -Target All -SkipAgentInstall -WarningVariable vscodeWarnings -WarningAction SilentlyContinue
    $vscodeAfterFirst = Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $vscodeInstall -Target All -SkipAgentInstall -WarningAction SilentlyContinue | Out-Null
    $vscodeAfterSecond = Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")

    & node -e '
const c = require(process.argv[1]);
const s = c.servers || {};
const f = s["user-defined-mcp"];
if (!f || f.command !== "python3" || !Array.isArray(f.args) || f.args[0] !== "/opt/user/mcp.py") process.exit(1);
for (const n of ["sdd-forge-mcp", "local-env-mcp"]) {
  const e = s[n];
  if (!e || e.type !== "stdio" || e.command !== "node" || !Array.isArray(e.args) || e.args.length !== 1) process.exit(1);
  if (!e.args[0].replace(/\\/g, "/").endsWith("/mcp/" + n + "/dist/index.js")) process.exit(1);
}
if (!Array.isArray(c.inputs) || c.inputs.length !== 1 || c.inputs[0].id !== "keep-me") process.exit(1);
' (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json") 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "vscode upsert (z): mcp.json missing managed entries, foreign entry, or unknown top-level key"
    }
    if ($vscodeAfterFirst -ne $vscodeAfterSecond) {
        throw "vscode upsert (z): second run is not byte-identical (not idempotent)"
    }
    if (Test-Path (Join-Path $vscodeRoot "cursor-missing")) {
        throw "vscode upsert (z): absent Cursor dir was created"
    }
    if (-not ($vscodeWarnings | Where-Object { $_.Message -match "(?i)cursor" })) {
        throw "vscode upsert (z): expected Cursor skip notice for absent dir not raised"
    }
    Write-Host "ok: VS Code mcp.json upsert preserves foreign entries, is idempotent, and absent Cursor dir is skipped with a notice"
}
finally {
    $env:PATH = $vscodeOriginalPath
    if ($null -eq $vscodeOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $vscodeOriginalCodexHome }
    $env:SDD_CURSOR_DIR = $vscodeOriginalCursorDir
    $env:SDD_VSCODE_USER_DIR = $vscodeOriginalVSCodeDir
    if (Test-Path $vscodeRoot) { Remove-Item -Path $vscodeRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# Scenario (aa): AC-015/AC-013 corrupted Cursor mcp.json. The installer must
# NOT modify the corrupt file (byte-identical), must raise an error notice, must
# still register the OTHER client (VS Code), and must exit zero.
$corruptCursorRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-corrupt-cursor-" + [guid]::NewGuid())
$corruptCursorInstall = Join-Path $corruptCursorRoot "installed"
$corruptCursorBin = Join-Path $corruptCursorRoot "bin"
$corruptCursorLog = Join-Path $corruptCursorRoot "commands.log"
$corruptCursorOriginalPath = $env:PATH
$corruptCursorOriginalCodexHome = $env:SDD_CODEX_HOME
$corruptCursorOriginalCursorDir = $env:SDD_CURSOR_DIR
$corruptCursorOriginalVSCodeDir = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $corruptCursorBin -LogPath $corruptCursorLog
    $env:PATH = "$corruptCursorBin$([System.IO.Path]::PathSeparator)$corruptCursorOriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $corruptCursorRoot "codex-home"
    New-Item -ItemType Directory -Path $env:SDD_CODEX_HOME -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Force | Out-Null
    $env:SDD_CURSOR_DIR = Join-Path $corruptCursorRoot "cursor"
    $env:SDD_VSCODE_USER_DIR = Join-Path $corruptCursorRoot "vscode-user"
    New-Item -ItemType Directory -Path $env:SDD_CURSOR_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $env:SDD_VSCODE_USER_DIR -Force | Out-Null
    Set-Content -Path (Join-Path $env:SDD_CURSOR_DIR "mcp.json") -Value "{ `"mcpServers`": { `"broken`"`n" -Encoding Utf8NoBOM -NoNewline
    $corruptCursorBefore = Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")

    $corruptCursorFailed = $false
    $corruptCursorOutput = ""
    try {
        $corruptCursorOutput = & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $corruptCursorInstall -Target All -SkipAgentInstall *>&1 | Out-String
    }
    catch {
        $corruptCursorFailed = $true
        $corruptCursorOutput = $_ | Out-String
    }
    if ($corruptCursorFailed) {
        throw "corrupt cursor JSON (aa): installer exited non-zero"
    }
    if ((Get-Content -Raw (Join-Path $env:SDD_CURSOR_DIR "mcp.json")) -ne $corruptCursorBefore) {
        throw "corrupt cursor JSON (aa): corrupt mcp.json was modified"
    }
    if ($corruptCursorOutput -notmatch "(?i)invalid") {
        throw "corrupt cursor JSON (aa): expected invalid-JSON error notice not raised"
    }
    & node -e '
const c = require(process.argv[1]);
const s = c.servers || {};
for (const n of ["sdd-forge-mcp", "local-env-mcp"]) {
  const e = s[n];
  if (!e || e.type !== "stdio" || e.command !== "node") process.exit(1);
}
' (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json") 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "corrupt cursor JSON (aa): VS Code registration did not continue"
    }
    Write-Host "ok: corrupt Cursor mcp.json is left unmodified with an error notice and VS Code registration continues"
}
finally {
    $env:PATH = $corruptCursorOriginalPath
    if ($null -eq $corruptCursorOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $corruptCursorOriginalCodexHome }
    $env:SDD_CURSOR_DIR = $corruptCursorOriginalCursorDir
    $env:SDD_VSCODE_USER_DIR = $corruptCursorOriginalVSCodeDir
    if (Test-Path $corruptCursorRoot) { Remove-Item -Path $corruptCursorRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# Scenario (ab): AC-015/AC-013 corrupted VS Code mcp.json — symmetric to (aa):
# the corrupt file is untouched, an error notice is raised, Cursor registration
# continues, and the installer exits zero.
$corruptVSCodeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-corrupt-vscode-" + [guid]::NewGuid())
$corruptVSCodeInstall = Join-Path $corruptVSCodeRoot "installed"
$corruptVSCodeBin = Join-Path $corruptVSCodeRoot "bin"
$corruptVSCodeLog = Join-Path $corruptVSCodeRoot "commands.log"
$corruptVSCodeOriginalPath = $env:PATH
$corruptVSCodeOriginalCodexHome = $env:SDD_CODEX_HOME
$corruptVSCodeOriginalCursorDir = $env:SDD_CURSOR_DIR
$corruptVSCodeOriginalVSCodeDir = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $corruptVSCodeBin -LogPath $corruptVSCodeLog
    $env:PATH = "$corruptVSCodeBin$([System.IO.Path]::PathSeparator)$corruptVSCodeOriginalPath"
    $env:SDD_CODEX_HOME = Join-Path $corruptVSCodeRoot "codex-home"
    New-Item -ItemType Directory -Path $env:SDD_CODEX_HOME -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Force | Out-Null
    $env:SDD_CURSOR_DIR = Join-Path $corruptVSCodeRoot "cursor"
    $env:SDD_VSCODE_USER_DIR = Join-Path $corruptVSCodeRoot "vscode-user"
    New-Item -ItemType Directory -Path $env:SDD_CURSOR_DIR -Force | Out-Null
    New-Item -ItemType Directory -Path $env:SDD_VSCODE_USER_DIR -Force | Out-Null
    Set-Content -Path (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json") -Value "not json at all { ]`n" -Encoding Utf8NoBOM -NoNewline
    $corruptVSCodeBefore = Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")

    $corruptVSCodeFailed = $false
    $corruptVSCodeOutput = ""
    try {
        $corruptVSCodeOutput = & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $installerSourceRoot -InstallRoot $corruptVSCodeInstall -Target All -SkipAgentInstall *>&1 | Out-String
    }
    catch {
        $corruptVSCodeFailed = $true
        $corruptVSCodeOutput = $_ | Out-String
    }
    if ($corruptVSCodeFailed) {
        throw "corrupt vscode JSON (ab): installer exited non-zero"
    }
    if ((Get-Content -Raw (Join-Path $env:SDD_VSCODE_USER_DIR "mcp.json")) -ne $corruptVSCodeBefore) {
        throw "corrupt vscode JSON (ab): corrupt mcp.json was modified"
    }
    if ($corruptVSCodeOutput -notmatch "(?i)invalid") {
        throw "corrupt vscode JSON (ab): expected invalid-JSON error notice not raised"
    }
    & node -e '
const c = require(process.argv[1]);
const s = c.mcpServers || {};
for (const n of ["sdd-forge-mcp", "local-env-mcp"]) {
  const e = s[n];
  if (!e || e.command !== "node") process.exit(1);
}
' (Join-Path $env:SDD_CURSOR_DIR "mcp.json") 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "corrupt vscode JSON (ab): Cursor registration did not continue"
    }
    Write-Host "ok: corrupt VS Code mcp.json is left unmodified with an error notice and Cursor registration continues"
}
finally {
    $env:PATH = $corruptVSCodeOriginalPath
    if ($null -eq $corruptVSCodeOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $corruptVSCodeOriginalCodexHome }
    $env:SDD_CURSOR_DIR = $corruptVSCodeOriginalCursorDir
    $env:SDD_VSCODE_USER_DIR = $corruptVSCodeOriginalVSCodeDir
    if (Test-Path $corruptVSCodeRoot) { Remove-Item -Path $corruptVSCodeRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Installer integration tests passed."

if (Test-Path $installerSourceRoot) {
    Remove-Item -Path $installerSourceRoot -Recurse -Force -ErrorAction SilentlyContinue
}
if ($global:SddInstallerIdeRoot -and (Test-Path $global:SddInstallerIdeRoot)) {
    Remove-Item -Path $global:SddInstallerIdeRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# Explicit success exit: GitHub Actions pwsh appends "exit $LASTEXITCODE", which
# would otherwise leak the exit code of the last native command run above.
exit 0
