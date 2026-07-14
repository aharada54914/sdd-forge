# loop-driver.tests.ps1 - PowerShell twin of loop-driver.tests.sh, coverage
# adapted for one confirmed upstream gap (T-002 / Issue #142 /
# epic-159-pillar-a REQ-002): spec-review-precheck.ps1 does not exist
# anywhere in this repository (only the .sh form exists; verified during
# this task -- see this task's implementation report). TEST-006's
# spec-review-driving assertions therefore emit a named SKIP on this lane,
# mirroring the already-established domain-review-precheck.ps1 degradation
# pattern (investigation.md INV-022, requirements.md Edge Cases). TEST-005,
# TEST-007, and TEST-017 do not depend on that script and run unconditionally
# on both lanes. See tests/loop-driver.tests.sh for the full checklist
# description.
$ErrorActionPreference = "Stop"

$startEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot "tests/lib/loop-driver.ps1")

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$jqCmd = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jqCmd) {
    Write-Output "FAIL: jq is required"
    exit 1
}

$cleanupRoots = New-Object System.Collections.Generic.List[string]
try {

# ---------------------------------------------------------------------------
# TEST-005 (AC-005): Initialize-LoopFixture - greenfield + brownfield
# ---------------------------------------------------------------------------
Write-Output "=== TEST-005: loop_fixture_init (greenfield + brownfield) ==="

$featureGf = "loop-driver-smoke-gf-$PID"
if (Initialize-LoopFixture -Profile "greenfield" -Feature $featureGf) {
    Ok "TEST-005.1: loop_fixture_init greenfield succeeds"
    $cleanupRoots.Add($script:LoopFixtureRoot)
} else {
    Fail "TEST-005.1: loop_fixture_init greenfield failed"
}
$gfRoot = $script:LoopFixtureRoot

if ($gfRoot -and $gfRoot -ne $repoRoot -and -not $gfRoot.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar)) {
    Ok "TEST-005.2: greenfield fixture root ($gfRoot) lies outside the repository working tree"
} else {
    Fail "TEST-005.2: greenfield fixture root resolves inside the repository working tree or was not set"
}

$ledger = Join-Path $gfRoot "reports/review-context/identity-ledger.json"
$ledgerOk = $false
if (Test-Path -LiteralPath $ledger) {
    $schemaOk = Invoke-LoopJq @("-r", '.schema == "review-identity-ledger/v1" and (.records | length) == 1') $ledger
    $ledgerOk = ($schemaOk -eq "true")
}
if ($ledgerOk) {
    Ok "TEST-005.3: greenfield genesis identity-ledger has exactly one well-formed record"
} else {
    Fail "TEST-005.3: greenfield genesis identity-ledger is missing or malformed"
}

$genesisExpected = Get-LoopSha256Text "1|genesis|loop-driver-fixture|fixture-genesis-run|fixture-genesis-session|"
$genesisActual = Invoke-LoopJq @("-r", '.records[0].record_sha256') $ledger
if ($genesisActual -and $genesisActual -eq $genesisExpected) {
    Ok "TEST-005.4: genesis record hash matches the canonical INV-006 formula (validate-review-context-set.ps1)"
} else {
    Fail "TEST-005.4: genesis record hash does not match the canonical INV-006 formula"
}

$realSpecReview = Join-Path $repoRoot "reports/spec-review/$featureGf"
$realSpecsDir = Join-Path $repoRoot "specs/$featureGf"
if (-not (Test-Path -LiteralPath $realSpecReview) -and -not (Test-Path -LiteralPath $realSpecsDir)) {
    Ok "TEST-005.5: loop_fixture_init writes no real repository path for the fixture feature"
} else {
    Fail "TEST-005.5: a real repository path was written for the fixture feature"
}

$seedRoot = Join-Path ([IO.Path]::GetTempPath()) ("loop-driver-seed." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $seedRoot | Out-Null
$cleanupRoots.Add($seedRoot)
$seedMarkerRel = "seed-marker-$PID.txt"
Set-Content -LiteralPath (Join-Path $seedRoot $seedMarkerRel) -Value "brownfield seed marker" -Encoding utf8

$featureBf = "loop-driver-smoke-bf-$PID"
$env:LOOP_FIXTURE_SEED = $seedRoot
if (Initialize-LoopFixture -Profile "brownfield" -Feature $featureBf) {
    Ok "TEST-005.6: loop_fixture_init brownfield succeeds"
    $cleanupRoots.Add($script:LoopFixtureRoot)
} else {
    Fail "TEST-005.6: loop_fixture_init brownfield failed"
}
$bfRoot = $script:LoopFixtureRoot
Remove-Item Env:\LOOP_FIXTURE_SEED -ErrorAction SilentlyContinue

if ($bfRoot -and (Test-Path -LiteralPath (Join-Path $bfRoot $seedMarkerRel))) {
    Ok "TEST-005.7: brownfield fixture copies the caller-supplied seed content"
} else {
    Fail "TEST-005.7: brownfield fixture does not contain the seed marker file"
}
$bfLedgerOk = $false
if ($bfRoot) {
    $bfCheck = Invoke-LoopJq @("-r", '.records | length == 1') (Join-Path $bfRoot "reports/review-context/identity-ledger.json")
    $bfLedgerOk = ($bfCheck -eq "true")
}
if ($bfLedgerOk) {
    Ok "TEST-005.8: brownfield fixture also synthesizes the genesis identity-ledger"
} else {
    Fail "TEST-005.8: brownfield fixture is missing the synthesized genesis identity-ledger"
}

if (Initialize-LoopFixture -Profile "bogus-profile" -Feature "loop-driver-smoke-neg-$PID" -ErrorAction SilentlyContinue) {
    Fail "TEST-005.9 (negative self-check): an unknown fixture profile did NOT fail loop_fixture_init"
} else {
    Ok "TEST-005.9 (negative self-check): an unknown fixture profile fails loop_fixture_init"
}

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): drive_review_round - spec-review rounds 1->3
# ---------------------------------------------------------------------------
Write-Output "=== TEST-006: drive_review_round (spec-review rounds 1->3) ==="

$specPrecheckPs1 = Join-Path $repoRoot "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1"
if (-not (Test-Path -LiteralPath $specPrecheckPs1)) {
    Write-Output "SKIP: TEST-006 spec-review-precheck.ps1 does not exist upstream at T-002 time (only the .sh form exists; verified finding, see this task's implementation report). This is a recorded degradation, not a loop-driver defect: Initialize-LoopFixture, Test-ArtifactsSchema, Test-LoopTerminal, and Test-RuntimeBudget are still exercised below (TEST-005/007/017)."
} else {
    $script:LoopFixtureRoot = $gfRoot
    $script:LoopFixtureFeature = $featureGf
    $env:LOOP_FIXTURE_ROOT = $gfRoot
    $env:LOOP_FIXTURE_FEATURE = $featureGf

    if (Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major") {
        Ok "TEST-006.1: drive_review_round spec attempt 1 round 1 (NEEDS_WORK/Major) succeeds"
    } else {
        Fail "TEST-006.1: drive_review_round spec attempt 1 round 1 (NEEDS_WORK/Major) failed"
    }
    $round1Dir = Join-Path $gfRoot "reports/spec-review/$featureGf/attempt-1/round-1"
    $round1Ok = $false
    if (Test-Path -LiteralPath (Join-Path $round1Dir "spec-review-contract.json")) {
        $v = Invoke-LoopJq @("-r", ".verdict") (Join-Path $round1Dir "spec-review-contract.json")
        $round1Ok = ($v -eq "NEEDS_WORK")
    }
    if ($round1Ok) {
        Ok "TEST-006.2: round-1 contract records verdict NEEDS_WORK"
    } else {
        Fail "TEST-006.2: round-1 contract is missing or does not record NEEDS_WORK"
    }

    if (Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major") {
        Ok "TEST-006.3: drive_review_round spec attempt 1 round 2 (NEEDS_WORK/Major) succeeds"
    } else {
        Fail "TEST-006.3: drive_review_round spec attempt 1 round 2 (NEEDS_WORK/Major) failed"
    }

    if (Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 3 -Verdict "PASS" -Severity "Minor") {
        Ok "TEST-006.4: drive_review_round spec attempt 1 round 3 (PASS/Minor) succeeds"
    } else {
        Fail "TEST-006.4: drive_review_round spec attempt 1 round 3 (PASS/Minor) failed"
    }
    $round3Dir = Join-Path $gfRoot "reports/spec-review/$featureGf/attempt-1/round-3"
    $round3Ok = $false
    if (Test-Path -LiteralPath (Join-Path $round3Dir "spec-review-contract.json")) {
        $v = Invoke-LoopJq @("-r", '.verdict == "PASS" and .warningCount == 1') (Join-Path $round3Dir "spec-review-contract.json")
        $round3Ok = ($v -eq "true")
    }
    if ($round3Ok) {
        Ok "TEST-006.5: round-3 contract records verdict PASS with warningCount 1 (Minor-only)"
    } else {
        Fail "TEST-006.5: round-3 contract does not record the Minor-only PASS shape"
    }

    if (Test-PriorRoundComplete -Stage "spec" -RoundDir $round1Dir) {
        Ok "TEST-006.6: assert_prior_round_complete recognizes round-1's genuine on-disk output set"
    } else {
        Fail "TEST-006.6: assert_prior_round_complete rejects round-1's genuine on-disk output set"
    }

    $incompleteDir = Join-Path ([IO.Path]::GetTempPath()) ("loop-driver-incomplete." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $incompleteDir | Out-Null
    $cleanupRoots.Add($incompleteDir)
    Get-ChildItem -LiteralPath $round1Dir -Filter "*.json" | Copy-Item -Destination $incompleteDir
    Remove-Item -LiteralPath (Join-Path $incompleteDir "spec-review-contract.json") -ErrorAction SilentlyContinue
    if (Test-PriorRoundComplete -Stage "spec" -RoundDir $incompleteDir) {
        Fail "TEST-006.7 (negative self-check): a manifest referencing a nonexistent artifact did NOT turn assert_prior_round_complete red"
    } else {
        Ok "TEST-006.7 (negative self-check): a manifest referencing a nonexistent artifact (missing spec-review-contract.json) turns assert_prior_round_complete red"
    }
}

# ---------------------------------------------------------------------------
# TEST-007 (AC-007): assert_artifacts_schema / assert_terminal
# ---------------------------------------------------------------------------
Write-Output "=== TEST-007: assert_artifacts_schema / assert_terminal ==="

$schemaDir = Join-Path ([IO.Path]::GetTempPath()) ("loop-driver-schema." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $schemaDir | Out-Null
$cleanupRoots.Add($schemaDir)
& jq -n '{schema:"spec-review-precheck/v1", feature:"loop-driver-schema-fixture", attempt:1, round:1}' |
    Set-Content -LiteralPath (Join-Path $schemaDir "precheck-result.json") -Encoding utf8
& jq -n '{schema:"spec-review-contract/v1", feature:"loop-driver-schema-fixture", attempt:1, round:1, verdict:"PASS"}' |
    Set-Content -LiteralPath (Join-Path $schemaDir "spec-review-contract.json") -Encoding utf8

if (Test-ArtifactsSchema -Dir $schemaDir) {
    Ok "TEST-007.1: assert_artifacts_schema passes on genuine, inventory-registered artifact schemas"
} else {
    Fail "TEST-007.1: assert_artifacts_schema failed on genuine, inventory-registered artifact schemas"
}

$mutatedDir = Join-Path ([IO.Path]::GetTempPath()) ("loop-driver-mutated." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $mutatedDir | Out-Null
$cleanupRoots.Add($mutatedDir)
Get-ChildItem -LiteralPath $schemaDir -Filter "*.json" | Copy-Item -Destination $mutatedDir
$mutatedPrecheck = Join-Path $mutatedDir "precheck-result.json"
(& jq '.schema = "bogus-schema/v1"' $mutatedPrecheck) | Set-Content -LiteralPath "$mutatedPrecheck.tmp" -Encoding utf8
Move-Item -LiteralPath "$mutatedPrecheck.tmp" -Destination $mutatedPrecheck -Force
if (Test-ArtifactsSchema -Dir $mutatedDir) {
    Fail "TEST-007.2 (negative self-check): a jq-mutated artifact schema did NOT turn assert_artifacts_schema red"
} else {
    Ok "TEST-007.2 (negative self-check): a jq-mutated artifact schema turns assert_artifacts_schema red"
}

if (Test-LoopTerminal -LoopId "spec-review" -Observed "PASS") {
    Ok "TEST-007.3: assert_terminal confirms spec-review's genuine PASS state matches the inventory"
} else {
    Fail "TEST-007.3: assert_terminal rejected spec-review's genuine PASS state"
}

if (Test-LoopTerminal -LoopId "spec-review" -Observed "BLOCKED") {
    Fail "TEST-007.4 (negative self-check): an end state contradicting the inventory did NOT turn assert_terminal red"
} else {
    Ok "TEST-007.4 (negative self-check): an end state contradicting the inventory (BLOCKED vs PASS) turns assert_terminal red"
}

# ---------------------------------------------------------------------------
# TEST-017 (AC-017): runtime budget
# ---------------------------------------------------------------------------
Write-Output "=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=$($script:LoopSuiteBudgetSeconds)) ==="

$syntheticPastEpoch = $startEpoch - 1
if (Test-RuntimeBudget -Start $syntheticPastEpoch -Budget 0) {
    Fail "TEST-017.1 (negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
} else {
    Ok "TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red"
}

$elapsedSeconds = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $startEpoch
if (Test-RuntimeBudget -Start $startEpoch) {
    Ok "TEST-017.2: suite completed within the $($script:LoopSuiteBudgetSeconds)s runtime budget"
} else {
    Fail "TEST-017.2: suite exceeded the $($script:LoopSuiteBudgetSeconds)s runtime budget"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Output ""
Write-Output "loop-driver.tests.ps1: $($script:passCount) passed, $($script:failCount) failed, ${elapsedSeconds}s elapsed"
if ($script:failCount -ne 0) { exit 1 }
exit 0

} finally {
    foreach ($d in $cleanupRoots) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
    }
}
