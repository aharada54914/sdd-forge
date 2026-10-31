# lite-gate-summary-absent-active-enforcement.tests.ps1
# (epic-194-a6-lite-integration, T-004, design.md Test Strategy item 15,
# TEST-030). PowerShell twin of
# lite-gate-summary-absent-active-enforcement.tests.sh.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $RepoRoot 'tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.ps1')
$Skill = Join-Path $RepoRoot 'plugins/sdd-lite/skills/lite-gate/SKILL.md'

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t004-aae-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

try {
    Write-Host '=== TEST-030a: active capability_enforcement, no Summary at all -> VERDICT: FAIL ==='
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'does-not-exist.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL') { Ok 'TEST-030a: required enforcement + absent Summary is VERDICT: FAIL' } else { Bad "TEST-030a: expected FAIL, got $($r.Verdict)" }
    if ($r.Reason -eq 'capability-summary.yaml missing under active capability_enforcement') { Ok 'TEST-030a: reason names active capability_enforcement specifically' } else { Bad "TEST-030a: unexpected reason: $($r.Reason)" }

    Write-Host '=== TEST-030b: advisory enforcement, no Summary at all -> also VERDICT: FAIL ==='
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'still-does-not-exist.json') -Enforcement 'advisory' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL') { Ok 'TEST-030b: advisory enforcement + absent Summary is also VERDICT: FAIL' } else { Bad "TEST-030b: expected FAIL, got $($r.Verdict)" }

    Write-Host '=== TEST-030c: disabled-legacy (distinct case) is NOT a failure ==='
    $r = Invoke-LiteGateStep2Simulation -SummaryPath '' -Enforcement 'none' -RepoRoot $Work
    if ($r.Verdict -eq 'PASS') { Ok 'TEST-030c: disabled-legacy is legitimate, VERDICT: PASS -- distinct from TEST-030a/b' } else { Bad "TEST-030c: disabled-legacy should be PASS, got $($r.Verdict) ($($r.Reason))" }

    Write-Host '=== TEST-030d: present-but-empty Summary is a pass-through ==='
    Set-Content -LiteralPath (Join-Path $Work 'present-empty.json') -Value '{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":[],"required_lite_checks":[],"full_upgrade_required":false}' -NoNewline
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'present-empty.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'PASS') { Ok 'TEST-030d: present-but-empty Summary passes through, VERDICT: PASS' } else { Bad "TEST-030d: expected PASS, got $($r.Verdict) ($($r.Reason))" }

    Write-Host '=== TEST-030e: SKILL.md text -- missing-Summary-under-active-enforcement stays VERDICT: FAIL ==='
    $skillContent = Get-Content -LiteralPath $Skill -Raw
    if ($skillContent -match 'VERDICT: FAIL.*capability-summary\.yaml missing under active capability_enforcement') {
        Ok "TEST-030e: SKILL.md's own missing-Summary branch still reads VERDICT: FAIL"
    } else {
        Bad "TEST-030e: SKILL.md's missing-Summary branch no longer reads VERDICT: FAIL (Blocker [B6] regression)"
    }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
