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
        AssertEq $m.review_tickets.minor              0 "no feat-a minor tickets"
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "emit-run-record-feature-scope.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
