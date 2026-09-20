# check-risk-upgrade-byte-identical.tests.ps1 (epic-194-a6-lite-integration,
# T-002, design.md Test Strategy item 4, TEST-007/AC-007). PowerShell twin of
# check-risk-upgrade-byte-identical.tests.sh -- see that file's header for
# the BASELINE PINNING note (2026-08-28, quality-gate cycle 2): after the
# human apply (80694f62) the live and staged paths named the same blob, so
# the comparison target is now the FROZEN pre-extension baseline fixture,
# blob 6a7366ba (the live ps1 at 80694f62^), sha256
# d1ac00563adecf9906516b7aa29d98b36ac5a485ba245532adf3ed00f14c4b38.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Live = Join-Path $RepoRoot 'plugins/sdd-lite/scripts/check-risk-upgrade.ps1'
$Baseline = Join-Path $RepoRoot 'tests/fixtures/epic-194-risk-upgrade-baseline/check-risk-upgrade-baseline.ps1'
$PowerShell = (Get-Process -Id $PID).Path

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

# Fail closed with a visible FAIL (not an opaque throw) if the frozen
# baseline fixture is missing; the tally and exit 1 still reach run-all.
if (-not (Test-Path -LiteralPath $Baseline -PathType Leaf)) {
    Bad "TEST-007-baseline-present: frozen baseline fixture missing at $Baseline"
    Write-Host ''
    Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
    exit 1
}

# Runtime pin of the frozen baseline bytes (2026-08-28 hardening): a silently
# rewritten fixture would re-tautologize AC-007 without any test going red, so
# the pinned sha256 is asserted here, not only documented in the header.
$BaselineExpectedSha = 'd1ac00563adecf9906516b7aa29d98b36ac5a485ba245532adf3ed00f14c4b38'
$BaselineActualSha = (Get-FileHash -LiteralPath $Baseline -Algorithm SHA256).Hash.ToLower()
if ($BaselineActualSha -eq $BaselineExpectedSha) {
    Ok 'TEST-007-baseline-hash: frozen baseline sha256 matches the pinned value'
} else {
    Bad "TEST-007-baseline-hash: frozen baseline sha256 drifted (expected $BaselineExpectedSha, got $BaselineActualSha)"
    Write-Host ''
    Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
    exit 1
}

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t002-bi-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

# Strict byte comparison (2026-08-28 hardening): stdout and stderr are
# captured as raw bytes via Process streams, so trailing-newline or joining
# differences that string-based capture would normalize away are detected.
function Invoke-Script([string]$ScriptPath, [string]$InputPath) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $PowerShell
    $psi.Arguments = "-NoProfile -File `"$ScriptPath`" -Path `"$InputPath`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $outMs = New-Object System.IO.MemoryStream
    $errMs = New-Object System.IO.MemoryStream
    $p.StandardOutput.BaseStream.CopyTo($outMs)
    $p.StandardError.BaseStream.CopyTo($errMs)
    $p.WaitForExit()
    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        OutB64 = [Convert]::ToBase64String($outMs.ToArray())
        ErrB64 = [Convert]::ToBase64String($errMs.ToArray())
        OutText = [System.Text.Encoding]::UTF8.GetString($outMs.ToArray())
        ErrText = [System.Text.Encoding]::UTF8.GetString($errMs.ToArray())
    }
}

function Assert-Identical([string]$Label, [string]$Fixture) {
    $liveResult = Invoke-Script $Live $Fixture
    $baseResult = Invoke-Script $Baseline $Fixture
    if ($liveResult.ExitCode -eq $baseResult.ExitCode) { Ok "$Label`: exit code identical ($($liveResult.ExitCode))" } else { Bad "$Label`: exit code differs (live=$($liveResult.ExitCode), baseline=$($baseResult.ExitCode))" }
    if (($liveResult.OutB64 -eq $baseResult.OutB64) -and ($liveResult.ErrB64 -eq $baseResult.ErrB64)) { Ok "$Label`: output byte-identical" } else { Bad "$Label`: output differs. live=[$($liveResult.OutText)$($liveResult.ErrText)] baseline=[$($baseResult.OutText)$($baseResult.ErrText)]" }
}

try {
    Set-Content -LiteralPath (Join-Path $Work 'clean.txt') -Value 'just an ordinary sentence with nothing notable in it.' -NoNewline
    Assert-Identical 'TEST-007-clean' (Join-Path $Work 'clean.txt')

    Set-Content -LiteralPath (Join-Path $Work 'auth.txt') -Value 'this endpoint needs oauth for authentication.' -NoNewline
    Assert-Identical 'TEST-007-auth' (Join-Path $Work 'auth.txt')

    Set-Content -LiteralPath (Join-Path $Work 'token.txt') -Value 'store the credential as a token, never a password.' -NoNewline
    Assert-Identical 'TEST-007-token' (Join-Path $Work 'token.txt')

    Set-Content -LiteralPath (Join-Path $Work 'mcp.txt') -Value 'this integrates with an mcp server.' -NoNewline
    Assert-Identical 'TEST-007-mcp' (Join-Path $Work 'mcp.txt')

    Set-Content -LiteralPath (Join-Path $Work 'api.txt') -Value 'calls a third-party API for external data.' -NoNewline
    Assert-Identical 'TEST-007-api' (Join-Path $Work 'api.txt')

    Set-Content -LiteralPath (Join-Path $Work 'secret.txt') -Value 'never log a secret value.' -NoNewline
    Assert-Identical 'TEST-007-secret' (Join-Path $Work 'secret.txt')

    Set-Content -LiteralPath (Join-Path $Work 'gha.txt') -Value 'runs entirely inside github actions.' -NoNewline
    Assert-Identical 'TEST-007-github-actions' (Join-Path $Work 'gha.txt')

    Assert-Identical 'TEST-007-unavailable' (Join-Path $Work 'does-not-exist.txt')
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
