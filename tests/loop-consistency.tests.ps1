# tests/loop-consistency.tests.ps1 - PowerShell twin of
# tests/loop-consistency.tests.sh, byte-equivalent in coverage where the
# upstream gate surfaces allow it (T-003 / Issue #143 / epic-159-pillar-a
# REQ-003). See the bash twin for full section-by-section rationale.
#
# Pwsh degradation (AC-015 recorded SKIP-with-reason): spec-review-precheck.ps1
# does not exist upstream (same gap T-002's tests/loop-driver.tests.ps1
# already names), and driving impl/task rounds requires a genuine on-disk
# spec-review PASS first (impl-review-precheck.ps1's own unconditional
# precondition), so the spec/impl/task legs of TEST-008/TEST-009 all
# transitively degrade to a named SKIP on this lane even though
# impl-review-precheck.ps1 and task-review-precheck.ps1 themselves exist.
# domain-review-precheck.ps1 is separately absent upstream (#147), degrading
# the domain leg independently. TEST-010 and TEST-017 do not depend on any
# precheck script (self-contained fixtures / pure timing) and run for real
# on both lanes.
#
# -Leg impl-round-2 (RED-differential single-leg mode, provided for
# cross-host parity with the bash twin): drives only spec prereqs + impl
# round 1 + impl round 2. On this lane it currently always fails at the
# spec prerequisite step (spec-review-precheck.ps1 absent), so it cannot
# exercise the pre-fix/post-fix INV-011 differential itself; the one-time
# recorded RED evidence is bash-only (design.md Test Strategy item 2).

param(
    [string]$Leg
)

$ErrorActionPreference = 'Stop'
$startEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
# The inventory registry is this suite's own lookup table, not one of the
# REAL gate scripts under differential test -- always read it from THIS
# checkout (HEAD) even when SDD_LOOP_REPO_ROOT points at a historical
# worktree.
$env:LOOP_INVENTORY_PATH = Join-Path $repoRoot "tests/loops/loop-inventory.json"
. (Join-Path $repoRoot "tests/lib/loop-driver.ps1")

$cleanupRoots = [System.Collections.Generic.List[string]]::new()
function Invoke-Cleanup {
    foreach ($d in $cleanupRoots) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
    }
}

if ($Leg -eq "impl-round-2") {
    try {
        $feature = "loop-consistency-red-$PID"
        if (-not (Initialize-LoopFixture -Profile "greenfield" -Feature $feature)) {
            Write-Host "FAIL: -Leg impl-round-2: Initialize-LoopFixture failed"
            exit 1
        }
        $cleanupRoots.Add($script:LoopFixtureRoot)
        if (-not (Initialize-LoopImplPrereqs $feature)) {
            Write-Host "FAIL: -Leg impl-round-2: spec prerequisite driving failed"
            exit 1
        }
        if (-not (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major")) {
            Write-Host "FAIL: -Leg impl-round-2: impl round 1 failed"
            exit 1
        }
        if (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major") {
            Write-Host "-Leg impl-round-2: round 2 succeeded (GREEN)"
            exit 0
        } else {
            Write-Host "-Leg impl-round-2: round 2 failed (RED)"
            exit 1
        }
    } finally {
        Invoke-Cleanup
    }
}

$script:Pass = 0
$script:Fail = 0
function Test-Ok([string]$Message) { Write-Host "ok: $Message"; $script:Pass++ }
function Test-Fail([string]$Message) { Write-Host "FAIL: $Message"; $script:Fail++ }

try {
    # -------------------------------------------------------------------
    # TEST-008 (AC-008): drive spec/impl/task/domain rounds 1->3
    # -------------------------------------------------------------------
    Write-Host "=== TEST-008: drive spec/impl/task/domain rounds 1->3 ==="

    $specPrecheckPs1 = Join-Path $repoRoot "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1"
    $domainPrecheckPs1 = Join-Path $repoRoot "plugins/sdd-domain/scripts/domain-review-precheck.ps1"

    if (-not (Test-Path -LiteralPath $specPrecheckPs1 -PathType Leaf)) {
        Write-Host "SKIP: TEST-008 spec/impl/task legs: spec-review-precheck.ps1 not found at $specPrecheckPs1 (same gap as tests/loop-driver.tests.ps1 TEST-006; impl/task both require a genuine on-disk spec-review PASS first, so they degrade transitively even though impl-review-precheck.ps1 and task-review-precheck.ps1 themselves exist)"
    } else {
        $specFeature = "loop-consistency-spec-$PID"
        if (Initialize-LoopFixture -Profile "greenfield" -Feature $specFeature) {
            Test-Ok "TEST-008.1: loop_fixture_init (spec leg fixture) succeeds"
            $cleanupRoots.Add($script:LoopFixtureRoot)
        } else {
            Test-Fail "TEST-008.1: loop_fixture_init (spec leg fixture) failed"
        }
        $specRoot = $script:LoopFixtureRoot

        if ((Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 3 -Verdict "PASS" -Severity "Minor")) {
            Test-Ok "TEST-008.2: spec leg drives rounds 1->3 green"
        } else {
            Test-Fail "TEST-008.2: spec leg failed to drive rounds 1->3"
        }
        if (Test-LoopTerminal -LoopId "spec-review" -Observed "PASS") {
            Test-Ok "TEST-008.3: spec leg observed end state PASS matches the loop-inventory terminal"
        } else {
            Test-Fail "TEST-008.3: spec leg observed end state does not match the loop-inventory terminal (PASS)"
        }

        # -------------------------------------------------------------------
        # TEST-018: regression (same-turn edit + reset). editing
        # requirements.md while it still declares Passed, then running
        # --reset, must persist the hash of the post-reset (Pending) bytes in
        # precheck-result.json, never the pre-mutation bytes hashed before
        # the script's own rewrite. Parity with the bash regression in
        # tests/spec-review-loop.tests.sh.
        # -------------------------------------------------------------------
        $specRequirementsPath = Join-Path $specRoot "specs/$specFeature/requirements.md"
        Set-LoopStatusField $specRequirementsPath "Spec-Review-Status" "Passed"
        Add-Content -LiteralPath $specRequirementsPath -Value "`n<!-- same-turn edit recorded while still Passed -->`n"
        $specResetScriptPath = Join-Path $specRoot "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1"
        & $specResetScriptPath $specFeature 2 1 "--reset" | Out-Null
        $specResetExitCode = $LASTEXITCODE
        if ($specResetExitCode -eq 0) {
            Test-Ok "TEST-018.1: same-turn edit + reset (attempt 2 round 1) exits success"
        } else {
            Test-Fail "TEST-018.1: same-turn edit + reset (attempt 2 round 1) exited $specResetExitCode"
        }

        $specResetStatusMatch = Select-String -LiteralPath $specRequirementsPath -CaseSensitive -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1
        $specResetStatusValue = if ($specResetStatusMatch) { ($specResetStatusMatch.Matches[0].Groups[1].Value -replace '\s', '') } else { '' }
        if ($specResetStatusValue -ceq 'Pending') {
            Test-Ok "TEST-018.2: reset restores Spec-Review-Status: Pending after the same-turn Passed edit"
        } else {
            Test-Fail "TEST-018.2: reset did not restore Spec-Review-Status: Pending (observed: $specResetStatusValue)"
        }

        $specAttemptTwoRoundOne = Join-Path $specRoot "reports/spec-review/$specFeature/attempt-2/round-1"
        $specResetPrecheckPath = Join-Path $specAttemptTwoRoundOne "precheck-result.json"
        $specLiveRequirementsSha = Get-LoopSha256 $specRequirementsPath
        $specPersistedRequirementsSha = Invoke-LoopJq @("-r", ".requirements_sha256") $specResetPrecheckPath
        if ($specPersistedRequirementsSha -ceq $specLiveRequirementsSha) {
            Test-Ok "TEST-018.3: reset persists the post-reset requirements hash, never the pre-mutation Passed bytes"
        } else {
            Test-Fail "TEST-018.3: reset persisted a stale requirements hash (expected $specLiveRequirementsSha, got $specPersistedRequirementsSha)"
        }

        $specPersistedAcceptanceSha = Invoke-LoopJq @("-r", ".acceptance_sha256") $specResetPrecheckPath
        $specExpectedInputSha = Get-LoopSha256Text "${specLiveRequirementsSha}:${specPersistedAcceptanceSha}"
        $specPersistedInputSha = Invoke-LoopJq @("-r", ".input_sha256") $specResetPrecheckPath
        if ($specPersistedInputSha -ceq $specExpectedInputSha) {
            Test-Ok "TEST-018.4: reset persists the composite input hash recomputed from the post-reset bytes"
        } else {
            Test-Fail "TEST-018.4: reset persisted a stale composite input hash (expected $specExpectedInputSha, got $specPersistedInputSha)"
        }

        $implFeature = "loop-consistency-impl-$PID"
        if (Initialize-LoopFixture -Profile "greenfield" -Feature $implFeature) {
            Test-Ok "TEST-008.4: loop_fixture_init (impl leg fixture) succeeds"
            $cleanupRoots.Add($script:LoopFixtureRoot)
        } else {
            Test-Fail "TEST-008.4: loop_fixture_init (impl leg fixture) failed"
        }
        $implRoot = $script:LoopFixtureRoot

        if ((Initialize-LoopImplPrereqs $implFeature) -and
            (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "impl" -Attempt 1 -Round 3 -Verdict "PASS" -Severity "none")) {
            Test-Ok "TEST-008.5: impl leg drives (genuine spec PASS prereq, then) rounds 1->3 green"
        } else {
            Test-Fail "TEST-008.5: impl leg failed to drive rounds 1->3"
        }
        if (Test-LoopTerminal -LoopId "impl-review" -Observed "PASS") {
            Test-Ok "TEST-008.6: impl leg observed end state PASS matches the loop-inventory terminal"
        } else {
            Test-Fail "TEST-008.6: impl leg observed end state does not match the loop-inventory terminal (PASS)"
        }
        $implRound2Dir = Join-Path $implRoot "reports/impl-review/$implFeature/attempt-1/round-2"
        $implContractPath = Join-Path $implRound2Dir "impl-review-contract.json"
        if (Test-Path -LiteralPath $implContractPath -PathType Leaf) {
            $carriesRound1Summary = (Invoke-LoopJq @("-e", "--arg", "role", "impl-reviewer-a",
                '.reviewers[] | select(.role == $role) | .allowed_input_manifest[] | select(.path | test("attempt-1/round-1/integrated-summary\\.json$"))') $implContractPath)
            if ($LASTEXITCODE -eq 0) {
                Test-Ok "TEST-008.7: impl round-2 reviewer-a manifest carries round-1's integrated-summary.json (INV-012/2d8c6a5 fix in effect)"
            } else {
                Test-Fail "TEST-008.7: impl round-2 reviewer-a manifest is missing the round-1 integrated-summary.json entry"
            }
        } else {
            Test-Fail "TEST-008.7: impl-review-contract.json missing for round 2"
        }

        $taskFeature = "loop-consistency-task-$PID"
        if (Initialize-LoopFixture -Profile "greenfield" -Feature $taskFeature) {
            Test-Ok "TEST-008.8: loop_fixture_init (task leg fixture) succeeds"
            $cleanupRoots.Add($script:LoopFixtureRoot)
        } else {
            Test-Fail "TEST-008.8: loop_fixture_init (task leg fixture) failed"
        }
        $taskRoot = $script:LoopFixtureRoot

        # OQ-5: Initialize-LoopTaskPrereqs drives a genuine spec PASS and a
        # genuine impl PASS before task-review-precheck.ps1 runs at all; see
        # this task's implementation report for the cross-stage finding.
        if ((Initialize-LoopTaskPrereqs $taskFeature) -and
            (Invoke-DriveReviewRound -Stage "task" -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "task" -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "task" -Attempt 1 -Round 3 -Verdict "PASS" -Severity "none")) {
            Test-Ok "TEST-008.9: task leg drives (genuine spec+impl PASS prereqs, then) rounds 1->3 green"
        } else {
            Test-Fail "TEST-008.9: task leg failed to drive rounds 1->3"
        }
        if (Test-LoopTerminal -LoopId "task-review" -Observed "PASS") {
            Test-Ok "TEST-008.10: task leg observed end state PASS matches the loop-inventory terminal"
        } else {
            Test-Fail "TEST-008.10: task leg observed end state does not match the loop-inventory terminal (PASS)"
        }

        $script:PwshImplRound2Dir = $implRound2Dir
    }

    if (-not (Test-Path -LiteralPath $domainPrecheckPs1 -PathType Leaf)) {
        Write-Host "SKIP: TEST-008 domain leg: domain-review-precheck.ps1 not found at $domainPrecheckPs1 (#147)"
    } else {
        $domainFeature = "loop-consistency-domain-$PID"
        if (Initialize-LoopFixture -Profile "greenfield" -Feature $domainFeature) {
            Test-Ok "TEST-008.11: loop_fixture_init (domain leg fixture) succeeds"
            $cleanupRoots.Add($script:LoopFixtureRoot)
        } else {
            Test-Fail "TEST-008.11: loop_fixture_init (domain leg fixture) failed"
        }

        if ((Invoke-DriveReviewRound -Stage "domain" -Attempt 1 -Round 1 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "domain" -Attempt 1 -Round 2 -Verdict "NEEDS_WORK" -Severity "Major") -and
            (Invoke-DriveReviewRound -Stage "domain" -Attempt 1 -Round 3 -Verdict "BLOCKED" -Severity "Major")) {
            Test-Ok "TEST-008.12: domain leg drives rounds 1->3 (cap-reached BLOCKED) green"
        } else {
            Test-Fail "TEST-008.12: domain leg failed to drive rounds 1->3"
        }
        if (Test-LoopTerminal -LoopId "domain-review" -Observed "BLOCKED") {
            Test-Ok "TEST-008.13: domain leg observed end state BLOCKED matches the loop-inventory terminal"
        } else {
            Test-Fail "TEST-008.13: domain leg observed end state does not match the loop-inventory terminal (BLOCKED)"
        }
    }

    # -------------------------------------------------------------------
    # TEST-008 brownfield-profile leg (T-002 / Issue #146 / epic-159-pillar-a2
    # REQ-002, AC-007/AC-010): loop_fixture_init brownfield seeded from the
    # canonical tests/fixtures/loops/brownfield-seed/ drives spec-review
    # round 1 and matches the same inventory terminal the greenfield leg
    # above already asserts. See the bash twin for the full AC-007 split
    # rationale (the seed-existence + three-category half lives in
    # tests/check-placeholders-brownfield.tests.sh/.ps1 instead).
    # No validator-capability-probe wrapping here: unlike the bash lane, the
    # pwsh loop-driver's review-context call path does not go through the
    # bash @tsv/while-read parsing INV-032 documents, so no probe/skip gate
    # exists in tests/lib/loop-driver.ps1 for this leg to inherit.
    # -------------------------------------------------------------------
    Write-Host "=== TEST-008 brownfield-profile leg: canonical seed drives spec-review round 1 (AC-007, AC-010) ==="

    $brownfieldSeed = Join-Path $repoRoot "tests/fixtures/loops/brownfield-seed"
    $brownfieldFeature = "loop-consistency-brownfield-$PID"
    $env:LOOP_FIXTURE_SEED = $brownfieldSeed
    if (Initialize-LoopFixture -Profile "brownfield" -Feature $brownfieldFeature) {
        Test-Ok "TEST-008.15 (AC-007): loop_fixture_init brownfield succeeds with LOOP_FIXTURE_SEED pointed at the canonical seed"
        $cleanupRoots.Add($script:LoopFixtureRoot)
    } else {
        Test-Fail "TEST-008.15 (AC-007): loop_fixture_init brownfield failed with LOOP_FIXTURE_SEED pointed at the canonical seed"
    }
    Remove-Item Env:\LOOP_FIXTURE_SEED -ErrorAction SilentlyContinue
    $brownfieldRoot = $script:LoopFixtureRoot

    $brownfieldVerbatim = $brownfieldRoot -and
        ((Get-LoopSha256 (Join-Path $brownfieldSeed "src/base.py")) -eq (Get-LoopSha256 (Join-Path $brownfieldRoot "src/base.py"))) -and
        ((Get-LoopSha256 (Join-Path $brownfieldSeed "src/legacy_util.py")) -eq (Get-LoopSha256 (Join-Path $brownfieldRoot "src/legacy_util.py"))) -and
        ((Get-LoopSha256 (Join-Path $brownfieldSeed "src/service.py")) -eq (Get-LoopSha256 (Join-Path $brownfieldRoot "src/service.py"))) -and
        ((Get-LoopSha256 (Join-Path $brownfieldSeed "specs/brownfield-seed-demo/tasks.md")) -eq (Get-LoopSha256 (Join-Path $brownfieldRoot "specs/brownfield-seed-demo/tasks.md"))) -and
        ((Get-LoopSha256 (Join-Path $brownfieldSeed "CHANGED_FILES.txt")) -eq (Get-LoopSha256 (Join-Path $brownfieldRoot "CHANGED_FILES.txt")))
    if ($brownfieldVerbatim) {
        Test-Ok "TEST-008.16 (AC-007): the canonical seed content is present verbatim under `$LoopFixtureRoot"
    } else {
        Test-Fail "TEST-008.16 (AC-007): the canonical seed content is NOT present verbatim under `$LoopFixtureRoot"
    }

    if (-not (Test-Path -LiteralPath $specPrecheckPs1 -PathType Leaf)) {
        Write-Host "SKIP: TEST-008 brownfield-profile leg (round drive): spec-review-precheck.ps1 not found at $specPrecheckPs1 (same gap as the greenfield spec leg above)"
    } else {
        if (Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 1 -Verdict "PASS" -Severity "Minor") {
            Test-Ok "TEST-008.17 (AC-010): brownfield-profile leg drives spec-review round 1 (PASS/Minor) green"
        } else {
            Test-Fail "TEST-008.17 (AC-010): brownfield-profile leg failed to drive spec-review round 1"
        }
        if (Test-LoopTerminal -LoopId "spec-review" -Observed "PASS") {
            Test-Ok "TEST-008.18 (AC-010): brownfield-profile leg observed end state PASS matches the same inventory terminal the greenfield leg (TEST-008.3) already asserts"
        } else {
            Test-Fail "TEST-008.18 (AC-010): brownfield-profile leg observed end state does not match the loop-inventory terminal (PASS)"
        }
    }

    # -------------------------------------------------------------------
    # TEST-009 (AC-009): impl-review round-2 RED differential regression lock
    # -------------------------------------------------------------------
    Write-Host "=== TEST-009: impl-review round-2 leg green at HEAD (RED differential regression lock) ==="

    if ($script:PwshImplRound2Dir -and (Test-Path -LiteralPath (Join-Path $script:PwshImplRound2Dir "impl-review-contract.json") -PathType Leaf)) {
        Test-Ok "TEST-009.1: impl-review round-2 leg is green at HEAD (2d8c6a5/INV-012 fix in effect; see TEST-008.5/.7 above)"
    } else {
        Write-Host "SKIP: TEST-009.1: spec-review-precheck.ps1 absent upstream blocks driving this lane (see TEST-008 SKIP note); the one-time RED/GREEN differential evidence is recorded bash-only"
    }

    $redLog = Join-Path $repoRoot "specs/epic-159-pillar-a/verification/T-003/red-differential.log"
    if ((Test-Path -LiteralPath $redLog -PathType Leaf) -and (Select-String -LiteralPath $redLog -Pattern "RED" -Quiet)) {
        Test-Ok "TEST-009.2: the one-time RED differential evidence against 2d8c6a5^ is recorded at specs/epic-159-pillar-a/verification/T-003/red-differential.log"
    } else {
        Test-Fail "TEST-009.2: the recorded RED differential evidence file is missing or does not record a RED result"
    }

    # -------------------------------------------------------------------
    # TEST-010 (AC-010): bidirectional invariant, self-contained
    # -------------------------------------------------------------------
    Write-Host "=== TEST-010: bidirectional invariant (downstream-required inputs are upstream-authorized) ==="

    $invFeature = "loop-consistency-inv-$PID"
    if (Initialize-LoopFixture -Profile "greenfield" -Feature $invFeature) {
        Test-Ok "TEST-010.0: loop_fixture_init (bidirectional-invariant fixture) succeeds"
        $cleanupRoots.Add($script:LoopFixtureRoot)
    } else {
        Test-Fail "TEST-010.0: loop_fixture_init (bidirectional-invariant fixture) failed"
    }
    $invRoot = $script:LoopFixtureRoot
    Initialize-LoopTaskFixture $invFeature | Out-Null

    $specR1 = Join-Path $invRoot "reports/spec-review/$invFeature/attempt-1/round-1"
    $implR1 = Join-Path $invRoot "reports/impl-review/$invFeature/attempt-1/round-1"
    $implR2 = Join-Path $invRoot "reports/impl-review/$invFeature/attempt-1/round-2"
    $taskR1 = Join-Path $invRoot "reports/task-review/$invFeature/attempt-1/round-1"
    $domainR1 = Join-Path $invRoot "reports/domain-review/attempt-1/round-1"
    foreach ($d in @($specR1, $implR1, $implR2, $taskR1, $domainR1)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    '{"schema":"placeholder/v1"}' | Set-Content -LiteralPath (Join-Path $specR1 "precheck-result.json") -Encoding utf8
    '{"schema":"placeholder/v1"}' | Set-Content -LiteralPath (Join-Path $implR1 "precheck-result.json") -Encoding utf8
    '{"schema":"placeholder/v1"}' | Set-Content -LiteralPath (Join-Path $implR1 "integrated-summary.json") -Encoding utf8
    '{"schema":"placeholder/v1"}' | Set-Content -LiteralPath (Join-Path $implR2 "precheck-result.json") -Encoding utf8
    '{"schema":"placeholder/v1"}' | Set-Content -LiteralPath (Join-Path $taskR1 "precheck-result.json") -Encoding utf8
    '{"schema":"placeholder/v1"}' | Set-Content -LiteralPath (Join-Path $taskR1 "dependency-graph.json") -Encoding utf8
    '{"schema":"placeholder/v1"}' | Set-Content -LiteralPath (Join-Path $domainR1 "precheck-result.json") -Encoding utf8

    $specManifestA = Get-LoopSpecManifestA $specR1
    if (Test-LoopBidirectionalInvariant "spec" "spec-reviewer-a" $invFeature $specManifestA) {
        Test-Ok "TEST-010.1: spec-review reviewer-a manifest satisfies the bidirectional invariant"
    } else {
        Test-Fail "TEST-010.1: spec-review reviewer-a manifest does not satisfy the bidirectional invariant"
    }

    $implManifestA = Get-LoopImplManifestA $implR2 2 $invFeature
    if (Test-LoopBidirectionalInvariant "impl" "impl-reviewer-a" $invFeature $implManifestA) {
        Test-Ok "TEST-010.2: impl-review round-2 reviewer-a manifest (carrying round-1's integrated-summary.json) satisfies the bidirectional invariant"
    } else {
        Test-Fail "TEST-010.2: impl-review round-2 reviewer-a manifest does not satisfy the bidirectional invariant"
    }

    $taskManifestA = Get-LoopTaskManifestA $taskR1 $invFeature
    if (Test-LoopBidirectionalInvariant "task" "task-reviewer-a" $invFeature $taskManifestA) {
        Test-Ok "TEST-010.3: task-review reviewer-a manifest satisfies the bidirectional invariant"
    } else {
        Test-Fail "TEST-010.3: task-review reviewer-a manifest does not satisfy the bidirectional invariant"
    }

    $domainManifestA = Get-LoopDomainManifestA $domainR1
    if (Test-LoopBidirectionalInvariant "domain" "domain-reviewer-a" "loop-driver-domain" $domainManifestA) {
        Test-Ok "TEST-010.4: domain-review reviewer-a manifest satisfies the bidirectional invariant"
    } else {
        Test-Fail "TEST-010.4: domain-review reviewer-a manifest does not satisfy the bidirectional invariant"
    }

    $badPath = "specs/$invFeature/requirements.md"
    $badAbs = Join-Path $invRoot $badPath
    if (Test-Path -LiteralPath $badAbs -PathType Leaf) {
        $badSha = Get-LoopSha256 $badAbs
        $badManifest = $domainManifestA | & jq -c --arg p $badPath --arg s $badSha '. + [{path:$p, sha256:$s}]'
        if (Test-LoopBidirectionalInvariant "domain" "domain-reviewer-a" "loop-driver-domain" $badManifest) {
            Test-Fail "TEST-010.5 (negative self-check): a synthetic required-but-unauthorized manifest entry did NOT turn Test-LoopBidirectionalInvariant red"
        } else {
            Test-Ok "TEST-010.5 (negative self-check): a synthetic required-but-unauthorized manifest entry (specs/.../requirements.md for a domain reviewer) turns Test-LoopBidirectionalInvariant red"
        }
    } else {
        Test-Fail "TEST-010.5 (negative self-check): could not construct the synthetic fixture (fixture's own specs/ requirements.md is missing)"
    }

    # -------------------------------------------------------------------
    # TEST-019 (T-006 / Issue #195 / epic-195-a7-compatibility REQ-003,
    # AC-022/AC-023/AC-024/AC-026/AC-032): Context-absent round event trace
    # vs. golden trace, via Test-EventTrace.
    #
    # Numbered TEST-019 on this lane, not TEST-018: this file's own
    # PowerShell-only "TEST-018" (above) is a pre-existing, unrelated
    # same-turn-edit-plus-reset regression case (parity coverage for
    # tests/spec-review-loop.tests.sh, which has no PowerShell twin of its
    # own) that already occupies that case number in this file. The bash
    # twin's own next-available number after TEST-017 really is TEST-018
    # (tests/loop-consistency.tests.sh has no such case), so the bash suite
    # names this case TEST-018 per tasks.md T-006/acceptance-tests.md
    # AC-032's own literal text ("TEST-018 in tests/loop-consistency.tests.sh");
    # this lane's own next-available number is TEST-019 instead. Both cases
    # exercise the identical assertions, golden-trace fixture, and AC set.
    # -------------------------------------------------------------------
    Write-Host "=== TEST-019: Context-absent round event trace matches the golden trace (AC-022, AC-023, AC-024, AC-026, AC-032) ==="

    $eventTraceGolden = Join-Path $repoRoot "tests/fixtures/compatibility-event-trace/f1-spec-round1-pass.json"

    if (-not (Test-Path -LiteralPath $specPrecheckPs1 -PathType Leaf)) {
        Write-Host "SKIP: TEST-019: spec-review-precheck.ps1 not found at $specPrecheckPs1 (same gap as TEST-008's own spec leg)"
    } else {
        $eventFeature = "loop-consistency-event-$PID"
        if (Initialize-LoopFixture -Profile "greenfield" -Feature $eventFeature) {
            Test-Ok "TEST-019.1: loop_fixture_init (Context-absent event-trace fixture) succeeds"
            $cleanupRoots.Add($script:LoopFixtureRoot)
        } else {
            Test-Fail "TEST-019.1: loop_fixture_init (Context-absent event-trace fixture) failed"
        }
        $eventRoot = $script:LoopFixtureRoot

        if (Invoke-DriveReviewRound -Stage "spec" -Attempt 1 -Round 1 -Verdict "PASS" -Severity "none") {
            Test-Ok "TEST-019.2 (AC-032): Context-absent round drives a single spec-review round (PASS/none) green"
        } else {
            Test-Fail "TEST-019.2 (AC-032): Context-absent round failed to drive spec-review round 1"
        }

        $terminalOk = $false
        if (Test-LoopTerminal -LoopId "spec-review" -Observed "PASS") {
            Test-Ok "TEST-019.3: observed end state PASS matches the loop-inventory terminal"
            $terminalOk = $true
        } else {
            Test-Fail "TEST-019.3: observed end state does not match the loop-inventory terminal (PASS)"
        }
        # done-transition:assert-terminal (AC-026): recorded here, immediately
        # after Test-LoopTerminal's own comparison, rather than inside
        # Test-LoopTerminal itself -- tests/loop-inventory.tests.ps1's own
        # TEST-009.2 regression lock (T-005) keeps Test-LoopTerminal
        # byte-identical to its pre-T-006 form (see the bash twin and this
        # task's implementation report, "Specification Differences").
        if ($terminalOk) {
            $doneValueJson = & jq -cn --arg v "PASS" '$v'
            [void](Write-LoopTraceEvent -Kind done-transition -Producer done-transition:assert-terminal -ValueJson ([string]$doneValueJson))
        }

        if (Test-EventTrace -GoldenTracePath $eventTraceGolden) {
            Test-Ok "TEST-019.4 (AC-022, AC-023, AC-024, AC-026, AC-032): observed event trace matches the recorded golden trace via Test-EventTrace"
        } else {
            Test-Fail "TEST-019.4 (AC-022, AC-023, AC-024, AC-026, AC-032): observed event trace does not match the recorded golden trace"
        }
    }

    # -------------------------------------------------------------------
    # TEST-019.5 (T-008 / Issue #195 / epic-195-a7-compatibility AC-036;
    # OQ-001 item (a)) -- anchor-fingerprint drift check against the live
    # sdd-bootstrap-interviewer/SKILL.md, adopting Epic A5's own design.md
    # item 10(a) fixture directly (FP-A5-CALLER-CONTRACT-10:
    # specs/epic-193-a5-capability-resolver/design.md:1886-1915). See the
    # bash twin's own TEST-018.5 header comment for the full mechanism and
    # activation-condition rationale; identical algorithm here (sha256 of a
    # fixed inclusive line-range window, LF-joined, no trailing newline,
    # plus the target heading's own 1-based ordinal position among every
    # ##/### heading in document order).
    #
    # TEST-019.5a/.5b prove the checker function itself first against
    # deliberately-constructed positive/negative fixtures (Scope: "a
    # deliberately drifted anchor window ... before the implementation"),
    # unconditionally live and gating pass/fail normally. TEST-019.5c then
    # runs the SAME checker against the live SKILL.md, reported for
    # provenance only -- AC-036's own Test Type (acceptance-tests.md) fixes
    # this as a named SKIP until Epic A5 merges, matching design.md Test
    # Strategy item 6 ("once Epic A5's caller insertion point is
    # implemented," never merely once the digest happens to still match).
    # -------------------------------------------------------------------
    Write-Host "=== TEST-019.5 (AC-036): anchor-fingerprint drift check (named SKIP until Epic A5 merges) ==="

    function Test-A5AnchorFingerprint {
        param(
            [string]$FilePath, [int]$Start, [int]$End, [string]$ExpectedSha,
            [string]$ExpectedHeading, [int]$ExpectedOrdinal
        )
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            return @{ Match = $false; Detail = "file not found: $FilePath" }
        }
        $lines = Get-Content -LiteralPath $FilePath
        $windowLines = $lines[($Start - 1)..($End - 1)] | ForEach-Object { $_ -replace "`r$", "" }
        $window = ($windowLines -join "`n")
        $actualSha = Get-LoopSha256Text $window
        $headings = @($lines | Where-Object { $_ -match '^#{2,3} ' })
        $ordinal = 0
        for ($i = 0; $i -lt $headings.Count; $i++) {
            if ($headings[$i] -eq $ExpectedHeading) { $ordinal = $i + 1; break }
        }
        $isMatch = ($actualSha -eq $ExpectedSha) -and ($ordinal -eq $ExpectedOrdinal)
        if ($isMatch) {
            return @{ Match = $true; Detail = "MATCH sha256=$actualSha ordinal=$ordinal" }
        } else {
            return @{ Match = $false; Detail = "DRIFT sha256=$actualSha (expected $ExpectedSha) ordinal=$ordinal (expected $ExpectedOrdinal)" }
        }
    }

    $a5AnchorDir = Join-Path ([IO.Path]::GetTempPath()) ("a5-anchor." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $a5AnchorDir | Out-Null
    $cleanupRoots.Add($a5AnchorDir)

    $a5SkillGood = Join-Path $a5AnchorDir "skill-good.md"
    @"
# Heading Zero

## Section One

### Full-Profile Layer Interview

Body text unrelated to any check.
"@ | Set-Content -LiteralPath $a5SkillGood -NoNewline -Encoding utf8

    $a5GoodWindowLines = (Get-Content -LiteralPath $a5SkillGood)[2..6] | ForEach-Object { $_ -replace "`r$", "" }
    $a5GoodSha = Get-LoopSha256Text (($a5GoodWindowLines) -join "`n")

    $a5PositiveResult = Test-A5AnchorFingerprint -FilePath $a5SkillGood -Start 3 -End 7 -ExpectedSha $a5GoodSha -ExpectedHeading "### Full-Profile Layer Interview" -ExpectedOrdinal 2
    if ($a5PositiveResult.Match) {
        Test-Ok "TEST-019.5a (positive self-check): the anchor-fingerprint checker matches a non-drifted window and ordinal"
    } else {
        Test-Fail "TEST-019.5a (positive self-check): the anchor-fingerprint checker rejected a non-drifted window and ordinal ($($a5PositiveResult.Detail))"
    }

    # Negative fixture (Scope: "a deliberately drifted anchor window"): line
    # 2 (blank in skill-good.md) becomes a new heading here, and lines 3-7
    # are otherwise byte-identical to skill-good.md's own lines 3-7 -- the
    # exact "heading moved to a different position without changing its own
    # immediate neighboring lines" regression A5's own design text names as
    # this revision's own proof case. A sha256-only comparison of the SAME
    # window (3-7) would wrongly report a MATCH here; only the ordinal
    # check (the target heading is now 3rd, not 2nd) detects this drift.
    $a5SkillDrifted = Join-Path $a5AnchorDir "skill-drifted.md"
    @"
# Heading Zero
## Extra Section (inserted -- shifts the ordinal, window untouched)
## Section One

### Full-Profile Layer Interview

Body text unrelated to any check.
"@ | Set-Content -LiteralPath $a5SkillDrifted -NoNewline -Encoding utf8

    $a5NegativeResult = Test-A5AnchorFingerprint -FilePath $a5SkillDrifted -Start 3 -End 7 -ExpectedSha $a5GoodSha -ExpectedHeading "### Full-Profile Layer Interview" -ExpectedOrdinal 2
    if ($a5NegativeResult.Match) {
        Test-Fail "TEST-019.5b (negative self-check): the anchor-fingerprint checker did NOT detect a heading relocated ahead of an otherwise byte-identical window (sha256-only would have missed this)"
    } else {
        Test-Ok "TEST-019.5b (negative self-check): the anchor-fingerprint checker correctly detects a heading relocated ahead of an otherwise byte-identical window"
    }

    $a5SkillMd = Join-Path $repoRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
    $a5LiveResult = Test-A5AnchorFingerprint -FilePath $a5SkillMd -Start 54 -End 64 -ExpectedSha "d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64" -ExpectedHeading "### Full-Profile Layer Interview" -ExpectedOrdinal 3
    $a5Merged = Test-Path -LiteralPath (Join-Path $repoRoot "specs/epic-193-a5-capability-resolver") -PathType Container
    if ($a5Merged) {
        if ($a5LiveResult.Match) {
            Test-Ok "TEST-019.5c (AC-036): live SKILL.md anchor fingerprint matches FP-A5-CALLER-CONTRACT-10 (Epic A5 merged)"
        } else {
            Test-Fail "TEST-019.5c (AC-036): live SKILL.md anchor fingerprint has drifted from FP-A5-CALLER-CONTRACT-10 (Epic A5 has merged -- this is a real regression)"
        }
    } else {
        Write-Host "SKIP: TEST-019.5c: AC-036 anchor-fingerprint drift check against the live SKILL.md -- Epic A5 has not merged (local ad hoc probe: specs/epic-193-a5-capability-resolver/ absent from this tree; design.md Test Strategy item 6, 'once Epic A5's caller insertion point is implemented' -- never merely once the digest happens to still match); current informational recomputation: $($a5LiveResult.Detail)"
    }

    # -------------------------------------------------------------------
    # TEST-017 (AC-017): runtime budget
    # -------------------------------------------------------------------
    Write-Host "=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=$script:LoopSuiteBudgetSeconds) ==="

    $syntheticPastEpoch = $startEpoch - 1
    if (Test-RuntimeBudget -Start $syntheticPastEpoch -Budget 0) {
        Test-Fail "TEST-017.1 (negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
    } else {
        Test-Ok "TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red"
    }

    $elapsedSeconds = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $startEpoch
    if (Test-RuntimeBudget -Start $startEpoch) {
        Test-Ok "TEST-017.2: suite completed within the $script:LoopSuiteBudgetSeconds`s runtime budget"
    } else {
        Test-Fail "TEST-017.2: suite exceeded the $script:LoopSuiteBudgetSeconds`s runtime budget"
    }

    Write-Host ""
    Write-Host "loop-consistency.tests.ps1: $script:Pass passed, $script:Fail failed, ${elapsedSeconds}s elapsed"
    if ($script:Fail -ne 0) { exit 1 }
    exit 0
} finally {
    Invoke-Cleanup
}
