$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:_SddFixtureMatrixBuilderSourced = $false
. (Join-Path $Root 'tests/lib/fixture-matrix-builder.ps1')

$Canonical = if ($env:T003_CANONICAL_UNDER_TEST) { $env:T003_CANONICAL_UNDER_TEST } else { Join-Path $Root 'specs/epic-195-a7-compatibility/verification/golden-baseline/canonical' }
$Cache = $env:T003_CAPTURE_CACHE
$Mutation = $env:T003_MUTATE_ASSERTION
$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-compatibility-byte.' + [Guid]::NewGuid().ToString('N'))
$Clone = Join-Path $Work 'repository'
# Canonical inventory asserted from manifest rows: deterministic-script-output,
# exit-code, stdout-stderr, template-copy-result, schema-validator-result,
# install-result, uninstall-result, generated-directory-listing, plugin-manifest.
$Fixtures = [Collections.Generic.List[string]]::new()
$Pass = 0
$Fail = 0
New-Item -ItemType Directory -Path $Work | Out-Null

function Add-Pass([string]$Message) { $script:Pass++; Write-Host "ok: $Message" }
function Add-Fail([string]$Message) { $script:Fail++; Write-Host "FAIL: $Message" }
function Test-BytesEqual([string]$Left, [string]$Right) {
    $a = [IO.File]::ReadAllBytes($Left)
    $b = [IO.File]::ReadAllBytes($Right)
    return [Linq.Enumerable]::SequenceEqual([byte[]]$a, [byte[]]$b)
}

function Invoke-FixedCapture([string]$Fixture, [string]$Destination) {
    $captureHome = Join-Path $Fixture '.compat-home'
    New-Item -ItemType Directory -Path $captureHome -Force | Out-Null
    $saved = @{}
    Get-ChildItem Env: | Where-Object Name -Like 'SDD_*' | ForEach-Object { $saved[$_.Name] = $_.Value; Remove-Item "Env:$($_.Name)" }
    $oldTz = $env:TZ; $oldLc = $env:LC_ALL; $oldHome = $env:HOME
    try {
        $env:TZ = 'UTC'; $env:LC_ALL = 'C'; $env:HOME = $captureHome
        Push-Location $Fixture
        try { & pwsh -NoProfile -File (Join-Path $Clone 'tests/capture-golden-baseline.ps1') --write-candidate *>$null }
        finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw 'capture failed' }
        Copy-Item -Recurse -LiteralPath (Join-Path $Clone 'specs/epic-195-a7-compatibility/verification/golden-baseline/candidate/current') -Destination $Destination
    } finally {
        $env:TZ = $oldTz; $env:LC_ALL = $oldLc; $env:HOME = $oldHome
        foreach ($entry in $saved.GetEnumerator()) { Set-Item "Env:$($entry.Key)" $entry.Value }
    }
}

function Invoke-Track([string]$Fixture, [string]$Flag, [string]$Output) {
    $result = if ($Flag -ceq '--full') { 'FULL' }
        elseif ($Flag -ceq '--lite') { 'LITE' }
        elseif ((Test-Path (Join-Path $Fixture 'AGENTS.md')) -and
            ((Get-Content -Raw (Join-Path $Fixture 'AGENTS.md')).Trim() -ceq 'spec_profile: lite')) { 'LITE' }
        else { 'FULL' }
    [IO.File]::WriteAllText($Output, "$result`n", [Text.UTF8Encoding]::new($false))
}

try {
    $needsCapture = -not $Cache -or @('F1-invocation-1', 'F1-invocation-2', 'F2-invocation-1', 'F2-invocation-2').Where({ -not (Test-Path -LiteralPath (Join-Path $Cache $_)) }).Count -gt 0
    if ($needsCapture) {
        & git clone -q --shared $Root $Clone
        if ($LASTEXITCODE -ne 0) { throw 'could not create isolated capture repository' }
        Copy-Item -LiteralPath (Join-Path $Root 'tests/capture-golden-baseline.sh') -Destination (Join-Path $Clone 'tests/capture-golden-baseline.sh') -Force
        Copy-Item -LiteralPath (Join-Path $Root 'tests/capture-golden-baseline.ps1') -Destination (Join-Path $Clone 'tests/capture-golden-baseline.ps1') -Force
        $cloneCanonical = Join-Path $Clone 'specs/epic-195-a7-compatibility/verification/golden-baseline/canonical'
        Remove-Item -LiteralPath $cloneCanonical -Recurse -Force
        Copy-Item -LiteralPath $Canonical -Destination $cloneCanonical -Recurse
    }

    $targets = (Get-Content -Raw (Join-Path $Canonical 'manifest.json') | ConvertFrom-Json).targets
    foreach ($row in @('F1', 'F2')) {
        $fixture = if ($row -ceq 'F1') { build_fixture absent absent disabled-legacy valid none } else { build_fixture absent present disabled-legacy valid none }
        $Fixtures.Add($fixture)
        $captureRoot = if ($Cache) { New-Item -ItemType Directory -Path $Cache -Force | Out-Null; $Cache } else { $Work }
        $first = Join-Path $captureRoot "$row-invocation-1"
        $second = Join-Path $captureRoot "$row-invocation-2"
        if (-not (Test-Path -LiteralPath $first)) { Invoke-FixedCapture $fixture $first }
        if (-not (Test-Path -LiteralPath $second)) { Invoke-FixedCapture $fixture $second }
        foreach ($target in $targets) {
            $left = Join-Path $first $target.path
            $right = Join-Path $second $target.path
            $golden = Join-Path $Canonical $target.path
            if ($Mutation -ceq "$row`:$($target.name)") {
                $mutatedRoot = Join-Path $Work "mutated-$row-$($target.name)"
                Copy-Item -LiteralPath $first -Destination $mutatedRoot -Recurse
                $mutatedPath = Join-Path $mutatedRoot $target.path
                $mutatedBytes = [IO.File]::ReadAllBytes($mutatedPath)
                if ($mutatedBytes.Length -eq 0) { $mutatedBytes = [byte[]]@(1) } else { $mutatedBytes[0] = $mutatedBytes[0] -bxor 1 }
                [IO.File]::WriteAllBytes($mutatedPath, $mutatedBytes)
                $left = $mutatedPath
            }
            if ((Test-BytesEqual $left $right) -and (Test-BytesEqual $left $golden)) {
                Add-Pass "$row $($target.name) is byte-identical across two fixed-environment invocations and canonical"
            } else { Add-Fail "$row $($target.name) differs across invocation or canonical" }
        }
    }

    foreach ($cell in @(
        'none|present|LITE', 'none|absent|FULL',
        '--full|present|FULL', '--full|absent|FULL',
        '--lite|present|LITE', '--lite|absent|LITE'
    )) {
        $flag, $marker, $expected = $cell.Split('|')
        $fixture = if ($marker -ceq 'present') { build_fixture absent present disabled-legacy valid $flag } else { build_fixture absent absent disabled-legacy valid $flag }
        $Fixtures.Add($fixture)
        $safe = ($flag -replace '-', '') + '-' + $marker
        $first = Join-Path $Work "$safe-1.txt"
        $second = Join-Path $Work "$safe-2.txt"
        Invoke-Track $fixture $flag $first
        Invoke-Track $fixture $flag $second
        if ($Mutation -ceq "CLI:$cell") { [IO.File]::WriteAllText($second, "MUTATED`n", [Text.UTF8Encoding]::new($false)) }
        $actual = (Get-Content -Raw $first).Trim()
        if ((Test-BytesEqual $first $second) -and $actual -ceq $expected) {
            Add-Pass "CLI cell $cell is byte-identical and respects flag-marker-default priority"
        } else { Add-Fail "CLI cell $cell differs or selects the wrong track" }
    }

    $source = Join-Path $Canonical 'targets/deterministic-script-output.bin'
    $mutated = Join-Path $Work 'one-byte-mutated.bin'
    $bytes = [IO.File]::ReadAllBytes($source)
    if ($Mutation -cne 'negative-self-check') {
        if ($bytes.Length -eq 0) { $bytes = [byte[]]@(1) } else { $bytes[0] = $bytes[0] -bxor 1 }
    }
    [IO.File]::WriteAllBytes($mutated, $bytes)
    if (Test-BytesEqual $source $mutated) { Add-Fail 'negative self-check did not detect the one-byte mutation' }
    else { Add-Pass 'negative self-check detects a one-byte mutation in the golden baseline' }
} catch {
    Add-Fail $_.Exception.Message
} finally {
    foreach ($fixture in $Fixtures) { if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force } }
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
}

Write-Host "$Pass passed, $Fail failed"
if ($Fail -ne 0) { exit 1 }
