# human-copy-runner-contract.tests.ps1 (epic-194-a6-lite-integration, T-001)
#
# TDD suite for specs/epic-194-a6-lite-integration/human-copy/
# apply-protected-files.ps1 -- design.md Protected-File Statement's
# four-point contract (AC-010, AC-031):
#   1. correct four-target payload + matching MANIFEST.sha256 copies
#      cleanly and every installed file's post-copy hash matches.
#   2. a payload file set with an undeclared fifth path is rejected before
#      any copy.
#   3. a payload missing one of the four declared targets is rejected
#      before any copy.
#   4. a per-target hash mismatch against MANIFEST.sha256 is rejected
#      before any copy.
#   5. a control file (MANIFEST.sha256 itself, or the runner script) is
#      correctly excluded from the payload-set comparison, never flagged
#      as extraneous.
#   6. a simulated post-copy corruption is detected and reported, not
#      silently accepted.
#   7. feature-scoped resolution: the runner reads targets/digests from
#      this feature's own human-copy prefix only.
#   8. control-file names and SHA-256 digests are matched case-sensitively.
#   9. a destination reached through an ancestor symlink/reparse point is
#      rejected before copy and cannot escape the repository root; a
#      destination parent substituted after validation cannot redirect the
#      publish either.
#  10. a nested PROPOSED/ subtree is rejected explicitly before copy; it is
#      payload, never an implicitly ignored control subtree.
#
# CI-resilience (Global Constraints): no possibly-empty array expanded
# under strict mode without a guard; every mktemp-equivalent root is
# resolved to its full path immediately after creation; no suite drives a
# real validator/gate directly against this repository's own live
# protected files -- every fixture below is a disposable, isolated
# temporary repository-root tree.

param(
    [ValidateSet('all', 'case-sensitive', 'ancestor-symlink', 'nested-proposed')]
    [string]$SecurityRegression = 'all',
    [string]$RunnerUnderTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$DefaultRunnerPath = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/drafts/apply-protected-files.ps1'
$RunnerPath = if ([string]::IsNullOrWhiteSpace($RunnerUnderTest)) { $DefaultRunnerPath } else { $RunnerUnderTest }
$RunnerPath = (Resolve-Path -LiteralPath $RunnerPath).Path
$FixtureCatalogPath = Join-Path $RepoRoot 'tests/fixtures/epic-194-human-copy/scenarios.json'
$CiDraftPath = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/drafts/T-001-ci-steps.yml'

$Script:Pass = 0
$Script:Fail = 0

function Ok([string]$Message) { Write-Host "ok: $Message"; $Script:Pass++ }
function Bad([string]$Message) { Write-Host "FAIL: $Message"; $Script:Fail++ }

if (-not (Test-Path -LiteralPath $FixtureCatalogPath -PathType Leaf)) {
    Bad "TEST-000a: fixture catalog is missing: $FixtureCatalogPath"
    Write-Host ''
    Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
    exit 1
}

$FixtureCatalog = Get-Content -LiteralPath $FixtureCatalogPath -Raw | ConvertFrom-Json
$RequiredScenarioNames = @(
    'correct',
    'undeclared_payload',
    'missing_payload',
    'manifest_extra_target',
    'manifest_missing_target',
    'hash_mismatch',
    'control_files',
    'post_copy_corruption',
    'feature_scope',
    'case_sensitive_control_and_digest',
    'ancestor_symlink_escape',
    'nested_proposed'
)
if ($FixtureCatalog.schema -eq 'epic-194-human-copy-fixtures/v1') {
    Ok 'TEST-000a: fixture catalog schema is recognized'
} else {
    Bad "TEST-000a: fixture catalog schema should be epic-194-human-copy-fixtures/v1, got $($FixtureCatalog.schema)"
}
$ActualScenarioNames = @($FixtureCatalog.scenarios.PSObject.Properties.Name)
$MissingScenarioNames = @($RequiredScenarioNames | Where-Object { $_ -notin $ActualScenarioNames })
if ($MissingScenarioNames.Count -eq 0) {
    Ok 'TEST-000b: fixture catalog covers every required runner scenario'
} else {
    Bad "TEST-000b: fixture catalog is missing scenarios: $($MissingScenarioNames -join ', ')"
}

$RunAllSh = Get-Content -LiteralPath (Join-Path $RepoRoot 'tests/run-all.sh') -Raw
$RunAllPs1 = Get-Content -LiteralPath (Join-Path $RepoRoot 'tests/run-all.ps1') -Raw
$ShT001 = $RunAllSh.IndexOf('tests/human-copy-runner-contract.tests.sh', [StringComparison]::Ordinal)
$ShT002 = $RunAllSh.IndexOf('tests/check-risk-upgrade-byte-identical.tests.sh', [StringComparison]::Ordinal)
$Ps1T001 = $RunAllPs1.IndexOf('tests/human-copy-runner-contract.tests.ps1', [StringComparison]::Ordinal)
$Ps1T002 = $RunAllPs1.IndexOf('tests/check-risk-upgrade-byte-identical.tests.ps1', [StringComparison]::Ordinal)
if ($ShT001 -ge 0 -and $ShT002 -ge 0 -and $ShT001 -lt $ShT002 -and $Ps1T001 -ge 0 -and $Ps1T002 -ge 0 -and $Ps1T001 -lt $Ps1T002) {
    Ok 'TEST-000c: twin suites self-register first in the Epic-194 serialized order'
} else {
    Bad 'TEST-000c: twin suites must be registered before the T-002 Epic-194 suites in both run-all arrays'
}

if (-not (Test-Path -LiteralPath $CiDraftPath -PathType Leaf)) {
    Bad "TEST-000d: non-protected CI wiring draft is missing: $CiDraftPath"
} else {
    $CiDraft = Get-Content -LiteralPath $CiDraftPath -Raw
    $HasShStep = $CiDraft.Contains('bash ./tests/human-copy-runner-contract.tests.sh')
    $HasPs1Step = $CiDraft.Contains('./tests/human-copy-runner-contract.tests.ps1')
    $HasInsertionPoint = $CiDraft.Contains('before: tests/check-risk-upgrade-byte-identical.tests.sh')
    if ($HasShStep -and $HasPs1Step -and $HasInsertionPoint) {
        Ok 'TEST-000d: CI draft contains both twin steps and the first-in-Epic-194 insertion point'
    } else {
        Bad 'TEST-000d: CI draft is missing a twin step or the required insertion point'
    }
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

$DeclaredTargets = @($FixtureCatalog.declared_targets)

function New-TempRoot {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t001-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    # Normalize immediately after creation (CI-resilience: mktemp-root normalization).
    return (Resolve-Path -LiteralPath $path).Path
}

function New-RepoFixture {
    # Builds an isolated fake "repository root" with: (a) AGENTS.md marker,
    # (b) live destination files at the four target paths (pre-existing
    # content, distinct from the staged payload so a real copy is
    # observable), and (c) an EMPTY human-copy staging directory the
    # caller populates per-scenario.
    param([Parameter(Mandatory)][string]$Root)
    New-Item -ItemType File -Path (Join-Path $Root 'AGENTS.md') -Force | Out-Null
    foreach ($target in $DeclaredTargets) {
        $native = $target -replace '/', [IO.Path]::DirectorySeparatorChar
        $dest = Join-Path $Root $native
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Set-Content -LiteralPath $dest -Value "live-original: $target" -NoNewline
    }
    $humanCopyRoot = Join-Path $Root 'specs/epic-194-a6-lite-integration/human-copy'
    New-Item -ItemType Directory -Path $humanCopyRoot -Force | Out-Null
    return $humanCopyRoot
}

function Get-Sha256Hex([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-StagedPayload {
    # Stages the four declared targets under $HumanCopyRoot with the given
    # content map (target -> content string), then writes a matching
    # MANIFEST.sha256 and copies the runner script itself alongside (both
    # control files, so a well-formed fixture proves they're excluded from
    # the exact-set comparison).
    param(
        [Parameter(Mandatory)][string]$HumanCopyRoot,
        [Parameter(Mandatory)]$ContentMap,
        [switch]$SkipManifest,
        [switch]$SkipRunnerCopy
    )
    foreach ($target in $ContentMap.Keys) {
        $native = $target -replace '/', [IO.Path]::DirectorySeparatorChar
        $stagedPath = Join-Path $HumanCopyRoot $native
        New-Item -ItemType Directory -Path (Split-Path -Parent $stagedPath) -Force | Out-Null
        Set-Content -LiteralPath $stagedPath -Value $ContentMap[$target] -NoNewline
    }
    if (-not $SkipManifest) {
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($target in $ContentMap.Keys) {
            $native = $target -replace '/', [IO.Path]::DirectorySeparatorChar
            $stagedPath = Join-Path $HumanCopyRoot $native
            $digest = Get-Sha256Hex $stagedPath
            [void]$lines.Add("$digest  $target")
        }
        Set-Content -LiteralPath (Join-Path $HumanCopyRoot 'MANIFEST.sha256') -Value ($lines -join "`n") -NoNewline
    }
    if (-not $SkipRunnerCopy) {
        Copy-Item -LiteralPath $RunnerPath -Destination (Join-Path $HumanCopyRoot 'apply-protected-files.ps1') -Force
    }
}

function Invoke-RunnerProcess([string]$Root) {
    # Out-of-process invocation: exercises the real CLI entry point
    # (auto-execute path), not just the dot-sourced functions.
    $powerShell = (Get-Process -Id $PID).Path
    $output = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $RunnerPath -RepositoryRoot $Root 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

function New-DefaultContentMap {
    $map = [ordered]@{}
    foreach ($target in $DeclaredTargets) { $map[$target] = "staged-payload: $target" }
    return $map
}

function Test-AllLiveFilesOriginal {
    param([Parameter(Mandatory)][string]$Root)
    foreach ($target in $DeclaredTargets) {
        $path = Join-Path $Root ($target -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        if ((Get-Content -LiteralPath $path -Raw) -ne "live-original: $target") { return $false }
    }
    return $true
}

$TempRoots = New-Object System.Collections.Generic.List[string]
function Register-TempRoot([string]$Path) { [void]$TempRoots.Add($Path) }

try {

# ===========================================================================
# TEST-001a/b: correct four-target payload copies cleanly; post-copy hashes
# match every installed file (contract points 1-4, happy path).
# ===========================================================================
Write-Host '=== TEST-001: correct payload copies cleanly, post-copy verified ==='
$root1 = New-TempRoot
Register-TempRoot $root1
$hc1 = New-RepoFixture $root1
$map1 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc1 -ContentMap $map1
$result1 = Invoke-RunnerProcess $root1
if ($result1.ExitCode -eq 0) { Ok "TEST-001a: correct payload exits 0" } else { Bad "TEST-001a: correct payload should exit 0, got $($result1.ExitCode). Output: $($result1.Output)" }
$allInstalled = $true
foreach ($target in $DeclaredTargets) {
    $native = $target -replace '/', [IO.Path]::DirectorySeparatorChar
    $installed = Join-Path $root1 $native
    $expected = "staged-payload: $target"
    $actual = Get-Content -LiteralPath $installed -Raw
    if ($actual -ne $expected) { $allInstalled = $false }
}
if ($allInstalled) { Ok "TEST-001b: every target's installed content matches the staged payload" } else { Bad "TEST-001b: installed content did not match staged payload for at least one target" }

# ===========================================================================
# TEST-002: an undeclared fifth payload path is rejected BEFORE any copy.
# ===========================================================================
Write-Host '=== TEST-002: undeclared fifth payload path rejected before copy ==='
$root2 = New-TempRoot
Register-TempRoot $root2
$hc2 = New-RepoFixture $root2
$map2 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc2 -ContentMap $map2
# Stage an undeclared fifth path (not in DeclaredTargets, not a control file).
$extraTarget = [string]$FixtureCatalog.scenarios.undeclared_payload.extra_payload
$extraPath = Join-Path $hc2 ($extraTarget -replace '/', [IO.Path]::DirectorySeparatorChar)
New-Item -ItemType Directory -Path (Split-Path -Parent $extraPath) -Force | Out-Null
Set-Content -LiteralPath $extraPath -Value 'undeclared payload' -NoNewline
$result2 = Invoke-RunnerProcess $root2
if ($result2.ExitCode -ne 0) { Ok "TEST-002a: undeclared fifth path rejected (exit $($result2.ExitCode))" } else { Bad "TEST-002a: undeclared fifth path should be rejected, got exit 0" }
if (Test-AllLiveFilesOriginal $root2) { Ok "TEST-002b: no copy occurred before rejection (all four live files unchanged)" } else { Bad "TEST-002b: at least one live file changed before undeclared-payload rejection" }

# The manifest's own set is an independent member of the three-way equality.
# An otherwise well-formed manifest-only fifth target must also be rejected.
$root2c = New-TempRoot
Register-TempRoot $root2c
$hc2c = New-RepoFixture $root2c
$map2c = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc2c -ContentMap $map2c
$manifest2c = Join-Path $hc2c 'MANIFEST.sha256'
$manifestExtra2c = [string]$FixtureCatalog.scenarios.manifest_extra_target.extra_target
Add-Content -LiteralPath $manifest2c -Value "`n$('0' * 64)  $manifestExtra2c" -NoNewline
$result2c = Invoke-RunnerProcess $root2c
if ($result2c.ExitCode -ne 0 -and $result2c.Output.Contains('MANIFEST.sha256 declares an undeclared target')) { Ok 'TEST-002c: manifest-only fifth target is rejected by the declared/manifest exact-set check' } else { Bad "TEST-002c: manifest-only fifth target was not rejected precisely. Output: $($result2c.Output)" }
if (Test-AllLiveFilesOriginal $root2c) { Ok 'TEST-002d: manifest-extra rejection occurs before every live copy' } else { Bad 'TEST-002d: a live target changed before manifest-extra rejection' }

# ===========================================================================
# TEST-003: a payload missing one of the four declared targets is rejected
# BEFORE any copy.
# ===========================================================================
Write-Host '=== TEST-003: missing declared target rejected before copy ==='
$root3 = New-TempRoot
Register-TempRoot $root3
$hc3 = New-RepoFixture $root3
$map3 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc3 -ContentMap $map3
$missingPayloadTarget3 = [string]$FixtureCatalog.scenarios.missing_payload.omit_target
Remove-Item -LiteralPath (Join-Path $hc3 ($missingPayloadTarget3 -replace '/', [IO.Path]::DirectorySeparatorChar)) -Force
$result3 = Invoke-RunnerProcess $root3
if ($result3.ExitCode -ne 0) { Ok "TEST-003a: missing declared target rejected (exit $($result3.ExitCode))" } else { Bad "TEST-003a: missing declared target should be rejected, got exit 0" }
if ($result3.Output.Contains('staged payload is missing a declared target')) { Ok 'TEST-003b: rejection is specifically the payload-vs-declared exact-set mismatch' } else { Bad "TEST-003b: expected missing staged payload diagnostic. Output: $($result3.Output)" }
if (Test-AllLiveFilesOriginal $root3) { Ok "TEST-003c: no copy occurred before rejection (all four live files unchanged)" } else { Bad "TEST-003c: at least one live file changed before missing-payload rejection" }

$root3d = New-TempRoot
Register-TempRoot $root3d
$hc3d = New-RepoFixture $root3d
$map3d = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc3d -ContentMap $map3d
$manifest3d = Join-Path $hc3d 'MANIFEST.sha256'
$manifestMissing3d = [string]$FixtureCatalog.scenarios.manifest_missing_target.omit_target
$remainingManifest3d = @((Get-Content -LiteralPath $manifest3d) | Where-Object { -not $_.EndsWith("  $manifestMissing3d", [StringComparison]::Ordinal) })
Set-Content -LiteralPath $manifest3d -Value ($remainingManifest3d -join "`n") -NoNewline
$result3d = Invoke-RunnerProcess $root3d
if ($result3d.ExitCode -ne 0 -and $result3d.Output.Contains('MANIFEST.sha256 is missing a declared target')) { Ok 'TEST-003d: manifest missing one declared target is rejected by the declared/manifest exact-set check' } else { Bad "TEST-003d: manifest omission was not rejected precisely. Output: $($result3d.Output)" }
if (Test-AllLiveFilesOriginal $root3d) { Ok 'TEST-003e: manifest-missing rejection occurs before every live copy' } else { Bad 'TEST-003e: a live target changed before manifest-missing rejection' }

# ===========================================================================
# TEST-004: a per-target hash mismatch against MANIFEST.sha256 is rejected
# BEFORE any copy.
# ===========================================================================
Write-Host '=== TEST-004: per-target hash mismatch rejected before copy ==='
$root4 = New-TempRoot
Register-TempRoot $root4
$hc4 = New-RepoFixture $root4
$map4 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc4 -ContentMap $map4
# Corrupt one staged payload file AFTER the manifest was written from the
# original content, so its hash no longer matches MANIFEST.sha256.
$corruptTarget = [string]$FixtureCatalog.scenarios.hash_mismatch.tamper_after_manifest
$corruptPath = Join-Path $hc4 ($corruptTarget -replace '/', [IO.Path]::DirectorySeparatorChar)
Set-Content -LiteralPath $corruptPath -Value 'tampered-after-manifest' -NoNewline
$result4 = Invoke-RunnerProcess $root4
if ($result4.ExitCode -ne 0) { Ok "TEST-004a: staged hash mismatch rejected (exit $($result4.ExitCode))" } else { Bad "TEST-004a: staged hash mismatch should be rejected, got exit 0" }
if (Test-AllLiveFilesOriginal $root4) { Ok "TEST-004b: no copy occurred before rejection (all four live files unchanged)" } else { Bad "TEST-004b: at least one live file changed before hash-mismatch rejection" }

# ===========================================================================
# TEST-005: control files (MANIFEST.sha256, the runner script itself) are
# excluded from the payload-set comparison by construction, never flagged
# as extraneous.
# ===========================================================================
Write-Host '=== TEST-005: control files excluded from payload-set comparison ==='
$root5 = New-TempRoot
Register-TempRoot $root5
$hc5 = New-RepoFixture $root5
$map5 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc5 -ContentMap $map5
. $RunnerPath
$payloadSet5 = Get-PayloadFileSet $hc5
$controlFiles = @($FixtureCatalog.scenarios.control_files.control_files)
if (($payloadSet5 -contains $controlFiles[0])) { Bad "TEST-005a: $($controlFiles[0]) must be excluded from the payload set, but it was included" } else { Ok "TEST-005a: $($controlFiles[0]) correctly excluded from the payload set" }
if (($payloadSet5 -contains $controlFiles[1])) { Bad "TEST-005b: $($controlFiles[1]) must be excluded from the payload set, but it was included" } else { Ok "TEST-005b: $($controlFiles[1]) correctly excluded from the payload set" }
$expectedSorted = @($DeclaredTargets | Sort-Object)
$actualSorted = @($payloadSet5 | Sort-Object)
$same = ($expectedSorted.Count -eq $actualSorted.Count)
if ($same) { for ($i = 0; $i -lt $expectedSorted.Count; $i++) { if ($expectedSorted[$i] -ne $actualSorted[$i]) { $same = $false; break } } }
if ($same) { Ok "TEST-005c: payload set == exactly the four declared targets, control files excluded" } else { Bad "TEST-005c: payload set should equal exactly the four declared targets. Got: $($actualSorted -join ', ')" }
# And the well-formed fixture (which stages both control files) still
# passes the runner end-to-end -- proving they don't trip the exact-set
# check as "extraneous".
$result5 = Invoke-RunnerProcess $root5
if ($result5.ExitCode -eq 0) { Ok "TEST-005d: a fixture with both control files present still passes (not flagged extraneous)" } else { Bad "TEST-005d: control files present should not cause rejection, got exit $($result5.ExitCode). Output: $($result5.Output)" }

# ===========================================================================
# TEST-006: a simulated post-copy corruption is detected and reported, not
# silently accepted.
# ===========================================================================
Write-Host '=== TEST-006: post-copy corruption detected and reported ==='
$root6 = New-TempRoot
Register-TempRoot $root6
$hc6 = New-RepoFixture $root6
$map6 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc6 -ContentMap $map6
. $RunnerPath
$manifestDigests6 = Get-ManifestTargets (Join-Path $hc6 'MANIFEST.sha256')
Copy-Payload $root6 $hc6 $DeclaredTargets
# Simulate corruption: mutate one just-installed live file's bytes so its
# hash no longer matches the manifest (this happens strictly AFTER
# Copy-Payload, i.e. after the bytes already "landed").
$postCopyTarget = [string]$FixtureCatalog.scenarios.post_copy_corruption.corrupt_after_copy
$corruptedLive = Join-Path $root6 ($postCopyTarget -replace '/', [IO.Path]::DirectorySeparatorChar)
Set-Content -LiteralPath $corruptedLive -Value 'corrupted-post-copy' -NoNewline
$caught = $false
$caughtMessage = ''
try {
    Test-PostCopyHashes $root6 $DeclaredTargets $manifestDigests6
} catch {
    $caught = $true
    $caughtMessage = $_.Exception.Message
}
if ($caught) { Ok "TEST-006a: post-copy corruption is detected (Test-PostCopyHashes threw)" } else { Bad "TEST-006a: post-copy corruption should have been detected, but Test-PostCopyHashes did not throw" }
if ($caughtMessage -match 'post-copy re-verification FAILED') { Ok "TEST-006b: failure message names post-copy re-verification" } else { Bad "TEST-006b: failure message should name post-copy re-verification. Got: $caughtMessage" }
if ($caughtMessage -match [regex]::Escape($postCopyTarget)) { Ok "TEST-006c: failure message names the corrupted target" } else { Bad "TEST-006c: failure message should name the corrupted target ($postCopyTarget). Got: $caughtMessage" }

# Exercise the real CLI sequence too: patch only the explicit post-copy test
# seam, corrupt one installed target, then require the CLI's own invocation of
# Test-PostCopyHashes to reject and diagnose it.
$patchRoot6 = New-TempRoot
Register-TempRoot $patchRoot6
$patchedRunner6 = Join-Path $patchRoot6 'apply-protected-files.ps1'
$runnerText6 = Get-Content -LiteralPath $RunnerPath -Raw
$afterCopySeam6 = '# TEST_FIXTURE_AFTER_COPY'
$afterCopyInjection6 = @'
$fixturePostCopyTarget = 'plugins/sdd-lite/scripts/check-risk-upgrade.sh'
Set-Content -LiteralPath (Join-Path $repoRoot ($fixturePostCopyTarget -replace '/', [IO.Path]::DirectorySeparatorChar)) -Value 'fixture-post-copy-corruption' -NoNewline
'@
if ($runnerText6.Contains($afterCopySeam6)) { $runnerText6 = $runnerText6.Replace($afterCopySeam6, $afterCopyInjection6) } else { Bad 'TEST-006d: runner has no explicit after-copy test seam' }
Set-Content -LiteralPath $patchedRunner6 -Value $runnerText6 -NoNewline
$root6d = New-TempRoot
Register-TempRoot $root6d
$savedRunnerPath6 = $RunnerPath
try {
    $RunnerPath = $patchedRunner6
    $hc6d = New-RepoFixture $root6d
    $map6d = New-DefaultContentMap
    Write-StagedPayload -HumanCopyRoot $hc6d -ContentMap $map6d
    $result6d = Invoke-RunnerProcess $root6d
} finally {
    $RunnerPath = $savedRunnerPath6
}
if ($result6d.ExitCode -ne 0) { Ok 'TEST-006d: real CLI rejects corruption injected after Copy-Payload' } else { Bad 'TEST-006d: real CLI silently accepted post-copy corruption' }
if ($result6d.Output.Contains('post-copy re-verification FAILED')) { Ok 'TEST-006e: real CLI invokes and reports post-copy re-verification' } else { Bad "TEST-006e: real CLI output lacks post-copy re-verification diagnostic. Output: $($result6d.Output)" }
if ($result6d.Output.Contains('plugins/sdd-lite/scripts/check-risk-upgrade.sh')) { Ok 'TEST-006f: real CLI diagnostic names the corrupted installed target' } else { Bad "TEST-006f: real CLI diagnostic omits corrupted target. Output: $($result6d.Output)" }

# ===========================================================================
# TEST-007: feature-scoped resolution -- the runner reads targets/digests
# from THIS feature's own human-copy prefix only, never the Epic-136
# prefix.
# ===========================================================================
Write-Host '=== TEST-007: feature-scoped, not fixed-prefix, resolution ==='
$root7 = New-TempRoot
Register-TempRoot $root7
$hc7 = New-RepoFixture $root7
$map7 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc7 -ContentMap $map7
# Also create an Epic-136-shaped prefix under the same fixture root with a
# DIFFERENT (invalid) payload; if the runner were fixed-prefix, this would
# either be read instead of / in addition to the real one, or cause an
# unrelated failure. It must be fully ignored.
$foreignPrefix = Join-Path $root7 ([string]$FixtureCatalog.scenarios.feature_scope.foreign_prefix -replace '/', [IO.Path]::DirectorySeparatorChar)
New-Item -ItemType Directory -Path $foreignPrefix -Force | Out-Null
Set-Content -LiteralPath (Join-Path $foreignPrefix 'MANIFEST.sha256') -Value ([string]$FixtureCatalog.scenarios.feature_scope.foreign_manifest) -NoNewline
$result7 = Invoke-RunnerProcess $root7
if ($result7.ExitCode -eq 0) { Ok "TEST-007: runner succeeds reading only its own feature-scoped prefix, ignoring an unrelated foreign prefix" } else { Bad "TEST-007: runner should have succeeded using only its own prefix, got exit $($result7.ExitCode). Output: $($result7.Output)" }

if ($SecurityRegression -in @('all', 'case-sensitive')) {
# ===========================================================================
# TEST-008: control names and digest text are Ordinal/case-sensitive.
# A mis-cased control is payload and therefore extraneous; an uppercase
# digest is malformed rather than equivalent to the canonical lowercase form.
# ===========================================================================
Write-Host '=== TEST-008: case-sensitive control names and digest grammar ==='
$root8a = New-TempRoot
Register-TempRoot $root8a
$hc8a = New-RepoFixture $root8a
$map8a = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc8a -ContentMap $map8a
$misCasedControl = [string]$FixtureCatalog.scenarios.case_sensitive_control_and_digest.mis_cased_control
. $RunnerPath
$controlHelperPresent = $null -ne (Get-Command Test-IsControlRelativePath -ErrorAction SilentlyContinue)
if ($controlHelperPresent -and -not (Test-IsControlRelativePath $misCasedControl)) { Ok 'TEST-008a: a mis-cased control filename is not classified as a control path' } else { Bad "TEST-008a: case-sensitive control classifier missing or incorrectly accepted $misCasedControl" }
$canonicalManifest8a = Join-Path $hc8a 'MANIFEST.sha256'
$validManifest8a = Get-Content -LiteralPath $canonicalManifest8a -Raw
Remove-Item -LiteralPath $canonicalManifest8a -Force
$misCasedControlPath = Join-Path $hc8a $misCasedControl
Set-Content -LiteralPath $misCasedControlPath -Value $validManifest8a -NoNewline
$result8a = Invoke-RunnerProcess $root8a
if ($result8a.ExitCode -ne 0) { Ok 'TEST-008b: real CLI rejects a mis-cased control name as undeclared payload' } else { Bad 'TEST-008b: real CLI incorrectly ignored a mis-cased control filename' }
if ($result8a.Output.Contains('staged payload contains an undeclared path')) { Ok 'TEST-008c: mis-cased control rejection identifies the exact-set violation' } else { Bad "TEST-008c: mis-cased control rejection lacks the expected exact-set diagnostic. Output: $($result8a.Output)" }
if (Test-AllLiveFilesOriginal $root8a) { Ok 'TEST-008d: mis-cased control rejection occurs before every live copy' } else { Bad 'TEST-008d: a live target changed before mis-cased control rejection' }

$root8b = New-TempRoot
Register-TempRoot $root8b
$hc8b = New-RepoFixture $root8b
$map8b = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc8b -ContentMap $map8b
$manifest8b = Join-Path $hc8b 'MANIFEST.sha256'
$uppercaseManifest = ((Get-Content -LiteralPath $manifest8b -Raw) -split "`n" | ForEach-Object {
    if ($_.Length -ge 64) { $_.Substring(0, 64).ToUpperInvariant() + $_.Substring(64) } else { $_ }
}) -join "`n"
Set-Content -LiteralPath $manifest8b -Value $uppercaseManifest -NoNewline
$result8b = Invoke-RunnerProcess $root8b
if ($result8b.ExitCode -ne 0) { Ok 'TEST-008e: uppercase digest text is rejected by the canonical lowercase manifest grammar' } else { Bad 'TEST-008e: uppercase digest text was incorrectly accepted as equal to lowercase SHA-256' }
if ($result8b.Output.Contains('lowercase two-space sha256 format')) { Ok 'TEST-008f: uppercase digest rejection identifies the canonical lowercase grammar' } else { Bad "TEST-008f: uppercase digest rejection lacks the expected diagnostic. Output: $($result8b.Output)" }
if (Test-AllLiveFilesOriginal $root8b) { Ok 'TEST-008g: uppercase digest rejection occurs before every live copy' } else { Bad 'TEST-008g: a live target changed before uppercase digest rejection' }
}

if ($SecurityRegression -in @('all', 'ancestor-symlink')) {
# ===========================================================================
# TEST-009: every existing ancestor is checked for symlinks/reparse points,
# and normalized candidates remain canonically contained by repository root.
# ===========================================================================
Write-Host '=== TEST-009: ancestor symlink escape rejected before copy ==='
$root9 = New-TempRoot
Register-TempRoot $root9
$hc9 = New-RepoFixture $root9
$map9 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc9 -ContentMap $map9
$outside9 = New-TempRoot
Register-TempRoot $outside9
$outsidePlugins = Join-Path $outside9 'plugins'
Move-Item -LiteralPath (Join-Path $root9 'plugins') -Destination $outsidePlugins
$linkKind = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
New-Item -ItemType $linkKind -Path (Join-Path $root9 'plugins') -Target $outsidePlugins | Out-Null
$escapedTarget = [string]$FixtureCatalog.scenarios.ancestor_symlink_escape.target
$escapedLive = Join-Path $outside9 ($escapedTarget -replace '^plugins/', ('plugins' + [IO.Path]::DirectorySeparatorChar) -replace '/', [IO.Path]::DirectorySeparatorChar)
$escapedBefore = Get-Content -LiteralPath $escapedLive -Raw
$result9 = Invoke-RunnerProcess $root9
if ($result9.ExitCode -ne 0) { Ok 'TEST-009a: destination ancestor symlink/reparse point is rejected' } else { Bad 'TEST-009a: runner followed an ancestor symlink/reparse point outside the repository' }
$escapedAfter = Get-Content -LiteralPath $escapedLive -Raw
if ([string]::Equals($escapedBefore, $escapedAfter, [StringComparison]::Ordinal)) { Ok 'TEST-009b: escaped external target remains byte-identical (rejection occurred before copy)' } else { Bad 'TEST-009b: external target was modified through the ancestor link' }
$containmentMessage = ''
try {
    Assert-AnchoredPath -Root $root9 -Candidate (Join-Path $root9 '../canonical-escape') -Label 'canonical containment fixture' -AllowMissingLeaf | Out-Null
} catch {
    $containmentMessage = $_.Exception.Message
}
if ($containmentMessage.Contains('escapes canonical root')) { Ok 'TEST-009c: lexical/canonical parent traversal outside the repository is rejected' } else { Bad "TEST-009c: canonical containment rejection missing. Got: $containmentMessage" }

# Deterministic TOCTOU regression: patch a disposable runner copy at the
# native directory-open seam. The fixture substitutes the first destination
# segment after the parent handle is held but immediately before the platform's
# handle-relative open. O_NOFOLLOW / FILE_OPEN_REPARSE_POINT must reject that
# exact lookup; a path-based check-then-open would follow the replacement link.
$patchRoot9 = New-TempRoot
Register-TempRoot $patchRoot9
$patchedRunner9 = Join-Path $patchRoot9 'apply-protected-files.ps1'
$runnerText9 = Get-Content -LiteralPath $RunnerPath -Raw
$nativeSeam9 = if ($IsWindows) { '// TEST_FIXTURE_BEFORE_DIRECTORY_OPEN_WINDOWS' } else { '// TEST_FIXTURE_BEFORE_POSIX_DIRECTORY_OPEN' }
$substitution9 = if ($IsWindows) { @'
if (fixtureDestination && parts[i] == "plugins" && !String.IsNullOrEmpty(Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_LINK"))) {
    Directory.Move(Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_ORIGINAL"), Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_MOVED"));
    Directory.Move(Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_LINK"), Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_ORIGINAL"));
    File.WriteAllText(Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_MARKER"), "executed");
}
'@ } else { @'
if (fixtureDestination && segment == "plugins" && !String.IsNullOrEmpty(Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_TARGET"))) {
    if (renameat(Fd(current), segment, Fd(current), segment + ".fixture-moved") != 0) ThrowUnix("fixture rename destination segment");
    if (symlinkat(Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_TARGET"), Fd(current), segment) != 0) ThrowUnix("fixture substitute destination segment");
    File.WriteAllText(Environment.GetEnvironmentVariable("SDD_A6_PARENT_SUBSTITUTION_MARKER"), "executed");
}
'@ }
if ($runnerText9.Contains($nativeSeam9)) {
    $runnerText9 = $runnerText9.Replace($nativeSeam9, $substitution9)
} else {
    Bad 'TEST-009d: runner has no deterministic parent-substitution test seam'
}
Set-Content -LiteralPath $patchedRunner9 -Value $runnerText9 -NoNewline

$root9d = New-TempRoot
Register-TempRoot $root9d
$outside9d = New-TempRoot
Register-TempRoot $outside9d
$externalPlugins9d = Join-Path $outside9d 'plugins'
$externalTarget9d = Join-Path $externalPlugins9d 'sdd-lite/references/risk-upgrade-policy.md'
New-Item -ItemType Directory -Path (Split-Path -Parent $externalTarget9d) -Force | Out-Null
Set-Content -LiteralPath $externalTarget9d -Value 'external-canary-before-substitution' -NoNewline
$substitutionMarker9d = Join-Path $outside9d 'substitution-executed.marker'
$savedRunnerPath9 = $RunnerPath
$savedSubstitutionTarget9 = $env:SDD_A6_PARENT_SUBSTITUTION_TARGET
$savedSubstitutionMarker9 = $env:SDD_A6_PARENT_SUBSTITUTION_MARKER
$savedSubstitutionOriginal9 = $env:SDD_A6_PARENT_SUBSTITUTION_ORIGINAL
$savedSubstitutionMoved9 = $env:SDD_A6_PARENT_SUBSTITUTION_MOVED
$savedSubstitutionLink9 = $env:SDD_A6_PARENT_SUBSTITUTION_LINK
try {
    $RunnerPath = $patchedRunner9
    $env:SDD_A6_PARENT_SUBSTITUTION_TARGET = $externalPlugins9d
    $env:SDD_A6_PARENT_SUBSTITUTION_MARKER = $substitutionMarker9d
    $hc9d = New-RepoFixture $root9d
    $map9d = New-DefaultContentMap
    Write-StagedPayload -HumanCopyRoot $hc9d -ContentMap $map9d
    if ($IsWindows) {
        $originalPlugins9d = Join-Path $root9d 'plugins'
        $movedPlugins9d = Join-Path $root9d 'plugins.fixture-moved'
        $preparedLink9d = Join-Path $root9d 'plugins.fixture-link'
        New-Item -ItemType Junction -Path $preparedLink9d -Target $externalPlugins9d | Out-Null
        $env:SDD_A6_PARENT_SUBSTITUTION_ORIGINAL = $originalPlugins9d
        $env:SDD_A6_PARENT_SUBSTITUTION_MOVED = $movedPlugins9d
        $env:SDD_A6_PARENT_SUBSTITUTION_LINK = $preparedLink9d
    }
    $result9d = Invoke-RunnerProcess $root9d
} finally {
    $RunnerPath = $savedRunnerPath9
    if ($null -eq $savedSubstitutionTarget9) { Remove-Item Env:SDD_A6_PARENT_SUBSTITUTION_TARGET -ErrorAction SilentlyContinue } else { $env:SDD_A6_PARENT_SUBSTITUTION_TARGET = $savedSubstitutionTarget9 }
    if ($null -eq $savedSubstitutionMarker9) { Remove-Item Env:SDD_A6_PARENT_SUBSTITUTION_MARKER -ErrorAction SilentlyContinue } else { $env:SDD_A6_PARENT_SUBSTITUTION_MARKER = $savedSubstitutionMarker9 }
    if ($null -eq $savedSubstitutionOriginal9) { Remove-Item Env:SDD_A6_PARENT_SUBSTITUTION_ORIGINAL -ErrorAction SilentlyContinue } else { $env:SDD_A6_PARENT_SUBSTITUTION_ORIGINAL = $savedSubstitutionOriginal9 }
    if ($null -eq $savedSubstitutionMoved9) { Remove-Item Env:SDD_A6_PARENT_SUBSTITUTION_MOVED -ErrorAction SilentlyContinue } else { $env:SDD_A6_PARENT_SUBSTITUTION_MOVED = $savedSubstitutionMoved9 }
    if ($null -eq $savedSubstitutionLink9) { Remove-Item Env:SDD_A6_PARENT_SUBSTITUTION_LINK -ErrorAction SilentlyContinue } else { $env:SDD_A6_PARENT_SUBSTITUTION_LINK = $savedSubstitutionLink9 }
}
if (Test-Path -LiteralPath $substitutionMarker9d -PathType Leaf) { Ok 'TEST-009d: deterministic substitution seam executed' } else { Bad "TEST-009d: substitution seam did not execute; Green would be inconclusive. Runner output=$($result9d.Output)" }
if ($result9d.ExitCode -ne 0 -and $result9d.Output.Contains('symlink/reparse-point ancestor')) { Ok 'TEST-009e: atomic no-follow directory open explicitly rejected the substituted ancestor' } else { Bad "TEST-009e: runner did not explicitly reject the substituted ancestor. Exit=$($result9d.ExitCode), output=$($result9d.Output)" }
if ((Get-Content -LiteralPath $externalTarget9d -Raw) -eq 'external-canary-before-substitution') { Ok 'TEST-009f: substituted external target remains byte-identical' } else { Bad 'TEST-009f: substituted external target was overwritten' }
$movedLive9d = Join-Path $root9d 'plugins.fixture-moved/sdd-lite/references/risk-upgrade-policy.md'
if ((Test-Path -LiteralPath $movedLive9d -PathType Leaf) -and (Get-Content -LiteralPath $movedLive9d -Raw) -eq 'live-original: plugins/sdd-lite/references/risk-upgrade-policy.md') { Ok 'TEST-009g: repository live target remains byte-identical after the rejected race' } else { Bad 'TEST-009g: repository live target changed during the rejected race or the seam never moved its parent' }
}

if ($SecurityRegression -in @('all', 'nested-proposed')) {
# ===========================================================================
# TEST-010: recursive payload enumeration and exact-set semantics agree.
# PROPOSED/ is not a control subtree, so any nested file is rejected with an
# explicit reserved-subtree diagnostic before a live target changes.
# ===========================================================================
Write-Host '=== TEST-010: nested PROPOSED subtree rejected explicitly ==='
$root10 = New-TempRoot
Register-TempRoot $root10
$hc10 = New-RepoFixture $root10
$map10 = New-DefaultContentMap
Write-StagedPayload -HumanCopyRoot $hc10 -ContentMap $map10
$nestedProposed = [string]$FixtureCatalog.scenarios.nested_proposed.path
$nestedProposedPath = Join-Path $hc10 ($nestedProposed -replace '/', [IO.Path]::DirectorySeparatorChar)
New-Item -ItemType Directory -Path (Split-Path -Parent $nestedProposedPath) -Force | Out-Null
Set-Content -LiteralPath $nestedProposedPath -Value 'not-an-ignored-control-file' -NoNewline
$result10 = Invoke-RunnerProcess $root10
if ($result10.ExitCode -ne 0) { Ok 'TEST-010a: nested PROPOSED payload is rejected' } else { Bad 'TEST-010a: nested PROPOSED payload was incorrectly accepted or ignored' }
if ($result10.Output.Contains('reserved PROPOSED/ subtree')) { Ok 'TEST-010b: rejection explicitly identifies the recursive PROPOSED/ incompatibility' } else { Bad "TEST-010b: expected reserved PROPOSED/ subtree diagnostic. Output: $($result10.Output)" }
if (Test-AllLiveFilesOriginal $root10) { Ok 'TEST-010c: all four live targets remain unchanged before nested PROPOSED rejection' } else { Bad 'TEST-010c: at least one live target changed before nested PROPOSED rejection' }
}

} finally {
    foreach ($root in $TempRoots) {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
