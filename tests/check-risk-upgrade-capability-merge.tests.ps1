# check-risk-upgrade-capability-merge.tests.ps1 (epic-194-a6-lite-integration,
# T-002, design.md Test Strategy item 5, TEST-008/TEST-009). PowerShell twin
# of check-risk-upgrade-capability-merge.tests.sh -- see that file's header
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

$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t002-merge-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

function Invoke-Sut([string]$InputPath, [string]$FragmentPath) {
    $output = & $PowerShell -NoProfile -File $Sut -Path $InputPath -CapabilityReasons $FragmentPath 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

try {
    Set-Content -LiteralPath (Join-Path $Work 'clean.txt') -Value 'an entirely unremarkable sentence.' -NoNewline
    Set-Content -LiteralPath (Join-Path $Work 'trig.txt') -Value 'we need an oauth token for this.' -NoNewline
    $fragmentMixed = @'
{"capabilities": [
  {"id": "durable-workflow-svc", "eligible": false, "upgrade_reasons": ["durable_workflow"]},
  {"id": "internal-tool-only", "eligible": false, "upgrade_reasons": []},
  {"id": "fine-capability", "eligible": true, "upgrade_reasons": ["should-not-appear"]}
]}
'@
    Set-Content -LiteralPath (Join-Path $Work 'fragment-mixed.json') -Value $fragmentMixed -NoNewline

    Write-Host '=== TEST-008a: clean source + mixed fragment merges correctly ==='
    $r1 = Invoke-Sut (Join-Path $Work 'clean.txt') (Join-Path $Work 'fragment-mixed.json')
    if ($r1.ExitCode -eq 10) { Ok 'TEST-008a: exits 10' } else { Bad "TEST-008a: expected exit 10, got $($r1.ExitCode). Output: $($r1.Output)" }
    if ($r1.Output -eq 'full-required: durable_workflow; triggers=durable_workflow,ineligible:internal-tool-only') { Ok 'TEST-008a: output matches exact expected merge' } else { Bad "TEST-008a: unexpected output: $($r1.Output)" }

    Write-Host '=== TEST-008b: keyword-derived tokens precede capability-derived tokens ==='
    $r2 = Invoke-Sut (Join-Path $Work 'trig.txt') (Join-Path $Work 'fragment-mixed.json')
    if ($r2.ExitCode -eq 10) { Ok 'TEST-008b: exits 10' } else { Bad "TEST-008b: expected exit 10, got $($r2.ExitCode). Output: $($r2.Output)" }
    if ($r2.Output -eq 'full-required: AUTH_BOUNDARY; triggers=AUTH_BOUNDARY,TOKEN_CREDENTIAL,durable_workflow,ineligible:internal-tool-only') { Ok 'TEST-008b: keyword tokens precede capability tokens; primary id unchanged' } else { Bad "TEST-008b: unexpected output: $($r2.Output)" }

    Write-Host '=== TEST-008c: all-eligible fragment contributes nothing ==='
    $fragmentAllEligible = @'
{"capabilities": [
  {"id": "cap-a", "eligible": true},
  {"id": "cap-b", "eligible": true, "upgrade_reasons": []}
]}
'@
    Set-Content -LiteralPath (Join-Path $Work 'fragment-all-eligible.json') -Value $fragmentAllEligible -NoNewline
    $r3 = Invoke-Sut (Join-Path $Work 'clean.txt') (Join-Path $Work 'fragment-all-eligible.json')
    if ($r3.ExitCode -eq 0 -and $r3.Output -eq 'lite-eligible') { Ok 'TEST-008c: all-eligible fragment + clean source stays lite-eligible' } else { Bad "TEST-008c: expected exit 0 / lite-eligible, got exit $($r3.ExitCode). Output: $($r3.Output)" }

    Write-Host '=== TEST-009: static review -- no new keyword row, no DSL/Registry call ==='
    $sutContent = Get-Content -LiteralPath $Sut -Raw
    $ruleDefCount = ([regex]::Matches($sutContent, '\$rules = @\(')).Count
    if ($ruleDefCount -eq 1) { Ok 'TEST-009a: exactly one $rules array definition' } else { Bad "TEST-009a: expected exactly one `$rules = @(` definition, found $ruleDefCount" }
    $ruleIds = [regex]::Matches($sutContent, "Id = '(AUTH_BOUNDARY|TOKEN_CREDENTIAL|MCP|EXTERNAL_API|SECRET|GITHUB_ACTIONS)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    if (@($ruleIds).Count -eq 6) { Ok 'TEST-009b: still exactly the original six keyword-rule IDs' } else { Bad "TEST-009b: expected exactly 6 distinct keyword-rule IDs, found $(@($ruleIds).Count)" }
    if ($sutContent -match '(?i)evaluate-predicate|predicate-dsl|registry[_-]match') { Bad 'TEST-009c: staged script must not call Predicate-DSL/Registry-matching logic of its own' } else { Ok 'TEST-009c: no Predicate-DSL/Registry-matching call found' }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
