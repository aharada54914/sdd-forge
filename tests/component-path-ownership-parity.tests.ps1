#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ResolverSh = Join-Path $Root 'plugins/sdd-quality-loop/scripts/resolve-component-paths.sh'
$ResolverPs = Join-Path $Root 'plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1'
$CoverageSh = Join-Path $Root 'plugins/sdd-quality-loop/scripts/check-component-coverage.sh'
$CoveragePs = Join-Path $Root 'plugins/sdd-quality-loop/scripts/check-component-coverage.ps1'
$ResolverFixture = Join-Path $Root 'tests/fixtures/component-path-ownership/test-016-overlap'
$CoverageFixture = Join-Path $Root 'tests/fixtures/check-component-coverage'
$FeatureRoot = Join-Path $Root 'specs/epic-191-a3-path-ownership'
$Acceptance = Join-Path $FeatureRoot 'acceptance-tests.md'
$Traceability = Join-Path $FeatureRoot 'traceability.md'
$HumanCopy = Join-Path $FeatureRoot 'human-copy'
$StagedWorkflow = Join-Path $HumanCopy '.github/workflows/test.yml'
$Manifest = Join-Path $HumanCopy 'MANIFEST.sha256'
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("path-ownership-parity-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Tmp | Out-Null
$script:Passed = 0
$script:Failed = 0

function Pass([string]$Label) {
    $script:Passed++
    Write-Output "ok - $Label"
}

function Fail([string]$Label) {
    $script:Failed++
    Write-Output "not ok - $Label"
}

function Assert-Equal([string]$Label, [string]$Actual, [string]$Expected) {
    if ([string]::Equals($Actual, $Expected, [System.StringComparison]::Ordinal)) {
        Pass $Label
    } else {
        Fail "$Label (shell=[$Actual], pwsh=[$Expected])"
    }
}

function Invoke-Captured([string]$Stem, [string]$Command, [string[]]$Arguments) {
    $stdout = Join-Path $Tmp "$Stem.stdout"
    $stderr = Join-Path $Tmp "$Stem.stderr"
    & $Command @Arguments 1> $stdout 2> $stderr
    $status = $LASTEXITCODE
    [System.IO.File]::WriteAllText((Join-Path $Tmp "$Stem.exit"), [string]$status)
}

function Read-Captured([string]$Stem, [string]$Extension) {
    return [System.IO.File]::ReadAllText((Join-Path $Tmp "$Stem.$Extension"))
}

function Get-CanonicalJson([string]$Stem) {
    $path = Join-Path $Tmp "$Stem.stdout"
    $text = & jq -S -c . $path 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return (($text -join "`n").TrimEnd("`r", "`n"))
}

function Get-ErrorCategory([string]$Stem, [string]$Probe) {
    $status = Read-Captured $Stem 'exit'
    if ($status -eq '0') { return 'accepted' }
    $stderr = Read-Captured $Stem 'stderr'
    if ($stderr.Contains($Probe, [System.StringComparison]::Ordinal)) {
        return 'rejected-named-extra'
    }
    if ($stderr.Length -gt 0) {
        return (($stderr -split "`r?`n", 2)[0] -split ':', 2)[0]
    }
    return 'rejected-without-category'
}

function Test-RegistrationAudit([string]$RunSh, [string]$RunPs, [string]$Workflow, [string[]]$Suites) {
    $runShText = [System.IO.File]::ReadAllText($RunSh)
    $runPsText = [System.IO.File]::ReadAllText($RunPs)
    $workflowText = [System.IO.File]::ReadAllText($Workflow)
    foreach ($suite in $Suites) {
        $shToken = "tests/$suite.tests.sh"
        $psToken = "tests/$suite.tests.ps1"
        if (($runShText.Split($shToken).Count - 1) -ne 1 -or
            ($runPsText.Split($psToken).Count - 1) -ne 1 -or
            ($workflowText.Split($shToken).Count - 1) -ne 1 -or
            ($workflowText.Split($psToken).Count - 1) -ne 1) {
            return $false
        }
    }
    return $true
}

try {
    $required = @(
        $ResolverSh, $ResolverPs, $CoverageSh, $CoveragePs,
        (Join-Path $ResolverFixture 'config.yaml'),
        (Join-Path $ResolverFixture 'changed-paths.txt'),
        (Join-Path $CoverageFixture 'config-required.yaml'),
        (Join-Path $CoverageFixture 'facet-manifest-full.json'),
        (Join-Path $CoverageFixture 'changed-paths-clean.txt')
    )
    foreach ($path in $required) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Fail "TEST-050 requires shipped surface $path"
        }
    }

    $resolverShArgs = @(
        $ResolverSh, '--config', (Join-Path $ResolverFixture 'config.yaml'),
        '--changed-paths-file', (Join-Path $ResolverFixture 'changed-paths.txt')
    )
    $resolverPsArgs = @(
        '-NoProfile', '-File', $ResolverPs,
        '-Config', (Join-Path $ResolverFixture 'config.yaml'),
        '-ChangedPathsFile', (Join-Path $ResolverFixture 'changed-paths.txt')
    )
    Invoke-Captured 'resolver-sh' 'bash' $resolverShArgs
    Invoke-Captured 'resolver-ps' 'pwsh' $resolverPsArgs
    $resolverShJson = Get-CanonicalJson 'resolver-sh'
    $resolverPsJson = Get-CanonicalJson 'resolver-ps'
    if ($resolverShJson.Length -gt 0 -and $resolverPsJson.Length -gt 0) {
        Pass 'TEST-050 resolver outputs parse as JSON'
    } else {
        Fail 'TEST-050 resolver outputs parse as JSON'
    }
    Assert-Equal 'TEST-050 resolver canonical stdout parity' $resolverShJson $resolverPsJson
    Assert-Equal 'TEST-050 resolver exit parity' (Read-Captured 'resolver-sh' 'exit') (Read-Captured 'resolver-ps' 'exit')

    $coverageShArgs = @(
        $CoverageSh, '--config', (Join-Path $CoverageFixture 'config-required.yaml'),
        '--facet-manifest', (Join-Path $CoverageFixture 'facet-manifest-full.json'),
        '--changed-paths-file', (Join-Path $CoverageFixture 'changed-paths-clean.txt')
    )
    $coveragePsArgs = @(
        '-NoProfile', '-File', $CoveragePs,
        '-Config', (Join-Path $CoverageFixture 'config-required.yaml'),
        '-FacetManifest', (Join-Path $CoverageFixture 'facet-manifest-full.json'),
        '-ChangedPathsFile', (Join-Path $CoverageFixture 'changed-paths-clean.txt')
    )
    Invoke-Captured 'coverage-sh' 'bash' $coverageShArgs
    Invoke-Captured 'coverage-ps' 'pwsh' $coveragePsArgs
    $coverageShJson = Get-CanonicalJson 'coverage-sh'
    $coveragePsJson = Get-CanonicalJson 'coverage-ps'
    if ($coverageShJson.Length -gt 0 -and $coveragePsJson.Length -gt 0) {
        Pass 'TEST-050 coverage outputs parse as JSON'
    } else {
        Fail 'TEST-050 coverage outputs parse as JSON'
    }
    Assert-Equal 'TEST-050 coverage canonical stdout and warning parity' $coverageShJson $coveragePsJson
    Assert-Equal 'TEST-050 coverage exit and LASTEXITCODE parity' (Read-Captured 'coverage-sh' 'exit') (Read-Captured 'coverage-ps' 'exit')

    # The probe is derived from this shipped suite, not copied in as an expected
    # product value. Resolver cells are GREEN under the amended direct fix; the
    # protected coverage cells remain designed RED pending human application.
    $probeDigest = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.Substring(0, 12).ToLowerInvariant()
    $probe = "parity-probe-$probeDigest"
    Invoke-Captured 'resolver-extra-sh' 'bash' ($resolverShArgs + "--$probe")
    Invoke-Captured 'resolver-extra-ps' 'pwsh' ($resolverPsArgs + "-$probe")
    Assert-Equal 'TEST-050 resolver extra-argument exit parity' (Read-Captured 'resolver-extra-sh' 'exit') (Read-Captured 'resolver-extra-ps' 'exit')
    Assert-Equal 'TEST-050 resolver extra-argument category parity' (Get-ErrorCategory 'resolver-extra-sh' $probe) (Get-ErrorCategory 'resolver-extra-ps' $probe)

    Invoke-Captured 'coverage-extra-sh' 'bash' ($coverageShArgs + "--$probe")
    Invoke-Captured 'coverage-extra-ps' 'pwsh' ($coveragePsArgs + "-$probe")
    Assert-Equal 'TEST-050 coverage extra-argument exit parity' (Read-Captured 'coverage-extra-sh' 'exit') (Read-Captured 'coverage-extra-ps' 'exit')
    Assert-Equal 'TEST-050 coverage extra-argument category parity' (Get-ErrorCategory 'coverage-extra-sh' $probe) (Get-ErrorCategory 'coverage-extra-ps' $probe)

    $env:T006_REAL_RESOLVER = $ResolverPs
    @'
param([string]$Config, [string]$ChangedPathsFile)
& $env:T006_REAL_RESOLVER -Config $Config -ChangedPathsFile $ChangedPathsFile
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath (Join-Path $Tmp 'argument-drop-mutant.ps1') -NoNewline
    @'
param([string]$Config, [string]$ChangedPathsFile)
& $env:T006_REAL_RESOLVER -Config $Config -ChangedPathsFile $ChangedPathsFile @args
exit 0
'@ | Set-Content -LiteralPath (Join-Path $Tmp 'child-exit-mutant.ps1') -NoNewline

    $dropMutant = Join-Path $Tmp 'argument-drop-mutant.ps1'
    Invoke-Captured 'mutant-drop-recognized' 'pwsh' @('-NoProfile', '-File', $dropMutant, '-Config', (Join-Path $ResolverFixture 'config.yaml'), '-ChangedPathsFile', (Join-Path $ResolverFixture 'changed-paths.txt'))
    Invoke-Captured 'mutant-drop-extra' 'pwsh' @('-NoProfile', '-File', $dropMutant, '-Config', (Join-Path $ResolverFixture 'config.yaml'), '-ChangedPathsFile', (Join-Path $ResolverFixture 'changed-paths.txt'), "-$probe")
    $dropDetected = (Get-CanonicalJson 'mutant-drop-recognized') -ceq $resolverShJson -and
        (Read-Captured 'mutant-drop-recognized' 'exit') -ceq (Read-Captured 'resolver-sh' 'exit') -and
        ((Read-Captured 'mutant-drop-extra' 'exit') -cne (Read-Captured 'resolver-extra-sh' 'exit') -or
         (Get-ErrorCategory 'mutant-drop-extra' $probe) -cne (Get-ErrorCategory 'resolver-extra-sh' $probe))
    if ($dropDetected) { Pass 'TEST-050 disposable argument-drop mutant is detected' } else { Fail 'TEST-050 disposable argument-drop mutant is detected' }

    $exitMutant = Join-Path $Tmp 'child-exit-mutant.ps1'
    Invoke-Captured 'mutant-exit-recognized' 'pwsh' @('-NoProfile', '-File', $exitMutant, '-Config', (Join-Path $ResolverFixture 'config.yaml'), '-ChangedPathsFile', (Join-Path $ResolverFixture 'changed-paths.txt'))
    Invoke-Captured 'mutant-exit-extra' 'pwsh' @('-NoProfile', '-File', $exitMutant, '-Config', (Join-Path $ResolverFixture 'config.yaml'), '-ChangedPathsFile', (Join-Path $ResolverFixture 'changed-paths.txt'), "-$probe")
    $exitDetected = (Get-CanonicalJson 'mutant-exit-recognized') -ceq $resolverShJson -and
        (Read-Captured 'mutant-exit-recognized' 'exit') -ceq (Read-Captured 'resolver-sh' 'exit') -and
        ((Read-Captured 'mutant-exit-extra' 'exit') -cne (Read-Captured 'resolver-extra-sh' 'exit') -or
         (Get-ErrorCategory 'mutant-exit-extra' $probe) -cne (Get-ErrorCategory 'resolver-extra-sh' $probe))
    if ($exitDetected) { Pass 'TEST-050 disposable child-exit mutant is detected' } else { Fail 'TEST-050 disposable child-exit mutant is detected' }
    Remove-Item Env:T006_REAL_RESOLVER -ErrorAction SilentlyContinue

    $suiteMatches = Select-String -LiteralPath $Traceability -Pattern 'tests/[a-z0-9-]+\.tests' -AllMatches
    $suiteBases = @($suiteMatches.Matches.Value | ForEach-Object { $_.Substring(6, $_.Length - 12) } | Sort-Object -Unique)
    if ($suiteBases.Count -gt 0 -and (Test-RegistrationAudit (Join-Path $Root 'tests/run-all.sh') (Join-Path $Root 'tests/run-all.ps1') $StagedWorkflow $suiteBases)) {
        Pass 'TEST-047 all spec-declared suites are registered once in both runners and staged CI'
    } else {
        Fail 'TEST-047 all spec-declared suites are registered once in both runners and staged CI'
    }

    $paritySuite = [System.IO.Path]::GetFileName($PSCommandPath).Replace('.tests.ps1', '')
    if (Test-RegistrationAudit (Join-Path $Root 'tests/run-all.sh') (Join-Path $Root 'tests/run-all.ps1') $StagedWorkflow @($paritySuite)) {
        Pass 'TEST-051 parity harness self-registration'
    } else {
        Fail 'TEST-051 parity harness self-registration'
    }

    Push-Location $HumanCopy
    try {
        $manifestOutput = & shasum -a 256 -c MANIFEST.sha256 2>&1
        $manifestStatus = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($manifestStatus -eq 0) { Pass 'TEST-051 staged candidates match every manifest row' } else { Fail "TEST-051 staged candidates match every manifest row ($($manifestOutput -join '; '))" }

    $mutantRunSh = Join-Path $Tmp 'run-all-mutant.sh'
    Copy-Item -LiteralPath (Join-Path $Root 'tests/run-all.sh') -Destination $mutantRunSh
    $firstSuite = $suiteBases[0]
    $mutantText = [System.IO.File]::ReadAllText($mutantRunSh)
    $mutantText = [regex]::Replace($mutantText, [regex]::Escape("tests/$firstSuite.tests.sh"), '', 1)
    [System.IO.File]::WriteAllText($mutantRunSh, $mutantText)
    if (-not (Test-RegistrationAudit $mutantRunSh (Join-Path $Root 'tests/run-all.ps1') $StagedWorkflow $suiteBases)) {
        Pass 'TEST-047 registration audit rejects a disposable missing-suite mutant'
    } else {
        Fail 'TEST-047 registration audit rejects a disposable missing-suite mutant'
    }

    $ac047 = Get-Content -LiteralPath $Acceptance | Where-Object { $_.StartsWith('| AC-047 ') }
    $behaviorSpan = [regex]::Match($ac047, 'each of (.+?) has ').Groups[1].Value
    $behaviors = @($behaviorSpan -split '[,/]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $behaviorContract = @(
        @{ Behavior = 'overlap'; Assertion = 'TEST-016.1'; Suite = 'component-path-resolver'; Evidence = 'T-001/component-path-resolver' }
        @{ Behavior = 'unowned'; Assertion = 'TEST-015.1'; Suite = 'component-path-resolver'; Evidence = 'T-001/component-path-resolver' }
        @{ Behavior = 'rename'; Assertion = 'TEST-022.1'; Suite = 'component-path-diff-basis'; Evidence = 'T-002/component-path-diff-basis' }
        @{ Behavior = 'untracked'; Assertion = 'TEST-020.1'; Suite = 'component-path-diff-basis'; Evidence = 'T-002/component-path-diff-basis' }
        @{ Behavior = 'exclude-misuse'; Assertion = 'TEST-032.1'; Suite = 'check-component-coverage'; Evidence = 'T-004/check-component-coverage' }
        @{ Behavior = 'shared-undeclared'; Assertion = 'TEST-031.2'; Suite = 'check-component-coverage'; Evidence = 'T-004/check-component-coverage' }
    )
    $behaviorAudit = $true
    $declaredBehaviorKeys = ($behaviors | Sort-Object) -join "`n"
    $expectedBehaviorKeys = ($behaviorContract.Behavior | Sort-Object) -join "`n"
    if ($declaredBehaviorKeys -cne $expectedBehaviorKeys) { $behaviorAudit = $false }
    foreach ($entry in $behaviorContract) {
        $shSource = [System.IO.File]::ReadAllText((Join-Path $Root "tests/$($entry.Suite).tests.sh"))
        $psSource = [System.IO.File]::ReadAllText((Join-Path $Root "tests/$($entry.Suite).tests.ps1"))
        $sourceLines = @(($shSource + "`n" + $psSource) -split "`r?`n" | Where-Object {
            -not $_.TrimStart().StartsWith('#') -and $_.Contains("$($entry.Assertion):", [System.StringComparison]::Ordinal)
        })
        $redText = [System.IO.File]::ReadAllText((Join-Path $FeatureRoot "verification/$($entry.Evidence).RED.log"))
        $greenText = [System.IO.File]::ReadAllText((Join-Path $FeatureRoot "verification/$($entry.Evidence).GREEN.log"))
        if (-not ($sourceLines | Where-Object { $_ -match '(^|[^A-Za-z0-9_])(ok|pass)\s' }) -or
            -not ($sourceLines | Where-Object { $_ -match '(^|[^A-Za-z0-9_])fail\s' }) -or
            -not $redText.Contains("$($entry.Assertion):", [System.StringComparison]::Ordinal) -or
            $redText -notmatch 'Results: \d+ passed, [1-9]\d* failed' -or
            -not $greenText.Contains("$($entry.Assertion):", [System.StringComparison]::Ordinal) -or
            $greenText -notmatch 'Results: \d+ passed, 0 failed') {
            $behaviorAudit = $false
        }
    }
    if ($behaviorAudit) { Pass 'TEST-047 spec-declared behavior branches have positive and red-then-fixed evidence' } else { Fail 'TEST-047 spec-declared behavior branches have positive and red-then-fixed evidence' }

    $fixtureAudit = $true
    foreach ($line in (Get-Content -LiteralPath $Acceptance)) {
        if ($line -match '^\| (AC-00[6-9]) .*\| TEST-([0-9]+) \|') {
            if (-not (Get-ChildItem -LiteralPath (Join-Path $Root 'tests/fixtures/component-path-ownership') -Directory -Filter "test-$($Matches[2])*")) { $fixtureAudit = $false }
        }
    }
    $ac010 = Get-Content -LiteralPath $Acceptance | Where-Object { $_.StartsWith('| AC-010 ') }
    $null = $ac010 -match '\| TEST-([0-9]+) \|'
    if (-not (Get-ChildItem -LiteralPath (Join-Path $Root 'tests/fixtures/component-path-ownership') -Directory -Filter "test-$($Matches[1])*")) { $fixtureAudit = $false }
    $ac024 = Get-Content -LiteralPath $Acceptance | Where-Object { $_.StartsWith('| AC-024 ') }
    $null = $ac024 -match '\| TEST-([0-9]+) \|.*\(([0-9]+) fixtures\)'
    $refTest = $Matches[1]
    $refCount = [int]$Matches[2]
    $diffSh = [System.IO.File]::ReadAllText((Join-Path $Root 'tests/component-path-diff-basis.tests.sh'))
    $diffPs = [System.IO.File]::ReadAllText((Join-Path $Root 'tests/component-path-diff-basis.tests.ps1'))
    foreach ($i in 1..$refCount) {
        if (-not $diffSh.Contains("TEST-$refTest.$i", [System.StringComparison]::Ordinal) -or
            -not $diffPs.Contains("TEST-$refTest.$i", [System.StringComparison]::Ordinal)) { $fixtureAudit = $false }
    }
    if ($fixtureAudit) { Pass 'TEST-047 glob, NFC-collision, and reference-only fixture inventory' } else { Fail 'TEST-047 glob, NFC-collision, and reference-only fixture inventory' }

    & git diff --quiet -- .github/workflows/test.yml
    if ($LASTEXITCODE -eq 0) { Pass 'TEST-047 live protected workflow remains byte-unchanged' } else { Fail 'TEST-047 live protected workflow remains byte-unchanged' }

    $releaseSurfaces = @(
        Get-ChildItem -LiteralPath (Join-Path $Root 'plugins') -Recurse -Force -File -Filter 'plugin.json' | Where-Object { $_.FullName -match '/\.(claude-plugin|codex-plugin|plugin)/plugin\.json$' } | ForEach-Object { $_.FullName.Substring($Root.Length + 1) }
        '.claude-plugin/marketplace.json'; '.agents/plugins/marketplace.json'; 'README.md'; 'tests/validate-repository.ps1'; 'tests/repository-release-validation.tests.sh'
    )
    $versionMutation = $false
    foreach ($surface in $releaseSurfaces) {
        & git diff --quiet -- $surface
        if ($LASTEXITCODE -ne 0) { $versionMutation = $true }
    }
    # Preserve the baseline across a real bump-version.sh replay. The normal
    # task path proves no surface changed; the content fallback proves that a
    # changed set converged on the validator-derived shipped version.
    $releaseSync = $true
    $validatorText = [System.IO.File]::ReadAllText((Join-Path $Root 'tests/validate-repository.ps1'))
    $versionMatch = [regex]::Match($validatorText, '"sdd-ship"\s*=\s*"([0-9.]+)"')
    if (-not $versionMatch.Success) { $releaseSync = $false; $shippedVersion = '' } else { $shippedVersion = $versionMatch.Groups[1].Value }
    foreach ($manifest in (Get-ChildItem -LiteralPath (Join-Path $Root 'plugins') -Recurse -Force -File -Filter 'plugin.json' | Where-Object { $_.FullName -match '/\.(claude-plugin|codex-plugin|plugin)/plugin\.json$' })) {
        if ((Get-Content -LiteralPath $manifest.FullName -Raw | ConvertFrom-Json).version -cne $shippedVersion) { $releaseSync = $false }
    }
    foreach ($marketplacePath in @('.claude-plugin/marketplace.json', '.agents/plugins/marketplace.json')) {
        $marketplaceText = [System.IO.File]::ReadAllText((Join-Path $Root $marketplacePath))
        $versions = [regex]::Matches($marketplaceText, '"version"\s*:\s*"([0-9.]+)"') | ForEach-Object { $_.Groups[1].Value }
        if ($versions.Count -eq 0 -or @($versions | Where-Object { $_ -cne $shippedVersion }).Count -gt 0) { $releaseSync = $false }
    }
    $readmeText = [System.IO.File]::ReadAllText((Join-Path $Root 'README.md'))
    $readmeMatch = [regex]::Match($readmeText, '(?m)^v([0-9.]+)')
    if (-not $readmeMatch.Success -or $readmeMatch.Groups[1].Value -cne $shippedVersion) { $releaseSync = $false }
    $releaseTestText = [System.IO.File]::ReadAllText((Join-Path $Root 'tests/repository-release-validation.tests.sh'))
    if (-not $releaseTestText.Contains($shippedVersion, [System.StringComparison]::Ordinal)) { $releaseSync = $false }
    if (-not $versionMutation -or $releaseSync) { Pass 'TEST-049 release surfaces are untouched or synchronized by bump-version' } else { Fail 'TEST-049 release surfaces are untouched or synchronized by bump-version' }

    $taskId = (((Get-Content -LiteralPath $Traceability | Where-Object { $_.StartsWith('| T-006 ') })[0]) -split '\|')[1].Trim()
    $ac048 = Get-Content -LiteralPath $Acceptance | Where-Object { $_.StartsWith('| AC-048 ') }
    $issueId = [regex]::Match($ac048, '#[0-9]+').Value
    $changeText = [System.IO.File]::ReadAllText((Join-Path $Root 'CHANGELOG.md'))
    if ($changeText -match "(?s)$([regex]::Escape($taskId)).{0,160}$([regex]::Escape($issueId))|$([regex]::Escape($issueId)).{0,160}$([regex]::Escape($taskId))") {
        Pass 'TEST-048 task changelog registration survives release-heading replay'
    } else {
        Fail 'TEST-048 task changelog registration survives release-heading replay'
    }

    Write-Output ''
    Write-Output ("Results: {0} passed, {1} failed" -f $script:Passed, $script:Failed)
    if ($script:Failed -gt 0) { exit 1 }
    exit 0
} finally {
    Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
