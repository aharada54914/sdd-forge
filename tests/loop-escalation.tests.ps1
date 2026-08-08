# tests/loop-escalation.tests.ps1 - PowerShell twin of
# tests/loop-escalation.tests.sh, byte-equivalent in coverage where the
# upstream gate surfaces allow it (T-004 / Issue #144 / epic-159-pillar-a
# REQ-004). See the bash twin for full section-by-section rationale.
#
# TEST-013 pwsh-lane note: check-terminal-tier-resume.ps1 is a pure
# PowerShell reimplementation with NO python3 (or any external deterministic-
# runtime) dependency at all (confirmed: no reference to python3 anywhere in
# that script), unlike its bash twin which shells out to python3 at
# check-terminal-tier-resume.sh:29-32. INV-017 cites only the .sh line
# numbers for this reason. This suite therefore records that leg as an
# explicit, reasoned SKIP on this lane rather than fabricating a PATH-
# restriction scenario the script cannot actually exhibit. select-agent-
# model.ps1 DOES carry an analogous -DeterministicRuntimeCommand check
# (default 'pwsh'), so its degradation IS driven for real here, using the
# override flag -- the exact mechanism already exercised by
# tests/agent-model-routing.tests.ps1's own "runtime unavailable" leg.
#
# Parity-extension placement note (TEST-012; design.md "A4 parity-extension
# placement decision", INV-016): this suite EXTENDS
# tests/template-validator-parity.tests.sh (referenced, never duplicated or
# edited). That suite pins template<->validator TEXT-RULE parity via
# replicated parsing; this suite drives the REAL validate-review-context-
# set.ps1 end-to-end against a REAL loop-driver fixture and a REAL identity
# ledger. No assertion below reproduces one of that suite's checks.

$ErrorActionPreference = 'Stop'
$startEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$env:LOOP_INVENTORY_PATH = Join-Path $repoRoot "tests/loops/loop-inventory.json"
. (Join-Path $repoRoot "tests/lib/loop-driver.ps1")

$cycleLimitPs1 = Join-Path $script:SddLoopRepoRoot "plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1"
$selectModelPs1 = Join-Path $script:SddLoopRepoRoot "plugins/sdd-implementation/scripts/select-agent-model.ps1"
$resumePs1 = Join-Path $script:SddLoopRepoRoot "plugins/sdd-implementation/scripts/check-terminal-tier-resume.ps1"
$validatorPs1 = Join-Path $script:SddLoopRepoRoot "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
$templateMd = Join-Path $script:SddLoopRepoRoot "plugins/sdd-implementation/templates/implementation-report.template.md"
$schemaJson = Join-Path $script:SddLoopRepoRoot "contracts/terminal-tier-blocked-state.schema.json"

# issue #167 / RT-20260712-001 / quality-loop-fixes T-001: the cycle-limit
# script's CLI contract gained a REQUIRED feature 2nd positional and its
# counting logic now requires an anchored Feature: header line matching the
# invoked feature -- every invocation below and every fixture report this
# suite writes must carry this feature slug, or every count silently reads 0.
$script:EscCycleLimitFeature = "loop-escalation-fixture"

foreach ($f in @($cycleLimitPs1, $selectModelPs1, $resumePs1, $validatorPs1, $templateMd, $schemaJson)) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
        Write-Host "FAIL: required driven artifact missing: $f"
        exit 1
    }
}

$script:Pass = 0
$script:Fail = 0
function Test-Ok([string]$Message) { Write-Host "ok: $Message"; $script:Pass++ }
function Test-Fail([string]$Message) { Write-Host "FAIL: $Message"; $script:Fail++ }

$cleanupRoots = [System.Collections.Generic.List[string]]::new()
function Invoke-Cleanup {
    foreach ($d in $cleanupRoots) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
    }
}

function New-EscTempDir([string]$Prefix) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("$Prefix." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $dir | Out-Null
    return $dir
}

# issue #167 / RT-20260712-001 / quality-loop-fixes T-001: the cycle-limit
# script's CLI contract gained a REQUIRED feature 2nd positional and its
# counting logic now requires an anchored Feature: header line matching the
# invoked feature -- every fixture report this suite writes must carry that
# feature slug (default: $EscCycleLimitFeature, set below), or every count
# silently reads 0.
function New-EscGateReport {
    param([string]$Path, [string]$Task, [string]$Feature = $script:EscCycleLimitFeature)
    @"
# Quality Gate Report

Task ID: $Task
Feature: $Feature

VERDICT: NEEDS_WORK
"@ | Set-Content -LiteralPath $Path -NoNewline -Encoding utf8
}

# Get-EscQualityManifest -Feature <f> -TaskId <t> -Entries <json-array-text>
# Builds a review-context-invocation/v2 manifest for stage "quality", role
# "sdd-evaluator" -- tests/lib/loop-driver.ps1's Invoke-LoopReviewContextCall
# (T-002/T-003 scope) omits the quality-stage task_id field entirely, and
# tests/lib/loop-driver.ps1 is not in this task's Planned Files, so this
# suite owns its own quality-stage manifest builder locally.
function Get-EscQualityManifest {
    param([string]$Feature, [string]$TaskId, [string]$Entries)
    $ledger = Join-Path $script:LoopFixtureRoot "reports/review-context/identity-ledger.json"
    $ledgerSha = Get-LoopSha256 $ledger
    $sequence = Get-LoopNextSequence
    $previous = Get-LoopPreviousHash
    $runId = "fixture-sdd-evaluator-$Feature-seq$sequence"
    $session = "fixture-session-sdd-evaluator-seq$sequence"
    return (& jq -n --arg schema "review-context-invocation/v2" --arg stage "quality" --arg role "sdd-evaluator" `
        --arg feature $Feature --arg task_id $TaskId --arg run_id $runId --arg session $session `
        --argjson sequence $sequence --arg previous $previous `
        --arg ledger_path "reports/review-context/identity-ledger.json" --arg ledger_sha $ledgerSha `
        --argjson manifest $Entries `
        '{schema: $schema, stage: $stage, role: $role, feature: $feature, task_id: $task_id, run_id: $run_id, host_session_id: $session, sequence: $sequence, previous_record_sha256: $previous, identity_ledger_path: $ledger_path, identity_ledger_sha256: $ledger_sha, input_mode: "file-manifest", fallback_mode: "none", read_only: true, allowed_input_manifest: $manifest}')
}

# Get-EscRenderedTemplate -TaskId <t> -OutputPath <p> -OutputSha <h> -WorkingNotes <text>
# Mechanical {{placeholder}} substitution, mirroring the render() helper in
# tests/template-validator-parity.tests.sh (referenced, never duplicated).
function Get-EscRenderedTemplate {
    param([string]$TaskId, [string]$OutputPath, [string]$OutputSha, [string]$WorkingNotes)
    $body = Get-Content -Raw -LiteralPath $templateMd
    $body = $body -replace [regex]::Escape("{{task_id}}"), $TaskId
    $body = $body -replace [regex]::Escape("{{output_path}}"), $OutputPath
    $body = $body -replace [regex]::Escape("{{output_sha256}}"), $OutputSha
    $marker = "ESC_WORKING_NOTES_MARKER"
    $body = $body -replace [regex]::Escape("{{working_notes}}"), $marker
    $body = [regex]::Replace($body, "\{\{[a-zA-Z_\|]*\}\}", "fixture-value")
    $body = $body.Replace($marker, $WorkingNotes)
    return $body
}

# Invoke-EscResume: wraps check-terminal-tier-resume.ps1, which signals
# failure via `throw` (a terminating exception) rather than `exit N`, unlike
# check-quality-gate-cycle-limit.ps1 / select-agent-model.ps1 / validate-
# review-context-set.ps1 (all of which use explicit exit codes and are
# invoked directly below). Returns $true/$false; sets $script:EscLastOutput.
function Invoke-EscResume {
    param([string]$Evidence, [string]$BlockedState, [string]$Tasks, [string]$RepoRoot, [string]$ExpectedTask)
    try {
        $out = & $resumePs1 -Evidence $Evidence -BlockedState $BlockedState -Tasks $Tasks `
            -RepoRoot $RepoRoot -ExpectedTask $ExpectedTask
        $script:EscLastOutput = ($out | Out-String).Trim()
        return $true
    } catch {
        $script:EscLastOutput = $_.Exception.Message
        return $false
    }
}

try {
    # -------------------------------------------------------------------
    # TEST-011 (AC-011): cycle-limit table, select-agent-model escalation,
    # terminal-tier-recurrence blocked-state schema, resume deny/permit
    # -------------------------------------------------------------------
    Write-Host "=== TEST-011: quality-gate cycle-limit / select-agent-model escalation / terminal-tier / resume ==="

    $work = New-EscTempDir "loop-escalation-work"
    $cleanupRoots.Add($work)

    $clTask = "T-511"
    $clAbsentDir = Join-Path $work "cycle-limit-absent-dir-does-not-exist"
    $out = & $cycleLimitPs1 -TaskId $clTask -Feature $script:EscCycleLimitFeature -ReportsDir $clAbsentDir
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -and $out -eq "continue") {
        Test-Ok "TEST-011.1: 0 gate reports (absent reports/quality-gate/ dir) -> continue"
    } else {
        Test-Fail "TEST-011.1: 0 gate reports did not yield continue/exit0 (rc=$rc, out=$out)"
    }

    $clDir = Join-Path $work "cycle-limit-reports"
    New-Item -ItemType Directory -Path $clDir | Out-Null

    New-EscGateReport (Join-Path $clDir "q1.md") $clTask
    $out = & $cycleLimitPs1 -TaskId $clTask -Feature $script:EscCycleLimitFeature -ReportsDir $clDir
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -and $out -eq "continue") {
        Test-Ok "TEST-011.2: 1 gate report -> continue"
    } else {
        Test-Fail "TEST-011.2: 1 gate report did not yield continue/exit0 (rc=$rc, out=$out)"
    }

    New-EscGateReport (Join-Path $clDir "q2.md") $clTask
    $out = & $cycleLimitPs1 -TaskId $clTask -Feature $script:EscCycleLimitFeature -ReportsDir $clDir
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -and $out -eq "continue") {
        Test-Ok "TEST-011.3: 2 gate reports -> continue"
    } else {
        Test-Fail "TEST-011.3: 2 gate reports did not yield continue/exit0 (rc=$rc, out=$out)"
    }

    New-EscGateReport (Join-Path $clDir "q3.md") $clTask
    $out = & $cycleLimitPs1 -TaskId $clTask -Feature $script:EscCycleLimitFeature -ReportsDir $clDir
    $rc = $LASTEXITCODE
    if ($rc -eq 1 -and $out -eq "Escalate-Human") {
        Test-Ok "TEST-011.4: 3 gate reports -> Escalate-Human/exit1"
    } else {
        Test-Fail "TEST-011.4: 3 gate reports did not yield Escalate-Human/exit1 (rc=$rc, out=$out)"
    }
    # check-quality-gate-cycle-limit.ps1's OWN contract signals Escalate-Human
    # via exit 1 (not exit 0) -- Test-LoopTerminal hard-requires ExitCode==0
    # (fit for review-loop prechecks), so it does not apply to this script's
    # exit-code-IS-the-verdict contract. TEST-011.4 above is the direct,
    # precise assertion for this loop's Escalate-Human terminal state.

    $escTask = "T-513"
    $candidates = @("modelA:lightweight:1", "modelB:standard:2", "modelC:strong:3")

    # select-agent-model.ps1's successful (non-BLOCKED) path performs no
    # native/external command and never calls an explicit `exit N`, so
    # $LASTEXITCODE after `& $selectModelPs1 ...` is not a meaningful signal
    # here (it is left over from whatever native command last set it) --
    # tests/agent-model-routing.tests.ps1's own "runtime unavailable" leg is
    # the one place that script contract DOES guarantee a checkable exit
    # code (see TEST-013.2 below). These three legs validate the escalation
    # decision by content instead, matching that established convention.
    $outA = & $selectModelPs1 -Risk medium -Candidate $candidates `
        -PreviousTier lightweight -FailureHistory "test,test" -AttemptNumber 2 -Json
    $jA = $outA | ConvertFrom-Json
    if ($jA.escalation.next_tier -eq "standard" -and $jA.escalation.prior_tier -eq "lightweight" `
        -and $jA.escalation.failure_class -eq "test" -and $jA.escalation.attempt_number -eq 2 `
        -and $jA.escalation.reason -eq "same-classified-failure-twice" -and $jA.canonical_tier -eq "standard") {
        Test-Ok "TEST-011.5: select-agent-model.ps1 escalates lightweight->standard on a repeated failure class"
    } else {
        Test-Fail "TEST-011.5: select-agent-model.ps1 did not escalate lightweight->standard as expected (out=$outA)"
    }

    $outB = & $selectModelPs1 -Risk medium -Candidate $candidates `
        -PreviousTier standard -FailureHistory "lint,lint" -AttemptNumber 3 -Json
    $jB = $outB | ConvertFrom-Json
    if ($jB.escalation.next_tier -eq "strong" -and $jB.escalation.prior_tier -eq "standard" `
        -and $jB.escalation.failure_class -eq "lint" -and $jB.escalation.attempt_number -eq 3 `
        -and $jB.canonical_tier -eq "strong") {
        Test-Ok "TEST-011.6: select-agent-model.ps1 escalates standard->strong on a repeated failure class"
    } else {
        Test-Fail "TEST-011.6: select-agent-model.ps1 did not escalate standard->strong as expected (out=$outB)"
    }

    $outC = & $selectModelPs1 -Risk medium -Candidate $candidates `
        -PreviousTier strong -FailureHistory "build,build" -AttemptNumber 4 -Json
    $jC = $outC | ConvertFrom-Json
    if ($jC.status -eq "BLOCKED" -and $jC.reason -eq "terminal-tier-recurrence" `
        -and $null -eq $jC.escalation.next_tier -and $jC.escalation.prior_tier -eq "strong" `
        -and $jC.escalation.failure_class -eq "build" -and $jC.escalation.attempt_number -eq 4) {
        Test-Ok "TEST-011.7: select-agent-model.ps1 reports BLOCKED terminal-tier-recurrence on a strong-tier repeat (next_tier null)"
    } else {
        Test-Fail "TEST-011.7: select-agent-model.ps1 did not report terminal-tier-recurrence as expected (out=$outC)"
    }

    $blockedStateFile = Join-Path $work "terminal-tier-blocked-state.json"
    & jq -n --arg task $escTask '{schema: "terminal-tier-blocked-state/v1", task_id: $task, blocked_task_contract_sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", tier: "strong", failure_class: "build", attempt_number: 4, reason: "terminal-tier-recurrence", blocked_at: "2020-01-01T00:00:00Z"}' |
        Set-Content -LiteralPath $blockedStateFile -Encoding utf8

    $schemaCheck = & jq -e '
      (keys | sort) == (["schema","task_id","blocked_task_contract_sha256","tier","failure_class","attempt_number","reason","blocked_at"] | sort) and
      .schema == "terminal-tier-blocked-state/v1" and
      (.task_id | type == "string" and test("^T-[0-9]{3}$")) and
      (.blocked_task_contract_sha256 | type == "string" and test("^[a-f0-9]{64}$")) and
      .tier == "strong" and
      ([.failure_class] | inside(["test","lint","typecheck","build","review-major","review-critical"])) and
      (.attempt_number | type == "number" and floor == . and . >= 2) and
      .reason == "terminal-tier-recurrence" and
      (.blocked_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    ' $blockedStateFile
    if ($LASTEXITCODE -eq 0) {
        Test-Ok "TEST-011.8: terminal-tier-recurrence blocked-state artifact validates against contracts/terminal-tier-blocked-state.schema.json"
    } else {
        Test-Fail "TEST-011.8: terminal-tier-recurrence blocked-state artifact does NOT validate against the schema"
    }

    if (Test-LoopTerminal -LoopId "terminal-tier" -Observed "BLOCKED" -ExitCode 0) {
        Test-Ok "TEST-011.9: Test-LoopTerminal confirms terminal-tier's BLOCKED end state matches the loop-inventory terminal"
    } else {
        Test-Fail "TEST-011.9: Test-LoopTerminal rejected terminal-tier's BLOCKED end state"
    }

    $resumeTask = "T-512"
    $resumeRoot = New-EscTempDir "loop-escalation-resume"
    $cleanupRoots.Add($resumeRoot)

    @"
# Diagnosis

Synthetic diagnosis fixture for the T-004 loop-escalation resume leg. Not a
real diagnosis; consumed only by check-terminal-tier-resume.ps1 under a
mktemp repo-root.
"@ | Set-Content -LiteralPath (Join-Path $resumeRoot "diagnosis.md") -NoNewline -Encoding utf8
    $diagnosisSha = Get-LoopSha256 (Join-Path $resumeRoot "diagnosis.md")

    $blockedContractSha = Get-LoopSha256Text "resume-fixture-blocked-contract"
    & jq -n --arg task $resumeTask --arg contract $blockedContractSha `
        '{schema: "terminal-tier-blocked-state/v1", task_id: $task, blocked_task_contract_sha256: $contract, tier: "strong", failure_class: "test", attempt_number: 2, reason: "terminal-tier-recurrence", blocked_at: "2020-01-01T00:00:00Z"}' |
        Set-Content -LiteralPath (Join-Path $resumeRoot "blocked-state.json") -Encoding utf8
    $blockedSha = Get-LoopSha256 (Join-Path $resumeRoot "blocked-state.json")

    $approvalAuthority = "fixture-maintainer"
    $approvalTs = "2020-01-01T00:00:00Z"

    $denySection = "## $resumeTask loop-escalation resume fixture (deny leg; synthetic, not a real task)`n`nStatus: Planned"
    $denyHash = Get-LoopSha256Text $denySection
    "# Tasks (T-004 resume fixture; not a real tasks.md)`n`n$denySection`n" |
        Set-Content -LiteralPath (Join-Path $resumeRoot "tasks-deny.md") -NoNewline -Encoding utf8

    & jq -n --arg task $resumeTask --arg contract $blockedContractSha --arg revised $denyHash `
        --arg dpath "diagnosis.md" --arg dsha $diagnosisSha `
        --arg authority $approvalAuthority --arg ts $approvalTs `
        --arg bpath "blocked-state.json" --arg bsha $blockedSha `
        '{schema: "terminal-tier-resume/v1", task_id: $task, blocked_task_contract_sha256: $contract, revised_task_contract_sha256: $revised, diagnosis_reference: {path: $dpath, sha256: $dsha}, human_reapproval: {authority: $authority, timestamp: $ts}, blocked_state_reference: {path: $bpath, sha256: $bsha}}' |
        Set-Content -LiteralPath (Join-Path $resumeRoot "evidence-deny.json") -Encoding utf8

    $denyOk = Invoke-EscResume -Evidence (Join-Path $resumeRoot "evidence-deny.json") `
        -BlockedState (Join-Path $resumeRoot "blocked-state.json") -Tasks (Join-Path $resumeRoot "tasks-deny.md") `
        -RepoRoot $resumeRoot -ExpectedTask $resumeTask
    if (-not $denyOk -and $script:EscLastOutput -like "*TERMINAL_RESUME_APPROVAL*") {
        Test-Ok "TEST-011.10: check-terminal-tier-resume.ps1 denies resume when tasks.md carries no human-approval record"
    } else {
        Test-Fail "TEST-011.10: check-terminal-tier-resume.ps1 did not deny the no-approval-record fixture as expected (out=$script:EscLastOutput)"
    }

    $permitSection = "## $resumeTask loop-escalation resume fixture (permit leg; synthetic, not a real task)`n`nApproval: Approved`n`nStatus: Planned`n`nDiagnosis Reference: diagnosis.md`n`nTerminal Reapproval: $approvalAuthority @ $approvalTs"
    $permitHash = Get-LoopSha256Text $permitSection
    "# Tasks (T-004 resume fixture; not a real tasks.md)`n`n$permitSection`n" |
        Set-Content -LiteralPath (Join-Path $resumeRoot "tasks-permit.md") -NoNewline -Encoding utf8

    & jq -n --arg task $resumeTask --arg contract $blockedContractSha --arg revised $permitHash `
        --arg dpath "diagnosis.md" --arg dsha $diagnosisSha `
        --arg authority $approvalAuthority --arg ts $approvalTs `
        --arg bpath "blocked-state.json" --arg bsha $blockedSha `
        '{schema: "terminal-tier-resume/v1", task_id: $task, blocked_task_contract_sha256: $contract, revised_task_contract_sha256: $revised, diagnosis_reference: {path: $dpath, sha256: $dsha}, human_reapproval: {authority: $authority, timestamp: $ts}, blocked_state_reference: {path: $bpath, sha256: $bsha}}' |
        Set-Content -LiteralPath (Join-Path $resumeRoot "evidence-permit.json") -Encoding utf8

    $permitOk = Invoke-EscResume -Evidence (Join-Path $resumeRoot "evidence-permit.json") `
        -BlockedState (Join-Path $resumeRoot "blocked-state.json") -Tasks (Join-Path $resumeRoot "tasks-permit.md") `
        -RepoRoot $resumeRoot -ExpectedTask $resumeTask
    if ($permitOk -and $script:EscLastOutput -eq "TERMINAL_RESUME_OK") {
        Test-Ok "TEST-011.11: check-terminal-tier-resume.ps1 permits resume once tasks.md carries a matching human-approval record"
    } else {
        Test-Fail "TEST-011.11: check-terminal-tier-resume.ps1 did not permit the recorded-approval fixture as expected (out=$script:EscLastOutput)"
    }

    # -------------------------------------------------------------------
    # TEST-018 (AC-018): T-001 vs T-0010 prefix collision + substring-grep
    # mutation negative self-check
    # -------------------------------------------------------------------
    Write-Host "=== TEST-018: task-ID prefix collision (T-001 vs T-0010) + substring-grep mutation ==="

    $collisionDir = Join-Path $work "collision-reports"
    New-Item -ItemType Directory -Path $collisionDir | Out-Null
    New-EscGateReport (Join-Path $collisionDir "c1.md") "T-0010"
    New-EscGateReport (Join-Path $collisionDir "c2.md") "T-0010"
    New-EscGateReport (Join-Path $collisionDir "c3.md") "T-0010"

    $out = & $cycleLimitPs1 -TaskId "T-001" -Feature $script:EscCycleLimitFeature -ReportsDir $collisionDir
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -and $out -eq "continue") {
        Test-Ok "TEST-018.1: 3 gate reports referencing T-0010 leave the T-001 count at 0 (word-boundary match)"
    } else {
        Test-Fail "TEST-018.1: T-0010 reports incorrectly inflated the T-001 count (rc=$rc, out=$out)"
    }

    $mutatedCycleLimit = Join-Path $work "check-quality-gate-cycle-limit.mutated.ps1"
    $originalContent = Get-Content -Raw -LiteralPath $cycleLimitPs1
    $wordBoundarySnippet = '"\b" + [regex]::Escape($TaskId) + "\b"'
    $substringSnippet = '[regex]::Escape($TaskId)'
    $mutatedContent = $originalContent.Replace($wordBoundarySnippet, $substringSnippet)
    Set-Content -LiteralPath $mutatedCycleLimit -Value $mutatedContent -NoNewline -Encoding utf8
    if ($mutatedContent.Contains($substringSnippet) -and -not $mutatedContent.Contains($wordBoundarySnippet)) {
        Test-Ok "TEST-018.2: temp copy mutation replaced the word-boundary pattern with a plain substring match"
    } else {
        Test-Fail "TEST-018.2: could not construct the substring-match mutated temp copy"
    }

    $out = & $mutatedCycleLimit -TaskId "T-001" -Feature $script:EscCycleLimitFeature -ReportsDir $collisionDir
    $rc = $LASTEXITCODE
    if ($rc -eq 1 -and $out -eq "Escalate-Human") {
        Test-Ok "TEST-018.3 (negative self-check): the substring-match mutation turns the T-0010-vs-T-001 fixture red (wrongly escalates)"
    } else {
        Test-Fail "TEST-018.3 (negative self-check): the substring-match mutation did NOT turn the fixture red (rc=$rc, out=$out)"
    }

    # -------------------------------------------------------------------
    # TEST-012 (AC-012): template<->gate parity EXTENSION
    # -------------------------------------------------------------------
    Write-Host "=== TEST-012: implementation-report.template.md rendered into a loop-driver fixture, driven through the REAL quality:sdd-evaluator identity checks ==="

    $parityFeature = "loop-escalation-parity-$PID"
    $parityTask = "T-521"
    if (Initialize-LoopFixture -Profile "greenfield" -Feature $parityFeature) {
        Test-Ok "TEST-012.1: loop_fixture_init (parity-extension fixture) succeeds"
        $cleanupRoots.Add($script:LoopFixtureRoot)
    } else {
        Test-Fail "TEST-012.1: loop_fixture_init (parity-extension fixture) failed"
    }
    $parityRoot = $script:LoopFixtureRoot

    $outputPath = "docs/loop-escalation-parity-output.md"
    New-Item -ItemType Directory -Force -Path (Join-Path $parityRoot (Split-Path $outputPath -Parent)) | Out-Null
    "# Fixture output`n`nSynthetic declared output for the T-004 parity-extension leg.`n" |
        Set-Content -LiteralPath (Join-Path $parityRoot $outputPath) -NoNewline -Encoding utf8
    $outputSha = Get-LoopSha256 (Join-Path $parityRoot $outputPath)

    $decoyPath = "docs/loop-escalation-parity-decoy-output.md"
    "# Decoy output`n`nThis file is referenced only from outside the ## Outputs section.`n" |
        Set-Content -LiteralPath (Join-Path $parityRoot $decoyPath) -NoNewline -Encoding utf8
    $decoySha = Get-LoopSha256 (Join-Path $parityRoot $decoyPath)

    $workingNotes = "Fixture working notes for the T-004 parity-extension leg (see``ntests/loop-escalation.tests.ps1 TEST-012 for the full rationale).`n`n### Attempt History (decoy row; lives outside the ## Outputs section`nboundary and must NOT be treated as a declared output -- INV-014 exact-`nsection-level check)`n`n| ``$decoyPath`` | ``$decoySha`` |"

    $implReportRel = "reports/implementation/$parityFeature/$parityTask.md"
    New-Item -ItemType Directory -Force -Path (Join-Path $parityRoot (Split-Path $implReportRel -Parent)) | Out-Null
    $rendered = Get-EscRenderedTemplate -TaskId $parityTask -OutputPath $outputPath -OutputSha $outputSha -WorkingNotes $workingNotes
    Set-Content -LiteralPath (Join-Path $parityRoot $implReportRel) -Value $rendered -NoNewline -Encoding utf8

    $firstLine = (Get-Content -LiteralPath (Join-Path $parityRoot $implReportRel) -TotalCount 1)
    $hasTaskIdLine = Select-String -LiteralPath (Join-Path $parityRoot $implReportRel) -Pattern "^- Task ID: $parityTask$" -Quiet
    if ($firstLine -eq "# Implementation Report: $parityTask" -and $hasTaskIdLine) {
        Test-Ok "TEST-012.2: rendered implementation report carries the real T-NNN heading and Task ID field"
    } else {
        Test-Fail "TEST-012.2: rendered implementation report is missing the expected heading or Task ID field"
    }

    $implSha = Get-LoopSha256 (Join-Path $parityRoot $implReportRel)
    $entriesOk = & jq -n --arg p1 $implReportRel --arg s1 $implSha --arg p2 $outputPath --arg s2 $outputSha `
        '[{path: $p1, sha256: $s1}, {path: $p2, sha256: $s2}]'
    $manifestOkPath = Join-Path ([IO.Path]::GetTempPath()) ("loop-escalation-manifest." + [Guid]::NewGuid().ToString("N") + ".json")
    Get-EscQualityManifest -Feature $parityFeature -TaskId $parityTask -Entries $entriesOk |
        Set-Content -LiteralPath $manifestOkPath -Encoding utf8

    & pwsh -NoProfile -File $validatorPs1 -Manifest $manifestOkPath -RepositoryRoot $parityRoot | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Test-Ok "TEST-012.3: the REAL validate-review-context-set.ps1 accepts the rendered implementation report and its declared ## Outputs row (quality:sdd-evaluator identity checks pass)"
    } else {
        Test-Fail "TEST-012.3: the REAL validate-review-context-set.ps1 rejected the genuine rendered fixture"
    }
    Remove-Item -LiteralPath $manifestOkPath -ErrorAction SilentlyContinue

    # Negative self-check A (AC-012 core): deleting the "- Task ID:" line
    # turns it red.
    $content = Get-Content -LiteralPath (Join-Path $parityRoot $implReportRel)
    $content = $content | Where-Object { $_ -ne "- Task ID: $parityTask" }
    Set-Content -LiteralPath (Join-Path $parityRoot $implReportRel) -Value $content -Encoding utf8
    $mutSha = Get-LoopSha256 (Join-Path $parityRoot $implReportRel)
    $entriesMut = & jq -n --arg p1 $implReportRel --arg s1 $mutSha '[{path: $p1, sha256: $s1}]'
    $manifestMutPath = Join-Path ([IO.Path]::GetTempPath()) ("loop-escalation-manifest." + [Guid]::NewGuid().ToString("N") + ".json")
    Get-EscQualityManifest -Feature $parityFeature -TaskId $parityTask -Entries $entriesMut |
        Set-Content -LiteralPath $manifestMutPath -Encoding utf8

    # Spawned as a genuine child pwsh process (not in-process `&`):
    # validate-review-context-set.ps1 reports failures via
    # [Console]::Error.WriteLine, which bypasses PowerShell's own stream
    # redirection when the script runs in-process -- only a real OS-level
    # process boundary makes `2>&1` capture that text reliably.
    $out = & pwsh -NoProfile -File $validatorPs1 -Manifest $manifestMutPath -RepositoryRoot $parityRoot 2>&1
    $rc = $LASTEXITCODE
    if ($rc -ne 0 -and ($out -join "`n") -like "*REVIEW_CONTEXT_PATH*") {
        Test-Ok "TEST-012.4 (negative self-check): deleting the '- Task ID:' line turns the quality:sdd-evaluator identity check red"
    } else {
        Test-Fail "TEST-012.4 (negative self-check): deleting the '- Task ID:' line did NOT turn the check red as expected (rc=$rc, out=$out)"
    }
    Remove-Item -LiteralPath $manifestMutPath -ErrorAction SilentlyContinue

    # Negative self-check B (INV-014 exact-section-level): a decoy row that
    # exists in the document but OUTSIDE the literal ## Outputs section
    # boundary must NOT be treated as a declared output.
    $entriesDecoy = & jq -n --arg p1 $implReportRel --arg s1 $mutSha --arg p2 $decoyPath --arg s2 $decoySha `
        '[{path: $p1, sha256: $s1}, {path: $p2, sha256: $s2}]'
    $manifestDecoyPath = Join-Path ([IO.Path]::GetTempPath()) ("loop-escalation-manifest." + [Guid]::NewGuid().ToString("N") + ".json")
    Get-EscQualityManifest -Feature $parityFeature -TaskId $parityTask -Entries $entriesDecoy |
        Set-Content -LiteralPath $manifestDecoyPath -Encoding utf8

    $out = & pwsh -NoProfile -File $validatorPs1 -Manifest $manifestDecoyPath -RepositoryRoot $parityRoot 2>&1
    $rc = $LASTEXITCODE
    if ($rc -ne 0 -and ($out -join "`n") -like "*REVIEW_CONTEXT_PATH*") {
        Test-Ok "TEST-012.5 (negative self-check, INV-014): a | path | sha256 | row outside the ## Outputs section boundary is NOT authorized as a declared output"
    } else {
        Test-Fail "TEST-012.5 (negative self-check, INV-014): the outside-section decoy row was incorrectly authorized (rc=$rc, out=$out)"
    }
    Remove-Item -LiteralPath $manifestDecoyPath -ErrorAction SilentlyContinue

    # -------------------------------------------------------------------
    # TEST-013 (AC-013): python3-absent / deterministic-runtime-unavailable
    # degradation
    # -------------------------------------------------------------------
    Write-Host "=== TEST-013: deterministic-runtime-unavailable degradation ==="

    Write-Host "SKIP: TEST-013.1: check-terminal-tier-resume.ps1 has no external deterministic-runtime dependency (pure PowerShell reimplementation) -- INV-017 cites only check-terminal-tier-resume.sh:29-32; this leg does not apply on the pwsh lane"

    $out = & $selectModelPs1 -Risk low -DeterministicRuntimeCommand "sdd-runtime-that-does-not-exist"
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -and $out -eq "BLOCKED deterministic-runtime-unavailable") {
        Write-Host "SKIP: TEST-013.2: select-agent-model.ps1 reports deterministic-runtime-unavailable when its deterministic-runtime command is unavailable (INV-017 analogue); recorded degradation"
    } else {
        Test-Fail "TEST-013.2: select-agent-model.ps1 did not report deterministic-runtime-unavailable as expected (rc=$rc, out=$out)"
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
    Write-Host "loop-escalation.tests.ps1: $script:Pass passed, $script:Fail failed, ${elapsedSeconds}s elapsed"
    if ($script:Fail -ne 0) { exit 1 }
    exit 0
} finally {
    Invoke-Cleanup
}
