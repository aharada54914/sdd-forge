# Regression - PowerShell twin of emit-run-record-feature-scope.tests.sh,
# equivalent in coverage. emit-run-record.ps1 must scope gate_reports and
# review_tickets to the target feature; task IDs (T-NNN) collide across
# features, so a repo-wide scan misattributes other features' gate reports,
# BLOCKED verdicts, and ticket severities to the run record.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/emit-run-record.ps1"

$work = Join-Path ([IO.Path]::GetTempPath()) ("emit-run-record-scope-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $work | Out-Null

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

try {
    # --- Fixture repo: feat-a (target) interleaved with feat-b (excluded) ---
    New-Item -ItemType Directory -Force -Path (Join-Path $work "specs/feat-a") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $work "reports/quality-gate") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $work "docs/review-tickets") | Out-Null

    Set-Content -Encoding Utf8 (Join-Path $work "specs/feat-a/tasks.md") @"
## T-001 first task
Status: Done

## T-002 second task
Status: Done
"@

    # feat-a: T-001 gated twice (max_runs_single_task = 2), both PASS.
    Set-Content -Encoding Utf8 (Join-Path $work "reports/quality-gate/a-t001-run1.md") "Task: T-001`nFeature: feat-a`nVERDICT: PASS`n"
    Set-Content -Encoding Utf8 (Join-Path $work "reports/quality-gate/a-t001-run2.md") "Task: T-001`nFeature: feat-a`nVERDICT: PASS`n"

    # feat-a: T-002 gated once, with CRLF line endings to guard the Feature-line
    # match's trailing-whitespace tolerance.
    [IO.File]::WriteAllText((Join-Path $work "reports/quality-gate/a-t002-run1.md"), "Task: T-002`r`nFeature: feat-a`r`nVERDICT: PASS`r`n")

    # feat-b: same bare id T-002 and a BLOCKED verdict; must not touch feat-a.
    Set-Content -Encoding Utf8 (Join-Path $work "reports/quality-gate/b-t002-run1.md") "Task: T-002`nFeature: feat-b`nVERDICT: BLOCKED`nBLOCKED`n"

    # feat-a: exactly one review ticket, severity major.
    Set-Content -Encoding Utf8 (Join-Path $work "docs/review-tickets/RT-a.yml") @"
ticket_id: RT-a
status: open
severity: major
target:
  feature: feat-a
  task: T-002
"@

    # feat-b: a critical ticket that must not be attributed to feat-a.
    Set-Content -Encoding Utf8 (Join-Path $work "docs/review-tickets/RT-b.yml") @"
ticket_id: RT-b
status: open
severity: critical
target:
  feature: feat-b
  task: T-002
"@

    # feat-a: CRLF ticket -- severity must still be counted despite `r`n endings.
    [System.IO.File]::WriteAllText(
        (Join-Path $work "docs/review-tickets/RT-c.yml"),
        "ticket_id: RT-c`r`nstatus: open`r`nseverity: minor`r`ntarget:`r`n  feature: feat-a`r`n  task: T-001`r`n")

    # --- Run the emitter from the fixture repo root --------------------------
    Push-Location $work
    try {
        & pwsh -NoProfile -File $script -Feature feat-a -Track lite | Out-Null
    } finally {
        Pop-Location
    }

    $out = Get-ChildItem (Join-Path $work "reports/runs") -Filter "RUN-*-feat-a.json" | Select-Object -First 1
    if (-not $out) {
        Fail "emit-run-record produced no run record for feat-a"
    } else {
        $record = Get-Content -Raw -Encoding Utf8 $out.FullName | ConvertFrom-Json
        $m = $record.metrics

        function AssertEq($got, $expected, $label) {
            if ("$got" -eq "$expected") { Ok "$label ($got)" }
            else { Fail "${label}: got $got, expected $expected" }
        }

        AssertEq $m.gate_reports.total                3 "gate_reports.total counts only feat-a reports"
        AssertEq $m.gate_reports.blocked              0 "feat-b's BLOCKED report is not counted for feat-a"
        AssertEq $m.gate_reports.max_runs_single_task 2 "max_runs_single_task reflects feat-a T-001 gated twice"
        AssertEq $m.first_pass_gate.passed_first_try  1 "only feat-a T-002 passed on a single gate run"
        AssertEq $m.review_tickets.major              1 "review_tickets.major counts only feat-a tickets"
        AssertEq $m.review_tickets.critical           0 "feat-b's critical ticket is not counted for feat-a"
        AssertEq $m.review_tickets.minor              1 "CRLF feat-a ticket severity is counted"
    }

    # ========================================================================
    # T-004 (#153): sdd-run-record/v2 effort attribution + degradation lock
    # (REQ-004; AC-021..026, AC-051; security-spec.md B4). Each scenario uses
    # its own uniquely-named feature slug so RUN-<UTC-second>-<feature>.json
    # filenames never collide within the same second. Native ConvertFrom-Json
    # is used throughout (not subject to the jq.exe CRLF hazard).
    # ========================================================================

    function EmitFixture([string]$Slug) {
        New-Item -ItemType Directory -Force -Path (Join-Path $work "specs/$Slug") | Out-Null
        Set-Content -Encoding Utf8 (Join-Path $work "specs/$Slug/tasks.md") "## T-001 only task`nStatus: Done`n"
    }

    function RunEmit {
        param([string]$Slug, [string[]]$ExtraArgs = @())
        EmitFixture $Slug
        Push-Location $work
        try {
            $combined = & pwsh -NoProfile -File $script -Feature $Slug -Track lite @ExtraArgs 2>&1
            $script:runExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $script:runOutputText = ($combined | Out-String)
        $found = Get-ChildItem (Join-Path $work "reports/runs") -Filter "RUN-*-$Slug.json" -ErrorAction SilentlyContinue | Select-Object -First 1
        $script:runRecord = $null
        if ($found) {
            $script:runRecord = Get-Content -Raw -Encoding Utf8 $found.FullName | ConvertFrom-Json
        }
    }

    # --- AC-021 (TEST-021): schema bump + additive fields, v1 fields unchanged
    RunEmit "feat-e021" @("-EffortMain", "high", "-EffortControlMain", "flag", "-EffortAppliedMain", "high")
    if ($runExit -eq 0 -and $runRecord) {
        AssertEq $runRecord.schema "sdd-run-record/v2" "AC-021: schema bumps to v2 when any -Effort* param bound"
        AssertEq $runRecord.feature "feat-e021" "AC-021: v1 field feature unchanged in v2 shape"
        AssertEq $runRecord.track "lite" "AC-021: v1 field track unchanged in v2 shape"
        AssertEq $runRecord.model_ids.main "unknown" "AC-021: v1 field model_ids.main unchanged in v2 shape"
        $mainKeys = ($runRecord.effort.main.PSObject.Properties.Name | Sort-Object) -join ","
        AssertEq $mainKeys "effort_applied,effort_degraded_reason,effort_requested" "AC-021: effort.main has exactly the three subfields"
        $reviewersKeys = ($runRecord.effort.reviewers.PSObject.Properties.Name | Sort-Object) -join ","
        AssertEq $reviewersKeys "effort_applied,effort_degraded_reason,effort_requested" "AC-021: effort.reviewers has exactly the three subfields"
        AssertEq $runRecord.metrics.tasks.total 1 "AC-021: v1 metrics object unchanged in v2 shape"
    } else {
        Fail "AC-021 setup: emit-run-record did not produce a run record (exit=$runExit)"
    }

    # --- AC-022 (TEST-022): effort_requested recorded whenever its flag is
    #     supplied, regardless of host/outcome. -------------------------------
    RunEmit "feat-e022" @("-EffortMain", "high", "-EffortControlMain", "flag", "-EffortAppliedMain", "high")
    if ($runExit -eq 0 -and $runRecord -and $runRecord.effort.main.effort_requested -ceq "high") {
        Ok "AC-022: effort_requested recorded on confirmed-applied outcome"
    } else {
        Fail "AC-022: effort_requested missing on confirmed-applied outcome"
    }

    RunEmit "feat-e022b" @("-EffortMain", "high", "-EffortControlMain", "frontmatter")
    if ($runExit -eq 0 -and $runRecord -and $runRecord.effort.main.effort_requested -ceq "high") {
        Ok "AC-022: effort_requested recorded on degraded (frontmatter) outcome"
    } else {
        Fail "AC-022: effort_requested missing on degraded (frontmatter) outcome"
    }

    # --- AC-023 (TEST-023): effort_applied non-null iff effort_control
    #     resolved to flag AND application was confirmed; null otherwise. ----
    RunEmit "feat-e023" @("-EffortMain", "high", "-EffortControlMain", "flag", "-EffortAppliedMain", "high")
    if ($runExit -eq 0 -and $runRecord.effort.main.effort_applied -ceq "high") {
        Ok "AC-023 positive: effort_applied carries the confirmed value under flag control"
    } else {
        Fail "AC-023 positive: effort_applied did not carry the confirmed value"
    }

    foreach ($control in @("frontmatter", "none")) {
        RunEmit "feat-e023-$control" @("-EffortMain", "high", "-EffortControlMain", $control)
        if ($runExit -eq 0 -and $null -eq $runRecord.effort.main.effort_applied) {
            Ok "AC-023 negative: effort_applied is null under $control control"
        } else {
            Fail "AC-023 negative: effort_applied is not null under $control control"
        }
    }

    RunEmit "feat-e023-declined" @("-EffortMain", "high", "-EffortControlMain", "flag", "-EffortAppliedMain", "none")
    if ($runExit -eq 0 -and $null -eq $runRecord.effort.main.effort_applied) {
        Ok "AC-023 negative: effort_applied is null when flag control declines application (none sentinel)"
    } else {
        Fail "AC-023 negative: effort_applied is not null on explicit decline"
    }

    # Structural enforcement (security-spec.md B4): a caller cannot report a
    # confirmed-applied value unless the paired control resolved to flag.
    RunEmit "feat-e023-reject" @("-EffortMain", "high", "-EffortControlMain", "frontmatter", "-EffortAppliedMain", "high")
    if ($runExit -ne 0 -and $runOutputText -like '*requires the paired -EffortControl* to resolve to "flag"*') {
        Ok "AC-023 structural: -EffortAppliedMain with non-flag control is rejected fail-closed"
    } else {
        Fail "AC-023 structural: rejection diagnostic missing/unexpected (exit=$runExit): $runOutputText"
    }

    # --- AC-024 (TEST-024): effort_degraded_reason populated iff
    #     effort_applied is null AND its role slot's flag was supplied (both
    #     directions locked; the vacuous case must NOT populate a reason). ---
    RunEmit "feat-e024-applied" @("-EffortMain", "high", "-EffortControlMain", "flag", "-EffortAppliedMain", "high")
    if ($null -eq $runRecord.effort.main.effort_degraded_reason) {
        Ok "AC-024 direction 1: effort_degraded_reason is null when effort_applied carries a value"
    } else {
        Fail "AC-024 direction 1: effort_degraded_reason unexpectedly populated alongside a real effort_applied"
    }

    RunEmit "feat-e024-degraded" @("-EffortMain", "high", "-EffortControlMain", "frontmatter")
    $reason = $runRecord.effort.main.effort_degraded_reason
    if ($null -ne $reason -and $reason -ne "") {
        Ok "AC-024 direction 2: effort_degraded_reason is non-empty when effort_applied is null and a flag was supplied ($reason)"
    } else {
        Fail "AC-024 direction 2: effort_degraded_reason is empty/null despite a supplied -EffortMain flag"
    }

    RunEmit "feat-e024-vacuous" @("-EffortControlMain", "flag")
    if ($null -eq $runRecord.effort.main.effort_requested -and $null -eq $runRecord.effort.main.effort_degraded_reason) {
        Ok "AC-024 vacuity: no reason recorded when -EffortMain itself was never supplied for that slot"
    } else {
        Fail "AC-024 vacuity: a reason was recorded despite -EffortMain never being supplied"
    }

    # --- AC-051 (TEST-051): host-independent degradation lock -- emit-run-record
    #     has no host concept at all; a "Codex host selecting a non-flag-control
    #     model" scenario and a "Claude Code" scenario both resolve through the
    #     identical -EffortControl* value, proving the null+reason shape is
    #     keyed on the resolved effort_control value, never on host identity.
    RunEmit "feat-e051-claude" @("-EffortMain", "high", "-EffortControlMain", "frontmatter")
    $claudeApplied = $runRecord.effort.main.effort_applied
    $claudeReason = $runRecord.effort.main.effort_degraded_reason
    RunEmit "feat-e051-codex" @("-EffortMain", "high", "-EffortControlMain", "frontmatter")
    $codexApplied = $runRecord.effort.main.effort_applied
    $codexReason = $runRecord.effort.main.effort_degraded_reason
    if (($null -eq $claudeApplied) -and ($null -eq $codexApplied) -and ($claudeReason -ceq $codexReason)) {
        Ok "AC-051: a Codex-host scenario with a non-flag effort_control degrades identically in shape to Claude Code ($codexReason)"
    } else {
        Fail "AC-051: Codex-host non-flag-control shape ($codexApplied/$codexReason) diverged from Claude Code shape ($claudeApplied/$claudeReason)"
    }

    RunEmit "feat-e051-codex-none" @("-EffortMain", "high", "-EffortControlMain", "none")
    if (($null -eq $runRecord.effort.main.effort_applied) -and ($runRecord.effort.main.effort_degraded_reason -ceq "effort-control-none")) {
        Ok "AC-051: Codex-host model with effort_control none also degrades (reason keyed on the resolved control value)"
    } else {
        Fail "AC-051: Codex-host model with effort_control none did not degrade as expected"
    }

    # PowerShell case-sensitivity twin discipline, layer 1 (ordinal HashSet
    # entry gate) + layer 2 (-ceq branch dispatch in Resolve-EffortSlot): a
    # mis-cased -EffortControlMain value must be rejected fail-closed, never
    # silently aliased to its lowercase form by PowerShell's default
    # case-insensitive comparison.
    RunEmit "feat-e-miscased" @("-EffortControlMain", "Flag")
    if ($runExit -ne 0 -and $runOutputText -like "*must be one of flag|frontmatter|none*") {
        Ok "case-sensitivity: mis-cased -EffortControlMain value is rejected fail-closed"
    } else {
        Fail "case-sensitivity: unexpected result for mis-cased value (exit=$runExit): $runOutputText"
    }

    # --- AC-025 (TEST-025): backward compatibility -- the no-flags code path
    #     stays byte-identical to every pre-feature invocation (v1 shape, no
    #     "effort" key), and an EXISTING, already-committed pre-feature v1
    #     record (never rewritten by this task) still carries schema v1. -----
    RunEmit "feat-e025" @()
    AssertEq $runRecord.schema "sdd-run-record/v1" "AC-025: no -Effort* param bound emits v1 schema, unchanged"
    $hasEffort = [bool]($runRecord.PSObject.Properties.Name -contains "effort")
    AssertEq $hasEffort $false "AC-025: v1 shape has no effort key at all"

    $preFeatureV1Record = Join-Path $repoRoot "reports/runs/RUN-20260705T023011Z-sdd-forge-mcp.json"
    if (Test-Path $preFeatureV1Record) {
        $preRecord = Get-Content -Raw -Encoding Utf8 $preFeatureV1Record | ConvertFrom-Json
        $preHasEffort = [bool]($preRecord.PSObject.Properties.Name -contains "effort")
        if ($preRecord.schema -ceq "sdd-run-record/v1" -and -not $preHasEffort) {
            Ok "AC-025: a real, already-committed pre-feature v1 record still validates as schema v1 (untouched by this task)"
        } else {
            Fail "AC-025: the pre-feature v1 record fixture no longer reads as schema v1"
        }
    } else {
        Fail "AC-025 setup: expected pre-feature v1 record fixture not found: $preFeatureV1Record"
    }

    # --- AC-026 (TEST-026): document conformance -- report template,
    #     validator, and quality-gate SKILL.md all carry the Model/Effort
    #     requirement. ----------------------------------------------------
    $template = Join-Path $repoRoot "plugins/sdd-implementation/templates/implementation-report.template.md"
    $validator = Join-Path $repoRoot "plugins/sdd-implementation/scripts/validate-implementation-report.sh"
    $gateSkill = Join-Path $repoRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"

    $templateText = Get-Content -Raw -Encoding Utf8 $template
    if (($templateText | Select-String -CaseSensitive -SimpleMatch '- Model: {{model}}') -and
        ($templateText | Select-String -CaseSensitive -SimpleMatch '- Effort: {{effort}}')) {
        Ok "AC-026: implementation-report.template.md carries the Model/Effort lines"
    } else {
        Fail "AC-026: implementation-report.template.md is missing the Model/Effort lines"
    }

    $validatorText = Get-Content -Raw -Encoding Utf8 $validator
    if ($validatorText | Select-String -CaseSensitive -SimpleMatch 'top_level_label in ("Model", "Effort")') {
        Ok "AC-026: validate-implementation-report.sh checks the Model/Effort lines"
    } else {
        Fail "AC-026: validate-implementation-report.sh does not check the Model/Effort lines"
    }

    $gateSkillText = Get-Content -Raw -Encoding Utf8 $gateSkill
    if ($gateSkillText | Select-String -CaseSensitive -SimpleMatch '`- Model:` / `- Effort:`') {
        Ok "AC-026: quality-gate SKILL.md documents the Model/Effort Process instruction"
    } else {
        Fail "AC-026: quality-gate SKILL.md is missing the Model/Effort Process instruction"
    }

    $validatorFixtureDir = Join-Path $work "validator-fixtures"
    New-Item -ItemType Directory -Force -Path $validatorFixtureDir | Out-Null
    $validFixture = Join-Path $validatorFixtureDir "valid.md"
    Set-Content -Encoding Utf8 $validFixture @"
# Implementation Report: T-999

- Model: anthropic/opus
- Effort: high

Report Schema: implementation-report/v2

## Output Paths And Hashes

- **Path**: ``plugins/example.md``; **SHA-256**: ``aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa``

## Test Evidence

- **Test Command**: ``bash tests/example.tests.sh``
- **Test Result**: PASS
- **Test Evidence Path**: ``specs/example/verification/T-999/green.log``

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: run-999
- **Session ID**: session-999
- **Agent Instance ID**: agent-999
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Unresolved Items

None.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality review
- **Unresolved Items**: None
"@

    & bash $validator $validFixture *> $null
    if ($LASTEXITCODE -eq 0) {
        Ok "AC-026: validator accepts a report carrying well-formed Model/Effort lines"
    } else {
        Fail "AC-026: validator rejected a report with well-formed Model/Effort lines"
    }

    $missingModelFixture = Join-Path $validatorFixtureDir "missing-model.md"
    (Get-Content -Raw -Encoding Utf8 $validFixture) -replace "(?m)^- Model: anthropic/opus\r?\n", "" |
        Set-Content -Encoding Utf8 $missingModelFixture
    $missingModelOutput = & bash $validator $missingModelFixture 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and $missingModelOutput -like "*missing or invalid Model*") {
        Ok "AC-026: validator rejects a report missing the Model line"
    } else {
        Fail "AC-026: validator did not reject a report missing the Model line (exit=$LASTEXITCODE): $missingModelOutput"
    }

    $missingEffortFixture = Join-Path $validatorFixtureDir "missing-effort.md"
    (Get-Content -Raw -Encoding Utf8 $validFixture) -replace "(?m)^- Effort: high\r?\n", "" |
        Set-Content -Encoding Utf8 $missingEffortFixture
    $missingEffortOutput = & bash $validator $missingEffortFixture 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and $missingEffortOutput -like "*missing or invalid Effort*") {
        Ok "AC-026: validator rejects a report missing the Effort line"
    } else {
        Fail "AC-026: validator did not reject a report missing the Effort line (exit=$LASTEXITCODE): $missingEffortOutput"
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "emit-run-record-feature-scope.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
