# lite-gate-summary-consumption.tests.ps1 (epic-194-a6-lite-integration,
# T-004, design.md Test Strategy item 7, TEST-015/016). PowerShell twin of
# lite-gate-summary-consumption.tests.sh -- see that file's header.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $RepoRoot 'tests/fixtures/epic-194-lite-gate/simulate-lite-gate-step2.ps1')
$Skill = Join-Path $RepoRoot 'plugins/sdd-lite/skills/lite-gate/SKILL.md'

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t004-sc-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $Work 'scripts') -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

function Write-Summary([string]$Path, [string]$RequiredChecksJson, [string]$FullUpgrade) {
    Set-Content -LiteralPath $Path -Value "{`"schema`":`"sdd-capability-summary/v1`",`"feature`":`"demo`",`"track`":`"lite`",`"capabilities`":[`"cap-a`"],`"required_lite_checks`":$RequiredChecksJson,`"full_upgrade_required`":$FullUpgrade}" -NoNewline
}

try {
    Write-Host '=== TEST-015a: baseline-name duplicate is a no-op ==='
    Write-Summary (Join-Path $Work 'baseline-only.json') '["build","test"]' 'false'
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'baseline-only.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'PASS') { Ok 'TEST-015a: baseline-only is a no-op, VERDICT: PASS' } else { Bad "TEST-015a: expected PASS, got $($r.Verdict) ($($r.Reason))" }
    if (@($r.RanChecks).Count -eq 0) { Ok 'TEST-015a: no command-discovery attempted for baseline names' } else { Bad "TEST-015a: unexpected discovery ran: $($r.RanChecks -join ',')" }

    Write-Host '=== TEST-015b: Registry-sourced check resolved via npm scripts ==='
    Set-Content -LiteralPath (Join-Path $Work 'package.json') -Value '{"scripts": {"custom-lint": "echo custom-lint"}}' -NoNewline
    Write-Summary (Join-Path $Work 'via-npm.json') '["build","custom-lint"]' 'false'
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'via-npm.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'PASS') { Ok 'TEST-015b: npm-resolvable check runs, VERDICT: PASS' } else { Bad "TEST-015b: expected PASS, got $($r.Verdict) ($($r.Reason))" }
    if ($r.RanChecks -contains 'npm:custom-lint') { Ok 'TEST-015b: recorded as run via npm' } else { Bad "TEST-015b: expected npm:custom-lint, got [$($r.RanChecks -join ',')]" }

    Write-Host '=== TEST-015c: Registry-sourced check resolved via scripts/<id> pair ==='
    Set-Content -LiteralPath (Join-Path $Work 'scripts/installer-dry-run.sh') -Value "#!/bin/sh`necho ok" -NoNewline
    Set-Content -LiteralPath (Join-Path $Work 'scripts/installer-dry-run.ps1') -Value 'Write-Host ok' -NoNewline
    Write-Summary (Join-Path $Work 'via-scripts.json') '["installer-dry-run"]' 'false'
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'via-scripts.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'PASS') { Ok 'TEST-015c: scripts-pair-resolvable check runs, VERDICT: PASS' } else { Bad "TEST-015c: expected PASS, got $($r.Verdict) ($($r.Reason))" }
    if ($r.RanChecks -contains 'scripts:installer-dry-run') { Ok 'TEST-015c: recorded as run via scripts pair' } else { Bad "TEST-015c: expected scripts:installer-dry-run, got [$($r.RanChecks -join ',')]" }

    Write-Host '=== TEST-016a: unmapped Registry-sourced id is VERDICT: FAIL, never N/A ==='
    Write-Summary (Join-Path $Work 'unmapped.json') '["totally-unmapped-check"]' 'false'
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'unmapped.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL') { Ok 'TEST-016a: unmapped id is VERDICT: FAIL' } else { Bad "TEST-016a: expected FAIL, got $($r.Verdict)" }
    if ($r.Reason -like '*no discoverable command*') { Ok 'TEST-016a: reason names the missing discoverable command (never N/A)' } else { Bad "TEST-016a: unexpected reason: $($r.Reason)" }

    Write-Host '=== TEST-016b: grammar-failing check-id blocked before discovery (NEW-01) ==='
    Write-Summary (Join-Path $Work 'bad-grammar.json') '["Bad_ID"]' 'false'
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'bad-grammar.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL' -and $r.Reason -like '*does not match the required*grammar*') { Ok 'TEST-016b: grammar-failing id rejected before discovery' } else { Bad "TEST-016b: expected grammar-rejection FAIL, got $($r.Verdict) ($($r.Reason))" }

    Write-Host '=== TEST-016c: symlink-escaping scripts/<id> candidate rejected (NEW-01) ==='
    Set-Content -LiteralPath (Join-Path $Work 'outside.sh') -Value 'outside content' -NoNewline
    Set-Content -LiteralPath (Join-Path $Work 'outside.ps1') -Value 'outside content' -NoNewline
    New-Item -ItemType SymbolicLink -Path (Join-Path $Work 'scripts/evil-check.sh') -Target (Join-Path $Work 'outside.sh') -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path (Join-Path $Work 'scripts/evil-check.ps1') -Target (Join-Path $Work 'outside.ps1') -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Summary (Join-Path $Work 'symlink.json') '["evil-check"]' 'false'
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'symlink.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL' -and $r.Reason -like '*no discoverable command*') { Ok 'TEST-016c: symlinked scripts/<id> pair treated as unmapped, never executed' } else { Bad "TEST-016c: expected unmapped FAIL, got $($r.Verdict) ($($r.Reason))" }

    Write-Host '=== TEST-016d: single-runtime-member pair is unmapped (NEW-01) ==='
    Set-Content -LiteralPath (Join-Path $Work 'scripts/onlysh-check.sh') -Value "#!/bin/sh`necho ok" -NoNewline
    Write-Summary (Join-Path $Work 'single-runtime.json') '["onlysh-check"]' 'false'
    $r = Invoke-LiteGateStep2Simulation -SummaryPath (Join-Path $Work 'single-runtime.json') -Enforcement 'required' -RepoRoot $Work
    if ($r.Verdict -eq 'FAIL' -and $r.Reason -like '*no discoverable command*') { Ok 'TEST-016d: single-runtime-member check-id is unmapped' } else { Bad "TEST-016d: expected unmapped FAIL, got $($r.Verdict) ($($r.Reason))" }

    Write-Host "=== TEST-016e: N/A stays reserved for Step 2's own pre-existing convention ==="
    $skillContent = Get-Content -LiteralPath $Skill -Raw
    if ($skillContent -match 'N/A.*は Step 2 既存の' -or $skillContent -match 'Step 2 既存の.*N/A') { Ok "TEST-016e: SKILL.md text still reserves N/A for Step 2's own convention only" } else { Bad 'TEST-016e: expected SKILL.md to state N/A stays reserved for Step 2' }

    Write-Host '=== TEST-018: static review -- no evidence-bundle/cross-model/second-approval/risk-hierarchy machinery introduced ==='
    $step2Match = [regex]::Match($skillContent, '(?s)2a\. \*\*`full_upgrade_required`.*?3\. `reports/quality-gate')
    $newStepText = if ($step2Match.Success) { $step2Match.Value } else { '' }
    if ($newStepText -match '(?i)generate-evidence-bundle|cross-model-verify\.[a-z]|second[- ]approval check|risk[_-]hierarchy classification|risk-classification-policy') {
        Bad "the NEW Step 2a/2b text must not introduce evidence-bundle/cross-model/second-approval/risk-hierarchy machinery"
    } elseif ($newStepText.Contains('一切追加しない')) {
        Ok 'TEST-018: the new Step 2a/2b text explicitly disclaims adding this machinery, and introduces none'
    } else {
        Bad 'TEST-018: expected the new Step 2a/2b text to explicitly disclaim this machinery'
    }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
