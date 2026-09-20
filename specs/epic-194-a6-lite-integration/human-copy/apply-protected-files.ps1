# apply-protected-files.ps1 (epic-194-a6-lite-integration)
#
# Feature-scoped human-copy application runner (T-001, REQ-002/REQ-005 share,
# AC-010/AC-031). Hard-anchored to this feature's own
# `specs/epic-194-a6-lite-integration/human-copy` prefix -- never the
# Epic-136 prefix (design.md Protected-File Statement, "Feature-scoped, not
# fixed-prefix"). Mirrors the discipline of
# `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
# (Get-CanonicalTargets / Get-ManifestDigests / VerifyPublished /
# Invoke-PostInstallVerification) against this feature's own, much smaller,
# five-target payload (the four design.md Protected-File Statement names
# plus the CI-workflow candidate tasks.md item 3 commits this runner to
# applying the same way, AC-010/AC-031 widened 2026-08-21) -- it does not
# call into that runner.
#
# Contract implemented (design.md Protected-File Statement, four points):
#   1. Feature-scoped, not fixed-prefix target/digest resolution.
#   2. Three-way exact-set verification: declared payload list ==
#      MANIFEST.sha256's own target set == the staged directory's own
#      payload file set (control files -- MANIFEST.sha256 and this runner
#      script itself -- excluded by construction, investigation.md
#      INV-020, "Payload file set, defined").
#   3. Per-target sha256 verification against MANIFEST.sha256 BEFORE any
#      copy is attempted.
#   4. Post-copy re-verification of every installed file's own hash against
#      the staged/manifest hash.
#
# Security-hardened (resume run a6-t001-resume-20260808T125638Z; promoted
# from the reviewed candidate at specs/epic-194-a6-lite-integration/drafts/
# apply-protected-files.ps1 to this canonical path once the R-10 guard's
# human-copy staging exemption was re-confirmed -- see this task's own
# implementation report for the re-measurement): ordinal (not
# culture-sensitive) string comparisons throughout; canonical-anchor
# containment checks against every path ancestor plus a handle-relative,
# no-follow native publisher on both POSIX and Windows so neither a
# destination-parent symlink substitution nor a TOCTOU race can redirect a
# write outside the repository root; staged payload enumeration is
# recursive and a nested `PROPOSED/` subtree is explicitly rejected
# (payload, never an implicitly ignored control subtree). Independent
# security review: PASS (Critical 0 / High 0,
# specs/epic-194-a6-lite-integration/verification/T-001/security-review.md).
#
# Functions below are intentionally separable (dot-sourceable) so the test
# suite can exercise each contract point in isolation, including simulating
# a post-copy corruption between Copy-Payload and Test-PostCopyHashes --
# the real end-to-end flow (Invoke-ApplyProtectedFiles) always runs all
# four points in order.

[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Feature-scoped prefix (never the Epic-136 prefix, contract point 1).
$Script:HumanCopyPrefix = 'specs/epic-194-a6-lite-integration/human-copy'

# The five declared payload targets: the four design.md Protected-File
# Statement names, plus the CI-workflow candidate tasks.md's own Protected
# Files item 3 commits this runner to applying "the same way it applies
# the four payload files" (acceptance-tests.md AC-010/AC-031, widened
# 2026-08-21 to resolve the four-target/fifth-target contradiction two
# independent cross-model T-001 reviews converged on: item 3 said the
# runner applies this fifth candidate the same way as the other four, but
# it was never one of $Script:DeclaredTargets and had no MANIFEST.sha256
# entry, so it got none of the pre-copy hash check, atomic publish, or
# post-copy re-verification the other four targets get -- it was applied
# by a bare, unverified `cp` instead, exactly what this runner's own
# contract point 4 and design.md's STRIDE row B5 exist to forbid). This is
# an ordinary declared target, not a special case: every check below
# (Test-ExactSet, Test-ManifestHashes, Copy-Payload, Test-PostCopyHashes)
# applies to it identically.
$Script:DeclaredTargets = @(
    'plugins/sdd-lite/references/risk-upgrade-policy.md',
    'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
    'plugins/sdd-lite/scripts/check-risk-upgrade.ps1',
    'plugins/sdd-lite/skills/lite-spec/SKILL.md',
    '.github/workflows/test.yml'
)

# Control files excluded from the payload-set comparison by construction
# (investigation.md INV-020, "Payload file set, defined"). Matched by their
# path relative to the human-copy root.
$Script:ControlFileRelativePaths = @(
    'MANIFEST.sha256',
    'apply-protected-files.ps1'
)

# Publish-state tracking for the failure path (design.md Protected-File
# Statement point 5). Publishes are per-target and the batch is NOT
# transactional, so a failure on the Nth target leaves 1..N-1 installed. Before
# this, the runner exited naming ONLY the failing target: an operator had no
# way to learn from the output which files were already live, and because
# `Fail` throws out of Copy-Payload, Test-PostCopyHashes never ran either --
# so a partial application was left both unenumerated and unverified. That is
# the state the four-point contract exists to prevent.
$Script:PublishedTargets = New-Object System.Collections.Generic.List[string]
$Script:FailedTarget = $null
$Script:CopyPhaseStarted = $false

function Fail {
    param([Parameter(Mandatory)][string]$Message)
    throw "apply-protected-files(epic-194-a6): $Message"
}

# Emitted from the ENTRY-POINT catch rather than from Fail or from
# Copy-Payload's own catch blocks. Why there:
#   * NOT in `Fail` -- roughly twenty call sites reach Fail, and nearly all of
#     them (Assert-AnchoredPath, Test-ExactSet, Test-ManifestHashes) fire
#     BEFORE any copy is attempted. Reporting publish state from those would
#     attach an install report to failures where nothing was installed.
#   * NOT in Copy-Payload's three catch blocks -- it would have to be repeated
#     in each, and it would still miss the case where Copy-Payload SUCCEEDS
#     and Test-PostCopyHashes then fails, which is a fully-applied batch with
#     a corrupt member: the operator needs the enumeration there too.
#   * The entry-point catch sees every failure after the copy phase began, in
#     one place, and `Fail` stays a pure thrower.
function Write-PublishStateReport {
    if (-not $Script:CopyPhaseStarted) {
        [Console]::Error.WriteLine('apply-protected-files(epic-194-a6): live state: no live file was modified (failure occurred before the copy phase began).')
        return
    }
    $published = @($Script:PublishedTargets)
    $failed = $Script:FailedTarget
    $notAttempted = @($Script:DeclaredTargets | Where-Object {
        $_ -notin $published -and $_ -ne $failed
    })

    [Console]::Error.WriteLine('apply-protected-files(epic-194-a6): live state after this partial run --')
    if ($published.Count -gt 0) {
        foreach ($t in $published) {
            [Console]::Error.WriteLine("  INSTALLED     $t")
        }
    } else {
        [Console]::Error.WriteLine('  INSTALLED     (none)')
    }
    if ($null -ne $failed) {
        [Console]::Error.WriteLine("  FAILED        $failed")
    }
    foreach ($t in $notAttempted) {
        [Console]::Error.WriteLine("  NOT ATTEMPTED $t")
    }
    if ($published.Count -gt 0) {
        [Console]::Error.WriteLine('apply-protected-files(epic-194-a6): the INSTALLED files above are LIVE and were not rolled back; each was published atomically and its published digest verified. Re-run this runner after fixing the cause -- re-applying an already-correct target is a no-op.')
    }
}

function Get-PathStringComparison {
    if ($IsWindows) { return [StringComparison]::OrdinalIgnoreCase }
    return [StringComparison]::Ordinal
}

function Test-IsControlRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)
    foreach ($controlPath in $Script:ControlFileRelativePaths) {
        if ([string]::Equals($RelativePath, $controlPath, [StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

function Test-IsLinkOrReparsePoint {
    param([Parameter(Mandatory)]$Item)
    $linkProperty = $Item.PSObject.Properties['LinkType']
    if ($null -ne $linkProperty -and -not [string]::IsNullOrEmpty([string]$linkProperty.Value)) {
        return $true
    }
    return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-AnchoredPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Candidate,
        [Parameter(Mandatory)][string]$Label,
        [ValidateSet('Any', 'Leaf', 'Container')][string]$RequiredType = 'Any',
        [switch]$AllowMissingLeaf
    )

    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $candidateFull = [IO.Path]::GetFullPath($Candidate)
    $comparison = Get-PathStringComparison
    $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not [string]::Equals($candidateFull, $rootFull, $comparison) -and
        -not $candidateFull.StartsWith($rootPrefix, $comparison)) {
        Fail "$Label escapes canonical root: $candidateFull (root $rootFull)"
    }

    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
        Fail "$Label anchor root does not exist: $rootFull"
    }
    $rootItem = Get-Item -LiteralPath $rootFull -Force -ErrorAction Stop
    if (Test-IsLinkOrReparsePoint $rootItem) {
        Fail "$Label anchor root is a symlink/reparse point: $rootFull"
    }

    $relative = [IO.Path]::GetRelativePath($rootFull, $candidateFull)
    [string[]]$segments = @()
    if (-not [string]::Equals($relative, '.', [StringComparison]::Ordinal)) {
        $segments = @($relative -split '[\\/]' | Where-Object { $_ -ne '' })
    }
    $cursor = $rootFull
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $cursor = Join-Path $cursor $segments[$index]
        $isLeafSegment = ($index -eq ($segments.Count - 1))
        if (-not (Test-Path -LiteralPath $cursor)) {
            if ($AllowMissingLeaf -and $isLeafSegment) { continue }
            Fail "$Label path component does not exist: $cursor"
        }
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (Test-IsLinkOrReparsePoint $item) {
            Fail "$Label has a symlink/reparse-point ancestor: $cursor"
        }
    }

    if ($RequiredType -eq 'Leaf' -and -not (Test-Path -LiteralPath $candidateFull -PathType Leaf)) {
        Fail "$Label must be an existing regular file: $candidateFull"
    }
    if ($RequiredType -eq 'Container' -and -not (Test-Path -LiteralPath $candidateFull -PathType Container)) {
        Fail "$Label must be an existing directory: $candidateFull"
    }
    return $candidateFull
}

function Get-RepositoryRoot {
    if ($RepositoryRoot) {
        return Assert-AnchoredPath -Root $RepositoryRoot -Candidate $RepositoryRoot -Label 'RepositoryRoot' -RequiredType Container
    }
    $current = Split-Path -Parent $PSCommandPath
    for ($i = 0; $i -lt 20; $i++) {
        if (Test-Path -LiteralPath (Join-Path $current 'AGENTS.md') -PathType Leaf) {
            return (Resolve-Path -LiteralPath $current).Path.TrimEnd('/', '\')
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    Fail 'unable to locate repository root (no AGENTS.md found above runner path)'
}

function Get-NormalizedRelativePath {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$FullPath)
    return ([IO.Path]::GetRelativePath($Root, $FullPath) -replace '\\', '/')
}

function Get-OrdinalSet {
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    return ,$set
}

function Get-PayloadFileSet {
    param([Parameter(Mandatory)][string]$HumanCopyRoot)
    $root = Assert-AnchoredPath -Root $HumanCopyRoot -Candidate $HumanCopyRoot -Label 'human-copy root' -RequiredType Container
    $entries = @(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction Stop)
    foreach ($entry in $entries) {
        if (Test-IsLinkOrReparsePoint $entry) {
            Fail "staged tree contains a symlink/reparse point: $(Get-NormalizedRelativePath $root $entry.FullName)"
        }
    }

    $payload = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @($entries | Where-Object { -not $_.PSIsContainer })) {
        $rel = Get-NormalizedRelativePath $root $entry.FullName
        if ($rel.StartsWith('PROPOSED/', [StringComparison]::Ordinal)) {
            Fail "staged payload uses reserved PROPOSED/ subtree; PROPOSED/ is recursively enumerated payload, not a control subtree: $rel"
        }
        if (Test-IsControlRelativePath $rel) { continue }
        [void]$payload.Add($rel)
    }
    $result = $payload.ToArray()
    [Array]::Sort($result, [StringComparer]::Ordinal)
    return $result
}

function Get-ManifestTargets {
    param([Parameter(Mandatory)][string]$ManifestPath)
    $manifestRoot = Split-Path -Parent $ManifestPath
    [void](Assert-AnchoredPath -Root $manifestRoot -Candidate $ManifestPath -Label 'MANIFEST.sha256' -RequiredType Leaf)
    $content = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop
    if ($null -eq $content) { $content = '' }
    $content = $content.Replace("`r`n", "`n")
    if ($content.Contains("`r")) { Fail 'MANIFEST.sha256 contains a bare carriage return' }

    $digests = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($line in @($content -split "`n" | Where-Object { $_ -ne '' })) {
        $match = [regex]::Match($line, '^([0-9a-f]{64})  (.+)$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
        if (-not $match.Success) {
            Fail "MANIFEST.sha256 line is not lowercase two-space sha256 format: $line"
        }
        $digest = $match.Groups[1].Value
        $target = $match.Groups[2].Value
        $parts = @($target -split '/')
        if ($target.StartsWith('/', [StringComparison]::Ordinal) -or $target.Contains('\') -or
            $target.Contains(':') -or @($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0) {
            Fail "MANIFEST.sha256 target is not a normalized repository-relative path: $target"
        }
        if ($digests.ContainsKey($target)) {
            Fail "MANIFEST.sha256 has a duplicate target: $target"
        }
        $digests.Add($target, $digest)
    }
    return $digests
}

function Test-ExactSet {
    param(
        [Parameter(Mandatory)][string[]]$Declared,
        [Parameter(Mandatory)]$ManifestDigests,
        [Parameter(Mandatory)][string[]]$PayloadSet
    )
    $declaredSet = Get-OrdinalSet
    $manifestSet = Get-OrdinalSet
    $payloadSetHash = Get-OrdinalSet
    foreach ($target in $Declared) { [void]$declaredSet.Add($target) }
    foreach ($target in $ManifestDigests.Keys) { [void]$manifestSet.Add($target) }
    foreach ($target in $PayloadSet) { [void]$payloadSetHash.Add($target) }

    $extraManifest = @($manifestSet | Where-Object { -not $declaredSet.Contains($_) })
    $missingManifest = @($declaredSet | Where-Object { -not $manifestSet.Contains($_) })
    $extraPayload = @($payloadSetHash | Where-Object { -not $declaredSet.Contains($_) })
    $missingPayload = @($declaredSet | Where-Object { -not $payloadSetHash.Contains($_) })
    if ($extraManifest.Count) { Fail "MANIFEST.sha256 declares an undeclared target: $($extraManifest -join ', ')" }
    if ($missingManifest.Count) { Fail "MANIFEST.sha256 is missing a declared target: $($missingManifest -join ', ')" }
    if ($extraPayload.Count) { Fail "staged payload contains an undeclared path outside the declared target set: $($extraPayload -join ', ')" }
    if ($missingPayload.Count) { Fail "staged payload is missing a declared target: $($missingPayload -join ', ')" }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$NativePublisherSource = @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class A6AnchoredPublisher
{
    private const int FILE_ATTRIBUTE_TAG_INFO_CLASS = 9;
    private const int FILE_RENAME_INFO = 3;
    private const int FILE_RENAME_INFORMATION = 10;
    private const uint FILE_READ_DATA = 0x0001;
    private const uint FILE_WRITE_DATA = 0x0002;
    private const uint FILE_APPEND_DATA = 0x0004;
    private const uint FILE_LIST_DIRECTORY = 0x0001;
    private const uint FILE_ADD_FILE = 0x0002;
    private const uint FILE_ADD_SUBDIRECTORY = 0x0004;
    private const uint FILE_READ_ATTRIBUTES = 0x0080;
    private const uint DELETE = 0x00010000;
    private const uint SYNCHRONIZE = 0x00100000;
    private const uint FILE_SHARE_READ = 0x1;
    private const uint FILE_SHARE_WRITE = 0x2;
    private const uint FILE_OPEN = 1;
    private const uint FILE_CREATE = 2;
    private const uint FILE_DIRECTORY_FILE = 0x1;
    private const uint FILE_NON_DIRECTORY_FILE = 0x40;
    private const uint FILE_SYNCHRONOUS_IO_NONALERT = 0x20;
    private const uint FILE_OPEN_REPARSE_POINT = 0x00200000;
    private const uint FILE_ATTRIBUTE_NORMAL = 0x80;
    private const uint FILE_ATTRIBUTE_DIRECTORY = 0x10;
    private const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
    private const uint OBJ_CASE_INSENSITIVE = 0x40;
    private const uint OPEN_EXISTING = 3;
    private const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
    private const uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;

    [StructLayout(LayoutKind.Sequential)] private struct UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
    [StructLayout(LayoutKind.Sequential)] private struct OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }
    [StructLayout(LayoutKind.Sequential)] private struct IO_STATUS_BLOCK { public IntPtr Status; public UIntPtr Information; }
    [StructLayout(LayoutKind.Sequential)] private struct FILE_ATTRIBUTE_TAG_INFO { public uint FileAttributes; public uint ReparseTag; }

    [DllImport("libc", SetLastError = true)] private static extern int open(string path, int flags, int mode);
    [DllImport("libc", SetLastError = true)] private static extern int openat(int dirfd, string path, int flags, int mode);
    [DllImport("libc", SetLastError = true)] private static extern int renameat(int olddirfd, string oldpath, int newdirfd, string newpath);
    [DllImport("libc", SetLastError = true)] private static extern int unlinkat(int dirfd, string path, int flags);
    [DllImport("libc", SetLastError = true)] private static extern int fsync(int fd);
    [DllImport("libc", SetLastError = true)] private static extern int fchmod(int fd, uint mode);
    // symlinkat is not called by any production code path in this file --
    // grep alone will make it look dead. It is load-bearing for the
    // deterministic TOCTOU regression fixture in
    // tests/human-copy-runner-contract.tests.ps1 (TEST-009d), which patches a
    // disposable copy of this source at the TEST_FIXTURE_BEFORE_POSIX_DIRECTORY_OPEN
    // marker below to substitute a destination-parent segment with a symlink
    // mid-resolution and assert the handle-relative, O_NOFOLLOW open still
    // rejects it. Do not remove it as unused without first checking that
    // fixture (T-001 Anthropic-panelist review, Minor: this was reported as
    // dead code; it is not -- removing it silently drops TEST-009d/e/f/g's
    // only way to inject the substitution).
    [DllImport("libc", SetLastError = true)] private static extern int symlinkat(string target, int newdirfd, string linkpath);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);
    [DllImport("ntdll.dll", EntryPoint = "NtCreateFile")]
    private static extern int NtCreateFile(out SafeFileHandle handle, uint access, ref OBJECT_ATTRIBUTES attributes, out IO_STATUS_BLOCK status, IntPtr allocationSize, uint fileAttributes, uint share, uint disposition, uint options, IntPtr eaBuffer, uint eaLength);
    [DllImport("ntdll.dll")] private static extern uint RtlNtStatusToDosError(int status);
    [DllImport("ntdll.dll", EntryPoint = "NtSetInformationFile")]
    private static extern int NtSetInformationFile(SafeFileHandle handle, out IO_STATUS_BLOCK status, IntPtr information, uint length, int informationClass);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandleEx(SafeFileHandle handle, int infoClass, out FILE_ATTRIBUTE_TAG_INFO info, uint size);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetFileInformationByHandle(SafeFileHandle handle, int infoClass, IntPtr info, uint size);

    public static void CopyOne(string root, string sourceRelative, string destinationRelative, string expectedDigest, bool isMac)
    {
        ValidatePath(sourceRelative); ValidatePath(destinationRelative);
        if (String.IsNullOrEmpty(expectedDigest) || expectedDigest.Length != 64) throw new InvalidDataException("invalid expected digest");
        if (Environment.OSVersion.Platform == PlatformID.Win32NT) CopyOneWindows(root, sourceRelative, destinationRelative, expectedDigest);
        else CopyOneUnix(root, sourceRelative, destinationRelative, expectedDigest, isMac);
    }

    private static void CopyOneUnix(string root, string sourceRelative, string destinationRelative, string digest, bool isMac)
    {
        int noFollow = isMac ? 0x100 : 0x20000;
        int directory = isMac ? 0x100000 : 0x10000;
        int closeExec = isMac ? 0x1000000 : 0x80000;
        int create = isMac ? 0x200 : 0x40;
        int exclusive = isMac ? 0x800 : 0x80;
        SafeFileHandle rootHandle = UnixHandle(open(root, noFollow | directory | closeExec, 0), "open repository root");
        SafeFileHandle sourceParent = null, source = null, destinationParent = null, temporary = null;
        string temporaryLeaf = ".sdd-a6-" + Guid.NewGuid().ToString("N") + ".tmp";
        bool renamed = false;
        try {
            string sourceLeaf;
            sourceParent = OpenUnixParent(rootHandle, sourceRelative, noFollow | directory | closeExec, false, out sourceLeaf);
            source = UnixHandle(openat(Fd(sourceParent), sourceLeaf, noFollow | closeExec, 0), "open staged source without following links");
            if (!String.Equals(Hash(source), digest, StringComparison.Ordinal)) throw new InvalidDataException("staged payload changed after pre-copy verification: " + sourceRelative);
            string destinationLeaf;
            destinationParent = OpenUnixParent(rootHandle, destinationRelative, noFollow | directory | closeExec, true, out destinationLeaf);
            temporary = UnixHandle(openat(Fd(destinationParent), temporaryLeaf, 2 | create | exclusive | noFollow | closeExec, 384), "create anchored temporary");
            Copy(source, temporary);
            uint mode = SourceMode(source);
            if (fchmod(Fd(temporary), mode) != 0) ThrowUnix("preserve source mode");
            if (fsync(Fd(temporary)) != 0) ThrowUnix("flush anchored temporary");
            if (!String.Equals(Hash(temporary), digest, StringComparison.Ordinal)) throw new InvalidDataException("temporary digest mismatch: " + destinationRelative);
            temporary.Dispose(); temporary = null;
            if (renameat(Fd(destinationParent), temporaryLeaf, Fd(destinationParent), destinationLeaf) != 0) ThrowUnix("publish anchored temporary");
            renamed = true;
            using (SafeFileHandle installed = UnixHandle(openat(Fd(destinationParent), destinationLeaf, noFollow | closeExec, 0), "reopen published target without following links"))
                if (!String.Equals(Hash(installed), digest, StringComparison.Ordinal)) throw new InvalidDataException("published digest mismatch: " + destinationRelative);
        }
        finally {
            if (temporary != null) temporary.Dispose();
            if (!renamed && destinationParent != null) unlinkat(Fd(destinationParent), temporaryLeaf, 0);
            if (destinationParent != null) destinationParent.Dispose();
            if (source != null) source.Dispose();
            if (sourceParent != null) sourceParent.Dispose();
            rootHandle.Dispose();
        }
    }

    // fixtureDestination is not read by this method's own body -- it exists
    // so tests/human-copy-runner-contract.tests.ps1's TEST-009d fixture can
    // patch the TEST_FIXTURE_BEFORE_POSIX_DIRECTORY_OPEN marker below with a
    // conditional keyed on it, distinguishing a destination-parent open (the
    // one under TOCTOU test) from a source-parent open. Not dead: see the
    // symlinkat comment above.
    private static SafeFileHandle OpenUnixParent(SafeFileHandle root, string path, int flags, bool fixtureDestination, out string leaf)
    {
        string[] parts = path.Split('/'); leaf = parts[parts.Length - 1];
        SafeFileHandle current = new SafeFileHandle(root.DangerousGetHandle(), false);
        bool owns = false;
        try {
            for (int i = 0; i < parts.Length - 1; i++) {
                string segment = parts[i];
                // TEST_FIXTURE_BEFORE_POSIX_DIRECTORY_OPEN
                SafeFileHandle next = UnixHandle(openat(Fd(current), segment, flags, 0), "open directory segment without following links: " + segment);
                if (owns) current.Dispose(); current = next; owns = true;
            }
            owns = false; return current;
        }
        finally { if (owns) current.Dispose(); }
    }

    private static void CopyOneWindows(string root, string sourceRelative, string destinationRelative, string digest)
    {
        SafeFileHandle rootHandle = CreateFileW(root, FILE_LIST_DIRECTORY | FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, IntPtr.Zero);
        ValidateWindowsHandle(rootHandle, true, "repository root");
        SafeFileHandle sourceParent = null, source = null, destinationParent = null, temporary = null;
        string temporaryLeaf = ".sdd-a6-" + Guid.NewGuid().ToString("N") + ".tmp";
        try {
            string sourceLeaf; sourceParent = OpenWindowsParent(rootHandle, sourceRelative, false, out sourceLeaf);
            source = OpenWindowsRelative(sourceParent, sourceLeaf, FILE_READ_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ, FILE_OPEN, FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, false, "open staged source");
            if (!String.Equals(Hash(source), digest, StringComparison.Ordinal)) throw new InvalidDataException("staged payload changed after pre-copy verification: " + sourceRelative);
            string destinationLeaf; destinationParent = OpenWindowsParent(rootHandle, destinationRelative, true, out destinationLeaf);
            temporary = OpenWindowsRelative(destinationParent, temporaryLeaf, FILE_READ_DATA | FILE_WRITE_DATA | FILE_APPEND_DATA | FILE_READ_ATTRIBUTES | DELETE | SYNCHRONIZE, 0, FILE_CREATE, FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, false, "create anchored temporary");
            Copy(source, temporary);
            if (!String.Equals(Hash(temporary), digest, StringComparison.Ordinal)) throw new InvalidDataException("temporary digest mismatch: " + destinationRelative);
            RenameWindows(temporary, destinationParent, destinationLeaf);
            temporary.Dispose(); temporary = null;
            using (SafeFileHandle installed = OpenWindowsRelative(destinationParent, destinationLeaf, FILE_READ_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ, FILE_OPEN, FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, false, "verify published target"))
                if (!String.Equals(Hash(installed), digest, StringComparison.Ordinal)) throw new InvalidDataException("published digest mismatch: " + destinationRelative);
        }
        finally {
            if (temporary != null) temporary.Dispose();
            if (destinationParent != null) destinationParent.Dispose();
            if (source != null) source.Dispose();
            if (sourceParent != null) sourceParent.Dispose();
            rootHandle.Dispose();
        }
    }

    // fixtureDestination: see the identical note on OpenUnixParent -- the
    // Windows twin of the same TEST-009d fixture patches the WINDOWS
    // directory-open seam marker below the same way. (The marker's literal
    // name must appear ONLY at the seam line itself: the suite's injection
    // is a plain substring replace, and a second occurrence in prose --
    // this comment's earlier wording had one -- gets the seam body spliced
    // into the space between methods, where its leading 'if' is CS1519,
    // measured on the first-ever Windows CI execution of this suite.)
    private static SafeFileHandle OpenWindowsParent(SafeFileHandle root, string path, bool fixtureDestination, out string leaf)
    {
        string[] parts = path.Split('/'); leaf = parts[parts.Length - 1];
        SafeFileHandle current = new SafeFileHandle(root.DangerousGetHandle(), false); bool owns = false;
        try {
            for (int i = 0; i < parts.Length - 1; i++) {
                // TEST_FIXTURE_BEFORE_DIRECTORY_OPEN_WINDOWS
                SafeFileHandle next = OpenWindowsRelative(current, parts[i], FILE_LIST_DIRECTORY | FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ | FILE_SHARE_WRITE, FILE_OPEN, FILE_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, true, "open anchored directory");
                if (owns) current.Dispose(); current = next; owns = true;
            }
            owns = false; return current;
        }
        finally { if (owns) current.Dispose(); }
    }

    private static SafeFileHandle OpenWindowsRelative(SafeFileHandle parent, string leaf, uint access, uint share, uint disposition, uint options, bool directory, string context)
    {
        ValidateLeaf(leaf); IntPtr name = IntPtr.Zero, unicodePtr = IntPtr.Zero; bool added = false; SafeFileHandle handle;
        try {
            name = Marshal.StringToHGlobalUni(leaf);
            UNICODE_STRING unicode = new UNICODE_STRING { Length = checked((ushort)(leaf.Length * 2)), MaximumLength = checked((ushort)((leaf.Length + 1) * 2)), Buffer = name };
            unicodePtr = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UNICODE_STRING))); Marshal.StructureToPtr(unicode, unicodePtr, false);
            parent.DangerousAddRef(ref added);
            OBJECT_ATTRIBUTES attrs = new OBJECT_ATTRIBUTES { Length = Marshal.SizeOf(typeof(OBJECT_ATTRIBUTES)), RootDirectory = parent.DangerousGetHandle(), ObjectName = unicodePtr, Attributes = OBJ_CASE_INSENSITIVE };
            IO_STATUS_BLOCK io; int status = NtCreateFile(out handle, access, ref attrs, out io, IntPtr.Zero, FILE_ATTRIBUTE_NORMAL, share, disposition, options, IntPtr.Zero, 0);
            if (status < 0) { if (handle != null) handle.Dispose(); uint error = RtlNtStatusToDosError(status); throw new IOException(context + " failed", new Win32Exception(unchecked((int)error))); }
            ValidateWindowsHandle(handle, directory, context); return handle;
        }
        finally { if (added) parent.DangerousRelease(); if (unicodePtr != IntPtr.Zero) Marshal.FreeHGlobal(unicodePtr); if (name != IntPtr.Zero) Marshal.FreeHGlobal(name); }
    }

    private static void ValidateWindowsHandle(SafeFileHandle handle, bool directory, string context)
    {
        if (handle == null || handle.IsInvalid) throw new IOException(context + " returned an invalid handle");
        FILE_ATTRIBUTE_TAG_INFO info;
        if (!GetFileInformationByHandleEx(handle, FILE_ATTRIBUTE_TAG_INFO_CLASS, out info, (uint)Marshal.SizeOf(typeof(FILE_ATTRIBUTE_TAG_INFO)))) throw new IOException(context + " attribute inspection failed", new Win32Exception(Marshal.GetLastWin32Error()));
        if ((info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) throw new IOException(context + " is a symlink/reparse point");
        if (((info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) != directory) throw new IOException(context + " has the wrong file type");
    }

    private static void RenameWindows(SafeFileHandle source, SafeFileHandle parent, string leaf)
    {
        byte[] name = Encoding.Unicode.GetBytes(leaf); int rootOffset = IntPtr.Size == 8 ? 8 : 4; int lengthOffset = rootOffset + IntPtr.Size; int nameOffset = lengthOffset + 4; int size = (IntPtr.Size == 8 ? 24 : 16) + name.Length;
        IntPtr buffer = Marshal.AllocHGlobal(size); bool added = false;
        try {
            for (int i = 0; i < size; i++) Marshal.WriteByte(buffer, i, 0); Marshal.WriteInt32(buffer, 0, 1);
            parent.DangerousAddRef(ref added); Marshal.WriteIntPtr(buffer, rootOffset, parent.DangerousGetHandle()); Marshal.WriteInt32(buffer, lengthOffset, name.Length); Marshal.Copy(name, 0, IntPtr.Add(buffer, nameOffset), name.Length);
            if (!SetFileInformationByHandle(source, FILE_RENAME_INFO, buffer, (uint)size)) { int error = Marshal.GetLastWin32Error(); if (error != 87) throw new Win32Exception(error); IO_STATUS_BLOCK io; int status = NtSetInformationFile(source, out io, buffer, (uint)size, FILE_RENAME_INFORMATION); if (status < 0) throw new IOException("NtSetInformationFile rename failed"); }
        }
        finally { if (added) parent.DangerousRelease(); Marshal.FreeHGlobal(buffer); }
    }

    private static void Copy(SafeFileHandle source, SafeFileHandle destination)
    {
        using (FileStream input = Borrow(source, FileAccess.Read)) using (FileStream output = Borrow(destination, FileAccess.ReadWrite)) { input.Position = 0; output.Position = 0; output.SetLength(0); input.CopyTo(output, 65536); output.Flush(true); input.Position = 0; output.Position = 0; }
    }
    private static string Hash(SafeFileHandle handle) { using (FileStream stream = Borrow(handle, FileAccess.Read)) using (SHA256 sha = SHA256.Create()) { stream.Position = 0; byte[] value = sha.ComputeHash(stream); stream.Position = 0; return BitConverter.ToString(value).Replace("-", String.Empty).ToLowerInvariant(); } }
    private static FileStream Borrow(SafeFileHandle handle, FileAccess access) { bool added = false; try { handle.DangerousAddRef(ref added); return new FileStream(new SafeFileHandle(handle.DangerousGetHandle(), false), access, 65536, false); } finally { if (added) handle.DangerousRelease(); } }
    private static int Fd(SafeFileHandle handle) { return handle.DangerousGetHandle().ToInt32(); }
    private static SafeFileHandle UnixHandle(int fd, string context) { if (fd < 0) ThrowUnix(context); return new SafeFileHandle(new IntPtr(fd), true); }
    private static void ThrowUnix(string context) { int error = Marshal.GetLastWin32Error(); throw new IOException(context + " failed (errno " + error + ")", new Win32Exception(error)); }
    // Reads the source file's own POSIX permission bits through the .NET
    // runtime's own File.GetUnixFileMode(SafeFileHandle) rather than by
    // hand-parsing an fstat(2) buffer at a fixed byte offset.
    //
    // T-001 Anthropic-panelist review, Major: the previous implementation
    // read st_mode via a hand-derived struct-stat byte offset (Marshal dot
    // ReadInt32, buffer, offset 24) for every non-macOS Unix. Offset 24 is
    // where st_mode lives ONLY in the x86-64 glibc
    // struct stat (dev 8 / ino 8 / nlink 8 / mode 4 ahead of it) --
    // confirmed against a live x86-64 glibc build (verification/T-001/
    // stat-offsets.log: st_mode=24, st_nlink=16, st_uid=28). On aarch64
    // Linux the kernel's asm-generic struct stat layout applies instead
    // (dev 8 / ino 8 / mode 4, no intervening nlink), so st_mode sits at
    // offset 16 and offset 24 is st_uid -- confirmed the same way on a
    // native aarch64 glibc build (same log: st_mode=16, st_uid=24). Reading
    // offset 24 there hands fchmod the low 9 bits of a uid instead of a
    // mode, silently, with no signal anywhere in this runner's own
    // tamper-evidence envelope (content hashes still match).
    //
    // Three fix shapes were on the table: (1) branch on
    // RuntimeInformation.ProcessArchitecture with a hand-maintained offset
    // table -- still silently wrong on the next architecture the table
    // doesn't name; (2) fail closed on any architecture not positively
    // identified -- never wrong, but refuses to run somewhere the layout
    // would in fact have been fine; (3) stop deriving the offset ourselves
    // at all. This is (3): File.GetUnixFileMode(SafeFileHandle) calls
    // fstat(2) through the .NET runtime's own native PAL, which is built
    // and tested per target RID by the runtime itself -- the same
    // authority that already has to get this right for every Unix File I/O
    // primitive .NET ships, not a table this file maintains in parallel.
    // It removes the offset-arithmetic class of bug rather than patching
    // the x86-64/aarch64 instance of it.
    //
    // Unanticipated-architecture behavior: if this script is running under
    // PowerShell at all, it is running on a RID .NET already supports and
    // already implements GetUnixFileMode for correctly -- there is no
    // "unsupported but still runs" gap for this call the way there was for
    // a hand-maintained offset table, because .NET's own PAL is exactly
    // where the platform's true struct-stat knowledge already has to live.
    // A platform .NET does not support does not run pwsh in the first
    // place, so the failure (if any) happens before this line, not as a
    // silently wrong mode after it.
    private static uint SourceMode(SafeFileHandle source) { return (uint)System.IO.File.GetUnixFileMode(source) & 511U; }
    private static void ValidatePath(string path) { if (String.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path) || path.IndexOf('\\') >= 0 || path.IndexOf(':') >= 0) throw new InvalidDataException("path is not normalized repository-relative"); foreach (string part in path.Split('/')) ValidateLeaf(part); }
    private static void ValidateLeaf(string leaf) { if (String.IsNullOrWhiteSpace(leaf) || leaf == "." || leaf == ".." || leaf.IndexOf('/') >= 0 || leaf.IndexOf('\\') >= 0 || leaf.IndexOf(':') >= 0) throw new InvalidDataException("invalid relative path segment"); }
}
'@

function Initialize-NativePublisher {
    if ($null -eq ('A6AnchoredPublisher' -as [type])) {
        try { Add-Type -TypeDefinition $NativePublisherSource -Language CSharp -ErrorAction Stop } catch { Fail "native handle-relative publisher compilation failed: $($_.Exception.Message)" }
    }
}

function Test-ManifestHashes {
    param([string]$HumanCopyRoot, [string[]]$Targets, $ManifestDigests)
    foreach ($target in $Targets) {
        $staged = Join-Path $HumanCopyRoot ($target -replace '/', [IO.Path]::DirectorySeparatorChar)
        [void](Assert-AnchoredPath -Root $HumanCopyRoot -Candidate $staged -Label "staged payload target ($target)" -RequiredType Leaf)
        $actual = Get-Sha256Hex $staged
        $expected = $ManifestDigests[$target]
        if (-not [string]::Equals($actual, $expected, [StringComparison]::Ordinal)) {
            Fail "staged payload hash mismatch for $target (manifest expected $expected, staged file is $actual)"
        }
    }
}

function Copy-Payload {
    param([string]$RepoRoot, [string]$HumanCopyRoot, [string[]]$Targets, $ManifestDigests = $null)
    Initialize-NativePublisher
    # From here on a partial application is possible, so the entry-point catch
    # must report live state (point 5).
    $Script:CopyPhaseStarted = $true
    foreach ($target in $Targets) {
        try {
            $expected = if ($null -eq $ManifestDigests) { Get-Sha256Hex (Join-Path $HumanCopyRoot ($target -replace '/', [IO.Path]::DirectorySeparatorChar)) } else { [string]$ManifestDigests[$target] }
            [A6AnchoredPublisher]::CopyOne($RepoRoot, "$($Script:HumanCopyPrefix)/$target", $target, $expected, [bool]$IsMacOS)
            # Recorded only after CopyOne returns. CopyOne verifies the
            # published digest itself before returning, so membership of this
            # list means "live and verified", not merely "rename issued".
            $Script:PublishedTargets.Add($target)
        } catch [System.IO.InvalidDataException] {
            $Script:FailedTarget = $target
            # Content-integrity and path-shape failures: a staged file that
            # changed between pre-copy verification and the copy, a temporary
            # or published digest mismatch, a malformed expected digest, or a
            # non-normalized repository-relative path. NONE of these is a
            # path-escape attempt, and every one of them used to be reported
            # to the operator as one -- this catch relabelled EVERY exception
            # from CopyOne as "symlink/reparse-point ancestor or unsafe leaf"
            # (T-001 Anthropic slot, Minor: "the headline diagnosis is wrong
            # for most failure modes"). Reproduced directly while
            # mutation-testing TEST-004a: a digest mismatch surfaced under the
            # symlink headline. InvalidDataException derives from
            # SystemException, not IOException, so the two classes separate
            # cleanly.
            Fail "staged payload integrity check failed for $target (content changed or path is not a normalized repository-relative path): $($_.Exception.Message)"
        } catch [System.IO.IOException] {
            # The class this headline was actually written for: no-follow
            # handle opens, reparse-point rejection, and errno-bearing libc
            # failures from ThrowUnix (which includes ENOSPC and friends).
            # TEST-009e matches on 'symlink/reparse-point ancestor', so this
            # branch keeps that wording verbatim.
            $Script:FailedTarget = $target
            Fail "secure handle-relative publish rejected $target (symlink/reparse-point ancestor or unsafe leaf): $($_.Exception.Message)"
        } catch {
            # Anything else -- e.g. EntryPointNotFoundException for a missing
            # libc entry point on an unexpected platform. Diagnosed as what it
            # is (unclassified) rather than as a path-escape attempt.
            $Script:FailedTarget = $target
            Fail "publish failed for $target (unclassified error; neither a content-integrity nor a path-safety rejection): $($_.Exception.Message)"
        }
    }
}

function Test-PostCopyHashes {
    param([string]$RepoRoot, [string[]]$Targets, $ManifestDigests)
    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($target in $Targets) {
        $destination = Join-Path $RepoRoot ($target -replace '/', [IO.Path]::DirectorySeparatorChar)
        try {
            [void](Assert-AnchoredPath -Root $RepoRoot -Candidate $destination -Label "installed target ($target)" -RequiredType Leaf)
            $actual = Get-Sha256Hex $destination
            $expected = $ManifestDigests[$target]
            if (-not [string]::Equals($actual, $expected, [StringComparison]::Ordinal)) {
                [void]$failures.Add("$target : post-copy hash mismatch (manifest expected $expected, installed file is $actual)")
            }
        } catch {
            [void]$failures.Add("$target : $($_.Exception.Message)")
        }
    }
    if ($failures.Count) { Fail "post-copy re-verification FAILED:`n$($failures -join "`n")" }
}

function Invoke-ApplyProtectedFiles {
    param([string]$RepoRootOverride)
    $repoRoot = if ($RepoRootOverride) {
        Assert-AnchoredPath -Root $RepoRootOverride -Candidate $RepoRootOverride -Label 'RepositoryRoot' -RequiredType Container
    } else {
        Get-RepositoryRoot
    }
    $humanCopyRoot = Join-Path $repoRoot ($Script:HumanCopyPrefix -replace '/', [IO.Path]::DirectorySeparatorChar)
    [void](Assert-AnchoredPath -Root $repoRoot -Candidate $humanCopyRoot -Label 'feature human-copy root' -RequiredType Container)
    $payloadSet = Get-PayloadFileSet $humanCopyRoot
    $manifestDigests = Get-ManifestTargets (Join-Path $humanCopyRoot 'MANIFEST.sha256')
    Test-ExactSet $Script:DeclaredTargets $manifestDigests $payloadSet
    Test-ManifestHashes $humanCopyRoot $Script:DeclaredTargets $manifestDigests
    Copy-Payload $repoRoot $humanCopyRoot $Script:DeclaredTargets $manifestDigests
    # TEST_FIXTURE_AFTER_COPY
    Test-PostCopyHashes $repoRoot $Script:DeclaredTargets $manifestDigests
    Write-Host 'apply-protected-files(epic-194-a6): complete'
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ApplyProtectedFiles $RepositoryRoot
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        # Live state BEFORE the stack trace: the operator's first question
        # after a failed protected-file application is "what is live now?",
        # and burying that under a PowerShell trace answers it last.
        Write-PublishStateReport
        if ($_.ScriptStackTrace) { [Console]::Error.WriteLine($_.ScriptStackTrace) }
        exit 2
    }
}
