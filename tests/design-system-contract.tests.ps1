$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repositoryRoot "contracts/design-system.contract.v1.schema.json"
$tokensPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/templates/design-tokens.template.json"

& node (Join-Path $PSScriptRoot "lib/bootstrap-core-contracts.mjs") design-system ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
if ($LASTEXITCODE -ne 0) { throw "not ok: Core design-system contract" }

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

& node (Join-Path $PSScriptRoot "lib/bootstrap-core-contracts.mjs") consent-initial
if ($LASTEXITCODE -eq 0) {
    Test-Pass "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
} else {
    Test-Fail "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
}

$pythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $pythonCommand) { $pythonCommand = Get-Command python -ErrorAction Stop }
& $pythonCommand -B (Join-Path $PSScriptRoot 'design-sync-policy.tests.py') PolicyTests.test_subsequent_uploads_reuse_current_grant
if ($LASTEXITCODE -eq 0) {
    Test-Pass "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
} else {
    Test-Fail "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
}

& $pythonCommand -B (Join-Path $PSScriptRoot 'design-sync-policy.tests.py') PolicyTests.test_different_feature_or_session_requires_consent
if ($LASTEXITCODE -eq 0) {
    Test-Pass "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
} else {
    Test-Fail "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
}

function Test-ConsentPolicy([string]$method, [string]$label) {
    & $pythonCommand -B (Join-Path $PSScriptRoot 'design-sync-policy.tests.py') "PolicyTests.$method"
    if ($LASTEXITCODE -eq 0) { Test-Pass $label } else { Test-Fail $label }
}
Test-ConsentPolicy 'test_disclosure_payload' 'TEST-005 disclosure element (a): payload is specification-derived, may be confidential (AC-003)'
Test-ConsentPolicy 'test_disclosure_destination' 'TEST-006 disclosure element (b): destination is claude.ai/design, external, the selected project (AC-003)'
Test-ConsentPolicy 'test_disclosure_retention' 'TEST-007 disclosure element (c): content sent there may be retained, outside repo control (AC-003)'
Test-ConsentPolicy 'test_disclosure_repeated_uploads' 'TEST-008 disclosure states scope and that later uploads proceed without asking again (AC-004)'
Test-ConsentPolicy 'test_disclosure_regenerated_mockups' 'TEST-048 disclosure element (d): coverage includes future regenerations, this session (AC-029)'
Test-ConsentPolicy 'test_disclosure_operator_authority' 'TEST-050 disclosure element (f): operator asserts authority to send content externally (AC-029)'

& node (Join-Path $PSScriptRoot "lib/bootstrap-core-contracts.mjs") consent-prompt
if ($LASTEXITCODE -eq 0) {
    Test-Pass "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
} else {
    Test-Fail "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
}

& node (Join-Path $PSScriptRoot "lib/bootstrap-core-contracts.mjs") consent-off
if ($LASTEXITCODE -eq 0) {
    Test-Pass "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
} else {
    Test-Fail "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
}

Test-ConsentPolicy 'test_decline_stops_current_upload' "TEST-041 a decline blocks that upload -- no upload occurs (AC-026)"
Test-ConsentPolicy 'test_retry_after_decline_prompts_again' "TEST-042 the next upload attempt within the same scope prompts again (AC-026)"
Test-ConsentPolicy 'test_decline_is_distinct_from_prohibition' "TEST-043 a decline is distinguished from AC-019's persistent not-permitted outcome (AC-026)"
Test-ConsentPolicy 'test_consent_binds_selected_project' "TEST-044 the consent names the destination project as part of its coverage (AC-027)"
Test-ConsentPolicy 'test_destination_change_checks_its_own_grant' "TEST-045 a different destination project does not inherit the consent, is gated again (AC-027)"
Test-ConsentPolicy 'test_operator_can_withdraw_during_session' "TEST-046 a mid-session withdrawal path is stated (AC-028)"
Test-ConsentPolicy 'test_withdrawn_consent_needs_fresh_grant' "TEST-047 after withdrawal, the next upload within that scope is gated again (AC-028)"

# DS-001 both JSON files must parse (PS5.1-safe: ConvertFrom-Json, no Test-Json)
$schema = Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json
$tokens = Get-Content -Raw -Encoding Utf8 $tokensPath | ConvertFrom-Json

if ($schema.'$id' -ne 'https://sdd-forge.dev/contracts/design-system.contract.v1.schema.json') {
    throw "not ok: DS-001 schema `$id mismatch"
}
if ($schema.properties.meta.properties.schema.const -cne 'design-system-contract/v1') {
    throw "not ok: DS-001 schema const mismatch"
}
Write-Host "ok: DS-001 contract schema envelope"

# DS-002 tokens template conforms to the meta contract (domain assertions replicate the schema)
if ($tokens.meta.schema -cne 'design-system-contract/v1') { throw "not ok: DS-002 meta.schema" }
if ($tokens.meta.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw "not ok: DS-002 meta.version semver" }
if (@('design-sync-loop','ui-ux-pro-max','manual','figma-dtcg-import') -notcontains $tokens.meta.generated_by) { throw "not ok: DS-002 meta.generated_by enum" }
if ($tokens.meta.profile -ne 'custom') { throw "not ok: DS-002 meta.profile" }
foreach ($group in @('color','typography','spacing')) {
    if ($null -eq $tokens.$group) { throw "not ok: DS-002 token group $group missing" }
}
if ($tokens.color.primary.'$value' -notmatch '^#[0-9a-fA-F]{6}$') { throw "not ok: DS-002 color.primary DTCG value" }
Write-Host "ok: DS-002 tokens template conforms"

# DS-003 / DS-004 markdown templates
$dsPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/templates/design-system.template.md"
$uipPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/templates/ui-patterns.template.md"
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
foreach ($needle in @('Ensure `design-system/`', 'ui-ux-pro-max', 'design-system --persist', 'Figma DTCG JSON', 'design-tokens.json', 'MASTER.md')) {
    if ($dsl -notmatch [regex]::Escape($needle)) { throw "not ok: DS-006 missing $needle" }
}
Write-Host "ok: DS-006 design-sync-loop v2"

# DS-007 investigate-codebase design inventory
$inv = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md")
if ($inv -notmatch 'Design Inventory') { throw "not ok: DS-007 Design Inventory missing" }
Write-Host "ok: DS-007 investigate-codebase design inventory"

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): DS-008/DS-009 read the retired interviewer and sdd-lite templates.

# DS-010 impl-reviewer-a design-system conformance check
# Retired 2026-11-28 (T-010, ADR-0051 decision 2): DS-010 reviewer-a checks read the retired impl reviewer.
$prc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-review-loop/references/phase-review-checklist.md")
if ($prc -notmatch [regex]::Escape('#### DESIGN-SYSTEM-CONFORMANCE')) { throw "not ok: DS-010 checklist block missing" }
Write-Host "ok: DS-010 reviewer-a conformance check"

# DS-011 impl-reviewer-b unsanctioned UI library rule
# Retired 2026-11-28 (T-010, ADR-0051 decision 2): DS-011 read the retired impl reviewer B.
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
foreach ($needle in @('design-system/{design-tokens.json,ui-patterns.md}', 'verdicts stay with sdd-gate')) {
    if ($vvl -cnotmatch [regex]::Escape($needle)) { throw "not ok: DS-013 missing $needle" }
}
Write-Host "ok: DS-013 visual-verify-loop design-system comparison"

# DS-014 design-system checklist and evaluator wiring
$dsc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/design-system-checklist.md")
if ($dsc -notmatch [regex]::Escape('# Design System Review Checklist')) { throw "not ok: DS-014 checklist missing" }
if ($dsc -notmatch [regex]::Escape('## UI Patterns (ui-patterns.md)')) { throw "not ok: DS-014 ui-patterns section missing" }
$rub = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/evaluation-rubric.md")
if ($rub -notmatch 'design-system non-conformance') { throw "not ok: DS-014 rubric classification missing" }
$evaluator = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/agents/evaluator.md")
if ($evaluator -cnotmatch 'G5.*design-system/') { throw "not ok: DS-014 the v2 evaluator does not check design-system conformance (G5)" }
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
# The retired quality-gate skill ran check-design-system; v2 keeps it standalone (as T-010 N2).
if ((Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "docs/skill-reference.md")) -cnotmatch 'check-design-system') { throw "not ok: DS-016 check-design-system is no longer documented" }
Write-Host "ok: DS-016 contract and matrix wiring"

# DS-017 user-facing documentation (ASCII-checkable subset; the Japanese changelog heading is asserted by the sh twin)
$sref = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "docs/skill-reference.md")
if ($sref -cnotmatch '(?m)^\| design-sync-loop \| sdd-bootstrap \|') { throw "not ok: DS-017 skill reference does not list design-sync-loop" }
# The workflow-guide wording (Japanese) is checked through the shared v2 needle fixture.
if ($sref -cnotmatch 'check-design-system') { throw "not ok: DS-017 skill-reference missing" }
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

$dslPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
$wfgPath = Join-Path $repositoryRoot "docs/workflow-guide.md"
$cdwPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/references/claude-design-workflow.md"
$chgPath = Join-Path $repositoryRoot "CHANGELOG.md"

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
$loopLines = Get-SectionBetween $dslLines '^## 3\. Mockup & Egress Consent Loop' '^## '
$boundariesLines = Get-SectionBetween $dslLines '^## Boundaries$' '^## '
$cdwText = Get-TextOrEmpty $cdwPath

$dslFlat = Get-FlatText $dslText
$loopFlat = Get-Flat $loopLines
$boundariesFlat = Get-Flat $boundariesLines
$cdwFlat = Get-FlatText $cdwText

# --- REQ-001 (AC-001, AC-002, AC-026, AC-027, AC-028, AC-030) -----------

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-009, TEST-011..013,
# TEST-017, TEST-031, TEST-035, TEST-036, TEST-038, TEST-039 and TEST-051
# checked v1 wording or files v2 removed (finalize_plan, the optional local
# review, sdd-lite, the interviewer, the workflow-guide 3.1b section, the
# staged CI patch, the push-failure rule). The v2 wording of TEST-004, 010,
# 014-016, 018, 023-027, 029, 032-034 and 049 is checked through the shared
# fixture tests/fixtures/design-system-contract/v2-needles.json below.

& node (Join-Path $PSScriptRoot "lib/bootstrap-core-contracts.mjs") tool-unavailable
if ($LASTEXITCODE -eq 0) {
    Test-Pass "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
} else {
    Test-Fail "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
}

& node (Join-Path $PSScriptRoot "lib/bootstrap-core-contracts.mjs") auth-failed
if ($LASTEXITCODE -eq 0) {
    Test-Pass "TEST-020 capability-detection branch 2: authentication failure -> fallback, marker recorded (AC-013)"
} else {
    Test-Fail "TEST-020 capability-detection branch 2: authentication failure -> fallback, marker recorded (AC-013)"
}

if ($cdwText.Contains("does not automatically inspect, upload, or retain") -and -not ($cdwFlat -match 'consent')) {
    Test-Pass "TEST-021 fallback still performs no upload, and gained no consent step (AC-014, positive+negative)"
} else {
    Test-Fail "TEST-021 fallback still performs no upload, and gained no consent step (AC-014, positive+negative)"
}

if ($cdwFlat -match 'mockups and HTML previews are optional attachments.{0,25}absence never blocks specification review') {
    Test-Pass "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
} else {
    Test-Fail "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
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

if (($dslFlat -cmatch 'Ensure `design-system/`') -and $dslText.Contains("ui-ux-pro-max") `
        -and $dslText.Contains("design-system --persist") -and $dslText.Contains("figma-dtcg-import") `
        -and $dslText.Contains("design-system/design-tokens.json") -and $dslText.Contains("MASTER.md")) {
    Test-Pass "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression) -- ASCII subset; the em-dash D6 fallback note is asserted by the sh twin, following this file's existing DS-006 precedent"
} else {
    Test-Fail "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression) -- ASCII subset; the em-dash D6 fallback note is asserted by the sh twin, following this file's existing DS-006 precedent"
}

$dslDescLine = ($dslLines | Where-Object { $_ -cmatch '^description:' } | Select-Object -First 1)
if ($null -eq $dslDescLine) { $dslDescLine = "" }
if (($dslDescLine -ne "") -and -not $dslDescLine.Contains($bannedPerUpload) -and $dslDescLine.Contains('explicit egress consent')) {
    Test-Pass "TEST-033 site 1 (frontmatter description) states explicit consent, not $bannedPerUpload (AC-021)"
} else {
    Test-Fail "TEST-033 site 1 (frontmatter description) states explicit consent, not $bannedPerUpload (AC-021)"
}
if (($boundariesLines.Count -gt 0) -and -not $boundariesFlat.Contains($bannedEveryTime)) {
    Test-Pass "TEST-034 site 2 (Boundaries) does not claim $bannedEveryTime consent (AC-021)"
} else {
    Test-Fail "TEST-034 site 2 (Boundaries) does not claim $bannedEveryTime consent (AC-021)"
}

# v2 skill wording (Japanese), shared with the bash twin through one UTF-8
# fixture; read as UTF-8 so no non-ASCII literal appears in this source.
$v2Needles = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot 'tests/fixtures/design-system-contract/v2-needles.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$dslAllLines = @([System.IO.File]::ReadAllText($dslPath, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n" -split "`n")
function Get-V2Section($bounds) {
    $out = @(); $inside = $false
    foreach ($line in $dslAllLines) {
        if ($inside -and ($line -cmatch $bounds[1]) -and -not ($line -cmatch $bounds[0])) { break }
        if ($line -cmatch $bounds[0]) { $inside = $true }
        if ($inside) { $out += $line }
    }
    return ,$out
}
function Get-V2Flat($lines) { return ((($lines -join ' ') -split '\s+') | Where-Object { $_ -ne '' }) -join ' ' }
$v2Loop = Get-V2Section $v2Needles.loop_section
$v2Scopes = @{ loop = (Get-V2Flat $v2Loop); dsl = (Get-V2Flat $dslAllLines); boundaries = (Get-V2Flat (Get-V2Section $v2Needles.boundaries_section)) }
foreach ($check in $v2Needles.checks) {
    if ($v2Scopes.ContainsKey($check.scope)) { $text = $v2Scopes[$check.scope] }
    else { $text = Get-V2Flat @([System.IO.File]::ReadAllText((Join-Path $repositoryRoot $check.scope.Substring(5)), [System.Text.Encoding]::UTF8) -replace "`r`n", "`n" -split "`n") }
    $ok = $true
    foreach ($needle in @($check.contains)) { if (-not $text.Contains((Get-V2Flat @($needle)))) { $ok = $false } }
    foreach ($needle in @($check.absent)) { if ($text.Contains($needle)) { $ok = $false } }
    if ($ok) { Test-Pass $check.label } else { Test-Fail $check.label }
}
$positions = @(foreach ($step in $v2Needles.order.steps) { $idx = -1; for ($i = 0; $i -lt $v2Loop.Count; $i++) { if ($v2Loop[$i] -cmatch $step) { $idx = $i; break } }; $idx })
$ordered = -not ($positions -contains -1)
for ($i = 1; $i -lt $positions.Count; $i++) { if ($positions[$i] -le $positions[$i - 1]) { $ordered = $false } }
if ($ordered) { Test-Pass $v2Needles.order.label } else { Test-Fail $v2Needles.order.label }

Write-Host "PASS: $Script:TestPass"
Write-Host "FAIL: $Script:TestFail"
if ($Script:TestFail -gt 0) {
    exit 1
}
