# T-003 ownership-digest acceptance suite (AC-037..AC-041, AC-048..049).
# Drives the independent PowerShell resolver. T003_ONLY and
# T003_MUTATE_ASSERTION are reserved for the mutation-proof transcript.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = if ($env:T003_SOURCE_ROOT) { $env:T003_SOURCE_ROOT } else { (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$resolver = if ($env:T003_RESOLVER) { $env:T003_RESOLVER } else { Join-Path $repoRoot 'plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1' }
$canonicalizer = Join-Path $repoRoot 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.ps1'
$only = $env:T003_ONLY
$mutation = $env:T003_MUTATE_ASSERTION
$powerShell = (Get-Process -Id $PID).Path
$script:passCount = 0
$script:failCount = 0
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ownership-digest-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null

function Should-Run([string]$Label) { return [string]::IsNullOrEmpty($only) -or $only -ceq $Label }
function Is-Mutated([string]$Label) { return $mutation -ceq $Label }
function Record([string]$Label, [string]$Description, [bool]$Result) {
    if ($Result) { Write-Output "ok: ${Label}: $Description"; $script:passCount++ }
    else { Write-Output "FAIL: ${Label}: $Description"; $script:failCount++ }
}
function Write-Utf8([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}
function Invoke-Resolver([string]$Config, [string]$Paths, [string]$Script = $resolver) {
    $output = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $Script -Config $Config -ChangedPathsFile $Paths 2>&1 | Out-String -Width 8192
    if ($LASTEXITCODE -ne 0) { throw "resolver failed ($LASTEXITCODE): $output" }
    return $output | ConvertFrom-Json
}
function Get-Digest($Object) {
    if ($null -eq $Object.PSObject.Properties['context_binding']) { return '' }
    if ($null -eq $Object.context_binding.PSObject.Properties['ownership_digest']) { return '' }
    return [string]$Object.context_binding.ownership_digest
}
function Get-RuleRevision($Object) {
    if ($null -eq $Object.PSObject.Properties['resolver']) { return '' }
    if ($null -eq $Object.resolver.PSObject.Properties['rule_set_revision']) { return '' }
    return [string]$Object.resolver.rule_set_revision
}
function Get-Semantic($Object) {
    $copy = ($Object | ConvertTo-Json -Depth 30 -Compress) | ConvertFrom-Json
    [void]$copy.PSObject.Properties.Remove('ownership_input')
    [void]$copy.PSObject.Properties.Remove('context_binding')
    [void]$copy.PSObject.Properties.Remove('resolver')
    return $copy | ConvertTo-Json -Depth 30 -Compress
}
function Get-Classification($Object, [string]$Path) {
    $record = @($Object.records | Where-Object { $_.raw_path -ceq $Path })
    if ($record.Count -eq 0) { return '' }
    return [string]$record[0].classification
}

try {
    Write-Utf8 (Join-Path $tempRoot 'base.yaml') @'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
      exclude:
        - "src/desktop/generated/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
      exclude:
        - "src/mobile/generated/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
shared_paths:
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    components:
      - desktop
      - mobile
'@
    Write-Utf8 (Join-Path $tempRoot 'owner-added.yaml') @'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
  - id: newcomer
    paths:
      include:
        - "src/new/**"
'@
    Write-Utf8 (Join-Path $tempRoot 'owner-absent.yaml') @'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
'@
    Write-Utf8 (Join-Path $tempRoot 'nonmatch-before.yaml') @'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: outside-owner
    paths:
      include:
        - "elsewhere/**"
'@
    Write-Utf8 (Join-Path $tempRoot 'nonmatch-after.yaml') @'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: outside-owner
    paths:
      include:
        - "outside/**"
'@
    Write-Utf8 (Join-Path $tempRoot 'bounded-before.yaml') @'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
shared_paths:
  - pattern: "contracts/**"
    components:
      - desktop
      - mobile
'@
    Write-Utf8 (Join-Path $tempRoot 'bounded-after.yaml') @'
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
  - id: legacy
    paths:
      include:
        - "legacy/**"
shared_paths:
  - pattern: "contracts/**"
    components:
      - mobile
      - legacy
'@
    Write-Utf8 (Join-Path $tempRoot 'desktop.paths') "src/desktop/app.py`n"
    Write-Utf8 (Join-Path $tempRoot 'mobile.paths') "src/mobile/app.py`n"
    Write-Utf8 (Join-Path $tempRoot 'new.paths') "src/new/file.py`n"
    Write-Utf8 (Join-Path $tempRoot 'outside.paths') "outside/file.py`n"

    $baseDesktop = Invoke-Resolver (Join-Path $tempRoot 'base.yaml') (Join-Path $tempRoot 'desktop.paths')
    $baseMobile = Invoke-Resolver (Join-Path $tempRoot 'base.yaml') (Join-Path $tempRoot 'mobile.paths')

    if (Should-Run 'TEST-037') {
        $ownershipPath = Join-Path $tempRoot 'ownership-input.json'
        Write-Utf8 $ownershipPath ($baseDesktop.ownership_input | ConvertTo-Json -Depth 30 -Compress)
        $expectedOwnershipPath = Join-Path $tempRoot 'expected-ownership-input.json'
        Write-Utf8 $expectedOwnershipPath @'
{"components":[{"id":"desktop","paths":{"include":["src/desktop/**"],"exclude":["src/desktop/generated/**"]}},{"id":"mobile","paths":{"include":["src/mobile/**"],"exclude":["src/mobile/generated/**"]}},{"id":"legacy","paths":{"include":["legacy/**"],"exclude":[]}}],"shared_paths":[{"pattern":"docs/**","components":null,"classification":"cross-cutting"},{"pattern":"contracts/**","components":["desktop","mobile"],"classification":null}],"matcher_semantics_version":"1.0.0"}
'@
        $actualInputDigest = (& $powerShell -NoProfile -ExecutionPolicy Bypass -File $canonicalizer $ownershipPath --input-format json --hash-only | Out-String).Trim()
        $expected = (& $powerShell -NoProfile -ExecutionPolicy Bypass -File $canonicalizer $expectedOwnershipPath --input-format json --hash-only | Out-String).Trim()
        $actual = Get-Digest $baseDesktop
        $mobileActual = Get-Digest $baseMobile
        if (Is-Mutated 'TEST-037') { $expected = 'sha256:' + ('0' * 64); Write-Output 'MUTATION: TEST-037 replaces the canonical full-input digest expectation' }
        Record 'TEST-037' 'digest covers the complete declared ownership input and is Feature-independent' ($actualInputDigest -ceq $expected -and $actual -cmatch '^sha256:[0-9a-f]{64}$' -and $actual -ceq $expected -and $actual -ceq $mobileActual)
    }

    if (Should-Run 'TEST-038A') {
        $shape = $null -ne $baseDesktop.PSObject.Properties['context_binding'] -and
            @($baseDesktop.context_binding.PSObject.Properties.Name).Count -eq 1 -and
            (Get-Digest $baseDesktop) -cmatch '^sha256:[0-9a-f]{64}$' -and
            $null -ne $baseDesktop.PSObject.Properties['resolver'] -and
            -not [string]::IsNullOrEmpty([string]$baseDesktop.resolver.version) -and
            ([string]$baseDesktop.resolver.rule_set_revision) -cmatch '^sha256:[0-9a-f]{64}$'
        if (Is-Mutated 'TEST-038A') { $shape = $false; Write-Output 'MUTATION: TEST-038A removes the required context binding from the observed contract' }
        Record 'TEST-038A' 'context_binding and resolver metadata have the ADR-0021 shape' $shape
    }

    if (Should-Run 'TEST-038B') {
        $metadataMutant = ($baseDesktop | ConvertTo-Json -Depth 30 -Compress) | ConvertFrom-Json
        if ($null -eq $metadataMutant.PSObject.Properties['context_binding']) {
            $metadataMutant | Add-Member -NotePropertyName context_binding -NotePropertyValue ([pscustomobject]@{ ownership_digest = '' })
        }
        if ($null -eq $metadataMutant.PSObject.Properties['resolver']) {
            $metadataMutant | Add-Member -NotePropertyName resolver -NotePropertyValue ([pscustomobject]@{ version = ''; rule_set_revision = '' })
        }
        $metadataMutant.context_binding.ownership_digest = 'sha256:' + ('f' * 64)
        $metadataMutant.resolver.version = '99.0.0'
        $metadataMutant.resolver.rule_set_revision = 'sha256:' + ('e' * 64)
        $mutantSemantic = Get-Semantic $metadataMutant
        if (Is-Mutated 'TEST-038B') { $mutantSemantic = '{"mutated":true}'; Write-Output 'MUTATION: TEST-038B leaks metadata into the semantic comparison projection' }
        Record 'TEST-038B' 'context binding, resolver metadata, and ownership input are excluded from semantic output comparison' ((Get-Semantic $baseDesktop) -ceq $mutantSemantic)
    }

    if (Should-Run 'TEST-039') {
        $before = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-before.yaml') (Join-Path $tempRoot 'desktop.paths')
        $after = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-after.yaml') (Join-Path $tempRoot 'desktop.paths')
        $outsideBefore = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-before.yaml') (Join-Path $tempRoot 'outside.paths')
        $outsideAfter = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-after.yaml') (Join-Path $tempRoot 'outside.paths')
        $afterDigest = Get-Digest $after
        if (Is-Mutated 'TEST-039') { $afterDigest = Get-Digest $before; Write-Output 'MUTATION: TEST-039 substitutes the stale evaluated-only digest' }
        Record 'TEST-039' 'a nonmatching-to-matching rule edit changes the digest without staling unchanged Feature semantics' (
            -not [string]::IsNullOrEmpty((Get-Digest $before)) -and (Get-Digest $before) -cne $afterDigest -and
            (Get-Semantic $before) -ceq (Get-Semantic $after) -and
            (Get-Classification $outsideBefore 'outside/file.py') -ceq 'UNOWNED' -and
            (Get-Classification $outsideAfter 'outside/file.py') -ceq 'EXCLUSIVE')
    }

    function Invoke-MatrixCase([string]$Label, [string]$BeforeConfig, [string]$AfterConfig, [string]$Paths, [bool]$SemanticChanged, [bool]$DigestChanged) {
        if (-not (Should-Run $Label)) { return }
        $before = Invoke-Resolver $BeforeConfig $Paths
        $after = Invoke-Resolver $AfterConfig $Paths
        $afterDigest = Get-Digest $after
        if (Is-Mutated $Label) { $afterDigest = Get-Digest $before; Write-Output "MUTATION: $Label collapses the after digest to the before digest" }
        $observedSemantic = (Get-Semantic $before) -cne (Get-Semantic $after)
        $observedDigest = -not [string]::IsNullOrEmpty((Get-Digest $before)) -and (Get-Digest $before) -cne $afterDigest
        Record $Label "ownership freshness matrix semantic=$SemanticChanged digest=$DigestChanged" ($observedSemantic -eq $SemanticChanged -and $observedDigest -eq $DigestChanged)
    }

    Invoke-MatrixCase 'TEST-040A' (Join-Path $tempRoot 'owner-absent.yaml') (Join-Path $tempRoot 'owner-added.yaml') (Join-Path $tempRoot 'new.paths') $true $true
    Invoke-MatrixCase 'TEST-040B' (Join-Path $tempRoot 'owner-added.yaml') (Join-Path $tempRoot 'owner-absent.yaml') (Join-Path $tempRoot 'new.paths') $true $true
    Invoke-MatrixCase 'TEST-040C' (Join-Path $tempRoot 'nonmatch-before.yaml') (Join-Path $tempRoot 'nonmatch-after.yaml') (Join-Path $tempRoot 'desktop.paths') $false $true
    Invoke-MatrixCase 'TEST-040D' (Join-Path $tempRoot 'bounded-before.yaml') (Join-Path $tempRoot 'bounded-after.yaml') (Join-Path $tempRoot 'desktop.paths') $false $true

    if (Should-Run 'TEST-040E') {
        $d1Before = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-before.yaml') (Join-Path $tempRoot 'desktop.paths')
        $d1After = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-after.yaml') (Join-Path $tempRoot 'desktop.paths')
        $d2Before = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-before.yaml') (Join-Path $tempRoot 'mobile.paths')
        $d2After = Invoke-Resolver (Join-Path $tempRoot 'nonmatch-after.yaml') (Join-Path $tempRoot 'mobile.paths')
        $afterDigest = Get-Digest $d1After
        if (Is-Mutated 'TEST-040E') { $afterDigest = Get-Digest $d1Before; Write-Output 'MUTATION: TEST-040E preserves one Feature digest across the disjoint edit' }
        Record 'TEST-040E' 'a disjoint edit invalidates all Feature digests simultaneously without semantic stale' (
            (Get-Semantic $d1Before) -ceq (Get-Semantic $d1After) -and
            (Get-Semantic $d2Before) -ceq (Get-Semantic $d2After) -and
            -not [string]::IsNullOrEmpty((Get-Digest $d1Before)) -and
            (Get-Digest $d1Before) -ceq (Get-Digest $d2Before) -and
            $afterDigest -ceq (Get-Digest $d2After) -and
            (Get-Digest $d1Before) -cne $afterDigest)
    }

    if (Should-Run 'TEST-040F') {
        $mutantDir = Join-Path $tempRoot 'matcher'
        [IO.Directory]::CreateDirectory($mutantDir) | Out-Null
        foreach ($name in @('resolve-component-paths.ps1', 'canonicalize-sdd-yaml.ps1', 'canonicalize-sdd-yaml.py', 'lib/py-dispatch.ps1')) {
            $mutantDestination = Join-Path $mutantDir $name
            [IO.Directory]::CreateDirectory((Split-Path -Parent $mutantDestination)) | Out-Null
            Copy-Item (Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/$name") $mutantDestination
        }
        $mutantResolver = Join-Path $mutantDir 'resolve-component-paths.ps1'
        $text = [IO.File]::ReadAllText($mutantResolver).Replace('$MATCHER_SEMANTICS_VERSION = "1.0.0"', '$MATCHER_SEMANTICS_VERSION = "1.0.1"')
        Write-Utf8 $mutantResolver $text
        Write-Utf8 (Join-Path $tempRoot 'star.yaml') @'
components:
  - id: star
    paths:
      include:
        - "src/*"
'@
        Write-Utf8 (Join-Path $tempRoot 'star.paths') "src/nested/file.py`n"
        $original = Invoke-Resolver (Join-Path $tempRoot 'star.yaml') (Join-Path $tempRoot 'star.paths')
        $bumped = Invoke-Resolver (Join-Path $tempRoot 'star.yaml') (Join-Path $tempRoot 'star.paths') $mutantResolver
        $text = [IO.File]::ReadAllText($mutantResolver).Replace('if ($seg -eq "**") {', 'if ($seg -eq "**" -or $seg -eq "*") {')
        Write-Utf8 $mutantResolver $text
        $semantics = Invoke-Resolver (Join-Path $tempRoot 'star.yaml') (Join-Path $tempRoot 'star.paths') $mutantResolver
        $semanticsClass = Get-Classification $semantics 'src/nested/file.py'
        if (Is-Mutated 'TEST-040F') { $semanticsClass = Get-Classification $original 'src/nested/file.py'; Write-Output 'MUTATION: TEST-040F hides the changed matcher classification' }
        Record 'TEST-040F' 'version-only bumps refresh metadata only; semantic matcher changes stale affected output' (
            (Get-Semantic $original) -ceq (Get-Semantic $bumped) -and
            (Get-Digest $original) -cne (Get-Digest $bumped) -and
            (Get-RuleRevision $original) -cne (Get-RuleRevision $bumped) -and
            (Get-RuleRevision $bumped) -ceq (Get-RuleRevision $semantics) -and
            $semanticsClass -cne (Get-Classification $original 'src/nested/file.py') -and
            (Get-Digest $bumped) -ceq (Get-Digest $semantics) -and
            (Get-Semantic $bumped) -cne (Get-Semantic $semantics))
    }

    if (Should-Run 'TEST-041') {
        $wiringCount = 0
        $runAllSh = Join-Path $repoRoot 'tests/run-all.sh'
        $runAllPs1 = Join-Path $repoRoot 'tests/run-all.ps1'
        if ([IO.File]::ReadAllText($runAllSh).Contains('  tests/ownership-digest.tests.sh')) { $wiringCount++ }
        if ([IO.File]::ReadAllText($runAllPs1).Contains("'tests/ownership-digest.tests.ps1'")) { $wiringCount++ }
        $liveWorkflow = [IO.File]::ReadAllText((Join-Path $repoRoot '.github/workflows/test.yml'))
        if ($liveWorkflow.Contains('bash ./tests/ownership-digest.tests.sh')) { $wiringCount++ }
        if ($liveWorkflow.Contains('./tests/ownership-digest.tests.ps1')) { $wiringCount++ }
        if ([IO.File]::ReadAllText((Join-Path $repoRoot 'specs/epic-191-a3-path-ownership/design.md')).Contains('`tests/ownership-digest.tests.sh` / `.ps1`')) { $wiringCount++ }
        if (Is-Mutated 'TEST-041') { $wiringCount = 4; Write-Output 'MUTATION: TEST-041 removes one required registration from the observed inventory' }
        Record 'TEST-041' 'both suites are wired in run-all, live CI, and the design inventory' ($wiringCount -eq 5)
    }

    if (Should-Run 'TEST-048') {
        # Twin of the Bash section-scoped scan: the entry must sit in SOME
        # single '## ' release-notes section -- '## Unreleased' while pending,
        # and the '## vX.Y.Z' section that same block becomes once
        # scripts/bump-version.sh renames its heading. Position is not
        # asserted, for the reason TEST-049 exempts a later release from its
        # version-surface attribution; both citations are still required, and
        # required together in one section, so two unrelated releases each
        # carrying half of the pair can never satisfy it.
        $found = $false; $hasIssue = $false; $hasTask = $false
        foreach ($line in [IO.File]::ReadAllLines((Join-Path $repoRoot 'CHANGELOG.md'))) {
            if ($line.StartsWith('## ')) { $hasIssue = $false; $hasTask = $false; continue }
            if ($line.Contains('Issue #191')) { $hasIssue = $true }
            if ($line.Contains('epic-191-a3-path-ownership T-003')) { $hasTask = $true }
            if ($hasIssue -and $hasTask) { $found = $true; $hasIssue = $false; $hasTask = $false }
        }
        $releaseCount = if ($found) { 1 } else { 0 }
        if (Is-Mutated 'TEST-048') { $releaseCount = 0; Write-Output 'MUTATION: TEST-048 removes the T-003 Issue #191 release-notes entry' }
        Record 'TEST-048' 'CHANGELOG has a release-notes T-003 entry citing Issue #191' ($releaseCount -ge 1)
    }

    if (Should-Run 'TEST-049') {
        # Twin of the Bash two-form guard: strict T-003 commit attribution in
        # full history, synchronized plugin-version content at shallow depth 1.
        # Sanctioned releases are exempt because they are not T-003 commits and
        # scripts/bump-version.sh preserves the synchronized content invariant.
        $t003Commits = @(
            'ee001845afa962d541eef736b6b5a5017fc93d2f',
            '8c961886d04cb77bae545bd9645fbc2e06b2155e',
            '3b27c3e5d12b8dabe1f9724b8b069c01e55ae408',
            '1e651dbd7e2987b35936b810506cfcac3f16e319',
            'b067213544d5e1097f58ec52969c33e478030c2c',
            '305de3c406eb2dd52d01bd75997f6c7b57fcc539'
        )
        $isShallow = (& git -C $repoRoot rev-parse --is-shallow-repository 2>$null | Out-String).Trim()
        if ($isShallow -ceq 'true') {
            $versionValues = @()
            foreach ($pattern in @('plugins/*/.claude-plugin/plugin.json', 'plugins/*/.codex-plugin/plugin.json', 'plugins/*/.plugin/plugin.json')) {
                foreach ($file in (Get-ChildItem -Path (Join-Path $repoRoot $pattern) -File -ErrorAction SilentlyContinue)) {
                    $versionValues += (Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json).version
                }
            }
            $distinctVersions = @($versionValues | Sort-Object -Unique)
            if (Is-Mutated 'TEST-049') { $distinctVersions = @('1.14.0', 'mutated'); Write-Output 'MUTATION: TEST-049 desynchronizes the shallow checkout version surface' }
            $valid = $versionValues.Count -gt 0 -and $distinctVersions.Count -eq 1
        } else {
            $missingCommit = ''
            $versionTouch = ''
            foreach ($commit in $t003Commits) {
                & git -C $repoRoot cat-file -e "$commit^{commit}" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    $missingCommit = $commit
                } else {
                    $touched = @(@(& git -C $repoRoot show --name-only --format= $commit) |
                        Where-Object { $_ -cmatch '(^|/)plugin\.json$' -or $_ -ceq 'tests/validate-repository.ps1' })
                    if ($touched.Count -gt 0) { $versionTouch = "${commit}:$($touched -join ',')" }
                }
            }
            if (Is-Mutated 'TEST-049') { $versionTouch = 'MUTATION:plugins/sdd-quality-loop/.claude-plugin/plugin.json'; Write-Output 'MUTATION: TEST-049 attributes an out-of-band version surface change to T-003' }
            $valid = [string]::IsNullOrEmpty($missingCommit) -and [string]::IsNullOrEmpty($versionTouch)
        }
        Record 'TEST-049' 'no version-carrying surface is changed outside the release bump script' $valid
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "$($script:passCount) passed / $($script:failCount) failed"
if ($script:failCount -gt 0) { exit 1 }
exit 0
