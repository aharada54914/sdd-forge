# lite-gate-summary-absent.tests.ps1 (epic-194-a6-lite-integration, T-004,
# design.md Test Strategy item 8, TEST-011). PowerShell twin of
# lite-gate-summary-absent.tests.sh.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $RepoRoot 'tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.ps1')

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t004-abs-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

try {
    Write-Host '=== TEST-011: disabled-legacy (no Project Context, no Summary) runs unchanged ==='
    $r = Invoke-LiteGateStep2Simulation -SummaryPath '' -Enforcement 'none' -RepoRoot $Work
    if ($r.Verdict -eq 'PASS') { Ok 'TEST-011a: disabled-legacy VERDICT: PASS' } else { Bad "TEST-011a: expected PASS, got $($r.Verdict) ($($r.Reason))" }
    if (@($r.RanChecks).Count -eq 0) { Ok 'TEST-011b: no Registry-sourced command-discovery attempted' } else { Bad "TEST-011b: expected no discovery, got [$($r.RanChecks -join ',')]" }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
