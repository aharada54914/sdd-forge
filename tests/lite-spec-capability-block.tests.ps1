# lite-spec-capability-block.tests.ps1 (epic-194-a6-lite-integration, T-003,
# design.md Test Strategy item 6, TEST-019, AC-019/AC-020/AC-021).
# PowerShell twin of lite-spec-capability-block.tests.sh -- see that file's
# header for the full rationale (SKILL.md is agent-facing prose, tested
# structurally + functionally; synthetic fragment assembly stands in for a
# real Epic A2 evaluate-predicate call, which does not exist in this
# repository yet).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$SkillProposed = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md'
$CheckRiskUpgrade = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.ps1'
$LiveShipSkill = Join-Path $RepoRoot 'plugins/sdd-ship/skills/ship/SKILL.md'
$PowerShell = (Get-Process -Id $PID).Path

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$SkillContent = Get-Content -LiteralPath $SkillProposed -Raw

function Assert-Contains([string]$Label, [string]$Needle) {
    if ($SkillContent.Contains($Needle)) { Ok $Label } else { Bad "$Label`: expected to find [$Needle] in proposed SKILL.md" }
}

Write-Host '=== TEST-019-static: proposed SKILL.md names every required element ==='
Assert-Contains 'TEST-019-static-a: names evaluate-predicate as the signal source' 'evaluate-predicate'
Assert-Contains 'TEST-019-static-b: names the Project-Context-declared component match' 'Project Context already declares'
Assert-Contains 'TEST-019-static-c: names the trigger-fragment eligible/upgrade_reasons shape' '"eligible": false'
Assert-Contains 'TEST-019-static-d: the checker call site gains the new second argument' '--capability-reasons <fragment-path>'
Assert-Contains 'TEST-019-static-e: the .ps1 call site gains its own new parameter' '-CapabilityReasons <fragment-path>'
Assert-Contains 'TEST-019-static-f: disabled-legacy (no Project Context) skip clause present' 'skip this step entirely'
Assert-Contains 'TEST-019-static-g: non-overridable by --lite, regardless of signal source' 'regardless of whether the'
Assert-Contains 'TEST-019-static-h: the dedicated fragment-invalid exit-2 diagnostic is documented' 'capability-reasons fragment invalid'
Assert-Contains 'TEST-019-static-i: ship-time recheck stays layered, not replaced' 'layered with, not a substitute for'
Assert-Contains 'TEST-019-static-j: Boundaries still disclaim reimplementing Predicate-DSL/Registry-matching' 'Predicate-DSL/Registry-matching'

Write-Host '=== TEST-019-functional: assembled Capability-derived fragment Blocks ==='
$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t003-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

try {
    # Synthetic Project Context + Registry (union-match simulation standing
    # in for a real evaluate-predicate call, Non-goals -- not reimplemented
    # here).
    $declaredComponents = @('payment-service')
    $registryCapabilities = @(
        [pscustomobject]@{ id = 'payment-processing-svc'; component = 'payment-service'; eligible = $false; upgrade_reasons = @('financial_settlement') }
    )
    $matched = @()
    foreach ($capability in $registryCapabilities) {
        if ($declaredComponents -contains $capability.component -and $capability.eligible -eq $false) {
            $matched += [pscustomobject]@{ id = $capability.id; eligible = $false; upgrade_reasons = $capability.upgrade_reasons }
        }
    }
    $fragment = [pscustomobject]@{ capabilities = $matched } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $Work 'fragment.json') -Value $fragment -NoNewline
    Set-Content -LiteralPath (Join-Path $Work 'source.txt') -Value 'a clean internal requirement body with no keyword trigger at all.' -NoNewline

    $output = & $PowerShell -NoProfile -File $CheckRiskUpgrade -Path (Join-Path $Work 'source.txt') -CapabilityReasons (Join-Path $Work 'fragment.json') 2>&1
    $exitCode = $LASTEXITCODE
    $joined = ($output -join "`n")

    if ($exitCode -eq 10) { Ok 'TEST-019-functional-a: Blocks (exit 10), same exit code as an existing keyword-match fixture' } else { Bad "TEST-019-functional-a: expected exit 10, got $exitCode. Output: $joined" }
    if ($joined.StartsWith('full-required:')) { Ok 'TEST-019-functional-b: message shape is full-required: ..., same shape as a keyword-match Block' } else { Bad "TEST-019-functional-b: unexpected message shape: $joined" }
    if ($joined.Contains('financial_settlement')) { Ok 'TEST-019-functional-c: matched Capability upgrade_reasons token present in the Block message' } else { Bad "TEST-019-functional-c: expected financial_settlement in output: $joined" }
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host '=== TEST-019-defense-in-depth: ship-time recheck skill is untouched ==='
if (Test-Path -LiteralPath $LiveShipSkill -PathType Leaf) {
    $shipContent = Get-Content -LiteralPath $LiveShipSkill -Raw
    if ($shipContent.Contains('check-risk-upgrade')) { Ok 'TEST-019-defense-in-depth: ship/SKILL.md still independently invokes check-risk-upgrade at ship time' } else { Bad 'TEST-019-defense-in-depth: ship/SKILL.md no longer mentions check-risk-upgrade' }
} else {
    Bad 'TEST-019-defense-in-depth: ship/SKILL.md not found at expected path'
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
