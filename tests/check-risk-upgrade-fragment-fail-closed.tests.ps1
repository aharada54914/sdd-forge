# check-risk-upgrade-fragment-fail-closed.tests.ps1
# (epic-194-a6-lite-integration, T-002, design.md Test Strategy item 13,
# TEST-013, AC-027, Blocker [B3]). PowerShell twin of
# check-risk-upgrade-fragment-fail-closed.tests.sh -- see that file's header
# for the interim SUT-path note.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Sut = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/human-copy/PROPOSED/check-risk-upgrade.ps1.PROPOSED'
$PowerShell = (Get-Process -Id $PID).Path

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t002-fc-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

function Assert-FragmentInvalid([string]$Label, [string]$FragmentPath) {
    $cleanPath = Join-Path $Work 'clean.txt'
    $output = & $PowerShell -NoProfile -File $Sut -Path $cleanPath -CapabilityReasons $FragmentPath 2>&1
    $exitCode = $LASTEXITCODE
    $joined = ($output -join "`n")
    if ($exitCode -eq 2) { Ok "$Label`: exits 2" } else { Bad "$Label`: expected exit 2, got $exitCode. Output: $joined" }
    if ($joined -eq 'risk-upgrade: capability-reasons fragment invalid') { Ok "$Label`: prints the dedicated fragment-invalid diagnostic" } else { Bad "$Label`: unexpected output: $joined" }
}

try {
    Set-Content -LiteralPath (Join-Path $Work 'clean.txt') -Value 'clean source, no keyword match at all.' -NoNewline

    Write-Host '=== TEST-013a: unreadable (missing) fragment path ==='
    Assert-FragmentInvalid 'TEST-013a' (Join-Path $Work 'does-not-exist.json')

    Write-Host '=== TEST-013b: malformed (not valid JSON) fragment ==='
    Set-Content -LiteralPath (Join-Path $Work 'malformed.json') -Value 'not valid json {{{ at all' -NoNewline
    Assert-FragmentInvalid 'TEST-013b' (Join-Path $Work 'malformed.json')

    Write-Host "=== TEST-013c: shape-invalid -- missing 'capabilities' key ==="
    Set-Content -LiteralPath (Join-Path $Work 'no-capabilities-key.json') -Value '{"not_capabilities": []}' -NoNewline
    Assert-FragmentInvalid 'TEST-013c' (Join-Path $Work 'no-capabilities-key.json')

    Write-Host "=== TEST-013d: shape-invalid -- 'capabilities' is not an array ==="
    Set-Content -LiteralPath (Join-Path $Work 'not-array.json') -Value '{"capabilities": "not-an-array"}' -NoNewline
    Assert-FragmentInvalid 'TEST-013d' (Join-Path $Work 'not-array.json')

    Write-Host "=== TEST-013e: shape-invalid -- entry missing 'id' ==="
    Set-Content -LiteralPath (Join-Path $Work 'missing-id.json') -Value '{"capabilities": [{"eligible": false}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013e' (Join-Path $Work 'missing-id.json')

    Write-Host "=== TEST-013f: shape-invalid -- entry missing 'eligible' ==="
    Set-Content -LiteralPath (Join-Path $Work 'missing-eligible.json') -Value '{"capabilities": [{"id": "x"}]}' -NoNewline
    Assert-FragmentInvalid 'TEST-013f' (Join-Path $Work 'missing-eligible.json')

    Write-Host '=== TEST-013g: distinct from the omitted-argument case ==='
    $omitOutput = & $PowerShell -NoProfile -File $Sut -Path (Join-Path $Work 'clean.txt') 2>&1
    $omitExit = $LASTEXITCODE
    $omitJoined = ($omitOutput -join "`n")
    if ($omitExit -eq 0 -and $omitJoined -eq 'lite-eligible') { Ok 'TEST-013g: omitted-argument case is unaffected (exit 0, lite-eligible)' } else { Bad "TEST-013g: omitted-argument case regressed. exit=$omitExit output=$omitJoined" }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
