# tests/component-path-diff-basis.tests.ps1 - PowerShell twin of
# tests/component-path-diff-basis.tests.sh (epic-191-a3-path-ownership
# T-002). See the bash twin for the full TEST-NNN/AC-NNN mapping and
# rationale. Drives resolve-component-paths.ps1 (real subprocess, mirroring
# the component-path-resolver twin's own established convention) against
# DISPOSABLE fixture git repos created at test-run time under a mktemp
# root (never this repository's own history).
$ErrorActionPreference = "Stop"

# Named $suiteRepoRoot (not $repoRoot / $RepoRoot) deliberately: the product
# script dot-sourced below (see the TEST-021.2/TEST-025.2 block) declares
# `param([string]$RepoRoot = ".")`, and PowerShell variable names are
# case-insensitive, so a script-scope `$repoRoot` here would be silently
# rebound to "." by that dot-source, corrupting the registration self-check
# at the bottom of this file when the suite is run from a directory other
# than this repository's root. Keeping this suite's own variable name
# case-insensitively distinct from the product's -RepoRoot parameter avoids
# the collision entirely rather than relying on run-from-repo-root luck.
$suiteRepoRoot = Split-Path -Parent $PSScriptRoot
$scriptPs1 = Join-Path $suiteRepoRoot "plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1"
$resolverPy = Join-Path $suiteRepoRoot "plugins/sdd-quality-loop/scripts/resolve-component-paths.py"
$powerShell = (Get-Process -Id $PID).Path

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$work = Join-Path ([IO.Path]::GetTempPath()) ("rcp-diffbasis." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$work = (Resolve-Path -LiteralPath $work).Path

$configPath = Join-Path $work "config.yaml"
@"
components:
  - id: desktop
    paths:
      include:
        - "src/desktop/**"
  - id: mobile
    paths:
      include:
        - "src/mobile/**"
"@ | Set-Content -LiteralPath $configPath -Encoding utf8 -NoNewline

function New-GitRepo {
    param([string]$Name)
    $dir = Join-Path $work $Name
    New-Item -ItemType Directory -Path $dir | Out-Null
    & git init -q -b main $dir | Out-Null
    Push-Location $dir
    try {
        git config user.email t@example.com
        git config user.name Test
    } finally {
        Pop-Location
    }
    return $dir
}

function Invoke-ResolverGit {
    param([string]$RepoDir, [string]$SourceRev, [string]$TargetRev, [string[]]$ExtraArgs = @())
    $allArgs = @("-RepoRoot", $RepoDir, "-Config", $configPath, "-SourceRev", $SourceRev, "-TargetRev", $TargetRev) + $ExtraArgs
    $out = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPs1 @allArgs 2>&1 | Out-String -Width 4096
    $flattened = (($out -replace '\s+', ' ') -replace ' \| ', ' ') -replace '\s+', ' '
    return @{ Output = $flattened; ExitCode = $LASTEXITCODE }
}

function Get-Classification {
    param([string]$Json, [string]$RawPath)
    $obj = $Json | ConvertFrom-Json
    $rec = $obj.records | Where-Object { $_.raw_path -eq $RawPath }
    if ($null -eq $rec) { return $null }
    return $rec.classification
}

# ============================================================================
# TEST-019 (AC-019): rev-resolution + merge-base baseline; fail-closed cases
# ============================================================================
Write-Output "=== TEST-019: rev-resolution + merge-base baseline ==="
$r19 = New-GitRepo "repo19"
New-Item -ItemType Directory -Path (Join-Path $r19 "src/desktop") | Out-Null
"line one" | Set-Content -LiteralPath (Join-Path $r19 "src/desktop/a.ts") -Encoding utf8
Push-Location $r19
git add -A; git commit -q -m base
$base19 = (git rev-parse HEAD).Trim()
Pop-Location

$r = Invoke-ResolverGit $r19 $base19 $base19
if ($r.ExitCode -eq 0) { Ok "TEST-019.1: identical source/target revs resolve cleanly" } else { Fail "TEST-019.1: expected clean resolve, got exit=$($r.ExitCode)" }

$r = Invoke-ResolverGit $r19 $base19 "totally-bogus-rev-xyz"
if ($r.ExitCode -ne 0 -and $r.Output -match "unresolvable rev") { Ok "TEST-019.2: an unresolvable target rev fails closed with a diagnostic" } else { Fail "TEST-019.2: expected non-zero exit + diagnostic, got exit=$($r.ExitCode) out=$($r.Output)" }

Push-Location $r19
git checkout -q --orphan orphan19
"orphan" | Set-Content -LiteralPath "orphan-only.txt" -Encoding utf8
git add orphan-only.txt
git commit -q -m "orphan root"
$orphan19 = (git rev-parse HEAD).Trim()
Pop-Location
$r = Invoke-ResolverGit $r19 $base19 $orphan19
if ($r.ExitCode -ne 0 -and $r.Output -match "no merge-base") { Ok "TEST-019.3: unrelated histories fail closed with a diagnostic" } else { Fail "TEST-019.3: expected non-zero exit + no-merge-base diagnostic, got exit=$($r.ExitCode) out=$($r.Output)" }

# ============================================================================
# TEST-020 (AC-020): staged + unstaged + untracked, no double-count
# ============================================================================
Write-Output "=== TEST-020: staged + unstaged + untracked, no double-count ==="
$r20 = New-GitRepo "repo20"
New-Item -ItemType Directory -Path (Join-Path $r20 "src/desktop") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $r20 "src/mobile") | Out-Null
"base desktop" | Set-Content -LiteralPath (Join-Path $r20 "src/desktop/a.ts") -Encoding utf8
"base mobile" | Set-Content -LiteralPath (Join-Path $r20 "src/mobile/b.ts") -Encoding utf8
Push-Location $r20
git add -A; git commit -q -m base
$base20 = (git rev-parse HEAD).Trim()
"staged change" | Set-Content -LiteralPath "src/desktop/a.ts" -Encoding utf8
git add src/desktop/a.ts
Add-Content -LiteralPath "src/mobile/b.ts" -Value "unstaged change"
"untracked" | Set-Content -LiteralPath "src/mobile/c.ts" -Encoding utf8
Pop-Location
$r = Invoke-ResolverGit $r20 $base20 $base20
$obj = $r.Output | ConvertFrom-Json
if ($obj.records.Count -eq 3 `
    -and (Get-Classification $r.Output "src/desktop/a.ts") -eq "EXCLUSIVE" `
    -and (Get-Classification $r.Output "src/mobile/b.ts") -eq "EXCLUSIVE" `
    -and (Get-Classification $r.Output "src/mobile/c.ts") -eq "EXCLUSIVE") {
    Ok "TEST-020.1: staged, unstaged, and untracked changes are each collected exactly once"
} else {
    Fail "TEST-020.1: expected exactly 3 records, got $($obj.records.Count)"
}

# ============================================================================
# Dot-source the real product script once so TEST-021.2 and TEST-025.2 below
# can call its actual functions (ConvertTo-PathStrict, Get-ChangedPaths)
# directly, rather than the standalone reproductions this suite previously
# used for both (see specs/epic-191-a3-path-ownership/verification/T-002/
# component-path-diff-basis-ps1.RED.log: both were confirmed structurally
# unable to catch a regression in the real functions -- a pre-existing gap
# in this suite's own design, not something T-002's remediation introduced).
# Safe: the script's CLI dispatch is guarded by
# `if ($MyInvocation.InvocationName -ne '.')`, so dot-sourcing here only
# defines functions/classes in this scope; it never runs the CLI body.
# Mirrors the bash twin's use of importlib to load the real
# resolve-component-paths.py module for the same two cases.
# ============================================================================
. $scriptPs1

# ============================================================================
# TEST-021 (AC-021): NUL-safe framing (TAB round-trip; invalid-UTF-8 as a
# direct unit test, same rationale as the bash twin)
# ============================================================================
Write-Output "=== TEST-021: NUL-safe framing ==="
$r21 = New-GitRepo "repo21"
New-Item -ItemType Directory -Path (Join-Path $r21 "src/desktop") | Out-Null
"base" | Set-Content -LiteralPath (Join-Path $r21 "src/desktop/base.ts") -Encoding utf8
Push-Location $r21
git add -A; git commit -q -m base
$base21 = (git rev-parse HEAD).Trim()
$tabName = "src/desktop/tab`tname.ts"
"has a tab in the name" | Set-Content -LiteralPath $tabName -Encoding utf8
git add -- $tabName
Pop-Location
$r = Invoke-ResolverGit $r21 $base21 $base21
if ((Get-Classification $r.Output $tabName) -eq "EXCLUSIVE") {
    Ok "TEST-021.1: a path containing a literal TAB round-trips correctly"
} else {
    Fail "TEST-021.1: expected the TAB-containing path to round-trip and classify EXCLUSIVE"
}

# Direct unit test of the real product function (same rationale as the bash
# twin, which importlib-loads resolve-component-paths.py and calls the real
# _decode_path_strict directly): macOS's own filesystem does not permit
# creating an invalid-UTF-8-named file on disk, so this cannot be driven
# through the CLI end-to-end. Calls the actual ConvertTo-PathStrict function
# (dot-sourced above) -- not a standalone reproduction of its contract -- so
# a regression in the real function is caught here.
$badBytes = [byte[]]@(0x73, 0x72, 0x63, 0xFF, 0x2E, 0x74, 0x73)  # "src\xFF.ts"
try {
    $decoded = ConvertTo-PathStrict $badBytes
    Fail "TEST-021.2: expected ConvertTo-PathStrict to throw a GitDiffError for invalid UTF-8 bytes, got '$decoded'"
} catch [GitDiffError] {
    if ($_.Exception.Message -match "invalid UTF-8") {
        Ok "TEST-021.2: the real ConvertTo-PathStrict fails closed with a diagnostic on invalid UTF-8 bytes, confirmed via a direct call to the product function itself (dot-sourced from resolve-component-paths.ps1; macOS's own filesystem does not permit creating such a filename on disk to drive this through the CLI end-to-end)"
    } else {
        Fail "TEST-021.2: ConvertTo-PathStrict threw but with the wrong diagnostic: $($_.Exception.Message)"
    }
}

# ============================================================================
# TEST-022 (AC-022): rename-follow incl. cross-component
# ============================================================================
Write-Output "=== TEST-022: rename-follow incl. cross-component ==="
$r22 = New-GitRepo "repo22"
New-Item -ItemType Directory -Path (Join-Path $r22 "src/desktop") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $r22 "src/mobile") | Out-Null
$bigContent = (1..40 | ForEach-Object { "meaningful content line $_ for rename similarity detection" }) -join "`n"
$bigContent | Set-Content -LiteralPath (Join-Path $r22 "src/desktop/big.ts") -Encoding utf8
Push-Location $r22
git add -A; git commit -q -m base
$base22 = (git rev-parse HEAD).Trim()
git mv src/desktop/big.ts src/mobile/big.ts
git commit -q -m "cross-component rename"
$target22 = (git rev-parse HEAD).Trim()
Pop-Location
$r = Invoke-ResolverGit $r22 $base22 $target22
$obj = $r.Output | ConvertFrom-Json
if ($obj.diff_basis.renames.Count -eq 1 -and $obj.diff_basis.renames[0].cross_component -eq $true) {
    Ok "TEST-022.1: a cross-component rename is detected and surfaced as its own distinct case"
} else {
    Fail "TEST-022.1: expected 1 rename with cross_component=true, got: $($r.Output)"
}
if ((Get-Classification $r.Output "src/desktop/big.ts") -eq "EXCLUSIVE" -and (Get-Classification $r.Output "src/mobile/big.ts") -eq "EXCLUSIVE") {
    Ok "TEST-022.2: both the pre-rename and post-rename path are independently classified"
} else {
    Fail "TEST-022.2: expected both old and new paths EXCLUSIVE"
}

# ============================================================================
# TEST-023 (AC-023): pinned threshold/limit contract; limit-exceeded is a
# direct unit test (same rationale as the bash twin).
# ============================================================================
Write-Output "=== TEST-023: pinned threshold/limit contract ==="
$ps1Text = Get-Content -Raw -LiteralPath $scriptPs1
if ($ps1Text -match '\$RENAME_SIMILARITY_THRESHOLD = 50' -and $ps1Text -match '\$RENAME_LIMIT = 1000') {
    Ok "TEST-023.1: the pinned rename similarity threshold (50%) and diff.renameLimit (1000) are defined as fixed constants"
} else {
    Fail "TEST-023.1: expected pinned RENAME_SIMILARITY_THRESHOLD=50 and RENAME_LIMIT=1000 constants"
}

# Direct unit test of the real product function (same rationale as the bash
# twin, which monkeypatches rcp._run_git on the importlib-loaded module and
# then calls the real collect_tracked_diff): reproducing git's own real
# "too many files" trigger at fixture scale is impractical (see the
# implementation report's Specification Differences #2). Redefining
# Invoke-GitRaw here in this scope is picked up by the real Get-TrackedDiff
# (dot-sourced above) without editing its source -- PowerShell resolves an
# unqualified function call dynamically at call time (confirmed empirically
# in TEST-025.2 below) -- proving the fail-closed branch in the actual
# function itself, not a source-text grep that would still pass with the
# branch made unreachable. The original Invoke-GitRaw is restored afterward
# so no later test in this file observes the monkeypatch.
$originalInvokeGitRaw = ${function:Invoke-GitRaw}
function Invoke-GitRaw {
    param([string]$RepoRoot, [string[]]$GitArgs)
    return @{
        ExitCode = 0
        Stdout = [byte[]]@()
        Stderr = [System.Text.Encoding]::UTF8.GetBytes("warning: inexact rename detection was skipped due to too many files.`n")
    }
}
try {
    Get-TrackedDiff -RepoRoot "/nonexistent" -BaselineOid "deadbeef" | Out-Null
    Fail "TEST-023.2: expected Get-TrackedDiff to throw a GitDiffError for a too-many-files stderr warning"
} catch [GitDiffError] {
    if ($_.Exception.Message -match "rename-detection limit exceeded") {
        Ok "TEST-023.2: the real Get-TrackedDiff fails closed with the expected diagnostic on a too-many-files stderr warning, confirmed via a direct call to the product function itself with Invoke-GitRaw monkeypatched (mirrors the bash twin's monkeypatching of rcp._run_git on the real module)"
    } else {
        Fail "TEST-023.2: Get-TrackedDiff threw but with the wrong diagnostic: $($_.Exception.Message)"
    }
} finally {
    ${function:Invoke-GitRaw} = $originalInvokeGitRaw
}

# ============================================================================
# TEST-024 (AC-024): four submodule/symlink reference-only cases
# ============================================================================
Write-Output "=== TEST-024: submodule/symlink reference-only (four cases) ==="
$r24Inner = New-GitRepo "repo24-inner"
"inner base" | Set-Content -LiteralPath (Join-Path $r24Inner "inner.txt") -Encoding utf8
Push-Location $r24Inner
git add -A; git commit -q -m "inner base"
Pop-Location

$r24 = New-GitRepo "repo24"
New-Item -ItemType Directory -Path (Join-Path $r24 "src/desktop") | Out-Null
"base" | Set-Content -LiteralPath (Join-Path $r24 "src/desktop/a.ts") -Encoding utf8
Push-Location $r24
git add -A; git commit -q -m base
git -c protocol.file.allow=always submodule add -q "file://$r24Inner" vendor/inner *>$null
git commit -q -m "add submodule"
$base24a = (git rev-parse HEAD).Trim()
Pop-Location

# Case 1: dirty-but-pointer-unchanged submodule -> NOT reported
Add-Content -LiteralPath (Join-Path $r24 "vendor/inner/inner.txt") -Value "dirty uncommitted change"
$r = Invoke-ResolverGit $r24 $base24a $base24a
$obj = $r.Output | ConvertFrom-Json
$submoduleRecord = $obj.records | Where-Object { $_.raw_path -eq "vendor/inner" }
if ($null -eq $submoduleRecord) { Ok "TEST-024.1: a dirty-but-pointer-unchanged submodule is NOT reported" } else { Fail "TEST-024.1: expected no record for vendor/inner" }

# Case 2: gitlink OID change (pointer bump) -> reported
Push-Location (Join-Path $r24 "vendor/inner")
git add -A; git commit -q -m "commit the dirty content"
Pop-Location
Push-Location $r24
git add vendor/inner
git commit -q -m "bump submodule pointer"
$base24b = (git rev-parse "HEAD~1").Trim()
$target24b = (git rev-parse HEAD).Trim()
Pop-Location
$r = Invoke-ResolverGit $r24 $base24b $target24b
if ((Get-Classification $r.Output "vendor/inner")) { Ok "TEST-024.2: a submodule gitlink OID change IS reported as a change" } else { Fail "TEST-024.2: expected a record for vendor/inner after the pointer bump" }

# Case 3: symlink target-text change -> reported
Push-Location $r24
New-Item -ItemType SymbolicLink -Path "src/desktop/link.ts" -Target "src/desktop/a.ts" -Force | Out-Null
git add src/desktop/link.ts
git commit -q -m "add symlink"
New-Item -ItemType Directory -Path "src/mobile" -Force | Out-Null
"other target" | Set-Content -LiteralPath "src/mobile/other.ts" -Encoding utf8
git add src/mobile/other.ts
git commit -q -m "add retarget destination"
Remove-Item -Force "src/desktop/link.ts"
New-Item -ItemType SymbolicLink -Path "src/desktop/link.ts" -Target "../mobile/other.ts" -Force | Out-Null
git add src/desktop/link.ts
git commit -q -m "retarget symlink"
$base24c2 = (git rev-parse "HEAD~1").Trim()
$target24c2 = (git rev-parse HEAD).Trim()
Pop-Location
$r = Invoke-ResolverGit $r24 $base24c2 $target24c2
$linkCls = Get-Classification $r.Output "src/desktop/link.ts"
if ($linkCls -eq "EXCLUSIVE" -or $linkCls -eq "UNOWNED") { Ok "TEST-024.3: a symlink's own target-text change is reported at the symlink's path" } else { Fail "TEST-024.3: expected a record for src/desktop/link.ts, got '$linkCls'" }

# Case 4: referent-only content change -> NOT reported at the symlink's path
Push-Location $r24
Add-Content -LiteralPath "src/mobile/other.ts" -Value "changed content in the referent, not the link"
git add src/mobile/other.ts
git commit -q -m "change the symlink's referent only"
$base24d = (git rev-parse "HEAD~1").Trim()
$target24d = (git rev-parse HEAD).Trim()
Pop-Location
$r = Invoke-ResolverGit $r24 $base24d $target24d
$obj = $r.Output | ConvertFrom-Json
$linkAfterReferentChange = $obj.records | Where-Object { $_.raw_path -eq "src/desktop/link.ts" }
if ($null -eq $linkAfterReferentChange -and (Get-Classification $r.Output "src/mobile/other.ts") -eq "EXCLUSIVE") {
    Ok "TEST-024.4: a referent-only content change is reported at the referent's own path, never at the untouched symlink's path"
} else {
    Fail "TEST-024.4: expected no record for the symlink's own path and EXCLUSIVE for the referent"
}

# ============================================================================
# TEST-025 (AC-025): single-writer/TOCTOU retry-then-fail-closed
# ============================================================================
Write-Output "=== TEST-025: single-writer/TOCTOU retry-then-fail-closed ==="
$r25 = New-GitRepo "repo25"
New-Item -ItemType Directory -Path (Join-Path $r25 "src/desktop") | Out-Null
"base" | Set-Content -LiteralPath (Join-Path $r25 "src/desktop/a.ts") -Encoding utf8
Push-Location $r25
git add -A; git commit -q -m base
$base25 = (git rev-parse HEAD).Trim()
Pop-Location

$r = Invoke-ResolverGit $r25 $base25 $base25
if ($r.ExitCode -eq 0) { Ok "TEST-025.1: an ordinary resolve with no concurrent writer succeeds" } else { Fail "TEST-025.1: expected a clean resolve with no concurrent writer" }

# Direct unit test of the real product function (same rationale as the bash
# twin, which monkeypatches rcp._capture_fingerprint on the importlib-loaded
# module and then calls the real collect_changed_paths): reliably simulating
# a true concurrent race via the CLI alone is impractical. PowerShell
# resolves an unqualified function call dynamically at call time (confirmed
# empirically), so redefining Get-RepoFingerprint here in this scope is
# picked up by the real Get-ChangedPaths (dot-sourced above) without editing
# its source -- proving the retry-once-then-fail-closed logic in the actual
# function itself, not a standalone reimplementation of its shape. The
# original Get-RepoFingerprint is restored afterward so no later test in
# this file observes the monkeypatch.
$originalGetRepoFingerprint = ${function:Get-RepoFingerprint}
$script:toctouCallCount = 0
function Get-RepoFingerprint {
    param([string]$RepoRoot)
    $script:toctouCallCount += 1
    return @{ Head = "fake-head-$($script:toctouCallCount)"; StatusHash = "fake-status-$($script:toctouCallCount)" }
}
try {
    Get-ChangedPaths -RepoRoot $r25 -SourceRev $base25 -TargetRev $base25 -IncludeUntracked $true | Out-Null
    Fail "TEST-025.2: expected Get-ChangedPaths to throw a GitDiffError after a persistent fingerprint mismatch"
} catch [GitDiffError] {
    if ($_.Exception.Message -match "retry" -and $script:toctouCallCount -eq 4) {
        # 2 attempts x 2 fingerprint captures (before+after) each = 4 calls
        Ok "TEST-025.2: a persistent single-writer/TOCTOU fingerprint mismatch retries exactly once then fails closed, confirmed via a direct call to the real Get-ChangedPaths with Get-RepoFingerprint monkeypatched to never settle"
    } else {
        Fail "TEST-025.2: expected callCount=4 and a 'retry' diagnostic, got callCount=$($script:toctouCallCount) diagnostic=$($_.Exception.Message)"
    }
} finally {
    ${function:Get-RepoFingerprint} = $originalGetRepoFingerprint
}

# ============================================================================
# DEFECT-002: tab-indentation guard (REQ-001 config parsing) fails closed on
# a bare leading tab. Found in passing during T-002 remediation and fixed
# here; not part of the T-002/AC-019..025 catalog this suite otherwise
# covers (REQ-001's YAML tab-indentation guard is conceptually T-001/
# component-path-resolver territory, but that suite is concurrently being
# remediated by another agent for T-005, so this regression check lives
# here instead, against the same shared resolve-component-paths
# implementation both suites exercise). Root cause: the guard computed an
# indent depth by stripping only " " (space) characters, then checked that
# same space-only-derived prefix for a tab -- a prefix that, by
# construction, can never contain a tab. It never fired for ANY
# tab-indented line, not just a bare leading tab. Same root cause and same
# fix in both resolve-component-paths.py and resolve-component-paths.ps1.
# ============================================================================
Write-Output "=== DEFECT-002: tab-indentation guard fails closed on a bare leading tab ==="
$tabConfig = Join-Path $work "tab-indent-config.yaml"
"components:`n`t- id: desktop`n`t  paths:`n`t    include:`n`t      - `"src/desktop/**`"`n" | Set-Content -LiteralPath $tabConfig -Encoding utf8 -NoNewline
$tabOutRaw = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPs1 -Config $tabConfig 2>&1 | Out-String -Width 4096
$tabExitCode = $LASTEXITCODE
# Same whitespace-flattening as Invoke-ResolverGit above: Write-Error wraps
# long diagnostic lines at the console width, which would otherwise split
# "spaces, not tabs" across two lines and defeat a simple -match.
$tabOut = (($tabOutRaw -replace '\s+', ' ') -replace ' \| ', ' ') -replace '\s+', ' '
if ($tabExitCode -ne 0 -and $tabOut -match "spaces, not tabs") {
    Ok "DEFECT-002.1: a config using a bare leading tab for indentation fails closed with the tabs-not-supported diagnostic (real CLI invocation)"
} else {
    Fail "DEFECT-002.1: expected a non-zero exit and a 'spaces, not tabs' diagnostic, got exit=$tabExitCode out=$tabOut"
}

# ============================================================================
# Registration self-check
# ============================================================================
Write-Output "=== registration self-check ==="
$runAllSh = Join-Path $suiteRepoRoot "tests/run-all.sh"
$runAllPs1 = Join-Path $suiteRepoRoot "tests/run-all.ps1"
if ((Select-String -LiteralPath $runAllSh -Pattern "component-path-diff-basis" -Quiet) -and (Select-String -LiteralPath $runAllPs1 -Pattern "component-path-diff-basis" -Quiet)) {
    Ok "component-path-diff-basis suite self-registers in run-all.sh and .ps1"
} else {
    Fail "component-path-diff-basis missing from run-all.sh/.ps1 registration"
}

Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue

# ============================================================================
# Summary
# ============================================================================
Write-Output ""
Write-Output "component-path-diff-basis.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
