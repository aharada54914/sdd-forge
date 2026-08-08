$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# design-sync-standing-consent (issue #140, DS-31) -- TEST-001..TEST-053,
# TEST-055, TEST-056 (55 blocking rows) plus TEST-054 (Deferred, non-
# blocking) -- specs/design-sync-standing-consent/tasks.md T-001.
# ASCII-only source throughout (ports no .sh -> .ps1 literal that requires
# a non-ASCII code point; this suite is authored directly in both runtimes,
# not translated, and every literal it checks for is ASCII).
#
# Case-sensitivity (AGENTS.md "Author-time sweeps" item 1): PowerShell's
# `-match`/`-notmatch` are case-INSENSITIVE by default, unlike the `.sh`
# twin's plain `grep -E`/`grep -Eq`. Every site below that mirrors a
# case-sensitive `.sh` check (`grep -F`, or `grep -E` without `-i`) uses
# `-cmatch`/`.Contains()` here; every site mirroring a case-insensitive
# `.sh` check (`grep -Ei`/`grep -Fi`) uses plain `-match` (or, for a
# case-insensitive literal-substring check, `-match [regex]::Escape(...)`).
# No `Select-String`, `-split`, `[regex]` static methods, `switch
# -wildcard`/`-regex`, or `Sort-Object` are used anywhere in this file, so
# the cmdlet-level layer of the sweep (item 1(b)) has no site to cover.

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

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

$agPath = Join-Path $repositoryRoot "AGENTS.md"
$dslPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
$cdwPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md"
$runAllShPath = Join-Path $repositoryRoot "tests/run-all.sh"
$runAllPs1Path = Join-Path $repositoryRoot "tests/run-all.ps1"
$dscPs1Path = Join-Path $repositoryRoot "tests/design-system-contract.tests.ps1"
$ciDir = Join-Path $repositoryRoot ".github/workflows"
$baselinePs1 = Join-Path $repositoryRoot "specs/design-sync-standing-consent/verification/T-001/ds29-baseline-ps1.log"

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

# Lines from the first line matching $startPattern (inclusive) up to, but
# excluding, the first later line matching $endPattern -- mirrors the .sh
# twin's section_between/section_of_lines (both collapse to one function
# here since a PowerShell line array works uniformly whether it came from a
# file or from an earlier Get-SectionBetween call). -cmatch/-cnotmatch, not
# -match: the .sh twin's awk-based helpers find section boundaries with
# `~`, which is case-SENSITIVE, and BL-008 dual-runtime parity requires
# both sides to accept/reject the same heading.
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

# Collapse an array of lines (or a single multi-line text) to one
# whitespace-normalized string, so a multi-word phrase assertion is not
# defeated by Markdown's ordinary prose line-wrapping.
function Get-Flat([string[]]$lines) {
    return (($lines -join " ") -replace '\s+', ' ')
}
function Get-FlatText([string]$text) {
    return ($text -replace '\s+', ' ')
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

# First line index (0-based) matching regex $pattern in $lines whose text
# contains $literal, or -1 if none -- used for the two anchor lookups in
# Test-049MinimalDiff.
function Get-FirstLineIndexContaining([string[]]$lines, [string]$literal) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Contains($literal)) { return $i }
    }
    return -1
}

# Every "PASS: DS-NNN ..." / "PASS: TEST-NNN ..." line recorded in the
# documented baseline log at $baselineLines must still be present, verbatim,
# in a fresh run of DS-29's own suite ($currentLines, already captured).
# Mirrors the .sh twin's no_green_to_red_flip.
function Test-NoGreenToRedFlip([string[]]$baselineLines, [string[]]$currentLines) {
    if ($baselineLines.Count -eq 0) { return $false }
    $currentSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($line in $currentLines) { [void]$currentSet.Add($line) }
    foreach ($line in $baselineLines) {
        if (($line.StartsWith("PASS: DS-")) -or ($line.StartsWith("PASS: TEST-"))) {
            if (-not $currentSet.Contains($line)) { return $false }
        }
    }
    return $true
}

# First line matching a literal "PASS: <id> " prefix (ordinal, case-
# sensitive), used for TEST-051's five explicitly-named rows and TEST-052.
function Test-HasPassPrefix([string[]]$lines, [string]$prefix) {
    foreach ($line in $lines) {
        if ($line.StartsWith($prefix)) { return $true }
    }
    return $false
}

# Runtime-assembled banned literals (AGENTS.md "Author-time sweeps" item 2;
# requirements.md Edge Case 8; acceptance-tests.md Notes). TEST-046's and
# TEST-050's own check logic and pass/fail labels must never embed either
# banned string as a contiguous literal in this suite's own source --
# assembled here from non-contiguous parts instead, exactly as the .sh twin
# and DS-29's own TEST-033..TEST-036 already do. Every other row in this
# suite checking for the *presence* of this feature's own setting key in
# AGENTS.md or design-sync-loop/SKILL.md writes it as an ordinary literal
# via this same variable -- the constraint applies only to the two negative
# checks against claude-design-workflow.md.
$bannedKey = "ds_upload" + "_consent"
$bannedWord = "con" + "sent"

$agText = Get-TextOrEmpty $agPath
$agFlat = Get-FlatText $agText
$agLines = Get-LinesOrEmpty $agPath
$agPsLines = Get-SectionBetween $agLines '^## Project Settings$' '^## '
$agPsFlat = Get-Flat $agPsLines
$agKeyLine = ""
foreach ($line in $agLines) {
    if ($line.Contains($bannedKey)) { $agKeyLine = $line; break }
}

$dslText = Get-TextOrEmpty $dslPath
$dslFlat = Get-FlatText $dslText
$dslLines = Get-LinesOrEmpty $dslPath
$loopLines = Get-SectionBetween $dslLines '^## Loop$' '^## '
$loopFlat = Get-Flat $loopLines
$step3Lines = Get-SectionBetween $loopLines '^3\. \*\*Resolve egress consent' '^4\. \*\*Obtain informed consent'
$step3Flat = Get-Flat $step3Lines
$standingLines = Get-SectionBetween $step3Lines '\*\*standing\*\*' '\*\*off\*\*'
$standingFlat = Get-Flat $standingLines
$offLines = Get-SectionBetween $step3Lines '\*\*off\*\*' 'ZZZ_NEVER_MATCHES_ZZZ'
$offFlat = Get-Flat $offLines
$whicheverLines = Get-SectionBetween $step3Lines 'Whichever regime or occasion' 'ZZZ_NEVER_MATCHES_ZZZ'
$whicheverFlat = Get-Flat $whicheverLines

$cdwText = Get-TextOrEmpty $cdwPath
$cdwFlat = Get-FlatText $cdwText

# --- REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-031) -----------------------

if (($agKeyLine -ne "") -and $agKeyLine.Contains("standing") -and $agKeyLine.Contains("per-feature") `
        -and $agKeyLine.Contains("off") -and -not ($agKeyLine -match 'e\.g\.|similar|etc\.|and so on|for example')) {
    Test-Pass "TEST-001 the setting's value domain is named as exactly three alternatives, no fourth value, no hedge (AC-001)"
} else {
    Test-Fail "TEST-001 the setting's value domain is named as exactly three alternatives, no fourth value, no hedge (AC-001)"
}

$hasProjectSettingsHeading = $false
foreach ($line in $agLines) { if ($line -ceq "## Project Settings") { $hasProjectSettingsHeading = $true; break } }
if ($hasProjectSettingsHeading -and $agPsFlat.Contains($bannedKey)) {
    Test-Pass "TEST-002 a ## Project Settings heading exists and the setting key is named in a table row under it (AC-002)"
} else {
    Test-Fail "TEST-002 a ## Project Settings heading exists and the setting key is named in a table row under it (AC-002)"
}

if (($agPsFlat -match 'absent.{0,10}section entirely') -and $agPsFlat.Contains("per-feature")) {
    Test-Pass "TEST-003 branch 1: a wholly absent Project Settings section is stated to resolve to per-feature (AC-003)"
} else {
    Test-Fail "TEST-003 branch 1: a wholly absent Project Settings section is stated to resolve to per-feature (AC-003)"
}

if (($agPsFlat -match 'absent key') -and $agPsFlat.Contains("per-feature")) {
    Test-Pass "TEST-004 branch 2: a present section that omits the setting key is stated to resolve to per-feature (AC-003)"
} else {
    Test-Fail "TEST-004 branch 2: a present section that omits the setting key is stated to resolve to per-feature (AC-003)"
}

if (($agPsFlat -ne "") -and $agPsFlat.Contains($bannedKey) -and -not ($agPsFlat -cmatch 'Codex|Claude Code')) {
    Test-Pass "TEST-005 the setting's own definition carries no host-name conditional (AC-004)"
} else {
    Test-Fail "TEST-005 the setting's own definition carries no host-name conditional (AC-004)"
}

if ($agPsFlat -match 'off.{0,10}:.{0,40}forbid.{0,30}every host|forbid.{0,30}upload.{0,20}every host') {
    Test-Pass "TEST-006 off's definition states the forbiddance applies on every host, unconditionally (AC-005)"
} else {
    Test-Fail "TEST-006 off's definition states the forbiddance applies on every host, unconditionally (AC-005)"
}

if (($step3Flat -ne "") -and $step3Flat.Contains($bannedKey) -and -not ($step3Flat -cmatch 'Codex|Claude Code')) {
    Test-Pass "TEST-007 step 3's outer selector carries no tool-presence conditional as part of what the three regimes mean (AC-006)"
} else {
    Test-Fail "TEST-007 step 3's outer selector carries no tool-presence conditional as part of what the three regimes mean (AC-006)"
}

# --- REQ-003 (AC-007, AC-008, AC-009, AC-030, AC-010) -- standing -----------

if ($standingFlat -match 'never produces.{0,10}outcome \(b\)|never produces.{0,10}\(b\)') {
    Test-Pass "TEST-008 under standing, step 3 never produces its 'must be requested' outcome (AC-007)"
} else {
    Test-Fail "TEST-008 under standing, step 3 never produces its 'must be requested' outcome (AC-007)"
}

if ($standingFlat.Contains("Design-Source")) {
    Test-Pass "TEST-009 the standing write is stated to go to the layer file's own Design-Source section specifically (AC-008)"
} else {
    Test-Fail "TEST-009 the standing write is stated to go to the layer file's own Design-Source section specifically (AC-008)"
}

if ($standingFlat -cmatch 'Ds-Upload-Consent-Setting: standing[^).]{0,30}(this|that|the current) destination') {
    Test-Pass "TEST-010 the first-occurrence test is scoped to (feature, destination), not the feature alone (AC-009, structural)"
} else {
    Test-Fail "TEST-010 the first-occurrence test is scoped to (feature, destination), not the feature alone (AC-009, structural)"
}

if (($standingFlat -match 'different destination.{0,60}fresh') `
        -and ($standingFlat -match 'own one-time write|gets its own one-time write')) {
    Test-Pass "TEST-011 a different destination for an already-recorded feature triggers a fresh one-time write (AC-030)"
} else {
    Test-Fail "TEST-011 a different destination for an already-recorded feature triggers a fresh one-time write (AC-030)"
}

if ($standingFlat.Contains("Egress-Consent: granted")) {
    Test-Pass "TEST-012 the one-time record's Egress-Consent value is granted, not a new fourth value (AC-010)"
} else {
    Test-Fail "TEST-012 the one-time record's Egress-Consent value is granted, not a new fourth value (AC-010)"
}

# --- REQ-004 (AC-011, AC-012, AC-013, AC-014) -- off ------------------------

if ($offFlat -match 'always resolves to outcome \(c\)') {
    Test-Pass "TEST-013 under off, step 3's resolved outcome is always outcome (c) (AC-011)"
} else {
    Test-Fail "TEST-013 under off, step 3's resolved outcome is always outcome (c) (AC-011)"
}

if ($offFlat -match 'manual fallback[^.]{0,80}no upload attempt|no upload attempt[^.]{0,80}manual fallback') {
    Test-Pass "TEST-014 outcome (c) routes to the manual fallback and no upload is attempted (combined, one clause) (AC-012)"
} else {
    Test-Fail "TEST-014 outcome (c) routes to the manual fallback and no upload is attempted (combined, one clause) (AC-012)"
}

if ($offFlat -match 'write a record|writes a record') {
    Test-Pass "TEST-015 an outcome record is written for the off resolution (existence) (AC-012)"
} else {
    Test-Fail "TEST-015 an outcome record is written for the off resolution (existence) (AC-012)"
}

if ($offFlat.Contains("Ds-Upload-Consent-Setting: off")) {
    Test-Pass "TEST-016 that record carries Ds-Upload-Consent-Setting: off specifically (AC-012)"
} else {
    Test-Fail "TEST-016 that record carries Ds-Upload-Consent-Setting: off specifically (AC-012)"
}

if (($offFlat -match 'persistently.{0,60}as long as the setting reads off') `
        -and ($offFlat -match 'not the transient per-attempt decline|does not lapse')) {
    Test-Pass "TEST-017 off's forbiddance is stated as persistent, distinguished from a transient decline (AC-013)"
} else {
    Test-Fail "TEST-017 off's forbiddance is stated as persistent, distinguished from a transient decline (AC-013)"
}

if (($agPsFlat -match 'off.{0,10}:.{0,40}forbid.{0,30}every host|forbid.{0,30}upload.{0,20}every host') `
        -and ($offFlat -match 'every host')) {
    Test-Pass "TEST-018 the forbiddance holds on every host, in both AGENTS.md and the loop's off branch (AC-014, cross-referencing TEST-006)"
} else {
    Test-Fail "TEST-018 the forbiddance holds on every host, in both AGENTS.md and the loop's off branch (AC-014, cross-referencing TEST-006)"
}

# --- REQ-005 (AC-015) -- DS-29's own text, unmodified, per span ------------

if ($loopFlat.Contains("The scope is the conjunction of those two coordinates and both must match") `
        -and $loopFlat.Contains("neither does one the operator withdrew mid-session")) {
    Test-Pass "TEST-019 step 3(a)'s scope clause is present, unmodified (AC-015)"
} else {
    Test-Fail "TEST-019 step 3(a)'s scope clause is present, unmodified (AC-015)"
}

if (($loopFlat -match 'Consent has not been obtained for this scope') -and $loopFlat.Contains("go to 4")) {
    Test-Pass "TEST-020 step 3(b)'s routing clause is present, unmodified (AC-015)"
} else {
    Test-Fail "TEST-020 step 3(b)'s routing clause is present, unmodified (AC-015)"
}

if ($loopFlat.Contains("This outcome is persistent for the scope") `
        -and $loopFlat.Contains("a decline is transient, binds only the upload attempt it was asked about")) {
    Test-Pass "TEST-021 step 3(c)'s not-permitted/persistence/decline-distinction clauses are present, unmodified (AC-015)"
} else {
    Test-Fail "TEST-021 step 3(c)'s not-permitted/persistence/decline-distinction clauses are present, unmodified (AC-015)"
}

if ($loopFlat.Contains("asserting they have authority to send this content externally") `
        -and $loopFlat.Contains("not knowable from this repository") `
        -and ($loopFlat -match 'not to a byte sequence')) {
    Test-Pass "TEST-022 step 4's informed-consent disclosure content is present, unmodified (AC-015)"
} else {
    Test-Fail "TEST-022 step 4's informed-consent disclosure content is present, unmodified (AC-015)"
}

if ($loopFlat.Contains("with no bypass") `
        -and ($loopFlat -match 'does not presume.{0,10}an interactive human is present at this point')) {
    Test-Pass "TEST-023 step 5's pre-upload check point text is present, unmodified (AC-015)"
} else {
    Test-Fail "TEST-023 step 5's pre-upload check point text is present, unmodified (AC-015)"
}

if ($loopFlat.Contains("does not change consent state, because consent is bound to the scope") `
        -and $loopFlat.Contains("resumes at 5 with no re-prompt") `
        -and ($loopFlat -match "push failure is not 3\(c\)'?s persistent")) {
    Test-Pass "TEST-024 step 6's push-failure rule is present, unmodified (AC-015)"
} else {
    Test-Fail "TEST-024 step 6's push-failure rule is present, unmodified (AC-015)"
}

if ($loopFlat.Contains("apply their feedback and return to 2") `
        -and $loopFlat.Contains("The cycle re-enters generation, never the consent step, because the scope has not changed") `
        -and $loopFlat.Contains("Local review is OPTIONAL and non-blocking") `
        -and $loopFlat.Contains("mockup content can reach claude.ai without any human having read it")) {
    Test-Pass "TEST-025 step 7's review/regeneration cycle text is present, unmodified (AC-015)"
} else {
    Test-Fail "TEST-025 step 7's review/regeneration cycle text is present, unmodified (AC-015)"
}

# --- REQ-006 (AC-016, AC-017, AC-018, AC-019, AC-029) -----------------------

if ($dslText.Contains("Egress-Consent-Party")) {
    Test-Pass "TEST-026 Egress-Consent-Party is enumerated by name in the record table (AC-016)"
} else {
    Test-Fail "TEST-026 Egress-Consent-Party is enumerated by name in the record table (AC-016)"
}
if ($dslText.Contains("Egress-Consent-At")) {
    Test-Pass "TEST-027 Egress-Consent-At is enumerated by name in the record table (AC-016)"
} else {
    Test-Fail "TEST-027 Egress-Consent-At is enumerated by name in the record table (AC-016)"
}
if ($dslText.Contains("Ds-Upload-Consent-Setting")) {
    Test-Pass "TEST-028 Ds-Upload-Consent-Setting is enumerated by name in the record table (AC-016)"
} else {
    Test-Fail "TEST-028 Ds-Upload-Consent-Setting is enumerated by name in the record table (AC-016)"
}

if (($dslFlat -match 'remains? conforming') `
        -and ($dslFlat -match 'DS-29-era|missing (all )?(the )?three|lacking the three|before these fields existed')) {
    Test-Pass "TEST-029 the extensibility paragraph states a DS-29-era record remains conforming (AC-017)"
} else {
    Test-Fail "TEST-029 the extensibility paragraph states a DS-29-era record remains conforming (AC-017)"
}

if ($dslText.Contains("Egress-Consent-Scope")) {
    Test-Pass "TEST-030 Egress-Consent-Scope field name present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-030 Egress-Consent-Scope field name present, unmodified (AC-018)"
}
if ($dslText.Contains("Egress-Consent-Subject")) {
    Test-Pass "TEST-031 Egress-Consent-Subject field name present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-031 Egress-Consent-Subject field name present, unmodified (AC-018)"
}
if ($dslText.Contains("Egress-Destination")) {
    Test-Pass "TEST-032 Egress-Destination field name present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-032 Egress-Destination field name present, unmodified (AC-018)"
}
if ($dslText.Contains("Egress-Consent-Expiry")) {
    Test-Pass "TEST-033 Egress-Consent-Expiry field name present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-033 Egress-Consent-Expiry field name present, unmodified (AC-018)"
}
if ($dslText.Contains("Egress-Consent")) {
    Test-Pass "TEST-034 Egress-Consent field name present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-034 Egress-Consent field name present, unmodified (AC-018)"
}
if ($dslText.Contains("granted")) {
    Test-Pass "TEST-035 Egress-Consent domain value granted present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-035 Egress-Consent domain value granted present, unmodified (AC-018)"
}
if ($dslText.Contains("not-permitted")) {
    Test-Pass "TEST-036 Egress-Consent domain value not-permitted present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-036 Egress-Consent domain value not-permitted present, unmodified (AC-018)"
}
if ($dslText.Contains("withdrawn")) {
    Test-Pass "TEST-037 Egress-Consent domain value withdrawn present, unmodified (AC-018)"
} else {
    Test-Fail "TEST-037 Egress-Consent domain value withdrawn present, unmodified (AC-018)"
}

if (($standingFlat -match 'never a fabricated') -and ($standingFlat -match 'per-occurrence identity')) {
    Test-Pass "TEST-038 standing's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
} else {
    Test-Fail "TEST-038 standing's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
}

if (($offFlat -match 'never a fabricated') -and ($offFlat -match 'per-occurrence identity')) {
    Test-Pass "TEST-039 off's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
} else {
    Test-Fail "TEST-039 off's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
}

if ($standingFlat.Contains("Egress-Consent-Party") -and $standingFlat.Contains("Egress-Consent-At") `
        -and $standingFlat.Contains("Ds-Upload-Consent-Setting")) {
    Test-Pass "TEST-040 a standing grant's target text carries all three new fields (AC-029)"
} else {
    Test-Fail "TEST-040 a standing grant's target text carries all three new fields (AC-029)"
}

if (($whicheverFlat -match 'per-feature grant') -and $whicheverFlat.Contains("Egress-Consent-Party") `
        -and $whicheverFlat.Contains("Egress-Consent-At") -and $whicheverFlat.Contains("Ds-Upload-Consent-Setting: per-feature")) {
    Test-Pass "TEST-041 an ordinary per-feature grant's target text carries all three new fields (AC-029)"
} else {
    Test-Fail "TEST-041 an ordinary per-feature grant's target text carries all three new fields (AC-029)"
}

if (($step3Flat -match 'mid-session') -and ($step3Flat -match 'withdraw') `
        -and $step3Flat.Contains("Egress-Consent-Party") -and $step3Flat.Contains("Egress-Consent-At") `
        -and $step3Flat.Contains("Ds-Upload-Consent-Setting")) {
    Test-Pass "TEST-042 a per-feature mid-session withdrawal's target text carries all three new fields (AC-029)"
} else {
    Test-Fail "TEST-042 a per-feature mid-session withdrawal's target text carries all three new fields (AC-029)"
}

if ($offFlat.Contains("Egress-Consent-Party") -and $offFlat.Contains("Egress-Consent-At") `
        -and $offFlat.Contains("Ds-Upload-Consent-Setting: off")) {
    Test-Pass "TEST-043 an off-driven not-permitted outcome's target text carries all three new fields (AC-029)"
} else {
    Test-Fail "TEST-043 an off-driven not-permitted outcome's target text carries all three new fields (AC-029)"
}

# --- REQ-007 (AC-020, AC-021) -----------------------------------------------

if (($step3Flat -match 'every time this step is resolved') `
        -and ($step3Flat -match 'never.{0,20}cached.{0,30}(earlier|previous) resolution|not cached across resolutions')) {
    Test-Pass "TEST-044 step 3's opening sentence states the setting is re-read at every resolution, not cached (AC-020, executable oracle)"
} else {
    Test-Fail "TEST-044 step 3's opening sentence states the setting is re-read at every resolution, not cached (AC-020, executable oracle)"
}

if ($dslFlat -match 'never override.{0,60}(current|currently configured) setting|record.{0,60}(never|does not) override.{0,60}setting') {
    Test-Pass "TEST-045 the record-table text states a record's own setting value never overrides the currently configured setting (AC-021)"
} else {
    Test-Fail "TEST-045 the record-table text states a record's own setting value never overrides the currently configured setting (AC-021)"
}

# --- REQ-008 (AC-022, AC-023, AC-024) -- the fallback -----------------------

# TEST-046's own negative check must never spell out the setting's literal
# key contiguously in this suite's own source -- $bannedKey above is
# assembled from two non-contiguous literals for exactly this reason, and
# is interpolated into the pass/fail label too, mirroring the .sh twin.
if (-not $cdwFlat.Contains($bannedKey)) {
    Test-Pass "TEST-046 claude-design-workflow.md contains no occurrence of the setting's literal key identifier (AC-022)"
} else {
    Test-Fail "TEST-046 claude-design-workflow.md contains no occurrence of the setting's literal key identifier (AC-022)"
}

if (($cdwFlat -match 'upload-policy setting') -and $cdwFlat.Contains("Design-Source") `
        -and ($cdwFlat -match 'AGENTS\.md|Project Settings')) {
    Test-Pass "TEST-047 the new bullet states the setting's value/outcome survive via an indirect reference, naming Design-Source (AC-022)"
} else {
    Test-Fail "TEST-047 the new bullet states the setting's value/outcome survive via an indirect reference, naming Design-Source (AC-022)"
}

if ($cdwText.Contains("does not automatically inspect, upload, or retain") `
        -and -not ($cdwFlat -match 'automatically upload|now uploads|may now upload|will upload')) {
    Test-Pass "TEST-048 the existing no-upload statement is present, unmodified, and no new upload-enabling language appears (AC-023)"
} else {
    Test-Fail "TEST-048 the existing no-upload statement is present, unmodified, and no new upload-enabling language appears (AC-023)"
}

function Test-049MinimalDiff {
    $cdwLines = Get-LinesOrEmpty $cdwPath
    $prefixIdx = Get-FirstLineIndexContaining $cdwLines "a normal specification edit."
    $suffixIdx = Get-FirstLineIndexContaining $cdwLines "When no visual input is supplied, record:"
    if (($prefixIdx -lt 0) -or ($suffixIdx -lt 0)) { return $false }
    $prefixBlock = (($cdwLines[0..$prefixIdx] -join "`n") + "`n")
    $suffixBlock = (($cdwLines[$suffixIdx..($cdwLines.Count - 1)] -join "`n") + "`n")
    $prefixHash = Get-Sha256OfText $prefixBlock
    $suffixHash = Get-Sha256OfText $suffixBlock
    return ($prefixHash -eq "5da4093e27d8533899ded892f50727b953ef8b2e7a9612a9538601d3b9db913a") `
        -and ($suffixHash -eq "8f40b3fef3ce403eeac8f4dd762fbf33b3d37c7c32aab44088fabc620b1a67d6")
}
if (Test-049MinimalDiff) {
    Test-Pass "TEST-049 the file's content is unchanged outside the one appended bullet (AC-023, minimal diff, anchor-located byte-identity)"
} else {
    Test-Fail "TEST-049 the file's content is unchanged outside the one appended bullet (AC-023, minimal diff, anchor-located byte-identity)"
}

# TEST-050's own negative check must never spell out the banned substring
# contiguously in this suite's own source, for the same reason as TEST-046.
if (-not ($cdwFlat -match $bannedWord)) {
    Test-Pass "TEST-050 no case-insensitive occurrence of the general banned substring exists anywhere in the fallback file (AC-024)"
} else {
    Test-Fail "TEST-050 no case-insensitive occurrence of the general banned substring exists anywhere in the fallback file (AC-024)"
}

# --- REQ-009 (AC-025, AC-026) -- baseline-relative regression against DS-29

$powerShellExe = (Get-Process -Id $PID).Path
$dscCurrentOutput = & $powerShellExe -NoProfile -File $dscPs1Path 2>&1
$dscCurrentLines = @($dscCurrentOutput | ForEach-Object { $_.ToString() })
$baselineLines = Get-LinesOrEmpty $baselinePs1

if ((Test-NoGreenToRedFlip $baselineLines $dscCurrentLines) `
        -and (Test-HasPassPrefix $dscCurrentLines "PASS: TEST-010 ") `
        -and (Test-HasPassPrefix $dscCurrentLines "PASS: TEST-015 ") `
        -and (Test-HasPassPrefix $dscCurrentLines "PASS: TEST-018 ") `
        -and (Test-HasPassPrefix $dscCurrentLines "PASS: TEST-026 ") `
        -and (Test-HasPassPrefix $dscCurrentLines "PASS: TEST-040 ")) {
    Test-Pass "TEST-051 zero rows in DS-29's own suite flip from green (baseline) to red (current), TEST-010/015/018/026/040 checked explicitly (AC-025)"
} else {
    Test-Fail "TEST-051 zero rows in DS-29's own suite flip from green (baseline) to red (current), TEST-010/015/018/026/040 checked explicitly (AC-025)"
}

if ((Test-HasPassPrefix $baselineLines "PASS: TEST-021 ") -and (Test-HasPassPrefix $dscCurrentLines "PASS: TEST-021 ")) {
    Test-Pass "TEST-052 DS-29's own TEST-021 is green in both the baseline and current run, re-verified from this feature's own suite (AC-026)"
} else {
    Test-Fail "TEST-052 DS-29's own TEST-021 is green in both the baseline and current run, re-verified from this feature's own suite (AC-026)"
}

# --- REQ-010 (AC-027, AC-028) ------------------------------------------------

$runAllShText = Get-TextOrEmpty $runAllShPath
$runAllPs1Text = Get-TextOrEmpty $runAllPs1Path
if ($runAllShText.Contains("tests/design-sync-standing-consent.tests.sh") `
        -and $runAllPs1Text.Contains("tests/design-sync-standing-consent.tests.ps1")) {
    Test-Pass "TEST-053 both suite files are registered in tests/run-all.sh and tests/run-all.ps1 (AC-027)"
} else {
    Test-Fail "TEST-053 both suite files are registered in tests/run-all.sh and tests/run-all.ps1 (AC-027)"
}

# --- REQ-001 (AC-031, round 3) ----------------------------------------------

if (($agPsFlat -match 'not exactly one of.{0,40}lowercase literals') `
        -and ($agPsFlat -match 'never.{0,5}standing') -and ($agPsFlat -match 'never.{0,5}off')) {
    Test-Pass "TEST-055 branch 3: a present out-of-domain value is stated to resolve to per-feature, never standing, never off (AC-031)"
} else {
    Test-Fail "TEST-055 branch 3: a present out-of-domain value is stated to resolve to per-feature, never standing, never off (AC-031)"
}

if (($agPsFlat -match 'exact.{0,15}case-sensitive') -and $agPsFlat.Contains("Standing")) {
    Test-Pass "TEST-056 value matching is stated as exact and case-sensitive, a case variant is named as out-of-domain input (AC-031)"
} else {
    Test-Fail "TEST-056 value matching is stated as exact and case-sensitive, a case variant is named as out-of-domain input (AC-031)"
}

Write-Host "PASS: $Script:TestPass"
Write-Host "FAIL: $Script:TestFail"

# ---------------------------------------------------------------------------
# Deferred (non-blocking verification) -- TEST-054 (AC-028)
#
# Presented after the summary line above, mirroring the .sh twin and
# acceptance-tests.md's own structural separation of this row into its own
# "Deferred" section (round 2 ruling E). Not counted in PASS/FAIL above;
# does not affect this script's exit code.
# ---------------------------------------------------------------------------

function Test-054CiRegistered {
    if (-not (Test-Path -LiteralPath $ciDir)) { return $false }
    $hasSh = $false
    $hasPs1 = $false
    Get-ChildItem -LiteralPath $ciDir -File | Where-Object { $_.Extension -in ".yml", ".yaml" } | ForEach-Object {
        $wfText = Get-TextOrEmpty $_.FullName
        if ($wfText.Contains("design-sync-standing-consent.tests.sh")) { $hasSh = $true }
        if ($wfText.Contains("design-sync-standing-consent.tests.ps1")) { $hasPs1 = $true }
    }
    return $hasSh -and $hasPs1
}
if (Test-054CiRegistered) {
    Write-Host "PASS: TEST-054 this feature's suite is reachable from a CI entry point (AC-028, deferred)"
} else {
    Write-Host "FAIL: TEST-054 this feature's suite is reachable from a CI entry point (AC-028, deferred) -- DESIGNED RED: staged workflow patch not yet applied (REQ-010/AC-028)"
}

if ($Script:TestFail -gt 0) {
    exit 1
}
exit 0
