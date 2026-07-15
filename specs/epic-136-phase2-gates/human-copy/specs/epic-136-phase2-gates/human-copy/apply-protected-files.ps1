[CmdletBinding()]
param(
    [switch]$Bootstrap,
    [Alias('RepoRoot')]
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$BootstrapTargets = @(
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
    'plugins/sdd-quality-loop/scripts/check-contract.ps1',
    'plugins/sdd-lite/references/risk-upgrade-policy.md',
    'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
    'plugins/sdd-lite/scripts/check-risk-upgrade.ps1',
    'plugins/sdd-lite/skills/lite-spec/SKILL.md',
    'plugins/sdd-ship/skills/ship/SKILL.md',
    'plugins/sdd-quality-loop/references/guard-invariants.json',
    'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py',
    'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1',
    'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh',
    '.github/workflows/test.yml',
    'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1'
)
$HumanCopyPrefix = 'specs/epic-136-phase2-gates/human-copy'

function Fail([string]$Message) { throw "apply-protected-files: $Message" }

function Get-RepositoryRoot {
    $current = Split-Path -Parent $PSCommandPath
    while (-not [string]::IsNullOrWhiteSpace($current)) {
        if (Test-Path -LiteralPath (Join-Path $current 'plugins/sdd-quality-loop/references/guard-invariants.json') -PathType Leaf) {
            $featureRoot = Split-Path -Parent $current
            $specsRoot = Split-Path -Parent $featureRoot
            return [IO.Path]::GetFullPath((Split-Path -Parent $specsRoot))
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
    Fail 'unable to locate the staged canonical file from the runner path'
}

function Get-ExecutionRoot {
    $candidate = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { Get-RepositoryRoot } else { $RepositoryRoot }
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { Fail 'RepositoryRoot must be an existing directory' }
    return [IO.Path]::GetFullPath($candidate).TrimEnd('\', '/')
}

function Assert-NormalizedRelativePath([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path) -or $Path.Contains('\') -or $Path.Contains(':')) { Fail "$Label is not repository-relative" }
    if (@($Path.Split('/') | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }).Count -ne 0) { Fail "$Label contains traversal or an empty segment" }
}

function Assert-SameOrder([string[]]$Expected, [string[]]$Actual, [string]$Label) {
    if ($Actual.Count -ne $Expected.Count) { Fail "$Label target count differs" }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($Actual[$index] -isnot [string] -or -not $Expected[$index].Equals($Actual[$index], [StringComparison]::Ordinal)) { Fail "$Label target order differs" }
    }
}

function Get-CanonicalTargets([string]$Content, [string]$Label) {
    try { $canonical = $Content | ConvertFrom-Json } catch { Fail "$Label is not valid JSON" }
    if ($null -eq $canonical -or $null -eq $canonical.PSObject.Properties['schema_version'] -or $canonical.schema_version -ne 1 -or $null -eq $canonical.PSObject.Properties['phase2_human_copy_targets']) { Fail "$Label has an invalid schema" }
    $targets = @($canonical.phase2_human_copy_targets)
    if ($targets.Count -eq 0) { Fail "$Label has no targets" }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($target in $targets) {
        Assert-NormalizedRelativePath $target "$Label target"
        if (-not $seen.Add($target)) { Fail "$Label has a duplicate target" }
    }
    return $targets
}

function Get-ManifestDigests([string]$Content, [string[]]$Targets) {
    if ($Content.Contains("`r")) { $Content = $Content.Replace("`r`n", "`n") }
    if ($Content.Contains("`r")) { Fail 'manifest contains a bare carriage return' }
    $lines = @($Content -split "`n")
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
    if ($lines.Count -ne $Targets.Count) { Fail 'manifest must have exactly one line per target' }
    $allowed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $digests = @{}
    foreach ($target in $Targets) { [void]$allowed.Add($target) }
    foreach ($line in $lines) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { Fail 'manifest is not lowercase GNU sha256 format' }
        $digest = $matches[1]
        $target = $matches[2]
        Assert-NormalizedRelativePath $target 'manifest target'
        if (-not $allowed.Contains($target)) { Fail 'manifest includes a non-inventory target' }
        if (-not $seen.Add($target)) { Fail 'manifest includes a duplicate target' }
        $digests[$target] = $digest
    }
    foreach ($target in $Targets) { if (-not $seen.Contains($target)) { Fail 'manifest omits an inventory target' } }
    return $digests
}

function Assert-CapabilityFloor([string]$Root) {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { Fail 'Windows is required' }
    if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -lt 1) { Fail 'Windows PowerShell 5.1 is required' }
    if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') { Fail 'FullLanguage mode is required' }
    if ($Root.StartsWith('\\', [StringComparison]::Ordinal)) { Fail 'UNC repository roots are not supported' }
    $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($Root))
    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { Fail 'repository root must be on a fixed local drive' }
    if ($drive.DriveFormat -ne 'NTFS') { Fail 'repository root filesystem must be NTFS' }
}

$NativeSource = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Win32.SafeHandles;

public sealed class AnchoredCopySession : IDisposable
{
    private const uint FILE_READ_DATA = 0x0001;
    private const uint FILE_WRITE_DATA = 0x0002;
    private const uint FILE_APPEND_DATA = 0x0004;
    private const uint FILE_LIST_DIRECTORY = 0x0001;
    private const uint FILE_ADD_FILE = 0x0002;
    private const uint FILE_ADD_SUBDIRECTORY = 0x0004;
    private const uint FILE_READ_ATTRIBUTES = 0x0080;
    private const uint DELETE = 0x00010000;
    private const uint SYNCHRONIZE = 0x00100000;
    private const uint FILE_SHARE_READ = 0x00000001;
    private const uint FILE_SHARE_WRITE = 0x00000002;
    private const uint FILE_OPEN = 0x00000001;
    private const uint FILE_CREATE = 0x00000002;
    private const uint FILE_OPEN_IF = 0x00000003;
    private const uint FILE_DIRECTORY_FILE = 0x00000001;
    private const uint FILE_NON_DIRECTORY_FILE = 0x00000040;
    private const uint FILE_SYNCHRONOUS_IO_NONALERT = 0x00000020;
    private const uint FILE_OPEN_REPARSE_POINT = 0x00200000;
    private const uint FILE_ATTRIBUTE_NORMAL = 0x00000080;
    private const uint FILE_ATTRIBUTE_DIRECTORY = 0x00000010;
    private const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400;
    private const uint OBJ_CASE_INSENSITIVE = 0x00000040;
    private const uint OPEN_EXISTING = 3;
    private const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
    private const uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;
    private const int FileAttributeTagInfo = 9;
    private const int FileRenameInfo = 3;
    private const int FileDispositionInfo = 4;
    private const int FileRenameInformation = 10;

    [StructLayout(LayoutKind.Sequential)]
    private struct UNICODE_STRING
    {
        public ushort Length;
        public ushort MaximumLength;
        public IntPtr Buffer;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct OBJECT_ATTRIBUTES
    {
        public int Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public uint Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IO_STATUS_BLOCK
    {
        public IntPtr Status;
        public UIntPtr Information;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct FILE_ATTRIBUTE_TAG_INFO
    {
        public uint FileAttributes;
        public uint ReparseTag;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct FILE_DISPOSITION_INFO
    {
        [MarshalAs(UnmanagedType.Bool)] public bool DeleteFile;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);

    [DllImport("ntdll.dll", EntryPoint = "NtCreateFile")]
    private static extern int NtCreateFile(out SafeFileHandle handle, uint access, ref OBJECT_ATTRIBUTES attributes, out IO_STATUS_BLOCK status, IntPtr allocationSize, uint fileAttributes, uint share, uint disposition, uint options, IntPtr eaBuffer, uint eaLength);

    [DllImport("ntdll.dll")]
    private static extern uint RtlNtStatusToDosError(int status);

    [DllImport("ntdll.dll", EntryPoint = "NtSetInformationFile")]
    private static extern int NtSetInformationFile(SafeFileHandle handle, out IO_STATUS_BLOCK status, IntPtr information, uint length, int informationClass);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandleEx(SafeFileHandle handle, int informationClass, out FILE_ATTRIBUTE_TAG_INFO info, uint size);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetFileInformationByHandle(SafeFileHandle handle, int informationClass, IntPtr info, uint size);

    private sealed class CopyPlan
    {
        public int Index;
        public string SourceRelative;
        public string DestinationRelative;
        public string DestinationParentRelative;
        public string DestinationLeaf;
        public string Digest;
        public SafeFileHandle SourceHandle;
        public SafeFileHandle ParentHandle;
        public SafeFileHandle TemporaryHandle;
        public string TemporaryLeaf;
        public bool Published;
    }

    private readonly string _repositoryPath;
    private readonly SafeFileHandle _rootHandle;
    private readonly List<CopyPlan> _plans = new List<CopyPlan>();
    private bool _disposed;

    public AnchoredCopySession(string repositoryPath)
    {
        if (String.IsNullOrWhiteSpace(repositoryPath)) throw new ArgumentException("repository path is required");
        _repositoryPath = Path.GetFullPath(repositoryPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        _rootHandle = CreateFileW(_repositoryPath, FILE_LIST_DIRECTORY | FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, IntPtr.Zero);
        if (_rootHandle == null || _rootHandle.IsInvalid) throw Win32("open repository root");
        ValidateHandle(_rootHandle, true, "repository root");
    }

    public string ReadUtf8File(string relativePath)
    {
        ValidateRelativePath(relativePath);
        using (SafeFileHandle handle = OpenFilePath(relativePath, FILE_READ_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ))
        using (FileStream stream = BorrowedStream(handle, FileAccess.Read))
        using (MemoryStream memory = new MemoryStream())
        {
            byte[] buffer = new byte[65536];
            int count;
            while ((count = stream.Read(buffer, 0, buffer.Length)) != 0)
            {
                if (memory.Length + count > 16777216) throw new InvalidDataException("anchored input is too large");
                memory.Write(buffer, 0, count);
            }
            return new UTF8Encoding(false, true).GetString(memory.ToArray());
        }
    }

    public void AddPlan(int index, string sourceRelative, string destinationRelative, string digest)
    {
        ValidateRelativePath(sourceRelative);
        ValidateRelativePath(destinationRelative);
        if (!Regex.IsMatch(digest ?? String.Empty, "^[0-9a-f]{64}$")) throw new InvalidDataException("invalid plan digest");
        int slash = destinationRelative.LastIndexOf('/');
        if (slash <= 0 || slash == destinationRelative.Length - 1) throw new InvalidDataException("destination requires a parent and leaf");
        _plans.Add(new CopyPlan {
            Index = index,
            SourceRelative = sourceRelative,
            DestinationRelative = destinationRelative,
            DestinationParentRelative = destinationRelative.Substring(0, slash),
            DestinationLeaf = destinationRelative.Substring(slash + 1),
            Digest = digest
        });
    }

    public void ValidateSourcesAndParents()
    {
        foreach (CopyPlan plan in _plans)
        {
            plan.SourceHandle = OpenFilePath(plan.SourceRelative, FILE_READ_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ);
            string actual = HashHandle(plan.SourceHandle);
            if (!String.Equals(actual, plan.Digest, StringComparison.Ordinal)) throw new InvalidDataException("staged source digest mismatch: " + plan.SourceRelative);
            // TEST_FIXTURE_SOURCE_SUBSTITUTION
        }
        foreach (CopyPlan plan in _plans)
        {
            plan.ParentHandle = OpenDirectoryPath(plan.DestinationParentRelative, true);
            SafeFileHandle existing = TryOpenRelativeFile(plan.ParentHandle, plan.DestinationLeaf, FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ | FILE_SHARE_WRITE);
            if (existing != null) existing.Dispose();
            // TEST_FIXTURE_PARENT_SUBSTITUTION
        }
    }

    public void PrepareAll()
    {
        try
        {
            foreach (CopyPlan plan in _plans)
            {
                plan.TemporaryLeaf = ".sdd-phase2-" + Guid.NewGuid().ToString("N") + ".tmp";
                plan.TemporaryHandle = OpenRelative(plan.ParentHandle, plan.TemporaryLeaf, FILE_READ_DATA | FILE_WRITE_DATA | FILE_APPEND_DATA | FILE_READ_ATTRIBUTES | DELETE | SYNCHRONIZE, 0, FILE_CREATE, FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, false, "create temporary");
                CopyHandle(plan.SourceHandle, plan.TemporaryHandle);
                string actual = HashHandle(plan.TemporaryHandle);
                if (!String.Equals(actual, plan.Digest, StringComparison.Ordinal)) throw new InvalidDataException("temporary digest mismatch: " + plan.DestinationRelative);
                // TEST_FIXTURE_AFTER_PREPARE_ITEM
            }
        }
        catch
        {
            CleanupUnpublished();
            throw;
        }
    }

    public void PublishAll()
    {
        try
        {
            for (int index = 0; index < _plans.Count; index++)
            {
                CopyPlan plan = _plans[index];
                // TEST_FIXTURE_BEFORE_RENAME
                RenameRelative(plan.TemporaryHandle, plan.ParentHandle, plan.DestinationLeaf);
                plan.Published = true;
                plan.TemporaryHandle.Dispose();
                plan.TemporaryHandle = null;
            }
        }
        catch
        {
            CleanupUnpublished();
            throw;
        }
    }

    public void VerifyPublished()
    {
        foreach (CopyPlan plan in _plans)
        {
            using (SafeFileHandle handle = OpenRelative(plan.ParentHandle, plan.DestinationLeaf, FILE_READ_DATA | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ, FILE_OPEN, FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, false, "verify published target"))
            {
                string actual = HashHandle(handle);
                if (!String.Equals(actual, plan.Digest, StringComparison.Ordinal)) throw new InvalidDataException("published digest mismatch: " + plan.DestinationRelative);
            }
        }
    }

    private SafeFileHandle OpenFilePath(string relativePath, uint access, uint share)
    {
        int slash = relativePath.LastIndexOf('/');
        if (slash <= 0 || slash == relativePath.Length - 1) throw new InvalidDataException("file path requires parent and leaf");
        using (SafeFileHandle parent = OpenDirectoryPath(relativePath.Substring(0, slash), false))
        {
            return OpenRelative(parent, relativePath.Substring(slash + 1), access, share, FILE_OPEN, FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, false, "open anchored file");
        }
    }

    private SafeFileHandle OpenDirectoryPath(string relativePath, bool createMissing)
    {
        ValidateRelativePath(relativePath);
        string[] segments = relativePath.Split('/');
        SafeFileHandle current = _rootHandle;
        bool ownsCurrent = false;
        try
        {
            foreach (string segment in segments)
            {
                SafeFileHandle next = OpenRelative(current, segment, FILE_LIST_DIRECTORY | FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY | FILE_READ_ATTRIBUTES | SYNCHRONIZE, FILE_SHARE_READ | FILE_SHARE_WRITE, createMissing ? FILE_OPEN_IF : FILE_OPEN, FILE_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, true, "open anchored directory");
                if (ownsCurrent) current.Dispose();
                current = next;
                ownsCurrent = true;
            }
            ownsCurrent = false;
            return current;
        }
        finally { if (ownsCurrent) current.Dispose(); }
    }

    private static SafeFileHandle TryOpenRelativeFile(SafeFileHandle parent, string leaf, uint access, uint share)
    {
        int status;
        SafeFileHandle handle = OpenRelativeStatus(parent, leaf, access, share, FILE_OPEN, FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT, out status);
        if (status == unchecked((int)0xC0000034) || status == unchecked((int)0xC000003A)) { if (handle != null) handle.Dispose(); return null; }
        if (status < 0) { if (handle != null) handle.Dispose(); ThrowNt(status, "open existing destination"); }
        ValidateHandle(handle, false, "existing destination");
        return handle;
    }

    private static SafeFileHandle OpenRelative(SafeFileHandle root, string leaf, uint access, uint share, uint disposition, uint options, bool directory, string context)
    {
        int status;
        SafeFileHandle handle = OpenRelativeStatus(root, leaf, access, share, disposition, options, out status);
        if (status < 0) { if (handle != null) handle.Dispose(); ThrowNt(status, context); }
        ValidateHandle(handle, directory, context);
        return handle;
    }

    private static SafeFileHandle OpenRelativeStatus(SafeFileHandle root, string leaf, uint access, uint share, uint disposition, uint options, out int status)
    {
        ValidateLeaf(leaf);
        IntPtr nameBuffer = IntPtr.Zero;
        IntPtr unicodePointer = IntPtr.Zero;
        bool added = false;
        SafeFileHandle handle;
        try
        {
            nameBuffer = Marshal.StringToHGlobalUni(leaf);
            UNICODE_STRING unicode = new UNICODE_STRING { Length = checked((ushort)(leaf.Length * 2)), MaximumLength = checked((ushort)((leaf.Length + 1) * 2)), Buffer = nameBuffer };
            unicodePointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UNICODE_STRING)));
            Marshal.StructureToPtr(unicode, unicodePointer, false);
            root.DangerousAddRef(ref added);
            OBJECT_ATTRIBUTES attributes = new OBJECT_ATTRIBUTES {
                Length = Marshal.SizeOf(typeof(OBJECT_ATTRIBUTES)),
                RootDirectory = root.DangerousGetHandle(),
                ObjectName = unicodePointer,
                Attributes = OBJ_CASE_INSENSITIVE,
                SecurityDescriptor = IntPtr.Zero,
                SecurityQualityOfService = IntPtr.Zero
            };
            IO_STATUS_BLOCK io;
            status = NtCreateFile(out handle, access, ref attributes, out io, IntPtr.Zero, FILE_ATTRIBUTE_NORMAL, share, disposition, options, IntPtr.Zero, 0);
            return handle;
        }
        finally
        {
            if (added) root.DangerousRelease();
            if (unicodePointer != IntPtr.Zero) Marshal.FreeHGlobal(unicodePointer);
            if (nameBuffer != IntPtr.Zero) Marshal.FreeHGlobal(nameBuffer);
        }
    }

    private static void ValidateHandle(SafeFileHandle handle, bool directory, string context)
    {
        if (handle == null || handle.IsInvalid) throw new IOException(context + " returned an invalid handle");
        FILE_ATTRIBUTE_TAG_INFO info;
        if (!GetFileInformationByHandleEx(handle, FileAttributeTagInfo, out info, (uint)Marshal.SizeOf(typeof(FILE_ATTRIBUTE_TAG_INFO)))) throw Win32("inspect " + context);
        if ((info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) throw new IOException(context + " is a reparse point");
        bool actualDirectory = (info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
        if (actualDirectory != directory) throw new IOException(context + (directory ? " is not a directory" : " is not a regular file"));
    }

    private static void CopyHandle(SafeFileHandle source, SafeFileHandle destination)
    {
        using (FileStream input = BorrowedStream(source, FileAccess.Read))
        using (FileStream output = BorrowedStream(destination, FileAccess.ReadWrite))
        {
            input.Position = 0;
            output.Position = 0;
            output.SetLength(0);
            input.CopyTo(output, 65536);
            output.Flush(true);
            input.Position = 0;
            output.Position = 0;
        }
    }

    private static string HashHandle(SafeFileHandle handle)
    {
        using (FileStream stream = BorrowedStream(handle, FileAccess.Read))
        using (SHA256 sha = SHA256.Create())
        {
            stream.Position = 0;
            byte[] digest = sha.ComputeHash(stream);
            stream.Position = 0;
            return BitConverter.ToString(digest).Replace("-", String.Empty).ToLowerInvariant();
        }
    }

    private static FileStream BorrowedStream(SafeFileHandle handle, FileAccess access)
    {
        bool added = false;
        try
        {
            handle.DangerousAddRef(ref added);
            SafeFileHandle borrowed = new SafeFileHandle(handle.DangerousGetHandle(), false);
            return new FileStream(borrowed, access, 65536, false);
        }
        finally { if (added) handle.DangerousRelease(); }
    }

    private static void RenameRelative(SafeFileHandle source, SafeFileHandle parent, string leaf)
    {
        ValidateLeaf(leaf);
        byte[] name = Encoding.Unicode.GetBytes(leaf);
        int rootOffset = IntPtr.Size == 8 ? 8 : 4;
        int lengthOffset = rootOffset + IntPtr.Size;
        int nameOffset = lengthOffset + 4;
        // The API requires at least sizeof(FILE_RENAME_INFO) plus the name
        // bytes, not merely the offset of FileName plus those bytes.
        int structureSize = IntPtr.Size == 8 ? 24 : 16;
        int size = checked(structureSize + name.Length);
        IntPtr buffer = Marshal.AllocHGlobal(size);
        bool added = false;
        try
        {
            for (int index = 0; index < size; index++) Marshal.WriteByte(buffer, index, 0);
            Marshal.WriteInt32(buffer, 0, 1); // ReplaceIfExists
            parent.DangerousAddRef(ref added);
            Marshal.WriteIntPtr(buffer, rootOffset, parent.DangerousGetHandle()); // RootDirectory
            Marshal.WriteInt32(buffer, lengthOffset, name.Length);
            Marshal.Copy(name, 0, IntPtr.Add(buffer, nameOffset), name.Length);
            if (!SetFileInformationByHandle(source, FileRenameInfo, buffer, (uint)size))
            {
                int win32 = Marshal.GetLastWin32Error();
                if (win32 != 87) throw Win32Code("publish temporary by FileRenameInfo", win32);
                IO_STATUS_BLOCK io;
                int status = NtSetInformationFile(source, out io, buffer, (uint)size, FileRenameInformation);
                if (status < 0) ThrowNt(status, "publish temporary by FileRenameInformation");
            }
        }
        finally
        {
            if (added) parent.DangerousRelease();
            Marshal.FreeHGlobal(buffer);
        }
    }

    private void CleanupUnpublished()
    {
        Exception cleanupFailure = null;
        foreach (CopyPlan plan in _plans)
        {
            if (plan.Published || plan.TemporaryHandle == null) continue;
            IntPtr buffer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO)));
            try
            {
                FILE_DISPOSITION_INFO info = new FILE_DISPOSITION_INFO { DeleteFile = true };
                Marshal.StructureToPtr(info, buffer, false);
                if (!SetFileInformationByHandle(plan.TemporaryHandle, FileDispositionInfo, buffer, (uint)Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO)))) cleanupFailure = Win32("delete unpublished temporary");
            }
            catch (Exception error) { cleanupFailure = error; }
            finally
            {
                Marshal.FreeHGlobal(buffer);
                plan.TemporaryHandle.Dispose();
                plan.TemporaryHandle = null;
            }
        }
        if (cleanupFailure != null) throw new IOException("temporary cleanup failed", cleanupFailure);
    }

    private static void ValidateRelativePath(string path)
    {
        if (String.IsNullOrWhiteSpace(path) || path.IndexOf('\\') >= 0 || path.IndexOf(':') >= 0 || Path.IsPathRooted(path)) throw new InvalidDataException("path is not normalized repository-relative");
        string[] parts = path.Split('/');
        foreach (string part in parts) ValidateLeaf(part);
    }

    private static void ValidateLeaf(string leaf)
    {
        if (String.IsNullOrWhiteSpace(leaf) || leaf == "." || leaf == ".." || leaf.IndexOf('/') >= 0 || leaf.IndexOf('\\') >= 0 || leaf.IndexOf(':') >= 0) throw new InvalidDataException("invalid relative path segment");
    }

    private static IOException Win32(string context)
    {
        int error = Marshal.GetLastWin32Error();
        return Win32Code(context, error);
    }

    private static IOException Win32Code(string context, int error)
    {
        Win32Exception detail = new Win32Exception(error);
        return new IOException(context + " failed (win32 " + error.ToString() + ": " + detail.Message + ")", detail);
    }

    private static void ThrowNt(int status, string context)
    {
        uint error = RtlNtStatusToDosError(status);
        throw new IOException(context + " failed", new Win32Exception(unchecked((int)error)));
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Exception failure = null;
        try { CleanupUnpublished(); } catch (Exception error) { failure = error; }
        foreach (CopyPlan plan in _plans)
        {
            if (plan.SourceHandle != null) plan.SourceHandle.Dispose();
            if (plan.ParentHandle != null) plan.ParentHandle.Dispose();
        }
        if (_rootHandle != null) _rootHandle.Dispose();
        if (failure != null) throw failure;
    }
}
'@

function Get-PythonCommand {
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($null -eq $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($null -eq $python) { Fail 'python is required for generator verification' }
    return $python.Source
}

function Invoke-PostInstallVerification([string]$Root) {
    $python = Get-PythonCommand
    & $python (Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py') --check
    if ($LASTEXITCODE -ne 0) { Fail 'generator --check failed after installation' }
    $previousChild = $env:SDD_PHASE2_RUNNER_CHILD
    $env:SDD_PHASE2_RUNNER_CHILD = '1'
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests/phase2-guard-invariants.tests.ps1')
        if ($LASTEXITCODE -ne 0) { Fail 'PowerShell focused suite failed after installation' }
        & bash (Join-Path $Root 'tests/phase2-guard-invariants.tests.sh')
        if ($LASTEXITCODE -ne 0) { Fail 'POSIX focused suite failed after installation' }
    } finally {
        if ($null -eq $previousChild) { Remove-Item Env:SDD_PHASE2_RUNNER_CHILD -ErrorAction SilentlyContinue } else { $env:SDD_PHASE2_RUNNER_CHILD = $previousChild }
    }
}

$session = $null
try {
    $repositoryRoot = Get-ExecutionRoot
    Assert-CapabilityFloor $repositoryRoot
    try { Add-Type -TypeDefinition $NativeSource -Language CSharp -ErrorAction Stop } catch { Fail ('native helper compilation failed: ' + $_.Exception.Message) }
    $session = New-Object AnchoredCopySession $repositoryRoot

    $stagedCanonicalRelative = $HumanCopyPrefix + '/plugins/sdd-quality-loop/references/guard-invariants.json'
    $stagedTargets = @(Get-CanonicalTargets ($session.ReadUtf8File($stagedCanonicalRelative)) 'staged canonical file')
    if ($Bootstrap) {
        Assert-SameOrder $BootstrapTargets $stagedTargets 'staged canonical bootstrap inventory'
        $targets = $BootstrapTargets
    } else {
        $liveTargets = @(Get-CanonicalTargets ($session.ReadUtf8File('plugins/sdd-quality-loop/references/guard-invariants.json')) 'installed live canonical file')
        Assert-SameOrder $liveTargets $stagedTargets 'staged/live canonical update inventory'
        $targets = $liveTargets
    }

    $digests = Get-ManifestDigests ($session.ReadUtf8File($HumanCopyPrefix + '/MANIFEST.sha256')) $targets
    for ($index = 0; $index -lt $targets.Count; $index++) {
        $target = $targets[$index]
        $session.AddPlan($index, $HumanCopyPrefix + '/' + $target, $target, [string]$digests[$target])
    }
    $session.ValidateSourcesAndParents()
    $session.PrepareAll()
    $session.PublishAll()
    $session.VerifyPublished()
    $session.Dispose()
    $session = $null
    Invoke-PostInstallVerification $repositoryRoot
    Write-Host 'apply-protected-files: complete'
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 2
} finally {
    if ($null -ne $session) {
        try { $session.Dispose() } catch { [Console]::Error.WriteLine($_.Exception.Message) }
    }
}
