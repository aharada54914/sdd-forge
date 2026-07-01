$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runner = Join-Path $root "scripts/rollback-1.5.0.ps1"
$temp = Join-Path ([IO.Path]::GetTempPath()) ("rollback-native-tests-" + [guid]::NewGuid())

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($Arguments -join ' ')" }
    return $output
}

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $source = Join-Path $temp "source"
    New-Item -ItemType Directory -Path $source | Out-Null
    Invoke-Git -C $source init -q
    Invoke-Git -C $source config user.name rollback-test
    Invoke-Git -C $source config user.email rollback-test@example.invalid
    [IO.File]::WriteAllText((Join-Path $source "present.txt"), "baseline`n",
        [Text.UTF8Encoding]::new($false))
    Invoke-Git -C $source add .
    Invoke-Git -C $source commit -qm baseline
    $baseline = Invoke-Git -C $source rev-parse HEAD
    [IO.File]::WriteAllText((Join-Path $source "present.txt"), "release`n",
        [Text.UTF8Encoding]::new($false))
    Invoke-Git -C $source add .
    Invoke-Git -C $source commit -qm release
    $reviewed = Invoke-Git -C $source rev-parse HEAD
    $baselineHash = (Get-FileHash -Algorithm SHA256 (Join-Path $source "present.txt")).Hash.ToLowerInvariant()
    Invoke-Git -C $source checkout -q "$baseline"
    $baselineHash = (Get-FileHash -Algorithm SHA256 (Join-Path $source "present.txt")).Hash.ToLowerInvariant()
    Invoke-Git -C $source checkout -q "$reviewed"
    $releaseHash = (Get-FileHash -Algorithm SHA256 (Join-Path $source "present.txt")).Hash.ToLowerInvariant()

    $contract = Join-Path $temp "contract.json"
    [ordered]@{
        schema = "rollback-1.5.0/v1"
        baseline_commit = $baseline
        reviewed_release_commit = $reviewed
        files = @([ordered]@{
            path = "present.txt"
            baseline_sha256 = $baselineHash
            new_sha256 = $releaseHash
        })
    } | ConvertTo-Json -Depth 5 | Set-Content -Encoding Utf8 -LiteralPath $contract

    $validator = Join-Path $temp "validator.ps1"
    @'
$ErrorActionPreference = "Stop"
if ((Get-Content -Raw present.txt) -ne "baseline`n") { throw "not baseline" }
'@ | Set-Content -Encoding Utf8 -LiteralPath $validator

    $success = Join-Path $temp "success"
    Invoke-Git clone -q $source $success
    & (Get-Process -Id $PID).Path -NoProfile -File $runner -RepoRoot $success `
        -Contract $contract -Validator $validator | Out-Null
    if ($LASTEXITCODE -ne 0 -or (Get-Content -Raw (Join-Path $success "present.txt")) -ne "baseline`n") {
        throw "PowerShell-native success case failed"
    }

    $partial = Join-Path $temp "partial"
    Invoke-Git clone -q $source $partial
    $before = (Get-FileHash -Algorithm SHA256 (Join-Path $partial "present.txt")).Hash
    $failureOutput = (& (Get-Process -Id $PID).Path -NoProfile -File $runner `
        -RepoRoot $partial -Contract $contract -Validator $validator `
        -InjectApplyFailureAfter 1 2>&1) -join "`n"
    $failed = $LASTEXITCODE -ne 0 -and $failureOutput -match "ROLLBACK_APPLY"
    $after = (Get-FileHash -Algorithm SHA256 (Join-Path $partial "present.txt")).Hash
    if (-not $failed -or $before -cne $after) {
        throw "PowerShell-native partial-apply restoration failed"
    }

    Write-Output "ok: PowerShell-native rollback integration passed"
} finally {
    Remove-Item -Recurse -Force -LiteralPath $temp -ErrorAction SilentlyContinue
}
