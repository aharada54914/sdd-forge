$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:_SddFixtureMatrixBuilderSourced = $false
. (Join-Path $Root 'tests/lib/fixture-matrix-builder.ps1')

$Canonical = if ($env:T003_CANONICAL_UNDER_TEST) { $env:T003_CANONICAL_UNDER_TEST } else { Join-Path $Root 'specs/epic-195-a7-compatibility/verification/golden-baseline/canonical' }
$ProductRoot = if ($env:T003_PRODUCT_ROOT_UNDER_TEST) { $env:T003_PRODUCT_ROOT_UNDER_TEST } else { $Root }
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

function Resolve-ContractTrack([string]$Document, [string]$Fixture, [string]$Flag) {
    if (-not (Test-Path -LiteralPath $Document -PathType Leaf)) {
        throw "missing live product contract: $Document"
    }
    $text = Get-Content -Raw -LiteralPath $Document
    $heading = [regex]::Match($text, '(?m)^#{3,4} Compatibility fallback \(no Project Context\)\s*$')
    if (-not $heading.Success) { throw "missing compatibility fallback section: $Document" }
    $tail = $text.Substring($heading.Index + $heading.Length)
    $nextHeading = [regex]::Match($tail, '(?m)^#{1,4} \S')
    $section = if ($nextHeading.Success) { $tail.Substring(0, $nextHeading.Index) } else { $tail }
    $rows = @{}
    foreach ($match in [regex]::Matches($section, '(?m)^\s*([1-4])\.\s+(.+?)\s*$')) {
        $rows[[int]$match.Groups[1].Value] = $match.Groups[2].Value
    }
    if ($rows.Count -ne 4) { throw "incomplete compatibility fallback rows: $Document" }

    $agents = Join-Path $Fixture 'AGENTS.md'
    $markerPresent = (Test-Path -LiteralPath $agents -PathType Leaf) -and
        ((Get-Content -LiteralPath $agents) -ccontains 'spec_profile: lite')
    $row = if ($Flag -ceq '--full') { 1 } elseif ($Flag -ceq '--lite') { 2 } elseif ($markerPresent) { 3 } else { 4 }
    $track = [regex]::Match($rows[$row], '(?<![A-Za-z])(FULL|LITE)(?![A-Za-z])')
    if (-not $track.Success) { throw "fallback row $row has no track resolution: $Document" }
    return $track.Value
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
        'none|present', 'none|absent',
        '--full|present', '--full|absent',
        '--lite|present', '--lite|absent'
    )) {
        $flag, $marker = $cell.Split('|')
        $fixture = if ($marker -ceq 'present') { build_fixture absent present disabled-legacy valid $flag } else { build_fixture absent absent disabled-legacy valid $flag }
        $Fixtures.Add($fixture)
        try {
            $first = Resolve-ContractTrack (Join-Path $ProductRoot 'plugins/sdd-ship/skills/ship/SKILL.md') $fixture $flag
            $second = Resolve-ContractTrack (Join-Path $ProductRoot 'plugins/sdd-ship/skills/ship/SKILL.md') $fixture $flag
            $expected = Resolve-ContractTrack (Join-Path $ProductRoot 'PLUGIN-CONTRACTS.md') $fixture $flag
            if (($first -ceq $second) -and ($first -ceq $expected)) {
                Add-Pass "CLI cell $cell resolves identically from both live product contracts"
            } else { Add-Fail "CLI cell $cell is inconsistent across live product contracts" }
        } catch {
            Add-Fail "CLI cell $cell could not resolve live product contracts: $($_.Exception.Message)"
        }
    }

    $source = Join-Path $Canonical 'targets/deterministic-script-output.bin'
    $observed = $source
    if ($Mutation -ceq 'negative-self-check') {
        $observed = Join-Path $Work 'one-byte-mutated.bin'
        $bytes = [IO.File]::ReadAllBytes($source)
        if ($bytes.Length -eq 0) { $bytes = [byte[]]@(1) } else { $bytes[0] = $bytes[0] -bxor 1 }
        [IO.File]::WriteAllBytes($observed, $bytes)
    }
    $manifestTarget = (Get-Content -Raw (Join-Path $Canonical 'manifest.json') | ConvertFrom-Json).targets |
        Where-Object name -CEQ 'deterministic-script-output'
    if ($null -eq $manifestTarget) { throw 'deterministic-script-output missing from manifest' }
    $actualHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($observed))).ToLowerInvariant()
    if ($actualHash -ceq $manifestTarget.sha256) {
        Add-Pass 'negative self-check: canonical target bytes match the manifest sha256'
    } else { Add-Fail 'negative self-check: canonical target bytes differ from the manifest sha256' }
} catch {
    Add-Fail $_.Exception.Message
} finally {
    foreach ($fixture in $Fixtures) { if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force } }
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
}

Write-Host "$Pass passed, $Fail failed"
if ($Fail -ne 0) { exit 1 }
