$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# installer-idempotency.tests.ps1 — PowerShell twin of
# installer-idempotency.tests.sh. WFI-041 regression suite.
#
# Covers the three behaviours WFI-041 introduced, and the one it deliberately
# preserved:
#
#   1. Registration is idempotent. An external CLI reporting "already
#      registered" / "already exists" is the desired end state, not a failure.
#   2. `claude plugin install` reporting an existing installation triggers an
#      upgrade path, and the version transition is reported.
#   3. A registration failure no longer reverts the install root.
#   4. A *placement*-phase failure still does.
#
# Cases 2 and 4 each carry their own negative control, because both are easy to
# satisfy vacuously: an upgrade check passes on a tool that always updates, and
# a "rollback did not fire" check passes on an installer that never rolls back.

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot "install.ps1"
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

# The messages below are the ones the real CLIs emitted on 2026-08-22 while
# upgrading a developer machine from 1.15.0 to 1.16.0 (WFI-041 "Problem
# Evidence"). They are the contract this suite pins: if a CLI changes its
# wording, the tolerance must be revisited, and this suite is where that shows
# up first. Kept byte-identical with the sh twin.
$MsgMarketplaceExists = 'Failed to add marketplace: Error: Marketplace "sdd-plugins" already registered'
$MsgMcpExists         = 'MCP server sdd-forge-mcp already exists in user config'
$MsgPluginInstalled   = 'Plugin is already installed (scope: user)'
# The two CLI families disagree about which outcome an existing plugin is.
# Codex and Copilot report it the way they report an existing marketplace — as
# a non-zero error — which is why the plugin-add loops need the same tolerance
# as the marketplace-add calls. The real 2026-08-22 upgrade never reached these
# calls (marketplace-add failed first), so this half of the contract is
# inferred from the marketplace behaviour rather than observed.
# Deliberately does not name a plugin: the stub is shared across the whole
# dependency closure, and a hardcoded name would read as if only that plugin
# were affected. Batch-safe (no quotes, no & | > characters) so the .cmd shim
# on Windows emits the identical string.
$MsgPluginAdded       = 'Error: this plugin is already added'
$MsgPluginUpgraded    = 'Plugin updated from 1.15.0 to 1.16.0'
$MsgPluginCurrent     = 'Plugin is up to date at 1.16.0'
$MsgUnrelated         = 'Error: could not write to disk'

# ---------------------------------------------------------------------------
# Source fixture
# ---------------------------------------------------------------------------
$sourceFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-idem-src-" + [guid]::NewGuid())
$sourceFixture = Join-Path $sourceFixtureRoot "source"
New-Item -ItemType Directory -Path $sourceFixture -Force | Out-Null

$archive = Join-Path $sourceFixtureRoot "fixture.tar"
& git -C $repositoryRoot archive --format=tar --output=$archive HEAD -- ':(exclude)specs' ':(exclude)reports'
if ($LASTEXITCODE -ne 0) { throw "git archive failed while building the source fixture." }
& tar -xf $archive -C $sourceFixture
if ($LASTEXITCODE -ne 0) { throw "tar extraction failed while building the source fixture." }
Remove-Item -Path $archive -Force

& git -C $sourceFixture init -q
# Commits here can spawn detached background maintenance that races teardown.
& git -C $sourceFixture config gc.auto 0
& git -C $sourceFixture config gc.autoDetach false
& git -C $sourceFixture config maintenance.auto false
# Overlay the working tree's installer so the suite exercises this checkout
# rather than HEAD.
Copy-Item -Path (Join-Path $repositoryRoot "install.ps1") -Destination (Join-Path $sourceFixture "install.ps1") -Force
Copy-Item -Path (Join-Path $repositoryRoot "install.sh") -Destination (Join-Path $sourceFixture "install.sh") -Force
& git -C $sourceFixture add -A
& git -C $sourceFixture -c user.name="Installer Test" -c user.email="installer-test@example.invalid" commit -qm "Fixture baseline"
if ($LASTEXITCODE -ne 0) { throw "fixture commit failed." }

# Minimal MCP payload. Install-McpServerPayloads copies this during the
# *placement* phase, which is what the placement-failure case injects into.
$mcpDist = Join-Path $sourceFixture "mcp/sdd-forge-mcp/dist"
New-Item -ItemType Directory -Path $mcpDist -Force | Out-Null
$mcpIndex = Join-Path $mcpDist "index.js"
Set-Content -Path $mcpIndex -Value "console.log(`"stub`");" -Encoding Utf8NoBOM
Set-Content -Path (Join-Path $sourceFixture "mcp/sdd-forge-mcp/package.json") `
    -Value '{ "name": "sdd-forge-mcp", "version": "0.1.0", "private": true }' -Encoding Utf8NoBOM

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------
# Modes:
#   fresh              every registration succeeds silently (clean machine)
#   installed          marketplace-add and mcp-add fail with the real
#                      "already ..." messages; plugin install reports an
#                      existing installation; plugin update reports a
#                      version transition
#   current            like `installed`, but plugin update reports no
#                      transition (the machine is already at the new version)
#   unrelated-failure  marketplace-add fails with a message that is not an
#                      idempotency message
function New-Stubs {
    param(
        [Parameter(Mandatory)][string]$BinRoot,
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][ValidateSet("fresh", "installed", "current", "unrelated-failure")][string]$Mode
    )

    New-Item -ItemType Directory -Path $BinRoot -Force | Out-Null

    # Per-mode bodies, expressed once per shell dialect.
    $marketplaceFails = $Mode -in @("installed", "current", "unrelated-failure")
    $marketplaceMsg = if ($Mode -eq "unrelated-failure") { $MsgUnrelated } else { $MsgMarketplaceExists }
    $mcpFails = $Mode -in @("installed", "current")
    $claudeInstallMsg = if ($Mode -in @("installed", "current")) { $MsgPluginInstalled } else { "" }
    $otherInstallFails = $Mode -in @("installed", "current")
    $updateMsg = switch ($Mode) {
        "installed" { $MsgPluginUpgraded }
        "current"   { $MsgPluginCurrent }
        default     { "" }
    }

    foreach ($command in @("codex", "claude", "copilot")) {
        if ($isWindowsPlatform) {
            $marketplaceBody = if ($marketplaceFails) { "(echo $marketplaceMsg 1>&2 & exit /b 1)" } else { "exit /b 0" }
            $mcpBody = if ($mcpFails) { "(echo $MsgMcpExists 1>&2 & exit /b 1)" } else { "exit /b 0" }
            $installBody = if ($command -eq "claude") {
                if ($claudeInstallMsg) { "(echo $claudeInstallMsg & exit /b 0)" } else { "exit /b 0" }
            }
            elseif ($otherInstallFails) { "(echo $MsgPluginAdded 1>&2 & exit /b 1)" } else { "exit /b 0" }
            $updateBody = if ($updateMsg) { "(echo $updateMsg & exit /b 0)" } else { "exit /b 0" }
            $lines = @(
                "@echo off",
                "echo $command %*>>`"$LogPath`"",
                "echo %*| findstr /c:`"plugin marketplace update`" >nul && exit /b 0",
                "echo %*| findstr /c:`"plugin marketplace add`" >nul && $marketplaceBody",
                "echo %*| findstr /c:`"plugin update`" >nul && $updateBody",
                "echo %*| findstr /c:`"plugin install`" >nul && $installBody",
                "echo %*| findstr /c:`"plugin add`" >nul && $installBody",
                "echo %*| findstr /c:`"mcp add`" >nul && $mcpBody",
                "exit /b 0"
            )
            Set-Content -Path (Join-Path $BinRoot "$command.cmd") -Value ($lines -join "`r`n") -Encoding Ascii
        }
        else {
            $marketplaceBody = if ($marketplaceFails) { "echo '$marketplaceMsg' >&2; exit 1" } else { "exit 0" }
            $mcpBody = if ($mcpFails) { "echo '$MsgMcpExists' >&2; exit 1" } else { "exit 0" }
            $installBody = if ($command -eq "claude") {
                if ($claudeInstallMsg) { "echo '$claudeInstallMsg'; exit 0" } else { "exit 0" }
            }
            elseif ($otherInstallFails) { "echo '$MsgPluginAdded' >&2; exit 1" } else { "exit 0" }
            $updateBody = if ($updateMsg) { "echo '$updateMsg'; exit 0" } else { "exit 0" }
            $lines = @(
                "#!/bin/sh",
                "echo `"$command `$*`" >> `"$LogPath`"",
                'case "$*" in',
                "  `"plugin marketplace update`"*) exit 0 ;;",
                "  `"plugin marketplace add`"*) $marketplaceBody ;;",
                "  `"plugin update`"*) $updateBody ;;",
                "  `"plugin install`"*|`"plugin add`"*) $installBody ;;",
                "  `"mcp add`"*) $mcpBody ;;",
                "esac",
                "exit 0"
            )
            $commandPath = Join-Path $BinRoot $command
            Set-Content -Path $commandPath -Value ($lines -join "`n") -Encoding Utf8NoBOM
            & chmod +x $commandPath
        }
    }

    # Report a Node version that clears the >= 22.19.0 gate, so MCP placement
    # runs on every host regardless of the real toolchain.
    if ($isWindowsPlatform) {
        Set-Content -Path (Join-Path $BinRoot "node.cmd") -Value "@echo off`r`necho v22.19.0`r`nexit /b 0" -Encoding Ascii
    }
    else {
        $nodePath = Join-Path $BinRoot "node"
        Set-Content -Path $nodePath -Value "#!/bin/sh`necho v22.19.0`n" -Encoding Utf8NoBOM
        & chmod +x $nodePath
    }
}

# ---------------------------------------------------------------------------
# Scenario runner
# ---------------------------------------------------------------------------
function Invoke-IdempotencyScenario {
    param(
        [Parameter(Mandatory)][ValidateSet("fresh", "installed", "current", "unrelated-failure")][string]$Mode,
        [switch]$SeedExistingInstall,
        [switch]$BreakPlacement
    )

    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-idem-" + [guid]::NewGuid())
    $installRoot = Join-Path $testRoot "installed"
    $binRoot = Join-Path $testRoot "bin"
    $logPath = Join-Path $testRoot "commands.log"
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    Set-Content -Path $logPath -Value "" -Encoding Utf8NoBOM

    New-Stubs -BinRoot $binRoot -LogPath $logPath -Mode $Mode

    if ($SeedExistingInstall) {
        New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
        Set-Content -Path (Join-Path $installRoot "existing.marker") -Value "keep" -Encoding Ascii
    }

    # Placement-phase injection. Install-McpServerPayloads sees the payload
    # (Test-Path succeeds) and then fails to read it, which is a real failure
    # inside the placement window rather than a simulated one. The two
    # platforms need different mechanisms: POSIX permissions do not stop a
    # copy on Windows, and .NET share-mode locks do not stop one on POSIX.
    $lockStream = $null
    if ($BreakPlacement) {
        if ($isWindowsPlatform) {
            $lockStream = [System.IO.File]::Open($mcpIndex, 'Open', 'Read', 'None')
        }
        else {
            & chmod 000 $mcpIndex
        }
    }

    $originalPath = $env:PATH
    $originalCodexHome = $env:SDD_CODEX_HOME
    $env:PATH = "$binRoot$([System.IO.Path]::PathSeparator)$originalPath"
    $env:SDD_CODEX_HOME = Join-Path $testRoot "codex-home"

    # `*>` sends every stream to the transcript file. Assigning a captured
    # pipeline to a variable instead would lose everything the installer wrote
    # before it threw — which is exactly the output the failure cases assert
    # on — and would miss Write-Host and Write-Warning besides.
    $transcript = Join-Path $testRoot "installer-output.txt"
    $failed = $false
    try {
        & $installer -SourceDirectory $sourceFixture -InstallRoot $installRoot `
            -Target All -Plugins @("sdd-bootstrap") -Mcp @("sdd-forge-mcp") *> $transcript
    }
    catch {
        $failed = $true
        Add-Content -Path $transcript -Value "$_"
    }
    finally {
        $env:PATH = $originalPath
        if ($null -eq $originalCodexHome) {
            Remove-Item Env:SDD_CODEX_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:SDD_CODEX_HOME = $originalCodexHome
        }
        if ($BreakPlacement) {
            if ($lockStream) { $lockStream.Dispose() }
            if (-not $isWindowsPlatform) { & chmod 644 $mcpIndex }
        }
    }

    return @{
        Failed      = $failed
        Output      = (Get-Content -Path $transcript -Raw -ErrorAction SilentlyContinue)
        Log         = (Get-Content -Path $logPath -Raw -ErrorAction SilentlyContinue)
        InstallRoot = $installRoot
        TestRoot    = $testRoot
    }
}

function Test-InstalledTreePresent {
    param([Parameter(Mandatory)][string]$InstallRoot)
    return (Test-Path (Join-Path $InstallRoot "plugins/sdd-bootstrap/.codex-plugin/plugin.json"))
}

function Test-NoBackupLeft {
    param([Parameter(Mandatory)][string]$TestRoot)
    return -not (Get-ChildItem -Path $TestRoot -Filter "sdd-plugins-backup-*" -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Case 1: re-running against already-registered CLIs succeeds
# ---------------------------------------------------------------------------
$c1 = Invoke-IdempotencyScenario -Mode installed -SeedExistingInstall
try {
    if ($c1.Failed) { throw "Re-run against already-registered CLIs should have succeeded. Output:`n$($c1.Output)" }
    if (-not (Test-InstalledTreePresent $c1.InstallRoot)) { throw "Re-run did not leave the new tree in the install root." }
    if (-not (Test-NoBackupLeft $c1.TestRoot)) { throw "Re-run left a backup directory behind." }
    if ($c1.Output -notmatch "is already registered; keeping the existing registration") {
        throw "Re-run did not report the tolerated registrations. Installer output:`n$($c1.Output)"
    }
    # The marketplace, the MCP server and the per-plugin registrations must all
    # be tolerated. Asserting only one of them would pass on a fix that covered
    # the marketplace and left the plugin loops fatal — which is what run 2 of
    # a real upgrade would hit first.
    foreach ($label in @("the Codex sdd-plugins marketplace", "MCP server 'sdd-forge-mcp'", "Codex plugin 'sdd-bootstrap'", "Copilot plugin 'sdd-bootstrap'")) {
        if ($c1.Output -notmatch [regex]::Escape("Note: $label is already registered")) {
            # The installer output is attached because the interesting
            # failures are the ones where a registration never ran at all —
            # the scenario runner sends every stream to a transcript, so the
            # warning that explains why (skipped MCP placement, missing Node,
            # absent payload) is captured rather than printed, and without it
            # the message says only that something did not happen.
            throw "Re-run did not tolerate: $label`nInstaller output:`n$($c1.Output)"
        }
    }
    Write-Host "ok: already-registered marketplaces and MCP servers are tolerated"
}
finally { if (Test-Path $c1.TestRoot) { Remove-Item -Path $c1.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Case 2 (negative control for case 1): an unrelated failure is still fatal
# ---------------------------------------------------------------------------
$c2 = Invoke-IdempotencyScenario -Mode unrelated-failure
try {
    if (-not $c2.Failed) { throw "A registration failure with an unrelated message must stay fatal." }
    if ($c2.Output -notmatch "failed with exit code") { throw "Unrelated registration failure did not name the failing command." }
    if ($c2.Output -match "is already registered; keeping") {
        throw "Unrelated registration failure was wrongly tolerated as idempotent."
    }
    Write-Host "ok: a non-idempotency registration failure is still fatal"
}
finally { if (Test-Path $c2.TestRoot) { Remove-Item -Path $c2.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Case 3: an existing Claude installation is upgraded, and the transition is
#         reported
# ---------------------------------------------------------------------------
$c3 = Invoke-IdempotencyScenario -Mode installed
try {
    if ($c3.Failed) { throw "Upgrade run should have succeeded. Output:`n$($c3.Output)" }
    if ($c3.Log -notmatch [regex]::Escape("claude plugin marketplace update sdd-plugins")) {
        throw "Upgrade path did not refresh the marketplace."
    }
    if ($c3.Log -notmatch [regex]::Escape("claude plugin update sdd-bootstrap@sdd-plugins")) {
        throw "Upgrade path did not update the already-installed plugin."
    }
    if ($c3.Output -notmatch [regex]::Escape("sdd-forge: upgraded sdd-bootstrap (updated from 1.15.0 to 1.16.0)")) {
        throw "Upgrade run did not report the version transition."
    }
    # The summary count must equal the number of per-plugin transition lines.
    # Comparing the two rather than hardcoding a number keeps this independent
    # of the dependency closure -Plugins expands to (sdd-bootstrap pulls in
    # sdd-review-loop), while still catching a summary that reports a fixed
    # count.
    $transitions = ([regex]::Matches($c3.Output, '(?m)^sdd-forge: upgraded [a-z-]+ \(updated from ')).Count
    $summary = [regex]::Match($c3.Output, '(?m)^sdd-forge: upgraded (\d+) Claude plugin\(s\)\.\s*$')
    if (-not $summary.Success) { throw "Upgrade run did not summarise the upgrade count." }
    if ([int]$summary.Groups[1].Value -ne $transitions) {
        throw "Upgrade summary count ($($summary.Groups[1].Value)) does not match the $transitions reported transitions."
    }
    Write-Host "ok: an already-installed Claude plugin is upgraded and the transition reported"
}
finally { if (Test-Path $c3.TestRoot) { Remove-Item -Path $c3.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Case 4 (negative control for case 3): a machine already at the new version
#         reports no change
# ---------------------------------------------------------------------------
$c4 = Invoke-IdempotencyScenario -Mode current
try {
    if ($c4.Failed) { throw "No-change run should have succeeded. Output:`n$($c4.Output)" }
    if ($c4.Output -notmatch [regex]::Escape("sdd-forge: sdd-bootstrap was already up to date")) {
        throw "No-change run did not report that nothing moved."
    }
    if ($c4.Output -notmatch [regex]::Escape("sdd-forge: no Claude plugin needed an upgrade.")) {
        throw "No-change run did not summarise zero upgrades."
    }
    if ($c4.Output -match [regex]::Escape("sdd-forge: upgraded sdd-bootstrap")) {
        throw "No-change run reported an upgrade that did not happen."
    }
    Write-Host "ok: a machine already at the new version reports no upgrade"
}
finally { if (Test-Path $c4.TestRoot) { Remove-Item -Path $c4.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Case 5 (second control for case 3): a clean machine never enters the upgrade
#         path
# ---------------------------------------------------------------------------
$c5 = Invoke-IdempotencyScenario -Mode fresh
try {
    if ($c5.Failed) { throw "Clean install should have succeeded. Output:`n$($c5.Output)" }
    if ($c5.Log -match [regex]::Escape("claude plugin update")) {
        throw "Clean install invoked the upgrade path it had no reason to enter."
    }
    if ($c5.Output -match [regex]::Escape("sdd-forge: upgraded")) {
        throw "Clean install reported an upgrade."
    }
    Write-Host "ok: a clean install does not enter the upgrade path"
}
finally { if (Test-Path $c5.TestRoot) { Remove-Item -Path $c5.TestRoot -Recurse -Force } }

# ---------------------------------------------------------------------------
# Case 6: a placement-phase failure still reverts the install root
# ---------------------------------------------------------------------------
# The POSIX injection depends on the process not being able to read a
# chmod-000 file. Running as root defeats that, so probe first and say so
# rather than passing on an injection that never fired.
$placementInjectable = $true
if (-not $isWindowsPlatform) {
    & chmod 000 $mcpIndex
    try {
        Get-Content -Path $mcpIndex -Raw -ErrorAction Stop | Out-Null
        $placementInjectable = $false
    }
    catch { $placementInjectable = $true }
    & chmod 644 $mcpIndex
}
if (-not $placementInjectable) {
    Write-Host "skip - placement-phase rollback: this process can read a chmod-000 file (running as root?), so the injection would not fire"
}
else {
    $c6 = Invoke-IdempotencyScenario -Mode fresh -SeedExistingInstall -BreakPlacement
    try {
        if (-not $c6.Failed) { throw "A placement-phase failure must be fatal." }
        if (-not (Test-Path (Join-Path $c6.InstallRoot "existing.marker"))) {
            throw "A placement-phase failure did not restore the previous installation."
        }
        if (Test-InstalledTreePresent $c6.InstallRoot) {
            throw "A placement-phase failure left the half-written tree in place."
        }
        Write-Host "ok: a placement-phase failure still reverts the install root"
    }
    finally { if (Test-Path $c6.TestRoot) { Remove-Item -Path $c6.TestRoot -Recurse -Force } }
}

# ---------------------------------------------------------------------------
# Case 7: a registration-phase failure does not revert, and names what failed
# ---------------------------------------------------------------------------
$c7 = Invoke-IdempotencyScenario -Mode unrelated-failure -SeedExistingInstall
try {
    if (-not $c7.Failed) { throw "A registration-phase failure must still be fatal." }
    if (Test-Path (Join-Path $c7.InstallRoot "existing.marker")) {
        throw "A registration-phase failure reverted the install root."
    }
    if (-not (Test-InstalledTreePresent $c7.InstallRoot)) {
        throw "A registration-phase failure discarded the newly placed tree."
    }
    if (-not (Test-NoBackupLeft $c7.TestRoot)) {
        throw "A registration-phase failure left a backup directory behind."
    }
    if ($c7.Output -notmatch "was left at the newly installed version") {
        throw "A registration-phase failure did not say the install root was kept."
    }
    if ($c7.Output -notmatch [regex]::Escape("plugin marketplace add")) {
        throw "A registration-phase failure did not name the failing registration."
    }
    Write-Host "ok: a registration-phase failure keeps the new version and names what failed"
}
finally { if (Test-Path $c7.TestRoot) { Remove-Item -Path $c7.TestRoot -Recurse -Force } }

if (Test-Path $sourceFixtureRoot) { Remove-Item -Path $sourceFixtureRoot -Recurse -Force }

Write-Host ""
Write-Host "installer-idempotency.tests.ps1: all scenarios passed."

# Reaching this line means every assertion held — failures throw, and
# $ErrorActionPreference is Stop, so there is no path here from a failed case.
#
# The explicit exit is not decoration. Several cases drive the installer to
# fail on purpose, which leaves $LASTEXITCODE at 1 from the stub that failed.
# GitHub Actions runs `shell: pwsh` as
#   pwsh -command ". 'script'"; if (Test-Path variable:\LASTEXITCODE) { exit $LASTEXITCODE }
# so without this the step fails with exit 1 *after* printing that all
# scenarios passed. That is exactly how this suite first broke main
# (2026-08-23, run 32648032515): green locally under `pwsh -File`, which uses
# the script's own exit code and never sees the leaked one.
exit 0
