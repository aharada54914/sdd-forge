$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# TEST-001 / TEST-002: #117 cross-runtime candidate corpus. The GUARD_* values
# default to live files for RED and may target staged human-copy candidates for
# GREEN. Only exit decisions are compared; denial messages are not an API.
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Get-EnvOrDefault {
    param([string]$Name, [string]$Default)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($value)) { return $Default }
    return $value
}

$guardPs1 = Get-EnvOrDefault "GUARD_PS1" (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1")
$guardPy  = Get-EnvOrDefault "GUARD_PY"  (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py")
$guardJs  = Get-EnvOrDefault "GUARD_JS"  (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js")

$missing = @()
foreach ($command in @("powershell.exe", "python.exe", "node.exe")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { $missing += $command }
}
if ($missing.Count -gt 0) {
    Write-Host "SKIP: phase2 tokenizer corpus requires $($missing -join ', ')"
    exit 0
}
foreach ($guard in @($guardPs1, $guardPy, $guardJs)) {
    if (-not (Test-Path -LiteralPath $guard -PathType Leaf)) {
        Write-Host "FAIL: guard candidate is missing: $guard"
        exit 1
    }
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("phase2-tokenizer-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null
$passCount = 0
$failCount = 0

function New-BashPayload {
    param([string]$Command)
    return ('{"tool_name":"bash","tool_input":{"command":' + (ConvertTo-Json -Compress $Command) + '}}')
}

function Invoke-GuardExit {
    param([string]$Runtime, [string]$GuardPath, [string]$Payload)
    $savedDirectory = [System.IO.Directory]::GetCurrentDirectory()
    $savedLocation = (Get-Location).Path
    $savedProjectDir = $env:CLAUDE_PROJECT_DIR
    try {
        [System.IO.Directory]::SetCurrentDirectory($workDir)
        Set-Location -LiteralPath $workDir
        $env:CLAUDE_PROJECT_DIR = $workDir
        $env:PAYLOAD = $Payload
        # Windows PowerShell 5.1 can surface a native guard's expected deny
        # stderr as NativeCommandError under Stop. Capture the process status
        # explicitly so exit 2 remains an assertion value, not a test abort.
        $savedPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        switch ($Runtime) {
            "ps1" { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GuardPath -Emit exit 2>$null | Out-Null }
            "py" { & python.exe $GuardPath --emit exit 2>$null | Out-Null }
            "js" { & node.exe $GuardPath --emit exit 2>$null | Out-Null }
        }
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedPreference
        return $exitCode
    } finally {
        Remove-Item Env:PAYLOAD -ErrorAction SilentlyContinue
        if ($null -eq $savedProjectDir) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $savedProjectDir }
        [System.IO.Directory]::SetCurrentDirectory($savedDirectory)
        Set-Location -LiteralPath $savedLocation
    }
}

function Assert-Parity {
    param([string]$Name, [int]$Expected, [string]$Command)
    $payload = New-BashPayload $Command
    $ps1 = Invoke-GuardExit "ps1" $guardPs1 $payload
    $py = Invoke-GuardExit "py" $guardPy $payload
    $js = Invoke-GuardExit "js" $guardJs $payload
    if ($ps1 -eq $Expected -and $py -eq $Expected -and $js -eq $Expected) {
        Write-Host "ok: $Name (all exit $Expected)"
        $script:passCount++
    } else {
        Write-Host "FAIL: $Name expected=$Expected ps1=$ps1 py=$py js=$js"
        $script:failCount++
    }
}

function Assert-AsciiNoBom {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $nonAscii = @($bytes | Where-Object { $_ -gt 0x7F }).Count
    if (-not $hasBom -and $nonAscii -eq 0) {
        Write-Host "ok: PowerShell candidate is ASCII-only without BOM"
        $script:passCount++
    } else {
        Write-Host "FAIL: PowerShell candidate ASCII/BOM check bom=$hasBom nonAscii=$nonAscii"
        $script:failCount++
    }
}

$protected = "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"

# Legal forms: the first combined form is the RED fixture for the live twins.
Assert-Parity "legal: quoted regex escaped alternation plus standalone fd duplicate" 0 "grep -n `"R-10\\|R-11`" $protected 2>&1"
Assert-Parity "legal: terminal quoted escaped pipe plus standalone fd duplicate" 0 "grep -n `"\|`" $protected 2>&1"
Assert-Parity "legal: fd duplicate on protected inspection" 0 "cat $protected 2>&1"
Assert-Parity "legal: ls protected inspection" 0 "ls $protected"
Assert-Parity "legal: cat protected inspection" 0 "cat $protected"
Assert-Parity "legal: find protected inspection" 0 "find $protected -maxdepth 0"

# Negative controls: only the narrowly modeled double-quoted regex escape may
# change; unquoted, dangling, or writing forms must remain fail-closed.
Assert-Parity "deny: unquoted backslash changes token boundary" 2 "grep -n R-10\\|R-11 $protected 2>&1"
Assert-Parity "deny: unclosed quoted regex" 2 "grep -n `"R-10\\|R-11 $protected 2>&1"
Assert-Parity "deny: regex plus protected redirect" 2 "grep -n `"R-10\\|R-11`" $protected 2>&1 > $protected"
Assert-Parity "deny: tee writes protected target" 2 "grep -n `"R-10\\|R-11`" $protected 2>&1 | tee $protected"
Assert-Parity "deny: cp writes protected target" 2 "cp /tmp/source $protected"
Assert-Parity "deny: rm protected target" 2 "rm $protected"
Assert-AsciiNoBom $guardPs1

Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "phase2-guard-tokenizer.tests.ps1: $passCount passed, $failCount failed"
if ($failCount -gt 0) { exit 1 }
