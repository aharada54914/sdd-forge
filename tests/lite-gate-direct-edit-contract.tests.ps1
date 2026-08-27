# lite-gate-direct-edit-contract.tests.ps1 (epic-194-a6-lite-integration,
# T-004 quality-gate remediation, TEST-014/TEST-017, AC-014/AC-017).
# PowerShell twin of lite-gate-direct-edit-contract.tests.sh -- see that
# file's header for the full rationale.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Skill = Join-Path $RepoRoot 'plugins/sdd-lite/skills/lite-gate/SKILL.md'
$GuardInvariants = Join-Path $RepoRoot 'plugins/sdd-quality-loop/references/guard-invariants.json'
$GoldenNote = Join-Path $RepoRoot 'tests/fixtures/epic-194-lite-gate/skill-ordering-note.golden.txt'

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$skillLines = Get-Content -LiteralPath $Skill

Write-Host '=== TEST-014a: Step 2a/2b sit strictly between the existing Step 2 and Step 3 ==='
$step2Line = (($skillLines | Select-String -SimpleMatch '2. プロジェクトの') | Select-Object -First 1).LineNumber
$step2aLine = (($skillLines | Select-String -SimpleMatch '2a. **`full_upgrade_required`') | Select-Object -First 1).LineNumber
$step2bLine = (($skillLines | Select-String -SimpleMatch '2b. **Registry-sourced') | Select-Object -First 1).LineNumber
$step3Line = (($skillLines | Select-String -SimpleMatch '3. `reports/quality-gate') | Select-Object -First 1).LineNumber
if ($step2Line -and $step2aLine -and $step2bLine -and $step3Line -and
    ($step2Line -lt $step2aLine) -and ($step2aLine -lt $step2bLine) -and ($step2bLine -lt $step3Line)) {
    Ok "TEST-014a: Step order is 2 ($step2Line) < 2a ($step2aLine) < 2b ($step2bLine) < 3 ($step3Line)"
} else {
    Bad "TEST-014a: expected Step2 < 2a < 2b < Step3, got Step2=$step2Line 2a=$step2aLine 2b=$step2bLine Step3=$step3Line"
}

Write-Host "=== TEST-014b: '順序が重要' ordering note preserved verbatim ==="
$actualNote = (($skillLines | Select-String -SimpleMatch '順序が重要') | Select-Object -First 1).Line
$expectedNote = (Get-Content -LiteralPath $GoldenNote -Raw).TrimEnd("`r", "`n")
if ($actualNote -and ($actualNote -eq $expectedNote)) {
    Ok 'TEST-014b: the 順序が重要 ordering note text is byte-for-byte unchanged'
} else {
    Bad "TEST-014b: ordering note text has drifted from the golden fixture -- expected [$expectedNote], got [$actualNote]"
}

Write-Host '=== TEST-017: guard-invariants.json direct-edit protection-status re-verification ==='
$grepMatches = Select-String -Path $GuardInvariants -Pattern 'sdd-lite' -SimpleMatch
$grepMatches | ForEach-Object { Write-Host "$($_.LineNumber):$($_.Line)" }
if (-not $grepMatches) {
    Bad 'TEST-017: grep for sdd-lite in guard-invariants.json returned nothing -- the check itself is vacuous (expected at least the lite-spec/SKILL.md entries)'
} elseif ($grepMatches | Where-Object { $_.Line -match 'lite-gate/SKILL\.md' }) {
    Bad 'TEST-017: lite-gate/SKILL.md now appears in guard-invariants.json -- the direct-edit path is no longer valid; re-route through human-copy'
} else {
    Ok 'TEST-017: lite-gate/SKILL.md is absent from every sdd-lite-tagged guard-invariants.json entry; direct-edit remains valid'
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
