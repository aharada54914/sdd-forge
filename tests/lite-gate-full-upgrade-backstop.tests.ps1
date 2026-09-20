# lite-gate-full-upgrade-backstop.tests.ps1 (epic-194-a6-lite-integration,
# T-004, design.md Test Strategy item 12, TEST-026). PowerShell twin of
# lite-gate-full-upgrade-backstop.tests.sh.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $RepoRoot 'tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.ps1')
$Skill = Join-Path $RepoRoot 'plugins/sdd-lite/skills/lite-gate/SKILL.md'

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t004-fub-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

try {
    Write-Host '=== TEST-026a: full_upgrade_required: true Blocks before Step 2b runs ==='
    Set-Content -LiteralPath (Join-Path $Work 'full-upgrade.json') -Value '{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":["totally-unmapped-check"],"full_upgrade_required":true}' -NoNewline
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'full-upgrade.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL') { Ok 'TEST-026a: VERDICT: FAIL' } else { Bad "TEST-026a: expected FAIL, got $($r.Verdict)" }
    if ($r.Reason -eq 'full_upgrade_required: true') { Ok 'TEST-026a: reason names full_upgrade_required specifically (proves Step 2b never ran)' } else { Bad "TEST-026a: expected the full_upgrade_required reason, got: $($r.Reason)" }
    if (@($r.RanChecks).Count -eq 0) { Ok 'TEST-026a: no check-discovery was attempted (Step 2b never reached)' } else { Bad "TEST-026a: Step 2b should never have run, but discovery was attempted: $($r.RanChecks -join ',')" }

    Write-Host '=== TEST-026b: full_upgrade_required: false continues normally ==='
    Set-Content -LiteralPath (Join-Path $Work 'no-full-upgrade.json') -Value '{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":["build"],"full_upgrade_required":false}' -NoNewline
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'no-full-upgrade.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'PASS') { Ok 'TEST-026b: full_upgrade_required: false continues, VERDICT: PASS' } else { Bad "TEST-026b: expected PASS, got $($r.Verdict) ($($r.Reason))" }

    Write-Host '=== TEST-026c: SKILL.md text -- full_upgrade_required: true backstop stays VERDICT: FAIL ==='
    $skillContent = Get-Content -LiteralPath $Skill -Raw
    if ($skillContent -match 'full_upgrade_required == true.*VERDICT: FAIL') {
        Ok "TEST-026c: SKILL.md's own Step 2a backstop clause still reads VERDICT: FAIL on full_upgrade_required == true"
    } else {
        Bad "TEST-026c: SKILL.md's Step 2a backstop clause no longer FAILs on full_upgrade_required == true (Blocker [B2] regression)"
    }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
