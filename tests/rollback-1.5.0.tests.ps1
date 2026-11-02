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

    $validContractText = Get-Content -Raw -LiteralPath $contract
    $shapeFailures = [Collections.Generic.List[string]]::new()
    foreach ($shape in @('root-array', 'files-object', 'schema-array')) {
        $malformed = $validContractText | ConvertFrom-Json
        if ($shape -eq 'root-array') { $malformedText = "[$validContractText]" }
        else {
            if ($shape -eq 'files-object') { $malformed.files = $malformed.files[0] }
            else { $malformed.schema = @($malformed.schema) }
            $malformedText = $malformed | ConvertTo-Json -Depth 5
        }
        $shapeContract = Join-Path $temp "$shape.json"
        [IO.File]::WriteAllText($shapeContract, $malformedText)
        $shapeRepo = Join-Path $temp $shape
        Invoke-Git clone -q $source $shapeRepo
        $shapeOutput = (& (Get-Process -Id $PID).Path -NoProfile -File $runner -RepoRoot $shapeRepo -Contract $shapeContract -Validator $validator 2>&1) -join "`n"
        $shapeExit = $LASTEXITCODE
        $afterShapeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $shapeRepo 'present.txt')).Hash.ToLowerInvariant()
        if ($shapeExit -eq 0 -or $shapeOutput -notmatch 'ROLLBACK_CONTRACT' -or $afterShapeHash -cne $releaseHash) { $shapeFailures.Add($shape) }
    }
    if ($shapeFailures.Count) { throw "Malformed rollback contracts were admitted or mutated files: $($shapeFailures -join ', ')" }
    Write-Output 'ok: rollback rejects root/files/schema container coercions before mutation'

    # Exercise the production pipe reader independently with a noisy/stalled Git executable.
    if (-not $IsWindows) {
        $ast = [Management.Automation.Language.Parser]::ParseFile($runner, [ref]$null, [ref]$null)
        foreach ($name in @('Fail-Rollback', 'Get-GitBlobHash')) {
            $definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
            . ([scriptblock]::Create($definition.Extent.Text))
        }
        $repo = $source
        $shimDir = Join-Path $temp 'git-shim'
        New-Item -ItemType Directory -Path $shimDir | Out-Null
        $shim = Join-Path $shimDir 'git'
        $savedPath = $env:PATH
        $env:SDD_ROLLBACK_TEST_GIT = (Get-Command git).Source
        @'
#!/bin/bash
if [[ "$SDD_ROLLBACK_TEST_MODE" == stall ]]; then sleep 30; exit 0; fi
printf '%100000s' x >&2
if [[ "$SDD_ROLLBACK_TEST_MODE" == failure ]]; then exit 9; fi
exec "$SDD_ROLLBACK_TEST_GIT" "$@"
'@ | Set-Content -LiteralPath $shim
        & chmod +x $shim
        if ($LASTEXITCODE -ne 0) { throw 'chmod failed' }
        try {
            $env:PATH = "$shimDir" + [IO.Path]::PathSeparator + $savedPath
            $env:SDD_ROLLBACK_TEST_MODE = 'noisy'
            if ((Get-GitBlobHash $reviewed 'present.txt') -cne $releaseHash) { throw 'noisy Git changed blob hash' }
            foreach ($mode in @('failure', 'stall')) {
                $env:SDD_ROLLBACK_TEST_MODE = $mode
                $watch = [Diagnostics.Stopwatch]::StartNew()
                $rejected = $false
                try { $null = Get-GitBlobHash $reviewed 'present.txt' -TimeoutMilliseconds 250 }
                catch { $rejected = $_.Exception.Message -match 'ROLLBACK_GIT' }
                if (-not $rejected -or $watch.Elapsed.TotalSeconds -gt 5) { throw "Git $mode was not promptly rejected" }
            }
            Write-Output 'ok: native noisy stderr drains, nonzero exit rejects, stalled Git terminates within deadline'
        } finally {
            $env:PATH = $savedPath
            Remove-Item Env:SDD_ROLLBACK_TEST_GIT, Env:SDD_ROLLBACK_TEST_MODE
        }
    } else {
        Write-Output 'skip: POSIX Git pipe fault fixture; native rollback integration still runs'
    }

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

    $finalFailure = Join-Path $temp "final-failure"
    Invoke-Git clone -q $source $finalFailure
    $before = (Get-FileHash -Algorithm SHA256 (Join-Path $finalFailure "present.txt")).Hash
    $failureOutput = (& (Get-Process -Id $PID).Path -NoProfile -File $runner `
        -RepoRoot $finalFailure -Contract $contract -Validator $validator `
        -InjectFinalVerificationFailure 2>&1) -join "`n"
    $failed = $LASTEXITCODE -ne 0 -and $failureOutput -match "ROLLBACK_APPLY"
    $after = (Get-FileHash -Algorithm SHA256 (Join-Path $finalFailure "present.txt")).Hash
    if (-not $failed -or $before -cne $after) {
        throw "PowerShell-native final-verification restoration failed"
    }

    Write-Output "ok: PowerShell-native rollback integration passed"
} finally {
    Remove-Item -Recurse -Force -LiteralPath $temp -ErrorAction SilentlyContinue
}
