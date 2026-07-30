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
# TEST-033i: crash BEFORE any rename recovers to ALL-PRE.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/a.txt') 'old-a'
Write-FixtureFile (Join-Path $F 'repo/plugins/x/b.txt') 'old-b'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'new-a'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/b.txt') 'new-b'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/b.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'journal-write') | Out-Null
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
if ($a -eq "old-a`n" -and $b -eq "old-b`n") { Test-Pass 'TEST-033i crash before any rename: both targets still PRE immediately after the crash' } else { Test-Fail 'TEST-033i crash before any rename: both targets still PRE' "a='$a' b='$b'" }
Invoke-Apply -RepoDir (Join-Path $F 'repo') | Out-Null
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
if ($a -eq "old-a`n" -and $b -eq "old-b`n") { Test-Pass 'TEST-033i recovery converges to ALL-PRE (crash before any rename)' } else { Test-Fail 'TEST-033i recovery converges to ALL-PRE' "a='$a' b='$b'" }

# ---------------------------------------------------------------------------
# TEST-033j: crash MID-BATCH recovers to ALL-PRE.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/a.txt') 'old-a'
Write-FixtureFile (Join-Path $F 'repo/plugins/x/b.txt') 'old-b'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'new-a'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/b.txt') 'new-b'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/b.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'rename-1') | Out-Null
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
if ($a -eq "new-a`n" -and $b -eq "old-b`n") { Test-Pass 'TEST-033j mid-batch crash leaves an observable partial state right after the crash' } else { Test-Fail 'TEST-033j mid-batch crash partial state' "a='$a' b='$b'" }
Invoke-Apply -RepoDir (Join-Path $F 'repo') | Out-Null
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
if ($a -eq "old-a`n" -and $b -eq "old-b`n") { Test-Pass 'TEST-033j recovery converges to ALL-PRE (mid-batch crash rolled back)' } else { Test-Fail 'TEST-033j recovery converges to ALL-PRE' "a='$a' b='$b'" }

# ---------------------------------------------------------------------------
# TEST-033k: crash AFTER the last rename but BEFORE journal deletion
# recovers to ALL-POST.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/a.txt') 'old-a'
Write-FixtureFile (Join-Path $F 'repo/plugins/x/b.txt') 'old-b'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'new-a'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/b.txt') 'new-b'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/b.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'rename-2') | Out-Null
Invoke-Apply -RepoDir (Join-Path $F 'repo') | Out-Null
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
if ($a -eq "new-a`n" -and $b -eq "new-b`n") { Test-Pass 'TEST-033k recovery converges to ALL-POST (crash after last rename, before journal delete)' } else { Test-Fail 'TEST-033k recovery converges to ALL-POST' "a='$a' b='$b'" }

# ---------------------------------------------------------------------------
# TEST-033l: a SECOND crash injected DURING recovery itself still
# converges correctly on the FOLLOWING invocation.
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/a.txt') 'old-a'
Write-FixtureFile (Join-Path $F 'repo/plugins/x/b.txt') 'old-b'
Write-FixtureFile (Join-Path $F 'repo/plugins/x/c.txt') 'old-c'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/a.txt') 'new-a'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/b.txt') 'new-b'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/c.txt') 'new-c'
$manifestLines = (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/a.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/b.txt') + "`n" + (Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/c.txt') + "`n"
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value $manifestLines
Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateCrashAfter', 'rename-2') | Out-Null
Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-SimulateCrashDuringRecoveryAfter', 'revert-1') | Out-Null
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
$c = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/c.txt')
if ($a -eq "old-a`n" -and $b -eq "new-b`n" -and $c -eq "old-c`n") { Test-Pass 'TEST-033l a second crash mid-recovery leaves an observable partial-recovery state' } else { Test-Fail 'TEST-033l partial-recovery state' "a='$a' b='$b' c='$c'" }
Invoke-Apply -RepoDir (Join-Path $F 'repo') | Out-Null
$a = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/a.txt')
$b = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/b.txt')
$c = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x/c.txt')
if ($a -eq "old-a`n" -and $b -eq "old-b`n" -and $c -eq "old-c`n") { Test-Pass 'TEST-033l the FOLLOWING invocation still converges to ALL-PRE (recovery is idempotent/re-entrant)' } else { Test-Fail 'TEST-033l final convergence' "a='$a' b='$b' c='$c'" }

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
# ---------------------------------------------------------------------------
$F = New-FixtureDir
Write-FixtureFile (Join-Path $F 'repo/plugins/x/file.txt') 'old-content'
Write-FixtureFile (Join-Path $F 'stage/plugins/x/file.txt') 'new-content'
Set-Content -LiteralPath (Join-Path $F 'stage/MANIFEST.sha256') -NoNewline -Encoding utf8 -Value ((Get-ManifestLine (Join-Path $F 'stage') 'plugins/x/file.txt') + "`n")
$r = Invoke-Apply -RepoDir (Join-Path $F 'repo') -ArgList @('-StagingDir', (Join-Path $F 'stage'), '-Manifest', (Join-Path $F 'stage/MANIFEST.sha256'), '-SimulateSubstitution')
if ($r.ExitCode -eq 0) { Test-Pass 'TEST-033o substitution-resistance fixture: tool still completes successfully' } else { Test-Fail 'TEST-033o substitution completes' "exit $($r.ExitCode)" }
$origPath = Join-Path $F 'repo/plugins/x/file.txt'
$origIsEmpty = -not (Test-Path -LiteralPath $origPath) -or ((Get-Item -LiteralPath $origPath).Length -eq 0)
if ($origIsEmpty) { Test-Pass 'TEST-033o the newly-substituted directory at the ORIGINAL name never receives the candidate' } else { Test-Fail 'TEST-033o original-name directory unaffected' 'candidate leaked into the substitute' }
$movedContent = Get-Content -Raw -LiteralPath (Join-Path $F 'repo/plugins/x.attacker-moved/file.txt') -ErrorAction SilentlyContinue
if ($movedContent -eq "new-content`n") { Test-Pass 'TEST-033o the write lands in the TRUE, anchored original directory (now at its new name)' } else { Test-Fail 'TEST-033o write lands in anchored original' "got '$movedContent'" }

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
