$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'native Windows required; not executed' }
$helper = Join-Path $PSScriptRoot '../../plugins/sdd-context/windows-store.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('sdd-private-' + [Guid]::NewGuid().ToString('N'))
try {
  $parent = Join-Path $root '.sdd'
  [IO.Directory]::CreateDirectory($parent) | Out-Null
  $store = Join-Path $parent 'context'
  $result = & pwsh -NoLogo -NoProfile -NonInteractive -File $helper -Store $store
  if ($LASTEXITCODE -ne 0 -or $result -cne 'created') { throw 'fresh creation failed' }
  $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
  $acl = Get-Acl -LiteralPath $store
  if (-not $acl.AreAccessRulesProtected -or -not $acl.GetOwner([Security.Principal.SecurityIdentifier]).Equals($sid)) {
    throw 'private owner/protection mismatch'
  }
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
  if ($rules.Count -ne 1 -or -not $rules[0].IdentityReference.Equals($sid) -or
      $rules[0].AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
      $rules[0].FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl -or
      $rules[0].InheritanceFlags -ne ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit) -or
      $rules[0].PropagationFlags -ne [Security.AccessControl.PropagationFlags]::None) { throw 'private rights mismatch' }
  $content = Join-Path $store 'synthetic.txt'
  [IO.File]::WriteAllText($content, 'ordinary synthetic fixture')
  $before = $acl.Sddl
  $result = & pwsh -NoLogo -NoProfile -NonInteractive -File $helper -Store $store
  if ($LASTEXITCODE -eq 0 -or $result -or (Get-Acl -LiteralPath $store).Sddl -cne $before -or
      [IO.File]::ReadAllText($content) -cne 'ordinary synthetic fixture') { throw 'existing target changed' }
  Write-Output 'Windows native private creation and existing-directory preservation passed'
} finally {
  if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
