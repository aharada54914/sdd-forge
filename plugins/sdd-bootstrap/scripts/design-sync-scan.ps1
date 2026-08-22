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
