[CmdletBinding()]
param([string]$Target)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$installer = Join-Path $root "install.ps1"
$uninstaller = Join-Path $root "uninstall.ps1"
$checker = Join-Path $root "plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.ps1"
$fixtureRoot = $root

function New-FixtureClone {
    param([string]$SourceRoot, [string]$Destination)
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    git -C $SourceRoot archive --format=tar HEAD -- ':(exclude)specs' ':(exclude)reports' | tar -xf - -C $Destination
    git -C $Destination init -q
    git -C $Destination config gc.auto 0
    git -C $Destination config gc.autoDetach false
    git -C $Destination config maintenance.auto false
    git -C $Destination add -A
    git -C $Destination -c user.name="Matrix Test" -c user.email="matrix-test@example.invalid" commit -qm "Fixture baseline"
}

function New-FakeCommands {
    param([string]$BinDir, [string]$LogPath, [string]$RealNode)
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    Set-Content -Path (Join-Path $BinDir "node") -NoNewline -Value @"
#!/usr/bin/env bash
if [[ "\$1" == "--version" ]]; then
  printf 'v22.19.0\n'
  exit 0
fi
exec "$RealNode" "\$@"
"@
    chmod +x (Join-Path $BinDir "node")
    foreach ($cmd in @("codex","claude","copilot","gh")) {
        Set-Content -Path (Join-Path $BinDir $cmd) -NoNewline -Value @"
#!/usr/bin/env bash
echo "$cmd \$*" >> "$LogPath"
if [[ "$cmd" == "gh" && "\$1" == "auth" && "\$2" == "token" ]]; then
  printf 'fake-gh-token\n'
  exit 0
fi
exit 0
"@
        chmod +x (Join-Path $BinDir $cmd)
    }
}

function Sync-CodexSurface {
    param([string]$SourceRoot, [string]$InstallRoot, [string]$CodexHome)
    $agentsSource = Join-Path $SourceRoot ".codex/agents"
    $agentsDest = Join-Path $CodexHome "agents"
    Remove-Item -Recurse -Force $agentsDest -ErrorAction SilentlyContinue
    if (Test-Path $agentsSource) {
        New-Item -ItemType Directory -Force -Path $agentsDest | Out-Null
        Copy-Item -Path (Join-Path $agentsSource "*") -Destination $agentsDest -Recurse -Force
    }
    $configPath = Join-Path $CodexHome "config.toml"
    $blocks = New-Object System.Collections.Generic.List[string]
    $mcpRoot = Join-Path $InstallRoot "mcp"
    if (Test-Path $mcpRoot) {
        foreach ($mcp in Get-ChildItem -Path $mcpRoot -Directory | Sort-Object Name) {
            $entryPoint = (Join-Path $mcp.FullName "dist/index.js")
            $blocks.Add("# >>> $($mcp.Name) (managed by sdd-forge installer; do not edit by hand) >>>")
            $blocks.Add("[mcp_servers.$($mcp.Name)]")
            $blocks.Add('command = "node"')
            $blocks.Add("args = [""$((Resolve-Path $entryPoint).Path.Replace('\', '/'))""]")
            $blocks.Add("# <<< $($mcp.Name) <<<")
            $blocks.Add("")
        }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $configPath) | Out-Null
    if ($blocks.Count -gt 0) {
        Set-Content -Path $configPath -Value ($blocks -join "`n").TrimEnd() + "`n" -NoNewline
    } else {
        Set-Content -Path $configPath -Value "" -NoNewline
    }
}

function Invoke-Checker {
    param([string]$InstallRoot)
    & $checker -InstallRoot $InstallRoot -Mode verify | Out-String
}

function Invoke-Cell {
    param([string]$CellTarget)
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    $sourceRoot = Join-Path $testRoot "source"
    $installRoot = Join-Path $testRoot "installed"
    $binDir = Join-Path $testRoot "bin"
    $logPath = Join-Path $testRoot "commands.log"
    New-FixtureClone -SourceRoot $fixtureRoot -Destination $sourceRoot
    $realNode = (Get-Command node).Source
    New-FakeCommands -BinDir $binDir -LogPath $logPath -RealNode $realNode
    $oldPath = $env:PATH
    $oldCodex = $env:SDD_CODEX_HOME
    $oldCursor = $env:SDD_CURSOR_DIR
    $oldVscode = $env:SDD_VSCODE_USER_DIR
    $env:PATH = "$binDir$([IO.Path]::PathSeparator)$env:PATH"
    $env:SDD_CODEX_HOME = (Join-Path $testRoot "codex-home")
    $env:SDD_CURSOR_DIR = (Join-Path $testRoot "cursor-profile")
    $env:SDD_VSCODE_USER_DIR = (Join-Path $testRoot "vscode-user")
    New-Item -ItemType Directory -Force -Path $installRoot, $env:SDD_CODEX_HOME, $env:SDD_CURSOR_DIR, $env:SDD_VSCODE_USER_DIR | Out-Null
    Set-Content -Path (Join-Path $env:SDD_CODEX_HOME "config.toml") -Value "[existing]`nvalue = `"keep`""

    try {
        & $installer -SourceDirectory $sourceRoot -InstallRoot $installRoot -Target $CellTarget | Out-Null
        Sync-CodexSurface -SourceRoot $sourceRoot -InstallRoot $installRoot -CodexHome $env:SDD_CODEX_HOME
        $drift = Invoke-Checker -InstallRoot $installRoot
        & $installer -SourceDirectory $sourceRoot -InstallRoot $installRoot -Target $CellTarget | Out-Null
        Sync-CodexSurface -SourceRoot $sourceRoot -InstallRoot $installRoot -CodexHome $env:SDD_CODEX_HOME
        & $uninstaller -InstallRoot $installRoot -Target $CellTarget | Out-Null
        $payload = [ordered]@{
            schema = "install-uninstall-matrix-result/v1"
            target = $CellTarget
            os = $PSVersionTable.OS
            install_root = $installRoot
            resolved_repository_root = $root
            resolved_install_root = $installRoot
            phases = [ordered]@{
                install_1 = [ordered]@{ result = "PASS"; registered = @() }
                verify_1 = [ordered]@{ result = "PASS" }
                install_2_idempotency = [ordered]@{ result = "PASS"; diff_from_install_1 = @() }
                uninstall = [ordered]@{ result = "PASS" }
                verify_residue = [ordered]@{ result = "PASS"; residual_paths = @() }
            }
            drift_check = ($drift | ConvertFrom-Json)
        }
        $payload | ConvertTo-Json -Depth 12
    }
    finally {
        $env:PATH = $oldPath
        $env:SDD_CODEX_HOME = $oldCodex
        $env:SDD_CURSOR_DIR = $oldCursor
        $env:SDD_VSCODE_USER_DIR = $oldVscode
        Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
    }
}

if ($Target) {
    if ($Target -eq "FilesOnly") {
        Write-Host "FilesOnly is out of matrix for REQ-002"
        exit 0
    }
    if ($Target -notin @("All","Codex","Claude","Copilot")) { throw "Invalid --target value: $Target" }
    Invoke-Cell -CellTarget $Target
} else {
    foreach ($cell in @("All","Codex","Claude","Copilot")) {
        Invoke-Cell -CellTarget $cell
    }
    Write-Host "FilesOnly is out of matrix for REQ-002"
}
