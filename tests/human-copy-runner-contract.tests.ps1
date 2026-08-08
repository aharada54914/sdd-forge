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
#
# CI-resilience (Global Constraints): no possibly-empty array expanded
# under strict mode without a guard; every mktemp-equivalent root is
# resolved to its full path immediately after creation; no suite drives a
# real validator/gate directly against this repository's own live
# protected files -- every fixture below is a disposable, isolated
# temporary repository-root tree.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$RunnerPath = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1'

$Script:Pass = 0
$Script:Fail = 0

function Ok([string]$Message) { Write-Host "ok: $Message"; $Script:Pass++ }
function Bad([string]$Message) { Write-Host "FAIL: $Message"; $Script:Fail++ }

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

$DeclaredTargets = @(
    'plugins/sdd-lite/references/risk-upgrade-policy.md',
    'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
    'plugins/sdd-lite/scripts/check-risk-upgrade.ps1',
    'plugins/sdd-lite/skills/lite-spec/SKILL.md'
)

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
$extraPath = Join-Path $hc2 ('plugins/sdd-lite/scripts/extra-undeclared.sh' -replace '/', [IO.Path]::DirectorySeparatorChar)
New-Item -ItemType Directory -Path (Split-Path -Parent $extraPath) -Force | Out-Null
Set-Content -LiteralPath $extraPath -Value 'undeclared payload' -NoNewline
$result2 = Invoke-RunnerProcess $root2
if ($result2.ExitCode -ne 0) { Ok "TEST-002a: undeclared fifth path rejected (exit $($result2.ExitCode))" } else { Bad "TEST-002a: undeclared fifth path should be rejected, got exit 0" }
$live2 = Join-Path $root2 ($DeclaredTargets[0] -replace '/', [IO.Path]::DirectorySeparatorChar)
$live2Content = Get-Content -LiteralPath $live2 -Raw
if ($live2Content -eq 'live-original: plugins/sdd-lite/references/risk-upgrade-policy.md') { Ok "TEST-002b: no copy occurred before rejection (live file unchanged)" } else { Bad "TEST-002b: a copy should NOT have occurred before rejection, live file was modified" }

# ===========================================================================
# TEST-003: a payload missing one of the four declared targets is rejected
# BEFORE any copy.
# ===========================================================================
Write-Host '=== TEST-003: missing declared target rejected before copy ==='
$root3 = New-TempRoot
Register-TempRoot $root3
$hc3 = New-RepoFixture $root3
$map3 = New-DefaultContentMap
$map3.Remove('plugins/sdd-lite/skills/lite-spec/SKILL.md')
Write-StagedPayload -HumanCopyRoot $hc3 -ContentMap $map3
$result3 = Invoke-RunnerProcess $root3
if ($result3.ExitCode -ne 0) { Ok "TEST-003a: missing declared target rejected (exit $($result3.ExitCode))" } else { Bad "TEST-003a: missing declared target should be rejected, got exit 0" }
$live3 = Join-Path $root3 ($DeclaredTargets[0] -replace '/', [IO.Path]::DirectorySeparatorChar)
$live3Content = Get-Content -LiteralPath $live3 -Raw
if ($live3Content -eq 'live-original: plugins/sdd-lite/references/risk-upgrade-policy.md') { Ok "TEST-003b: no copy occurred before rejection (live file unchanged)" } else { Bad "TEST-003b: a copy should NOT have occurred before rejection, live file was modified" }

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
$corruptTarget = 'plugins/sdd-lite/scripts/check-risk-upgrade.sh'
$corruptPath = Join-Path $hc4 ($corruptTarget -replace '/', [IO.Path]::DirectorySeparatorChar)
Set-Content -LiteralPath $corruptPath -Value 'tampered-after-manifest' -NoNewline
$result4 = Invoke-RunnerProcess $root4
if ($result4.ExitCode -ne 0) { Ok "TEST-004a: staged hash mismatch rejected (exit $($result4.ExitCode))" } else { Bad "TEST-004a: staged hash mismatch should be rejected, got exit 0" }
$live4 = Join-Path $root4 ($DeclaredTargets[0] -replace '/', [IO.Path]::DirectorySeparatorChar)
$live4Content = Get-Content -LiteralPath $live4 -Raw
if ($live4Content -eq 'live-original: plugins/sdd-lite/references/risk-upgrade-policy.md') { Ok "TEST-004b: no copy occurred before rejection (live file unchanged)" } else { Bad "TEST-004b: a copy should NOT have occurred before rejection, live file was modified" }

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
if (($payloadSet5 -contains 'MANIFEST.sha256')) { Bad "TEST-005a: MANIFEST.sha256 must be excluded from the payload set, but it was included" } else { Ok "TEST-005a: MANIFEST.sha256 correctly excluded from the payload set" }
if (($payloadSet5 -contains 'apply-protected-files.ps1')) { Bad "TEST-005b: the runner script must be excluded from the payload set, but it was included" } else { Ok "TEST-005b: runner script correctly excluded from the payload set" }
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
$corruptedLive = Join-Path $root6 ($DeclaredTargets[2] -replace '/', [IO.Path]::DirectorySeparatorChar)
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
if ($caughtMessage -match [regex]::Escape($DeclaredTargets[2])) { Ok "TEST-006c: failure message names the corrupted target" } else { Bad "TEST-006c: failure message should name the corrupted target ($($DeclaredTargets[2])). Got: $caughtMessage" }

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
$foreignPrefix = Join-Path $root7 'specs/epic-136-phase2-gates/human-copy'
New-Item -ItemType Directory -Path $foreignPrefix -Force | Out-Null
Set-Content -LiteralPath (Join-Path $foreignPrefix 'MANIFEST.sha256') -Value 'not-a-valid-manifest-at-all' -NoNewline
$result7 = Invoke-RunnerProcess $root7
if ($result7.ExitCode -eq 0) { Ok "TEST-007: runner succeeds reading only its own feature-scoped prefix, ignoring an unrelated foreign prefix" } else { Bad "TEST-007: runner should have succeeded using only its own prefix, got exit $($result7.ExitCode). Output: $($result7.Output)" }

} finally {
    foreach ($root in $TempRoots) {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
