$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# uninstall.tests.ps1 — PowerShell port of uninstall.tests.sh.
# Exercises uninstall.ps1 without network or real CLIs by stubbing codex/claude/
# copilot with logging shims and simulating an installed layout.

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$uninstaller = Join-Path $repositoryRoot "uninstall.ps1"
$allPlugins = @("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop")
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function New-FakeCommands {
    param(
        [Parameter(Mandatory)][string]$BinRoot,
        [Parameter(Mandatory)][string]$LogPath,
        [string]$OmitCommand
    )

    New-Item -ItemType Directory -Path $BinRoot -Force | Out-Null
    foreach ($command in @("codex", "claude", "copilot")) {
        if ($command -eq $OmitCommand) { continue }
        if ($isWindowsPlatform) {
            $commandPath = Join-Path $BinRoot "$command.cmd"
            "@echo $command %*>>`"$LogPath`"`r`n@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
        }
        else {
            $commandPath = Join-Path $BinRoot $command
            "#!/bin/sh`necho `"$command `$*`" >> `"$LogPath`"`nexit 0`n" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
            & chmod +x $commandPath
        }
    }
}

function New-InstalledLayout {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$CodexHome
    )
    New-Item -ItemType Directory -Path (Join-Path $InstallRoot "plugins/sdd-bootstrap") -Force | Out-Null
    Set-Content -Path (Join-Path $InstallRoot "marker.txt") -Value "marker" -Encoding Ascii
    $agents = Join-Path $CodexHome "agents"
    New-Item -ItemType Directory -Path $agents -Force | Out-Null
    Set-Content -Path (Join-Path $agents "sdd-investigator.toml") -Value "name = `"sdd-investigator`"`ndeveloper_instructions = `"x`"" -Encoding Utf8NoBOM
    Set-Content -Path (Join-Path $agents "sdd-evaluator.toml") -Value "name = `"sdd-evaluator`"`ndeveloper_instructions = `"x`"" -Encoding Utf8NoBOM
    # A user's own agent role file that must NOT be removed.
    Set-Content -Path (Join-Path $agents "auditor.toml") -Value "name = `"auditor`"" -Encoding Utf8NoBOM
}

# Restricted PATH used by "missing CLI" scenarios so a real codex on the host
# PATH cannot shadow the omitted shim.
function Get-RestrictedPath {
    param([Parameter(Mandatory)][string]$FakeBin)
    if ($isWindowsPlatform) {
        $sys = Join-Path $env:SystemRoot "System32"
        return "$FakeBin$([System.IO.Path]::PathSeparator)$sys"
    }
    return "$FakeBin$([System.IO.Path]::PathSeparator)/usr/bin$([System.IO.Path]::PathSeparator)/bin"
}

function Invoke-UninstallScenario {
    param(
        [string[]]$Plugins = $allPlugins,
        [string]$Target = "All",
        [switch]$KeepFiles,
        [switch]$SkipAgentUninstall,
        [string]$OmitCommand,
        [switch]$RestrictPath
    )

    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-test-" + [guid]::NewGuid())
    $installRoot = Join-Path $testRoot "installed"
    $codexHome = Join-Path $testRoot "codex-home"
    $fakeBin = Join-Path $testRoot "bin"
    $commandLog = Join-Path $testRoot "commands.log"
    $originalPath = $env:PATH
    $originalCodexHome = $env:SDD_CODEX_HOME

    New-FakeCommands -BinRoot $fakeBin -LogPath $commandLog -OmitCommand $OmitCommand
    New-InstalledLayout -InstallRoot $installRoot -CodexHome $codexHome
    if ($RestrictPath) { $env:PATH = Get-RestrictedPath -FakeBin $fakeBin }
    else { $env:PATH = "$fakeBin$([System.IO.Path]::PathSeparator)$originalPath" }
    $env:SDD_CODEX_HOME = $codexHome

    $failed = $false
    try {
        $params = @{ InstallRoot = $installRoot; Target = $Target; Plugins = $Plugins }
        if ($KeepFiles) { $params.KeepFiles = $true }
        if ($SkipAgentUninstall) { $params.SkipAgentUninstall = $true }
        & $uninstaller @params *>$null
    }
    catch {
        $failed = $true
    }
    finally {
        $env:PATH = $originalPath
        if ($null -eq $originalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue }
        else { $env:SDD_CODEX_HOME = $originalCodexHome }
    }

    $log = if (Test-Path $commandLog) { Get-Content -Raw $commandLog } else { "" }
    return [pscustomobject]@{
        Failed      = $failed
        Log         = $log
        InstallRoot = $installRoot
        CodexHome   = $codexHome
        TestRoot    = $testRoot
    }
}

# ---------------------------------------------------------------------------
# Scenario (a): full uninstall
# ---------------------------------------------------------------------------
$a = Invoke-UninstallScenario
try {
    if ($a.Failed) { throw "full uninstall: uninstaller threw" }
    foreach ($p in $allPlugins) {
        foreach ($expected in @("codex plugin remove $p", "claude plugin uninstall $p@sdd-plugins", "copilot plugin uninstall $p@sdd-plugins")) {
            if ($a.Log -notmatch [regex]::Escape($expected)) { throw "full uninstall: missing command: $expected" }
        }
    }
    foreach ($expected in @("codex plugin marketplace remove sdd-plugins", "claude plugin marketplace remove sdd-plugins", "copilot plugin marketplace remove sdd-plugins")) {
        if ($a.Log -notmatch [regex]::Escape($expected)) { throw "full uninstall: missing command: $expected" }
    }
    if (-not (Test-Path (Join-Path $a.CodexHome "agents/auditor.toml"))) { throw "full uninstall: user's auditor.toml was removed" }
    if (Test-Path $a.InstallRoot) { throw "full uninstall: install root not removed" }
    if (Test-Path (Join-Path $a.CodexHome "agents/sdd-investigator.toml")) { throw "full uninstall: shipped agent toml not removed" }
    Write-Host "ok: full uninstall unregisters all plugins+marketplace, removes files and shipped agents"
}
finally { if (Test-Path $a.TestRoot) { Remove-Item -Path $a.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Scenario (b): -KeepFiles
# ---------------------------------------------------------------------------
$b = Invoke-UninstallScenario -KeepFiles
try {
    if ($b.Failed) { throw "-KeepFiles: uninstaller threw" }
    if (-not (Test-Path (Join-Path $b.InstallRoot "marker.txt"))) { throw "-KeepFiles removed install root" }
    Write-Host "ok: -KeepFiles preserves installed files while unregistering"
}
finally { if (Test-Path $b.TestRoot) { Remove-Item -Path $b.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Scenario (c): -SkipAgentUninstall
# ---------------------------------------------------------------------------
$c = Invoke-UninstallScenario -SkipAgentUninstall
try {
    if ($c.Failed) { throw "-SkipAgentUninstall: uninstaller threw" }
    if (-not (Test-Path (Join-Path $c.CodexHome "agents/sdd-investigator.toml"))) { throw "-SkipAgentUninstall removed agent toml" }
    Write-Host "ok: -SkipAgentUninstall preserves shipped agent role files"
}
finally { if (Test-Path $c.TestRoot) { Remove-Item -Path $c.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Scenario (d): subset -Plugins only unregisters chosen plugins
# ---------------------------------------------------------------------------
$d = Invoke-UninstallScenario -Plugins @("sdd-bootstrap", "sdd-implementation")
try {
    if ($d.Log -notmatch [regex]::Escape("claude plugin uninstall sdd-bootstrap@sdd-plugins")) { throw "subset: sdd-bootstrap not unregistered" }
    if ($d.Log -notmatch [regex]::Escape("claude plugin uninstall sdd-implementation@sdd-plugins")) { throw "subset: sdd-implementation not unregistered" }
    if ($d.Log -match [regex]::Escape("uninstall sdd-ship@sdd-plugins") -or $d.Log -match [regex]::Escape("remove sdd-ship")) { throw "subset: unselected sdd-ship was unregistered" }
    Write-Host "ok: subset -Plugins only unregisters chosen plugins"
}
finally { if (Test-Path $d.TestRoot) { Remove-Item -Path $d.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Scenario (e): missing optional CLI (target All) tolerated
# ---------------------------------------------------------------------------
$e = Invoke-UninstallScenario -OmitCommand "codex" -RestrictPath
try {
    if ($e.Failed) { throw "missing optional codex CLI should be tolerated under target All" }
    if (Test-Path $e.InstallRoot) { throw "files not removed when an optional CLI was absent" }
    Write-Host "ok: missing optional CLI tolerated under target All"
}
finally { if (Test-Path $e.TestRoot) { Remove-Item -Path $e.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Scenario (f): target Codex with codex absent is a hard error
# ---------------------------------------------------------------------------
$f = Invoke-UninstallScenario -Target "Codex" -OmitCommand "codex" -RestrictPath
try {
    if (-not $f.Failed) { throw "target Codex with codex absent should fail" }
    Write-Host "ok: target Codex with codex absent fails as required"
}
finally { if (Test-Path $f.TestRoot) { Remove-Item -Path $f.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Scenario (g): idempotency — a second uninstall still succeeds
# ---------------------------------------------------------------------------
$g1 = Invoke-UninstallScenario
$gFailed = $g1.Failed
# Re-run against the now-clean root (files already gone): must not throw.
$gRoot = $g1.InstallRoot
$gCodex = $g1.CodexHome
$savedPath = $env:PATH
$savedCodexHome = $env:SDD_CODEX_HOME
try {
    $gBin = Join-Path $g1.TestRoot "bin2"
    $gLog = Join-Path $g1.TestRoot "commands2.log"
    New-FakeCommands -BinRoot $gBin -LogPath $gLog
    $env:PATH = "$gBin$([System.IO.Path]::PathSeparator)$savedPath"
    $env:SDD_CODEX_HOME = $gCodex
    & $uninstaller -InstallRoot $gRoot -Target All *>$null
}
catch { $gFailed = $true }
finally {
    $env:PATH = $savedPath
    if ($null -eq $savedCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $savedCodexHome }
    if (Test-Path $g1.TestRoot) { Remove-Item -Path $g1.TestRoot -Recurse -Force }
}
if ($gFailed) { throw "idempotency: second uninstall should succeed" }
Write-Host "ok: idempotency: second uninstall succeeds"

# ---------------------------------------------------------------------------
# Scenario (h): invalid plugin name rejected (ValidateSet)
# ---------------------------------------------------------------------------
$hFailed = $false
try { & $uninstaller -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())) -Target FilesOnly -Plugins @("not-a-plugin") *>$null }
catch { $hFailed = $true }
if (-not $hFailed) { throw "invalid plugin name was accepted" }
Write-Host "ok: invalid plugin name rejected"

# ---------------------------------------------------------------------------
# Scenario (i): refuses a filesystem root as -InstallRoot
# ---------------------------------------------------------------------------
$rootPath = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()))
$iFailed = $false
try { & $uninstaller -InstallRoot $rootPath -Target FilesOnly -SkipPluginUninstall -SkipAgentUninstall *>$null }
catch { $iFailed = $true }
if (-not $iFailed) { throw "filesystem root was accepted as -InstallRoot" }
Write-Host "ok: filesystem root rejected as -InstallRoot"

# ---------------------------------------------------------------------------
# Scenario (j): FilesOnly skips CLI calls but still removes files
# ---------------------------------------------------------------------------
$j = Invoke-UninstallScenario -Target "FilesOnly"
try {
    if ($j.Failed) { throw "FilesOnly: uninstaller threw" }
    if ($j.Log.Trim().Length -ne 0) { throw "FilesOnly should not call any CLI" }
    if (Test-Path $j.InstallRoot) { throw "FilesOnly should still remove installed files" }
    Write-Host "ok: FilesOnly skips CLI calls but removes files"
}
finally { if (Test-Path $j.TestRoot) { Remove-Item -Path $j.TestRoot -Recurse -Force } }

Write-Host ""
Write-Host "uninstall.tests.ps1: all scenarios passed."
