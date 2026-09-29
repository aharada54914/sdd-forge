param([Parameter(Mandatory=$true)][string]$Store)
$ErrorActionPreference = 'Stop'
try {
  if (-not $IsWindows) { throw 'unavailable' }
  Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class SddPrivateDirectory {
  [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes {
    public int Length; public IntPtr Descriptor; public int InheritHandle;
  }
  [StructLayout(LayoutKind.Sequential)] struct FileInfo {
    public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Creation;
    public System.Runtime.InteropServices.ComTypes.FILETIME Access, Write;
    public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
  }
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  static extern bool CreateDirectoryW(string path, ref SecurityAttributes attributes);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  static extern SafeFileHandle CreateFileW(string path, uint access, uint sharing,
    IntPtr attributes, uint disposition, uint flags, IntPtr template);
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool GetFileInformationByHandle(SafeFileHandle handle, out FileInfo info);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle, StringBuilder path, uint size, uint flags);
  [DllImport("advapi32.dll")]
  static extern uint GetSecurityInfo(SafeFileHandle handle, uint type, uint information,
    out IntPtr owner, out IntPtr group, out IntPtr dacl, out IntPtr sacl, out IntPtr descriptor);
  [DllImport("advapi32.dll")] static extern uint GetSecurityDescriptorLength(IntPtr descriptor);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr pointer);

  static SafeFileHandle Open(string path) {
    // READ_CONTROL; no delete sharing. OPEN_REPARSE_POINT inspects the named object.
    var handle = CreateFileW(path, 0x20000, 3, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero);
    if (handle.IsInvalid) { handle.Dispose(); throw new IOException(); }
    return handle;
  }
  static FileInfo Inspect(SafeFileHandle handle, string expected) {
    FileInfo info;
    if (!GetFileInformationByHandle(handle, out info) || (info.Attributes & 0x10) == 0 ||
        (info.Attributes & 0x400) != 0) throw new IOException();
    var name = new StringBuilder(32768);
    uint length = GetFinalPathNameByHandleW(handle, name, (uint)name.Capacity, 0);
    if (length == 0 || length >= name.Capacity) throw new IOException();
    string actual = name.ToString();
    if (actual.StartsWith(@"\\?\UNC\", StringComparison.Ordinal)) actual = @"\\" + actual.Substring(8);
    else if (actual.StartsWith(@"\\?\", StringComparison.Ordinal)) actual = actual.Substring(4);
    if (!String.Equals(actual.TrimEnd('\\'), expected.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
      throw new IOException();
    return info;
  }
  static RawSecurityDescriptor Security(SafeFileHandle handle) {
    IntPtr owner, group, dacl, sacl, descriptor;
    if (GetSecurityInfo(handle, 1, 5, out owner, out group, out dacl, out sacl, out descriptor) != 0)
      throw new IOException();
    try {
      uint length = GetSecurityDescriptorLength(descriptor);
      if (length == 0 || length > 65536) throw new IOException();
      byte[] bytes = new byte[length]; Marshal.Copy(descriptor, bytes, 0, (int)length);
      return new RawSecurityDescriptor(bytes, 0);
    } finally { LocalFree(descriptor); }
  }
  static void Private(SafeFileHandle handle, SecurityIdentifier sid) {
    var security = Security(handle);
    if (security.Owner == null || !security.Owner.Equals(sid) ||
        (security.ControlFlags & ControlFlags.DiscretionaryAclProtected) == 0 ||
        (security.ControlFlags & ControlFlags.DiscretionaryAclPresent) == 0 ||
        security.DiscretionaryAcl == null || security.DiscretionaryAcl.Count != 1) throw new IOException();
    var ace = security.DiscretionaryAcl[0] as CommonAce;
    if (ace == null || ace.AceQualifier != AceQualifier.AccessAllowed ||
        !ace.SecurityIdentifier.Equals(sid) || ace.IsCallback ||
        ace.AceFlags != (AceFlags.ContainerInherit | AceFlags.ObjectInherit) ||
        ace.AccessMask != (int)FileSystemRights.FullControl)
      throw new IOException();
  }
  static bool Same(FileInfo first, FileInfo second) {
    return first.Volume == second.Volume && first.IndexHigh == second.IndexHigh && first.IndexLow == second.IndexLow;
  }
  public static void Create(string path) {
    path = Path.GetFullPath(path);
    if (!String.Equals(Path.GetFileName(path), "context", StringComparison.Ordinal) ||
        !String.Equals(Path.GetFileName(Path.GetDirectoryName(path)), ".sdd", StringComparison.Ordinal))
      throw new IOException("path-shape");
    var sid = WindowsIdentity.GetCurrent().User;
    if (sid == null) throw new IOException("identity");
    string parentPath = Path.GetDirectoryName(path);
    using (var parent = Open(parentPath)) {
      var before = Inspect(parent, parentPath);
      if (!sid.Equals(Security(parent).Owner)) throw new IOException("parent-owner");
      var security = new DirectorySecurity();
      security.SetOwner(sid); security.SetAccessRuleProtection(true, false);
      security.AddAccessRule(new FileSystemAccessRule(sid, FileSystemRights.FullControl,
        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
        PropagationFlags.None, AccessControlType.Allow));
      byte[] bytes = security.GetSecurityDescriptorBinaryForm();
      var pinned = GCHandle.Alloc(bytes, GCHandleType.Pinned);
      try {
        var attributes = new SecurityAttributes { Length = Marshal.SizeOf(typeof(SecurityAttributes)),
          Descriptor = pinned.AddrOfPinnedObject(), InheritHandle = 0 };
        // Win32 atomically rejects preexisting leaf; no chmod/Set-Acl repair.
        if (!CreateDirectoryW(path, ref attributes))
          throw new IOException("create-win32-" + Marshal.GetLastWin32Error());
      } finally { pinned.Free(); }
      using (var created = Open(path)) {
        var first = Inspect(created, path); Private(created, sid);
        using (var again = Open(path)) {
          if (!Same(first, Inspect(again, path))) throw new IOException();
          Private(again, sid);
        }
      }
      using (var again = Open(parentPath)) {
        if (!Same(before, Inspect(again, parentPath)) || !sid.Equals(Security(again).Owner))
          throw new IOException("parent-changed");
      }
    }
  }
}
'@
  [SddPrivateDirectory]::Create($Store)
  [Console]::Out.Write('created')
} catch {
  $cause = $_.Exception
  while ($cause.InnerException) { $cause = $cause.InnerException }
  $method = [regex]::Match([string]$cause.StackTrace, 'SddPrivateDirectory\.[A-Za-z]+').Value
  $detail = if ($cause -is [System.IO.IOException]) { $cause.Message } else { '' }
  [Console]::Error.WriteLine("windows-store: $($cause.GetType().Name) $method $detail")
  exit 1
}
