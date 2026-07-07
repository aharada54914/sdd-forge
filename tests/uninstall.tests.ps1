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
    # Manifest: the role files this project ships (source install copied from).
    $manifest = Join-Path (Join-Path $InstallRoot ".codex") "agents"
    New-Item -ItemType Directory -Path $manifest -Force | Out-Null
    Set-Content -Path (Join-Path $manifest "sdd-investigator.toml") -Value "name = `"sdd-investigator`"`ndeveloper_instructions = `"x`"" -Encoding Utf8NoBOM
    Set-Content -Path (Join-Path $manifest "sdd-evaluator.toml") -Value "name = `"sdd-evaluator`"`ndeveloper_instructions = `"x`"" -Encoding Utf8NoBOM
    # Destination ~/.codex/agents: shipped roles + user-owned roles.
    $agents = Join-Path $CodexHome "agents"
    New-Item -ItemType Directory -Path $agents -Force | Out-Null
    Set-Content -Path (Join-Path $agents "sdd-investigator.toml") -Value "name = `"sdd-investigator`"`ndeveloper_instructions = `"x`"" -Encoding Utf8NoBOM
    Set-Content -Path (Join-Path $agents "sdd-evaluator.toml") -Value "name = `"sdd-evaluator`"`ndeveloper_instructions = `"x`"" -Encoding Utf8NoBOM
    # A user's own non-project role file — must NOT be removed.
    Set-Content -Path (Join-Path $agents "auditor.toml") -Value "name = `"auditor`"" -Encoding Utf8NoBOM
    # A user-authored role that merely shares the sdd- prefix — must NOT be removed.
    Set-Content -Path (Join-Path $agents "sdd-custom.toml") -Value "name = `"sdd-custom`"`ndeveloper_instructions = `"x`"" -Encoding Utf8NoBOM
}

# Seeds an installed MCP payload + a Codex config.toml with a registered
# marker block, mirroring what install.ps1 would have produced.
function New-InstalledMcpLayout {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$CodexHome
    )
    $mcpDistDir = Join-Path (Join-Path $InstallRoot "mcp/sdd-forge-mcp") "dist"
    New-Item -ItemType Directory -Path $mcpDistDir -Force | Out-Null
    Set-Content -Path (Join-Path $mcpDistDir "index.js") -Value "console.log('stub');" -Encoding Utf8NoBOM
    Set-Content -Path (Join-Path $InstallRoot "mcp/sdd-forge-mcp/package.json") -Value '{"name":"sdd-forge-mcp"}' -Encoding Utf8NoBOM
    New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
    $entryPoint = (Join-Path $mcpDistDir "index.js") -replace '\\', '/'
    $configLines = @(
        '[some_other_section]',
        'key = "value"',
        '',
        '# >>> sdd-forge-mcp (managed by sdd-forge installer; do not edit by hand) >>>',
        '[mcp_servers.sdd-forge-mcp]',
        'command = "node"',
        "args = [`"$entryPoint`"]",
        '# <<< sdd-forge-mcp <<<'
    )
    Set-Content -Path (Join-Path $CodexHome "config.toml") -Value $configLines -Encoding Utf8NoBOM
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
        [switch]$SkipPluginUninstall,
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
        if ($SkipPluginUninstall) { $params.SkipPluginUninstall = $true }
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
        foreach ($expected in @("codex plugin remove $p@sdd-plugins", "claude plugin uninstall $p@sdd-plugins", "copilot plugin uninstall $p@sdd-plugins")) {
            if ($a.Log -notmatch [regex]::Escape($expected)) { throw "full uninstall: missing command: $expected" }
        }
    }
    foreach ($expected in @("codex plugin marketplace remove sdd-plugins", "claude plugin marketplace remove sdd-plugins", "copilot plugin marketplace remove sdd-plugins")) {
        if ($a.Log -notmatch [regex]::Escape($expected)) { throw "full uninstall: missing command: $expected" }
    }
    if (-not (Test-Path (Join-Path $a.CodexHome "agents/auditor.toml"))) { throw "full uninstall: user's auditor.toml was removed" }
    if (-not (Test-Path (Join-Path $a.CodexHome "agents/sdd-custom.toml"))) { throw "full uninstall: user-authored sdd-custom.toml was removed" }
    if (Test-Path $a.InstallRoot) { throw "full uninstall: install root not removed" }
    if (Test-Path (Join-Path $a.CodexHome "agents/sdd-investigator.toml")) { throw "full uninstall: shipped agent toml not removed" }
    Write-Host "ok: full uninstall unregisters all plugins+marketplace, removes files and only shipped agents"
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
# Scenario (d): subset -Plugins unregisters only chosen plugins and KEEPS the
# marketplace (removing it would uninstall the unselected plugins too).
# ---------------------------------------------------------------------------
$d = Invoke-UninstallScenario -Plugins @("sdd-bootstrap", "sdd-implementation")
try {
    if ($d.Failed) { throw "subset: uninstaller threw" }
    if ($d.Log -notmatch [regex]::Escape("claude plugin uninstall sdd-bootstrap@sdd-plugins")) { throw "subset: sdd-bootstrap not unregistered" }
    if ($d.Log -notmatch [regex]::Escape("claude plugin uninstall sdd-implementation@sdd-plugins")) { throw "subset: sdd-implementation not unregistered" }
    if ($d.Log -match [regex]::Escape("uninstall sdd-ship@sdd-plugins") -or $d.Log -match [regex]::Escape("remove sdd-ship@sdd-plugins")) { throw "subset: unselected sdd-ship was unregistered" }
    if ($d.Log -match [regex]::Escape("marketplace remove")) { throw "subset: marketplace must not be removed for a partial uninstall" }
    Write-Host "ok: subset -Plugins unregisters only chosen plugins and keeps the marketplace"
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
# Scenario (f2): -SkipPluginUninstall proceeds even when the CLI is absent
# ---------------------------------------------------------------------------
$f2 = Invoke-UninstallScenario -Target "Codex" -OmitCommand "codex" -RestrictPath -SkipPluginUninstall
try {
    if ($f2.Failed) { throw "-SkipPluginUninstall should not error on absent CLI" }
    if (Test-Path $f2.InstallRoot) { throw "-SkipPluginUninstall should still remove files" }
    Write-Host "ok: -SkipPluginUninstall proceeds when CLI is absent"
}
finally { if (Test-Path $f2.TestRoot) { Remove-Item -Path $f2.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Scenario (g): idempotency — a second uninstall still succeeds
# ---------------------------------------------------------------------------
$g1 = Invoke-UninstallScenario
$gFailed = $g1.Failed
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
# Scenario (h2): invalid -Target rejected (ValidateSet)
# ---------------------------------------------------------------------------
$h2Failed = $false
try { & $uninstaller -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())) -Target "NotATarget" *>$null }
catch { $h2Failed = $true }
if (-not $h2Failed) { throw "invalid -Target was accepted" }
Write-Host "ok: invalid -Target rejected"

# ---------------------------------------------------------------------------
# Scenario (h3): empty -InstallRoot rejected before any removal
# ---------------------------------------------------------------------------
$h3Failed = $false
try { & $uninstaller -InstallRoot "" -Target FilesOnly -SkipPluginUninstall -SkipAgentUninstall *>$null }
catch { $h3Failed = $true }
if (-not $h3Failed) { throw "empty -InstallRoot was accepted" }
Write-Host "ok: empty -InstallRoot rejected"

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
# Scenario (i2): refuses the home directory as -InstallRoot
# ---------------------------------------------------------------------------
$homeDir = [Environment]::GetFolderPath("UserProfile")
$i2Failed = $false
try { & $uninstaller -InstallRoot $homeDir -Target FilesOnly -SkipPluginUninstall -SkipAgentUninstall *>$null }
catch { $i2Failed = $true }
if (-not $i2Failed) { throw "home directory was accepted as -InstallRoot" }
Write-Host "ok: home directory rejected as -InstallRoot"

# ---------------------------------------------------------------------------
# MCP scenarios (T-006): AC-009
# ---------------------------------------------------------------------------

# Scenario (k): uninstall removes the MCP payload directory and the Codex
# config.toml marker block, while preserving unrelated config.toml content.
$kRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-mcp-k-" + [guid]::NewGuid())
$kInstall = Join-Path $kRoot "installed"
$kCodexHome = Join-Path $kRoot "codex-home"
$kBin = Join-Path $kRoot "bin"
$kLog = Join-Path $kRoot "commands.log"
$kOriginalPath = $env:PATH
$kOriginalCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $kBin -LogPath $kLog
    New-InstalledLayout -InstallRoot $kInstall -CodexHome $kCodexHome
    New-InstalledMcpLayout -InstallRoot $kInstall -CodexHome $kCodexHome
    $env:PATH = "$kBin$([System.IO.Path]::PathSeparator)$kOriginalPath"
    $env:SDD_CODEX_HOME = $kCodexHome

    $kFailed = $false
    try { & $uninstaller -InstallRoot $kInstall -Target All *>$null } catch { $kFailed = $true }

    if ($kFailed) { throw "MCP uninstall (k): uninstaller threw" }
    if (Test-Path (Join-Path $kInstall "mcp")) { throw "MCP uninstall (k): mcp/ payload not removed" }
    $configTomlPath = Join-Path $kCodexHome "config.toml"
    if (-not (Test-Path $configTomlPath)) { throw "MCP uninstall (k): config.toml was deleted entirely" }
    $configTomlContent = Get-Content -Raw $configTomlPath
    if ($configTomlContent -match "sdd-forge-mcp") { throw "MCP uninstall (k): sdd-forge-mcp marker block not removed" }
    if ($configTomlContent -notmatch "some_other_section") { throw "MCP uninstall (k): unrelated config.toml content was removed" }
    $kLogContent = if (Test-Path $kLog) { Get-Content -Raw $kLog } else { "" }
    if ($kLogContent -notmatch [regex]::Escape("claude mcp remove sdd-forge-mcp")) { throw "MCP uninstall (k): claude mcp remove not invoked" }
    Write-Host "ok: uninstall removes MCP payload and Codex config.toml marker block"
}
finally {
    $env:PATH = $kOriginalPath
    if ($null -eq $kOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $kOriginalCodexHome }
    if (Test-Path $kRoot) { Remove-Item -Path $kRoot -Recurse -Force }
}

# Scenario (l): uninstall on a system with no MCP ever installed succeeds
# best-effort (no error, nothing to remove).
$lRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-mcp-l-" + [guid]::NewGuid())
$lInstall = Join-Path $lRoot "installed"
$lCodexHome = Join-Path $lRoot "codex-home"
$lBin = Join-Path $lRoot "bin"
$lLog = Join-Path $lRoot "commands.log"
$lOriginalPath = $env:PATH
$lOriginalCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $lBin -LogPath $lLog
    New-InstalledLayout -InstallRoot $lInstall -CodexHome $lCodexHome
    # Intentionally do NOT seed MCP payload or config.toml.
    $env:PATH = "$lBin$([System.IO.Path]::PathSeparator)$lOriginalPath"
    $env:SDD_CODEX_HOME = $lCodexHome

    $lFailed = $false
    try { & $uninstaller -InstallRoot $lInstall -Target All *>$null } catch { $lFailed = $true }

    if ($lFailed) { throw "uninstall with no MCP ever installed should succeed best-effort" }
    Write-Host "ok: uninstall with no MCP ever installed succeeds best-effort"
}
finally {
    $env:PATH = $lOriginalPath
    if ($null -eq $lOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $lOriginalCodexHome }
    if (Test-Path $lRoot) { Remove-Item -Path $lRoot -Recurse -Force }
}

# Scenario (m): -Mcp <list> selects which MCP registrations/payloads are removed.
$mRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-mcp-m-" + [guid]::NewGuid())
$mInstall = Join-Path $mRoot "installed"
$mCodexHome = Join-Path $mRoot "codex-home"
$mBin = Join-Path $mRoot "bin"
$mLog = Join-Path $mRoot "commands.log"
$mOriginalPath = $env:PATH
$mOriginalCodexHome = $env:SDD_CODEX_HOME
try {
    New-FakeCommands -BinRoot $mBin -LogPath $mLog
    New-InstalledLayout -InstallRoot $mInstall -CodexHome $mCodexHome
    New-InstalledMcpLayout -InstallRoot $mInstall -CodexHome $mCodexHome
    $env:PATH = "$mBin$([System.IO.Path]::PathSeparator)$mOriginalPath"
    $env:SDD_CODEX_HOME = $mCodexHome

    $mFailed = $false
    try { & $uninstaller -InstallRoot $mInstall -Target All -Mcp @("sdd-forge-mcp") *>$null } catch { $mFailed = $true }

    if ($mFailed) { throw "-Mcp subset (m): uninstaller threw" }
    if (Test-Path (Join-Path $mInstall "mcp")) { throw "-Mcp subset (m): mcp/ payload not removed" }
    Write-Host "ok: -Mcp <list> selects MCP payload/registration removal"
}
finally {
    $env:PATH = $mOriginalPath
    if ($null -eq $mOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $mOriginalCodexHome }
    if (Test-Path $mRoot) { Remove-Item -Path $mRoot -Recurse -Force }
}

# Scenario (n): invalid -Mcp name rejected (ValidateSet)
$nFailed = $false
try { & $uninstaller -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())) -Target FilesOnly -Mcp @("bogus-mcp") *>$null }
catch { $nFailed = $true }
if (-not $nFailed) { throw "invalid -Mcp name was accepted" }
Write-Host "ok: invalid -Mcp name rejected"

# Scenario (n2): -Mcp "" (empty value) is rejected cleanly by ValidateSet
# parameter binding rather than being silently accepted as "no MCP selected"
# (mirrors uninstall.sh's guard against bash 3.2's unbound-variable crash).
$n2Failed = $false
$n2Error = $null
try { & $uninstaller -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())) -Target FilesOnly -Mcp "" *>$null }
catch { $n2Failed = $true; $n2Error = $_ }
if (-not $n2Failed) { throw "-Mcp `"`" (n2): uninstaller accepted an empty MCP value" }
if ($n2Error -and ($n2Error.Exception.Message -match "unbound variable")) {
    throw "-Mcp `"`" (n2): uninstaller crashed with an unbound variable error"
}
Write-Host "ok: -Mcp `"`" (empty) is rejected"

# Scenario (n3): -Plugins "" (empty value) is rejected cleanly by ValidateSet
# parameter binding (mirrors uninstall.sh's guard against bash 3.2's
# unbound-variable crash on an empty --plugins list).
$n3Failed = $false
$n3Error = $null
try { & $uninstaller -InstallRoot (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())) -Target FilesOnly -Plugins "" *>$null }
catch { $n3Failed = $true; $n3Error = $_ }
if (-not $n3Failed) { throw "-Plugins `"`" (n3): uninstaller accepted an empty plugin value" }
if ($n3Error -and ($n3Error.Exception.Message -match "unbound variable")) {
    throw "-Plugins `"`" (n3): uninstaller crashed with an unbound variable error"
}
Write-Host "ok: -Plugins `"`" (empty) is rejected"

# ---------------------------------------------------------------------------
# MCP scenarios (T-009): AC-012 — remove BOTH managed MCPs and the Cursor /
# VS Code managed keys, while preserving user-defined entries and unknown
# top-level keys. Uses SDD_CURSOR_DIR / SDD_VSCODE_USER_DIR overrides so the
# real user profile is never touched.
# ---------------------------------------------------------------------------

# Seed an installed layout for BOTH managed MCPs: payloads, a Codex config.toml
# with a marker block per MCP plus an unrelated section, and Cursor / VS Code
# mcp.json files each holding the two managed keys, a user-defined key, and an
# unknown top-level key.
function New-InstalledTwoMcpLayout {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$CodexHome,
        [Parameter(Mandatory)][string]$CursorDir,
        [Parameter(Mandatory)][string]$VSCodeDir
    )
    foreach ($name in @("sdd-forge-mcp", "local-env-mcp")) {
        $distDir = Join-Path (Join-Path (Join-Path $InstallRoot "mcp") $name) "dist"
        New-Item -ItemType Directory -Path $distDir -Force | Out-Null
        Set-Content -Path (Join-Path $distDir "index.js") -Value "console.log('stub');" -Encoding Utf8NoBOM
        Set-Content -Path (Join-Path (Join-Path (Join-Path $InstallRoot "mcp") $name) "package.json") -Value "{`"name`":`"$name`"}" -Encoding Utf8NoBOM
    }
    New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
    $forgeEntry = ((Join-Path (Join-Path (Join-Path (Join-Path $InstallRoot "mcp") "sdd-forge-mcp") "dist") "index.js") -replace '\\', '/')
    $localEntry = ((Join-Path (Join-Path (Join-Path (Join-Path $InstallRoot "mcp") "local-env-mcp") "dist") "index.js") -replace '\\', '/')
    $configLines = @(
        '[some_other_section]',
        'key = "value"',
        '',
        '# >>> sdd-forge-mcp (managed by sdd-forge installer; do not edit by hand) >>>',
        '[mcp_servers.sdd-forge-mcp]',
        'command = "node"',
        "args = [`"$forgeEntry`"]",
        '# <<< sdd-forge-mcp <<<',
        '',
        '# >>> local-env-mcp (managed by sdd-forge installer; do not edit by hand) >>>',
        '[mcp_servers.local-env-mcp]',
        'command = "node"',
        "args = [`"$localEntry`"]",
        '# <<< local-env-mcp <<<'
    )
    Set-Content -Path (Join-Path $CodexHome "config.toml") -Value $configLines -Encoding Utf8NoBOM

    New-Item -ItemType Directory -Path $CursorDir -Force | Out-Null
    $cursorJson = @{
        mcpServers = [ordered]@{
            "sdd-forge-mcp" = [ordered]@{ command = "node"; args = @($forgeEntry) }
            "local-env-mcp" = [ordered]@{ command = "node"; args = @($localEntry) }
            "my-server"     = [ordered]@{ command = "node"; args = @("/home/user/my-server.js") }
        }
        telemetry = [ordered]@{ enabled = $false }
    } | ConvertTo-Json -Depth 6
    Set-Content -Path (Join-Path $CursorDir "mcp.json") -Value $cursorJson -Encoding Utf8NoBOM

    New-Item -ItemType Directory -Path $VSCodeDir -Force | Out-Null
    $vscodeJson = @{
        servers = [ordered]@{
            "sdd-forge-mcp" = [ordered]@{ type = "stdio"; command = "node"; args = @($forgeEntry) }
            "local-env-mcp" = [ordered]@{ type = "stdio"; command = "node"; args = @($localEntry) }
            "my-server"     = [ordered]@{ type = "stdio"; command = "node"; args = @("/home/user/my-server.js") }
        }
        inputs = @()
    } | ConvertTo-Json -Depth 6
    Set-Content -Path (Join-Path $VSCodeDir "mcp.json") -Value $vscodeJson -Encoding Utf8NoBOM
}

# Scenario (o): uninstall removes ONLY the managed Cursor/VS Code keys for both
# MCPs; the user-defined key and unknown top-level keys survive.
$oRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-mcp-o-" + [guid]::NewGuid())
$oInstall = Join-Path $oRoot "installed"
$oCodexHome = Join-Path $oRoot "codex-home"
$oCursor = Join-Path $oRoot "cursor"
$oVSCode = Join-Path $oRoot "vscode-user"
$oBin = Join-Path $oRoot "bin"
$oLog = Join-Path $oRoot "commands.log"
$oOriginalPath = $env:PATH
$oOriginalCodexHome = $env:SDD_CODEX_HOME
$oOriginalCursor = $env:SDD_CURSOR_DIR
$oOriginalVSCode = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $oBin -LogPath $oLog
    New-InstalledLayout -InstallRoot $oInstall -CodexHome $oCodexHome
    New-InstalledTwoMcpLayout -InstallRoot $oInstall -CodexHome $oCodexHome -CursorDir $oCursor -VSCodeDir $oVSCode
    $env:PATH = "$oBin$([System.IO.Path]::PathSeparator)$oOriginalPath"
    $env:SDD_CODEX_HOME = $oCodexHome
    $env:SDD_CURSOR_DIR = $oCursor
    $env:SDD_VSCODE_USER_DIR = $oVSCode

    $oFailed = $false
    try { & $uninstaller -InstallRoot $oInstall -Target All -Mcp @("sdd-forge-mcp", "local-env-mcp") *>$null } catch { $oFailed = $true }

    if ($oFailed) { throw "Cursor/VSCode (o): uninstaller threw" }
    $oCur = Get-Content -Raw (Join-Path $oCursor "mcp.json")
    $oVsc = Get-Content -Raw (Join-Path $oVSCode "mcp.json")
    if ($oCur -match '"sdd-forge-mcp"') { throw "Cursor (o): managed sdd-forge-mcp key not removed" }
    if ($oCur -match '"local-env-mcp"') { throw "Cursor (o): managed local-env-mcp key not removed" }
    if ($oVsc -match '"sdd-forge-mcp"') { throw "VSCode (o): managed sdd-forge-mcp key not removed" }
    if ($oVsc -match '"local-env-mcp"') { throw "VSCode (o): managed local-env-mcp key not removed" }
    if ($oCur -notmatch '"my-server"') { throw "Cursor (o): user-defined my-server key was removed" }
    if ($oCur -notmatch '"telemetry"') { throw "Cursor (o): unknown top-level telemetry key was removed" }
    if ($oVsc -notmatch '"my-server"') { throw "VSCode (o): user-defined my-server key was removed" }
    if ($oVsc -notmatch '"inputs"') { throw "VSCode (o): unknown top-level inputs key was removed" }
    $null = $oCur | ConvertFrom-Json
    $null = $oVsc | ConvertFrom-Json
    Write-Host "ok: uninstall removes only managed Cursor/VS Code keys for both MCPs, preserves user + unknown keys"
}
finally {
    $env:PATH = $oOriginalPath
    if ($null -eq $oOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $oOriginalCodexHome }
    if ($null -eq $oOriginalCursor) { Remove-Item Env:SDD_CURSOR_DIR -ErrorAction SilentlyContinue } else { $env:SDD_CURSOR_DIR = $oOriginalCursor }
    if ($null -eq $oOriginalVSCode) { Remove-Item Env:SDD_VSCODE_USER_DIR -ErrorAction SilentlyContinue } else { $env:SDD_VSCODE_USER_DIR = $oOriginalVSCode }
    if (Test-Path $oRoot) { Remove-Item -Path $oRoot -Recurse -Force }
}

# Scenario (p): both managed MCPs fully removed — payloads gone, claude mcp
# remove invoked for each, both Codex marker blocks stripped, unrelated Codex
# section preserved.
$pRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-mcp-p-" + [guid]::NewGuid())
$pInstall = Join-Path $pRoot "installed"
$pCodexHome = Join-Path $pRoot "codex-home"
$pCursor = Join-Path $pRoot "cursor"
$pVSCode = Join-Path $pRoot "vscode-user"
$pBin = Join-Path $pRoot "bin"
$pLog = Join-Path $pRoot "commands.log"
$pOriginalPath = $env:PATH
$pOriginalCodexHome = $env:SDD_CODEX_HOME
$pOriginalCursor = $env:SDD_CURSOR_DIR
$pOriginalVSCode = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $pBin -LogPath $pLog
    New-InstalledLayout -InstallRoot $pInstall -CodexHome $pCodexHome
    New-InstalledTwoMcpLayout -InstallRoot $pInstall -CodexHome $pCodexHome -CursorDir $pCursor -VSCodeDir $pVSCode
    $env:PATH = "$pBin$([System.IO.Path]::PathSeparator)$pOriginalPath"
    $env:SDD_CODEX_HOME = $pCodexHome
    $env:SDD_CURSOR_DIR = $pCursor
    $env:SDD_VSCODE_USER_DIR = $pVSCode

    $pFailed = $false
    try { & $uninstaller -InstallRoot $pInstall -Target All -Mcp @("sdd-forge-mcp", "local-env-mcp") *>$null } catch { $pFailed = $true }

    if ($pFailed) { throw "both-MCP removal (p): uninstaller threw" }
    # Both payloads must be gone (here via full install-root removal; scenario
    # (m) already covers payload selection semantics for a single MCP).
    if (Test-Path (Join-Path (Join-Path $pInstall "mcp") "sdd-forge-mcp")) { throw "both-MCP removal (p): sdd-forge-mcp payload not removed" }
    if (Test-Path (Join-Path (Join-Path $pInstall "mcp") "local-env-mcp")) { throw "both-MCP removal (p): local-env-mcp payload not removed" }
    $pLogContent = if (Test-Path $pLog) { Get-Content -Raw $pLog } else { "" }
    if ($pLogContent -notmatch [regex]::Escape("claude mcp remove sdd-forge-mcp")) { throw "both-MCP removal (p): claude mcp remove sdd-forge-mcp not invoked" }
    if ($pLogContent -notmatch [regex]::Escape("claude mcp remove local-env-mcp")) { throw "both-MCP removal (p): claude mcp remove local-env-mcp not invoked" }
    $pConfig = Get-Content -Raw (Join-Path $pCodexHome "config.toml")
    if ($pConfig -match "sdd-forge-mcp") { throw "both-MCP removal (p): sdd-forge-mcp Codex block not removed" }
    if ($pConfig -match "local-env-mcp") { throw "both-MCP removal (p): local-env-mcp Codex block not removed" }
    if ($pConfig -notmatch "some_other_section") { throw "both-MCP removal (p): unrelated Codex section removed" }
    Write-Host "ok: uninstall removes both managed MCP payloads, Claude regs, and both Codex marker blocks"
}
finally {
    $env:PATH = $pOriginalPath
    if ($null -eq $pOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $pOriginalCodexHome }
    if ($null -eq $pOriginalCursor) { Remove-Item Env:SDD_CURSOR_DIR -ErrorAction SilentlyContinue } else { $env:SDD_CURSOR_DIR = $pOriginalCursor }
    if ($null -eq $pOriginalVSCode) { Remove-Item Env:SDD_VSCODE_USER_DIR -ErrorAction SilentlyContinue } else { $env:SDD_VSCODE_USER_DIR = $pOriginalVSCode }
    if (Test-Path $pRoot) { Remove-Item -Path $pRoot -Recurse -Force }
}

# Scenario (q): corrupt Cursor mcp.json is left BYTE-IDENTICAL (fail-safe) while
# the VS Code client is still cleaned (per-client continuation).
$qRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-mcp-q-" + [guid]::NewGuid())
$qInstall = Join-Path $qRoot "installed"
$qCodexHome = Join-Path $qRoot "codex-home"
$qCursor = Join-Path $qRoot "cursor"
$qVSCode = Join-Path $qRoot "vscode-user"
$qBin = Join-Path $qRoot "bin"
$qLog = Join-Path $qRoot "commands.log"
$qOriginalPath = $env:PATH
$qOriginalCodexHome = $env:SDD_CODEX_HOME
$qOriginalCursor = $env:SDD_CURSOR_DIR
$qOriginalVSCode = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $qBin -LogPath $qLog
    New-InstalledLayout -InstallRoot $qInstall -CodexHome $qCodexHome
    New-InstalledTwoMcpLayout -InstallRoot $qInstall -CodexHome $qCodexHome -CursorDir $qCursor -VSCodeDir $qVSCode
    # Corrupt the Cursor file AFTER seeding (truncated / invalid JSON).
    Set-Content -Path (Join-Path $qCursor "mcp.json") -Value '{ "mcpServers": { "sdd-forge-mcp": { not valid json' -Encoding Utf8NoBOM -NoNewline
    $qCursorBefore = (Get-FileHash -Algorithm SHA256 (Join-Path $qCursor "mcp.json")).Hash
    $env:PATH = "$qBin$([System.IO.Path]::PathSeparator)$qOriginalPath"
    $env:SDD_CODEX_HOME = $qCodexHome
    $env:SDD_CURSOR_DIR = $qCursor
    $env:SDD_VSCODE_USER_DIR = $qVSCode

    $qFailed = $false
    $qErr = $null
    try { $qErr = (& $uninstaller -InstallRoot $qInstall -Target All -Mcp @("sdd-forge-mcp", "local-env-mcp") -KeepFiles 2>&1 | Out-String) } catch { $qFailed = $true }

    if ($qFailed) { throw "corrupt JSON (q): uninstaller threw instead of continuing" }
    $qCursorAfter = (Get-FileHash -Algorithm SHA256 (Join-Path $qCursor "mcp.json")).Hash
    if ($qCursorBefore -ne $qCursorAfter) { throw "corrupt JSON (q): corrupt Cursor mcp.json was modified" }
    if ($qErr -notmatch "invalid JSON") { throw "corrupt JSON (q): no invalid-JSON error notice was emitted" }
    $qVsc = Get-Content -Raw (Join-Path $qVSCode "mcp.json")
    if ($qVsc -match '"sdd-forge-mcp"') { throw "corrupt JSON (q): VS Code managed key not removed (client continuation failed)" }
    Write-Host "ok: corrupt Cursor mcp.json left unmodified with error notice; VS Code still cleaned"
}
finally {
    $env:PATH = $qOriginalPath
    if ($null -eq $qOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $qOriginalCodexHome }
    if ($null -eq $qOriginalCursor) { Remove-Item Env:SDD_CURSOR_DIR -ErrorAction SilentlyContinue } else { $env:SDD_CURSOR_DIR = $qOriginalCursor }
    if ($null -eq $qOriginalVSCode) { Remove-Item Env:SDD_VSCODE_USER_DIR -ErrorAction SilentlyContinue } else { $env:SDD_VSCODE_USER_DIR = $qOriginalVSCode }
    if (Test-Path $qRoot) { Remove-Item -Path $qRoot -Recurse -Force }
}

# Scenario (r): absent Cursor/VS Code dirs → silent skip (no error), and the
# rest of the uninstall (payloads, Codex) still completes.
$rRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-uninstall-mcp-r-" + [guid]::NewGuid())
$rInstall = Join-Path $rRoot "installed"
$rCodexHome = Join-Path $rRoot "codex-home"
$rBin = Join-Path $rRoot "bin"
$rLog = Join-Path $rRoot "commands.log"
$rNoCursor = Join-Path $rRoot "no-such-cursor"
$rNoVSCode = Join-Path $rRoot "no-such-vscode"
$rOriginalPath = $env:PATH
$rOriginalCodexHome = $env:SDD_CODEX_HOME
$rOriginalCursor = $env:SDD_CURSOR_DIR
$rOriginalVSCode = $env:SDD_VSCODE_USER_DIR
try {
    New-FakeCommands -BinRoot $rBin -LogPath $rLog
    New-InstalledLayout -InstallRoot $rInstall -CodexHome $rCodexHome
    $env:PATH = "$rBin$([System.IO.Path]::PathSeparator)$rOriginalPath"
    $env:SDD_CODEX_HOME = $rCodexHome
    $env:SDD_CURSOR_DIR = $rNoCursor
    $env:SDD_VSCODE_USER_DIR = $rNoVSCode

    $rFailed = $false
    try { & $uninstaller -InstallRoot $rInstall -Target All -Mcp @("sdd-forge-mcp", "local-env-mcp") *>$null } catch { $rFailed = $true }

    if ($rFailed) { throw "absent Cursor/VSCode dir (r): uninstaller threw" }
    if (Test-Path $rInstall) { throw "absent Cursor/VSCode dir (r): install root not removed" }
    if (Test-Path $rNoCursor) { throw "absent Cursor/VSCode dir (r): uninstaller created the Cursor dir" }
    if (Test-Path $rNoVSCode) { throw "absent Cursor/VSCode dir (r): uninstaller created the VS Code dir" }
    Write-Host "ok: absent Cursor/VS Code dirs are skipped without error and without directory creation"
}
finally {
    $env:PATH = $rOriginalPath
    if ($null -eq $rOriginalCodexHome) { Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue } else { $env:SDD_CODEX_HOME = $rOriginalCodexHome }
    if ($null -eq $rOriginalCursor) { Remove-Item Env:SDD_CURSOR_DIR -ErrorAction SilentlyContinue } else { $env:SDD_CURSOR_DIR = $rOriginalCursor }
    if ($null -eq $rOriginalVSCode) { Remove-Item Env:SDD_VSCODE_USER_DIR -ErrorAction SilentlyContinue } else { $env:SDD_VSCODE_USER_DIR = $rOriginalVSCode }
    if (Test-Path $rRoot) { Remove-Item -Path $rRoot -Recurse -Force }
}

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
