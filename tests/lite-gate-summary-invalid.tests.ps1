# lite-gate-summary-invalid.tests.ps1 (epic-194-a6-lite-integration,
# T-004, design.md Test Strategy item 9, TEST-012/TEST-013). PowerShell
# twin of lite-gate-summary-invalid.tests.sh.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $RepoRoot 'tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.ps1')
$Skill = Join-Path $RepoRoot 'plugins/sdd-lite/skills/lite-gate/SKILL.md'

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t004-inv-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

try {
    Write-Host '=== TEST-012a: wrong schema constant is VERDICT: FAIL ==='
    Set-Content -LiteralPath (Join-Path $Work 'wrong-schema.json') -Value '{"schema":"not-the-right-schema","feature":"demo","track":"lite","capabilities":[],"required_lite_checks":[],"full_upgrade_required":false}' -NoNewline
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'wrong-schema.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL') { Ok 'TEST-012a: wrong schema constant is VERDICT: FAIL' } else { Bad "TEST-012a: expected FAIL, got $($r.Verdict)" }

    Write-Host '=== TEST-012b: missing a required key is VERDICT: FAIL ==='
    Set-Content -LiteralPath (Join-Path $Work 'missing-key.json') -Value '{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":[]}' -NoNewline
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'missing-key.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL') { Ok 'TEST-012b: missing required keys is VERDICT: FAIL' } else { Bad "TEST-012b: expected FAIL, got $($r.Verdict)" }

    Write-Host '=== TEST-012c: wrong-type field is VERDICT: FAIL ==='
    Set-Content -LiteralPath (Join-Path $Work 'wrong-type.json') -Value '{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":[],"required_lite_checks":[],"full_upgrade_required":"true"}' -NoNewline
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'wrong-type.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL') { Ok 'TEST-012c: non-boolean full_upgrade_required is VERDICT: FAIL' } else { Bad "TEST-012c: expected FAIL, got $($r.Verdict)" }

    Write-Host '=== TEST-013: static review -- no per-Capability re-aggregation logic ==='
    $skillContent = Get-Content -LiteralPath $Skill -Raw
    if ($skillContent.Contains('横断で再集約しない')) { Ok 'TEST-013a: Boundaries explicitly disclaims cross-Capability re-aggregation' } else { Bad 'TEST-013a: expected Boundaries to disclaim cross-Capability re-aggregation' }
    if ($skillContent.Contains('A5 の Resolver が既に書いた')) { Ok 'TEST-013b: text confirms the field is read as already-aggregated' } else { Bad 'TEST-013b: expected text confirming the already-aggregated-field read' }
    if ($skillContent -match '(実行する|呼び出す|呼ぶ)[^。]*(evaluate-predicate|registry[_-]match)') {
        Bad 'TEST-013c: lite-gate/SKILL.md must not itself invoke Predicate-DSL/Registry-matching logic'
    } else {
        Ok 'TEST-013c: no Predicate-DSL/Registry-matching invocation found (disclaimed, not called)'
    }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
