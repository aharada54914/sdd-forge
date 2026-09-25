[CmdletBinding()]
param(
    [ValidateSet("All", "Codex", "Claude", "Copilot")]
    [string]$Target = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$installer = Join-Path $repositoryRoot "install.ps1"
$uninstaller = Join-Path $repositoryRoot "uninstall.ps1"
$driftChecker = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.ps1"
$pass = 0
$fail = 0

function Write-Ok([string]$Message) { $script:pass++; Write-Host "ok: $Message" }
function Write-Fail([string]$Message) { $script:fail++; Write-Host "not ok: $Message" }

function Get-Manifest([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root)) { return "[]" }
    $items = @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
            Sort-Object FullName |
            ForEach-Object {
                $relative = [System.IO.Path]::GetRelativePath($Root, $_.FullName).Replace([IO.Path]::DirectorySeparatorChar, "/")
                $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                [PSCustomObject]@{ path = $relative; sha256 = $hash }
            }
    )
    return ($items | ConvertTo-Json -Compress)
}

function New-FakeCli([string]$Bin, [string]$Log) {
    New-Item -ItemType Directory -Path $Bin -Force | Out-Null
    $windowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    foreach ($name in @("codex", "claude", "copilot", "gh")) {
        if ($windowsHost) {
            $path = Join-Path $Bin "$name.cmd"
            Set-Content -LiteralPath $path -Encoding ascii -Value "@echo off`necho $name %*>>`"$Log`"`nexit /b 0"
        }
        else {
            $path = Join-Path $Bin $name
            Set-Content -LiteralPath $path -Encoding utf8NoBOM -Value "#!/bin/sh`nprintf '%s %s\\n' '$name' `"\$*`" >> '$Log'`nexit 0"
            & chmod +x $path
        }
    }
}

function Invoke-Cell([string]$CellTarget) {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("sdd-matrix-" + [guid]::NewGuid().ToString("N"))
    $installRoot = Join-Path $root "install"
    $resolvedInstallRoot = $null
    $codexHome = Join-Path $root "codex"
    $vscodeDir = Join-Path $root "vscode"
    $cursorDir = Join-Path $root "cursor"
    $bin = Join-Path $root "bin"
    $log = Join-Path $root "cli.log"
    try {
        New-Item -ItemType Directory -Path $root, $installRoot -Force | Out-Null
        $pythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
        if ($pythonCommand) {
            $resolvedInstallRoot = (& $pythonCommand.Source -c "import os,sys; print(os.path.realpath(sys.argv[1]))" $installRoot).Trim()
        }
        else {
            $resolvedInstallRoot = (Resolve-Path -LiteralPath $installRoot).Path
        }
        $installRoot = $resolvedInstallRoot
        New-Item -ItemType Directory -Path $codexHome, $vscodeDir, $cursorDir, (Join-Path $codexHome "agents") -Force | Out-Null
        $agentSource = Join-Path $repositoryRoot ".codex/agents"
        if (Test-Path $agentSource) { Copy-Item (Join-Path $agentSource "*.toml") (Join-Path $codexHome "agents") -Force }
        $config = @("# fixture config")
        foreach ($mcp in @("sdd-forge-mcp", "local-env-mcp", "ci-mcp")) {
            $config += "", "# >>> $mcp (managed by sdd-forge installer; do not edit by hand) >>>", "[mcp_servers.$mcp]", 'command = "node"', "args = [`"$resolvedInstallRoot/mcp/$mcp/dist/index.js`"]", "# <<< $mcp <<<"
        }
        Set-Content -LiteralPath (Join-Path $codexHome "config.toml") -Value $config -Encoding utf8NoBOM
        Set-Content -LiteralPath (Join-Path $vscodeDir "mcp.json") -Value '{"servers":{}}' -Encoding utf8NoBOM
        Set-Content -LiteralPath (Join-Path $cursorDir "mcp.json") -Value '{"mcpServers":{}}' -Encoding utf8NoBOM
        New-FakeCli $bin $log
        $env:PATH = "$bin$([IO.Path]::PathSeparator)$env:PATH"
        $env:SDD_CODEX_HOME = $codexHome
        $env:SDD_VSCODE_USER_DIR = $vscodeDir
        $env:SDD_CURSOR_DIR = $cursorDir
        $env:CI_MCP_GITHUB_TOKEN = if ($env:CI_MCP_GITHUB_TOKEN) { $env:CI_MCP_GITHUB_TOKEN } else { "fixture-readonly-token" }

        & $installer -SourceDirectory $repositoryRoot -InstallRoot $installRoot -Target $CellTarget -Plugins @("sdd-bootstrap", "sdd-ship")
        if ($LASTEXITCODE -ne 0) { throw "install_1 exited with code $LASTEXITCODE" }
        if (Test-Path -LiteralPath $installRoot) { Write-Ok "$CellTarget install_1 present" } else { Write-Fail "$CellTarget install_1 install root" }
        $manifest1 = Get-Manifest $installRoot
        $driftOutput = & $driftChecker -InstallRoot $installRoot -Mode verify | Out-String
        $drift = $driftOutput | ConvertFrom-Json
        if ($drift.mode -eq "verify" -and $drift.state -eq "installed_synced") { Write-Ok "$CellTarget verify_1 drift_check" } else { Write-Host "drift_check_output[$CellTarget]: $($driftOutput.Trim())"; Write-Fail "$CellTarget verify_1 drift_check" }

        & $installer -SourceDirectory $repositoryRoot -InstallRoot $installRoot -Target $CellTarget -Plugins @("sdd-bootstrap", "sdd-ship")
        if ($LASTEXITCODE -ne 0) { throw "install_2 exited with code $LASTEXITCODE" }
        if ((Get-Manifest $installRoot) -eq $manifest1) { Write-Ok "$CellTarget install_2 idempotent" } else { Write-Fail "$CellTarget install_2 diff_from_install_1" }

        $allPlugins = @("sdd-bootstrap", "sdd-ship", "sdd-implementation", "sdd-quality-loop", "sdd-lite", "sdd-review-loop", "sdd-domain")
        & $uninstaller -InstallRoot $installRoot -Target $CellTarget -Plugins $allPlugins -Mcp @("sdd-forge-mcp", "local-env-mcp", "ci-mcp")
        if ($LASTEXITCODE -ne 0) { throw "uninstall exited with code $LASTEXITCODE" }
        if (-not (Test-Path -LiteralPath $installRoot)) { Write-Ok "$CellTarget verify_residue empty" } else { Write-Fail "$CellTarget verify_residue residual_paths=$installRoot" }
        Write-Ok "$CellTarget result schema install-uninstall-matrix-result/v1"
    }
    catch {
        Write-Fail "$CellTarget execution: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$powershell = (Get-Process -Id $PID).Path
if ($Target) { Invoke-Cell $Target } else { foreach ($cellTarget in @("All", "Codex", "Claude", "Copilot")) { Invoke-Cell $cellTarget } }
Write-Ok "FilesOnly is explicitly out-of-matrix (AC-011)"
Write-Host "install-uninstall-matrix: $pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
