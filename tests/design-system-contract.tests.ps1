$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repositoryRoot "contracts/design-system.contract.v1.schema.json"
$tokensPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json"

# DS-001 both JSON files must parse (PS5.1-safe: ConvertFrom-Json, no Test-Json)
$schema = Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json
$tokens = Get-Content -Raw -Encoding Utf8 $tokensPath | ConvertFrom-Json

if ($schema.'$id' -ne 'https://sdd-forge.dev/contracts/design-system.contract.v1.schema.json') {
    throw "not ok: DS-001 schema `$id mismatch"
}
if ($schema.properties.meta.properties.schema.const -ne 'design-system-contract/v1') {
    throw "not ok: DS-001 schema const mismatch"
}
Write-Host "ok: DS-001 contract schema envelope"

# DS-002 tokens template conforms to the meta contract (domain assertions replicate the schema)
if ($tokens.meta.schema -ne 'design-system-contract/v1') { throw "not ok: DS-002 meta.schema" }
if ($tokens.meta.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw "not ok: DS-002 meta.version semver" }
if (@('design-sync-loop','ui-ux-pro-max','manual','figma-dtcg-import') -notcontains $tokens.meta.generated_by) { throw "not ok: DS-002 meta.generated_by enum" }
if ($tokens.meta.profile -ne 'custom') { throw "not ok: DS-002 meta.profile" }
foreach ($group in @('color','typography','spacing')) {
    if ($null -eq $tokens.$group) { throw "not ok: DS-002 token group $group missing" }
}
if ($tokens.color.primary.'$value' -notmatch '^#[0-9a-fA-F]{6}$') { throw "not ok: DS-002 color.primary DTCG value" }
Write-Host "ok: DS-002 tokens template conforms"

# DS-003 / DS-004 markdown templates
$dsPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md"
$uipPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md"
$ds = Get-Content -Raw -Encoding Utf8 $dsPath
$uip = Get-Content -Raw -Encoding Utf8 $uipPath
# PS5.1 reads BOM-less .ps1 as ANSI, so non-ASCII literals must be built from code points.
$em = [string][char]0x2014
foreach ($section in @("## Layer 1 $em Tokens (machine-extracted)", "## Layer 2 $em Do / Don't (component conventions)", "## Layer 3 $em Review checklist (human-curated)", '## Change Process')) {
    if ($ds -notmatch [regex]::Escape($section)) { throw "not ok: DS-003 missing section $section" }
}
if ($ds -notmatch 'WCAG 2\.2 AA') { throw "not ok: DS-003 WCAG 2.2 AA missing" }
Write-Host "ok: DS-003 design-system template sections"
foreach ($section in @('## Actions', '## Dialogs', '## Icons', '## Flow', '## States', '## Cognitive Load')) {
    if ($uip -notmatch [regex]::Escape($section)) { throw "not ok: DS-004 missing section $section" }
}
Write-Host "ok: DS-004 ui-patterns template sections"

# DS-005 PLUGIN-CONTRACTS section
# PS5.1 reads BOM-less .ps1 files as ANSI, so non-ASCII literals (the arrow in
# the heading) must be constructed from code points, never written literally.
$arrow = [string][char]0x2192
$pc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "PLUGIN-CONTRACTS.md")
if ($pc -notmatch [regex]::Escape("## sdd-bootstrap design-system artifacts $arrow consumers (v1.8.0+)")) { throw "not ok: DS-005 contract section missing" }
if ($pc -notmatch 'absence never blocks') { throw "not ok: DS-005 absence contract missing" }
Write-Host "ok: DS-005 PLUGIN-CONTRACTS section"

# DS-006 design-sync-loop v2 (ASCII-only assertions; the em-dash fallback note is asserted by the sh twin)
$dsl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md")
foreach ($needle in @('## Ensure design-system/', 'ui-ux-pro-max', 'design-system --persist', 'figma-dtcg-import', 'design-system/design-tokens.json', 'MASTER.md')) {
    if ($dsl -notmatch [regex]::Escape($needle)) { throw "not ok: DS-006 missing $needle" }
}
Write-Host "ok: DS-006 design-sync-loop v2"

# DS-007 investigate-codebase design inventory
$inv = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md")
if ($inv -notmatch 'Design Inventory') { throw "not ok: DS-007 Design Inventory missing" }
Write-Host "ok: DS-007 investigate-codebase design inventory"

# DS-008 / DS-009 design templates
$dt = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md")
if ($dt -notmatch [regex]::Escape('## Design System Compliance')) { throw "not ok: DS-008 compliance section missing" }
if ($dt -notmatch 'ds_profile: none') { throw "not ok: DS-008 none rule missing" }
if ($dt -notmatch 'design_system_version') { throw "not ok: DS-008 version placeholder missing" }
$dl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-lite/templates/design-lite.md")
if ($dl -notmatch 'design-system/') { throw "not ok: DS-009 lite declaration missing" }
Write-Host "ok: DS-008/DS-009 design templates"

# DS-010 impl-reviewer-a design-system conformance check
$ira = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-review-loop/agents/impl-reviewer-a.md")
if ($ira -notmatch [regex]::Escape('## DESIGN-SYSTEM-CONFORMANCE (Major, TYPE-D)')) { throw "not ok: DS-010 reviewer-a check missing" }
if ($ira -notmatch [regex]::Escape('ADR-PRESENT, DESIGN-SYSTEM-CONFORMANCE, DOMAIN-CONFORMANCE.')) { throw "not ok: DS-010 ordered checks not updated" }
$prc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-review-loop/references/phase-review-checklist.md")
if ($prc -notmatch [regex]::Escape('#### DESIGN-SYSTEM-CONFORMANCE')) { throw "not ok: DS-010 checklist block missing" }
Write-Host "ok: DS-010 reviewer-a conformance check"

# DS-011 impl-reviewer-b unsanctioned UI library rule
$irb = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-review-loop/agents/impl-reviewer-b.md")
if ($irb -notmatch 'component library or styling framework') { throw "not ok: DS-011 reviewer-b rule missing" }
Write-Host "ok: DS-011 reviewer-b UI library rule"

# DS-012 implementation policy UI rules and conditional required reading
$ipol = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md")
if ($ipol -notmatch [regex]::Escape('## UI Implementation Rules')) { throw "not ok: DS-012 UI rules section missing" }
if ($ipol -notmatch 'design-tokens\.json tokens only') { throw "not ok: DS-012 tokens-only rule missing" }
$itsk = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/SKILL.md")
if ($itsk -notmatch 'design-system/design-system\.md') { throw "not ok: DS-012 required reading missing" }
Write-Host "ok: DS-012 implementation policy UI rules"

# DS-013 visual-verify-loop design-system comparison
$vvl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md")
foreach ($needle in @('design-system/design-tokens.json', 'design-system/ui-patterns.md', 'check-design-system')) {
    if ($vvl -notmatch [regex]::Escape($needle)) { throw "not ok: DS-013 missing $needle" }
}
Write-Host "ok: DS-013 visual-verify-loop design-system comparison"

# DS-014 design-system checklist and evaluator wiring
$dsc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/design-system-checklist.md")
if ($dsc -notmatch [regex]::Escape('# Design System Review Checklist')) { throw "not ok: DS-014 checklist missing" }
if ($dsc -notmatch [regex]::Escape('## UI Patterns (ui-patterns.md)')) { throw "not ok: DS-014 ui-patterns section missing" }
$rub = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/evaluation-rubric.md")
if ($rub -notmatch 'design-system non-conformance') { throw "not ok: DS-014 rubric classification missing" }
$qgs = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md")
if ($qgs -notmatch 'design-system-checklist\.md') { throw "not ok: DS-014 quality-gate load missing" }
Write-Host "ok: DS-014 design-system checklist wiring"

# DS-015 WCAG 2.2 AA update
$acc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/accessibility-checklist.md")
if ($acc -notmatch 'WCAG 2\.2 AA') { throw "not ok: DS-015 target not updated" }
if ($acc -match 'WCAG 2\.1 AA') { throw "not ok: DS-015 stale 2.1 reference remains" }
Write-Host "ok: DS-015 WCAG 2.2 AA"

# DS-016 contract check id, matrix row, quality-gate wiring
$vct = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/templates/verification-contract.template.json")
if ($vct -notmatch '"id": "design-system"') { throw "not ok: DS-016 contract check id missing" }
$rgm = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/risk-gate-matrix.md")
if ($rgm -notmatch 'design-system conformance') { throw "not ok: DS-016 matrix row missing" }
if ($qgs -notmatch 'check-design-system') { throw "not ok: DS-016 quality-gate wiring missing" }
Write-Host "ok: DS-016 contract and matrix wiring"

# DS-017 user-facing documentation (ASCII-checkable subset; the Japanese changelog heading is asserted by the sh twin)
$readme = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "README.md")
if ($readme -notmatch 'design-system/') { throw "not ok: DS-017 README bullet missing" }
$wfg = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "docs/workflow-guide.md")
if ($wfg -notmatch 'design-sync-loop') { throw "not ok: DS-017 workflow-guide missing" }
$sref = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "docs/skill-reference.md")
if ($sref -notmatch 'check-design-system') { throw "not ok: DS-017 skill-reference missing" }
Write-Host "ok: DS-017 documentation"

Write-Host "ok: design-system contract tests passed"

# -----------------------------------------------------------------------
# design-sync-consent (issue #138, DS-29) -- TEST-001..TEST-051
#
# Unlike the DS-NNN blocks above (which `throw` on the first mismatch,
# relying on $ErrorActionPreference = "Stop"), this section accumulates
# PASS/FAIL and runs every one of the 51 assertions to completion, then
# exits non-zero if any failed -- tasks.md T-001 Done-When: "the suite
# runs to completion, reports PASS/FAIL per assertion, and exits non-zero
# on any FAIL, in both runtimes."
#
# T-001's own scope is authoring these 51 assertions against
# specs/design-sync-consent/acceptance-tests.md's Test Matrix. The content
# most of them check -- design-sync-loop/SKILL.md's Loop restructuring,
# the Design-Source field table, the four REQ-007 reconciliation sites,
# the staged lite-spec candidate -- is produced by T-002/T-003/T-004,
# none of which has landed at this task's authoring time. Most TEST-NNN
# below are therefore expected to FAIL (RED) against the live tree until
# those tasks land; that RED is this task's own required baseline
# evidence, not a defect here. A handful already PASS today because the
# text they check is preserved unchanged by design (TEST-016, TEST-019,
# TEST-020, TEST-021, TEST-022, TEST-023, TEST-024, TEST-037, TEST-040).
#
# TEST-039 stays RED on the live tree even after every other task in this
# decomposition lands, by design (R-OQ-8 part 3): CI registration is a
# separately staged, human-applied workflow patch outside this feature's
# task plan.
#
# Case-sensitivity (AGENTS.md "Author-time sweeps" item 1): PowerShell's
# `-match`/`-notmatch` are case-INSENSITIVE by default, unlike the
# `.sh` twin's plain `grep -E`. Every site below that mirrors a
# case-sensitive `.sh` check (no `-i`, or `grep -F`) uses `-cmatch` /
# `-cnotmatch` or `[string]::Contains` (ordinal, case-sensitive) here;
# every site mirroring a case-insensitive `.sh` check (`-Ei`/`-Fi`) uses
# plain `-match`/`-notmatch`. No `Select-String`, `-split`, `[regex]`
# static methods, `switch -wildcard/-regex` or `Sort-Object` are used in
# this section, so the cmdlet-level layer of the sweep has no site to
# cover here.
# -----------------------------------------------------------------------

$Script:TestPass = 0
$Script:TestFail = 0
function Test-Pass([string]$label) {
    $Script:TestPass++
    Write-Host "PASS: $label"
}
function Test-Fail([string]$label) {
    $Script:TestFail++
    Write-Host "FAIL: $label"
}

$dslPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
$bsiPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
$wfgPath = Join-Path $repositoryRoot "docs/workflow-guide.md"
$cdwPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md"
$chgPath = Join-Path $repositoryRoot "CHANGELOG.md"
$dscDraftPath = Join-Path $repositoryRoot "specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md"
$dscManifestPath = Join-Path $repositoryRoot "specs/design-sync-consent/human-copy/MANIFEST.sha256"
$liteLivePath = Join-Path $repositoryRoot "plugins/sdd-lite/skills/lite-spec/SKILL.md"
$liteDestName = "plugins/sdd-lite/skills/lite-spec/SKILL.md"
# Captured 2026-08-05 at this task's authoring time, against the then-live
# file. plugins/sdd-lite/skills/lite-spec/SKILL.md is never edited live by
# any task in this decomposition (BL-004) -- T-004 stages a draft
# candidate instead -- so this hash is expected to hold for the life of
# the feature.
$liteLiveSha256AtT001 = "40fdba6f1849effb06a8439a09b92a192a36b42a708c3cf1a253d7d48a50fc74"

function Get-LinesOrEmpty([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        return @(Get-Content -Encoding Utf8 -LiteralPath $path -ErrorAction Stop)
    } catch {
        return @()
    }
}

function Get-TextOrEmpty([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return "" }
    try {
        return (Get-Content -Raw -Encoding Utf8 -LiteralPath $path -ErrorAction Stop)
    } catch {
        return ""
    }
}

function Get-Sha256OrNull([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        return (Get-FileHash -Algorithm SHA256 -LiteralPath $path -ErrorAction Stop).Hash.ToLowerInvariant()
    } catch {
        return $null
    }
}

function Get-Sha256OfText([string]$text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    return -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
}

# Lines from the first line matching $2 (inclusive) up to, but excluding,
# the first later line matching $3. Scopes an assertion to one named
# section/site instead of sweeping the whole file (acceptance-tests.md
# Notes: "assert per-site, never...one repository-wide sweep").
# -cmatch/-cnotmatch, not -match/-notmatch: the .sh twin's section_between()
# finds section boundaries with awk's `~`, which is case-SENSITIVE, and
# BL-008 dual-runtime parity requires both sides to accept/reject the same
# heading (T-005 case-sensitivity-sweep-evidence.log, F-1).
function Get-SectionBetween([string[]]$lines, [string]$startPattern, [string]$endPattern) {
    $result = New-Object System.Collections.Generic.List[string]
    $flag = $false
    foreach ($line in $lines) {
        if (-not $flag) {
            if ($line -cmatch $startPattern) {
                $flag = $true
                $result.Add($line)
            }
            continue
        }
        if (($line -cmatch $endPattern) -and ($line -cnotmatch $startPattern)) {
            break
        }
        $result.Add($line)
    }
    return $result.ToArray()
}

# Collapse an array of lines to one whitespace-normalized string, so a
# multi-word phrase assertion is not defeated by Markdown's ordinary
# prose line-wrapping (observed first-hand while validating the `.sh`
# twin against a realistic fixture: a phrase such as "both must match"
# can legitimately wrap mid-phrase across two source lines). Only used
# for phrase/content checks, never for the positional checks (TEST-010,
# TEST-025, TEST-026), which need real line boundaries to compare order.
function Get-Flat([string[]]$lines) {
    return (($lines -join " ") -replace '\s+', ' ')
}
function Get-FlatText([string]$text) {
    return ($text -replace '\s+', ' ')
}

# First line index (0-based, within $lines) matching regex $pattern, or
# -1 if none.
function Get-FirstLineIndex([string[]]$lines, [string]$pattern) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) { return $i }
    }
    return -1
}

# Runtime-assembled banned frequency-model markers, retired by this feature
# (AGENTS.md "Author-time sweeps" item 2; requirements.md Edge Case 8).
# TEST-033..TEST-036's negative half must never embed either retired phrase
# as a contiguous literal in this suite's own source, comments or messages --
# assembled here from non-contiguous parts instead. The Japanese marker
# and the TEST-036 positive marker are additionally built from Unicode
# code points rather than as literal characters: PS5.1 reads a BOM-less
# `.ps1` as ANSI, so a literal non-ASCII character embedded in this
# source would be corrupted on that runtime (the existing precedent at
# this file's DS-003/DS-005 blocks, `$em`/`$arrow`) -- building from code
# points sidesteps that independently of the non-contiguous-assembly
# requirement above.
$bannedPerUpload = "per-up" + "load"
$bannedEveryTime = "every" + " time"
$bannedJaPerUpload = -join (@(0x90FD, 0x5EA6, 0x4EBA, 0x9593, 0x627F, 0x8A8D) | ForEach-Object { [char]$_ })
$sessionKatakana = -join (@(0x30BB, 0x30C3, 0x30B7, 0x30E7, 0x30F3) | ForEach-Object { [char]$_ })

$dslLines = Get-LinesOrEmpty $dslPath
$dslText = Get-TextOrEmpty $dslPath
$loopLines = Get-SectionBetween $dslLines '^## Loop$' '^## '
$boundariesLines = Get-SectionBetween $dslLines '^## Boundaries$' '^## '
$capLines = Get-SectionBetween $dslLines '^## Capability Detection$' '^## '
$bsiLines = Get-LinesOrEmpty $bsiPath
$bsiUiBulletLines = Get-SectionBetween $bsiLines '^- When the target is a UI application' '^- Otherwise ask whether the human has a local mockup'
$wfgLines = Get-LinesOrEmpty $wfgPath
$wfgSectionLines = Get-SectionBetween $wfgLines '^### 3\.1b ' '^### 3\.2 '
$cdwText = Get-TextOrEmpty $cdwPath

$dslFlat = Get-FlatText $dslText
$loopFlat = Get-Flat $loopLines
$boundariesFlat = Get-Flat $boundariesLines
$capFlat = Get-Flat $capLines
$bsiUiBulletFlat = Get-Flat $bsiUiBulletLines
$wfgSectionFlat = Get-Flat $wfgSectionLines
$cdwFlat = Get-FlatText $cdwText

# --- REQ-001 (AC-001, AC-002, AC-026, AC-027, AC-028, AC-030) -----------

if (($loopFlat -match 'consent has not been obtained for this scope') -and ($loopFlat -match 'Obtain informed consent')) {
    Test-Pass "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
} else {
    Test-Fail "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
}

if (($loopFlat -match 'consent already holds') -and ($loopFlat -match 'continue to 5|proceeds? (directly )?to (the )?(pre-upload|step 5)')) {
    Test-Pass "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
} else {
    Test-Fail "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
}

if (($loopFlat -match 'both must match') -or ($loopFlat -match 'session has ended does not hold')) {
    Test-Pass "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
} else {
    Test-Fail "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
}

if (($dslFlat -cmatch 'this feature AND this session|this feature and this session') -and -not ($dslFlat -match 'feature or session|feature/session|per-feature/session')) {
    Test-Pass "TEST-004 scope names exactly one unit, no disjunction between units (AC-002)"
} else {
    Test-Fail "TEST-004 scope names exactly one unit, no disjunction between units (AC-002)"
}

if (($loopFlat -match 'REQ-NNN') -and ($loopFlat -match 'AC-NNN') -and ($loopFlat -match 'confidential|pre-release')) {
    Test-Pass "TEST-005 disclosure element (a): payload is specification-derived, may be confidential (AC-003)"
} else {
    Test-Fail "TEST-005 disclosure element (a): payload is specification-derived, may be confidential (AC-003)"
}

if ($loopFlat.Contains("claude.ai/design") -and ($loopFlat -match 'external') -and ($loopFlat -match 'selected in step 1|project selected')) {
    Test-Pass "TEST-006 disclosure element (b): destination is claude.ai/design, external, the selected project (AC-003)"
} else {
    Test-Fail "TEST-006 disclosure element (b): destination is claude.ai/design, external, the selected project (AC-003)"
}

if (($loopFlat -match 'may be retained') -and ($loopFlat -match 'does not control|outside this repository.{0,3}s control')) {
    Test-Pass "TEST-007 disclosure element (c): content sent there may be retained, outside repo control (AC-003)"
} else {
    Test-Fail "TEST-007 disclosure element (c): content sent there may be retained, outside repo control (AC-003)"
}

if (($loopFlat -match 'for this session') -and ($loopFlat -match 'without asking again|without prompting again|proceed without asking')) {
    Test-Pass "TEST-008 disclosure states scope and that later uploads proceed without asking again (AC-004)"
} else {
    Test-Fail "TEST-008 disclosure states scope and that later uploads proceed without asking again (AC-004)"
}

if ($loopFlat.Contains("finalize_plan") -and ($loopFlat -match 'not (fully )?(known|knowable|established)|opacity|limitation|not (fully )?enumerable')) {
    Test-Pass "TEST-009 finalize_plan payload is cited or its opacity is stated as a limitation (AC-005)"
} else {
    Test-Fail "TEST-009 finalize_plan payload is cited or its opacity is stated as a limitation (AC-005)"
}

$t010Gen = Get-FirstLineIndex $loopLines 'Generate mockups'
$t010Consent = Get-FirstLineIndex $loopLines 'Resolve egress consent|Consent Resolution'
$t010Push = Get-FirstLineIndex $loopLines '\bPush\b'
$t010Review = Get-FirstLineIndex $loopLines 'claude\.ai/design browser'
if (($t010Gen -ge 0) -and ($t010Consent -ge 0) -and ($t010Push -ge 0) -and ($t010Review -ge 0) `
        -and ($t010Gen -lt $t010Consent) -and ($t010Consent -lt $t010Push) -and ($t010Push -lt $t010Review)) {
    Test-Pass "TEST-010 Loop order: generate -> consent -> push -> claude.ai review (AC-006, ordered structure)"
} else {
    Test-Fail "TEST-010 Loop order: generate -> consent -> push -> claude.ai review (AC-006, ordered structure)"
}

if ($loopFlat -match 'Local review is OPTIONAL') {
    Test-Pass "TEST-011 local review carries an optionality marker (AC-007)"
} else {
    Test-Fail "TEST-011 local review carries an optionality marker (AC-007)"
}

if ($loopFlat -match 'no upload waits on it|not a precondition for push') {
    Test-Pass "TEST-012 local review is explicitly stated not to be a precondition for push (AC-007)"
} else {
    Test-Fail "TEST-012 local review is explicitly stated not to be a precondition for push (AC-007)"
}

if ($loopFlat -match 'reach claude\.ai without.{0,20}(any )?human|without any human having read it') {
    Test-Pass "TEST-013 the demotion's consequence is stated where the demotion is described (AC-008)"
} else {
    Test-Fail "TEST-013 the demotion's consequence is stated where the demotion is described (AC-008)"
}

if (($loopFlat -cmatch 'return to 2\b') -and -not ($loopFlat -cmatch 'return to 3\b')) {
    Test-Pass "TEST-014 regeneration cycle returns to generation (2), not consent (3) (AC-009, ordered structure)"
} else {
    Test-Fail "TEST-014 regeneration cycle returns to generation (2), not consent (3) (AC-009, ordered structure)"
}

if ($dslText.Contains("Egress-Consent-Scope") -and $dslText.Contains("Egress-Consent-Subject") `
        -and $dslText.Contains("Egress-Destination") -and $dslText.Contains("Egress-Consent-Expiry") `
        -and $dslText.Contains("Egress-Consent")) {
    Test-Pass "TEST-015 Design-Source record fields are enumerated by name, not a heading check (AC-010)"
} else {
    Test-Fail "TEST-015 Design-Source record fields are enumerated by name, not a heading check (AC-010)"
}

if ($dslText.Contains("specs/<feature>/ux-spec.md")) {
    Test-Pass "TEST-016 full-profile record destination is specs/<feature>/ux-spec.md (AC-011)"
} else {
    Test-Fail "TEST-016 full-profile record destination is specs/<feature>/ux-spec.md (AC-011)"
}

# TEST-017 targets the STAGED draft candidate (T-004), never the live,
# protected plugins/sdd-lite/skills/lite-spec/SKILL.md -- red against the
# live tree until T-004 lands.
$dscDraftText = Get-TextOrEmpty $dscDraftPath
if ((Test-Path -LiteralPath $dscDraftPath) -and $dscDraftText.Contains("specs/<feature>/design.md")) {
    Test-Pass "TEST-017 lite-profile record destination is specs/<feature>/design.md, staged draft (AC-011)"
} else {
    Test-Fail "TEST-017 lite-profile record destination is specs/<feature>/design.md, staged draft (AC-011)"
}

# TEST-018 -- load-bearing (security-spec.md:169). Structural: requires
# the negation RELATIONSHIP (audit trace .. not .. authorization) within
# one neighbourhood, not the independent presence of the two vocabulary
# words. Demonstrated against a deliberately vacuous fixture in the
# implementation report, not embedded in this suite.
if ($dslFlat -match 'audit trace[^.]{0,100}not[^.]{0,60}authorization') {
    Test-Pass "TEST-018 record is an audit trace, not an authorization anything enforces (AC-012, load-bearing)"
} else {
    Test-Fail "TEST-018 record is an audit trace, not an authorization anything enforces (AC-012, load-bearing)"
}

if (($capFlat -match 'tool is unavailable') -and $capFlat.Contains("design tools unavailable")) {
    Test-Pass "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
} else {
    Test-Fail "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
}

if (($capFlat -match 'authentication fails') -and $capFlat.Contains("design tools unavailable")) {
    Test-Pass "TEST-020 capability-detection branch 2: authentication failure -> fallback, marker recorded (AC-013)"
} else {
    Test-Fail "TEST-020 capability-detection branch 2: authentication failure -> fallback, marker recorded (AC-013)"
}

if ($cdwText.Contains("does not automatically inspect, upload, or retain") -and -not ($cdwFlat -match 'consent')) {
    Test-Pass "TEST-021 fallback still performs no upload, and gained no consent step (AC-014, positive+negative)"
} else {
    Test-Fail "TEST-021 fallback still performs no upload, and gained no consent step (AC-014, positive+negative)"
}

if ($boundariesFlat -match 'absence of mockups.{0,20}never blocks|mockups or design tools') {
    Test-Pass "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
} else {
    Test-Fail "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
}

if ($boundariesFlat -match 'design tools.{0,20}never blocks|mockups or design tools') {
    Test-Pass "TEST-023 non-blocking condition 2: absence of design tools never blocks review (AC-015)"
} else {
    Test-Fail "TEST-023 non-blocking condition 2: absence of design tools never blocks review (AC-015)"
}

$bsiText = Get-TextOrEmpty $bsiPath
if ($bsiText.Contains("no artifacts and no") -and $bsiText.Contains("further design-system questions")) {
    Test-Pass "TEST-024 ds_profile: none keeps no artifacts / no further questions; no consent leak (AC-016)"
} else {
    Test-Fail "TEST-024 ds_profile: none keeps no artifacts / no further questions; no consent leak (AC-016)"
}

$t025Cp = Get-FirstLineIndex $loopLines 'Pre-upload check point'
$t025Consent = Get-FirstLineIndex $loopLines 'Resolve egress consent|Consent Resolution'
if (($t025Cp -ge 0) -and ($t025Consent -ge 0) -and ($t025Cp -ne $t025Consent) -and $loopFlat.Contains("specs/<feature>/mockups/")) {
    Test-Pass "TEST-025 pre-upload check point named, distinct from consent, over mockups/ (AC-017)"
} else {
    Test-Fail "TEST-025 pre-upload check point named, distinct from consent, over mockups/ (AC-017)"
}

# TEST-026 -- structural, load-bearing (security-spec.md:169): every path
# in the Loop that reaches an upload call passes the named pre-upload
# point first. Deliberately scans only `write_files` (the call the
# security-spec.md B1 boundary and the loop's own Push step name as the
# actual sender), not `finalize_plan` too: `finalize_plan` is legitimately
# *discussed*, never called, inside step 4's disclosure (the OQ-6 hedge
# AC-005/TEST-009 requires), which sits before the check point by design.
# Demonstrated against a deliberately vacuous fixture in the
# implementation report, not embedded in this suite.
function Test-026NoBypass {
    $cpIdx = Get-FirstLineIndex $loopLines 'Pre-upload check point'
    if ($cpIdx -lt 0) { return $false }
    $uploadIdxs = @()
    for ($i = 0; $i -lt $loopLines.Count; $i++) {
        if ($loopLines[$i] -cmatch 'write_files') { $uploadIdxs += $i }
    }
    if ($uploadIdxs.Count -eq 0) { return $false }
    foreach ($idx in $uploadIdxs) {
        if ($idx -lt $cpIdx) { return $false }
    }
    return $true
}
if (Test-026NoBypass) {
    Test-Pass "TEST-026 no upload path in the Loop bypasses the pre-upload check point (AC-017, structural)"
} else {
    Test-Fail "TEST-026 no upload path in the Loop bypasses the pre-upload check point (AC-017, structural)"
}

if ($loopFlat.Contains("property of the check") -and ($loopFlat -match 'does not presume.{0,10}an interactive human')) {
    Test-Pass "TEST-027 check point's blocking behaviour carries no interactive-human precondition (AC-018)"
} else {
    Test-Fail "TEST-027 check point's blocking behaviour carries no interactive-human precondition (AC-018)"
}

if ($loopFlat -match 'consent has not been obtained for this scope') {
    Test-Pass "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
} else {
    Test-Fail "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
}

if ($loopFlat -match 'consent already holds for this feature') {
    Test-Pass "TEST-029 consent-resolution outcome 2: already holds for this scope (AC-019)"
} else {
    Test-Fail "TEST-029 consent-resolution outcome 2: already holds for this scope (AC-019)"
}

if (($loopFlat -match 'egress is not permitted') -and ($loopFlat -match 'manual fallback') -and ($loopFlat -match 'no upload')) {
    Test-Pass "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
} else {
    Test-Fail "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
}

if (($dslFlat -match 'extensible') -and ($dslFlat -match 'ignored|non-conforming')) {
    Test-Pass "TEST-031 Design-Source shape is stated as additively extensible (AC-020)"
} else {
    Test-Fail "TEST-031 Design-Source shape is stated as additively extensible (AC-020)"
}

if ($dslFlat -match 'per-feature.{0,80}(select|default)|(select|default).{0,80}per-feature') {
    Test-Pass "TEST-032 this feature's behaviour is the one a later per-feature setting selects (AC-020)"
} else {
    Test-Fail "TEST-032 this feature's behaviour is the one a later per-feature setting selects (AC-020)"
}

$dslDescLine = ($dslLines | Where-Object { $_ -cmatch '^description:' } | Select-Object -First 1)
if ($null -eq $dslDescLine) { $dslDescLine = "" }
if (($dslDescLine -ne "") -and -not $dslDescLine.Contains($bannedPerUpload) `
        -and ($dslDescLine -match 'per-feature|feature.{0,15}(and|AND).{0,15}session')) {
    Test-Pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not $bannedPerUpload (AC-021)"
} else {
    Test-Fail "TEST-033 site 1 (frontmatter description) states the per-feature model, not $bannedPerUpload (AC-021)"
}

if (($boundariesLines.Count -gt 0) -and -not $boundariesFlat.Contains($bannedEveryTime) `
        -and ($boundariesFlat -match 'per-feature|feature.{0,15}(and|AND).{0,15}session')) {
    Test-Pass "TEST-034 site 2 (Boundaries) states the per-feature model, not $bannedEveryTime (AC-021)"
} else {
    Test-Fail "TEST-034 site 2 (Boundaries) states the per-feature model, not $bannedEveryTime (AC-021)"
}

if (($bsiUiBulletLines.Count -gt 0) -and -not $bsiUiBulletFlat.Contains($bannedPerUpload) `
        -and ($bsiUiBulletFlat -match 'per-feature|feature.{0,15}(and|AND).{0,15}session')) {
    Test-Pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not $bannedPerUpload (AC-021)"
} else {
    Test-Fail "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not $bannedPerUpload (AC-021)"
}

if (($wfgSectionLines.Count -gt 0) -and -not $wfgSectionFlat.Contains($bannedJaPerUpload) `
        -and $wfgSectionFlat.Contains($sessionKatakana)) {
    Test-Pass "TEST-036 site 4 (workflow-guide.md, Japanese) states the per-feature/session model (AC-021)"
} else {
    Test-Fail "TEST-036 site 4 (workflow-guide.md, Japanese) states the per-feature/session model (AC-021)"
}

# TEST-037 -- regression (negative): the historical release note is
# byte-identical to its pre-change content (BL-006, AC-022). Located by
# an ASCII-only anchor ("design-sync-loop`", backtick immediately
# following, unique in CHANGELOG.md) rather than a hardcoded line number,
# then compared by SHA-256 over the anchor line plus the following four
# lines -- a true byte-identity check that never needs the Japanese text
# as a literal in this source at all. The anchor search is an inline
# -cmatch scan, not Get-FirstLineIndex: the .sh twin finds this anchor
# with a plain `grep -n` (no -i, case-SENSITIVE), unlike TEST-010/
# TEST-025's loop_line_of() (grep -iE), so this one site must not route
# through the case-insensitive helper (T-005 sweep evidence, F-2) --
# mirroring how TEST-026 keeps its `write_files` scan inline.
function Test-037Unchanged {
    $chgLines = Get-LinesOrEmpty $chgPath
    $anchorIdx = -1
    for ($i = 0; $i -lt $chgLines.Count; $i++) {
        if ($chgLines[$i] -cmatch 'design-sync-loop`') { $anchorIdx = $i; break }
    }
    if ($anchorIdx -lt 0) { return $false }
    if ($anchorIdx + 4 -ge $chgLines.Count) { return $false }
    $block = ($chgLines[$anchorIdx..($anchorIdx + 4)] -join "`n") + "`n"
    $actualHash = Get-Sha256OfText $block
    return $actualHash -eq "4d911e7a8adc86e9ea79adfe1bec5c6e26b62c939a6f0dde517d204a2ef410c8"
}
if (Test-037Unchanged) {
    Test-Pass "TEST-037 CHANGELOG.md historical release note is byte-identical to pre-change content (AC-022)"
} else {
    Test-Fail "TEST-037 CHANGELOG.md historical release note is byte-identical to pre-change content (AC-022)"
}

function Test-038Staged {
    if (-not (Test-Path -LiteralPath $dscDraftPath)) { return $false }
    if (-not (Test-Path -LiteralPath $dscManifestPath)) { return $false }
    $draftHash = Get-Sha256OrNull $dscDraftPath
    if ($null -eq $draftHash) { return $false }
    $manifestLines = Get-LinesOrEmpty $dscManifestPath
    $manifestPattern = "^" + [regex]::Escape($draftHash) + "\s+.*" + [regex]::Escape($liteDestName) + "$"
    $found = $false
    foreach ($line in $manifestLines) {
        if ($line -cmatch $manifestPattern) { $found = $true; break }
    }
    if (-not $found) { return $false }
    $liveHash = Get-Sha256OrNull $liteLivePath
    return $liveHash -eq $liteLiveSha256AtT001
}
if (Test-038Staged) {
    Test-Pass "TEST-038 lite-spec change staged, live file unmodified, manifest hash matches (AC-023)"
} else {
    Test-Fail "TEST-038 lite-spec change staged, live file unmodified, manifest hash matches (AC-023)"
}

# TEST-039 -- CI-registration conformance. Traced from a CI entry point
# (.github/workflows/*.yml) to this suite, in both runtimes. Expected RED
# against the live tree until a human applies the separately staged
# workflow patch (R-OQ-8 part 3) -- not this task's or T-005's to fix.
function Test-039CiRegistered {
    $ciDir = Join-Path $repositoryRoot ".github/workflows"
    if (-not (Test-Path -LiteralPath $ciDir)) { return $false }
    $hasSh = $false
    $hasPs1 = $false
    Get-ChildItem -LiteralPath $ciDir -File | Where-Object { $_.Extension -in ".yml", ".yaml" } | ForEach-Object {
        $wfText = Get-TextOrEmpty $_.FullName
        if ($wfText.Contains("design-system-contract.tests.sh")) { $hasSh = $true }
        if ($wfText.Contains("design-system-contract.tests.ps1")) { $hasPs1 = $true }
    }
    return $hasSh -and $hasPs1
}
if (Test-039CiRegistered) {
    Test-Pass "TEST-039 this feature's assertions are reachable from a CI entry point (AC-024)"
} else {
    Test-Fail "TEST-039 this feature's assertions are reachable from a CI entry point (AC-024) -- DESIGNED RED: staged workflow patch not yet applied (R-OQ-8 part 3)"
}

if (($dslFlat -cmatch '## Ensure design-system/') -and $dslText.Contains("ui-ux-pro-max") `
        -and $dslText.Contains("design-system --persist") -and $dslText.Contains("figma-dtcg-import") `
        -and $dslText.Contains("design-system/design-tokens.json") -and $dslText.Contains("MASTER.md")) {
    Test-Pass "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression) -- ASCII subset; the em-dash D6 fallback note is asserted by the sh twin, following this file's existing DS-006 precedent"
} else {
    Test-Fail "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression) -- ASCII subset; the em-dash D6 fallback note is asserted by the sh twin, following this file's existing DS-006 precedent"
}

if (($loopFlat -match 'no upload') -and ($loopFlat -match 'decline')) {
    Test-Pass "TEST-041 a decline blocks that upload -- no upload occurs (AC-026)"
} else {
    Test-Fail "TEST-041 a decline blocks that upload -- no upload occurs (AC-026)"
}

if ($loopFlat -match 'next (one|attempt).{0,20}asks again|next upload attempt.{0,20}prompts again') {
    Test-Pass "TEST-042 the next upload attempt within the same scope prompts again (AC-026)"
} else {
    Test-Fail "TEST-042 the next upload attempt within the same scope prompts again (AC-026)"
}

if ($loopFlat -match 'not a persisted refusal|no standing forbiddance') {
    Test-Pass "TEST-043 a decline is distinguished from AC-019's persistent not-permitted outcome (AC-026)"
} else {
    Test-Fail "TEST-043 a decline is distinguished from AC-019's persistent not-permitted outcome (AC-026)"
}

if ($dslFlat.Contains("Egress-Destination") -and ($dslFlat -match 'project selected in step 1|selected in step 1')) {
    Test-Pass "TEST-044 the consent names the destination project as part of its coverage (AC-027)"
} else {
    Test-Fail "TEST-044 the consent names the destination project as part of its coverage (AC-027)"
}

if ($dslFlat -match 'does not carry to|re-enters step 4|different destination.{0,30}gated again') {
    Test-Pass "TEST-045 a different destination project does not inherit the consent, is gated again (AC-027)"
} else {
    Test-Fail "TEST-045 a different destination project does not inherit the consent, is gated again (AC-027)"
}

if (($dslFlat -match 'withdraw') -and ($dslFlat -match 'mid-session')) {
    Test-Pass "TEST-046 a mid-session withdrawal path is stated (AC-028)"
} else {
    Test-Fail "TEST-046 a mid-session withdrawal path is stated (AC-028)"
}

if (($dslFlat -match 'withdraw') -and ($dslFlat -match 'gated again|does not hold')) {
    Test-Pass "TEST-047 after withdrawal, the next upload within that scope is gated again (AC-028)"
} else {
    Test-Fail "TEST-047 after withdrawal, the next upload within that scope is gated again (AC-028)"
}

if (($loopFlat -match 'future regenerations') -and ($loopFlat -match 'for this session')) {
    Test-Pass "TEST-048 disclosure element (d): coverage includes future regenerations, this session (AC-029)"
} else {
    Test-Fail "TEST-048 disclosure element (d): coverage includes future regenerations, this session (AC-029)"
}

if (($loopFlat -match 'pull direction') -and ($loopFlat -match 'human-supplied project name')) {
    Test-Pass "TEST-049 disclosure element (e): the pull direction also transmits a project name (AC-029)"
} else {
    Test-Fail "TEST-049 disclosure element (e): the pull direction also transmits a project name (AC-029)"
}

if (($loopFlat -match 'asserting.{0,20}authority') -and ($loopFlat -match 'claim, not a check|not enforced')) {
    Test-Pass "TEST-050 disclosure element (f): operator asserts authority to send content externally (AC-029)"
} else {
    Test-Fail "TEST-050 disclosure element (f): operator asserts authority to send content externally (AC-029)"
}

if (($loopFlat -match 'not change consent state') -and ($loopFlat -match 'reports the failure') `
        -and ($loopFlat -match 'no re-prompt|without a new consent prompt') -and ($loopFlat -match 'no standing forbiddance')) {
    Test-Pass "TEST-051 push-failure rule, all four parts (AC-030)"
} else {
    Test-Fail "TEST-051 push-failure rule, all four parts (AC-030)"
}

Write-Host "PASS: $Script:TestPass"
Write-Host "FAIL: $Script:TestFail"
if ($Script:TestFail -gt 0) {
    exit 1
}
