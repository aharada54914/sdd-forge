# design-sync-scan.tests.ps1 - PowerShell twin of design-sync-scan.tests.sh
# (issue #139, DS-30, epic #136; specs/design-sync-scan/tasks.md T-002,
# BL-008). Every TEST-ID in the .sh suite is ported here at parity, labelled
# by the same Test ID in its pass/fail message (tasks.md T-002 Done-When).
# This file additionally carries the categories that did not exist before a
# second runtime existed: cross-runtime exit-code/classification parity
# (TEST-049-051, TEST-070-079, TEST-086's cross-runtime half),
# representative-caller parity's .ps1 half (TEST-069), the case-sensitivity
# sweep (TEST-051), and the dual-form (POSIX ERE vs .NET) parity claim for
# S7/P2 (TEST-084).
#
# ASCII-only source throughout, per the precedent
# tests/design-system-contract.tests.ps1:57 states for this class of file:
# any single literal the .sh twin asserts that cannot be expressed in an
# ASCII-only .ps1 source would have its asymmetry stated as a comment at
# the point it is created. No such literal exists in this port -- every
# assertion below is expressible in ASCII, so no asymmetry comment appears.
#
# Case-sensitivity sweep (AGENTS.md "Author-time sweeps" item 1, applied at
# full strength per acceptance-tests.md's own Notes -- this is a genuine
# .sh -> .ps1 port of new regex-bearing detection logic, unlike
# design-sync-consent's narrowly-applicable sweep): every -match/-notmatch/
# Select-String site in design-sync-scan.ps1 that implements a pattern the
# .sh original compares case-sensitively is exercised here with a
# mis-cased negative fixture (TEST-051, below) at both the operator layer
# (-match/-notmatch defaults) and the cmdlet layer (Select-String
# -CaseSensitive). PowerShell's own -match/-notmatch/Select-String are
# case-INSENSITIVE by default unless -CaseSensitive (cmdlet) is given, so
# this suite's own assertions against the script's report text (which do
# not need to be case-sensitive) use plain -match throughout; only the
# script under test needs the sweep, and TEST-051 is that proof.
#
# Cross-runtime rows are environment-conditional (AGENTS.md item 5): they
# require both bash and pwsh on the host. Where bash is absent, each row
# SKIPs individually with a stated reason rather than silently vanishing.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SC = Join-Path $RepoRoot "plugins/sdd-bootstrap/scripts/design-sync-scan.ps1"
$ScSh = Join-Path $RepoRoot "plugins/sdd-bootstrap/scripts/design-sync-scan.sh"
$CheckPlaceholdersPs1 = Join-Path $RepoRoot "plugins/sdd-quality-loop/scripts/check-placeholders.ps1"
$RequirementsMd = Join-Path $RepoRoot "specs/design-sync-scan/requirements.md"
$AcceptanceTestsMd = Join-Path $RepoRoot "specs/design-sync-scan/acceptance-tests.md"

$script:PassCount = 0
$script:FailCount = 0
function Ok([string]$Name) { Write-Host "ok: $Name"; $script:PassCount++ }
function Fail([string]$Name) { Write-Host "FAIL: $Name"; $script:FailCount++ }

$Work = Join-Path ([System.IO.Path]::GetTempPath()) ("design-sync-scan-ps1-tests-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Work | Out-Null
$Work = (Resolve-Path -LiteralPath $Work).Path

$BashAvailable = [bool](Get-Command bash -ErrorAction SilentlyContinue)

Write-Host "=== design-sync-scan.tests.ps1: RepoRoot=$RepoRoot ==="
Write-Host "=== target script: $SC ==="
Write-Host "=== bash available for cross-runtime rows: $BashAvailable ==="

function New-WorkDir([string]$Name) {
    $d = Join-Path $Work $Name
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    return $d
}

# Writes an array of lines as a fixture file, one array element per line --
# used instead of a single multi-line string so every fixture's exact line
# numbers are explicit and auditable (several assertions below check a
# finding's reported line number).
function Set-Fixture([string]$Path, [string[]]$Lines) {
    Set-Content -LiteralPath $Path -Value $Lines -Encoding utf8
}

# Runs design-sync-scan.ps1 as a genuine child process, stdin closed
# (piping an empty collection into an external command closes its stdin
# immediately after zero bytes -- verified empirically to return in well
# under a second against a blocking `cat` with no arguments, the same
# no-hang guarantee AC-015/TEST-030 requires). Captures combined
# stdout+stderr and the real exit code via $LASTEXITCODE, mirroring
# tests/scripts.tests.ps1's Invoke-Gate / tests/check-placeholders-
# brownfield.tests.ps1's Invoke-CheckPlaceholders pattern. Every ordinary
# invocation in this suite goes through this function, not only TEST-030's
# dedicated row -- the same discipline the .sh twin's run_scan states.
function Invoke-Scan {
    param([string[]]$ScanArgs)
    $out = @() | & pwsh -NoProfile -ExecutionPolicy Bypass -File $SC @ScanArgs 2>&1
    $exit = $LASTEXITCODE
    $text = (@($out) | ForEach-Object { "$_" }) -join "`n"
    return [pscustomobject]@{ ExitCode = $exit; Output = $text }
}

# Same, against the .sh twin via bash -- used only by the cross-runtime
# rows below, all of which check $BashAvailable first.
function Invoke-ScanSh {
    param([string[]]$ScanArgs)
    $out = @() | & bash $ScSh @ScanArgs 2>&1
    $exit = $LASTEXITCODE
    $text = (@($out) | ForEach-Object { "$_" }) -join "`n"
    return [pscustomobject]@{ ExitCode = $exit; Output = $text }
}

# Runs design-sync-scan.ps1 with a caller-supplied set of the three
# representative-caller marker variables (TEST-069). The other two markers
# in the finite set are actively cleared first so a prior call's leftovers
# cannot leak into this one, and every marker's original value (from this
# suite's own process) is restored afterward regardless of outcome.
function Invoke-ScanEnv {
    param([hashtable]$EnvVars, [string[]]$ScanArgs)
    $markers = @('CLAUDE_CODE', 'ANTHROPIC', 'CODEX')
    $saved = @{}
    foreach ($k in $markers) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $null)
    }
    foreach ($k in $EnvVars.Keys) {
        [Environment]::SetEnvironmentVariable($k, $EnvVars[$k])
    }
    try {
        return Invoke-Scan -ScanArgs $ScanArgs
    } finally {
        foreach ($k in $markers) {
            [Environment]::SetEnvironmentVariable($k, $saved[$k])
        }
    }
}

try {

# ============================================================================
# REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-039) -- the script contract's
# basic shape and the HTML selection boundary
# ============================================================================

Write-Host ""
Write-Host "=== TEST-001 (AC-001): script exists, is directly invocable, requires an argument ==="
if (Test-Path -LiteralPath $SC -PathType Leaf) {
    Ok "TEST-001a: $SC exists"
} else {
    Fail "TEST-001a: $SC does not exist"
}

$t001Dir = New-WorkDir "t001-empty"
$r = Invoke-Scan -ScanArgs @($t001Dir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-001b: pwsh design-sync-scan.ps1 <dir> is directly invocable and completes (exit 0 on an empty dir)"
} else {
    Fail "TEST-001b: expected exit 0 for a valid empty target dir, got $($r.ExitCode). Output: $($r.Output)"
}

$r = Invoke-Scan -ScanArgs @()
if ($r.ExitCode -ne 0) {
    Ok "TEST-001c: zero-argument invocation does not succeed (a required first positional argument exists)"
} else {
    Fail "TEST-001c: zero-argument invocation must not succeed"
}

Write-Host ""
Write-Host "=== TEST-002 (AC-002): a finding nested >=2 directories deep is detected ==="
$t002Dir = New-WorkDir "t002"
$t002Nested = Join-Path $t002Dir "level1/level2"
New-Item -ItemType Directory -Path $t002Nested -Force | Out-Null
Set-Fixture (Join-Path $t002Nested "nested.html") @("<html>", "<body>", "<!-- TODO: fix this nested mockup -->", "</body>", "</html>")
$r = Invoke-Scan -ScanArgs @($t002Dir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-002a: a finding nested two directories deep yields exit 1"
} else {
    Fail "TEST-002a: expected exit 1, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match [regex]::Escape("level2/nested.html:3:")) {
    Ok "TEST-002b: the nested finding's file:line is reported"
} else {
    Fail "TEST-002b: nested finding file:line not reported. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-003 (AC-003): one invocation, no flag, flags findings from >1 category ==="
$t003Dir = New-WorkDir "t003"
Set-Fixture (Join-Path $t003Dir "mixed.html") @("<html><body>", "<!-- TODO: replace -->", "<p>AKIAABCDEFGHIJKLMNOP</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t003Dir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-003a: a two-category fixture, one plain invocation, exits 1"
} else {
    Fail "TEST-003a: expected exit 1, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'placeholder' -and $r.Output -match 'secret') {
    Ok "TEST-003b: both categories' findings appear in the one-invocation report -- no flag selected a subset"
} else {
    Fail "TEST-003b: expected both placeholder and secret findings in output. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-004 (AC-004): a target dir with zero .html files exits 0, is not an error ==="
$t004Dir = New-WorkDir "t004"
Set-Fixture (Join-Path $t004Dir "notes.txt") @("not html")
$r = Invoke-Scan -ScanArgs @($t004Dir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-004: a target dir with zero .html files exits 0"
} else {
    Fail "TEST-004: expected exit 0, got $($r.ExitCode). Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-085 (AC-039a): a non-.html file with secret/PII-shaped content is never scanned ==="
$t085Dir = New-WorkDir "t085"
Set-Fixture (Join-Path $t085Dir "clean.html") @("<html><body><p>clean mockup</p></body></html>")
Set-Fixture (Join-Path $t085Dir "data.json") @('{"key": "AKIAABCDEFGHIJKLMNOP", "email": "user@realcompany.com"}')
$r = Invoke-Scan -ScanArgs @($t085Dir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-085a: a .json fixture with secret/PII-shaped strings beside a clean .html produces no block (exit 0)"
} else {
    Fail "TEST-085a: expected exit 0 (non-.html excluded), got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -notmatch [regex]::Escape("data.json")) {
    Ok "TEST-085b: the .json fixture is never named in the report"
} else {
    Fail "TEST-085b: data.json must never appear in the report. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-086 (.ps1 half of AC-039b): an upper-cased .HTML file is scanned (case-insensitive extension) ==="
$t086Dir = New-WorkDir "t086"
Set-Fixture (Join-Path $t086Dir "MOCKUP.HTML") @("<html><body>", "<!-- TODO: uppercase extension mockup -->", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t086Dir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-086 (.ps1 half): an upper-cased .HTML file containing a finding is scanned and blocks (extension match is case-insensitive)"
} else {
    Fail "TEST-086 (.ps1 half): expected exit 1 for a finding inside an upper-cased .HTML file, got $($r.ExitCode). Output: $($r.Output)"
}

# ============================================================================
# REQ-002 (AC-005, AC-006, AC-007, AC-008, AC-037's script-level half) --
# the three-valued, fail-closed exit-code contract
# ============================================================================

Write-Host ""
Write-Host "=== TEST-005 (AC-005): a fully clean fixture set exits 0 ==="
$t005Dir = New-WorkDir "t005"
$t005Sub = Join-Path $t005Dir "sub"
New-Item -ItemType Directory -Path $t005Sub -Force | Out-Null
Set-Fixture (Join-Path $t005Dir "a.html") @("<html><body><p>Welcome to our product.</p></body></html>")
Set-Fixture (Join-Path $t005Sub "b.html") @("<html><body><p>Nothing to see here.</p></body></html>")
$r = Invoke-Scan -ScanArgs @($t005Dir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-005a: a fully clean multi-file fixture set exits 0"
} else {
    Fail "TEST-005a: expected exit 0, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'passed') {
    Ok "TEST-005b: a clean run reports passed"
} else {
    Fail "TEST-005b: clean run should report passed. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-006 (AC-006.1): a placeholder-only fixture exits 1 ==="
$t006Dir = New-WorkDir "t006"
Set-Fixture (Join-Path $t006Dir "ph.html") @("<html><body>", "<!-- TODO: placeholder only -->", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t006Dir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-006a: a placeholder-only fixture exits 1"
} else {
    Fail "TEST-006a: expected exit 1, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'placeholder' -and $r.Output -notmatch 'secret|PII') {
    Ok "TEST-006b: only the placeholder category is reported"
} else {
    Fail "TEST-006b: expected only placeholder category. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-007 (AC-006.2): a secret-only fixture exits 1 ==="
$t007Dir = New-WorkDir "t007"
Set-Fixture (Join-Path $t007Dir "sec.html") @("<html><body>", "<p>AKIAABCDEFGHIJKLMNOP</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t007Dir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-007a: a secret-only fixture exits 1"
} else {
    Fail "TEST-007a: expected exit 1, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'secret' -and $r.Output -notmatch 'placeholder|PII') {
    Ok "TEST-007b: only the secret category is reported"
} else {
    Fail "TEST-007b: expected only secret category. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-008 (AC-006.3): a PII-only fixture exits 1 ==="
$t008Dir = New-WorkDir "t008"
Set-Fixture (Join-Path $t008Dir "pii.html") @("<html><body>", "<p>Contact: user@realcompany.com</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t008Dir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-008a: a PII-only fixture exits 1"
} else {
    Fail "TEST-008a: expected exit 1, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'PII' -and $r.Output -notmatch 'placeholder|secret') {
    Ok "TEST-008b: only the PII category is reported"
} else {
    Fail "TEST-008b: expected only PII category. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-009 (AC-006.4): a mixed-category fixture exits 1, names every category present ==="
$t009Dir = New-WorkDir "t009"
Set-Fixture (Join-Path $t009Dir "mixed.html") @("<html><body>", "<!-- TODO: mixed fixture -->", "<p>API Key: AKIAABCDEFGHIJKLMNOP</p>", "<p>Contact: user@realcompany.com</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t009Dir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-009a: a mixed-category fixture exits 1"
} else {
    Fail "TEST-009a: expected exit 1, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'placeholder' -and $r.Output -match 'secret' -and $r.Output -match 'PII') {
    Ok "TEST-009b: the report names every category present, not only the first matched"
} else {
    Fail "TEST-009b: expected all three categories named. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-010 (AC-007.1, AC-008): zero arguments exits 2 with a usage diagnostic, never 1 ==="
$r = Invoke-Scan -ScanArgs @()
if ($r.ExitCode -eq 2) {
    Ok "TEST-010a: zero arguments exits 2"
} else {
    Fail "TEST-010a: expected exit 2, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'usage') {
    Ok "TEST-010b: zero-argument invocation prints a usage diagnostic"
} else {
    Fail "TEST-010b: expected a usage diagnostic. Output: $($r.Output)"
}
if ($r.Output -notmatch 'override') {
    Ok "TEST-010c: no override affordance is offered in the exit-2 output (AC-007's fourth clause)"
} else {
    Fail "TEST-010c: exit-2 output must not mention an override affordance. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-056 (AC-007.2): more arguments than the contract defines exits 2 with a usage diagnostic ==="
$t056Dir = New-WorkDir "t056"
$r = Invoke-Scan -ScanArgs @($t056Dir, "extra-argument")
if ($r.ExitCode -eq 2) {
    Ok "TEST-056a: two positional arguments (one too many) exits 2"
} else {
    Fail "TEST-056a: expected exit 2, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match 'usage') {
    Ok "TEST-056b: too-many-arguments invocation prints a usage diagnostic"
} else {
    Fail "TEST-056b: expected a usage diagnostic. Output: $($r.Output)"
}
if ($r.Output -notmatch 'override') {
    Ok "TEST-056c: no override affordance is offered in the too-many-arguments exit-2 output"
} else {
    Fail "TEST-056c: exit-2 output must not mention an override affordance. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-011 (AC-007.3): a nonexistent target directory exits 2, names the missing path ==="
$t011Missing = Join-Path $Work "t011-does-not-exist"
$r = Invoke-Scan -ScanArgs @($t011Missing)
if ($r.ExitCode -eq 2) {
    Ok "TEST-011a: a nonexistent target directory exits 2"
} else {
    Fail "TEST-011a: expected exit 2, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match [regex]::Escape($t011Missing)) {
    Ok "TEST-011b: the diagnostic names the missing path"
} else {
    Fail "TEST-011b: expected the missing path named. Output: $($r.Output)"
}
if ($r.Output -notmatch 'override') {
    Ok "TEST-011c: no override affordance is offered for a nonexistent target directory"
} else {
    Fail "TEST-011c: exit-2 output must not mention an override affordance. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-012 (AC-007.4): an unreadable .html file exits 2, names the file, rest not silently clean ==="
$t012Dir = New-WorkDir "t012"
Set-Fixture (Join-Path $t012Dir "clean.html") @("<html><body><p>clean sibling</p></body></html>")
$t012Blocked = Join-Path $t012Dir "blocked.html"
Set-Fixture $t012Blocked @("<html><body><p>secret content, unreadable</p></body></html>")
& chmod 000 $t012Blocked
$r = Invoke-Scan -ScanArgs @($t012Dir)
if ($r.ExitCode -eq 2) {
    Ok "TEST-012a: an unreadable .html file exits 2"
} else {
    Fail "TEST-012a: expected exit 2, got $($r.ExitCode). Output: $($r.Output)"
}
if ($r.Output -match [regex]::Escape("blocked.html")) {
    Ok "TEST-012b: the diagnostic names the unreadable file"
} else {
    Fail "TEST-012b: expected the unreadable file named. Output: $($r.Output)"
}
if ($r.Output -notmatch 'passed') {
    Ok "TEST-012c: the rest of the set is not silently reported clean/passed"
} else {
    Fail "TEST-012c: must not report a false 'passed' when a file is unreadable. Output: $($r.Output)"
}
& chmod 644 $t012Blocked

Write-Host ""
Write-Host "=== TEST-013 (AC-008): usage-error exit code is 2, never 1 -- contrast with check-placeholders.ps1 ==="
$cpOut = @() | & pwsh -NoProfile -ExecutionPolicy Bypass -File $CheckPlaceholdersPs1 2>&1
$cpExit = $LASTEXITCODE
if ($cpExit -eq 1) {
    Ok "TEST-013a: check-placeholders.ps1's own zero-argument usage error exits 1 (the convention this script deliberately diverges from)"
} else {
    Fail "TEST-013a: expected check-placeholders.ps1 zero-arg exit 1, got $cpExit. Output: $cpOut"
}
$r = Invoke-Scan -ScanArgs @()
if ($r.ExitCode -eq 2 -and $r.ExitCode -ne 1) {
    Ok "TEST-013b: design-sync-scan.ps1's own zero-argument usage error exits 2, never 1"
} else {
    Fail "TEST-013b: expected exit 2 (never 1), got $($r.ExitCode). Output: $($r.Output)"
}

# ============================================================================
# REQ-003 (AC-009, AC-010, AC-011, AC-012, AC-038's .NET half) -- the three
# detection categories' pattern catalogue
# ============================================================================

Write-Host ""
Write-Host "=== TEST-014 (AC-009): placeholder detection reproduces check-placeholders.ps1's own verdicts ==="
$cpContent = Get-Content -Raw -LiteralPath $CheckPlaceholdersPs1
$cpCsMatch = [regex]::Match($cpContent, "(?m)^\`$patternCs\s*=\s*'([^']*)'")
$cpCiMatch = [regex]::Match($cpContent, "(?m)^\`$patternCi\s*=\s*'([^']*)'")
if ($cpCsMatch.Success -and $cpCiMatch.Success) {
    Ok "TEST-014-setup: re-read check-placeholders.ps1's live `$patternCs/`$patternCi at test-run time (not transcribed)"
} else {
    Fail "TEST-014-setup: could not extract `$patternCs/`$patternCi from $CheckPlaceholdersPs1"
}
$t014PosTxt = Join-Path $Work "t014-pos.txt"
Set-Fixture $t014PosTxt @("TODO one", "FIXME two", "HACK three", "raise NotImplemented", "PLACEHOLDER five", "TODO_REPLACE_WITH_PROJECT_COMMANDS", "not implemented seven", "lorem ipsum eight", "coming soon nine", "do not ship ten", "temporary stub eleven", "dummy data twelve")
$cpPosOut = @() | & pwsh -NoProfile -ExecutionPolicy Bypass -File $CheckPlaceholdersPs1 $t014PosTxt 2>&1
$cpPosExit = $LASTEXITCODE
if ($cpPosExit -eq 1) {
    Ok "TEST-014a: check-placeholders.ps1 flags the positive marker corpus (exit 1)"
} else {
    Fail "TEST-014a: expected check-placeholders.ps1 exit 1 on the positive corpus, got $cpPosExit"
}
$t014PosDir = New-WorkDir "t014-pos-dir"
Copy-Item -LiteralPath $t014PosTxt -Destination (Join-Path $t014PosDir "markers.html")
$r = Invoke-Scan -ScanArgs @($t014PosDir)
if ($r.ExitCode -eq 1 -and $r.Output -match 'placeholder') {
    Ok "TEST-014b: design-sync-scan.ps1 flags the identical corpus as a placeholder finding -- same verdict as check-placeholders.ps1"
} else {
    Fail "TEST-014b: expected exit 1 with a placeholder finding, got $($r.ExitCode). Output: $($r.Output)"
}
$t014NegTxt = Join-Path $Work "t014-neg.txt"
Set-Fixture $t014NegTxt @("nothing to see here, ordinary prose about a todo list app")
$null = @() | & pwsh -NoProfile -ExecutionPolicy Bypass -File $CheckPlaceholdersPs1 $t014NegTxt 2>&1
$cpNegExit = $LASTEXITCODE
$t014NegDir = New-WorkDir "t014-neg-dir"
Copy-Item -LiteralPath $t014NegTxt -Destination (Join-Path $t014NegDir "clean.html")
$r = Invoke-Scan -ScanArgs @($t014NegDir)
if ($cpNegExit -eq 0 -and $r.ExitCode -eq 0) {
    Ok "TEST-014c: both scripts agree the negative corpus (lowercase 'todo' as ordinary prose) is clean"
} else {
    Fail "TEST-014c: expected both exit 0, got check-placeholders=$cpNegExit design-sync-scan=$($r.ExitCode). Output: $($r.Output)"
}

# QG cycle-1 remediation (scan T-001 Major-1): TEST-014a-c above prove the
# two scripts agree on VERDICTS for two fixed corpora, but a verdict match
# does not prove the PATTERNS themselves are byte-identical -- two
# independently-drifted regexes can still happen to agree on these
# particular fixtures. TEST-014d closes that gap by comparing the literal
# pattern text design-sync-scan.ps1's own placeholderPatternCs/
# placeholderPatternCi transcribed from check-placeholders.ps1's own
# patternCs/patternCi against the live source, at test-run time.
$scContent = Get-Content -Raw -LiteralPath $SC
$scCsMatch = [regex]::Match($scContent, "(?m)^\`$placeholderPatternCs\s*=\s*'([^']*)'")
$scCiMatch = [regex]::Match($scContent, "(?m)^\`$placeholderPatternCi\s*=\s*'([^']*)'")
if ($scCsMatch.Success -and $scCiMatch.Success) {
    Ok "TEST-014d-setup: re-read design-sync-scan.ps1's live `$placeholderPatternCs/`$placeholderPatternCi at test-run time (not transcribed)"
} else {
    Fail "TEST-014d-setup: could not extract `$placeholderPatternCs/`$placeholderPatternCi from $SC"
}
if ($scCsMatch.Groups[1].Value -eq $cpCsMatch.Groups[1].Value -and $scCiMatch.Groups[1].Value -eq $cpCiMatch.Groups[1].Value) {
    Ok "TEST-014d: design-sync-scan.ps1's placeholder patterns are byte-identical to check-placeholders.ps1's -- verbatim transcription, not independent authorship (AC-009)"
} else {
    Fail "TEST-014d: design-sync-scan.ps1's placeholder patterns have drifted from check-placeholders.ps1's -- cs '$($scCsMatch.Groups[1].Value)' vs '$($cpCsMatch.Groups[1].Value)', ci '$($scCiMatch.Groups[1].Value)' vs '$($cpCiMatch.Groups[1].Value)'"
}

Write-Host ""
Write-Host "=== TEST-015 - TEST-020, TEST-083 (AC-010): one row per secret pattern S1-S6, plus S5's sk-proj- sub-format ==="
function Assert-SecretHit {
    param([string]$Label, [string]$Content)
    $safeName = ($Label -replace '[^A-Za-z0-9]', '_')
    $d = New-WorkDir "secret-$safeName"
    Set-Fixture (Join-Path $d "s.html") @("<html><body>", $Content, "</body></html>")
    $r = Invoke-Scan -ScanArgs @($d)
    if ($r.ExitCode -eq 1 -and $r.Output -match 'secret') {
        Ok "${Label}: triggers a secret finding"
    } else {
        Fail "${Label}: expected a secret finding (exit 1), got $($r.ExitCode). Output: $($r.Output)"
    }
}
Assert-SecretHit "TEST-015 (S1 PEM private-key header)" "-----BEGIN RSA PRIVATE KEY-----"
Assert-SecretHit "TEST-016 (S2 AKIA...)" "AKIAABCDEFGHIJKLMNOP"
Assert-SecretHit "TEST-017 (S3 ghp_...)" ("ghp_" + ("a" * 36))
Assert-SecretHit "TEST-018 (S4 github_pat_...)" ("github_pat_" + ("a" * 22))
Assert-SecretHit "TEST-019 (S5 bare sk-...)" ("sk-" + ("a" * 20))
Assert-SecretHit "TEST-020 (S6 xoxb-...)" "xoxb-1234567890-abcdefghij"
Assert-SecretHit "TEST-083 (S5 sk-proj- sub-format)" ("sk-proj-" + ("a" * 20))

Write-Host ""
Write-Host "=== TEST-021 (AC-010): S7 triggers on a substantive quoted value, not on a bare or empty value ==="
$t021Dir = New-WorkDir "t021"
Set-Fixture (Join-Path $t021Dir "pos.html") @("<html><body>", '<p>password: "hunter2hunter2"</p>', "</body></html>")
$r = Invoke-Scan -ScanArgs @($t021Dir)
if ($r.ExitCode -eq 1 -and $r.Output -match 'secret') {
    Ok "TEST-021a: S7 triggers on a keyword followed by a substantive quoted value"
} else {
    Fail "TEST-021a: expected a secret finding, got $($r.ExitCode). Output: $($r.Output)"
}
$t021NegDir = New-WorkDir "t021-neg"
Set-Fixture (Join-Path $t021NegDir "neg.html") @("<html><body>", "<p>password:</p>", "<label>Password</label>", '<input type="password">', '<p>password: ""</p>', "</body></html>")
$r = Invoke-Scan -ScanArgs @($t021NegDir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-021b: S7 does NOT trigger on a bare keyword, a form-field label, an input type attribute, or an empty quoted value"
} else {
    Fail "TEST-021b: expected exit 0 (no S7 false positive), got $($r.ExitCode). Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-022 (AC-011): P1 (email, non-reserved domain) triggers a PII finding ==="
$t022Dir = New-WorkDir "t022"
Set-Fixture (Join-Path $t022Dir "e.html") @("<html><body>", "<p>Contact: user@realcompany.com</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t022Dir)
if ($r.ExitCode -eq 1 -and $r.Output -match 'PII') {
    Ok "TEST-022: a non-reserved-domain email triggers a PII finding"
} else {
    Fail "TEST-022: expected a PII finding, got $($r.ExitCode). Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-087 (AC-011, QG cycle-1 remediation scan T-001 Major-2): P1 (.edu email) triggers a PII finding -- .edu is not one of the seven RFC 2606/6761 reserved domains/TLDs design.md's pattern catalogue names ==="
$t087Dir = New-WorkDir "t087"
Set-Fixture (Join-Path $t087Dir "e.html") @("<html><body>", "<p>Contact: prof@university.edu</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t087Dir)
if ($r.ExitCode -eq 1 -and $r.Output -match 'PII') {
    Ok "TEST-087: a .edu-domain email triggers a PII finding -- .edu is deliberately absent from the reserved-domain exclusion list and must not be silently added to it"
} else {
    Fail "TEST-087: expected a PII finding for a .edu address, got $($r.ExitCode). Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-023 (AC-011): P2 (E.164-shaped phone) triggers a PII finding ==="
$t023Dir = New-WorkDir "t023"
Set-Fixture (Join-Path $t023Dir "p.html") @("<html><body>", "<p>Call us: +12345678901</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t023Dir)
if ($r.ExitCode -eq 1 -and $r.Output -match 'PII') {
    Ok "TEST-023: an E.164-shaped phone number triggers a PII finding"
} else {
    Fail "TEST-023: expected a PII finding, got $($r.ExitCode). Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-024, TEST-057 - TEST-062 (AC-011): the seven RFC 2606/6761 reserved domains/TLDs do not trigger ==="
function Assert-ReservedDomainClean {
    param([string]$Label, [string]$EmailAddress)
    $safeName = ($Label -replace '[^A-Za-z0-9]', '_')
    $d = New-WorkDir "reserved-$safeName"
    Set-Fixture (Join-Path $d "e.html") @("<html><body>", "<p>Contact: $EmailAddress</p>", "</body></html>")
    $r = Invoke-Scan -ScanArgs @($d)
    if ($r.ExitCode -eq 0) {
        Ok "${Label}: $EmailAddress does not trigger a finding"
    } else {
        Fail "${Label}: $EmailAddress must not trigger, got exit $($r.ExitCode). Output: $($r.Output)"
    }
}
Assert-ReservedDomainClean "TEST-024 (example.com)" "user@example.com"
Assert-ReservedDomainClean "TEST-057 (example.net)" "user@example.net"
Assert-ReservedDomainClean "TEST-058 (example.org)" "user@example.org"
Assert-ReservedDomainClean "TEST-059 (.test)" "user@mockups.test"
Assert-ReservedDomainClean "TEST-060 (.example)" "user@mockups.example"
Assert-ReservedDomainClean "TEST-061 (.invalid)" "user@mockups.invalid"
Assert-ReservedDomainClean "TEST-062 (.localhost)" "user@mockups.localhost"

Write-Host ""
Write-Host "=== TEST-080 - TEST-082 (AC-011): P2's three negative boundary shapes ==="
$t080Dir = New-WorkDir "t080"
Set-Fixture (Join-Path $t080Dir "short.html") @("<html><body>", "<p>Ref: +1234567</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t080Dir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-080: a 7-digit run (one short of the minimum) does not trigger"
} else {
    Fail "TEST-080: expected exit 0, got $($r.ExitCode). Output: $($r.Output)"
}

$t081Dir = New-WorkDir "t081"
Set-Fixture (Join-Path $t081Dir "long.html") @("<html><body>", "<p>Ref: +1234567890123456</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t081Dir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-081: a 16-digit run (one over the maximum) does not trigger -- the boundary rejects an embedded valid-length substring, not only the total count"
} else {
    Fail "TEST-081: expected exit 0, got $($r.ExitCode). Output: $($r.Output)"
}

# TEST-082 exercises the LEADING side of the .NET (?<!\d)...(?!\d) boundary,
# complementing TEST-081's trailing/quantifier-adjacent case: a digit
# sitting immediately before the required "+" defeats the match even
# though the digits after "+" are, on their own, a valid 8-15 digit run
# (design.md's dual-form block; Edge Case 8's "one more digit... on either
# side").
$t082Dir = New-WorkDir "t082"
Set-Fixture (Join-Path $t082Dir "adjacent.html") @("<html><body>", "<p>ID9+123456789 tracking number</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t082Dir)
if ($r.ExitCode -eq 0) {
    Ok "TEST-082: a valid-length run with a digit immediately adjacent on the leading side (before '+') does not trigger"
} else {
    Fail "TEST-082: expected exit 0, got $($r.ExitCode). Output: $($r.Output)"
}
# Sanity control: the same digits WOULD trigger without the leading-adjacent digit.
$t082CtrlDir = New-WorkDir "t082-ctrl"
Set-Fixture (Join-Path $t082CtrlDir "control.html") @("<html><body>", "<p>ID +123456789 tracking number</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t082CtrlDir)
if ($r.ExitCode -eq 1) {
    Ok "TEST-082-control: without the leading-adjacent digit, the same-length run DOES trigger (proves TEST-082 exercises the boundary, not the quantifier)"
} else {
    Fail "TEST-082-control: expected exit 1 (positive control), got $($r.ExitCode). Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-025 (AC-012): a mixed-category fixture's report labels every finding with its correct category ==="
$t025Dir = New-WorkDir "t025"
Set-Fixture (Join-Path $t025Dir "mixed.html") @("<html>", "<body>", "<!-- TODO: mixed -->", "<p>AKIAABCDEFGHIJKLMNOP</p>", "<p>user@realcompany.com</p>", "</body>", "</html>")
$r = Invoke-Scan -ScanArgs @($t025Dir)
if ($r.Output -match 'placeholder\s+.*mixed\.html:3:' -and $r.Output -match 'secret\s+.*mixed\.html:4:' -and $r.Output -match 'PII\s+.*mixed\.html:5:') {
    Ok "TEST-025: every finding in the mixed fixture is labelled with its correct category at its correct line"
} else {
    Fail "TEST-025: expected placeholder@3, secret@4, PII@5, correctly labelled. Output: $($r.Output)"
}

# ============================================================================
# REQ-004 (AC-013, AC-014, AC-015) -- actionable reports that are not
# themselves a new disclosure surface
# ============================================================================

Write-Host ""
Write-Host "=== TEST-026 (AC-013): a multi-file fixture's report gives correct, distinct file:line per finding ==="
$t026Dir = New-WorkDir "t026"
$t026A = Join-Path $t026Dir "a"
$t026B = Join-Path $t026Dir "b"
$t026C = Join-Path $t026Dir "c"
New-Item -ItemType Directory -Path $t026A -Force | Out-Null
New-Item -ItemType Directory -Path $t026B -Force | Out-Null
New-Item -ItemType Directory -Path $t026C -Force | Out-Null
Set-Fixture (Join-Path $t026A "one.html") @("<html>", "<body>", "<!-- TODO: file one -->", "</body>", "</html>")
Set-Fixture (Join-Path $t026B "two.html") @("<html>", "<body>", "<p>x</p>", "<p>AKIAABCDEFGHIJKLMNOP</p>", "</body>", "</html>")
Set-Fixture (Join-Path $t026C "three.html") @("<html>", "<body>", "<p>a</p>", "<p>b</p>", "<p>user@realcompany.com</p>", "</body>", "</html>")
$r = Invoke-Scan -ScanArgs @($t026Dir)
if ($r.ExitCode -eq 1 -and $r.Output -match [regex]::Escape("a/one.html:3:") -and $r.Output -match [regex]::Escape("b/two.html:4:") -and $r.Output -match [regex]::Escape("c/three.html:5:")) {
    Ok "TEST-026: each of three files' findings is reported at its own correct, distinct file:line"
} else {
    Fail "TEST-026: expected a/one.html:3, b/two.html:4, c/three.html:5, got exit $($r.ExitCode). Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-027, TEST-028, TEST-029, TEST-063 (AC-014): masking is category-differentiated ==="
$t027Dir = New-WorkDir "t027"
Set-Fixture (Join-Path $t027Dir "s.html") @("<html><body>", "<p>AKIAABCDEFGHIJKLMNOP</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t027Dir)
if ($r.Output -notmatch [regex]::Escape("AKIAABCDEFGHIJKLMNOP")) {
    Ok "TEST-027: a secret finding's report line does not contain the matched secret value"
} else {
    Fail "TEST-027: the matched secret value must not appear in the report. Output: $($r.Output)"
}
if ($r.Output -match [regex]::Escape("REDACTED")) {
    Ok "TEST-027b: the secret finding is masked with the fixed token"
} else {
    Fail "TEST-027b: expected [REDACTED] in the report. Output: $($r.Output)"
}

$t028Dir = New-WorkDir "t028"
Set-Fixture (Join-Path $t028Dir "e.html") @("<html><body>", "<p>Contact: user@realcompany.com</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t028Dir)
if ($r.Output -notmatch [regex]::Escape("user@realcompany.com")) {
    Ok "TEST-028: a PII/email finding's report line does not contain the matched address"
} else {
    Fail "TEST-028: the matched email address must not appear in the report. Output: $($r.Output)"
}

$t063Dir = New-WorkDir "t063"
Set-Fixture (Join-Path $t063Dir "p.html") @("<html><body>", "<p>Call: +19876543210</p>", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t063Dir)
if ($r.Output -notmatch [regex]::Escape("+19876543210")) {
    Ok "TEST-063: a PII/phone finding's report line does not contain the matched number"
} else {
    Fail "TEST-063: the matched phone number must not appear in the report. Output: $($r.Output)"
}

$t029Dir = New-WorkDir "t029"
Set-Fixture (Join-Path $t029Dir "ph.html") @("<html><body>", "<!-- TODO: keep this marker visible -->", "</body></html>")
$r = Invoke-Scan -ScanArgs @($t029Dir)
if ($r.Output -match [regex]::Escape("TODO")) {
    Ok "TEST-029: a placeholder finding's report line contains the matched marker text in full"
} else {
    Fail "TEST-029: expected the literal marker TODO in the report. Output: $($r.Output)"
}

Write-Host ""
Write-Host "=== TEST-030 (AC-015): the script completes with stdin closed, no interactive read, no hang ==="
$t030Dir = New-WorkDir "t030"
Set-Fixture (Join-Path $t030Dir "c.html") @("<html><body><p>clean</p></body></html>")
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$r = Invoke-Scan -ScanArgs @($t030Dir)
$sw.Stop()
if ($sw.ElapsedMilliseconds -lt 5000) {
    Ok "TEST-030: the scan completed within 5s with stdin closed (exit $($r.ExitCode)) -- no interactive read, no prompt, no hang"
} else {
    Fail "TEST-030: the scan did not complete within 5s with stdin closed -- possible hang/interactive read"
}

# ============================================================================
# REQ-005 (AC-018's .ps1-script half) -- the script's own header states the
# egress-hygiene-only boundary
# ============================================================================

Write-Host ""
Write-Host "=== TEST-034 (.ps1 half of AC-018): the script's header comment states the egress-hygiene-only scope ==="
if (Test-Path -LiteralPath $SC -PathType Leaf) {
    $headerRaw = Get-Content -LiteralPath $SC -TotalCount 55
    $headerCommentLines = @($headerRaw | Where-Object { $_ -match '^\s*#' } | ForEach-Object { $_ -replace '^\s*#\s?', '' })
    $t034Flat = (($headerCommentLines -join ' ') -replace '\s+', ' ')
} else {
    $t034Flat = ""
}
if ($t034Flat -match 'egress hygiene') {
    Ok "TEST-034a: the header states the check is limited to egress hygiene"
} else {
    Fail "TEST-034a: header must state 'egress hygiene'. Header: $t034Flat"
}
if ($t034Flat -match 'no assessment of mockup quality' -and $t034Flat -match 'design fidelity' -and $t034Flat -match 'accessibility' -and $t034Flat -match 'design-system') {
    Ok "TEST-034b: the header states no assessment of mockup quality, design fidelity, accessibility, or design-system/ adherence"
} else {
    Fail "TEST-034b: header must disclaim quality/fidelity/accessibility/design-system judgment. Header: $t034Flat"
}

# ============================================================================
# REQ-008 (.ps1 half of AC-030) -- runtime neutrality
# ============================================================================

Write-Host ""
Write-Host "=== TEST-048 (.ps1 half of AC-030): no finite-set host/tool identifier appears as a branch condition ==="
$forbiddenIdentifierPattern = 'CLAUDE_CODE|CODEX|DesignSync|ANTHROPIC|OPENAI'
if (Test-Path -LiteralPath $SC -PathType Leaf) {
    $scLines = Get-Content -LiteralPath $SC
    $t048Bad = $false
    $t048BadLines = @()
    foreach ($line in $scLines) {
        if ($line -notmatch $forbiddenIdentifierPattern) { continue }
        if ($line.TrimStart().StartsWith('#')) { continue }
        $t048Bad = $true
        $t048BadLines += $line
    }
    if (-not $t048Bad) {
        Ok "TEST-048: none of the finite identifier set (CLAUDE_CODE, CODEX, DesignSync, ANTHROPIC, OPENAI) appears as a branch condition outside a comment"
    } else {
        Fail "TEST-048: forbidden identifier found outside a comment: $($t048BadLines -join '; ')"
    }
} else {
    Fail "TEST-048: $SC does not exist -- cannot inspect its source for forbidden identifiers"
}

Write-Host ""
Write-Host "=== TEST-069 (.ps1 half of AC-030): representative-caller parity -- Claude-Code-style vs bare-terminal/Codex-style env ==="
$t069Dir = New-WorkDir "t069"
Set-Fixture (Join-Path $t069Dir "mixed.html") @("<html><body>", "<!-- TODO: caller parity fixture -->", "<p>AKIAABCDEFGHIJKLMNOP</p>", "</body></html>")
$rA = Invoke-ScanEnv -EnvVars @{ CLAUDE_CODE = '1'; ANTHROPIC = '1' } -ScanArgs @($t069Dir)
$rB = Invoke-ScanEnv -EnvVars @{ CODEX = '1' } -ScanArgs @($t069Dir)
if ($rA.ExitCode -eq $rB.ExitCode -and $rA.Output -eq $rB.Output) {
    Ok "TEST-069: the same fixture, invoked once under a Claude-Code-style env and once under a bare-terminal/Codex-style env, is exit-code- and report-identical"
} else {
    Fail "TEST-069: caller environments diverged. A(exit=$($rA.ExitCode)): $($rA.Output) | B(exit=$($rB.ExitCode)): $($rB.Output)"
}

# ============================================================================
# REQ-010 (AC-034, this task's ported contribution) -- traceability manifest
# ============================================================================

Write-Host ""
Write-Host "=== TEST-052 (AC-034): traceability manifest -- every REQ-001..REQ-009 AC-NNN heading appears in acceptance-tests.md's AC column ==="
$reqLines = Get-Content -LiteralPath $RequirementsMd
$currentReq = ""
$acList = New-Object System.Collections.Generic.List[string]
foreach ($line in $reqLines) {
    if ($line -match '^### (REQ-[0-9]+)') {
        $currentReq = $Matches[1]
        continue
    }
    if ($line -match '^#### (AC-[0-9]+)') {
        $ac = $Matches[1]
        if ($currentReq -ne "" -and $currentReq -ne "REQ-010") {
            $acList.Add($ac) | Out-Null
        }
    }
}
$acListUnique = @($acList | Sort-Object -Unique)
if ($acListUnique.Count -gt 0) {
    Ok "TEST-052-setup: extracted $($acListUnique.Count) AC headings from requirements.md's REQ-001..REQ-009 sections"
} else {
    Fail "TEST-052-setup: extracted zero AC headings from $RequirementsMd -- the manifest check itself is broken"
}
$atContent = Get-Content -Raw -LiteralPath $AcceptanceTestsMd
$t052Missing = @()
foreach ($ac in $acListUnique) {
    if ($atContent -notmatch [regex]::Escape($ac)) {
        $t052Missing += $ac
    }
}
if ($t052Missing.Count -eq 0) {
    Ok "TEST-052: every REQ-001..REQ-009 AC-NNN heading in requirements.md appears at least once in acceptance-tests.md"
} else {
    Fail "TEST-052: AC(s) missing from acceptance-tests.md's AC column: $($t052Missing -join ' ')"
}

Write-Host ""
Write-Host "=== TEST-053 (AC-035, QG cycle-1 remediation scan T-005 Major): both tests/run-all.sh and tests/run-all.ps1 list the new suite ==="
$runAllShPath053 = Join-Path $RepoRoot "tests/run-all.sh"
$runAllPs1Path053 = Join-Path $RepoRoot "tests/run-all.ps1"
$runAllShText053 = Get-Content -Raw -LiteralPath $runAllShPath053
$runAllPs1Text053 = Get-Content -Raw -LiteralPath $runAllPs1Path053
if ($runAllShText053.Contains("tests/design-sync-scan.tests.sh") -and $runAllPs1Text053.Contains("tests/design-sync-scan.tests.ps1")) {
    Ok "TEST-053: both tests/run-all.sh and tests/run-all.ps1 list the new suite"
} else {
    Fail "TEST-053: tests/design-sync-scan.tests.{sh,ps1} is not registered in both tests/run-all.sh and tests/run-all.ps1"
}

# ============================================================================
# REQ-009 (AC-031, AC-032, AC-033, AC-038) -- the two runtimes agree with
# each other, branch by branch, and the case-sensitivity sweep at full
# strength (T-002's own scope; none of this category is checkable before
# both scripts exist). Every row below is environment-conditional
# (AGENTS.md item 5): where bash is absent, each row SKIPs individually
# with a stated reason.
# ============================================================================

Write-Host ""
Write-Host "=== Cross-runtime exit-code parity (AC-031): TEST-049, TEST-070 - TEST-076 ==="
function Assert-ExitCodeParity {
    param([string]$Label, [string[]]$ScanArgs)
    if (-not $BashAvailable) {
        Write-Host "SKIP: ${Label}: bash is not available on this host (AGENTS.md 'Author-time sweeps' item 5) -- cross-runtime exit-code parity cannot be checked here."
        return
    }
    $rPs1 = Invoke-Scan -ScanArgs $ScanArgs
    $rSh = Invoke-ScanSh -ScanArgs $ScanArgs
    if ($rPs1.ExitCode -eq $rSh.ExitCode) {
        Ok "${Label}: both runtimes exit $($rPs1.ExitCode) for this fixture"
    } else {
        Fail "${Label}: exit codes diverged -- ps1=$($rPs1.ExitCode) sh=$($rSh.ExitCode). ps1 output: $($rPs1.Output) | sh output: $($rSh.Output)"
    }
}
Assert-ExitCodeParity "TEST-049 (AC-031, placeholder-only)" @($t006Dir)
Assert-ExitCodeParity "TEST-070 (AC-031, secret-only)" @($t007Dir)
Assert-ExitCodeParity "TEST-071 (AC-031, PII-only)" @($t008Dir)
Assert-ExitCodeParity "TEST-072 (AC-031, mixed-category)" @($t009Dir)
Assert-ExitCodeParity "TEST-073 (AC-031, clean)" @($t005Dir)
Assert-ExitCodeParity "TEST-074 (AC-031, zero-argument)" @()
Assert-ExitCodeParity "TEST-075 (AC-031, nonexistent target directory)" @($t011Missing)

$t076Dir = New-WorkDir "t076"
Set-Fixture (Join-Path $t076Dir "clean.html") @("<html><body><p>clean sibling</p></body></html>")
$t076Blocked = Join-Path $t076Dir "blocked.html"
Set-Fixture $t076Blocked @("<html><body><p>secret content, unreadable</p></body></html>")
if ($BashAvailable) {
    & chmod 000 $t076Blocked
    Assert-ExitCodeParity "TEST-076 (AC-031, unreadable file)" @($t076Dir)
    & chmod 644 $t076Blocked
} else {
    Write-Host "SKIP: TEST-076 (AC-031, unreadable file): bash is not available on this host (AGENTS.md 'Author-time sweeps' item 5) -- cross-runtime exit-code parity cannot be checked here."
}

Write-Host ""
Write-Host "=== Cross-runtime classification parity (AC-032): TEST-050, TEST-077 - TEST-079 ==="
function Get-FindingSet {
    param([string]$Output)
    $set = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Output -split "`n")) {
        if ($line -match '^\s*-\s+(\S+)\s+(.+):(\d+):') {
            $set.Add("$($Matches[1])|$($Matches[2])|$($Matches[3])") | Out-Null
        }
    }
    # The unary comma wraps the already-built array as a single pipeline
    # object so `return`'s implicit Write-Output does not unroll it back
    # into individual elements -- without this, a 0- or 1-element result
    # collapses to $null or a bare scalar at the call site (a documented
    # PowerShell return-value quirk, reproduced empirically while authoring
    # this suite), which then fails Set-StrictMode's property lookup on
    # .Count for an empty finding set (the classification-parity rows'
    # exact 0-finding-set inputs never occur in this suite's own fixtures,
    # but the fix is applied unconditionally rather than relying on that).
    return , @($set | Sort-Object -Unique)
}
function Assert-ClassificationParity {
    param([string]$Label, [string[]]$ScanArgs)
    if (-not $BashAvailable) {
        Write-Host "SKIP: ${Label}: bash is not available on this host (AGENTS.md 'Author-time sweeps' item 5) -- cross-runtime classification parity cannot be checked here."
        return
    }
    $rPs1 = Invoke-Scan -ScanArgs $ScanArgs
    $rSh = Invoke-ScanSh -ScanArgs $ScanArgs
    $setPs1 = Get-FindingSet $rPs1.Output
    $setSh = Get-FindingSet $rSh.Output
    $diff = if ($setSh.Count -gt 0 -or $setPs1.Count -gt 0) { Compare-Object -ReferenceObject $setSh -DifferenceObject $setPs1 } else { $null }
    if ($null -eq $diff -and $setPs1.Count -gt 0) {
        Ok "${Label}: both runtimes agree on every finding's category and file:line ($($setPs1.Count) finding(s))"
    } else {
        Fail "${Label}: classification diverged. sh findings: $($setSh -join '; ') | ps1 findings: $($setPs1 -join '; ')"
    }
}
Assert-ClassificationParity "TEST-050 (AC-032, placeholder)" @($t006Dir)
Assert-ClassificationParity "TEST-077 (AC-032, secret)" @($t007Dir)
Assert-ClassificationParity "TEST-078 (AC-032, PII)" @($t008Dir)
Assert-ClassificationParity "TEST-079 (AC-032, mixed)" @($t009Dir)

Write-Host ""
Write-Host "=== TEST-051 (AC-033, AGENTS.md item 1): case-sensitivity sweep -- a mis-cased negative fixture per case-sensitive pattern group, rejected identically to the .sh original ==="
function Assert-MisCasedRejected {
    param([string]$Label, [string]$Content)
    $safeName = ($Label -replace '[^A-Za-z0-9]', '_')
    $d = New-WorkDir "miscase-$safeName"
    Set-Fixture (Join-Path $d "m.html") @("<html><body>", $Content, "</body></html>")
    $rPs1 = Invoke-Scan -ScanArgs @($d)
    if ($rPs1.ExitCode -eq 0) {
        Ok "${Label} (ps1): the mis-cased fixture is rejected (exit 0, no false-positive finding)"
    } else {
        Fail "${Label} (ps1): expected exit 0 for the mis-cased negative fixture, got $($rPs1.ExitCode). Output: $($rPs1.Output)"
    }
    if (-not $BashAvailable) {
        Write-Host "SKIP: ${Label} (cross-runtime comparison): bash is not available on this host (AGENTS.md 'Author-time sweeps' item 5)."
        return
    }
    $rSh = Invoke-ScanSh -ScanArgs @($d)
    if ($rPs1.ExitCode -eq $rSh.ExitCode) {
        Ok "${Label} (cross-runtime): rejected identically to the .sh original (both exit $($rPs1.ExitCode))"
    } else {
        Fail "${Label} (cross-runtime): ps1 exit=$($rPs1.ExitCode) sh exit=$($rSh.ExitCode) -- diverged. ps1 output: $($rPs1.Output) | sh output: $($rSh.Output)"
    }
}
Assert-MisCasedRejected "TEST-051a (placeholder cs group, lower-cased 'todo')" "this todo list app has nothing to hide"
Assert-MisCasedRejected "TEST-051b (S1 PEM header, lower-cased)" "-----begin rsa private key-----"
Assert-MisCasedRejected "TEST-051c (S2 AKIA, lower-cased)" "akiaabcdefghijklmnop"
Assert-MisCasedRejected "TEST-051d (S3 ghp_, upper-cased prefix)" ("GHP_" + ("a" * 36))
Assert-MisCasedRejected "TEST-051e (S4 github_pat_, upper-cased prefix)" ("GITHUB_PAT_" + ("a" * 22))
Assert-MisCasedRejected "TEST-051f (S5 bare sk-, upper-cased prefix)" ("SK-" + ("a" * 20))
Assert-MisCasedRejected "TEST-051g (S5 sk-proj- sub-format, upper-cased prefix)" ("SK-PROJ-" + ("a" * 20))
Assert-MisCasedRejected "TEST-051h (S6 xoxb-, upper-cased prefix)" "XOXB-1234567890-abcdefghij"

Write-Host ""
Write-Host "=== TEST-084 (AC-038): the POSIX ERE (.sh) and .NET (.ps1) forms of S7 and P2 classify TEST-021/080-082's fixture set identically ==="
function Assert-DualFormParity {
    param([string]$Label, [string]$Dir, [int]$ExpectedExit)
    if (-not $BashAvailable) {
        Write-Host "SKIP: ${Label}: bash is not available on this host (AGENTS.md 'Author-time sweeps' item 5) -- dual-form parity cannot be checked here."
        return
    }
    $rPs1 = Invoke-Scan -ScanArgs @($Dir)
    $rSh = Invoke-ScanSh -ScanArgs @($Dir)
    if ($rPs1.ExitCode -eq $ExpectedExit -and $rSh.ExitCode -eq $ExpectedExit) {
        Ok "${Label}: both the .NET form (ps1) and the POSIX ERE form (sh) classify this fixture identically (exit $ExpectedExit)"
    } else {
        Fail "${Label}: expected both exit $ExpectedExit -- ps1=$($rPs1.ExitCode) sh=$($rSh.ExitCode). ps1: $($rPs1.Output) | sh: $($rSh.Output)"
    }
}
Assert-DualFormParity "TEST-084a (S7 positive, TEST-021 fixture)" $t021Dir 1
Assert-DualFormParity "TEST-084b (S7 negative, TEST-021 fixture)" $t021NegDir 0
Assert-DualFormParity "TEST-084c (P2 7-digit short, TEST-080 fixture)" $t080Dir 0
Assert-DualFormParity "TEST-084d (P2 16-digit long, TEST-081 fixture)" $t081Dir 0
Assert-DualFormParity "TEST-084e (P2 leading-adjacent digit, TEST-082 fixture)" $t082Dir 0
Assert-DualFormParity "TEST-084f (P2 leading-adjacent control, TEST-082-control fixture)" $t082CtrlDir 1

Write-Host ""
Write-Host "=== TEST-086 (cross-runtime half of AC-039b): an upper-cased .HTML file containing a finding blocks identically on both runtimes ==="
if (-not $BashAvailable) {
    Write-Host "SKIP: TEST-086 (cross-runtime): bash is not available on this host (AGENTS.md 'Author-time sweeps' item 5) -- cross-runtime selection-boundary parity cannot be checked here."
} else {
    $rPs1 = Invoke-Scan -ScanArgs @($t086Dir)
    $rSh = Invoke-ScanSh -ScanArgs @($t086Dir)
    if ($rPs1.ExitCode -eq 1 -and $rSh.ExitCode -eq 1) {
        Ok "TEST-086 (cross-runtime): both runtimes block on the same upper-cased .HTML finding (exit 1) -- PowerShell's case-insensitive filesystem filtering and .sh's -iname agree"
    } else {
        Fail "TEST-086 (cross-runtime): expected both exit 1 -- ps1=$($rPs1.ExitCode) sh=$($rSh.ExitCode)."
    }
}

# ============================================================================
# T-003 -- REQ-002 (AC-037), REQ-004 (AC-016), REQ-005 (AC-017, AC-018's
# SKILL.md half, AC-019), REQ-006 (AC-020-AC-025), REQ-007 (AC-026-AC-028) --
# design-sync-loop/SKILL.md step 5's activation and the Design-Source
# record's two new fields (Egress-Scan, Egress-Scan-At). Document-
# conformance rows (parse/read SKILL.md text, no script execution), plus one
# baseline-relative regression (TEST-046) run directly against the
# pre-existing tests/design-system-contract.tests.ps1 suite this task does
# not edit. Positional/structural technique (TEST-035, TEST-045) mirrors
# design-sync-consent's TEST-010/TEST-014, ported at parity from the .sh
# twin (BL-008); every literal below is plain ASCII, so no asymmetry
# comment is required at any assertion site in this block.
#
# Baseline preservation (tasks.md Global Constraints): SKILL.md steps 1-4,
# 6-7, "## Capability Detection", "## Ensure design-system/", "##
# Boundaries", and the five existing Design-Source field rows are untouched
# by this task's SKILL.md edit -- the rows below verify only step 5's new
# content and the two new field rows.
# ============================================================================

$Dsl = Join-Path $RepoRoot "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"

function Get-T003FlattenedFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $raw = Get-Content -Raw -LiteralPath $Path
    return ($raw -replace '\r?\n', ' ') -replace '\s+', ' '
}

# Lines from the first line matching $Start (inclusive) up to, but
# excluding, the first later line matching $End, from file $Path.
function Get-T003SectionBetween([string]$Path, [string]$Start, [string]$End) {
    $lines = Get-Content -LiteralPath $Path
    $out = New-Object System.Collections.Generic.List[string]
    $flag = $false
    foreach ($line in $lines) {
        if (-not $flag -and $line -match $Start) { $flag = $true }
        elseif ($flag -and ($line -match $End) -and ($line -notmatch $Start)) { break }
        if ($flag) { $out.Add($line) | Out-Null }
    }
    return ($out -join "`n")
}

$DslFlat = Get-T003FlattenedFile $Dsl
$DslLoopSection = Get-T003SectionBetween $Dsl '^## Loop$' '^## '
$DslLoopFlat = (($DslLoopSection -replace '\r?\n', ' ') -replace '\s+', ' ')

# First line number (1-based, within $DslLoopSection) matching regex $Pattern.
function Get-T003LoopLineOf([string]$Pattern) {
    $lines = $DslLoopSection -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $Pattern) { return $i + 1 }
    }
    return $null
}

Write-Host ""
Write-Host "=== TEST-031 (AC-016): step 5 names the script, the target dir, and states exit-1 presents findings before any push ==="
if ($DslFlat -match 'design-sync-scan\.sh' `
        -and $DslFlat.Contains("specs/<feature>/mockups/") `
        -and $DslFlat.Contains("present the findings report to the human before any push is attempted") `
        -and $DslFlat.Contains("no push occurs without that presentation")) {
    Ok "TEST-031: step 5 names design-sync-scan.ps1 and specs/<feature>/mockups/, and states exit-1 presents findings before any push"
} else {
    Fail "TEST-031: step 5 must name the script, the target dir, and state exit-1 presents findings before push"
}

Write-Host ""
Write-Host "=== TEST-032 (AC-017): the exit-0 branch states direct continuation to 6, no additional prompt, no delay beyond scan run time ==="
if ($DslFlat.Contains("continue directly to 6") `
        -and $DslFlat.Contains("No additional prompt") `
        -and $DslFlat.Contains("no delay beyond the scan") `
        -and $DslFlat.Contains("own run time")) {
    Ok "TEST-032: exit 0 states direct continuation to step 6, no additional prompt, no delay beyond the scan's own run time"
} else {
    Fail "TEST-032: exit-0 branch must state direct continuation, no prompt, no delay beyond the scan's own run time"
}

Write-Host ""
Write-Host "=== TEST-033 (AC-018, SKILL.md half): the skill text states the check is egress-hygiene-only, no quality judgment ==="
if ($DslFlat -match 'egress hygiene' `
        -and $DslFlat -match 'no assessment of mockup quality' `
        -and $DslFlat -match 'design fidelity' `
        -and $DslFlat -match 'accessibility' `
        -and $DslFlat -match 'design-system') {
    Ok "TEST-033: SKILL.md states the check is limited to egress hygiene and makes no quality/fidelity/accessibility/design-system judgment"
} else {
    Fail "TEST-033: SKILL.md must state the egress-hygiene-only boundary in its own words"
}

Write-Host ""
Write-Host "=== TEST-035 (AC-019, structural): the Loop's step order is unchanged -- generate -> consent -> check point -> push -> review, cycle to 2 ==="
$t035S1 = Get-T003LoopLineOf '^1\. \*\*Select project'
$t035S2 = Get-T003LoopLineOf '^2\. \*\*Generate mockups'
$t035S3 = Get-T003LoopLineOf '^3\. \*\*Resolve egress consent'
$t035S4 = Get-T003LoopLineOf '^4\. \*\*Obtain informed consent'
$t035S5 = Get-T003LoopLineOf '^5\. \*\*Pre-upload check point'
$t035S6 = Get-T003LoopLineOf '^6\. \*\*Push'
$t035S7 = Get-T003LoopLineOf '^7\. \*\*Review in the claude\.ai'
if ($null -ne $t035S1 -and $null -ne $t035S2 -and $null -ne $t035S3 -and $null -ne $t035S4 `
        -and $null -ne $t035S5 -and $null -ne $t035S6 -and $null -ne $t035S7 `
        -and $t035S1 -lt $t035S2 -and $t035S2 -lt $t035S3 -and $t035S3 -lt $t035S4 `
        -and $t035S4 -lt $t035S5 -and $t035S5 -lt $t035S6 -and $t035S6 -lt $t035S7 `
        -and $DslLoopFlat -match 'return to 2\b' `
        -and $DslLoopFlat -notmatch 'return to 3\b') {
    Ok "TEST-035: the Loop's seven numbered steps retain their relative order, and the cycle at 7 returns to 2, not 3"
} else {
    Fail "TEST-035: step order or the regeneration cycle target changed. lines: 1=$t035S1 2=$t035S2 3=$t035S3 4=$t035S4 5=$t035S5 6=$t035S6 7=$t035S7"
}

Write-Host ""
Write-Host "=== TEST-036 (AC-020): an explicit override affordance is stated; absent it, no push occurs -- silence/non-response/agent judgment is not an override ==="
if ($DslFlat -match 'explicit human override' `
        -and $DslFlat.Contains("Absent an explicit override") `
        -and $DslFlat.Contains("silence") `
        -and $DslFlat.Contains("non-response") `
        -and $DslFlat.Contains("own judgment") `
        -and $DslFlat.Contains("never an override") `
        -and $DslFlat.Contains("no push occurs")) {
    Ok "TEST-036: an explicit override affordance is stated; silence, non-response, or agent judgment is never an override, and absent it no push occurs"
} else {
    Fail "TEST-036: the override affordance and its negative (no explicit approval -> no push) must both be stated"
}

Write-Host ""
Write-Host "=== TEST-037 (AC-021.1): a fresh scan after regeneration requires its own override decision -- a prior override does not carry forward ==="
if ($DslFlat.Contains("fresh scan after any regeneration requires its own override decision")) {
    Ok "TEST-037: a fresh scan after any regeneration is stated to require its own override decision"
} else {
    Fail "TEST-037: step 5 must state that a fresh scan after regeneration requires its own override decision"
}

Write-Host ""
Write-Host "=== TEST-038 (AC-021.2): this holds even when the new scan reproduces IDENTICAL findings -- recurrence is not evidence the human need not be asked again ==="
if ($DslFlat.Contains("reproduces findings identical to the ones already overridden")) {
    Ok "TEST-038: the no-carry-forward rule is stated to hold even for identical findings, not only different ones"
} else {
    Fail "TEST-038: step 5 must state the no-carry-forward rule holds even when findings are identical to a prior override"
}

Write-Host ""
Write-Host "=== TEST-039 (AC-022.1): an override is stated to record Egress-Scan: overridden ==="
if ($DslFlat.Contains("Egress-Scan: overridden")) {
    Ok "TEST-039: step 5 states an override records Egress-Scan: overridden"
} else {
    Fail "TEST-039: step 5 must state Egress-Scan: overridden is recorded on override"
}

Write-Host ""
Write-Host "=== TEST-040 (AC-022.2): a clean scan is stated to record Egress-Scan: clean ==="
if ($DslFlat.Contains("Egress-Scan: clean")) {
    Ok "TEST-040: step 5 states a clean scan records Egress-Scan: clean"
} else {
    Fail "TEST-040: step 5 must state Egress-Scan: clean is recorded on a clean scan"
}

Write-Host ""
Write-Host "=== TEST-041 (AC-023, clean value): Egress-Scan-At (ISO-8601) is stated for the clean branch ==="
if ($DslFlat -match 'Egress-Scan: clean.{0,120}ISO-8601') {
    Ok "TEST-041: the clean branch states Egress-Scan-At as an ISO-8601 timestamp"
} else {
    Fail "TEST-041: the clean branch must state Egress-Scan-At (ISO-8601)"
}

Write-Host ""
Write-Host "=== TEST-064 (AC-023, overridden value): Egress-Scan-At (ISO-8601) is stated for the overridden branch too, not only the exceptional one ==="
if ($DslFlat -match 'Egress-Scan: overridden.{0,120}ISO-8601') {
    Ok "TEST-064: the overridden branch also states Egress-Scan-At as an ISO-8601 timestamp"
} else {
    Fail "TEST-064: the overridden branch must state Egress-Scan-At (ISO-8601), not only the clean branch"
}

Write-Host ""
Write-Host "=== TEST-042, TEST-065 - TEST-068 (AC-024): the five existing Design-Source field names are present, unrenamed, unredefined ==="
function Assert-FieldRowPresent([string]$Label, [string]$Row) {
    if ($DslFlat.Contains($Row)) {
        Ok "${Label}: the field row $Row is present, unrenamed"
    } else {
        Fail "${Label}: expected the unmodified field row $Row in $Dsl"
    }
}
Assert-FieldRowPresent "TEST-042 (Egress-Consent)" '| `Egress-Consent` |'
Assert-FieldRowPresent "TEST-065 (Egress-Consent-Scope)" '| `Egress-Consent-Scope` |'
Assert-FieldRowPresent "TEST-066 (Egress-Consent-Subject)" '| `Egress-Consent-Subject` |'
Assert-FieldRowPresent "TEST-067 (Egress-Destination)" '| `Egress-Destination` |'
Assert-FieldRowPresent "TEST-068 (Egress-Consent-Expiry)" '| `Egress-Consent-Expiry` |'

Write-Host ""
Write-Host "=== TEST-043 (AC-025): on decline, no push, nothing written to Design-Source as an override, remediate before rescan -- distinguished from Egress-Consent's decline/withdrawal ==="
if ($DslFlat.Contains("nothing is written to") `
        -and $DslFlat.Contains("Design-Source") `
        -and $DslFlat.Contains("as an override") `
        -and $DslFlat -match 'remediates the flagged mockups' `
        -and $DslFlat.Contains("distinct from") `
        -and $DslFlat.Contains("decline or withdrawal")) {
    Ok "TEST-043: the decline outcome (no push, nothing written as override, remediate) is stated and distinguished from Egress-Consent's own decline/withdrawal vocabulary"
} else {
    Fail "TEST-043: the decline outcome must be stated in full and distinguished from Egress-Consent's decline/withdrawal vocabulary"
}

Write-Host ""
Write-Host "=== TEST-044 (AC-026): step 5 remains the single named point -- not duplicated, not relocated relative to steps 4 and 6 ==="
$t044Lines = Get-Content -LiteralPath $Dsl
$t044Count = @($t044Lines | Where-Object { $_ -match '^5\. \*\*Pre-upload check point' }).Count
$t044S4 = Get-T003LoopLineOf '^4\. \*\*Obtain informed consent'
$t044S5 = Get-T003LoopLineOf '^5\. \*\*Pre-upload check point'
$t044S6 = Get-T003LoopLineOf '^6\. \*\*Push'
if ($t044Count -eq 1 -and $null -ne $t044S4 -and $null -ne $t044S5 -and $null -ne $t044S6 `
        -and $t044S4 -lt $t044S5 -and $t044S5 -lt $t044S6) {
    Ok "TEST-044: step 5 appears exactly once, still positioned between steps 4 and 6"
} else {
    Fail "TEST-044: step 5 must appear exactly once and stay positioned between steps 4 and 6. count=$t044Count s4=$t044S4 s5=$t044S5 s6=$t044S6"
}

Write-Host ""
Write-Host "=== TEST-045 (AC-027, positional): no route from generation to push (write_files) in the Loop's text reaches push without passing step 5's position first ==="
function Test-045NoBypass {
    $cpLine = Get-T003LoopLineOf '^5\. \*\*Pre-upload check point'
    if ($null -eq $cpLine) { return $false }
    $loopLines = $DslLoopSection -split "`n"
    $uploadIdxs = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $loopLines.Count; $i++) {
        if ($loopLines[$i] -match 'write_files') { $uploadIdxs.Add($i + 1) | Out-Null }
    }
    if ($uploadIdxs.Count -eq 0) { return $false }
    foreach ($idx in $uploadIdxs) {
        if ($idx -lt $cpLine) { return $false }
    }
    return $true
}
if (Test-045NoBypass) {
    Ok "TEST-045: every write_files mention in the Loop's text sits at or after step 5's position -- no described route bypasses it"
} else {
    Fail "TEST-045: a write_files mention sits before step 5's position -- the text describes a bypass"
}

Write-Host ""
Write-Host "=== TEST-046 (AC-028, baseline-relative regression): tests/design-system-contract.tests.ps1 introduces zero new failures vs its documented baseline ==="
$DscPs1 = Join-Path $RepoRoot "tests/design-system-contract.tests.ps1"
$DscBaselinePs1 = Join-Path $RepoRoot "specs/design-sync-scan/verification/T-003/dsc-baseline.ps1.log"
function Test-046NoGreenToRedFlip([string]$BaselineLog, [string[]]$CurrentOutput) {
    if (-not (Test-Path -LiteralPath $BaselineLog -PathType Leaf)) { return $false }
    $baselineLines = Get-Content -LiteralPath $BaselineLog
    $currentSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($l in $CurrentOutput) { [void]$currentSet.Add($l) }
    foreach ($line in $baselineLines) {
        if ($line -like "PASS: DS-*" -or $line -like "PASS: TEST-*") {
            if (-not $currentSet.Contains($line)) { return $false }
        }
    }
    return $true
}
$dscCurrentPs1Raw = @() | & pwsh -NoProfile -ExecutionPolicy Bypass -File $DscPs1 2>&1
$dscCurrentPs1 = @($dscCurrentPs1Raw | ForEach-Object { "$_" })
if ((Test-046NoGreenToRedFlip $DscBaselinePs1 $dscCurrentPs1) `
        -and ($dscCurrentPs1 -match '^PASS: TEST-010 ').Count -gt 0 `
        -and ($dscCurrentPs1 -match '^PASS: TEST-015 ').Count -gt 0 `
        -and ($dscCurrentPs1 -match '^PASS: TEST-018 ').Count -gt 0 `
        -and ($dscCurrentPs1 -match '^PASS: TEST-026 ').Count -gt 0 `
        -and ($dscCurrentPs1 -match '^PASS: TEST-040 ').Count -gt 0) {
    Ok "TEST-046: tests/design-system-contract.tests.ps1 has zero new failures against its documented baseline (TEST-010/015/018/026/040 re-verified passing; TEST-039 remains its pre-existing designed red)"
} else {
    Fail "TEST-046: tests/design-system-contract.tests.ps1 regressed -- a baseline-green row is no longer green, or one of TEST-010/015/018/026/040 is no longer passing"
}

Write-Host ""
Write-Host "=== TEST-055 (AC-037): the skill states the exit-2 branch is unconditionally blocking, with no override affordance offered at all ==="
if ($DslFlat -match 'unconditionally blocking' `
        -and $DslFlat -match 'no override affordance' `
        -and $DslFlat -match 'offered at all' `
        -and $DslFlat -match 'tool failure') {
    Ok "TEST-055: the exit-2 branch is stated as unconditionally blocking with no override affordance offered at all, worded as a tool failure"
} else {
    Fail "TEST-055: the exit-2 branch must state it is unconditionally blocking with no override affordance at all"
}

# ============================================================================
# T-004 -- REQ-008 (AC-029) -- claude-design-workflow.md documents the
# standalone/Codex scan usage ahead of the manual fallback it describes.
# Document conformance (real read), ported at parity from the .sh twin
# (BL-008); the medium tier's required-check set (risk-gate-matrix.md) --
# no independent review / traceability evidence mandated at this tier.
# This is the last content-adding task in this suite's Shared-Suite Append
# Discipline (tasks.md Global Constraints); with this block landed,
# AC-034's full "both suite files together cover REQ-001 through REQ-009"
# claim is satisfiable for the first time, and T-001's TEST-052
# traceability-manifest check above is re-run at this point and recorded
# passing (tasks.md T-004 Done-When). Every literal below is plain ASCII,
# so no asymmetry comment is required at any assertion site in this block.
#
# Reuses Get-T003FlattenedFile (defined above, in T-003's block) -- a
# generic whitespace-flatten utility, not itself part of T-003's
# byte-unchanged assertion content, so calling it here does not modify
# that block.
# ============================================================================

$Cdw = Join-Path $RepoRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md"
$CdwFlat = Get-T003FlattenedFile $Cdw

Write-Host ""
Write-Host "=== TEST-047 (AC-029): claude-design-workflow.md documents standalone design-sync-scan usage ahead of the manual fallback it describes ==="
if ($CdwFlat.Contains("design-sync-scan.sh") `
        -and $CdwFlat.Contains("design-sync-scan.ps1") `
        -and $CdwFlat.Contains("specs/<feature>/mockups/") `
        -and $CdwFlat.Contains("no Claude Code-specific tool") `
        -and $CdwFlat.Contains("no deferred-tool search") `
        -and $CdwFlat.Contains("no DesignSync capability") `
        -and $CdwFlat.Contains("as a precondition")) {
    Ok "TEST-047: claude-design-workflow.md names both scripts, the required target-directory argument, and states no Claude Code-specific tool/deferred-tool search/DesignSync capability is a precondition"
} else {
    Fail "TEST-047: claude-design-workflow.md must name design-sync-scan.sh/.ps1, specs/<feature>/mockups/, and state no Claude Code-specific tool/deferred-tool search/DesignSync capability is a precondition"
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "Results: $($script:PassCount) passed, $($script:FailCount) failed"
if ($script:FailCount -gt 0) {
    exit 1
}
exit 0

} finally {
    if (Test-Path -LiteralPath $Work) {
        Remove-Item -Recurse -Force -LiteralPath $Work -ErrorAction SilentlyContinue
    }
}
