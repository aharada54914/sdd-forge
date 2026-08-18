# check-risk-upgrade-ineligible-no-reasons.tests.ps1
# (epic-194-a6-lite-integration, T-002, design.md Test Strategy item 14,
# TEST-014, AC-028, Blocker [B4]). PowerShell twin of
# check-risk-upgrade-ineligible-no-reasons.tests.sh -- see that file's
# header for the canonical staged human-copy SUT-path note.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Sut = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.ps1'
$PowerShell = (Get-Process -Id $PID).Path

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t002-inr-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

function Invoke-Sut([string]$FragmentPath) {
    $output = & $PowerShell -NoProfile -File $Sut -Path (Join-Path $Work 'clean.txt') -CapabilityReasons $FragmentPath 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

try {
    Set-Content -LiteralPath (Join-Path $Work 'clean.txt') -Value 'a clean source with no keyword trigger.' -NoNewline

    Write-Host '=== TEST-014a: eligible:false, upgrade_reasons key absent ==='
    Set-Content -LiteralPath (Join-Path $Work 'absent.json') -Value '{"capabilities": [{"id": "no-reasons-key-cap", "eligible": false}]}' -NoNewline
    $r1 = Invoke-Sut (Join-Path $Work 'absent.json')
    if ($r1.ExitCode -eq 10) { Ok 'TEST-014a: exits 10' } else { Bad "TEST-014a: expected exit 10, got $($r1.ExitCode). Output: $($r1.Output)" }
    if ($r1.Output -eq 'full-required: ineligible:no-reasons-key-cap; triggers=ineligible:no-reasons-key-cap') { Ok 'TEST-014a: synthetic ineligible:<id> token produced' } else { Bad "TEST-014a: unexpected output: $($r1.Output)" }

    Write-Host '=== TEST-014b: eligible:false, upgrade_reasons is an empty array ==='
    Set-Content -LiteralPath (Join-Path $Work 'empty-array.json') -Value '{"capabilities": [{"id": "empty-reasons-cap", "eligible": false, "upgrade_reasons": []}]}' -NoNewline
    $r2 = Invoke-Sut (Join-Path $Work 'empty-array.json')
    if ($r2.ExitCode -eq 10) { Ok 'TEST-014b: exits 10' } else { Bad "TEST-014b: expected exit 10, got $($r2.ExitCode). Output: $($r2.Output)" }
    if ($r2.Output -eq 'full-required: ineligible:empty-reasons-cap; triggers=ineligible:empty-reasons-cap') { Ok 'TEST-014b: synthetic ineligible:<id> token produced for an explicit empty array too' } else { Bad "TEST-014b: unexpected output: $($r2.Output)" }

    Write-Host '=== TEST-014c: mixed no-reasons + has-reasons entries, both contribute ==='
    Set-Content -LiteralPath (Join-Path $Work 'mixed.json') -Value '{"capabilities": [{"id": "no-reasons-cap", "eligible": false}, {"id": "has-reasons-cap", "eligible": false, "upgrade_reasons": ["explicit_reason"]}]}' -NoNewline
    $r3 = Invoke-Sut (Join-Path $Work 'mixed.json')
    if ($r3.ExitCode -eq 10) { Ok 'TEST-014c: exits 10' } else { Bad "TEST-014c: expected exit 10, got $($r3.ExitCode). Output: $($r3.Output)" }
    if ($r3.Output -eq 'full-required: ineligible:no-reasons-cap; triggers=ineligible:no-reasons-cap,explicit_reason') { Ok "TEST-014c: no-reasons entry's synthetic token appears in its own array position" } else { Bad "TEST-014c: unexpected output: $($r3.Output)" }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
