param(
  [Parameter(Mandatory=$true)][string]$Manifest,
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$SnapshotRoot
)
$ErrorActionPreference = 'Stop'

function Fail([string]$Code, [string]$Message) {
  throw "TASK_INPUT_${Code}: $Message"
}
function Test-RepoPath([object]$Path) {
  if ($Path -isnot [string] -or [string]::IsNullOrEmpty($Path)) { return $false }
  if ($Path.StartsWith('/', [StringComparison]::Ordinal) -or $Path.Contains('\', [StringComparison]::Ordinal)) { return $false }
  foreach ($part in $Path.Split('/')) {
    if ($part -eq '' -or $part -eq '.' -or $part -eq '..') { return $false }
  }
  return $Path -match '^[A-Za-z0-9][A-Za-z0-9._/-]*$'
}
function Get-SafeSource([string]$Repo, [string]$RelativePath) {
  $current = $Repo
  foreach ($part in $RelativePath.Split('/')) {
    $current = Join-Path $current $part
    if (-not (Test-Path -LiteralPath $current)) { Fail PATH "input missing: $RelativePath" }
    $item = Get-Item -LiteralPath $current -Force
    if ($item.LinkType -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      Fail PATH "input contains symlink: $RelativePath"
    }
  }
  if (-not (Test-Path -LiteralPath $current -PathType Leaf)) {
    Fail PATH "input is not a regular non-symlink file: $RelativePath"
  }
  return $current
}
function Set-SnapshotReadOnly([string]$Root) {
  $items = @(Get-ChildItem -LiteralPath $Root -Recurse -Force)
  if ($IsWindows) {
    foreach ($item in $items) {
      if (-not $item.PSIsContainer) {
        [IO.File]::SetAttributes($item.FullName, [IO.File]::GetAttributes($item.FullName) -bor [IO.FileAttributes]::ReadOnly)
      }
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rootRights = [Security.AccessControl.FileSystemRights]::WriteData -bor
      [Security.AccessControl.FileSystemRights]::AppendData -bor
      [Security.AccessControl.FileSystemRights]::WriteAttributes -bor
      [Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
      [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
    $childRights = $rootRights -bor [Security.AccessControl.FileSystemRights]::Delete
    $acl = Get-Acl -LiteralPath $Root
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
      $identity, $rootRights, [Security.AccessControl.AccessControlType]::Deny
    ))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
      $identity,
      $childRights,
      [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit,
      [Security.AccessControl.PropagationFlags]::InheritOnly,
      [Security.AccessControl.AccessControlType]::Deny
    ))
    Set-Acl -LiteralPath $Root -AclObject $acl
    foreach ($item in @((Get-Item -LiteralPath $Root -Force)) + $items) {
      $denyRules = @((Get-Acl -LiteralPath $item.FullName).Access | Where-Object {
        $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]) -eq $identity -and
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny -and
        ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::WriteData)
      })
      if ($denyRules.Count -eq 0) { Fail PATH 'snapshot ACL is not read-only' }
      if (-not $item.PSIsContainer -and -not ([IO.File]::GetAttributes($item.FullName) -band [IO.FileAttributes]::ReadOnly)) {
        Fail PATH 'snapshot file is not read-only'
      }
    }
  } else {
    foreach ($item in @($items | Where-Object { -not $_.PSIsContainer })) {
      [IO.File]::SetUnixFileMode($item.FullName, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::GroupRead -bor [IO.UnixFileMode]::OtherRead)
    }
    foreach ($item in @($items | Where-Object { $_.PSIsContainer } | Sort-Object { $_.FullName.Length } -Descending)) {
      [IO.File]::SetUnixFileMode($item.FullName, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserExecute -bor [IO.UnixFileMode]::GroupRead -bor [IO.UnixFileMode]::GroupExecute -bor [IO.UnixFileMode]::OtherRead -bor [IO.UnixFileMode]::OtherExecute)
    }
    [IO.File]::SetUnixFileMode($Root, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserExecute -bor [IO.UnixFileMode]::GroupRead -bor [IO.UnixFileMode]::GroupExecute -bor [IO.UnixFileMode]::OtherRead -bor [IO.UnixFileMode]::OtherExecute)
    $writeBits = [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::GroupWrite -bor [IO.UnixFileMode]::OtherWrite
    foreach ($item in @((Get-Item -LiteralPath $Root -Force)) + @(Get-ChildItem -LiteralPath $Root -Recurse -Force)) {
      if ([IO.File]::GetUnixFileMode($item.FullName) -band $writeBits) { Fail PATH 'snapshot item is not read-only' }
    }
  }
}
function Wait-TestPublicationBarrier {
  $barrier = $env:SDD_TEST_SNAPSHOT_PUBLISH_BARRIER_DIR
  if (-not $barrier) { return }
  try {
    [IO.File]::WriteAllBytes((Join-Path $barrier 'ready'), [byte[]]@())
  } catch {
    Fail PATH "invalid test publication barrier: $($_.Exception.Message)"
  }
  $deadline = [DateTime]::UtcNow.AddSeconds(10)
  while (-not (Test-Path -LiteralPath (Join-Path $barrier 'continue'))) {
    if ([DateTime]::UtcNow -ge $deadline) { Fail PATH 'test publication barrier timed out' }
    Start-Sleep -Milliseconds 10
  }
}
function Remove-TemporarySnapshot([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  if ($IsWindows) {
    try {
      $acl = Get-Acl -LiteralPath $Path
      $acl.SetAccessRuleProtection($false, $false)
      $acl.PurgeAccessRules([Security.Principal.WindowsIdentity]::GetCurrent().User)
      Set-Acl -LiteralPath $Path -AclObject $acl
    } catch {}
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue)) {
      if (-not $item.PSIsContainer) {
        try { [IO.File]::SetAttributes($item.FullName, [IO.File]::GetAttributes($item.FullName) -band (-bnot [IO.FileAttributes]::ReadOnly)) } catch {}
      }
    }
  } else {
    foreach ($item in @((Get-Item -LiteralPath $Path -Force)) + @(Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue)) {
      try {
        $mode = if ($item.PSIsContainer) {
          [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute
        } else {
          [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite
        }
        [IO.File]::SetUnixFileMode($item.FullName, $mode)
      } catch {}
    }
  }
  Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
}

try {
  $data = Get-Content -Raw -LiteralPath $Manifest | ConvertFrom-Json
} catch {
  Fail JSON $_.Exception.Message
}
if ($null -eq $data -or $data -is [System.Array]) { Fail JSON 'manifest must be an object' }
if ($data.allowed_inputs -isnot [System.Array] -or $data.allowed_inputs.Count -eq 0) {
  Fail PATH 'allowed_inputs must be non-empty'
}
$repo = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
$repoItem = Get-Item -LiteralPath $repo -Force
if (-not $repoItem.PSIsContainer -or $repoItem.LinkType) { Fail PATH 'repository root is not a directory' }
if (Test-Path -LiteralPath $SnapshotRoot) { Fail PATH 'snapshot root already exists' }
$parent = Split-Path -Parent ([IO.Path]::GetFullPath($SnapshotRoot))
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$tmp = Join-Path $parent ('.task-snapshot-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  $seen = @{}
  foreach ($entry in @($data.allowed_inputs)) {
    $entryNames = @($entry.PSObject.Properties | Select-Object -ExpandProperty Name)
    if (($entryNames | Sort-Object -CaseSensitive) -join ',' -cne 'path,sha256') { Fail PATH 'invalid allowed_inputs entry' }
    if (-not (Test-RepoPath $entry.path)) { Fail PATH "invalid input path: $($entry.path)" }
    if ($seen.ContainsKey($entry.path)) { Fail PATH "duplicate input path: $($entry.path)" }
    $seen[$entry.path] = $true
    if ($entry.sha256 -isnot [string] -or $entry.sha256 -notmatch '^[a-f0-9]{64}$') { Fail HASH "invalid sha256 for $($entry.path)" }
    $source = Get-SafeSource $repo $entry.path
    $fullSource = [IO.Path]::GetFullPath($source)
    $repoPrefix = $repo.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $fullSource.StartsWith($repoPrefix, [StringComparison]::Ordinal)) { Fail PATH "input escapes repository: $($entry.path)" }
    $item = Get-Item -LiteralPath $source -Force
    $beforeLength = $item.Length
    $beforeWrite = $item.LastWriteTimeUtc.Ticks
    $target = Join-Path $tmp ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    $sourceStream = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
      $sha = [Security.Cryptography.SHA256]::Create()
      try {
        $actual = [BitConverter]::ToString($sha.ComputeHash($sourceStream)).Replace('-','').ToLowerInvariant()
      } finally {
        $sha.Dispose()
      }
      if ($actual -cne $entry.sha256) { Fail HASH "source hash mismatch: $($entry.path)" }
      $sourceStream.Position = 0
      $targetStream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
      try {
        $sourceStream.CopyTo($targetStream)
        $targetStream.Flush($true)
      } finally {
        $targetStream.Dispose()
      }
    } finally {
      $sourceStream.Dispose()
    }
    $after = Get-Item -LiteralPath $source -Force
    if ($after.LinkType -or $after.Length -ne $beforeLength -or $after.LastWriteTimeUtc.Ticks -ne $beforeWrite) { Fail HASH "source changed during copy: $($entry.path)" }
    $copied = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
    if ($copied -cne $entry.sha256) { Fail HASH "snapshot hash mismatch: $($entry.path)" }
  }
  Set-SnapshotReadOnly $tmp
  Wait-TestPublicationBarrier
  try {
    [IO.Directory]::Move($tmp, [IO.Path]::GetFullPath($SnapshotRoot))
  } catch [IO.IOException] {
    if (Test-Path -LiteralPath $SnapshotRoot) { Fail PATH 'snapshot root already exists' }
    Fail PATH "atomic snapshot publication failed: $($_.Exception.Message)"
  }
} catch {
  Remove-TemporarySnapshot $tmp
  throw
}
Write-Output 'TASK_INPUT_OK'
