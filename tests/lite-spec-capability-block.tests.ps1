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

# ---------------------------------------------------------------------------
# "Attempted and failed" producer-side rule (panelist Critical finding,
# cross-model verdict T-003.panelist-anthropic.verdict.json): a Project
# Context that exists but whose Capability evaluation cannot be completed
# must Block, not silently fall through to the one-argument, keyword-only
# call -- the only legitimate degrade is the second argument's own total
# absence (disabled-legacy). Each failure mode this rule names, plus the
# required outcome, gets its own assertion.
# ---------------------------------------------------------------------------
Assert-Contains 'TEST-019-static-k: names evaluate-predicate absence/non-zero exit as a producer failure mode' 'absent or exits non-zero'
Assert-Contains 'TEST-019-static-l: names an unreadable/unparseable Registry as a producer failure mode' 'Registry is unreadable or fails to parse'
Assert-Contains 'TEST-019-static-m: names a temp-fragment write failure as a producer failure mode' 'writing the temp fragment fails'
Assert-Contains 'TEST-019-static-n: the required outcome is an immediate Block, before the checker ever runs' 'Block immediately, before'
Assert-Contains 'TEST-019-static-o: an attempted-and-failed signal is never treated as one never attempted' 'never a silent degrade'

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

# ---------------------------------------------------------------------------
# Companion fixture (defense-in-depth, design.md Test Strategy item 6,
# panelist Major finding): the OLD version of this companion only grepped
# ship/SKILL.md for the string "check-risk-upgrade" -- true whether or not
# T-003 ever existed, so it discriminated nothing. This version *executes*
# both independent gate positions for a component the intake-time
# Capability-derived evaluation did NOT flag, and separately proves the
# fixture is actually coupled to the proposed SKILL.md text (not a
# tautology) by requiring its own precondition to hold.
# ---------------------------------------------------------------------------
Write-Host '=== TEST-019-defense-in-depth: ship-time recheck independently Blocks a component intake did not flag ==='

if ($SkillContent.Contains('--capability-reasons <fragment-path>')) {
    Ok 'TEST-019-defense-in-depth-a: proposed SKILL.md documents the intake-time --capability-reasons contract this fixture drives'
} else {
    Bad 'TEST-019-defense-in-depth-a: proposed SKILL.md no longer documents --capability-reasons; the property below cannot be exercised'
}

$DiWork = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t003-di-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $DiWork -Force | Out-Null
$DiWork = (Resolve-Path -LiteralPath $DiWork).Path

try {
    # Component "payment-service": its matched Capability is eligible:$true,
    # so per the documented assembly rule ("Assemble every matched Capability
    # whose own lite_policy.eligible is false") it is excluded from the
    # fragment entirely -- the intake-time Capability-derived evaluation does
    # not flag it.
    $diFragment = [pscustomobject]@{
        capabilities = @(
            [pscustomobject]@{ id = 'payment-processing-svc'; eligible = $true; upgrade_reasons = @() }
        )
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $DiWork 'di-fragment.json') -Value $diFragment -NoNewline
    Set-Content -LiteralPath (Join-Path $DiWork 'di-intake-source.txt') -Value 'a clean internal requirement body with no keyword trigger at all.' -NoNewline

    $intakeOutput = & $PowerShell -NoProfile -File $CheckRiskUpgrade -Path (Join-Path $DiWork 'di-intake-source.txt') -CapabilityReasons (Join-Path $DiWork 'di-fragment.json') 2>&1
    $intakeExit = $LASTEXITCODE
    $intakeJoined = ($intakeOutput -join "`n")
    if ($intakeExit -eq 0) {
        Ok 'TEST-019-defense-in-depth-b: intake-time evaluation does not flag the eligible:true component (exit 0, lite-eligible)'
    } else {
        Bad "TEST-019-defense-in-depth-b: expected intake to pass with exit 0, got $intakeExit. Output: $intakeJoined"
    }

    # Ship-time recheck: independent invocation, single argument only --
    # exactly ship/SKILL.md's own unmodified command (still just
    # check-risk-upgrade with no -CapabilityReasons at all, per its own live
    # text) -- against a task-block+requirements body that DOES carry an
    # unrelated keyword trigger for the same component.
    Set-Content -LiteralPath (Join-Path $DiWork 'di-ship-source.txt') -Value 'the payment-service task rotates a secret used by the settlement worker.' -NoNewline
    $shipOutput = & $PowerShell -NoProfile -File $CheckRiskUpgrade -Path (Join-Path $DiWork 'di-ship-source.txt') 2>&1
    $shipExit = $LASTEXITCODE
    $shipJoined = ($shipOutput -join "`n")
    if ($shipExit -eq 10) {
        Ok 'TEST-019-defense-in-depth-c: ship-time recheck independently Blocks (exit 10) even though intake did not flag this component'
    } else {
        Bad "TEST-019-defense-in-depth-c: expected ship-time recheck to Block with exit 10, got $shipExit. Output: $shipJoined"
    }
} finally {
    if (Test-Path -LiteralPath $DiWork) { Remove-Item -LiteralPath $DiWork -Recurse -Force -ErrorAction SilentlyContinue }
}

if (Test-Path -LiteralPath $LiveShipSkill -PathType Leaf) {
    $shipContent = Get-Content -LiteralPath $LiveShipSkill -Raw
    if ($shipContent.Contains('check-risk-upgrade')) { Ok 'TEST-019-defense-in-depth-d: ship/SKILL.md still independently invokes check-risk-upgrade at ship time' } else { Bad 'TEST-019-defense-in-depth-d: ship/SKILL.md no longer mentions check-risk-upgrade' }
} else {
    Bad 'TEST-019-defense-in-depth-d: ship/SKILL.md not found at expected path'
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
