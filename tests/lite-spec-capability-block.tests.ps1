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
# tasks.md T-003 Planned Files declares this fixture tree; it was declared but
# never created, and both twins built fixtures inline instead (T-003 Anthropic
# slot, Minor). Reading BOTH twins from one file is additionally what stops
# them modelling the Registry differently -- the divergence a previous round
# had to repair by hand.
#
# Loaded defensively: with $ErrorActionPreference = 'Stop' an unguarded
# Get-Content on a missing catalog throws at LOAD time -- before a single
# assertion runs and before any "Results:" line, so the tally vanishes
# entirely. That is the same opaque-abort mode the sh twin's python3 guard
# exists to prevent, and it is worse here because nothing at all is printed.
# A missing catalog must be a visible FAIL plus visible skips, never silence.
$FixtureCatalogPath = Join-Path $RepoRoot 'tests/fixtures/epic-194-lite-spec/scenarios.json'
$HaveCatalog = $false
$FixtureCatalog = $null
if (Test-Path -LiteralPath $FixtureCatalogPath -PathType Leaf) {
    try {
        $FixtureCatalog = Get-Content -LiteralPath $FixtureCatalogPath -Raw | ConvertFrom-Json
        $HaveCatalog = $true
    } catch {
        $HaveCatalog = $false
    }
}

$Script:Pass = 0
$Script:Fail = 0
function Ok([string]$m) { Write-Host "ok: $m"; $Script:Pass++ }
function Bad([string]$m) { Write-Host "FAIL: $m"; $Script:Fail++ }

$SkillContent = Get-Content -LiteralPath $SkillProposed -Raw

function Assert-Contains([string]$Label, [string]$Needle) {
    if ($SkillContent.Contains($Needle)) { Ok $Label } else { Bad "$Label`: expected to find [$Needle] in proposed SKILL.md" }
}

# Whitespace-flattened view of the same file, so a needle that spans a hard
# line wrap in the Markdown source can still be asserted verbatim (twin of the
# sh suite's own $SKILL_FLAT).
$SkillFlat = [System.Text.RegularExpressions.Regex]::Replace($SkillContent, '\s+', ' ')

function Assert-FlatContains([string]$Label, [string]$Needle) {
    if ($SkillFlat.Contains($Needle)) { Ok $Label } else { Bad "$Label`: expected to find [$Needle] in the line-flattened proposed SKILL.md" }
}

Write-Host '=== TEST-019-static: proposed SKILL.md names every required element ==='
Assert-Contains 'TEST-019-static-a: names evaluate-predicate as the signal source' 'evaluate-predicate'
Assert-Contains 'TEST-019-static-b: names the Project-Context-declared component match' 'Project Context already declares'
Assert-Contains 'TEST-019-static-c: names the trigger-fragment eligible/upgrade_reasons shape' '"eligible": false'
Assert-Contains 'TEST-019-static-d: the checker call site gains the new second argument' '--capability-reasons <fragment-path>'
Assert-Contains 'TEST-019-static-e: the .ps1 call site gains its own new parameter' '-CapabilityReasons <fragment-path>'
Assert-Contains 'TEST-019-static-f: disabled-legacy (no Project Context) skip clause present' 'skip this step entirely'
# AC-019 names non-overridability as "`--lite` never overrides". The needle
# used here previously was 'regardless of whether the', which names neither
# `--lite` nor any override (T-003 Anthropic-panelist review, Major). See the
# sh twin for the full rationale.
Assert-Contains 'TEST-019-static-g: non-overridable -- the "--lite never overrides" clause is present verbatim (AC-019)' '`--lite` never overrides this decision'
Assert-FlatContains 'TEST-019-static-g2: that non-override applies to the Capability-derived signal too, not only the keyword scan' 'regardless of whether the match came from the keyword scan or from this Capability-derived signal'
Assert-Contains 'TEST-019-static-h: the dedicated fragment-invalid exit-2 diagnostic is documented' 'capability-reasons fragment invalid'
Assert-Contains 'TEST-019-static-i: ship-time recheck stays layered, not replaced' 'layered with, not a substitute for'
Assert-Contains 'TEST-019-static-j: Boundaries still disclaim reimplementing Predicate-DSL/Registry-matching' 'Predicate-DSL/Registry-matching'

# AC-019's second named property: the Block happens "before any
# specs/<feature>/ file exists". Structural, not a substring-presence check --
# moving the gate after file generation would leave every substring intact
# while destroying the property (twin of the sh suite's static-p/q).
Assert-Contains 'TEST-019-static-p: the gate states it runs before any specs/<feature>/ file is created (AC-019)' 'Before beginning the Process or creating any file under `specs/<feature>/`'
$SkillLines = Get-Content -LiteralPath $SkillProposed
$GateLine = (1..$SkillLines.Count | Where-Object { $SkillLines[$_ - 1] -eq '## Risk-Upgrade Gate' } | Select-Object -First 1)
# .Contains, not -like: PowerShell's wildcard engine treats a backtick in the
# PATTERN as its own escape character, so the literal backticks around
# `specs/<feature>/` in the Markdown would never match a -like needle that
# spells them (verified: the -like form returns False against the very line
# it quotes). The sh twin has no such quirk -- grep -F is literal.
$GenerateLine = (1..$SkillLines.Count | Where-Object { $SkillLines[$_ - 1].Contains('次の3ファイルを `specs/<feature>/` に生成') } | Select-Object -First 1)
if ($null -ne $GateLine -and $null -ne $GenerateLine -and $GateLine -lt $GenerateLine) {
    Ok "TEST-019-static-q: the Risk-Upgrade Gate section (line $GateLine) precedes the specs/<feature>/ generation step (line $GenerateLine)"
} else {
    Bad "TEST-019-static-q: expected the Risk-Upgrade Gate to precede specs/<feature>/ generation; gate=[$GateLine] generate=[$GenerateLine]"
}

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

if (Test-Path -LiteralPath $FixtureCatalogPath -PathType Leaf) {
    Ok 'TEST-019-fixture-catalog: the tasks.md-declared fixture tree exists and is read by both twins'
} else {
    Bad "TEST-019-fixture-catalog: declared fixture tree is missing at $FixtureCatalogPath"
}

Write-Host '=== TEST-019-functional: assembled Capability-derived fragment Blocks ==='
$Work = Join-Path ([IO.Path]::GetTempPath()) ('sdd-a6-t003-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

try {
    # Synthetic Project Context + Registry (union-match simulation standing
    # in for a real evaluate-predicate call, Non-goals -- not reimplemented
    # here).
    # The Registry fixture must carry design.md's own Data Plan shape --
    # eligibility nested under `lite_policy` -- exactly as the sh twin's
    # registry.json does. This fixture previously FLATTENED eligible/
    # upgrade_reasons straight onto the capability object, so the PowerShell
    # half never exercised the designed Registry shape at all and the twin
    # pair was not the runtime-equivalence check it is presented as (T-003
    # Anthropic-panelist review, Minor). Reading through `.lite_policy` also
    # means a regression back to the flat shape now throws under
    # Set-StrictMode instead of silently matching nothing.
    $declaredComponents = @($FixtureCatalog.project_context.components)
    $registryCapabilities = @($FixtureCatalog.registry.capabilities)
    $matched = @()
    foreach ($capability in $registryCapabilities) {
        if ($declaredComponents -contains $capability.component -and $capability.lite_policy.eligible -eq $false) {
            $matched += [pscustomobject]@{ id = $capability.id; eligible = $false; upgrade_reasons = $capability.lite_policy.upgrade_reasons }
        }
    }
    # Assert the SHAPE of the Registry fixture, not just that the match found
    # something: a flattened fixture would still yield exactly one match, so a
    # count-only assertion would not detect the divergence it exists to catch.
    $regEntry = $registryCapabilities[0]
    $regNames = @($regEntry.PSObject.Properties.Name)
    $hasNested = ($regNames -contains 'lite_policy') -and (@($regEntry.lite_policy.PSObject.Properties.Name) -contains 'eligible')
    $hasFlat = ($regNames -contains 'eligible') -or ($regNames -contains 'upgrade_reasons')
    if ($hasNested -and -not $hasFlat -and $matched.Count -eq 1) {
        Ok 'TEST-019-functional-registry-shape: the Registry fixture nests eligibility under lite_policy and exposes no flattened eligible/upgrade_reasons (design.md Data Plan; parity with the sh twin''s registry.json)'
    } else {
        Bad "TEST-019-functional-registry-shape: Registry fixture shape diverges from design.md's Data Plan and from the sh twin. nested=$hasNested flat=$hasFlat matched=$($matched.Count) props=[$($regNames -join ',')]"
    }
    $fragment = [pscustomobject]@{ capabilities = $matched } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $Work 'fragment.json') -Value $fragment -NoNewline
    Set-Content -LiteralPath (Join-Path $Work 'source.txt') -Value $FixtureCatalog.sources.clean -NoNewline

    # AC-019 requires the Capability-derived Block to carry "the identical
    # exit code (10) [and] message shape (full-required: ...) ... as an
    # existing keyword-match fixture". These assertions used to hard-code 10
    # and the prefix, so their labels claimed a comparison the suite never
    # performed (T-003 Anthropic-panelist review, Major). The keyword-match
    # fixture is now actually RUN and its observed values are the comparison
    # target.
    Set-Content -LiteralPath (Join-Path $Work 'keyword-source.txt') -Value $FixtureCatalog.sources.keyword_match -NoNewline
    $kwOutput = & $PowerShell -NoProfile -File $CheckRiskUpgrade -Path (Join-Path $Work 'keyword-source.txt') 2>&1
    $kwExit = $LASTEXITCODE
    $kwJoined = ($kwOutput -join "`n")
    $kwPrefix = $kwJoined.Split(':')[0]
    if ($kwExit -ne 0 -and $kwPrefix -eq 'full-required') {
        Ok "TEST-019-functional-baseline: the keyword-match reference fixture Blocks (exit $kwExit, '$kwPrefix`: ...') -- the comparison target AC-019 names actually exists"
    } else {
        Bad "TEST-019-functional-baseline: the keyword-match reference fixture did not Block; exit=$kwExit output=$kwJoined. Every parity assertion below is meaningless without it."
    }

    $output = & $PowerShell -NoProfile -File $CheckRiskUpgrade -Path (Join-Path $Work 'source.txt') -CapabilityReasons (Join-Path $Work 'fragment.json') 2>&1
    $exitCode = $LASTEXITCODE
    $joined = ($output -join "`n")

    if ($exitCode -eq $kwExit -and $exitCode -eq 10) { Ok "TEST-019-functional-a: Blocks with the IDENTICAL exit code the keyword-match fixture just produced ($exitCode)" } else { Bad "TEST-019-functional-a: expected the keyword fixture's own exit $kwExit (and 10), got $exitCode. Output: $joined" }
    if ($joined.Split(':')[0] -eq $kwPrefix) { Ok "TEST-019-functional-b: message shape is the IDENTICAL '$kwPrefix`: ...' shape the keyword-match fixture just produced" } else { Bad "TEST-019-functional-b: expected the keyword fixture's own '$kwPrefix`:' prefix, got: $joined" }
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
    $diFragment = $FixtureCatalog.defense_in_depth.fragment | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $DiWork 'di-fragment.json') -Value $diFragment -NoNewline
    Set-Content -LiteralPath (Join-Path $DiWork 'di-intake-source.txt') -Value $FixtureCatalog.sources.clean -NoNewline

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
    Set-Content -LiteralPath (Join-Path $DiWork 'di-ship-source.txt') -Value $FixtureCatalog.sources.defense_in_depth_ship -NoNewline
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

# ---------------------------------------------------------------------------
# TEST-021 (AC-021): single-file, human-copy-only lock. Twin of the sh
# suite's -- see that file for the full rationale. AC-021 had no automated
# assertion in this task's own suite at all (T-003 Anthropic slot, Major).
# ---------------------------------------------------------------------------
Write-Host '=== TEST-021 (AC-021): single-file, human-copy-only lock ==='
$HcRoot = Join-Path $RepoRoot 'specs/epic-194-a6-lite-integration/human-copy'
$SoleTarget = $FixtureCatalog.ac_021.sole_staged_target
$SoleTargetNative = $SoleTarget -replace '/', [IO.Path]::DirectorySeparatorChar

$skillsStaged = @(Get-ChildItem -LiteralPath (Join-Path $HcRoot 'plugins/sdd-lite/skills') -Recurse -File -ErrorAction SilentlyContinue)
if ($skillsStaged.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $HcRoot $SoleTargetNative) -PathType Leaf)) {
    Ok "TEST-021a: REQ-005 stages exactly one file under sdd-lite/skills/, and it is $SoleTarget"
} else {
    Bad "TEST-021a: expected exactly 1 staged file under sdd-lite/skills/ ($SoleTarget), found $($skillsStaged.Count)"
}

$manifestLines = @(Get-Content -LiteralPath (Join-Path $HcRoot 'MANIFEST.sha256') | Where-Object { $_.EndsWith("  $SoleTarget", [StringComparison]::Ordinal) })
$actualDigest = (Get-FileHash -LiteralPath (Join-Path $HcRoot $SoleTargetNative) -Algorithm SHA256).Hash.ToLowerInvariant()
$manifestDigest = if ($manifestLines.Count -eq 1) { $manifestLines[0].Split('  ')[0] } else { '' }
if ($manifestLines.Count -eq 1 -and $manifestDigest -eq $actualDigest) {
    Ok "TEST-021b: exactly one MANIFEST.sha256 entry names $SoleTarget, and its digest matches the staged bytes"
} else {
    Bad "TEST-021b: expected exactly 1 manifest entry with a matching digest for $SoleTarget; entries=$($manifestLines.Count) manifest=$manifestDigest actual=$actualDigest"
}

$appliers = @(Get-ChildItem -LiteralPath $HcRoot -File | Where-Object { $_.Extension -in @('.ps1', '.sh') } | ForEach-Object { $_.Name } | Sort-Object)
if ($appliers.Count -eq 1 -and $appliers[0] -eq $FixtureCatalog.ac_021.shared_application_runner) {
    Ok "TEST-021c: the only application path staged is the shared $($appliers[0]) -- no REQ-005-specific applier was introduced"
} else {
    Bad "TEST-021c: expected the shared runner to be the only staged application script, found: [$($appliers -join ', ')]"
}

Write-Host ''
Write-Host "Results: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -gt 0) { exit 1 }
exit 0
