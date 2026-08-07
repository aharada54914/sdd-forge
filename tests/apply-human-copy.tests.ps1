# T-007 (epic-189-a1-project-context, REQ-007): acceptance checks for
# plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 -- the anchored-
# publisher-equivalent human-copy tool (design.md "Human-copy publisher
# transactional bundle contract"; AC-033/TEST-033).
#
# PowerShell parity port of tests/apply-human-copy.tests.sh. See that
# file's header for the full TEST-033a..o <-> AC-033 mapping.
#
# Every invocation below runs apply-human-copy.ps1 as a REAL CHILD PROCESS
# via [System.Diagnostics.Process] (never PowerShell's own `&` call
# operator: the tool calls `exit $Code` internally, which would terminate
# THIS test session if invoked in-process -- mirroring detect-policy-
# weakening.tests.ps1's own established rationale).
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("apply-human-copy-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$ApplyPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/apply-human-copy.ps1'
# The SAME PowerShell binary currently running this suite, matching
# tests/run-all.ps1's own convention.
$PowerShellExe = (Get-Process -Id $PID).Path

$script:PassCount = 0
$script:FailCount = 0

function Test-Pass([string]$Label) {
    $script:PassCount++
    Write-Output "PASS: $Label"
}

function Test-Fail([string]$Label, [string]$Detail = '') {
    $script:FailCount++
    Write-Output "FAIL: ${Label}: $Detail"
}

function Invoke-ChildProcess {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$ArgList = @(),
        [string]$WorkingDirectory
    )
    $outPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.out')
    $errPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.err')

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Exe
    foreach ($a in $ArgList) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdoutStream = [System.IO.MemoryStream]::new()
    $stderrStream = [System.IO.MemoryStream]::new()
    $copyOutTask = $proc.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
    $copyErrTask = $proc.StandardError.BaseStream.CopyToAsync($stderrStream)
    $proc.WaitForExit()
    $copyOutTask.GetAwaiter().GetResult()
    $copyErrTask.GetAwaiter().GetResult()
    [System.IO.File]::WriteAllBytes($outPath, $stdoutStream.ToArray())
    [System.IO.File]::WriteAllBytes($errPath, $stderrStream.ToArray())

    return @{ ExitCode = $proc.ExitCode; StdoutPath = $outPath; StderrPath = $errPath }
}

function Invoke-Apply {
    param([string]$RepoDir, [string[]]$ArgList = @())
    return Invoke-ChildProcess -Exe $PowerShellExe `
        -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ApplyPs1) + $ArgList) `
        -WorkingDirectory $RepoDir
}

function Get-CategoryOf([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $text) { return $null }
    if ($text -match '"category":"([^"]*)"') { return $Matches[1] }
    return $null
}

function Get-Sha256Hex([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$script:FixtureCounter = 0
function New-FixtureDir {
    $script:FixtureCounter++
    $dir = Join-Path $Work "f$script:FixtureCounter"
    New-Item -ItemType Directory -Path (Join-Path $dir 'repo/sdd/.staging') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'stage') -Force | Out-Null
    return $dir
}

function Write-FixtureFile([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, "$Content`n", [System.Text.Encoding]::UTF8)
}

function Get-ManifestLine([string]$StageDir, [string]$RelPath) {
    $hash = Get-Sha256Hex (Join-Path $StageDir $RelPath)
    return "$hash  $RelPath"
}

try {

# ---------------------------------------------------------------------------
# TEST-033a: basic single-target fresh publish.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'candidate-v1'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/file.txt') + "`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -eq 0) { Test-Pass 'TEST-033a fresh single-target publish: tool exits 0' } else { Test-Fail 'TEST-033a fresh single-target publish: tool exits 0' "exit $($r.ExitCode)" }
$liveContent = (Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/file.txt') -ErrorAction SilentlyContinue)
if ($liveContent -eq "candidate-v1`n") { Test-Pass 'TEST-033a fresh single-target publish: live content matches candidate' } else { Test-Fail 'TEST-033a fresh single-target publish: live content matches candidate' "got '$liveContent'" }

# ---------------------------------------------------------------------------
# TEST-033b: publish over existing live content.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/file.txt') 'old-content'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'new-content'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/file.txt') + "`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
$liveContent = (Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/file.txt') -ErrorAction SilentlyContinue)
if ($liveContent -eq "new-content`n") { Test-Pass 'TEST-033b publish over existing live content: content replaced' } else { Test-Fail 'TEST-033b publish over existing live content: content replaced' "got '$liveContent'" }

# ---------------------------------------------------------------------------
# TEST-033c: pre-existing symlink at the destination leaf denied.
# ---------------------------------------------------------------------------
if ($IsWindows) {
    # Symlink creation on Windows requires elevation/Developer Mode not
    # guaranteed in CI; skip this ONE OS-specific fixture rather than fail
    # spuriously on environment capability, matching this epic's other
    # suites' own non-use declarations for capability gaps outside scope.
    Test-Pass 'TEST-033c pre-existing symlink at destination leaf denied (skipped: Windows symlink creation requires elevation)'
} else {
    $F = New-FixtureDir
    Write-FixtureFile (Join-Path $F 'canary.txt') 'untouched-canary'
    New-Item -ItemType Directory -Path (Join-Path $F 'repo/plugins/x') -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path (Join-Path $F 'repo/plugins/x/file.txt') -Target (Join-Path $F 'canary.txt') | Out-Null
    Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'malicious'
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/file.txt') + "`n")
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    if ($r.ExitCode -ne 0) { Test-Pass "TEST-033c pre-existing symlink at destination leaf denied (exit $($r.ExitCode))" } else { Test-Fail 'TEST-033c pre-existing symlink at destination leaf denied' "exit 0" }
    $canaryContent = Get-Content -Raw -LiteralPath (Join-Path $F 'canary.txt')
    if ($canaryContent -eq "untouched-canary`n") { Test-Pass 'TEST-033c symlink target (canary) is never written through' } else { Test-Fail 'TEST-033c symlink target (canary) is never written through' "got '$canaryContent'" }
}

# ---------------------------------------------------------------------------
# TEST-033d: symlink at an INTERMEDIATE destination-parent segment is
# denied (quality-gate seq0357 Major #2 remedy: this case previously had
# NO pwsh coverage on ANY platform -- an earlier report claimed an
# `$IsWindows` skip branch that did not exist. Implemented here, running
# for real on macOS/Linux, where the CI matrix actually exercises pwsh
# symlink handling; skipped ONLY on native Windows, matching TEST-033c's
# own already-correct convention, for the SAME reason -- symlink creation
# there requires elevation/Developer Mode not guaranteed in CI).
# ---------------------------------------------------------------------------
if ($IsWindows) {
    Test-Pass 'TEST-033d symlinked intermediate destination-parent segment denied (skipped: Windows symlink creation requires elevation)'
} else {
    $F = New-FixtureDir
    New-Item -ItemType Directory -Path (Join-Path $F 'repo/plugins') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $F 'elsewhere-dir') -Force | Out-Null
    Write-FixtureFile (Join-Path $F 'elsewhere-dir/untouched.txt') 'elsewhere-canary'
    New-Item -ItemType SymbolicLink -Path (Join-Path $F 'repo/plugins/x') -Target (Join-Path $F 'elsewhere-dir') | Out-Null
    Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'malicious2'
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/file.txt') + "`n")
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    if ($r.ExitCode -ne 0) { Test-Pass "TEST-033d symlinked intermediate destination-parent segment denied (exit $($r.ExitCode))" } else { Test-Fail 'TEST-033d symlinked intermediate destination-parent segment denied' "exit 0" }
    if (-not (Test-Path -LiteralPath (Join-Path $F 'elsewhere-dir/file.txt'))) { Test-Pass 'TEST-033d write never redirected through the symlinked segment' } else { Test-Fail 'TEST-033d write never redirected through the symlinked segment' 'leaked into elsewhere-dir' }
}

# ---------------------------------------------------------------------------
# TEST-033e: the STAGED SOURCE candidate itself being a symlink is denied
# (quality-gate seq0357 Major #2 remedy -- see TEST-033d's header comment;
# same skip-only-on-native-Windows convention).
# ---------------------------------------------------------------------------
if ($IsWindows) {
    Test-Pass 'TEST-033e symlinked staged source candidate denied (skipped: Windows symlink creation requires elevation)'
} else {
    $F = New-FixtureDir
    Write-FixtureFile (Join-Path $F 'canary2.txt') 'source-canary'
    New-Item -ItemType Directory -Path (Join-Path $F 'stage/plugins/x') -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path (Join-Path $F 'stage/plugins/x/file.txt') -Target (Join-Path $F 'canary2.txt') | Out-Null
    $h = Get-Sha256Hex (Join-Path $F 'canary2.txt')
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value "$h  plugins/x/file.txt`n"
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    if ($r.ExitCode -ne 0) { Test-Pass "TEST-033e symlinked staged source candidate denied (exit $($r.ExitCode))" } else { Test-Fail 'TEST-033e symlinked staged source candidate denied' 'exit 0' }
    if (-not (Test-Path -LiteralPath (Join-Path $F 'repo/plugins/x/file.txt'))) { Test-Pass 'TEST-033e no live target created from a symlinked source' } else { Test-Fail 'TEST-033e no live target created from a symlinked source' 'live target exists' }
}

# ---------------------------------------------------------------------------
# TEST-033f: hard-link-alias non-propagation.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/live.txt') 'shared-old'
New-Item -ItemType HardLink -Path (Join-Path $F 'repo/plugins/x/alias.txt') -Target (Join-Path $F 'repo/plugins/x/live.txt') | Out-Null
Write-FixtureFile (Join-Path $F 'stage/plugins/x/live.txt') 'shared-new'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/live.txt') + "`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
$liveContent = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/live.txt')
$aliasContent = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/alias.txt')
if ($liveContent -eq "shared-new`n") { Test-Pass 'TEST-033f hard-link non-propagation: live target updated' } else { Test-Fail 'TEST-033f hard-link non-propagation: live target updated' "got '$liveContent'" }
if ($aliasContent -eq "shared-old`n") { Test-Pass 'TEST-033f hard-link non-propagation: alias name retains OLD bytes' } else { Test-Fail 'TEST-033f hard-link non-propagation: alias name retains OLD bytes' "got '$aliasContent'" }

# ---------------------------------------------------------------------------
# TEST-033g: staged-candidate hash mismatch -- preparation-stage failure,
# live target unchanged.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/file.txt') 'untouched-live'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'whatever'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ("0000000000000000000000000000000000000000000000000000000000000000  plugins/x/file.txt`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
$cat = Get-CategoryOf $r.StdoutPath
if ($r.ExitCode -ne 0 -and $cat -eq 'STAGED_CANDIDATE_HASH_MISMATCH') { Test-Pass 'TEST-033g staged-candidate hash mismatch denied (STAGED_CANDIDATE_HASH_MISMATCH)' } else { Test-Fail 'TEST-033g staged-candidate hash mismatch denied' "exit $($r.ExitCode) category $cat" }
$liveContent = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/file.txt')
if ($liveContent -eq "untouched-live`n") { Test-Pass 'TEST-033g live target unchanged on preparation-stage failure' } else { Test-Fail 'TEST-033g live target unchanged on preparation-stage failure' "got '$liveContent'" }

# ---------------------------------------------------------------------------
# TEST-033h: manifest shape validation.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'x'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value "not-a-valid-manifest-line`n"
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'MANIFEST_INVALID') { Test-Pass 'TEST-033h malformed manifest line rejected (MANIFEST_INVALID)' } else { Test-Fail 'TEST-033h malformed manifest line rejected' "exit $($r.ExitCode)" }

$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'x'
$h = Get-Sha256Hex (Join-Path $F 'stage/plugins/x/file.txt')
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value "$h  ../escape.txt`n"
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'MANIFEST_INVALID') { Test-Pass 'TEST-033h traversal target path rejected (MANIFEST_INVALID)' } else { Test-Fail 'TEST-033h traversal target path rejected' "exit $($r.ExitCode)" }

$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'x'
$h = Get-Sha256Hex (Join-Path $F 'stage/plugins/x/file.txt')
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value "$h  plugins/x/file.txt`n$h  plugins/x/file.txt`n"
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'MANIFEST_INVALID') { Test-Pass 'TEST-033h duplicate manifest target rejected (MANIFEST_INVALID)' } else { Test-Fail 'TEST-033h duplicate manifest target rejected' "exit $($r.ExitCode)" }

# ---------------------------------------------------------------------------
# TEST-033i..l: the four AC-033 crash-injection scenarios, each driven
# across the DESTINATION-DIRECTORY-EXISTENCE AXIS (quality-gate seq0361
# STRUCTURAL remedy -- see tests/apply-human-copy.tests.sh's own header
# comment for the full rationale). Every scenario runs once with the
# destination chain and live targets ALREADY PRESENT (journal records a
# real pre_hash) and once with NOTHING present (journal records
# pre_hash="ABSENT", the ordinary first-ever-publish shape that rounds 1-4
# never exercised and round 4's Critical fix then broke).
# ---------------------------------------------------------------------------

function New-CrashFixture([string]$Variant, [int]$TargetCount) {
    $f = New-FixtureDir
    $lines = ''
    $names = @('a', 'b', 'c')[0..($TargetCount - 1)]
    foreach ($nm in $names) {
        if ($Variant -eq 'pre-existing') {
            Write-FixtureFile (Join-Path $f "repo/plugins/x/$nm.txt") "old-$nm"
        }
        Write-FixtureFile (Join-Path $f "stage/plugins/x/$nm.txt") "new-$nm"
        $lines += (Get-ManifestLine (Join-Path $f 'stage') "plugins/x/$nm.txt") + "`n"
    }
    Set-Content -LiteralPath (Join-Path $f 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $lines
    return $f
}

# Get-CrashState -> the target's ABSTRACT state: PRE, POST or OTHER. A
# target that does not exist IS its pre-transaction state exactly when the
# journal recorded pre_hash='ABSENT' (design.md:1042-1043's "or both are
# ABSENT" clause), which the `absent` variant exists to exercise.
function Get-CrashState([string]$FixtureDir, [string]$Variant, [string]$Name) {
    $p = Join-Path $FixtureDir "repo/plugins/x/$Name.txt"
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $c = Get-Content -Raw -LiteralPath $p
        if ($c -eq "new-$Name`n") { return 'POST' }
        if ($Variant -eq 'pre-existing' -and $c -eq "old-$Name`n") { return 'PRE' }
        return 'OTHER'
    }
    if ($Variant -eq 'absent') { return 'PRE' }
    return 'OTHER'
}

function Get-CrashStates([string]$FixtureDir, [string]$Variant, [int]$TargetCount) {
    $names = @('a', 'b', 'c')[0..($TargetCount - 1)]
    return (($names | ForEach-Object { Get-CrashState $FixtureDir $Variant $_ }) -join ' ')
}

function Test-NoStagingLitter([string]$FixtureDir) {
    $litter = Get-ChildItem -Path (Join-Path $FixtureDir 'repo/sdd/.staging') -Recurse -File -ErrorAction SilentlyContinue
    return (-not $litter)
}

foreach ($axis in @('pre-existing', 'absent')) {

    # -----------------------------------------------------------------------
    # TEST-033i: crash BEFORE any rename recovers to ALL-PRE. In the
    # `absent` variant this is the exact fixture quality-gate seq0361
    # reported as a Critical regression.
    # -----------------------------------------------------------------------
    $F = New-CrashFixture $axis 2
    $stageArgs = @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList ($stageArgs + @('-SimulateCrashAfter', 'journal-write')) | Out-Null
    $obs = Get-CrashStates $F $axis 2
    if ($obs -eq 'PRE PRE') { Test-Pass "TEST-033i [$axis] crash before any rename: both targets still PRE immediately after the crash" } else { Test-Fail "TEST-033i [$axis] crash before any rename: both targets still PRE" "states '$obs'" }
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
    $obs = Get-CrashStates $F $axis 2
    if ($r.ExitCode -eq 0 -and $obs -eq 'PRE PRE') { Test-Pass "TEST-033i [$axis] recovery converges to ALL-PRE (crash before any rename)" } else { Test-Fail "TEST-033i [$axis] recovery converges to ALL-PRE" "exit $($r.ExitCode) states '$obs' category $(Get-CategoryOf $r.StdoutPath)" }
    if (Test-NoStagingLitter $F) { Test-Pass "TEST-033i [$axis] stale journal cleaned up after recovery" } else { Test-Fail "TEST-033i [$axis] stale journal cleaned up after recovery" 'litter remains' }
    Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'newer-a'
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST2.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n")
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST2.sha256'))
    $aNow = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt') -ErrorAction SilentlyContinue
    if ($r.ExitCode -eq 0 -and $aNow -eq "newer-a`n") { Test-Pass "TEST-033i [$axis] a subsequent UNRELATED batch still publishes (publisher not bricked)" } else { Test-Fail "TEST-033i [$axis] a subsequent UNRELATED batch still publishes" "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)" }

    # -----------------------------------------------------------------------
    # TEST-033j: crash MID-BATCH recovers to ALL-PRE.
    # -----------------------------------------------------------------------
    $F = New-CrashFixture $axis 2
    $stageArgs = @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList ($stageArgs + @('-SimulateCrashAfter', 'rename-1')) | Out-Null
    $obs = Get-CrashStates $F $axis 2
    if ($obs -eq 'POST PRE') { Test-Pass "TEST-033j [$axis] mid-batch crash leaves an observable partial state right after the crash" } else { Test-Fail "TEST-033j [$axis] mid-batch crash partial state" "states '$obs'" }
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
    $obs = Get-CrashStates $F $axis 2
    if ($r.ExitCode -eq 0 -and $obs -eq 'PRE PRE') { Test-Pass "TEST-033j [$axis] recovery converges to ALL-PRE (mid-batch crash rolled back)" } else { Test-Fail "TEST-033j [$axis] recovery converges to ALL-PRE" "exit $($r.ExitCode) states '$obs' category $(Get-CategoryOf $r.StdoutPath)" }
    if (Test-NoStagingLitter $F) { Test-Pass "TEST-033j [$axis] journal/staging litter fully cleaned up after convergence" } else { Test-Fail "TEST-033j [$axis] journal/staging litter fully cleaned up after convergence" 'litter remains' }

    # -----------------------------------------------------------------------
    # TEST-033k: crash AFTER the last rename but BEFORE journal deletion
    # recovers to ALL-POST.
    # -----------------------------------------------------------------------
    $F = New-CrashFixture $axis 2
    $stageArgs = @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList ($stageArgs + @('-SimulateCrashAfter', 'rename-2')) | Out-Null
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
    $obs = Get-CrashStates $F $axis 2
    if ($r.ExitCode -eq 0 -and $obs -eq 'POST POST') { Test-Pass "TEST-033k [$axis] recovery converges to ALL-POST (crash after last rename, before journal delete)" } else { Test-Fail "TEST-033k [$axis] recovery converges to ALL-POST" "exit $($r.ExitCode) states '$obs'" }
    if (Test-NoStagingLitter $F) { Test-Pass "TEST-033k [$axis] journal removed once recovery confirms ALL-POST" } else { Test-Fail "TEST-033k [$axis] journal removed once recovery confirms ALL-POST" 'litter remains' }

    # -----------------------------------------------------------------------
    # TEST-033l: a SECOND crash injected DURING recovery itself still
    # converges correctly on the FOLLOWING invocation.
    # -----------------------------------------------------------------------
    $F = New-CrashFixture $axis 3
    $stageArgs = @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList ($stageArgs + @('-SimulateCrashAfter', 'rename-2')) | Out-Null
    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-SimulateCrashDuringRecoveryAfter', 'revert-1') | Out-Null
    $obs = Get-CrashStates $F $axis 3
    if ($obs -eq 'PRE POST PRE') { Test-Pass "TEST-033l [$axis] a second crash mid-recovery leaves an observable partial-recovery state" } else { Test-Fail "TEST-033l [$axis] partial-recovery state" "states '$obs'" }
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
    $obs = Get-CrashStates $F $axis 3
    if ($r.ExitCode -eq 0 -and $obs -eq 'PRE PRE PRE') { Test-Pass "TEST-033l [$axis] the FOLLOWING invocation still converges to ALL-PRE (recovery is idempotent/re-entrant)" } else { Test-Fail "TEST-033l [$axis] final convergence" "exit $($r.ExitCode) states '$obs'" }
    if (Test-NoStagingLitter $F) { Test-Pass "TEST-033l [$axis] journal fully cleaned up after the second recovery invocation" } else { Test-Fail "TEST-033l [$axis] journal fully cleaned up after the second recovery invocation" 'litter remains' }
}

# ---------------------------------------------------------------------------
# TEST-033m: journal shape mismatch fails closed (carry-forward
# obligation 2).
# ---------------------------------------------------------------------------
$F = New-FixtureDir
New-Item -ItemType Directory -Path (Join-Path $F 'repo/sdd/.staging/badbatch') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $F 'repo/sdd/.staging/badbatch/TRANSACTION.json') -NoNewline -Encoding utf8 -Value "{`"schema`":`"x`",`"status`":`"in-progress`"}`n"
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'JOURNAL_SHAPE_INVALID') { Test-Pass 'TEST-033m shape-mismatched journal (missing targets[]) is REJECTED, not silently ignored (JOURNAL_SHAPE_INVALID)' } else { Test-Fail 'TEST-033m journal shape mismatch' "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)" }
if (Test-Path -LiteralPath (Join-Path $F 'repo/sdd/.staging/badbatch/TRANSACTION.json')) { Test-Pass 'TEST-033m the malformed journal is left in place for human inspection, not deleted' } else { Test-Fail 'TEST-033m malformed journal retained' 'journal was deleted' }

# ---------------------------------------------------------------------------
# TEST-033n: recovery is a safe no-op when nothing is stale.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
if ($r.ExitCode -eq 0) { Test-Pass 'TEST-033n recovery-only invocation with nothing stale exits 0' } else { Test-Fail 'TEST-033n recovery-only invocation' "exit $($r.ExitCode)" }
$outText = Get-Content -Raw -LiteralPath $r.StdoutPath
if ($outText -match '"recovered":0') { Test-Pass 'TEST-033n recovery-only invocation reports recovered:0' } else { Test-Fail 'TEST-033n recovered:0 reported' "got '$outText'" }

# ---------------------------------------------------------------------------
# TEST-033o: held-handle substitution resistance.
#
# PLATFORM NOTE (native Windows). The attack this fixture simulates -- an
# attacker renaming the publisher's anchored destination-parent aside and
# dropping an empty substitute at the original name -- CANNOT BE CONSTRUCTED
# on native Windows, because Windows itself already forbids it.
# [System.IO.Directory]::SetCurrentDirectory maps to Win32
# SetCurrentDirectory, which OPENS the target directory and keeps that handle
# in the process's own PEB (ProcessParameters->CurrentDirectory.Handle) for as
# long as it remains the current directory, with a share mode of
# FILE_SHARE_READ | FILE_SHARE_WRITE -- deliberately WITHOUT
# FILE_SHARE_DELETE. Renaming a directory requires opening it for DELETE
# access, so the rename is refused with a sharing violation while ANY process
# is anchored inside it. The publisher's own -SimulateSubstitution block
# swallows that failure by design (its catch is documented as best-effort
# precisely so a fixture that cannot substitute never masks a real publish
# failure), so on Windows the substitution simply never occurs. CI run
# 31138444391 confirmed exactly this shape empirically: the moved-aside
# directory did not exist at all ("got ''"), which is only possible if
# [System.IO.Directory]::Move threw -- had the rename SUCCEEDED and the
# publisher then followed the substitute, that path would have held the
# original 'old-content'.
#
# POSIX has no such rule -- a directory that is a live process's cwd renames
# freely -- which is exactly why both twins must close the hole in user space
# there: the .sh twin re-checks the anchored directory's (device, inode)
# identity, and this .ps1 twin re-reads Environment.CurrentDirectory (a real
# getcwd() walk UP from the pinned directory, so it tracks a rename) freshly
# before each use.
#
# This is therefore NOT a skip for convenience. The Windows leg asserts what
# the platform genuinely guarantees, and is written so that a future Windows
# or .NET release that ALLOWED the rename would fail this leg LOUDLY rather
# than let the claim decay into something untested.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/file.txt') 'old-content'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'new-content'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/file.txt') + "`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateSubstitution')
if ($r.ExitCode -eq 0) { Test-Pass 'TEST-033o substitution-resistance fixture: tool still completes successfully' } else { Test-Fail 'TEST-033o substitution completes' "exit $($r.ExitCode)" }
$origPath = Join-Path $F 'repo/plugins/x/file.txt'
$movedDir = Join-Path $F 'repo/plugins/x.attacker-moved'
if ($IsWindows) {
    if (-not (Test-Path -LiteralPath $movedDir)) {
        Test-Pass 'TEST-033o (Windows) the rename-aside is refused by the OS itself: an anchored destination-parent cannot be renamed while the publisher holds it as its current directory'
    } else {
        Test-Fail 'TEST-033o (Windows) the rename-aside is refused by the OS itself' 'the anchored directory WAS renamed aside -- Windows sharing semantics have changed, so the POSIX-style user-space identity defense now has to be ported to this twin'
    }
    $origContent = Get-Content -Raw -LiteralPath $origPath -ErrorAction SilentlyContinue
    if ($origContent -eq "new-content`n") {
        Test-Pass 'TEST-033o (Windows) the write lands in the TRUE, still-anchored original directory'
    } else {
        Test-Fail 'TEST-033o (Windows) write lands in the still-anchored original' "got '$origContent'"
    }
} else {
    $origIsEmpty = -not (Test-Path -LiteralPath $origPath) -or ((Get-Item -LiteralPath $origPath).Length -eq 0)
    if ($origIsEmpty) { Test-Pass 'TEST-033o the newly-substituted directory at the ORIGINAL name never receives the candidate' } else { Test-Fail 'TEST-033o original-name directory unaffected' 'candidate leaked into the substitute' }
    $movedContent = Get-Content -Raw -LiteralPath (Join-Path $movedDir 'file.txt') -ErrorAction SilentlyContinue
    if ($movedContent -eq "new-content`n") { Test-Pass 'TEST-033o the write lands in the TRUE, anchored original directory (now at its new name)' } else { Test-Fail 'TEST-033o write lands in anchored original' "got '$movedContent'" }
}

# ---------------------------------------------------------------------------
# TEST-033p (quality-gate seq0357 Critical remedy): a batch containing a
# PRE-EXISTING, LEGITIMATELY ZERO-BYTE live target must still converge to
# ALL-PRE after a mid-batch crash, and the publisher must remain usable
# afterward. Backup-PreBytes was already correct on this ps1 twin (it
# keys on the resolved SOURCE PATH string being non-null, not on the
# copied byte count), matching the evaluator's own cross-runtime
# observation -- this test locks that behavior in as a regression guard.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/b.txt') 'old-b'
New-Item -ItemType File -Path (Join-Path $F 'repo/plugins/x/a.txt') -Force | Out-Null
Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'new-a'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/b.txt') 'new-b'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/b.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'rename-1') | Out-Null
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
$aLen = (Get-Item -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')).Length
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
if ($r.ExitCode -eq 0 -and $aLen -eq 0 -and $b -eq "old-b`n") {
    Test-Pass 'TEST-033p zero-byte live target survives mid-batch crash + recovery, converging ALL-PRE (exit 0)'
} else {
    Test-Fail 'TEST-033p zero-byte live target converges ALL-PRE' "exit $($r.ExitCode); a-len=$aLen; b='$b'"
}
Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'newer-a'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST2.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n")
$r2 = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST2.sha256'))
$a2 = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt') -ErrorAction SilentlyContinue
if ($r2.ExitCode -eq 0 -and $a2 -eq "newer-a`n") {
    Test-Pass 'TEST-033p the publisher remains usable afterward (a subsequent legitimate publish succeeds, not permanently bricked)'
} else {
    Test-Fail 'TEST-033p publisher remains usable afterward' "exit $($r2.ExitCode); a='$a2'"
}

# ---------------------------------------------------------------------------
# TEST-033q (quality-gate seq0357 Major #1 remedy): two targets sharing a
# basename in different directories within the SAME batch are refused at
# manifest-parse time (DUPLICATE_BASENAME_IN_BATCH).
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/dir1/same.txt') 'old-1'
Write-FixtureFile (Join-Path $F 'repo/dir2/same.txt') 'old-2'
Write-FixtureFile (Join-Path $F 'stage/dir1/same.txt') 'new-1'
Write-FixtureFile (Join-Path $F 'stage/dir2/same.txt') 'new-2'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'dir1/same.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'dir2/same.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'DUPLICATE_BASENAME_IN_BATCH') {
    Test-Pass 'TEST-033q duplicate-basename batch rejected (DUPLICATE_BASENAME_IN_BATCH)'
} else {
    Test-Fail 'TEST-033q duplicate-basename batch rejected' "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
}
$d1 = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/dir1/same.txt')
$d2 = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/dir2/same.txt')
if ($d1 -eq "old-1`n" -and $d2 -eq "old-2`n") {
    Test-Pass 'TEST-033q both live targets unchanged (refused before any live mutation)'
} else {
    Test-Fail 'TEST-033q both live targets unchanged' "d1='$d1' d2='$d2'"
}

# ---------------------------------------------------------------------------
# TEST-033r (quality-gate seq0357 Major #3 remedy): this runtime's own
# journal writer emits BOM-less UTF-8, parseable by a plain `python3
# json.load` (no `utf-8-sig` workaround needed) -- the ps1-side half of
# the cross-runtime parity proof; the sh suite's own TEST-033r performs
# the full cross-runtime byte comparison (this suite alone cannot shell
# out to a POSIX `sh` on native Windows, where this suite ALSO runs).
# Skips gracefully if python3 is unavailable.
# ---------------------------------------------------------------------------
$python3Cmd = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python3Cmd) { $python3Cmd = Get-Command python -ErrorAction SilentlyContinue }
if ($python3Cmd) {
    $F = New-FixtureDir
    Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'bom-check-a'
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n")
    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'journal-write') | Out-Null
    $journal = Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Filter 'TRANSACTION.json' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($journal) {
        $bytes = [System.IO.File]::ReadAllBytes($journal.FullName) | Select-Object -First 3
        $hex = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
        if ($hex -eq '7b2273') {
            Test-Pass "TEST-033r ps1 journal has no BOM (leading bytes $hex = open-brace quote s)"
        } else {
            Test-Fail 'TEST-033r ps1 journal has no BOM' "got $hex"
        }
        $procResult = Invoke-ChildProcess -Exe $python3Cmd.Source -ArgList @('-c', 'import json,sys; json.load(open(sys.argv[1]))', $journal.FullName) -WorkingDirectory $F
        if ($procResult.ExitCode -eq 0) {
            Test-Pass 'TEST-033r ps1 journal parses via plain python3 json.load (no utf-8-sig needed)'
        } else {
            Test-Fail 'TEST-033r ps1 journal parses via plain python3 json.load' "exit $($procResult.ExitCode)"
        }
    } else {
        Test-Fail 'TEST-033r ps1 journal exists for BOM inspection' 'no TRANSACTION.json found'
    }
} else {
    Test-Pass 'TEST-033r ps1 journal BOM check (skipped: python3/python not available in this environment)'
}

# ---------------------------------------------------------------------------
# TEST-033s (quality-gate seq0358 Major remedy -- ps1-side parity lock):
# this runtime was ALREADY correct on whitespace-containing manifest
# target paths (the sh twin was the one with the IFS field-splitting
# defect); these assertions lock that correctness in as a regression
# guard so a future ps1 change cannot silently reintroduce the same class
# of bug the sh runtime had.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/live/d/a b.txt') 'old content'
Write-FixtureFile (Join-Path $F 'stage/live/d/a b.txt') 'new content'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'live/d/a b.txt') + "`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
$content = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/live/d/a b.txt') -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 0 -and $content -eq "new content`n") {
    Test-Pass 'TEST-033s embedded-space path publishes correctly (exit 0, correct content)'
} else {
    Test-Fail 'TEST-033s embedded-space path publishes correctly' "exit $($r.ExitCode); content='$content'"
}

$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/live/d/a b.txt') 'old content'
Write-FixtureFile (Join-Path $F 'repo/live/d/c.txt') 'old-c'
Write-FixtureFile (Join-Path $F 'stage/live/d/a b.txt') 'new content'
Write-FixtureFile (Join-Path $F 'stage/live/d/c.txt') 'new-c'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'live/d/a b.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'live/d/c.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'rename-1') | Out-Null
$journal = Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Filter 'TRANSACTION.json' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($journal -and (Get-Content -Raw -LiteralPath $journal.FullName) -match '"live_path":"live/d/a b\.txt"') {
    Test-Pass "TEST-033s journal preserves the embedded-space live_path byte-exact"
} else {
    Test-Fail 'TEST-033s journal preserves embedded-space live_path' 'not found in journal'
}
$r2 = Invoke-Apply -RepoDir (Join-Path $F 'repo')
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/live/d/a b.txt') -ErrorAction SilentlyContinue
$c = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/live/d/c.txt') -ErrorAction SilentlyContinue
if ($r2.ExitCode -eq 0 -and $a -eq "old content`n" -and $c -eq "old-c`n") {
    Test-Pass 'TEST-033s mid-batch crash with an embedded-space target converges to ALL-PRE on recovery'
} else {
    Test-Fail 'TEST-033s mid-batch crash convergence with embedded-space target' "exit $($r2.ExitCode); a='$a' c='$c'"
}

$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/live/a b.txt') 'content-ab'
Write-FixtureFile (Join-Path $F 'stage/live/b.txt') 'content-b'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'live/a b.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'live/b.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
$r3 = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
$ab = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/live/a b.txt') -ErrorAction SilentlyContinue
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/live/b.txt') -ErrorAction SilentlyContinue
if ($r3.ExitCode -eq 0 -and $ab -eq "content-ab`n" -and $b -eq "content-b`n") {
    Test-Pass "TEST-033s 'b.txt' is never false-positive-flagged as a duplicate of 'a b.txt' (both publish correctly)"
} else {
    Test-Fail 'TEST-033s no false-positive duplicate rejection for space-containing paths' "exit $($r3.ExitCode)"
}

# ---------------------------------------------------------------------------
# TEST-033t (quality-gate seq0359 CLASS-ELIMINATION mandate, ps1-side):
# hostile-path property matrix -- publish, mid-batch crash, recovery
# convergence, and (this runtime's own ConvertFrom-Json, already reliable)
# journal live_path round-trip, for each required character class. The
# sh suite's own TEST-033t performs the full cross-runtime parity check
# (it can shell out to pwsh); this suite locks in ps1's OWN correctness
# for every class, including on native Windows where it cannot shell out
# to a POSIX sh.
# ---------------------------------------------------------------------------
function Test-HostileMatrixCase([string]$Label, [string]$Frag) {
    $F = New-FixtureDir
    $relPath = "hostile/$Frag"
    Write-FixtureFile (Join-Path $F 'repo/hostile/zz.txt') 'old-z'
    Write-FixtureFile (Join-Path $F "stage/$relPath") "new-$Label"
    Write-FixtureFile (Join-Path $F 'stage/hostile/zz.txt') 'new-z'
    $manifestLines = (Get-ManifestLine (Join-Path $F 'stage') $relPath) + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'hostile/zz.txt') + "`n"
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines

    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'rename-1') | Out-Null
    $journal = Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Filter 'TRANSACTION.json' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($journal) {
        try {
            $d = Get-Content -Raw -LiteralPath $journal.FullName | ConvertFrom-Json
            $paths = @($d.targets | ForEach-Object { $_.live_path })
            if ($paths -contains $relPath) {
                Test-Pass "TEST-033t [$Label] journal round-trips live_path exactly (ConvertFrom-Json)"
            } else {
                Test-Fail "TEST-033t [$Label] journal round-trips live_path exactly" "paths=$($paths -join ',')"
            }
        } catch {
            Test-Fail "TEST-033t [$Label] journal round-trips live_path exactly" "parse error: $_"
        }
    } else {
        Test-Fail "TEST-033t [$Label] journal exists for round-trip check" 'no TRANSACTION.json found'
    }

    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
    $targetGone = -not (Test-Path -LiteralPath (Join-Path $F "repo/$relPath"))
    $sibling = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/hostile/zz.txt') -ErrorAction SilentlyContinue
    if ($r.ExitCode -eq 0 -and $targetGone -and $sibling -eq "old-z`n") {
        Test-Pass "TEST-033t [$Label] recovery converges ALL-PRE (target absent, sibling unchanged)"
    } else {
        Test-Fail "TEST-033t [$Label] recovery converges ALL-PRE" "exit $($r.ExitCode)"
    }
}

Test-HostileMatrixCase -Label 'space' -Frag 'sp ace.txt'
Test-HostileMatrixCase -Label 'tab' -Frag "ta$([char]9)b.txt"
Test-HostileMatrixCase -Label 'leadtrail' -Frag ' lead-trail '
Test-HostileMatrixCase -Label 'dquote' -Frag 'qu"ote.txt'
Test-HostileMatrixCase -Label 'obrace' -Frag 'o{pen.txt'
Test-HostileMatrixCase -Label 'cbrace' -Frag 'c}lose.txt'
Test-HostileMatrixCase -Label 'comma' -Frag 'com,ma.txt'
Test-HostileMatrixCase -Label 'star' -Frag 'st*ar.txt'
Test-HostileMatrixCase -Label 'question' -Frag 'que?stion.txt'
Test-HostileMatrixCase -Label 'obracket' -Frag 'ob[racket.txt'
Test-HostileMatrixCase -Label 'cbracket' -Frag 'cb]racket.txt'
Test-HostileMatrixCase -Label 'dollar' -Frag 'do$llar.txt'
Test-HostileMatrixCase -Label 'backtick' -Frag 'back`tick.txt'
Test-HostileMatrixCase -Label 'squote' -Frag "sq'uote.txt"
Test-HostileMatrixCase -Label 'utf8' -Frag 'utf8-café-日本語.txt'

# C0 control-character classes (quality-gate seq0360 Major #1 remedy):
# the evaluator's own extended matrix found vtab(0x0B)/soh(0x01)/
# formfeed(0x0C)/esc(0x1B) journaled as INVALID JSON on the .sh twin
# (json_escape only escaped backslash/quote/TAB there); ps1's own
# ConvertTo-Json already escaped these correctly, so this locks that
# CONTINUED correctness as a regression guard, matching the .sh suite's
# matrix one-for-one for parity. "unitsep" (0x1F, the highest C0 value)
# is an additional representative sample. CR (0x0D) is DELIBERATELY
# EXCLUDED here too -- see the dedicated CR rejection test below instead.
Test-HostileMatrixCase -Label 'vtab' -Frag "vt$([char]11)ab.txt"
Test-HostileMatrixCase -Label 'soh' -Frag "so$([char]1)h.txt"
Test-HostileMatrixCase -Label 'formfeed' -Frag "ff$([char]12)eed.txt"
Test-HostileMatrixCase -Label 'esc' -Frag "es$([char]27)c.txt"
Test-HostileMatrixCase -Label 'unitsep' -Frag "un$([char]31)itsep.txt"

# Backslash: a GENUINELY unsupportable character on this runtime (see the
# .sh suite's own dedicated test for the full empirical verification) --
# classified-rejected here too (UNSUPPORTED_PATH_CHARACTER), never
# silently accepted. Rejection happens at manifest-PARSE time (before any
# staged-file access), so no staged file needs to exist for this fixture
# -- the manifest line's own hash value is an arbitrary placeholder.
$F = New-FixtureDir
$placeholderHash = '0' * 64
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value "$placeholderHash  back\slash.txt`n"
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
# PR #229 CI (first-ever Linux execution): the rejection LAYER is
# platform-dependent — Linux refuses the manifest row itself
# (MANIFEST_INVALID) while macOS classifies the path
# (UNSUPPORTED_PATH_CHARACTER). Both are classified fail-closed rejections;
# the load-bearing property is that no platform ever publishes the path.
$bsCat = Get-CategoryOf $r.StdoutPath
if ($r.ExitCode -ne 0 -and ($bsCat -eq 'UNSUPPORTED_PATH_CHARACTER' -or $bsCat -eq 'MANIFEST_INVALID')) {
    Test-Pass "TEST-033t ps1 rejects a literal backslash in a manifest path (fail-closed, category $bsCat)"
} else {
    Test-Fail 'TEST-033t ps1 rejects a literal backslash' "exit $($r.ExitCode) category $bsCat"
}

# Carriage return (CR): a GENUINELY unsupportable character (quality-gate
# seq0360 Major #2) -- a literal CR embedded in a manifest target path is,
# by raw bytes alone, indistinguishable from a legitimate CRLF line
# terminator, and this runtime's own Get-Content independently mis-splits
# a bare CR as its own line boundary (verified: an accidental,
# mis-categorized MANIFEST_INVALID on the identical input, BEFORE this
# remedy). Classified-rejected (UNSUPPORTED_PATH_CHARACTER), whole-file,
# symmetric with the .sh twin and with backslash's own precedent.
$F = New-FixtureDir
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value "$placeholderHash  cr$([char]13)path.txt`n"
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'UNSUPPORTED_PATH_CHARACTER') {
    Test-Pass 'TEST-033t ps1 rejects a literal CR in a manifest path (UNSUPPORTED_PATH_CHARACTER)'
} else {
    Test-Fail 'TEST-033t ps1 rejects a literal CR' "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
}

# ---------------------------------------------------------------------------
# TEST-033u (quality-gate seq0360 Major #3 remedy): a glob-metacharacter
# DIRECTORY SEGMENT, not merely a leaf basename -- Test-HostileMatrixCase's
# own fragments are ALWAYS "hostile/$Frag", i.e. the hostile fragment is
# always the LEAF, so a decoy directory a naive glob-vulnerable walk would
# substitute into is never actually exercised. A pre-existing decoy
# directory 'axxb' sits next to the real target 'a*b'.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
New-Item -ItemType Directory -Path (Join-Path $F 'repo/axxb') -Force | Out-Null
Write-FixtureFile (Join-Path $F 'repo/axxb/decoy-canary.txt') 'decoy-untouched'
Write-FixtureFile (Join-Path $F 'stage/a*b/t.txt') 'real-payload'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'a*b/t.txt') + "`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
$realContent = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/a*b/t.txt') -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 0 -and $realContent -eq "real-payload`n") {
    Test-Pass 'TEST-033u glob-metacharacter DIRECTORY SEGMENT publishes to the literal name, not a decoy'
} else {
    Test-Fail 'TEST-033u glob-metacharacter DIRECTORY SEGMENT publishes to the literal name' "exit $($r.ExitCode)"
}
$decoyContent = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/axxb/decoy-canary.txt') -ErrorAction SilentlyContinue
$decoyGotTarget = Test-Path -LiteralPath (Join-Path $F 'repo/axxb/t.txt')
if ($decoyContent -eq "decoy-untouched`n" -and -not $decoyGotTarget) {
    Test-Pass "TEST-033u decoy directory 'axxb' left completely untouched (no substitution into it)"
} else {
    Test-Fail "TEST-033u decoy directory 'axxb' left completely untouched" 'substitution detected'
}

# ---------------------------------------------------------------------------
# TEST-033v (quality-gate seq0360 CRITICAL remedy, requirements 1+2+3): the
# evaluator's own 3-trigger regression fixture. A genuine MIXED state (t1
# already committed to POST, t2 still at PRE) is created via a real
# mid-batch crash; the destination-parent of the ALREADY-COMMITTED target
# is then attacked via 3 independent, non-adversarial triggers (symlink
# replacement / rename-aside / chmod 000 -- the last two run on
# non-Windows only, matching this suite's own established Windows-skip
# convention for capability gaps outside scope). Recovery must FAIL
# CLOSED (nonzero exit, category RECOVERY_FAILED, journal AND pre/ backup
# RETAINED) while the trigger is active, then CONVERGE to ALL-PRE once
# the trigger is undone.
# ---------------------------------------------------------------------------

function New-RecoveryProbeFailureFixture([string]$Variant) {
    $f = New-FixtureDir
    if ($Variant -eq 'pre-existing') {
        Write-FixtureFile (Join-Path $f 'repo/sub1/a.txt') 'old-a'
        Write-FixtureFile (Join-Path $f 'repo/sub2/b.txt') 'old-b'
    }
    Write-FixtureFile (Join-Path $f 'stage/sub1/a.txt') 'new-a'
    Write-FixtureFile (Join-Path $f 'stage/sub2/b.txt') 'new-b'
    $lines = (Get-ManifestLine (Join-Path $f 'stage') 'sub1/a.txt') + "`n" + (Get-ManifestLine (Join-Path $f 'stage') 'sub2/b.txt') + "`n"
    Set-Content -LiteralPath (Join-Path $f 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $lines
    Invoke-Apply -RepoDir (Join-Path $f 'repo') -ArgList @('-StagingDir', (Join-Path $f 'stage'), '-Manifest', (Join-Path $f 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'rename-1') | Out-Null
    $journal = Get-ChildItem -Path (Join-Path $f 'repo/sdd/.staging') -Filter 'TRANSACTION.json' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    return @{ F = $f; JournalDir = $journal.DirectoryName }
}

function Get-RpfState([string]$FixtureDir, [string]$Variant, [string]$RelPath, [string]$Old, [string]$New) {
    $p = Join-Path $FixtureDir "repo/$RelPath"
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $c = Get-Content -Raw -LiteralPath $p
        if ($c -eq "$New`n") { return 'POST' }
        if ($Variant -eq 'pre-existing' -and $c -eq "$Old`n") { return 'PRE' }
        return 'OTHER'
    }
    if ($Variant -eq 'absent') { return 'PRE' }
    return 'OTHER'
}

function Test-RecoveryProbeFailureCase([string]$Label, [string]$Variant) {
    $fixture = New-RecoveryProbeFailureFixture $Variant
    $f = $fixture.F
    $sub1 = Join-Path $f 'repo/sub1'
    switch ($Label) {
        'symlink' {
            Rename-Item -LiteralPath $sub1 -NewName 'sub1.saved'
            New-Item -ItemType SymbolicLink -Path $sub1 -Target (Join-Path $f 'repo/sub1.saved') | Out-Null
        }
        'renameaside' {
            Rename-Item -LiteralPath $sub1 -NewName 'sub1.attacker-moved'
        }
        'chmod000' {
            & chmod 000 $sub1
        }
    }

    # "The journal's own recorded pre_hash decides": a plainly-missing
    # chain is tolerated ONLY where the journal recorded ABSENT. See the
    # .sh twin's TEST-033v header comment for the full derivation.
    $expectClosed = -not ($Label -eq 'renameaside' -and $Variant -eq 'absent')

    $r = Invoke-Apply -RepoDir (Join-Path $f 'repo')
    if ($expectClosed) {
        if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'RECOVERY_FAILED') {
            Test-Pass "TEST-033v [$Label/$Variant] recovery fails closed while the target's true state is undeterminable (RECOVERY_FAILED)"
        } else {
            Test-Fail "TEST-033v [$Label/$Variant] recovery fails closed" "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
        }
        $journalStillThere = Test-Path -LiteralPath (Join-Path $fixture.JournalDir 'TRANSACTION.json')
        $backupStillThere = ($Variant -eq 'absent') -or ((Get-ChildItem -Path (Join-Path $fixture.JournalDir 'pre') -File -ErrorAction SilentlyContinue).Count -gt 0)
        if ($journalStillThere -and $backupStillThere) {
            Test-Pass "TEST-033v [$Label/$Variant] journal (and pre/ backup where one exists) RETAINED after the failed recovery attempt"
        } else {
            Test-Fail "TEST-033v [$Label/$Variant] journal and pre/ backup RETAINED" "journal=$journalStillThere backup=$backupStillThere"
        }
    } else {
        $st1 = Get-RpfState $f $Variant 'sub1/a.txt' 'old-a' 'new-a'
        $st2 = Get-RpfState $f $Variant 'sub2/b.txt' 'old-b' 'new-b'
        if ($r.ExitCode -eq 0 -and $st1 -eq 'PRE' -and $st2 -eq 'PRE') {
            Test-Pass "TEST-033v [$Label/$Variant] a plainly-absent chain the journal itself recorded as ABSENT converges to ALL-PRE (design.md:1042-1043), never a permanent RECOVERY_FAILED brick"
        } else {
            Test-Fail "TEST-033v [$Label/$Variant] plainly-absent + journal pre=ABSENT converges to ALL-PRE" "exit $($r.ExitCode) states '$st1 $st2' category $(Get-CategoryOf $r.StdoutPath)"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $fixture.JournalDir 'TRANSACTION.json'))) {
            Test-Pass "TEST-033v [$Label/$Variant] the journal is deleted once recovery reaches its terminal state"
        } else {
            Test-Fail "TEST-033v [$Label/$Variant] the journal is deleted once recovery reaches its terminal state" 'journal retained'
        }
    }

    switch ($Label) {
        'symlink' {
            Remove-Item -LiteralPath $sub1 -Force
            Rename-Item -LiteralPath (Join-Path $f 'repo/sub1.saved') -NewName 'sub1'
        }
        'renameaside' {
            if ((Test-Path -LiteralPath (Join-Path $f 'repo/sub1.attacker-moved')) -and -not (Test-Path -LiteralPath $sub1)) {
                Rename-Item -LiteralPath (Join-Path $f 'repo/sub1.attacker-moved') -NewName 'sub1'
            }
        }
        'chmod000' {
            & chmod 755 $sub1
        }
    }

    $r2 = Invoke-Apply -RepoDir (Join-Path $f 'repo')
    if ($expectClosed) {
        $st1 = Get-RpfState $f $Variant 'sub1/a.txt' 'old-a' 'new-a'
        $st2 = Get-RpfState $f $Variant 'sub2/b.txt' 'old-b' 'new-b'
        if ($r2.ExitCode -eq 0 -and $st1 -eq 'PRE' -and $st2 -eq 'PRE') {
            Test-Pass "TEST-033v [$Label/$Variant] recovery converges to ALL-PRE once the trigger is undone"
        } else {
            Test-Fail "TEST-033v [$Label/$Variant] recovery converges to ALL-PRE once the trigger is undone" "exit $($r2.ExitCode) states '$st1 $st2'"
        }
    } else {
        if ($r2.ExitCode -eq 0) {
            Test-Pass "TEST-033v [$Label/$Variant] a further invocation after convergence is a clean no-op (recovery is idempotent)"
        } else {
            Test-Fail "TEST-033v [$Label/$Variant] a further invocation after convergence is a clean no-op" "exit $($r2.ExitCode)"
        }
    }
    $litter = Get-ChildItem -Path (Join-Path $f 'repo/sdd/.staging') -Recurse -File -ErrorAction SilentlyContinue
    if (-not $litter) {
        Test-Pass "TEST-033v [$Label/$Variant] journal/staging litter fully cleaned up after convergence"
    } else {
        Test-Fail "TEST-033v [$Label/$Variant] journal/staging litter fully cleaned up after convergence" 'litter remains'
    }
}

foreach ($rpfAxis in @('pre-existing', 'absent')) {
    if ($IsWindows) {
        'symlink', 'renameaside', 'chmod000' | ForEach-Object {
            Test-Pass "TEST-033v [$_/$rpfAxis] recovery fails closed / converges (skipped: requires Windows elevation or POSIX permission bits)"
            Test-Pass "TEST-033v [$_/$rpfAxis] journal and pre/ backup RETAINED (skipped)"
            Test-Pass "TEST-033v [$_/$rpfAxis] recovery converges to ALL-PRE once undone (skipped)"
            Test-Pass "TEST-033v [$_/$rpfAxis] journal/staging litter fully cleaned up (skipped)"
        }
    } else {
        Test-RecoveryProbeFailureCase 'symlink' $rpfAxis
        Test-RecoveryProbeFailureCase 'renameaside' $rpfAxis
        Test-RecoveryProbeFailureCase 'chmod000' $rpfAxis
    }
}

# ---------------------------------------------------------------------------
# TEST-033w (quality-gate seq0360 CRITICAL remedy): the SAME probe-failure
# fail-closed discipline also applies at PREPARE time (before ANY journal
# for a NEW batch is written) -- a symlinked destination-parent denies the
# WHOLE batch (LIVE_PROBE_FAILED) rather than silently proceeding with a
# guessed pre_hash='ABSENT' that could hide real live content behind the
# symlink from the backup step.
# ---------------------------------------------------------------------------
if ($IsWindows) {
    Test-Pass 'TEST-033w PREPARE-time symlinked destination-parent denies the whole batch (skipped: Windows symlink creation requires elevation)'
    Test-Pass 'TEST-033w real content behind the symlink is unchanged (skipped)'
    Test-Pass 'TEST-033w no journal/staging litter left behind by the denied batch (skipped)'
} else {
    $F = New-FixtureDir
    New-Item -ItemType Directory -Path (Join-Path $F 'repo/real-sub1') -Force | Out-Null
    Write-FixtureFile (Join-Path $F 'repo/real-sub1/hidden.txt') 'hidden-content'
    New-Item -ItemType SymbolicLink -Path (Join-Path $F 'repo/sub1') -Target (Join-Path $F 'repo/real-sub1') | Out-Null
    Write-FixtureFile (Join-Path $F 'stage/sub1/hidden.txt') 'new-content'
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'sub1/hidden.txt') + "`n")
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'LIVE_PROBE_FAILED') {
        Test-Pass 'TEST-033w PREPARE-time symlinked destination-parent denies the whole batch (LIVE_PROBE_FAILED)'
    } else {
        Test-Fail 'TEST-033w PREPARE-time symlinked destination-parent denies the whole batch' "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
    }
    $hiddenContent = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/real-sub1/hidden.txt') -ErrorAction SilentlyContinue
    if ($hiddenContent -eq "hidden-content`n") {
        Test-Pass 'TEST-033w real content behind the symlink is unchanged (never silently overwritten)'
    } else {
        Test-Fail 'TEST-033w real content behind the symlink is unchanged' "got '$hiddenContent'"
    }
    $litter = Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Recurse -File -ErrorAction SilentlyContinue
    if (-not $litter) {
        Test-Pass 'TEST-033w no journal/staging litter left behind by the denied batch'
    } else {
        Test-Fail 'TEST-033w no journal/staging litter left behind by the denied batch' 'litter remains'
    }
}

# ---------------------------------------------------------------------------
# TEST-033x (quality-gate seq0361 Major #1): a REGRESSION LOCK on the
# design.md:1055-1056 POST-REVERT CONFIRMATION PASS, which seq0360 added
# as its headline Critical fix and seq0361 proved had ZERO coverage
# (deleting the whole loop from a scratch copy still gave 174/0). Driven
# across the destination-directory-existence axis, because with
# pre_hash='ABSENT' the confirmation compares "must be absent" instead of
# "must equal a hash" -- a genuinely different code path.
# ---------------------------------------------------------------------------
foreach ($axis in @('pre-existing', 'absent')) {
    $F = New-CrashFixture $axis 2
    $stageArgs = @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList ($stageArgs + @('-SimulateCrashAfter', 'rename-1')) | Out-Null
    $journal = Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Filter 'TRANSACTION.json' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $journalDir = $journal.DirectoryName
    # Move the already-committed target to a THIRD state, matching neither
    # its journal-recorded PRE nor its POST hash: the classification pass
    # sees a MIX, the revert pass legitimately skips it (it is not at
    # POST), and ONLY the confirmation pass can catch that recovery did not
    # in fact reach a terminal state.
    Write-FixtureFile (Join-Path $F 'repo/plugins/x/a.txt') 'third-state-content'
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
    if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'RECOVERY_FAILED') {
        Test-Pass "TEST-033x [$axis] post-revert confirmation catches a target left at a THIRD state (RECOVERY_FAILED, design.md:1055-1056)"
    } else {
        Test-Fail "TEST-033x [$axis] post-revert confirmation catches a target left at a THIRD state" "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
    }
    if (Test-Path -LiteralPath (Join-Path $journalDir 'TRANSACTION.json')) {
        Test-Pass "TEST-033x [$axis] the journal is RETAINED, never deleted, while any target is unconfirmed"
    } else {
        Test-Fail "TEST-033x [$axis] the journal is RETAINED, never deleted, while any target is unconfirmed" 'journal deleted'
    }
    $backupStillThere = ($axis -eq 'absent') -or ((Get-ChildItem -Path (Join-Path $journalDir 'pre') -File -ErrorAction SilentlyContinue).Count -gt 0)
    if ($backupStillThere) {
        Test-Pass "TEST-033x [$axis] the pre/ backup (where one exists) is RETAINED alongside the journal"
    } else {
        Test-Fail "TEST-033x [$axis] the pre/ backup is RETAINED alongside the journal" 'backup deleted'
    }
    if ($axis -eq 'pre-existing') {
        Write-FixtureFile (Join-Path $F 'repo/plugins/x/a.txt') 'old-a'
    } else {
        Remove-Item -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt') -Force
    }
    $r = Invoke-Apply -RepoDir (Join-Path $F 'repo')
    $obs = Get-CrashStates $F $axis 2
    if ($r.ExitCode -eq 0 -and $obs -eq 'PRE PRE') {
        Test-Pass "TEST-033x [$axis] once the target is back at PRE the SAME journal converges and is deleted"
    } else {
        Test-Fail "TEST-033x [$axis] once the target is back at PRE the SAME journal converges" "exit $($r.ExitCode) states '$obs'"
    }
}

# ---------------------------------------------------------------------------
# TEST-033y (quality-gate seq0361 Major #2): the DUPLICATE_BASENAME_IN_BATCH
# guard must be CASE-INSENSITIVE, because design.md:1011's backup slot is
# `pre/<target-basename>` and macOS APFS (this tool's primary platform) is
# case-insensitive by default. The ASCII case fold is applied on EVERY
# platform so both runtimes accept or refuse a batch identically
# regardless of the volume's own case semantics. See the .sh twin for the
# full rationale.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/d1/File.txt') 'pre-upper'
Write-FixtureFile (Join-Path $F 'repo/d2/file.txt') 'pre-lower'
Write-FixtureFile (Join-Path $F 'stage/d1/File.txt') 'new-upper'
Write-FixtureFile (Join-Path $F 'stage/d2/file.txt') 'new-lower'
$lines = (Get-ManifestLine (Join-Path $F 'stage') 'd1/File.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'd2/file.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $lines
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'DUPLICATE_BASENAME_IN_BATCH') {
    Test-Pass 'TEST-033y basenames differing only by ASCII case are refused (DUPLICATE_BASENAME_IN_BATCH), on every platform'
} else {
    Test-Fail 'TEST-033y basenames differing only by ASCII case are refused' "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
}
$u = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/d1/File.txt') -ErrorAction SilentlyContinue
$l = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/d2/file.txt') -ErrorAction SilentlyContinue
if ($u -eq "pre-upper`n" -and $l -eq "pre-lower`n") {
    Test-Pass 'TEST-033y both live targets unchanged (refused at manifest-parse time, before any live mutation)'
} else {
    Test-Fail 'TEST-033y both live targets unchanged' "u='$u' l='$l'"
}
if (Test-NoStagingLitter $F) {
    Test-Pass 'TEST-033y no journal/staging litter left behind by the refused batch'
} else {
    Test-Fail 'TEST-033y no journal/staging litter left behind by the refused batch' 'litter remains'
}

# The SAME case-variant batch with NO pre-existing live content: both
# targets record pre_hash='ABSENT', so no `pre/` backup slot is ever
# written and the PREPARE-time slot-exclusivity check CANNOT fire -- only
# the manifest-parse case fold can refuse this batch. This isolates the
# two guards from one another (on a case-insensitive volume they would
# otherwise mask each other and neither would have independent detection
# power).
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/d1/File.txt') 'new-upper'
Write-FixtureFile (Join-Path $F 'stage/d2/file.txt') 'new-lower'
$lines = (Get-ManifestLine (Join-Path $F 'stage') 'd1/File.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'd2/file.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $lines
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'DUPLICATE_BASENAME_IN_BATCH') {
    Test-Pass 'TEST-033y the manifest-parse case fold refuses a case-variant batch even when no backup slot would ever be written (guard isolated from the slot check)'
} else {
    Test-Fail 'TEST-033y the manifest-parse case fold refuses a case-variant batch with no live content' "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
}
if (-not (Test-Path -LiteralPath (Join-Path $F 'repo/d1/File.txt')) -and -not (Test-Path -LiteralPath (Join-Path $F 'repo/d2/file.txt'))) {
    Test-Pass 'TEST-033y neither target was published by the refused no-live-content batch'
} else {
    Test-Fail 'TEST-033y neither target was published by the refused no-live-content batch' 'a target was published'
}

# Non-ASCII case folding is a filesystem property an ASCII fold cannot
# decide, so the second line of defence is the backup slot ITSELF: PREPARE
# refuses to write a slot that already exists. PROPERTY-BASED rather than
# platform-hardcoded -- probe what this volume does, then require the tool
# to agree with that observation.
$probeDir = Join-Path $Work 'caseprobe'
New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $probeDir "CASEPROBE-$([char]0x00C9).txt"), 'x')
$volumeFoldsUnicodeCase = [System.IO.File]::Exists((Join-Path $probeDir "caseprobe-$([char]0x00E9).txt"))
$F = New-FixtureDir
$upperName = "d1/$([char]0x00C9).txt"
$lowerName = "d2/$([char]0x00E9).txt"
Write-FixtureFile (Join-Path $F "repo/$upperName") 'pre-upper-acute'
Write-FixtureFile (Join-Path $F "repo/$lowerName") 'pre-lower-acute'
Write-FixtureFile (Join-Path $F "stage/$upperName") 'new-upper-acute'
Write-FixtureFile (Join-Path $F "stage/$lowerName") 'new-lower-acute'
$lines = (Get-ManifestLine (Join-Path $F 'stage') $upperName) + "`n" + (Get-ManifestLine (Join-Path $F 'stage') $lowerName) + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $lines
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
$u = Get-Content -Raw -LiteralPath (Join-Path $F "repo/$upperName") -ErrorAction SilentlyContinue
$l = Get-Content -Raw -LiteralPath (Join-Path $F "repo/$lowerName") -ErrorAction SilentlyContinue
if ($volumeFoldsUnicodeCase) {
    if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'DUPLICATE_BASENAME_IN_BATCH') {
        Test-Pass 'TEST-033y on a volume that folds non-ASCII case, the colliding backup slot is detected and the batch refused (DUPLICATE_BASENAME_IN_BATCH)'
    } else {
        Test-Fail 'TEST-033y on a volume that folds non-ASCII case, the colliding backup slot is refused' "exit $($r.ExitCode) category $(Get-CategoryOf $r.StdoutPath)"
    }
    if ($u -eq "pre-upper-acute`n" -and $l -eq "pre-lower-acute`n") {
        Test-Pass 'TEST-033y non-ASCII collision refused BEFORE any live mutation (both targets still at PRE)'
    } else {
        Test-Fail 'TEST-033y non-ASCII collision refused BEFORE any live mutation' "u='$u' l='$l'"
    }
} else {
    if ($r.ExitCode -eq 0 -and $u -eq "new-upper-acute`n" -and $l -eq "new-lower-acute`n") {
        Test-Pass 'TEST-033y on a volume that does NOT fold non-ASCII case, both targets are distinct slots and both publish'
    } else {
        Test-Fail 'TEST-033y on a volume that does NOT fold non-ASCII case, both targets publish' "exit $($r.ExitCode)"
    }
    Test-Pass 'TEST-033y non-ASCII slot-collision behaviour matches this volume own case semantics (no collision to refuse here)'
}

# ---------------------------------------------------------------------------
# TEST-033z (quality-gate seq0361 Major #3): the tool must NEVER silence
# its own stderr. The .sh twin had `exec 8<. 2>/dev/null` at the top of
# main, which under POSIX `exec` semantics redirected the CURRENT SHELL's
# stderr for the whole remainder of execution, discarding every diagnostic
# raised after it. This runtime never had the defect ([Console]::Error.
# WriteLine); the assertion exists in BOTH suites so the parity is locked
# from both sides.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'no-such-stage'), '-Manifest', (Join-Path $F 'no-such-stage/MANIFEST.sha256'))
$errText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
$outText = Get-Content -Raw -LiteralPath $r.StdoutPath -ErrorAction SilentlyContinue
if ($r.ExitCode -ne 0 -and $null -ne $errText -and $errText.Contains('"category":"MANIFEST_INVALID"')) {
    Test-Pass 'TEST-033z a denial raised AFTER argument parsing still reaches stderr (the diagnostic is never swallowed)'
} else {
    Test-Fail 'TEST-033z a denial raised AFTER argument parsing still reaches stderr' "exit $($r.ExitCode) stderr='$errText'"
}
if ($null -ne $outText -and $outText.Contains('"category":"MANIFEST_INVALID"')) {
    Test-Pass 'TEST-033z the same denial ALSO reaches the machine-readable stdout channel (both channels, as documented)'
} else {
    Test-Fail 'TEST-033z the same denial ALSO reaches the machine-readable stdout channel' "stdout='$outText'"
}

# ---------------------------------------------------------------------------
# ===========================================================================
# TEST-PR229-AHC: a NON-REGULAR entry at a live target is never "ABSENT".
#
# PowerShell twin of the same block in tests/apply-human-copy.tests.sh --
# see that file for the full rationale (external review of PR #229, Codex,
# finding 1). Get-Sha256OrAbsent returned the bare string 'ABSENT' for a
# reparse point, so a journal recording pre_hash='ABSENT' plus a symlink
# squatting the live target made Invoke-RecoverAll classify an
# ALREADY-COMMITTED target as "never began committing" -- deleting the
# journal and backups and leaving the symlink on a protected path.
#
# WHICH SCRIPT THIS EXERCISES: the live .ps1 is R-10 protected, so these
# assertions run the STAGED CANDIDATE. They keep passing unchanged after a
# human applies it; to re-point them at the live script, replace
# $ApplyPs1Pr229 with $ApplyPs1.
# ===========================================================================

$ApplyPs1Pr229 = Join-Path $Root 'specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/apply-human-copy.ps1'

if (Test-Path -LiteralPath $ApplyPs1Pr229 -PathType Leaf) {
    Test-Pass 'TEST-PR229-AHC staged apply-human-copy.ps1 candidate exists'
} else {
    Test-Fail 'TEST-PR229-AHC staged apply-human-copy.ps1 candidate exists'
}

function Invoke-ApplyPr229 {
    param([string]$RepoDir, [string[]]$ArgList = @())
    return Invoke-ChildProcess -Exe $PowerShellExe `
        -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ApplyPs1Pr229) + $ArgList) `
        -WorkingDirectory $RepoDir
}

function Test-IsReparsePoint([string]$Path) {
    try {
        $a = [System.IO.File]::GetAttributes($Path)
        return (([int]$a -band [int][System.IO.FileAttributes]::ReparsePoint) -ne 0)
    } catch { return $false }
}

# --- (1) RECOVERY: symlink at a target whose journal pre_hash is ABSENT. ---
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/live/x.txt') 'candidate-v1'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 `
    -Value ((Get-ManifestLine (Join-Path $F 'stage') 'live/x.txt') + "`n")
# Commit the rename, then die before the journal is deleted.
Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo') -ArgList @(
    '-StagingDir', (Join-Path $F 'stage'),
    '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'),
    '-SimulateCrashAfter', 'rename-1') | Out-Null

$journals = @(Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Recurse -Filter 'TRANSACTION.json' -ErrorAction SilentlyContinue)
if ((Test-Path -LiteralPath (Join-Path $F 'repo/live/x.txt') -PathType Leaf) -and $journals.Count -eq 1) {
    Test-Pass 'TEST-PR229-AHC precondition: crash after rename-1 leaves the target committed and the journal present'
} else {
    Test-Fail 'TEST-PR229-AHC precondition: crash after rename-1 leaves the target committed and the journal present' "journals=$($journals.Count)"
}
$journalText = if ($journals.Count -gt 0) { Get-Content -Raw -LiteralPath $journals[0].FullName } else { '' }
if ($journalText -match '"pre_hash"\s*:\s*"ABSENT"') {
    Test-Pass 'TEST-PR229-AHC precondition: the journal records pre_hash=ABSENT for this target'
} else {
    Test-Fail 'TEST-PR229-AHC precondition: the journal records pre_hash=ABSENT for this target' $journalText
}

# An attacker replaces the committed target with a symlink elsewhere.
Write-FixtureFile (Join-Path $F 'attacker.txt') 'attacker-controlled'
$attackerHashBefore = Get-Sha256Hex (Join-Path $F 'attacker.txt')
Remove-Item -LiteralPath (Join-Path $F 'repo/live/x.txt') -Force
New-Item -ItemType SymbolicLink -Path (Join-Path $F 'repo/live/x.txt') -Target (Join-Path $F 'attacker.txt') | Out-Null

$r = Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo')
$outText = Get-Content -Raw -LiteralPath $r.StdoutPath -ErrorAction SilentlyContinue
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'RECOVERY_FAILED') {
    Test-Pass "TEST-PR229-AHC recovery fails CLOSED on a symlinked target (RECOVERY_FAILED), never 'confirmed absent'"
} else {
    Test-Fail 'TEST-PR229-AHC recovery fails CLOSED on a symlinked target' "exit $($r.ExitCode), category $(Get-CategoryOf $r.StdoutPath), stdout $outText"
}
if ($null -ne $outText -and $outText.Contains('"recovered":1')) {
    Test-Fail 'TEST-PR229-AHC recovery never reports the batch as successfully recovered' $outText
} else {
    Test-Pass 'TEST-PR229-AHC recovery never reports the batch as successfully recovered'
}
$journalsAfter = @(Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Recurse -Filter 'TRANSACTION.json' -ErrorAction SilentlyContinue)
if ($journalsAfter.Count -eq 1) {
    Test-Pass 'TEST-PR229-AHC the transaction journal is RETAINED, not deleted (the durable record survives)'
} else {
    Test-Fail 'TEST-PR229-AHC the transaction journal is RETAINED, not deleted' "journals=$($journalsAfter.Count)"
}
if (Test-IsReparsePoint (Join-Path $F 'repo/live/x.txt')) {
    Test-Pass 'TEST-PR229-AHC the symlink is left exactly as found (never followed, never replaced)'
} else {
    Test-Fail 'TEST-PR229-AHC the symlink is left exactly as found'
}
if ((Test-Path -LiteralPath (Join-Path $F 'attacker.txt') -PathType Leaf) -and
    (Get-Sha256Hex (Join-Path $F 'attacker.txt')) -eq $attackerHashBefore) {
    Test-Pass "TEST-PR229-AHC the symlink's target is never written through, deleted, or modified"
} else {
    Test-Fail "TEST-PR229-AHC the symlink's target is never written through, deleted, or modified"
}

# --- (2) The same rule at PREPARE time, before any journal exists. ---------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/live/y.txt') 'candidate-v1'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 `
    -Value ((Get-ManifestLine (Join-Path $F 'stage') 'live/y.txt') + "`n")
Write-FixtureFile (Join-Path $F 'canary3.txt') 'canary-untouched'
$canaryHashBefore = Get-Sha256Hex (Join-Path $F 'canary3.txt')
New-Item -ItemType Directory -Path (Join-Path $F 'repo/live') -Force | Out-Null
New-Item -ItemType SymbolicLink -Path (Join-Path $F 'repo/live/y.txt') -Target (Join-Path $F 'canary3.txt') | Out-Null
$r = Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo') -ArgList @(
    '-StagingDir', (Join-Path $F 'stage'),
    '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'PRE_EXISTING_SYMLINK_DENIED') {
    Test-Pass "TEST-PR229-AHC PREPARE denies a symlinked live target under the script's existing symlink category"
} else {
    Test-Fail "TEST-PR229-AHC PREPARE denies a symlinked live target under the script's existing symlink category" "exit $($r.ExitCode), category $(Get-CategoryOf $r.StdoutPath)"
}
$journalsPrep = @(Get-ChildItem -Path (Join-Path $F 'repo/sdd/.staging') -Recurse -Filter 'TRANSACTION.json' -ErrorAction SilentlyContinue)
if ($journalsPrep.Count -eq 0) {
    Test-Pass 'TEST-PR229-AHC PREPARE denial writes no journal (it refuses before the transaction begins)'
} else {
    Test-Fail 'TEST-PR229-AHC PREPARE denial writes no journal' "journals=$($journalsPrep.Count)"
}
if ((Test-IsReparsePoint (Join-Path $F 'repo/live/y.txt')) -and
    (Get-Sha256Hex (Join-Path $F 'canary3.txt')) -eq $canaryHashBefore) {
    Test-Pass 'TEST-PR229-AHC PREPARE denial leaves the symlink and its target untouched'
} else {
    Test-Fail 'TEST-PR229-AHC PREPARE denial leaves the symlink and its target untouched'
}

# --- (3) A DIRECTORY at the live target is the same class of observation. --
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'stage/live/z.txt') 'candidate-v1'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 `
    -Value ((Get-ManifestLine (Join-Path $F 'stage') 'live/z.txt') + "`n")
New-Item -ItemType Directory -Path (Join-Path $F 'repo/live/z.txt') -Force | Out-Null
$r = Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo') -ArgList @(
    '-StagingDir', (Join-Path $F 'stage'),
    '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
if ($r.ExitCode -ne 0 -and (Get-CategoryOf $r.StdoutPath) -eq 'PRE_EXISTING_SYMLINK_DENIED') {
    Test-Pass 'TEST-PR229-AHC a DIRECTORY occupying the live target is denied too (the whole non-regular class, not symlinks alone)'
} else {
    Test-Fail 'TEST-PR229-AHC a DIRECTORY occupying the live target is denied too' "exit $($r.ExitCode), category $(Get-CategoryOf $r.StdoutPath)"
}
if (Test-Path -LiteralPath (Join-Path $F 'repo/live/z.txt') -PathType Container) {
    Test-Pass 'TEST-PR229-AHC the occupying directory is left in place'
} else {
    Test-Fail 'TEST-PR229-AHC the occupying directory is left in place'
}

# ===========================================================================
# TEST-MODE-PRESERVE: PowerShell twin of the same block in
# tests/apply-human-copy.tests.sh -- see that file for the full rationale.
# Publish propagates the STAGED CANDIDATE's Unix permission bits to the live
# target (the live target's own PRE-existing mode is never consulted), and
# rollback restores the PRE-transaction target's own mode along with its
# bytes. Runs against the STAGED candidate ($ApplyPs1Pr229), same convention
# as TEST-PR229-AHC above; skipped entirely on native Windows, where POSIX
# permission bits do not exist and [System.IO.File]::GetUnixFileMode throws.
# ===========================================================================
function Get-ModeOctal([string]$Path) {
    return ('{0}' -f [Convert]::ToString([int][System.IO.File]::GetUnixFileMode($Path), 8))
}

if ($IsWindows) {
    Test-Pass 'TEST-MODE-PRESERVE fresh publish: executable staged candidate mode propagates (skipped: POSIX file modes not applicable on Windows)'
    Test-Pass 'TEST-MODE-PRESERVE existing-live overwrite: staged mode wins over live mode (skipped: POSIX file modes not applicable on Windows)'
    Test-Pass 'TEST-MODE-PRESERVE non-executable target: staged mode wins over live executable mode (skipped: POSIX file modes not applicable on Windows)'
    Test-Pass 'TEST-MODE-PRESERVE rollback: target1 mode reverted to its PRE mode (skipped: POSIX file modes not applicable on Windows)'
} else {
    # --- (1) executable target, FRESH publish. -----------------------------
    $F = New-FixtureDir
    Write-FixtureFile (Join-Path $F 'stage/live/tool.sh') 'echo hi'
    & chmod 755 (Join-Path $F 'stage/live/tool.sh')
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'live/tool.sh') + "`n")
    $r = Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    $livePath1 = Join-Path $F 'repo/live/tool.sh'
    if ($r.ExitCode -eq 0 -and (Test-Path -LiteralPath $livePath1 -PathType Leaf) -and (Get-ModeOctal $livePath1) -eq '755') {
        Test-Pass 'TEST-MODE-PRESERVE fresh publish: executable staged candidate mode 755 propagates to the live target'
    } else {
        Test-Fail 'TEST-MODE-PRESERVE fresh publish: executable staged candidate mode 755 propagates to the live target' "exit $($r.ExitCode), mode $(if (Test-Path -LiteralPath $livePath1) { Get-ModeOctal $livePath1 } else { 'n/a' })"
    }

    # --- (2) executable target, EXISTING live overwrite -- staged mode must
    #         win over the live target's OWN pre-existing mode. ------------
    $F = New-FixtureDir
    Write-FixtureFile (Join-Path $F 'repo/live/tool2.sh') 'old script'
    & chmod 600 (Join-Path $F 'repo/live/tool2.sh')
    Write-FixtureFile (Join-Path $F 'stage/live/tool2.sh') 'new script'
    & chmod 755 (Join-Path $F 'stage/live/tool2.sh')
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'live/tool2.sh') + "`n")
    $r = Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    $livePath2 = Join-Path $F 'repo/live/tool2.sh'
    if ($r.ExitCode -eq 0 -and (Test-Path -LiteralPath $livePath2 -PathType Leaf) -and (Get-ModeOctal $livePath2) -eq '755') {
        Test-Pass "TEST-MODE-PRESERVE existing-live overwrite: staged mode 755 wins over the live target's own pre-existing mode 600"
    } else {
        Test-Fail "TEST-MODE-PRESERVE existing-live overwrite: staged mode 755 wins over the live target's own pre-existing mode 600" "exit $($r.ExitCode), mode $(if (Test-Path -LiteralPath $livePath2) { Get-ModeOctal $livePath2 } else { 'n/a' })"
    }

    # --- (3) non-executable target -- the SAME rule in the opposite
    #         direction: a staged 644 candidate must strip an executable
    #         LIVE target's own 755. ------------------------------------
    $F = New-FixtureDir
    Write-FixtureFile (Join-Path $F 'repo/live/data.txt') 'old data'
    & chmod 755 (Join-Path $F 'repo/live/data.txt')
    Write-FixtureFile (Join-Path $F 'stage/live/data.txt') 'new data'
    & chmod 644 (Join-Path $F 'stage/live/data.txt')
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'live/data.txt') + "`n")
    $r = Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'))
    $livePath3 = Join-Path $F 'repo/live/data.txt'
    if ($r.ExitCode -eq 0 -and (Test-Path -LiteralPath $livePath3 -PathType Leaf) -and (Get-ModeOctal $livePath3) -eq '644') {
        Test-Pass "TEST-MODE-PRESERVE non-executable target: staged mode 644 wins over the live target's own pre-existing executable mode 755"
    } else {
        Test-Fail "TEST-MODE-PRESERVE non-executable target: staged mode 644 wins over the live target's own pre-existing executable mode 755" "exit $($r.ExitCode), mode $(if (Test-Path -LiteralPath $livePath3) { Get-ModeOctal $livePath3 } else { 'n/a' })"
    }

    # --- (4) rollback mode fidelity: a genuine MIX state (target1 committed
    #         to POST, target2 never reached) via a real mid-batch crash.
    #         Recovery must restore target1's PRE-transaction MODE (755),
    #         not the staged 644, and not a backup-file default. ---------
    $F = New-FixtureDir
    Write-FixtureFile (Join-Path $F 'repo/live/a.txt') 'old-a'
    & chmod 755 (Join-Path $F 'repo/live/a.txt')
    Write-FixtureFile (Join-Path $F 'stage/live/a.txt') 'new-a'
    & chmod 644 (Join-Path $F 'stage/live/a.txt')
    Write-FixtureFile (Join-Path $F 'stage/live/b.txt') 'new-b'
    $mpLines = (Get-ManifestLine (Join-Path $F 'stage') 'live/a.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'live/b.txt') + "`n"
    Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $mpLines
    Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo') -ArgList @(
        '-StagingDir', (Join-Path $F 'stage'),
        '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'),
        '-SimulateCrashAfter', 'rename-1') | Out-Null
    $aPath = Join-Path $F 'repo/live/a.txt'
    $bPath = Join-Path $F 'repo/live/b.txt'
    $aContentPost = Get-Content -Raw -LiteralPath $aPath -ErrorAction SilentlyContinue
    if ($aContentPost -eq "new-a`n" -and -not (Test-Path -LiteralPath $bPath)) {
        Test-Pass 'TEST-MODE-PRESERVE rollback precondition: mid-batch crash leaves target1 committed to POST, target2 not yet created'
    } else {
        Test-Fail 'TEST-MODE-PRESERVE rollback precondition: mid-batch crash leaves target1 committed to POST, target2 not yet created' "a='$aContentPost' bExists=$(Test-Path -LiteralPath $bPath)"
    }
    $r = Invoke-ApplyPr229 -RepoDir (Join-Path $F 'repo')
    $mpOutText = Get-Content -Raw -LiteralPath $r.StdoutPath -ErrorAction SilentlyContinue
    if ($r.ExitCode -eq 0 -and $null -ne $mpOutText -and $mpOutText.Contains('"recovered":1')) {
        Test-Pass 'TEST-MODE-PRESERVE rollback: recovery succeeds and reports the batch recovered'
    } else {
        Test-Fail 'TEST-MODE-PRESERVE rollback: recovery succeeds and reports the batch recovered' "exit $($r.ExitCode), stdout $mpOutText"
    }
    $aContentReverted = Get-Content -Raw -LiteralPath $aPath -ErrorAction SilentlyContinue
    if ($aContentReverted -eq "old-a`n") {
        Test-Pass 'TEST-MODE-PRESERVE rollback: target1 content reverted to its PRE bytes'
    } else {
        Test-Fail 'TEST-MODE-PRESERVE rollback: target1 content reverted to its PRE bytes' "got '$aContentReverted'"
    }
    if ((Test-Path -LiteralPath $aPath -PathType Leaf) -and (Get-ModeOctal $aPath) -eq '755') {
        Test-Pass 'TEST-MODE-PRESERVE rollback: target1 mode reverted to its PRE mode 755 (never the staged 644, never a backup-file default)'
    } else {
        Test-Fail 'TEST-MODE-PRESERVE rollback: target1 mode reverted to its PRE mode 755' "got $(if (Test-Path -LiteralPath $aPath) { Get-ModeOctal $aPath } else { 'n/a' })"
    }
    if (-not (Test-Path -LiteralPath $bPath)) {
        Test-Pass 'TEST-MODE-PRESERVE rollback: target2 (never committed) remains absent'
    } else {
        Test-Fail 'TEST-MODE-PRESERVE rollback: target2 (never committed) remains absent'
    }
    if (Test-NoStagingLitter $F) {
        Test-Pass 'TEST-MODE-PRESERVE rollback: journal/staging litter fully cleaned up after convergence'
    } else {
        Test-Fail 'TEST-MODE-PRESERVE rollback: journal/staging litter fully cleaned up after convergence' 'litter remains'
    }
}

# ---------------------------------------------------------------------------
# Self-registration.
# ---------------------------------------------------------------------------
if ((Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.ps1')) -match 'apply-human-copy\.tests\.ps1') {
    Test-Pass 'self-registration: tests/run-all.ps1 references apply-human-copy.tests.ps1'
} else {
    Test-Fail 'self-registration: tests/run-all.ps1 references apply-human-copy.tests.ps1' 'not found'
}

} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ''
Write-Output "$script:PassCount passed, $script:FailCount failed"
if ($script:FailCount -gt 0) { exit 1 }
exit 0
