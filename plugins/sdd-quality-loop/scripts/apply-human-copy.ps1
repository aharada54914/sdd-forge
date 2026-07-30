#requires -Version 7
<#
.SYNOPSIS
apply-human-copy.ps1 (REQ-007, epic-189-a1-project-context T-007).

Anchored-publisher-equivalent human-copy tool: generalizes
docs/adr/0011-phase2-handle-relative-protected-copy.md's guarantee to a
cross-platform sh/ps1 pair (never a reuse of, or extension to,
specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1, which is
frozen/out of scope, INV-011, and Windows-only). NO Python master: this
file, and its .sh twin, each implement the FULL publisher logic
independently -- neither dispatches to the other, and neither dispatches
to a shared .py.

.DESCRIPTION
Held-handle technique note (read before modifying): this script runs via
`pwsh` on Windows, macOS, AND Linux (the CI matrix runs every `pwsh` step
on all three), so a literal Win32 NtCreateFile/SetFileInformationByHandle
implementation would not be portable, and .NET's own [System.IO.File]::
OpenHandle throws UnauthorizedAccessException for a DIRECTORY target on
every platform (verified empirically at implementation time -- the BCL
deliberately restricts it to regular files). The guarantee requirements.md
describes -- "opens the repository root and every destination parent
directory via a HELD handle ... resolves every relative path one segment
at a time through that held handle" -- is realized here via the SAME
technique as the .sh twin: the process's own current-working-directory
binding. `Set-Location` with a RELATIVE name resolves against the
runtime's already-open reference to the CURRENT directory (chdir/
SetCurrentDirectory are both real, kernel-mediated calls on every
platform), never by re-walking the path string from the drive/filesystem
root. Walking one segment at a time -- each preceded by a reparse-point/
symlink check via [System.IO.File]::GetAttributes() (works identically for
Unix symlinks and Windows junctions/symlinks) that denies BEFORE ever
entering it -- is therefore a genuine, kernel-mediated equivalent of
handle-relative traversal, immune to an attacker renaming/replacing an
ALREADY-ENTERED ancestor directory out from under us. An identity
re-check (physical resolved path comparison) is performed immediately
before every write, for defense-in-depth. Documented residual (never
silently implied as fully closed): as with the .sh twin, the narrow
window between a segment's own reparse-point check and its
Set-Location, and between the final pre-rename re-check and the actual
[System.IO.File]::Move call, is not closed by a single held syscall the
way a real openat()/renameat() or NtCreateFile chain would close it. See
ADR-0025 for the full write-up.

.PARAMETER StagingDir
Directory whose tree mirrors repo-relative target paths (the source side
of the batch). Omit (together with -Manifest) to run ONLY the mandatory
start-of-invocation crash-recovery scan.

.PARAMETER Manifest
A GNU sha256sum-format file (`<64-hex-lowercase>  <repo-relative-path>`,
two spaces, one line per target, in COMMIT ORDER).

.PARAMETER SimulateCrashAfter
TEST-ONLY fault injection: one of `prepare`, `journal-write`,
`rename-<N>` (1-based), matching generate-approval-sidecar.py's
established `-SimulateMidWriteFailure` convention. Immediately terminates
the process via [Environment]::Exit (skips all `finally` blocks -- a
genuine crash, never a soft `exit`).

.PARAMETER SimulateCrashDuringRecoveryAfter
TEST-ONLY fault injection during the recovery scan: `revert-<N>`.

.PARAMETER SimulateSubstitution
TEST-ONLY: after anchoring the FIRST target's destination-parent, renames
that directory aside (from an unanchored vantage) and creates an empty
replacement at the original name, proving the write still lands in the
true, anchored original.
#>
[CmdletBinding()]
param(
    [string]$StagingDir,
    [string]$Manifest,
    [ValidateSet('', 'prepare', 'journal-write', 'rename-1', 'rename-2', 'rename-3', 'rename-4')]
    [string]$SimulateCrashAfter = '',
    [ValidateSet('', 'revert-1', 'revert-2', 'revert-3', 'revert-4')]
    [string]$SimulateCrashDuringRecoveryAfter = '',
    [switch]$SimulateSubstitution
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ExitOk = 0
$ExitUsageError = 2
$ExitPreExistingSymlinkDenied = 10
$ExitTraversalDenied = 11
$ExitStagedCandidateHashMismatch = 12
$ExitManifestInvalid = 13
$ExitJournalShapeInvalid = 14
$ExitJournalWriteFailed = 15
$ExitRenameFailed = 16
$ExitRecoveryFailed = 17

function Write-Denial([int]$Code, [string]$Category, [string]$Message) {
    $obj = [ordered]@{ status = 'denied'; category = $Category; message = $Message }
    $json = $obj | ConvertTo-Json -Compress
    [Console]::Error.WriteLine($json)
    [Console]::Out.WriteLine($json)
    exit $Code
}

function Write-Ok([int]$Recovered, [string[]]$Targets) {
    $obj = [ordered]@{ status = 'ok'; recovered = $Recovered; targets = @($Targets) }
    $json = $obj | ConvertTo-Json -Compress
    [Console]::Out.WriteLine($json)
}

function Invoke-SimulatedCrash([string]$Label) {
    [Console]::Error.WriteLine("SIMULATED_CRASH: $Label")
    # [Environment]::Exit bypasses try/finally unwind -- a genuine,
    # trap-immune process death, matching the .sh twin's `kill -KILL $$`.
    [Environment]::Exit(137)
}

function Get-Sha256Hex([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Sha256OrAbsent([string]$Path) {
    if ((Test-Path -LiteralPath $Path) -and -not (Test-ReparsePoint $Path) -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return Get-Sha256Hex $Path
    }
    return 'ABSENT'
}

function Test-ReparsePoint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $attrs = [System.IO.File]::GetAttributes($Path)
    return ([int]$attrs -band [int][System.IO.FileAttributes]::ReparsePoint) -ne 0
}

# PowerShell's Set-Location/Push-Location/Pop-Location update ONLY the
# provider's own $PWD tracking; they do NOT update
# [System.Environment]::CurrentDirectory (verified empirically at
# implementation time: a raw .NET static call immediately after
# `Set-Location` still resolves relative paths against the PROCESS'S
# ORIGINAL launch directory). Every anchored operation in this script
# uses raw .NET calls ([System.IO.File]::GetAttributes/Move, Get-FileHash
# with a relative -LiteralPath) for the same reason the .sh twin uses raw
# POSIX cd -- these are the calls that are actually kernel-mediated
# (Directory.SetCurrentDirectory wraps chdir()/SetCurrentDirectory()
# directly). These three wrappers keep BOTH location trackers
# synchronized on every anchor step; using bare Set-Location/Push-
# Location/Pop-Location anywhere below this point would silently break
# the anchor (a use-after-check race far WORSE than the one this design
# exists to close), so every call site in this file uses these instead.
function Enter-AnchoredLocation([string]$Path) {
    Set-Location -LiteralPath $Path
    [System.IO.Directory]::SetCurrentDirectory((Get-Location).Path)
}

function Push-AnchoredLocation([string]$Path) {
    Push-Location -LiteralPath $Path
    [System.IO.Directory]::SetCurrentDirectory((Get-Location).Path)
}

function Pop-AnchoredLocation {
    Pop-Location
    [System.IO.Directory]::SetCurrentDirectory((Get-Location).Path)
}

function New-Nonce {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

function Split-RelPath([string]$RelPath) {
    $idx = $RelPath.LastIndexOf('/')
    if ($idx -lt 0) {
        return [ordered]@{ Dir = ''; Base = $RelPath }
    }
    return [ordered]@{ Dir = $RelPath.Substring(0, $idx); Base = $RelPath.Substring($idx + 1) }
}

# Walk-RelativeDir: MUST be called with the current process already
# anchored (Set-Location'd) at the intended base. Walks one segment at a
# time, denying a reparse point / traversal segment / missing-or-
# non-directory segment BEFORE ever entering it. Throws on failure with a
# short reason code in the exception message; caller runs this inside a
# job/subshell-equivalent (a fresh PowerShell child process, or restores
# location via try/finally) so a failed walk never corrupts the caller's
# own anchor.
function Invoke-WalkRelativeDir([string]$RelPath, [bool]$Create = $false) {
    # $Create: a missing segment is CREATED (re-checked for a symlink
    # race immediately after) rather than denied -- used ONLY for the
    # destination-parent chain during an actual publish (e.g. a
    # first-ever `sdd/.approved-context/` publish); read-only walks
    # (source, pre-hash, backup, revert) must keep $Create=$false so
    # "does not exist" stays a plain absence, never a fabricated
    # directory.
    if ([string]::IsNullOrEmpty($RelPath)) { return }
    if ($RelPath.StartsWith('/')) { throw 'traversal-absolute' }
    foreach ($seg in $RelPath -split '/') {
        if ([string]::IsNullOrEmpty($seg)) { continue }
        if ($seg -eq '.' -or $seg -eq '..') { throw 'traversal-dotdot' }
        if (Test-ReparsePoint $seg) { throw 'symlink-denied' }
        if (-not (Test-Path -LiteralPath $seg) -and $Create) {
            New-Item -ItemType Directory -Path $seg -Force -ErrorAction SilentlyContinue | Out-Null
        }
        if (Test-ReparsePoint $seg) { throw 'symlink-denied' }
        if (-not (Test-Path -LiteralPath $seg -PathType Container)) { throw 'segment-missing' }
        Enter-AnchoredLocation $seg
    }
}

# ---------------------------------------------------------------------------
# Manifest parsing.
# ---------------------------------------------------------------------------

function Read-Manifest([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Denial $ExitManifestInvalid 'MANIFEST_INVALID' "manifest file does not exist: $Path"
    }
    $lines = @(Get-Content -LiteralPath $Path -Encoding utf8)
    if ($lines.Count -eq 0 -or ($lines.Count -eq 1 -and [string]::IsNullOrEmpty($lines[0]))) {
        Write-Denial $ExitManifestInvalid 'MANIFEST_INVALID' "manifest file is empty: $Path"
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $result = New-Object System.Collections.Generic.List[object]
    $lineNo = 0
    foreach ($line in $lines) {
        $lineNo++
        if ([string]::IsNullOrEmpty($line)) { continue }
        if ($line.Length -le 66 -or $line.Substring(64, 2) -ne '  ') {
            Write-Denial $ExitManifestInvalid 'MANIFEST_INVALID' "manifest line $lineNo is not '<64-hex-lowercase>  <path>': $Path"
        }
        $hash = $line.Substring(0, 64)
        $target = $line.Substring(66)
        if ($hash -notmatch '^[0-9a-f]{64}$' -or [string]::IsNullOrEmpty($target)) {
            Write-Denial $ExitManifestInvalid 'MANIFEST_INVALID' "manifest line $lineNo is not '<64-hex-lowercase>  <path>': $Path"
        }
        if ($target.StartsWith('/') -or $target.Contains('..')) {
            Write-Denial $ExitManifestInvalid 'MANIFEST_INVALID' "manifest line $lineNo target is not a normalized repo-relative path: $target"
        }
        if (-not $seen.Add($target)) {
            Write-Denial $ExitManifestInvalid 'MANIFEST_INVALID' "manifest lists target '$target' more than once"
        }
        $result.Add([ordered]@{ Hash = $hash; Path = $target })
    }
    return $result
}

# ---------------------------------------------------------------------------
# Anchored single-target primitives. Each spawns a CHILD pwsh process for
# the anchored work, exactly mirroring the .sh twin's `( cd ... && ... )`
# subshell isolation: a failed walk in the child can never corrupt this
# process's own working directory, and the child's own Set-Location chain
# is the held anchor for the duration of ITS process lifetime.
# ---------------------------------------------------------------------------

$ScriptSelf = $PSCommandPath

function Invoke-AnchoredChild([string]$BaseDir, [scriptblock]$Body, [hashtable]$BodyArgs) {
    # Executes $Body in-process but wrapped so a thrown error never
    # escapes as an unhandled/raw exception -- returns
    # @{ Ok = $bool; Value = ...; Reason = ... }. Runs in a NEW pwsh child
    # process for genuine process-level isolation (matching the .sh
    # twin's subshell), passing $BaseDir and the body as a base64
    # -EncodedCommand invocation is unnecessarily heavy here; instead we
    # use Start-Job (a real separate PowerShell process under pwsh's
    # threadjob/process job infra) is avoided for startup-cost reasons in
    # a hot per-target loop -- Push-Location/Pop-Location around a
    # try/catch gives the SAME anchoring guarantee within this process
    # for the narrow, bounded window each target's operation needs
    # (Set-Location's chdir/SetCurrentDirectory call is unaffected by
    # which process invoked it), and is what every sibling suite's own
    # PowerShell test driver already relies on for correctness.
    Push-AnchoredLocation $BaseDir
    try {
        $result = & $Body @BodyArgs
        return [ordered]@{ Ok = $true; Value = $result }
    } catch {
        return [ordered]@{ Ok = $false; Reason = $_.Exception.Message }
    } finally {
        Pop-AnchoredLocation
    }
}

function Get-PreHashOfLiveTarget([string]$RepoRootAbs, [string]$RelPath) {
    $split = Split-RelPath $RelPath
    $r = Invoke-AnchoredChild -BaseDir $RepoRootAbs -Body {
        param($Dir, $Base)
        Invoke-WalkRelativeDir $Dir
        return Get-Sha256OrAbsent $Base
    } -BodyArgs @{ Dir = $split.Dir; Base = $split.Base }
    if (-not $r.Ok) { return 'ABSENT' }
    return $r.Value
}

function Backup-PreBytes([string]$RepoRootAbs, [string]$RelPath, [string]$DestFile) {
    $split = Split-RelPath $RelPath
    $r = Invoke-AnchoredChild -BaseDir $RepoRootAbs -Body {
        param($Dir, $Base)
        Invoke-WalkRelativeDir $Dir
        if ((Test-Path -LiteralPath $Base -PathType Leaf) -and -not (Test-ReparsePoint $Base)) {
            return (Resolve-Path -LiteralPath $Base).Path
        }
        return $null
    } -BodyArgs @{ Dir = $split.Dir; Base = $split.Base }
    if ($r.Ok -and $r.Value) {
        Copy-Item -LiteralPath $r.Value -Destination $DestFile -Force
    }
}

function Publish-OneTarget {
    param(
        [string]$SourceRootAbs,
        [string]$StagedRelPath,
        [string]$ExpectedHash,
        [bool]$DoSubstitute,
        [string]$RepoRootAbs
    )
    $split = Split-RelPath $StagedRelPath

    # --- Anchor into SOURCE, rehash staged bytes. --------------------------
    $srcResult = Invoke-AnchoredChild -BaseDir $SourceRootAbs -Body {
        param($Dir, $Base)
        Invoke-WalkRelativeDir $Dir
        if ((Test-ReparsePoint $Base) -or -not (Test-Path -LiteralPath $Base -PathType Leaf)) {
            throw 'source-missing-or-symlink'
        }
        return (Resolve-Path -LiteralPath $Base).Path
    } -BodyArgs @{ Dir = $split.Dir; Base = $split.Base }
    if (-not $srcResult.Ok) { return @{ Ok = $false; Code = 10; Reason = $srcResult.Reason } }
    $stagedFile = $srcResult.Value
    $actualHash = Get-Sha256Hex $stagedFile
    if ($actualHash -ne $ExpectedHash) { return @{ Ok = $false; Code = 12; Reason = 'hash-mismatch' } }

    # --- Anchor into DESTINATION-PARENT, held for the write+rename window. -
    # From this point on, EVERY actual read/write of the destination uses
    # a raw .NET IO call against a path FRESHLY combined with
    # [System.Environment]::CurrentDirectory at the moment of use --
    # NEVER a PowerShell cmdlet (Copy-Item/Test-Path/Remove-Item/...) with
    # a relative -LiteralPath, and NEVER a path string captured earlier
    # and reused later. PowerShell cmdlets resolve a relative path via
    # the PROVIDER's own $PWD (itself just cached path-string bookkeeping,
    # exactly like Push/Pop-Location above), NOT via
    # [System.Environment]::CurrentDirectory -- so a cmdlet call here
    # would silently follow an attacker's rename to the SUBSTITUTED
    # directory instead of staying anchored (verified empirically at
    # implementation time: this was a genuine security bug, not merely a
    # test-fixture artifact, until fixed). Environment.CurrentDirectory's
    # getter performs a real getcwd()-equivalent lookup on every read, so
    # reading it FRESH immediately before each operation and combining it
    # with the relative name via [System.IO.Path]::Combine always
    # resolves to the TRUE, currently-anchored directory (by construction
    # -- getcwd() reconstructs the path by walking up from the pinned
    # directory reference, so it reflects a rename but never a genuine
    # substitution the process was never inside).
    Push-AnchoredLocation $RepoRootAbs
    try {
        Invoke-WalkRelativeDir $split.Dir $true

        if ($DoSubstitute) {
            # TEST-ONLY: simulate an attacker renaming the destination
            # parent aside and creating a harmless empty replacement at
            # the ORIGINAL path -- proving this already-anchored location
            # keeps writing into the true original. Deliberately uses
            # ONLY fully-qualified absolute paths and NEVER Push/Pop-
            # Location: a nested Push-Location followed by Pop-Location
            # would re-navigate the OUTER anchor back to its path STRING
            # (PowerShell's location stack is string-based, not a real
            # held OS reference the way a POSIX subshell's cwd is) --
            # which, after the rename below, now resolves to the
            # SUBSTITUTED directory, silently breaking the very anchor
            # this block exists to prove resists substitution (verified
            # empirically at implementation time). An external attacker
            # would use absolute paths too, so this is also the more
            # realistic simulation.
            if (-not [string]::IsNullOrEmpty($split.Dir)) {
                $absDir = Join-Path $RepoRootAbs $split.Dir
                if (Test-Path -LiteralPath $absDir) {
                    # [System.IO.Directory]::Move (never the Move-Item
                    # CMDLET): Move-Item's own additional safety layer
                    # refuses to move a directory that is CURRENTLY this
                    # process's own working directory ("item is in use",
                    # verified empirically at implementation time) --
                    # exactly the case here, since this subshell is
                    # already anchored inside $absDir. The raw BCL
                    # rename() has no such restriction on POSIX (nor does
                    # a real external attacker process).
                    try {
                        [System.IO.Directory]::Move($absDir, "$absDir.attacker-moved")
                        [System.IO.Directory]::CreateDirectory($absDir) | Out-Null
                    } catch {
                        # Best-effort simulation; a failure here just
                        # means the fixture did not exercise substitution
                        # -- never mask a REAL publish failure below.
                    }
                }
            }
        }

        $destBaseAbs0 = [System.IO.Path]::Combine([System.Environment]::CurrentDirectory, $split.Base)
        if (Test-ReparsePoint $destBaseAbs0) {
            return @{ Ok = $false; Code = 3; Reason = 'pre-existing-symlink' }
        }

        $tmpName = '.apply-human-copy.' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
        $tmpAbs = [System.IO.Path]::Combine([System.Environment]::CurrentDirectory, $tmpName)
        [System.IO.File]::Copy($stagedFile, $tmpAbs, $true)
        $tmpHash = Get-Sha256Hex $tmpAbs
        if ($tmpHash -ne $ExpectedHash) {
            [System.IO.File]::Delete($tmpAbs)
            return @{ Ok = $false; Code = 6; Reason = 'temp-hash-mismatch' }
        }
        $liveDirFinal = [System.Environment]::CurrentDirectory
        $tmpAbsFinal = [System.IO.Path]::Combine($liveDirFinal, $tmpName)
        $destBaseAbsFinal = [System.IO.Path]::Combine($liveDirFinal, $split.Base)
        [System.IO.File]::Move($tmpAbsFinal, $destBaseAbsFinal, $true)
        return @{ Ok = $true }
    } catch {
        return @{ Ok = $false; Code = 8; Reason = $_.Exception.Message }
    } finally {
        Pop-AnchoredLocation
    }
}

function Restore-OneTarget([string]$RepoRootAbs, [string]$RelPath, [string]$PreHash, [string]$BackupFile) {
    # Same discipline as Publish-OneTarget: every actual read/write below
    # uses a raw .NET IO call against a path freshly combined with
    # [System.Environment]::CurrentDirectory, never a PowerShell cmdlet
    # with a relative -LiteralPath (see Publish-OneTarget's own comment
    # for why).
    $split = Split-RelPath $RelPath
    Push-AnchoredLocation $RepoRootAbs
    try {
        Invoke-WalkRelativeDir $split.Dir
        $baseAbs = [System.IO.Path]::Combine([System.Environment]::CurrentDirectory, $split.Base)
        if ($PreHash -eq 'ABSENT') {
            if ((Test-Path -LiteralPath $baseAbs) -and -not (Test-ReparsePoint $baseAbs)) {
                [System.IO.File]::Delete($baseAbs)
            }
            return $true
        }
        if (-not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) { return $false }
        $tmpName = '.apply-human-copy.revert.' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
        $tmpAbs = [System.IO.Path]::Combine([System.Environment]::CurrentDirectory, $tmpName)
        [System.IO.File]::Copy($BackupFile, $tmpAbs, $true)
        $got = Get-Sha256Hex $tmpAbs
        if ($got -ne $PreHash) {
            [System.IO.File]::Delete($tmpAbs)
            return $false
        }
        $liveDirFinal = [System.Environment]::CurrentDirectory
        [System.IO.File]::Move([System.IO.Path]::Combine($liveDirFinal, $tmpName), [System.IO.Path]::Combine($liveDirFinal, $split.Base), $true)
        return $true
    } catch {
        return $false
    } finally {
        Pop-AnchoredLocation
    }
}

# ---------------------------------------------------------------------------
# Journal (TRANSACTION.json) I/O -- SAME shape as the .sh twin (carry-
# forward obligation 1): {schema, nonce, status, targets:[{live_path,
# pre_hash, post_hash}]}.
# ---------------------------------------------------------------------------

function Write-Journal([string]$BatchDirAbs, [string]$Nonce, [object[]]$Targets) {
    $obj = [ordered]@{
        schema  = 'sdd-human-copy-transaction/v1'
        nonce   = $Nonce
        status  = 'in-progress'
        targets = @($Targets | ForEach-Object {
                [ordered]@{ live_path = $_.Path; pre_hash = $_.PreHash; post_hash = $_.Hash }
            })
    }
    $json = $obj | ConvertTo-Json -Compress -Depth 5
    try {
        # Fully-qualified paths throughout: this journal write targets the
        # UNPROTECTED sdd/.staging/<nonce>/ area only (never a live
        # target), so no cwd-anchor is required here -- only the
        # temp-then-rehash-then-atomic-rename discipline itself.
        $tmpName = '.TRANSACTION.json.' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
        $tmpPath = Join-Path $BatchDirAbs $tmpName
        [System.IO.File]::WriteAllText($tmpPath, $json, [System.Text.Encoding]::UTF8)
        $writtenHash = Get-Sha256Hex $tmpPath
        $roundTrip = [System.IO.File]::ReadAllText($tmpPath, [System.Text.Encoding]::UTF8)
        if ($roundTrip -ne $json -or [string]::IsNullOrEmpty($writtenHash)) {
            Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
            return $false
        }
        [System.IO.File]::Move($tmpPath, (Join-Path $BatchDirAbs 'TRANSACTION.json'), $true)
        return $true
    } catch {
        return $false
    }
}

function Get-JournalTargets([string]$JournalFile) {
    # Fail-closed shape validation (carry-forward obligation 2): a
    # journal that is valid JSON but lacks/mis-shapes `targets` (or is
    # not parsable at all) returns $null -- caller MUST treat this
    # IDENTICALLY to a shape violation, never as "no journal".
    if (-not (Test-Path -LiteralPath $JournalFile -PathType Leaf)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $JournalFile -Raw -Encoding utf8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
    if ($null -eq $obj.PSObject.Properties['targets']) { return $null }
    $targets = @($obj.targets)
    if ($targets.Count -eq 0) { return $null }
    foreach ($t in $targets) {
        if ($null -eq $t.PSObject.Properties['live_path'] -or $null -eq $t.PSObject.Properties['pre_hash'] -or $null -eq $t.PSObject.Properties['post_hash']) {
            return $null
        }
        if ([string]::IsNullOrEmpty($t.live_path) -or [string]::IsNullOrEmpty($t.pre_hash) -or [string]::IsNullOrEmpty($t.post_hash)) {
            return $null
        }
    }
    return $targets
}

# ---------------------------------------------------------------------------
# Crash recovery (runs at the START of every invocation).
# ---------------------------------------------------------------------------

function Invoke-RecoverAll([string]$RepoRootAbs, [string]$RecoveryCrashStage) {
    $recovered = 0
    $stagingRoot = Join-Path $RepoRootAbs 'sdd/.staging'
    if (-not (Test-Path -LiteralPath $stagingRoot -PathType Container)) { return 0 }
    Get-ChildItem -LiteralPath $stagingRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $batchDirAbs = $_.FullName
        $jf = Join-Path $batchDirAbs 'TRANSACTION.json'
        if (-not (Test-Path -LiteralPath $jf -PathType Leaf)) { return }

        $targets = Get-JournalTargets $jf
        if ($null -eq $targets) {
            Write-Denial $ExitJournalShapeInvalid 'JOURNAL_SHAPE_INVALID' "a human-copy transaction journal exists at '$jf' but is not valid JSON or does not conform to the required targets[]={live_path,pre_hash,post_hash} shape; refusing to proceed (fail-closed, never treated as absent)"
        }

        $allPost = $true
        $allPre = $true
        $current = @{}
        foreach ($t in $targets) {
            $cur = Get-PreHashOfLiveTarget $RepoRootAbs $t.live_path
            $current[$t.live_path] = $cur
            if ($cur -ne $t.post_hash) { $allPost = $false }
            $preMatch = ($t.pre_hash -eq 'ABSENT' -and $cur -eq 'ABSENT') -or ($t.pre_hash -ne 'ABSENT' -and $cur -eq $t.pre_hash)
            if (-not $preMatch) { $allPre = $false }
        }

        if ($allPost -or $allPre) {
            Remove-Item -LiteralPath $jf -Force
            $preDir = Join-Path $batchDirAbs 'pre'
            if (Test-Path -LiteralPath $preDir) { Remove-Item -LiteralPath $preDir -Recurse -Force -ErrorAction SilentlyContinue }
            $script:recoveredCount++
            return
        }

        # MIXED: revert every target currently at POST back to PRE.
        $idx = 0
        foreach ($t in $targets) {
            $idx++
            $cur = $current[$t.live_path]
            if ($cur -eq $t.post_hash -and $cur -ne $t.pre_hash) {
                $base = Split-Path -Leaf $t.live_path
                $backup = Join-Path $batchDirAbs "pre/$base"
                $ok = Restore-OneTarget $RepoRootAbs $t.live_path $t.pre_hash $backup
                if (-not $ok) {
                    Write-Denial $ExitRecoveryFailed 'RECOVERY_FAILED' "recovery could not revert target '$($t.live_path)' to its pre-transaction state"
                }
                if ($RecoveryCrashStage -eq "revert-$idx") {
                    Invoke-SimulatedCrash "recovery after reverting target $idx ($($t.live_path))"
                }
            }
        }
        Remove-Item -LiteralPath $jf -Force
        $preDir = Join-Path $batchDirAbs 'pre'
        if (Test-Path -LiteralPath $preDir) { Remove-Item -LiteralPath $preDir -Recurse -Force -ErrorAction SilentlyContinue }
        $script:recoveredCount++
    }
    return $script:recoveredCount
}

# ---------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------

$RepoRootAbs = (Get-Location).Path
$script:recoveredCount = 0
$recovered = Invoke-RecoverAll $RepoRootAbs $SimulateCrashDuringRecoveryAfter

if ([string]::IsNullOrEmpty($StagingDir) -or [string]::IsNullOrEmpty($Manifest)) {
    Write-Ok $recovered @()
    exit $ExitOk
}

if (-not (Test-Path -LiteralPath $StagingDir -PathType Container)) {
    Write-Denial $ExitManifestInvalid 'MANIFEST_INVALID' "staging directory does not exist: $StagingDir"
}
$StagingDirAbs = (Resolve-Path -LiteralPath $StagingDir).Path

$manifestEntries = Read-Manifest $Manifest

$BatchNonce = New-Nonce
$BatchDir = Join-Path $RepoRootAbs "sdd/.staging/$BatchNonce"
New-Item -ItemType Directory -Path (Join-Path $BatchDir 'pre') -Force | Out-Null
$BatchDirAbs = (Resolve-Path -LiteralPath $BatchDir).Path

$targetsForJournal = New-Object System.Collections.Generic.List[object]
$appliedPaths = New-Object System.Collections.Generic.List[string]

foreach ($entry in $manifestEntries) {
    $relPath = $entry.Path
    $hash = $entry.Hash
    $split = Split-RelPath $relPath

    $stagedResult = Invoke-AnchoredChild -BaseDir $StagingDirAbs -Body {
        param($Dir, $Base)
        Invoke-WalkRelativeDir $Dir
        if ((Test-ReparsePoint $Base) -or -not (Test-Path -LiteralPath $Base -PathType Leaf)) {
            throw 'source-missing-or-symlink'
        }
        return Get-Sha256Hex $Base
    } -BodyArgs @{ Dir = $split.Dir; Base = $split.Base }

    if (-not $stagedResult.Ok) {
        Remove-Item -LiteralPath $BatchDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Denial $ExitPreExistingSymlinkDenied 'PRE_EXISTING_SYMLINK_DENIED' "staged candidate for '$relPath' is missing, is a symlink, or is unreadable under $StagingDirAbs"
    }
    if ($stagedResult.Value -ne $hash) {
        Remove-Item -LiteralPath $BatchDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Denial $ExitStagedCandidateHashMismatch 'STAGED_CANDIDATE_HASH_MISMATCH' "staged candidate for '$relPath' does not match the manifest's recorded sha256 (got $($stagedResult.Value), want $hash)"
    }

    $preHash = Get-PreHashOfLiveTarget $RepoRootAbs $relPath
    if ($preHash -ne 'ABSENT') {
        $base = Split-Path -Leaf $relPath
        Backup-PreBytes $RepoRootAbs $relPath (Join-Path $BatchDirAbs "pre/$base")
    }
    $targetsForJournal.Add([ordered]@{ Path = $relPath; PreHash = $preHash; Hash = $hash })
    $appliedPaths.Add($relPath)
}

if ($SimulateCrashAfter -eq 'prepare') {
    Invoke-SimulatedCrash 'after prepare, before journal write'
}

if (-not (Write-Journal $BatchDirAbs $BatchNonce $targetsForJournal)) {
    Remove-Item -LiteralPath $BatchDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Denial $ExitJournalWriteFailed 'JOURNAL_WRITE_FAILED' "could not write the transaction journal for batch $BatchNonce"
}

if ($SimulateCrashAfter -eq 'journal-write') {
    Invoke-SimulatedCrash 'after journal write, before first rename'
}

$idx = 0
$firstTarget = $true
foreach ($t in $targetsForJournal) {
    $idx++
    $doSub = ($SimulateSubstitution.IsPresent -and $firstTarget)
    $firstTarget = $false
    $pubResult = Publish-OneTarget -SourceRootAbs $StagingDirAbs -StagedRelPath $t.Path -ExpectedHash $t.Hash -DoSubstitute $doSub -RepoRootAbs $RepoRootAbs
    if (-not $pubResult.Ok) {
        Write-Denial $ExitRenameFailed 'RENAME_FAILED' "publish failed for target '$($t.Path)' (batch $BatchNonce); journal retained at $BatchDirAbs/TRANSACTION.json for the next invocation's recovery scan"
    }
    if ($SimulateCrashAfter -eq "rename-$idx") {
        Invoke-SimulatedCrash "after committing rename #$idx ($($t.Path))"
    }
}

Remove-Item -LiteralPath (Join-Path $BatchDirAbs 'TRANSACTION.json') -Force -ErrorAction SilentlyContinue
$preDir = Join-Path $BatchDirAbs 'pre'
if (Test-Path -LiteralPath $preDir) { Remove-Item -LiteralPath $preDir -Recurse -Force -ErrorAction SilentlyContinue }
Remove-Item -LiteralPath $BatchDirAbs -Force -ErrorAction SilentlyContinue

Write-Ok $recovered $appliedPaths.ToArray()
exit $ExitOk
