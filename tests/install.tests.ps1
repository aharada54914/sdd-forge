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
    foreach ($command in @("codex", "claude")) {
        if ($isWindowsPlatform) {
            $commandPath = Join-Path $BinRoot "$command.cmd"
            $failureLine = if ($FailPattern) { "@echo %*| findstr /c:`"$FailPattern`" >nul && exit /b 9`r`n" } else { "" }
            "@echo $command %*>>`"$LogPath`"`r`n$failureLine@exit /b 0`r`n" | Set-Content -Path $commandPath -Encoding Ascii
        }
        else {
            $commandPath = Join-Path $BinRoot $command
            $failureLine = if ($FailPattern) { "echo `"`$*`" | grep -F `"$FailPattern`" >/dev/null && exit 9`n" } else { "" }
            "#!/bin/sh`necho `"$command `$*`" >> `"$LogPath`"`n$failureLine" | Set-Content -Path $commandPath -Encoding Utf8NoBOM
            & chmod +x $commandPath
        }
    }
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

    try {
        New-FakeCommands -BinRoot $fakeBin -LogPath $commandLog -FailPattern $FailPattern
        $env:PATH = "$fakeBin$([System.IO.Path]::PathSeparator)$originalPath"

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
            foreach ($expectedCommand in @("codex plugin add $plugin@sdd-plugins", "claude plugin install $plugin@sdd-plugins")) {
                if ($log -notmatch [regex]::Escape($expectedCommand)) {
                    throw "Installer did not run expected command: $expectedCommand"
                }
            }
        }
        foreach ($plugin in $allPlugins | Where-Object { $_ -notin $Plugins }) {
            if ($log -match [regex]::Escape("plugin add $plugin@sdd-plugins") -or $log -match [regex]::Escape("plugin install $plugin@sdd-plugins")) {
                throw "Installer registered an unselected plugin: $plugin"
            }
        }
    }
    finally {
        $env:PATH = $originalPath
        if (Test-Path $testRoot) {
            Remove-Item -Path $testRoot -Recurse -Force
        }
    }
}

Invoke-InstallerScenario -Plugins $allPlugins
Invoke-InstallerScenario -Plugins @("sdd-bootstrap", "sdd-implementation")
Invoke-InstallerScenario -Plugins $allPlugins -FailPattern "sdd-implementation@sdd-plugins"
Invoke-InstallerScenario -Plugins $allPlugins -FailPattern "sdd-implementation@sdd-plugins" -SeedExistingInstall

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

Write-Host "Installer integration tests passed."
