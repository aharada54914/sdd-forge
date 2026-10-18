$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Runner = Join-Path $RepoRoot 'plugins/sdd-lite/lib/run-lite-gate.py'
$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) { $Python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $Python) { Write-Output 'ok: Python unavailable; deferred to CI'; exit 0 }
$Pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $Pwsh) { Write-Output 'ok: PowerShell unavailable; deferred to Windows CI'; exit 0 }
$Work = Join-Path ([IO.Path]::GetTempPath()) ('lite-gate-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $Work 'scripts') -Force | Out-Null
try {
    Set-Content -LiteralPath (Join-Path $Work 'capability-summary.json') -Value '{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":["emit-proof"],"full_upgrade_required":false}' -NoNewline
    @'
Write-Output 'child-stdout'
[Console]::Error.WriteLine('child-stderr')
[IO.File]::WriteAllText((Join-Path (Get-Location) 'ran.txt'), 'ran')
'@ | Set-Content -LiteralPath (Join-Path $Work 'scripts/emit-proof.ps1')
    @'
#!/bin/sh
printf 'child-stdout\n'
printf 'child-stderr\n' >&2
printf 'ran\n' > ran.txt
'@ | Set-Content -LiteralPath (Join-Path $Work 'scripts/emit-proof.sh')
    $raw = & $Python.Source $Runner --summary (Join-Path $Work 'capability-summary.json') --enforcement required --repo-root $Work --runtime powershell
    if ($LASTEXITCODE -ne 0) { throw 'PowerShell child was reported as failed' }
    $result = $raw | ConvertFrom-Json
    if ($result.verdict -ne 'PASS' -or $result.checks[0].exit_code -ne 0) { throw 'unexpected pass payload' }
    if ($result.checks[0].stdout.Trim() -ne 'child-stdout' -or $result.checks[0].stderr.Trim() -ne 'child-stderr') { throw 'stdout/stderr were not captured separately' }
    if (-not (Test-Path (Join-Path $Work 'ran.txt'))) { throw 'child sentinel was not written' }
    Write-Output 'ok: PowerShell child execution captures output and exit status'
    $evidence = Join-Path $Work 'result.json'
    $raw = & $Python.Source $Runner --enforcement none --repo-root $Work --runtime powershell --check emit-proof --check emit-proof --output $evidence
    if ($LASTEXITCODE -ne 0) { throw 'explicit check failed' }
    $result = Get-Content -Raw -LiteralPath $evidence | ConvertFrom-Json
    if ($result.checks.Count -ne 1 -or $result.checks[0].exit_code -ne 0) { throw 'explicit checks were not deduplicated' }
    if ((Get-Content -Raw -LiteralPath $evidence).Trim() -ne ($raw -join "`n").Trim()) { throw 'evidence differs from execution output' }
    Write-Output 'ok: explicit checks deduplicate and generate actual execution evidence'
    $raw = & $Python.Source $Runner --enforcement none --repo-root $Work --runtime powershell --check emit-proof --check missing --output $evidence
    if ($LASTEXITCODE -eq 0) { throw 'missing check was waived' }
    $result = Get-Content -Raw -LiteralPath $evidence | ConvertFrom-Json
    if ($result.verdict -ne 'FAIL' -or $result.failed_check -ne 'missing' -or $result.checks.Count -ne 1) { throw 'failure lost prior execution evidence' }
    Write-Output 'ok: discovery failure preserves completed evidence'
    Write-Output 'Results: 3 passed, 0 failed'
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
