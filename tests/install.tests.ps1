$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-installer-test-" + [guid]::NewGuid())
$installRoot = Join-Path $testRoot "installed"
$fakeBin = Join-Path $testRoot "bin"
$commandLog = Join-Path $testRoot "commands.log"
$originalPath = $env:PATH
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

try {
    New-Item -ItemType Directory -Path $fakeBin | Out-Null
    foreach ($command in @("codex", "claude")) {
        if ($isWindowsPlatform) {
            $commandPath = Join-Path $fakeBin "$command.cmd"
            "@echo $command %*>>`"$commandLog`"`r`n@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
        }
        else {
            $commandPath = Join-Path $fakeBin $command
            "#!/bin/sh`necho `"$command `$*`" >> `"$commandLog`"`n" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
            & chmod +x $commandPath
        }
    }

    $env:PATH = "$fakeBin$([System.IO.Path]::PathSeparator)$originalPath"
    & (Join-Path $repositoryRoot "install.ps1") -SourceDirectory $repositoryRoot -InstallRoot $installRoot -Target All

    $expectedFiles = @(
        ".agents/plugins/marketplace.json",
        ".claude-plugin/marketplace.json",
        "plugins/sdd-bootstrap/.codex-plugin/plugin.json",
        "plugins/sdd-quality-loop/.codex-plugin/plugin.json"
    )
    foreach ($relativePath in $expectedFiles) {
        if (-not (Test-Path (Join-Path $installRoot $relativePath))) {
            throw "Installer did not copy $relativePath."
        }
    }

    $log = Get-Content -Raw $commandLog
    $expectedCommands = @(
        "codex plugin marketplace add",
        "codex plugin add sdd-bootstrap@sdd-plugins",
        "codex plugin add sdd-quality-loop@sdd-plugins",
        "claude plugin marketplace add",
        "claude plugin install sdd-bootstrap@sdd-plugins",
        "claude plugin install sdd-quality-loop@sdd-plugins"
    )
    foreach ($expectedCommand in $expectedCommands) {
        if ($log -notmatch [regex]::Escape($expectedCommand)) {
            throw "Installer did not run expected command: $expectedCommand"
        }
    }

    Write-Host "Installer integration test passed."
}
finally {
    $env:PATH = $originalPath
    if (Test-Path $testRoot) {
        Remove-Item -Path $testRoot -Recurse -Force
    }
}
