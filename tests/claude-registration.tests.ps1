$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot "install.ps1"
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function New-FakeClaudeCommand {
    param(
        [Parameter(Mandatory)][string]$BinRoot,
        [Parameter(Mandatory)][string]$LogPath,
        [switch]$FailValidate
    )

    New-Item -ItemType Directory -Path $BinRoot -Force | Out-Null
    if ($isWindowsPlatform) {
        $commandPath = Join-Path $BinRoot "claude.cmd"
        # Quote both operands. cmd.exe otherwise treats the second comparison
        # differently on Windows runners and the validation-failure fixture
        # incorrectly exits successfully.
        $failureLine = if ($FailValidate) { '@if /I "%~1"=="plugin" if /I "%~2"=="validate" exit /b 9' + [Environment]::NewLine } else { "" }
        "@echo claude %*>>`"$LogPath`"`r`n$failureLine@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
    }
    else {
        $commandPath = Join-Path $BinRoot "claude"
        $failureLine = if ($FailValidate) { "if [ `"`$1`" = plugin ] && [ `"`$2`" = validate ]; then exit 9; fi`n" } else { "" }
        "#!/bin/sh`necho `"claude `$*`" >> `"$LogPath`"`n$failureLine`nexit 0`n" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
        & chmod +x $commandPath
    }
}

function New-FakeSuccessfulPluginCommands {
    param([Parameter(Mandatory)][string]$BinRoot)

    foreach ($command in @("codex", "copilot")) {
        if ($isWindowsPlatform) {
            "@exit /b 0`r`n" | Set-Content -Path (Join-Path $BinRoot "$command.cmd") -Encoding Ascii
        }
        else {
            $commandPath = Join-Path $BinRoot $command
            "#!/bin/sh`nexit 0`n" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
            & chmod +x $commandPath
        }
    }
}

function New-GitShim {
    param([Parameter(Mandatory)][string]$BinRoot)

    $realGit = (Get-Command git -ErrorAction Stop).Source
    if ($isWindowsPlatform) {
        @(
            '@echo off'
            ('"{0}" %*' -f $realGit)
            '@exit /b %ERRORLEVEL%'
        ) | Set-Content -Path (Join-Path $BinRoot "git.cmd") -Encoding Ascii
    }
    else {
        $commandPath = Join-Path $BinRoot "git"
        @(
            '#!/bin/sh'
            # Apple's /usr/bin/git dispatches through xcrun. Keep system tools
            # available without re-exposing a separately installed Claude CLI.
            'PATH="/usr/bin:/bin:$PATH"'
            'export PATH'
            ('exec "{0}" "$@"' -f $realGit)
        ) | Set-Content -Path $commandPath -Encoding Utf8NoBOM
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
# Claude validation must fail before marketplace registration.
# ---------------------------------------------------------------------------
$validationRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-claude-reg-validation-" + [guid]::NewGuid())
$validationInstall = Join-Path $validationRoot "installed"
$validationBin = Join-Path $validationRoot "bin"
$validationLog = Join-Path $validationRoot "commands.log"
$validationSavedPath = $env:PATH
try {
    New-FakeClaudeCommand -BinRoot $validationBin -LogPath $validationLog -FailValidate
    $env:PATH = "$validationBin$([System.IO.Path]::PathSeparator)$validationSavedPath"

    $failed = $false
    try {
        & $installer -SourceDirectory $repositoryRoot -InstallRoot $validationInstall -Target Claude -Plugins @("sdd-bootstrap") -RequireClaude *>&1 | Out-String | Out-Null
    }
    catch {
        $failed = $true
    }
    if (-not $failed) { throw "Claude manifest validation failure should stop installation." }

    $log = Get-Content -Raw $validationLog
    if ($log -notmatch [regex]::Escape("claude plugin validate")) {
        throw "Claude validation did not invoke plugin validate.`nLog:`n$log"
    }
    if ($log -match [regex]::Escape("claude plugin marketplace add")) {
        throw "Claude marketplace was registered before manifest validation passed.`nLog:`n$log"
    }
    Write-Host "ok: Claude manifest validation fails before marketplace registration"
}
finally {
    $env:PATH = $validationSavedPath
    if (Test-Path $validationRoot) { Remove-Item -Path $validationRoot -Recurse -Force }
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
    New-FakeSuccessfulPluginCommands -BinRoot $requireBin
    # Keep Git available for source validation without retaining its containing
    # directory on PATH. GitHub macOS runners can install git and claude in the
    # same directory, which would otherwise make the "missing Claude" branch
    # depend on runner layout instead of installer behavior.
    New-GitShim -BinRoot $requireBin
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
