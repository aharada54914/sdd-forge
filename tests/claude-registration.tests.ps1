param([switch]$RuntimeBoundariesOnly)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot "install.ps1"
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function New-FakeClaudeCommand {
    param(
        [Parameter(Mandatory)][string]$BinRoot,
        [Parameter(Mandatory)][string]$LogPath,
        [switch]$FailValidate,
        [switch]$FailVersion
    )

    New-Item -ItemType Directory -Path $BinRoot -Force | Out-Null
    if ($isWindowsPlatform) {
        $commandPath = Join-Path $BinRoot "claude.cmd"
        # Quote both operands. cmd.exe otherwise treats the second comparison
        # differently on Windows runners and the validation-failure fixture
        # incorrectly exits successfully.
        $failureLine = if ($FailValidate) { '@if /I "%~1"=="plugin" if /I "%~2"=="validate" exit /b 9' + [Environment]::NewLine } else { "" }
        if ($FailVersion) { $failureLine += '@if "%~1"=="--version" exit /b 7' + [Environment]::NewLine }
        $failureLine += '@if "%~1"=="--version" (echo 2.1.317 ^(Claude Code^) & exit /b 0)' + [Environment]::NewLine
        "@echo claude %*>>`"$LogPath`"`r`n$failureLine@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
    }
    else {
        $commandPath = Join-Path $BinRoot "claude"
        $failureLine = if ($FailValidate) { "if [ `"`$1`" = plugin ] && [ `"`$2`" = validate ]; then exit 9; fi`n" } else { "" }
        if ($FailVersion) { $failureLine += "if [ `"`$1`" = --version ]; then exit 7; fi`n" }
        $failureLine += "if [ `"`$1`" = --version ]; then echo '2.1.317 (Claude Code)'; exit 0; fi`n"
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
            ("exec '" + $realGit.Replace("'", "'\''") + "' " + '"$@"')
        ) | Set-Content -Path $commandPath -Encoding Utf8NoBOM
        & chmod +x $commandPath
    }
}

# Exercise only the actual process/encoding boundaries on Desktop. Core runs
# these with the common registration suite; do not repeat full installs on 5.1.
& {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($installer, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Installer parse failed.' }
    $definition = $ast.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-VersionPreflight'
    }, $true)
    if (-not $definition) { throw 'Installer version preflight is missing.' }
    . ([scriptblock]::Create($definition.Extent.Text))
    $work = Join-Path ([IO.Path]::GetTempPath()) ("sdd-cli boundary's-" + [guid]::NewGuid())
    try {
        New-FakeClaudeCommand -BinRoot $work -LogPath (Join-Path $work 'commands.log')
        $commandName = if ($isWindowsPlatform) { 'claude.cmd' } else { 'claude' }
        $command = Join-Path $work $commandName
        $version = Invoke-VersionPreflight -Command $command -Label 'Claude Code CLI'
        if ($version -ne '2.1.317 (Claude Code)') { throw "Spaced/apostrophe path lost output: $version" }
        $scriptPath = Join-Path $work 'probe.ps1'
        [IO.File]::WriteAllText($scriptPath, '$PSVersionTable.PSVersion.ToString()')
        $version = Invoke-VersionPreflight -Command $scriptPath -Label 'engine fixture'
        if ($version -ne $PSVersionTable.PSVersion.ToString()) { throw 'Version probe used a different PowerShell engine.' }
        [IO.File]::WriteAllText($scriptPath, 'exit 7')
        $failure = $null
        try { Invoke-VersionPreflight -Command $scriptPath -Label 'broken fixture' | Out-Null } catch { $failure = $_ }
        if (-not $failure -or "$failure" -notmatch 'preflight failed.*exit 7') { throw "Broken CLI lost exit status: $failure" }
        if ($isWindowsPlatform) {
            $invalidExe = Join-Path $work 'invalid.exe'
            [IO.File]::WriteAllText($invalidExe, 'Not a Windows executable')
            $failure = $null
            try { Invoke-VersionPreflight -Command $invalidExe -Label 'invalid executable fixture' | Out-Null } catch { $failure = $_ }
            if (-not $failure -or "$failure" -notmatch 'preflight failed') { throw "Invalid executable was accepted: $failure" }
        }
        [IO.File]::WriteAllText($scriptPath, 'Start-Sleep -Seconds 30')
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $failure = $null
        try { Invoke-VersionPreflight -Command $scriptPath -Label 'hung fixture' -TimeoutSeconds 2 | Out-Null } catch { $failure = $_ }
        if (-not $failure -or "$failure" -notmatch 'preflight timed out' -or $watch.Elapsed.TotalSeconds -gt 12) {
            throw "Hung CLI was not bounded: $failure ($($watch.Elapsed.TotalSeconds)s)"
        }
        Write-Host 'ok: CLI preflight preserves literal paths, current engine, and bounded startup'
    } finally {
        if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    }
}
if ($RuntimeBoundariesOnly) { return }

# A CLI that cannot start must never replace an existing installation. Also
# cover a new root, whose parent must not be created on a failed preflight.
$preflightRoot = Join-Path ([IO.Path]::GetTempPath()) ("sdd-claude-preflight-" + [guid]::NewGuid())
$preflightBin = Join-Path $preflightRoot 'bin'
$preflightLog = Join-Path $preflightRoot 'commands.log'
$preflightSavedPath = $env:PATH
$preflightSavedOverride = $env:SDD_CLAUDE_BIN
try {
    $env:SDD_CLAUDE_BIN = $null
    New-FakeClaudeCommand -BinRoot $preflightBin -LogPath $preflightLog -FailVersion
    $env:PATH = "$preflightBin$([IO.Path]::PathSeparator)$preflightSavedPath"
    foreach ($existing in @($true, $false)) {
        $destination = Join-Path $preflightRoot "case-$existing/installed"
        if ($existing) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $destination 'previous.marker') -Value 'previous release' -Encoding Ascii
        }
        $failure = $null
        try {
            & $installer -SourceDirectory $repositoryRoot -InstallRoot $destination -Target Claude -Plugins sdd-bootstrap -SkipAgentInstall -SkipPluginInstall -SkipMcp *>&1 | Out-Null
        } catch { $failure = $_ }
        if (-not $failure -or "$failure" -notmatch 'Claude.*preflight') { throw "Broken CLI should fail in preflight: $failure" }
        if ($existing) {
            $remaining = @(Get-ChildItem -LiteralPath $destination -Force)
            if ($remaining.Count -ne 1 -or (Get-Content -Raw (Join-Path $destination 'previous.marker')).Trim() -ne 'previous release') {
                throw 'Broken CLI mutated the previous installation.'
            }
        } elseif (Test-Path (Split-Path -Parent $destination)) { throw 'Broken CLI created the install parent.' }
    }
    $log = Get-Content -Raw $preflightLog
    if ($log -match 'plugin|mcp') { throw "Broken CLI reached registration: $log" }
    $destination = Join-Path $preflightRoot 'invalid-override/installed'
    $failure = $null
    try {
        & $installer -SourceDirectory $repositoryRoot -InstallRoot $destination -Target All -Plugins sdd-bootstrap -ClaudeCommand (Join-Path $preflightRoot 'missing-cli') -SkipMcp *>&1 | Out-Null
    } catch { $failure = $_ }
    if (-not $failure -or "$failure" -notmatch 'Claude Code CLI was not found' -or (Test-Path (Split-Path $destination))) {
        throw "Explicit invalid CLI should fail before installing, without PATH fallback: $failure"
    }
    if ((Get-Content -Raw $preflightLog) -ne $log) { throw 'Invalid explicit CLI fell back to PATH.' }
    Write-Host 'ok: failed Claude startup leaves existing and new install roots unchanged'
} finally {
    $env:PATH = $preflightSavedPath
    $env:SDD_CLAUDE_BIN = $preflightSavedOverride
    if (Test-Path $preflightRoot) { Remove-Item $preflightRoot -Recurse -Force }
}

# ---------------------------------------------------------------------------
# Target Claude: must register marketplace and install the two public commands.
# sdd-ship auto-expands its internal companions, but sdd-bootstrap and sdd-ship
# are the user-facing commands whose absence caused the regression.
# ---------------------------------------------------------------------------
$successRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-claude-reg-success-" + [guid]::NewGuid())
$successInstall = Join-Path $successRoot "installed"
$successBin = Join-Path $successRoot "selected CLI's bin"
$successLog = Join-Path $successRoot "commands.log"
$successSavedPath = $env:PATH
$successSavedOverride = $env:SDD_CLAUDE_BIN
try {
    New-FakeClaudeCommand -BinRoot $successBin -LogPath $successLog
    $brokenBin = Join-Path $successRoot 'broken-bin'
    $brokenLog = Join-Path $successRoot 'broken.log'
    New-FakeClaudeCommand -BinRoot $brokenBin -LogPath $brokenLog -FailVersion
    $env:PATH = "$brokenBin$([System.IO.Path]::PathSeparator)$successSavedPath"
    $env:SDD_CLAUDE_BIN = Join-Path $successRoot 'does-not-exist'
    $commandName = if ($isWindowsPlatform) { 'claude.cmd' } else { 'claude' }
    $selectedCommand = Join-Path $successBin $commandName

    $output = & $installer -SourceDirectory $repositoryRoot -InstallRoot $successInstall -Target Claude -Plugins @("sdd-bootstrap", "sdd-ship") -RequireClaude -ClaudeCommand $selectedCommand *>&1 | Out-String
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

    foreach ($expectedOutput in @("/reload-plugins", "/sdd-bootstrap:bootstrap", "/sdd-ship:ship")) {
        if ($output -notmatch [regex]::Escape($expectedOutput)) {
            throw "Claude install summary did not mention expected text: $expectedOutput`nOutput:`n$output"
        }
    }

    $env:SDD_CLAUDE_BIN = $selectedCommand
    & $installer -SourceDirectory $repositoryRoot -InstallRoot $successInstall -Target Claude -Plugins sdd-bootstrap -SkipMcp *>&1 | Out-Null
    if (Test-Path $brokenLog) { throw 'Claude registration ignored the selected CLI and invoked the broken PATH launcher.' }
    $env:SDD_CLAUDE_BIN = Join-Path $successRoot 'does-not-exist'
    & $installer -SourceDirectory $repositoryRoot -InstallRoot $successInstall -Target FilesOnly -Plugins sdd-bootstrap -SkipMcp *>&1 | Out-Null
    Write-Host 'ok: explicit Claude path overrides environment and PATH; environment overrides PATH; FilesOnly ignores Claude'
}
finally {
    $env:PATH = $successSavedPath
    $env:SDD_CLAUDE_BIN = $successSavedOverride
    if (Test-Path $successRoot) { Remove-Item -Path $successRoot -Recurse -Force }
}

# An incomplete local checkout is rejected before installation, with a possible
# Windows cause and a concrete recovery path rather than a claimed diagnosis.
$missingRoot = Join-Path ([IO.Path]::GetTempPath()) ("sdd-source-missing-" + [guid]::NewGuid())
try {
    $source = Join-Path $missingRoot 'source'
    $destination = Join-Path $missingRoot 'installed'
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    & git -C $source init -q
    if ($LASTEXITCODE -ne 0) { throw 'Could not prepare missing-source fixture.' }
    $failure = $null
    try { & $installer -SourceDirectory $source -InstallRoot $destination -Target FilesOnly -SkipMcp *>&1 | Out-Null } catch { $failure = $_ }
    foreach ($text in @('Required file is missing', 'one possible cause', 'core.longpaths=true', 'short directory')) {
        if (-not $failure -or "$failure" -notmatch [regex]::Escape($text)) { throw "Missing-source recovery diagnostic lacks '$text': $failure" }
    }
    if (Test-Path $destination) { throw 'Incomplete source changed the install root.' }
    Write-Host 'ok: incomplete source suggests short Windows checkout without assuming the cause'
} finally {
    if (Test-Path $missingRoot) { Remove-Item $missingRoot -Recurse -Force }
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
