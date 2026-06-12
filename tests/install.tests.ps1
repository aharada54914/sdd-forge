$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$allPlugins = @("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop")
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

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
    foreach ($entry in (Get-ChildItem -Path $SourceRoot -Force)) {
        if ($entry.Name -ne ".git") {
            Copy-Item -Path $entry.FullName -Destination (Join-Path $archiveSource $entry.Name) -Recurse -Force
        }
    }
    & tar -czf $archivePath -C $archiveRoot "repo"
    return $archivePath
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
            & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot $installRoot -Target All -Plugins $Plugins
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
        foreach ($plugin in $Plugins) {
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
        foreach ($plugin in $allPlugins | Where-Object { $_ -notin $Plugins }) {
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
    $archivePath = New-ArchiveFixture -SourceRoot $repositoryRoot

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
        Copy-Item -Path $archivePath -Destination $OutFile -Force
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
        if (Test-Path (Split-Path -Parent $archivePath)) {
            Remove-Item -Path (Split-Path -Parent $archivePath) -Recurse -Force
        }
    }
}

Invoke-InstallerScenario -Plugins $allPlugins
Invoke-InstallerScenario -Plugins @("sdd-bootstrap", "sdd-implementation")
Invoke-InstallerScenario -Plugins $allPlugins -FailPattern "sdd-implementation@sdd-plugins"
Invoke-InstallerScenario -Plugins $allPlugins -FailPattern "sdd-implementation@sdd-plugins" -SeedExistingInstall

$filesOnlyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-filesonly-" + [guid]::NewGuid())
$filesOnlyInstall = Join-Path $filesOnlyRoot "installed"
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot $filesOnlyInstall -Target FilesOnly
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

$preDeploymentRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-predeploy-" + [guid]::NewGuid())
$badSourceRoot = Join-Path $preDeploymentRoot "bad-source"
$existingInstallRoot = Join-Path $preDeploymentRoot "installed"
try {
    New-Item -ItemType Directory -Path $badSourceRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $existingInstallRoot -Force | Out-Null
    Set-Content -Path (Join-Path $existingInstallRoot "existing.marker") -Value "keep" -Encoding Ascii
    $preDeploymentFailed = $false
    try {
        & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $badSourceRoot -InstallRoot $existingInstallRoot -Target FilesOnly
    }
    catch {
        $preDeploymentFailed = $true
    }
    if (-not $preDeploymentFailed) {
        throw "Installer accepted an invalid source directory."
    }
    if (-not (Test-Path (Join-Path $existingInstallRoot "existing.marker"))) {
        throw "Installer removed the existing installation before deployment started."
    }
}
finally {
    if (Test-Path $preDeploymentRoot) {
        Remove-Item -Path $preDeploymentRoot -Recurse -Force
    }
}

$invalidFailed = $false
try {
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot (Join-Path $env:TEMP ([guid]::NewGuid())) -Target FilesOnly -Plugins @("not-a-plugin")
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
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot $idempotencyInstall -Target All -Plugins $allPlugins
    # Second install (idempotent)
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot $idempotencyInstall -Target All -Plugins $allPlugins
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
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot $nonestingInstall -Target All -Plugins $allPlugins
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
    $malformedOutput = & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot $malformedInstall -Target All *>&1 | Out-String
    # Verify agents were installed with developer_instructions
    if (-not (Test-Path (Join-Path $malformedCodexAgents "sdd-investigator.toml"))) {
        throw "sdd-investigator.toml was not installed"
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
    # Copy repository to bad source, excluding .git
    New-Item -ItemType Directory -Path $badDeploySource -Force | Out-Null
    foreach ($entry in (Get-ChildItem -Path $repositoryRoot -Force)) {
        if ($entry.Name -ne ".git") {
            Copy-Item -Path $entry.FullName -Destination (Join-Path $badDeploySource $entry.Name) -Recurse -Force
        }
    }
    # Overwrite the sdd-investigator.toml to make it malformed (missing developer_instructions)
    $investigatorPath = Join-Path $badDeploySource ".codex/agents/sdd-investigator.toml"
    Set-Content -Path $investigatorPath -Value 'name = "sdd-investigator"' -Encoding Utf8
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

Write-Host "Installer integration tests passed."

# Explicit success exit: GitHub Actions pwsh appends "exit $LASTEXITCODE", which
# would otherwise leak the exit code of the last native command run above.
exit 0
