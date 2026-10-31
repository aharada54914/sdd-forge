$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# TEST-003 / AC-003: exercise only the staged T-002 PowerShell candidate.
# A synthetic token passes through the ordinary approval guard so each case
# observes Test-SudoActive without editing a protected live source or task file.
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$defaultGuard = Join-Path $repositoryRoot "specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1"
$guardPs1 = if ([string]::IsNullOrEmpty($env:GUARD_PS1)) { $defaultGuard } else { $env:GUARD_PS1 }

if (-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
    Write-Host "SKIP: powershell.exe is required for the PS5.1 signature suite"
    exit 0
}
if (-not (Test-Path -LiteralPath $guardPs1 -PathType Leaf)) {
    Write-Host "FAIL: staged guard candidate is missing: $guardPs1"
    exit 1
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("phase2-sudo-signature-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null
$passCount = 0
$failCount = 0
$testKey = "phase2-sudo-signature-test-key"
$issuedEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 1
$expiresEpoch = $issuedEpoch + 3601
$repoCanonical = (Resolve-Path -LiteralPath $workDir).Path

function Get-ExpectedSignature {
    param(
        [string]$RepositoryPath,
        [int64]$Issued,
        [int64]$Expires
    )
    $issuer = "phase2-sudo-signature-test"
    $nonce = "a5" * 32
    $canonical = ($issuer, $nonce, $RepositoryPath, [string]$Issued, [string]$Expires) -join "`n"
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($testKey)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(,$keyBytes)
    try {
        return -join ($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical)) | ForEach-Object { $_.ToString("x2") })
    } finally {
        $hmac.Dispose()
    }
}

function Set-SudoToken {
    param([string]$Signature)
    $lines = @(
        "issuer: phase2-sudo-signature-test",
        "nonce: $("a5" * 32)",
        "repo: $script:repoCanonical",
        "issued-epoch: $script:issuedEpoch",
        "expires-epoch: $script:expiresEpoch",
        "sig: $Signature"
    )
    [System.IO.File]::WriteAllText((Join-Path $workDir "SDD_SUDO"), (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

function Get-MutatedSignature {
    param(
        [string]$Signature,
        [int]$ByteIndex
    )
    $offset = $ByteIndex * 2
    $replacement = if ($Signature.Substring($offset, 2) -eq "00") { "ff" } else { "00" }
    return $Signature.Substring(0, $offset) + $replacement + $Signature.Substring($offset + 2)
}

function Invoke-GuardExit {
    $payload = @{
        tool_name = "edit"
        tool_input = @{
            file_path = (Join-Path $workDir "tasks.md")
            old_string = "Approval: Draft"
            new_string = "Approval: Approved"
        }
    } | ConvertTo-Json -Depth 4 -Compress

    $savedDirectory = [System.IO.Directory]::GetCurrentDirectory()
    $savedLocation = (Get-Location).Path
    $savedProjectDir = $env:CLAUDE_PROJECT_DIR
    $savedPayload = $env:PAYLOAD
    $savedKey = $env:SDD_SUDO_KEY
    try {
        [System.IO.Directory]::SetCurrentDirectory($workDir)
        Set-Location -LiteralPath $workDir
        $env:CLAUDE_PROJECT_DIR = $workDir
        $env:PAYLOAD = $payload
        $env:SDD_SUDO_KEY = $testKey
        $savedPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guardPs1 -Emit exit 2>$null | Out-Null
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedPreference
        return $exitCode
    } finally {
        if ($null -eq $savedProjectDir) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_PROJECT_DIR = $savedProjectDir }
        if ($null -eq $savedPayload) { Remove-Item Env:PAYLOAD -ErrorAction SilentlyContinue } else { $env:PAYLOAD = $savedPayload }
        if ($null -eq $savedKey) { Remove-Item Env:SDD_SUDO_KEY -ErrorAction SilentlyContinue } else { $env:SDD_SUDO_KEY = $savedKey }
        [System.IO.Directory]::SetCurrentDirectory($savedDirectory)
        Set-Location -LiteralPath $savedLocation
    }
}

function Assert-GuardExit {
    param(
        [string]$Name,
        [string]$Signature,
        [int]$ExpectedExit
    )
    Set-SudoToken $Signature
    $actualExit = Invoke-GuardExit
    if ($actualExit -eq $ExpectedExit) {
        Write-Host "ok: $Name (exit $ExpectedExit)"
        $script:passCount++
    } else {
        Write-Host "FAIL: $Name expected=$ExpectedExit actual=$actualExit"
        $script:failCount++
    }
}

try {
    $validSignature = Get-ExpectedSignature $repoCanonical $issuedEpoch $expiresEpoch
    Assert-GuardExit "valid 64-hex HMAC activates sudo" $validSignature 0
    Assert-GuardExit "63-character signature stays inactive" ("a" * 63) 2
    Assert-GuardExit "65-character signature stays inactive" ("a" * 65) 2
    Assert-GuardExit "malformed 64-character non-hex signature stays inactive" ("g" * 64) 2
    Assert-GuardExit "first-byte signature mutation stays inactive" (Get-MutatedSignature $validSignature 0) 2
    Assert-GuardExit "middle-byte signature mutation stays inactive" (Get-MutatedSignature $validSignature 16) 2
    Assert-GuardExit "last-byte signature mutation stays inactive" (Get-MutatedSignature $validSignature 31) 2
} finally {
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "phase2-sudo-signature.tests.ps1: $passCount passed, $failCount failed"
if ($failCount -gt 0) { exit 1 }
