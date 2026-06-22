$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot "install.ps1"
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function New-FakeClaudeCommand {
    param(
        [Parameter(Mandatory)][string]$BinRoot,
        [Parameter(Mandatory)][string]$LogPath
    )

    New-Item -ItemType Directory -Path $BinRoot -Force | Out-Null
    if ($isWindowsPlatform) {
        $commandPath = Join-Path $BinRoot "claude.cmd"
        "@echo claude %*>>`"$LogPath`"`r`n@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
    }
    else {
        $commandPath = Join-Path $BinRoot "claude"
        "#!/bin/sh`necho \"claude `$*\" >> \"$LogPath\"`nexit 0`n" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
        & chmod +x $commandPath
    }
}

# ---------------------------------------------------------------------------
# Target Claude: must register marketplace and install the two public commands.
# sdd-ship auto-expands its internal companions, but sdd-bootstrap and sdd-ship
# are the user-facing commands whose absence caused the regression.
# ---------------------------------------------------------------------------
$successRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-claude-reg-success-" + [guid]::NewGuid())
$successInstall = Join-Path $successRoot "installed"
$successBin = Join-Path $successRoot "bin"
$successLog = Join-Path $successRoot "commands.log"
$successSavedPath = $env:PATH
try {
    New-FakeClaudeCommand -BinRoot $successBin -LogPath $successLog
    $env:PATH = "$successBin$([System.IO.Path]::PathSeparator)$successSavedPath"

    $output = & $installer -SourceDirectory $repositoryRoot -InstallRoot $successInstall -Target Claude -Plugins @("sdd-bootstrap", "sdd-ship") -RequireClaude *>&1 | Out-String
    $log = Get-Content -Raw $successLog

    foreach ($expected in @(
        "claude plugin marketplace add",
        "claude plugin install sdd-bootstrap@sdd-plugins --scope user",
        "claude plugin install sdd-ship@sdd-plugins --scope user"
    )) {
        if ($log -notmatch [regex]::Escape($expected)) {
            throw "Claude registration did not run expected command: $expected`nLog:`n$log"
        }
    }

    foreach ($expectedOutput in @("/reload-plugins", "/sdd-bootstrap:run", "/sdd-ship:run")) {
        if ($output -notmatch [regex]::Escape($expectedOutput)) {
            throw "Claude install summary did not mention expected text: $expectedOutput`nOutput:`n$output"
        }
    }

    Write-Host "ok: Claude registration installs sdd-bootstrap:run and sdd-ship:run plugins"
}
finally {
    $env:PATH = $successSavedPath
    if (Test-Path $successRoot) { Remove-Item -Path $successRoot -Recurse -Force }
}

# ---------------------------------------------------------------------------
# RequireClaude: Target All must fail when Claude CLI is absent. Without this,
# users can see a successful install while Claude was silently skipped.
# ---------------------------------------------------------------------------
$requireRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-claude-reg-require-" + [guid]::NewGuid())
$requireInstall = Join-Path $requireRoot "installed"
$requireBin = Join-Path $requireRoot "bin"
$requireSavedPath = $env:PATH
try {
    New-Item -ItemType Directory -Path $requireBin -Force | Out-Null
    $env:PATH = $requireBin

    $failed = $false
    try {
        & $installer -SourceDirectory $repositoryRoot -InstallRoot $requireInstall -Target All -Plugins @("sdd-bootstrap", "sdd-ship") -RequireClaude -SkipAgentInstall *>&1 | Out-String | Out-Null
    }
    catch {
        $failed = $true
        if ($_ -notmatch "Claude Code CLI was not found") {
            throw "RequireClaude failed with unexpected error: $_"
        }
    }

    if (-not $failed) {
        throw "RequireClaude should fail when Claude Code CLI is absent."
    }

    Write-Host "ok: RequireClaude fails closed when Claude CLI is absent"
}
finally {
    $env:PATH = $requireSavedPath
    if (Test-Path $requireRoot) { Remove-Item -Path $requireRoot -Recurse -Force }
}
