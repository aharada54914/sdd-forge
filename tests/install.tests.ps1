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
            Remove-Item -Path $testRoot -Recurse -Force
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
            Remove-Item -Path $testRoot -Recurse -Force
        }
        if (Test-Path (Split-Path -Parent $global:SddInstallerFixtureArchivePath)) {
            Remove-Item -Path (Split-Path -Parent $global:SddInstallerFixtureArchivePath) -Recurse -Force
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
        Remove-Item -Path $filesOnlyRoot -Recurse -Force
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
    if (Test-Path $trackedOnlyRoot) { Remove-Item -Path $trackedOnlyRoot -Recurse -Force }
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
        Remove-Item -Path $preDeploymentRoot -Recurse -Force
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
    if (Test-Path $idempotencyRoot) { Remove-Item -Path $idempotencyRoot -Recurse -Force }
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
    if (Test-Path $nonestingRoot) { Remove-Item -Path $nonestingRoot -Recurse -Force }
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
    if (Test-Path $malformedRoot) { Remove-Item -Path $malformedRoot -Recurse -Force }
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
    if (Test-Path $badDeployRoot) { Remove-Item -Path $badDeployRoot -Recurse -Force }
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
    if (Test-Path $lockTestRoot) { Remove-Item -Path $lockTestRoot -Recurse -Force }
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
    if (Test-Path $lockSuccessRoot) { Remove-Item -Path $lockSuccessRoot -Recurse -Force }
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
    if (Test-Path $smokeRoot) { Remove-Item -Path $smokeRoot -Recurse -Force }
}

Write-Host "Installer integration tests passed."

if (Test-Path $installerSourceRoot) {
    Remove-Item -Path $installerSourceRoot -Recurse -Force
}

# Explicit success exit: GitHub Actions pwsh appends "exit $LASTEXITCODE", which
# would otherwise leak the exit code of the last native command run above.
exit 0
