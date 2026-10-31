# WFI-058 designed-red regression: this suite MUST fail until the staged
# protected-script patch is applied, then pass unchanged.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ppi = if ($env:WFI_058_PPI_PS1) { $env:WFI_058_PPI_PS1 } else { Join-Path $repoRoot 'plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1' }
$work = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $work | Out-Null
$pass = 0; $fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $script:pass++ }
function Fail([string]$m) { Write-Host "FAIL: $m"; $script:fail++ }

function New-Fixture([string]$root, [string]$declaredHash) {
    New-Item -ItemType Directory -Path (Join-Path $root 'input') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'reports/implementation/wfi-058') -Force | Out-Null
    & git -C $root init -q; & git -C $root config user.email wfi-058@example.invalid; & git -C $root config user.name WFI-058
    [IO.File]::WriteAllText((Join-Path $root 'shared.txt'), "shared v1`n", [Text.UTF8Encoding]::new($false))
    if ($declaredHash -eq 'auto') { $declaredHash = (Get-FileHash (Join-Path $root 'shared.txt') -Algorithm SHA256).Hash.ToLower() }
    [IO.File]::WriteAllText((Join-Path $root 'tasks.md'), "# Tasks`n`n## T-001 Fixture`n`nStatus: Planned`nRisk: high`nCross-Model: enabled`n", [Text.UTF8Encoding]::new($false))
    $report = "# Implementation Report`n`n## Outputs`n`n| Path | SHA-256 |`n|---|---|`n| ``shared.txt`` | ``$declaredHash`` |`n`n## Evidence`nfixture`n"
    [IO.File]::WriteAllText((Join-Path $root 'reports/implementation/wfi-058/T-001.md'), $report, [Text.UTF8Encoding]::new($false))
    & git -C $root add shared.txt tasks.md reports/implementation/wfi-058/T-001.md; & git -C $root commit -q -m C1-outputs-declared
    $script:fixtureC1 = (& git -C $root rev-parse HEAD).Trim()
    [IO.File]::WriteAllText((Join-Path $root 'shared.txt'), "shared v2 drift`n", [Text.UTF8Encoding]::new($false))
    & git -C $root add shared.txt; & git -C $root commit -q -m C2-output-drift
    [IO.File]::AppendAllText((Join-Path $root 'reports/implementation/wfi-058/T-001.md'), "`nTask ID: T-001`n", [Text.UTF8Encoding]::new($false))
    & git -C $root add reports/implementation/wfi-058/T-001.md; & git -C $root commit -q -m C3-header-only-report-edit
    $script:fixtureC3 = (& git -C $root rev-parse HEAD).Trim()
}

function Invoke-Prepare([string]$root) {
    $script:prepareOutput = (& pwsh -NoProfile -File $ppi --task T-001 --feature wfi-058 --input (Join-Path $root input) --tasks-file (Join-Path $root tasks.md) --project-root $root --out (Join-Path $root bundle.txt) 2>&1) -join "`n"
    $script:prepareExit = $LASTEXITCODE
}

try {
    $good = Join-Path $work good; New-Fixture $good auto; $goodC1 = $fixtureC1; $goodC3 = $fixtureC3; Invoke-Prepare $good
    Write-Host "WFI-058 fixture anchors: Outputs-section C1=$goodC1 header-only C3=$goodC3"
    if ($prepareExit -eq 0) { Ok 'C3 succeeds after output drift' } else { Fail "C3 must resolve drift at C1; exit=$prepareExit output=$prepareOutput" }
    if ($prepareOutput -match [regex]::Escape("declaration commit $($goodC1.Substring(0,7))")) { Ok 'notice names the Outputs-section anchor C1' } else { Fail "notice must name C1; output=$prepareOutput" }

    $bad = Join-Path $work control; New-Fixture $bad ('f' * 64); Invoke-Prepare $bad
    if ($prepareExit -ne 0 -and $prepareOutput.Contains('declared output hash mismatch: shared.txt')) { Ok 'control mismatched at worktree and C1 fails closed' } else { Fail "control must fail closed; exit=$prepareExit output=$prepareOutput" }
} finally { Remove-Item -Recurse -Force $work }
Write-Host "$pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
