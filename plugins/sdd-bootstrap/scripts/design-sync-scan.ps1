# design-sync-scan.ps1 -- pre-upload egress-hygiene scanner for
# design-sync-loop (issue #139, DS-30, epic #136). PowerShell twin of
# design-sync-scan.sh (specs/design-sync-scan/tasks.md T-002, BL-008).
#
# Scope (REQ-005 / AC-018): this check is limited to egress hygiene --
# placeholder/stub-marker, secret-shaped, and PII-shaped string detection
# over HTML mockups about to leave the repository via claude.ai/design. It
# performs no assessment of mockup quality, design fidelity, accessibility,
# or design-system/ adherence -- those are design-system-contract's and
# human review's job, not this script's.
#
# Usage: design-sync-scan.ps1 <target-dir>
#   <target-dir>  required, the ONLY positional argument. Scanned
#                 recursively for *.html files; the extension match is
#                 case-insensitive (.html, .HTML, .Html are all scanned --
#                 PowerShell's Get-ChildItem -Filter matches case-
#                 insensitively by default on this runtime, so no extra
#                 logic is needed for that half of AC-039). A file with any
#                 other extension is outside the scan entirely -- no
#                 finding, no block, even if its content would match a
#                 secret or PII pattern. All three detection categories
#                 (placeholder, secret, PII) run in every invocation; no
#                 flag selects a subset.
#
# Exit codes (precedence: a tool-error condition always yields 2, decided
# before either detection outcome -- a scan that does not complete is
# never reported as 0 or 1, regardless of what it would have found):
#   0  the scan COMPLETED and found zero matches in any category --
#      caller may proceed to push.
#   1  the scan COMPLETED and found at least one match -- caller must not
#      push without an explicit, human-granted override recorded per
#      design-sync-loop/SKILL.md step 5; that override applies only to
#      THIS scan's disclosed findings.
#   2  the scan DID NOT COMPLETE (bad/missing/extra argument, a
#      nonexistent target directory, or an unreadable .html file under an
#      otherwise valid target) -- a tool-error outcome, not a detection
#      outcome. Blocking is unconditional here and there is no override
#      path: an override is a decision about disclosed findings, and a
#      scan that did not complete discloses none.
#
# This script presumes no interactive human at its own invocation -- it
# reads no stdin and prompts for nothing; its exit code plus its finding
# report are sufficient for a caller to gate on. It performs no runtime-
# or host-specific branching: the same command against the same input
# produces the same verdict whether the caller is Claude Code, Codex, or
# a bare terminal.
#
# S7 and P2 use the .NET regex forms design.md's dual-form block
# specifies (lookbehind/lookahead for P2's boundary, not the POSIX ERE
# consuming-character-class form design-sync-scan.sh uses for the same
# two patterns) -- see the Detection pattern catalogue section below.

param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Argument validation (AC-001, AC-007 branches 1-2, AC-008). Usage errors
# exit 2, never 1 -- a deliberate divergence from check-placeholders.ps1's
# own exit-1 usage convention (check-placeholders.ps1's Mandatory-parameter
# engine error): this script's two failure codes carry different caller-
# facing meanings ("here is what was found" vs "the tool did not run") and
# must not be collapsed into one. No override affordance is offered
# anywhere below. $Arguments is NOT declared Mandatory specifically so a
# zero-argument invocation reaches this explicit check instead of the
# PowerShell engine's own interactive-prompt-then-terminating-error path.
# ---------------------------------------------------------------------------
$argCount = if ($null -eq $Arguments) { 0 } else { $Arguments.Count }

if ($argCount -eq 0) {
    [Console]::Error.WriteLine("usage: design-sync-scan.ps1 <target-dir>")
    exit 2
}
if ($argCount -gt 1) {
    [Console]::Error.WriteLine("usage: design-sync-scan.ps1 <target-dir> (exactly one argument required, got $argCount)")
    exit 2
}

$targetDir = $Arguments[0]

if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
    [Console]::Error.WriteLine("design-sync-scan: target directory not found: $targetDir")
    exit 2
}

# ---------------------------------------------------------------------------
# Selection: *.html recursively, extension match case-insensitive (AC-002,
# AC-039). Anything else (a .json fixture, an image, stray notes) is
# outside the scan entirely -- no finding, no block, even with matching
# content.
# ---------------------------------------------------------------------------
$files = @(Get-ChildItem -LiteralPath $targetDir -Recurse -File -Filter '*.html' -ErrorAction SilentlyContinue | Sort-Object -Property FullName)

# Fail closed: every selected file must be readable before scanning begins
# (AC-007 branch 4) -- an unreadable file is a tool error, not silently
# skipped while the rest of the set is reported clean.
foreach ($f in $files) {
    try {
        [System.IO.File]::OpenRead($f.FullName).Close()
    } catch {
        [Console]::Error.WriteLine("design-sync-scan: cannot read file: $($f.FullName)")
        exit 2
    }
}

# ---------------------------------------------------------------------------
# Detection pattern catalogue (design.md's Detection pattern catalogue and
# S7/P2 dual-form block). Placeholder patterns are reused verbatim from
# check-placeholders.sh:18-19 (AC-009) -- identical to check-placeholders.
# ps1's own $patternCs/$patternCi, so the two never drift regardless of
# which runtime's twin a reader consults. The secret and PII sets are this
# feature's own (AC-010, AC-011). S7 and P2 use the .NET regex forms of
# design.md's dual-form block (AC-038); the .sh twin uses the POSIX ERE
# forms.
#
# Case-sensitivity sweep (AGENTS.md "Author-time sweeps" item 1), both
# layers, swept across this entire script: (a) operator-level -- no
# -match/-notmatch/-eq/-ne/-contains/-notcontains/-replace/-like/-notlike
# site in this file implements a pattern the .sh original compares
# case-sensitively (the domain-reserved switch below normalizes to
# lower-case via .ToLowerInvariant() *before* comparing, mirroring the .sh
# twin's own `tr '[:upper:]' '[:lower:]'` pre-normalization, so that site's
# own case-folding setting is a no-op by construction, not an oversight);
# (b) cmdlet-level -- the two Select-String -CaseSensitive calls below (the
# placeholder-cs group and the S1-S6 secret-prefix group, the two sites
# tasks.md's T-002 Done-When names) are this script's only sites matching a
# pattern the .sh original compares case-sensitively, and TEST-051 in the
# suite covers both with a mis-cased negative fixture per site. Every other
# Select-String call below is deliberately case-insensitive (placeholder-ci,
# S7, P1, P2), mirroring the .sh twin's own `grep -i`/no-`-i` choice per
# pattern, so none of those is a sweep site.
# ---------------------------------------------------------------------------

# Placeholder -- reused verbatim from check-placeholders.sh:18-19 /
# check-placeholders.ps1's own $patternCs/$patternCi. ALL-CAPS stub markers
# are case-sensitive (their lowercase occurrences are ordinary prose);
# multi-word phrases are case-insensitive (unambiguous in any casing).
# Case-sensitivity sweep (AGENTS.md item 1, operator+cmdlet layers): the
# placeholder-cs group below is matched via Select-String -CaseSensitive
# (cmdlet-level layer); TEST-051 in the suite proves a lower-cased mutation
# of each marker is rejected.
$placeholderPatternCs = 'TODO|FIXME|HACK\b|NotImplemented|PLACEHOLDER|TODO_REPLACE_WITH_PROJECT_COMMANDS'
$placeholderPatternCi = 'not[ _-]implemented|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)'

# Secret -- S1-S6 (case-sensitive fixed vendor-format prefixes; the format
# IS the casing) combined as one alternation, matched via Select-String
# -CaseSensitive (cmdlet-level case-sensitivity sweep site); S7
# (case-insensitive generic keyword-plus-assignment shape, .NET dual-form)
# is its own pattern, matched via plain (case-insensitive) Select-String.
$secretPatternCs = '-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}'
# Embedded double-quote uses a backtick escape (`") rather than string
# concatenation, for auditability -- the pattern is otherwise identical to
# the .sh twin's secret_pattern_s7, just with \s instead of [[:space:]]
# (design.md's dual-form block: .NET supports \s directly; POSIX ERE
# needs the bracket-expression form for portability across this
# repository's CI grep matrix, Edge Case 5).
$secretPatternS7 = "(api[_-]?key|secret|token|password)\s*[:=]\s*['`"][^'`"\s]{8,}['`"]"

# PII -- exactly two patterns. P1 (email-shaped) is matched here without
# the RFC 2606/6761 domain exclusion; the exclusion is applied afterward
# per matched address (below), since a bracket-expression regex cannot
# express "except these specific domains" directly. P2 (E.164-shaped
# phone, .NET dual-form: zero-width lookbehind/lookahead bound both sides
# so it cannot match a substring of a longer digit run) needs no such
# post-filter.
$piiPatternP1 = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
$piiPatternP2 = '(?<!\d)\+[1-9]\d{7,14}(?!\d)'

function Test-ReservedDomain {
    param([string]$Domain)
    $domainLc = $Domain.ToLowerInvariant()
    switch -Wildcard ($domainLc) {
        'example.com' { return $true }
        'example.net' { return $true }
        'example.org' { return $true }
        '*.test' { return $true }
        '*.example' { return $true }
        '*.invalid' { return $true }
        '*.localhost' { return $true }
        default { return $false }
    }
}

$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
    param([string]$Category, [string]$File, [int]$Line, [string]$Display)
    $findings.Add([pscustomobject]@{
        Category = $Category
        File     = $File
        Line     = $Line
        Display  = $Display
    }) | Out-Null
}

# One rule of the detection table: category, pattern, cmdlet-level
# case-sensitivity, display mode. Display modes mirror the .sh twin:
#   match         emit the matched text
#   redact        emit [REDACTED]
#   email-filter  drop RFC 2606/6761 reserved domains/TLDs per matched
#                 address, redact what is emitted
# Select-String -CaseSensitive remains the cmdlet-level case-sensitivity
# sweep site for the case-sensitive rows.
function Invoke-ScanRule {
    param([string]$Category, [string]$Path, [string]$Pattern,
          [bool]$CaseSensitive, [string]$Display)
    $hits = if ($CaseSensitive) {
        Select-String -LiteralPath $Path -Pattern $Pattern -CaseSensitive -AllMatches -ErrorAction SilentlyContinue
    } else {
        Select-String -LiteralPath $Path -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue
    }
    foreach ($m in $hits) {
        foreach ($mm in $m.Matches) {
            switch ($Display) {
                'match'  { Add-Finding $Category $Path $m.LineNumber $mm.Value }
                'redact' { Add-Finding $Category $Path $m.LineNumber '[REDACTED]' }
                'email-filter' {
                    $matchValue = $mm.Value
                    $atIndex = $matchValue.IndexOf('@')
                    $domain = $matchValue.Substring($atIndex + 1)
                    if (-not (Test-ReservedDomain $domain)) {
                        Add-Finding $Category $Path $m.LineNumber '[REDACTED]'
                    }
                }
            }
        }
    }
}

# The detection table: the six rules were previously six copy-pasted scan
# blocks; each row's semantics (pattern, case-sensitivity, display) are
# unchanged, and row order preserves the emitted finding order.
foreach ($f in $files) {
    $path = $f.FullName
    Invoke-ScanRule 'placeholder' $path $placeholderPatternCs $true  'match'
    Invoke-ScanRule 'placeholder' $path $placeholderPatternCi $false 'match'
    Invoke-ScanRule 'secret'      $path $secretPatternCs      $true  'redact'
    Invoke-ScanRule 'secret'      $path $secretPatternS7      $false 'redact'
    Invoke-ScanRule 'PII'         $path $piiPatternP1         $false 'email-filter'
    Invoke-ScanRule 'PII'         $path $piiPatternP2         $false 'redact'
}

# ---------------------------------------------------------------------------
# Exit-code decision and report (AC-005, AC-006, AC-012, AC-013, AC-014).
# ---------------------------------------------------------------------------
$count = $findings.Count

if ($count -eq 0) {
    Write-Host "Design-Sync Scan passed (0 findings)."
    exit 0
}

Write-Host "Design-Sync Scan FAILED ($count finding(s)):"
foreach ($finding in $findings) {
    $categoryPadded = $finding.Category.PadRight(11)
    Write-Host " - $categoryPadded $($finding.File):$($finding.Line): $($finding.Display)"
}
Write-Host "Findings must be reviewed. Continuing past a FAILED scan requires an"
Write-Host "explicit human override, recorded in Design-Source as"
Write-Host "Egress-Scan: overridden."
exit 1
